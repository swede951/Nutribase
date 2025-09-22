#!/usr/bin/env python3
"""
Open Food Facts CSV Sample Importer
This script processes a small sample of the Open Food Facts CSV data and imports it into Supabase.
"""

import os
import json
import time
import csv
import requests
from tqdm import tqdm

# Supabase configuration
SUPABASE_URL = "https://owmwxzkzqrbhhiofzgmm.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93bXd4emt6cXJiaGhpb2Z6Z21tIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzI0MjEwMiwiZXhwIjoyMDYyODE4MTAyfQ.5XKQo-XEWaRXVUPP4wdRj5W-KA9vluuZJPtwIknJo4k"

# CSV file path
CSV_FILE_PATH = os.path.expanduser("~/Documents/en.openfoodfacts.org.products.csv")

# Sample size
SAMPLE_SIZE = 1000

# Skip the first N items (to avoid duplicates from previous imports)
SKIP_ITEMS = 1000

# Batch size for uploads
BATCH_SIZE = 50

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
        return False
        
    endpoint = f"{SUPABASE_URL}/rest/v1/foods"
    
    headers = {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_KEY,
        'Authorization': f'Bearer {SUPABASE_KEY}',
        'Prefer': 'resolution=merge-duplicates'
    }
    
    # Process in batches for better efficiency
    total_items = len(food_items)
    successful_uploads = 0
    
    print(f"Uploading {total_items} food items to Supabase in batches of {BATCH_SIZE}...")
    
    # Split into batches
    batches = [food_items[i:i + BATCH_SIZE] for i in range(0, len(food_items), BATCH_SIZE)]
    
    for i, batch in enumerate(batches):
        try:
            print(f"Uploading batch {i+1}/{len(batches)} ({len(batch)} items)...")
            response = requests.post(endpoint, headers=headers, json=batch)
            
            if response.status_code == 201:
                successful_uploads += len(batch)
                print(f"✅ Batch {i+1} upload successful! ({successful_uploads}/{total_items} total)")
            else:
                print(f"❌ Batch {i+1} upload failed with status code: {response.status_code}")
                print(f"Response: {response.text[:200]}..." if len(response.text) > 200 else f"Response: {response.text}")
            
            # Add a small delay between batches to avoid rate limiting
            if i < len(batches) - 1:
                time.sleep(1)
                
        except Exception as e:
            print(f"❌ Error uploading batch {i+1}: {e}")
    
    print(f"\nUpload complete: {successful_uploads}/{total_items} items successfully uploaded")
    
    if successful_uploads > 0:
        print("\nSample of uploaded items:")
        print(json.dumps(food_items[0], indent=2))
        return True
    else:
        return False

def process_csv_sample():
    """
    Process a sample of the Open Food Facts CSV file
    """
    try:
        print(f"Processing CSV file at {CSV_FILE_PATH}")
        
        # Check if file exists
        if not os.path.exists(CSV_FILE_PATH):
            print(f"Error: CSV file not found at {CSV_FILE_PATH}")
            return []
        
        # Process the CSV file
        food_items = []
        count = 0
        skipped = 0
        
        with open(CSV_FILE_PATH, 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file, delimiter='\t')
            
            # Skip items we've already processed
            for row in reader:
                if skipped < SKIP_ITEMS:
                    skipped += 1
                    if skipped % 100 == 0:
                        print(f"Skipped {skipped} items...")
                    continue
                
                if count >= SAMPLE_SIZE:
                    break
                    
                food_item = convert_to_food_item(row)
                if food_item:
                    food_items.append(food_item)
                    print(f"Processed item {count+1}: {food_item['name']}")
                    count += 1
        
        print(f"Processed {count} food items")
        
        # Upload food items to Supabase
        if food_items:
            upload_to_supabase(food_items)
        
        return food_items
        
    except Exception as e:
        print(f"Error processing CSV file: {e}")
        return []

def verify_data_in_supabase(food_items):
    """
    Verify that data was successfully imported by searching for multiple items
    using the correct query format that works with our app
    """
    if not food_items or len(food_items) < 10:
        print("Not enough food items to verify")
        return
    
    # Pick several items to search for
    test_indices = [9, 19, 29, 39, 49]  # Test multiple items
    test_items = [food_items[i] for i in test_indices if i < len(food_items)]
    
    print("\n🔍 Verifying data in Supabase using multiple search strategies...")
    
    endpoint = f"{SUPABASE_URL}/rest/v1/foods"
    headers = {
        'apikey': SUPABASE_KEY,
        'Authorization': f'Bearer {SUPABASE_KEY}'
    }
    
    for i, test_item in enumerate(test_items):
        search_term = test_item.get('name', '')
        if not search_term:
            continue
            
        print(f"\n✨ Test {i+1}: Searching for '{search_term}'")
        
        # Strategy 1: Using the correct format that works with our app (from memory)
        search_pattern = "%" + search_term + "%"
        params = {
            'select': '*',
            'name': f"ilike.{search_pattern}",
            'limit': '5'
        }
        
        try:
            print("Strategy 1: name=ilike.%term%")
            response = requests.get(endpoint, params=params, headers=headers)
            print(f"Status code: {response.status_code}")
            
            if response.status_code == 200:
                results = response.json()
                print(f"Found {len(results)} items")
                if results:
                    print(f"First match: {results[0].get('name', 'Unknown')}")
                
            # Strategy 2: Using OR condition with both name and brand
            print("\nStrategy 2: or=(name.ilike.%term%,brand.ilike.%term%)")
            or_params = {
                'select': '*',
                'or': f"(name.ilike.%{search_term}%,brand.ilike.%{search_term}%)",
                'limit': '5'
            }
            
            response = requests.get(endpoint, params=or_params, headers=headers)
            print(f"Status code: {response.status_code}")
            
            if response.status_code == 200:
                results = response.json()
                print(f"Found {len(results)} items")
                if results:
                    print(f"First match: {results[0].get('name', 'Unknown')}")
                    
        except Exception as e:
            print(f"Error searching: {e}")
    
    # Also check total count of items in database
    try:
        count_params = {'select': 'count'}
        response = requests.get(endpoint, params=count_params, headers=headers)
        
        if response.status_code == 200:
            count_result = response.json()
            if count_result and len(count_result) > 0:
                total_count = count_result[0].get('count', 0)
                print(f"\n📊 Total items in database: {total_count}")
        
    except Exception as e:
        print(f"Error getting count: {e}")

if __name__ == "__main__":
    print("Starting Open Food Facts sample import...")
    food_items = process_csv_sample()
    verify_data_in_supabase(food_items)
    print("Done!")
