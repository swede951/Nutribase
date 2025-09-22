#!/usr/bin/env python3
"""
Open Food Facts Full Import with Timestamp Tracking
This script does a full import but tracks the last update timestamp for future incremental updates.
"""

import os
import json
import time
import csv
import requests
from tqdm import tqdm
from datetime import datetime, timezone

# Supabase configuration
SUPABASE_URL = "https://owmwxzkzqrbhhiofzgmm.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93bXd4emt6cXJiaGhpb2Z6Z21tIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzI0MjEwMiwiZXhwIjoyMDYyODE4MTAyfQ.5XKQo-XEWaRXVUPP4wdRj5W-KA9vluuZJPtwIknJo4k"

# CSV file path
CSV_FILE_PATH = os.path.expanduser("~/Documents/en.openfoodfacts.org.products.csv")

# Import configuration
BATCH_SIZE = 50
MAX_PRODUCTS = None  # Set to None to import all products

# Metadata file to track last import
METADATA_FILE = "last_import_metadata.json"

def load_import_metadata():
    """Load metadata about the last import"""
    if os.path.exists(METADATA_FILE):
        with open(METADATA_FILE, 'r') as f:
            return json.load(f)
    return {}

def save_import_metadata(metadata):
    """Save metadata about the current import"""
    with open(METADATA_FILE, 'w') as f:
        json.dump(metadata, f, indent=2)

def convert_to_food_item(row):
    """Convert CSV row to Supabase food item format"""
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
            
        # Extract nutrients
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
        
        # Extract nutrition values
        if 'energy-kcal_100g' in row and row['energy-kcal_100g']:
            try:
                nutrients['calories'] = int(float(row['energy-kcal_100g']))
            except (ValueError, TypeError):
                pass
        
        if 'proteins_100g' in row and row['proteins_100g']:
            try:
                nutrients['protein'] = float(row['proteins_100g'])
            except (ValueError, TypeError):
                pass
        
        if 'carbohydrates_100g' in row and row['carbohydrates_100g']:
            try:
                nutrients['carbohydrates'] = float(row['carbohydrates_100g'])
            except (ValueError, TypeError):
                pass
        
        if 'fat_100g' in row and row['fat_100g']:
            try:
                nutrients['fat'] = float(row['fat_100g'])
            except (ValueError, TypeError):
                pass
        
        if 'sodium_100g' in row and row['sodium_100g']:
            try:
                nutrients['sodium'] = float(row['sodium_100g'])
            except (ValueError, TypeError):
                pass
        
        if 'sugars_100g' in row and row['sugars_100g']:
            try:
                nutrients['sugar'] = float(row['sugars_100g'])
            except (ValueError, TypeError):
                pass
        
        if 'saturated-fat_100g' in row and row['saturated-fat_100g']:
            try:
                nutrients['saturated_fat'] = float(row['saturated-fat_100g'])
            except (ValueError, TypeError):
                pass
        
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
        
        if 'nutriscore_score' in row and row['nutriscore_score']:
            try:
                nutriscore_score = int(float(row['nutriscore_score']))
            except (ValueError, TypeError):
                pass
                
        if 'nutriscore_grade' in row and row['nutriscore_grade'] and row['nutriscore_grade'] != 'unknown':
            nutriscore_grade = row['nutriscore_grade'].lower()
            if nutriscore_grade not in ['a', 'b', 'c', 'd', 'e']:
                nutriscore_grade = None
        
        # Get last modified timestamp if available
        last_modified = None
        if 'last_modified_datetime' in row and row['last_modified_datetime']:
            last_modified = row['last_modified_datetime']
        
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
            'verified': True,
            'source': 'open_food_facts',
            'last_modified_off': last_modified  # Track Open Food Facts modification time
        }
        
        return food_item
    except Exception as e:
        print(f"Error converting row: {e}")
        return None

