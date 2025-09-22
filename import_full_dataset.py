#!/usr/bin/env python3
"""
Full Open Food Facts CSV Importer
This script processes the entire Open Food Facts CSV data and imports it into Supabase.
It uses chunking to handle the large file size and includes all available fields.
"""

import os
import csv
import sys
import time
import requests
from tqdm import tqdm

# Increase CSV field size limit to handle large fields
csv.field_size_limit(sys.maxsize)

# Supabase configuration
SUPABASE_URL = "https://owmwxzkzqrbhhiofzgmm.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93bXd4emt6cXJiaGhpb2Z6Z21tIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzI0MjEwMiwiZXhwIjoyMDYyODE4MTAyfQ.5XKQo-XEWaRXVUPP4wdRj5W-KA9vluuZJPtwIknJo4k"

# CSV file path
CSV_FILE_PATH = os.path.expanduser("~/Documents/en.openfoodfacts.org.products.csv")

# Import configuration
BATCH_SIZE = 100  # Number of items to upload in a single batch
MAX_ITEMS = 10000  # Maximum number of items to import (set to None for all)
SKIP_ITEMS = 0     # Number of items to skip at the beginning

def convert_to_food_item(row):
    """
    Convert CSV row to Supabase food item format
    """
    try:
        # Extract basic information
        code = row.get('code', '')
        name = row.get('product_name', '')
        
        # Skip products without a name or code
        if not name or not code:
            return None
            
        # Extract brand
        brands = row.get('brands', '')
        
        # Extract NOVA score
        nova_group = 0
        if 'nova_group' in row and row['nova_group']:
            try:
                nova_group = int(float(row['nova_group']))
            except (ValueError, TypeError):
                pass
            
        # Extract Nutri-Score data
        nutriscore_score = None
        nutriscore_grade = None
        
        # Get Nutri-Score score (numeric value)
        if 'nutriscore_score' in row and row['nutriscore_score']:
            try:
                nutriscore_score = int(float(row['nutriscore_score']))
            except (ValueError, TypeError):
                pass
                
        # Get Nutri-Score grade (letter: a, b, c, d, e)
        if 'nutriscore_grade' in row and row['nutriscore_grade'] and row['nutriscore_grade'] != 'unknown':
            nutriscore_grade = row['nutriscore_grade'].lower()
            # Validate that it's a valid grade (a-e)
            if nutriscore_grade not in ['a', 'b', 'c', 'd', 'e']:
                nutriscore_grade = None
        
        # Extract nutrients - match the NutrientInfo structure in Swift
        nutrients = {
            'calories': 0,
            'protein': 0.0,
            'carbohydrates': 0.0,
            'fat': 0.0,
            'sodium': 0.0,
            'sugar': 0.0,
            'saturated_fat': 0.0,
            'serving_size': '',
            'servings_per_package': None
        }
        
        # Try to get energy in kcal - ensure it's an integer as required by NutrientInfo
        if 'energy-kcal_100g' in row and row['energy-kcal_100g']:
            try:
                nutrients['calories'] = int(float(row['energy-kcal_100g']))
            except (ValueError, TypeError):
                pass
        
        # Try to get protein
        if 'proteins_100g' in row and row['proteins_100g']:
            try:
                nutrients['protein'] = float(row['proteins_100g'])
            except (ValueError, TypeError):
                pass
        
        # Try to get carbohydrates
        if 'carbohydrates_100g' in row and row['carbohydrates_100g']:
            try:
                nutrients['carbohydrates'] = float(row['carbohydrates_100g'])
            except (ValueError, TypeError):
                pass
        
        # Try to get fat
        if 'fat_100g' in row and row['fat_100g']:
            try:
                nutrients['fat'] = float(row['fat_100g'])
            except (ValueError, TypeError):
                pass
        
        # Try to get sodium
        if 'sodium_100g' in row and row['sodium_100g']:
            try:
                nutrients['sodium'] = float(row['sodium_100g'])
            except (ValueError, TypeError):
                pass
        
        # Try to get sugar
        if 'sugars_100g' in row and row['sugars_100g']:
            try:
                nutrients['sugar'] = float(row['sugars_100g'])
            except (ValueError, TypeError):
                pass
        
        # Try to get saturated fat
        if 'saturated-fat_100g' in row and row['saturated-fat_100g']:
            try:
                nutrients['saturated_fat'] = float(row['saturated-fat_100g'])
            except (ValueError, TypeError):
                pass
        
        # Try to get serving size
        if 'serving_size' in row:
            nutrients['serving_size'] = row['serving_size']
        
        # Extract ingredients
        ingredients_array = []
        if 'ingredients_text' in row and row['ingredients_text']:
            ingredients_text = row['ingredients_text']
            ingredients_array = [i.strip() for i in ingredients_text.split(',') if i.strip()]
        
        # Create the food item
        food_item = {
            'name': name,
            'brand': brands,
            'barcode': code,
            'nova_score': nova_group,
            'nutriscore_score': nutriscore_score,
            'nutriscore_grade': nutriscore_grade,
            'ingredients': ingredients_array,
            'nutrients': nutrients,
            'verified': True
        }
        
        return food_item
    except Exception as e:
        print(f"Error converting row: {e}")
        return None

