#!/usr/bin/env python3
"""
Test script to import a small sample of products with Nutri-Score data
"""

import os
import csv
import sys
import requests
import time
from tqdm import tqdm

# Increase CSV field size limit to handle large fields
csv.field_size_limit(sys.maxsize)

# Supabase configuration
SUPABASE_URL = "https://owmwxzkzqrbhhiofzgmm.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93bXd4emt6cXJiaGhpb2Z6Z21tIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzI0MjEwMiwiZXhwIjoyMDYyODE4MTAyfQ.5XKQo-XEWaRXVUPP4wdRj5W-KA9vluuZJPtwIknJo4k"

# CSV file path
CSV_FILE_PATH = os.path.expanduser("~/Documents/en.openfoodfacts.org.products.csv")

# Sample size - small for testing
SAMPLE_SIZE = 20

def convert_to_food_item(row):
    """
    Convert CSV row to Supabase food item format with Nutri-Score data
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
        
        # Try to get energy in kcal
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
    Upload food items to Supabase
    """
    if not food_items:
        print("No food items to upload")
        return False
        
    endpoint = f"{SUPABASE_URL}/rest/v1/foods"
    headers = {
        'apikey': SUPABASE_KEY,
        'Authorization': f'Bearer {SUPABASE_KEY}',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates'
    }
    
    # Upload in a single batch for this small test
    try:
        print(f"Uploading {len(food_items)} food items to Supabase...")
        response = requests.post(endpoint, json=food_items, headers=headers)
        
        if response.status_code == 201:
            print("✅ Upload successful")
            return True
        else:
            print(f"❌ Upload failed with status code: {response.status_code}")
            print(response.text)
            return False
    except Exception as e:
        print(f"Error uploading to Supabase: {e}")
        return False

def find_products_with_nutriscore():
    """
    Find products with Nutri-Score data in the CSV file
    """
    try:
        print(f"Searching for products with Nutri-Score data...")
        
        # Check if file exists
        if not os.path.exists(CSV_FILE_PATH):
            print(f"Error: CSV file not found at {CSV_FILE_PATH}")
            return []
        
        products_with_nutriscore = []
        
        with open(CSV_FILE_PATH, 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file, delimiter='\t')
            
            for i, row in enumerate(reader):
                if i >= 10000:  # Only check first 10,000 rows
                    break
                
                # Check if this product has Nutri-Score data
                has_nutriscore = False
                if ('nutriscore_score' in row and row['nutriscore_score'] and
                    'nutriscore_grade' in row and row['nutriscore_grade'] and 
                    row['nutriscore_grade'] != 'unknown'):
                    has_nutriscore = True
                
                if has_nutriscore:
                    food_item = convert_to_food_item(row)
                    if food_item:
                        products_with_nutriscore.append(food_item)
                        
                        # Print progress
                        if len(products_with_nutriscore) % 5 == 0:
                            print(f"Found {len(products_with_nutriscore)} products with Nutri-Score data")
                
                # Stop once we have enough products
                if len(products_with_nutriscore) >= SAMPLE_SIZE:
                    break
        
        print(f"\nFound {len(products_with_nutriscore)} products with Nutri-Score data")
        return products_with_nutriscore
    
    except Exception as e:
        print(f"Error finding products with Nutri-Score: {e}")
        return []

def verify_nutriscore_in_supabase(food_items):
    """
    Verify that Nutri-Score data was successfully imported
    """
    if not food_items:
        print("No food items to verify")
        return
    
    print("\nVerifying Nutri-Score data in Supabase...")
    
    # Check a few random items
    for i, item in enumerate(food_items[:3]):
        barcode = item['barcode']
        
        endpoint = f"{SUPABASE_URL}/rest/v1/foods"
        params = {
            'select': '*',
            'barcode': f"eq.{barcode}"
        }
        
        headers = {
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}'
        }
        
        try:
            response = requests.get(endpoint, params=params, headers=headers)
            
            if response.status_code == 200:
                results = response.json()
                if results:
                    db_item = results[0]
                    print(f"\nItem {i+1}: {db_item.get('name', 'Unknown')}")
                    print(f"  Barcode: {db_item.get('barcode', 'Unknown')}")
                    print(f"  Nutri-Score Score: {db_item.get('nutriscore_score', 'Not found')}")
                    print(f"  Nutri-Score Grade: {db_item.get('nutriscore_grade', 'Not found')}")
                    
                    # Check if Nutri-Score data matches
                    if db_item.get('nutriscore_score') == item['nutriscore_score'] and db_item.get('nutriscore_grade') == item['nutriscore_grade']:
                        print("  ✅ Nutri-Score data matches!")
                    else:
                        print("  ❌ Nutri-Score data mismatch!")
                        print(f"  Expected: score={item['nutriscore_score']}, grade={item['nutriscore_grade']}")
                else:
                    print(f"\nItem {i+1}: Not found in database")
            else:
                print(f"\nError verifying item {i+1}: {response.status_code}")
                print(response.text)
        
        except Exception as e:
            print(f"Error verifying item {i+1}: {e}")

if __name__ == "__main__":
    print("Starting Nutri-Score import test...")
    
    # Find products with Nutri-Score data
    food_items = find_products_with_nutriscore()
    
    if food_items:
        # Upload to Supabase
        success = upload_to_supabase(food_items)
        
        if success:
            # Verify the data
            verify_nutriscore_in_supabase(food_items)
    else:
        print("No products with Nutri-Score data found")