def clear_existing_data():
    """Clear existing Open Food Facts data from the database"""
    print("🗑️  Clearing existing Open Food Facts data...")
    
    endpoint = f"{SUPABASE_URL}/rest/v1/foods"
    headers = {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_KEY,
        'Authorization': f'Bearer {SUPABASE_KEY}',
    }
    
    # Delete all records with source = 'open_food_facts'
    params = {'source': 'eq.open_food_facts'}
    
    try:
        response = requests.delete(endpoint, headers=headers, params=params)
        if response.status_code in [200, 204]:
            print("✅ Existing data cleared successfully")
            return True
        else:
            print(f"❌ Error clearing data: {response.status_code}")
            print(response.text)
            return False
    except Exception as e:
        print(f"❌ Exception clearing data: {e}")
        return False

def upload_to_supabase(food_items):
    """Upload food items to Supabase in batches"""
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
    
    total_items = len(food_items)
    successful_uploads = 0
    
    print(f"📤 Uploading {total_items} food items to Supabase in batches of {BATCH_SIZE}...")
    
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
            
            # Add a small delay between batches
            if i < len(batches) - 1:
                time.sleep(1)
                
        except Exception as e:
            print(f"❌ Error uploading batch {i+1}: {e}")
    
    print(f"\n📊 Upload complete: {successful_uploads}/{total_items} items successfully uploaded")
    return successful_uploads > 0

def process_csv_full():
    """Process the full Open Food Facts CSV file"""
    try:
        print(f"📁 Processing CSV file at {CSV_FILE_PATH}")
        
        # Check if file exists
        if not os.path.exists(CSV_FILE_PATH):
            print(f"❌ Error: CSV file not found at {CSV_FILE_PATH}")
            print("Please download the file from: https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv")
            return []
        
        # Load previous import metadata
        metadata = load_import_metadata()
        print(f"📋 Previous import: {metadata.get('last_import_date', 'Never')}")
        
        # Clear existing data
        if not clear_existing_data():
            print("❌ Failed to clear existing data. Aborting.")
            return []
        
        # Process the CSV file
        food_items = []
        count = 0
        latest_modified = None
        
        print("🔄 Processing CSV data...")
        with open(CSV_FILE_PATH, 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file, delimiter='\t')
            
            for row in tqdm(reader, desc="Processing products"):
                if MAX_PRODUCTS and count >= MAX_PRODUCTS:
                    break
                    
                food_item = convert_to_food_item(row)
                if food_item:
                    food_items.append(food_item)
                    count += 1
                    
                    # Track the latest modification date
                    if food_item.get('last_modified_off'):
                        if not latest_modified or food_item['last_modified_off'] > latest_modified:
                            latest_modified = food_item['last_modified_off']
                    
                    # Upload in batches to avoid memory issues
                    if len(food_items) >= BATCH_SIZE * 10:  # Upload every 500 items
                        if upload_to_supabase(food_items):
                            food_items = []  # Clear the batch
        
        # Upload any remaining items
        if food_items:
            upload_to_supabase(food_items)
        
        # Save import metadata
        current_metadata = {
            'last_import_date': datetime.now(timezone.utc).isoformat(),
            'total_products_imported': count,
            'latest_product_modified': latest_modified,
            'import_method': 'full_csv'
        }
        save_import_metadata(current_metadata)
        
        print(f"✅ Import completed!")
        print(f"📊 Total products processed: {count}")
        print(f"📅 Latest product modification: {latest_modified}")
        print(f"💾 Metadata saved to {METADATA_FILE}")
        
        return food_items
        
    except Exception as e:
        print(f"❌ Error processing CSV file: {e}")
        return []

if __name__ == "__main__":
    print("🚀 Starting Open Food Facts full import with tracking...")
    print("⚠️  This will replace all existing Open Food Facts data in your database.")
    
    # Ask for confirmation
    response = input("Continue? (y/N): ")
    if response.lower() != 'y':
        print("❌ Import cancelled.")
        exit(1)
    
    start_time = time.time()
    food_items = process_csv_full()
    end_time = time.time()
    
    print(f"⏱️  Total time: {end_time - start_time:.2f} seconds")
    print("✅ Done!")