def upload_to_supabase(food_items):
    """
    Upload food items to Supabase in batches
    """
    if not food_items:
        print("No food items to upload")
        return 0
        
    endpoint = f"{SUPABASE_URL}/rest/v1/foods"
    headers = {
        'apikey': SUPABASE_KEY,
        'Authorization': f'Bearer {SUPABASE_KEY}',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates'
    }
    
    # Split into batches
    batches = [food_items[i:i + BATCH_SIZE] for i in range(0, len(food_items), BATCH_SIZE)]
    total_uploaded = 0
    
    print(f"Uploading {len(food_items)} food items in {len(batches)} batches...")
    
    # Upload each batch
    for i, batch in enumerate(tqdm(batches, desc="Uploading batches")):
        try:
            response = requests.post(endpoint, json=batch, headers=headers)
            
            if response.status_code == 201:
                total_uploaded += len(batch)
            else:
                print(f"Batch {i+1} upload failed with status code: {response.status_code}")
                print(response.text[:200] + "..." if len(response.text) > 200 else response.text)
                
            # Sleep briefly between batches to avoid rate limiting
            time.sleep(0.5)
            
        except Exception as e:
            print(f"Error uploading batch {i+1}: {e}")
    
    return total_uploaded

def process_csv_file():
    """
    Process the Open Food Facts CSV file
    """
    try:
        print(f"Processing CSV file: {CSV_FILE_PATH}")
        
        # Check if file exists
        if not os.path.exists(CSV_FILE_PATH):
            print(f"Error: CSV file not found at {CSV_FILE_PATH}")
            return []
        
        food_items = []
        processed = 0
        skipped = 0
        empty_name_or_code = 0
        conversion_errors = 0
        
        # Process the CSV file
        with open(CSV_FILE_PATH, 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file, delimiter='\t')
            
            # Skip items if needed
            if SKIP_ITEMS > 0:
                print(f"Skipping first {SKIP_ITEMS} items...")
                for _ in tqdm(range(SKIP_ITEMS), desc="Skipping items"):
                    try:
                        next(reader)
                        skipped += 1
                    except StopIteration:
                        print("Reached end of file while skipping")
                        break
            
            # Process remaining items
            print("Processing items...")
            for row in tqdm(reader, desc="Processing rows"):
                processed += 1
                
                # Convert row to food item
                food_item = convert_to_food_item(row)
                
                if food_item:
                    food_items.append(food_item)
                else:
                    empty_name_or_code += 1
                
                # Upload in batches to avoid memory issues
                if len(food_items) >= BATCH_SIZE:
                    uploaded = upload_to_supabase(food_items)
                    print(f"Uploaded {uploaded} food items")
                    food_items = []  # Clear the list after uploading
                
                # Stop if we've reached the maximum number of items
                if MAX_ITEMS and processed >= MAX_ITEMS:
                    break
        
        # Upload any remaining items
        if food_items:
            uploaded = upload_to_supabase(food_items)
            print(f"Uploaded final batch of {uploaded} food items")
        
        # Print statistics
        print("\nImport Statistics:")
        print(f"- Total rows processed: {processed}")
        print(f"- Rows skipped at start: {skipped}")
        print(f"- Items with empty name or code: {empty_name_or_code}")
        print(f"- Conversion errors: {conversion_errors}")
        
        return food_items
    
    except Exception as e:
        print(f"Error processing CSV file: {e}")
        return []

def verify_data_in_supabase():
    """
    Verify that data was successfully imported
    """
    print("\nVerifying data in Supabase...")
    
    endpoint = f"{SUPABASE_URL}/rest/v1/foods"
    params = {
        'select': 'count',
        'limit': 1
    }
    
    headers = {
        'apikey': SUPABASE_KEY,
        'Authorization': f'Bearer {SUPABASE_KEY}',
        'Prefer': 'count=exact'
    }
    
    try:
        response = requests.get(endpoint, params=params, headers=headers)
        
        if response.status_code == 200:
            count = int(response.headers.get('Content-Range', '0').split('/')[1])
            print(f"✅ Found {count} food items in the database")
            
            # Check for items with Nutri-Score data
            params_nutriscore = {
                'select': 'count',
                'nutriscore_grade': 'not.is.null',
                'limit': 1
            }
            
            response_nutriscore = requests.get(endpoint, params=params_nutriscore, headers=headers)
            
            if response_nutriscore.status_code == 200:
                nutriscore_count = int(response_nutriscore.headers.get('Content-Range', '0').split('/')[1])
                print(f"✅ Found {nutriscore_count} food items with Nutri-Score data ({nutriscore_count/count*100:.1f}%)")
            
            return True
        else:
            print(f"❌ Failed to verify data: {response.status_code}")
            print(response.text)
            return False
    
    except Exception as e:
        print(f"Error verifying data: {e}")
        return False

if __name__ == "__main__":
    print("Starting full Open Food Facts import...")
    process_csv_file()
    verify_data_in_supabase()
