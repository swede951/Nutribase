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

# MongoDB dump file path
MONGODB_DUMP_PATH = os.path.expanduser("~/Documents/openfoodfacts-mongodbdump")

# Import configuration
BATCH_SIZE = 100
MAX_PRODUCTS = 10000  # Set to None to import all products

def convert_to_food_item(product):
    """Convert MongoDB product to Supabase food item format"""
    try:
        # Extract basic information
        name = product.get('product_name', '')
        if not name and 'product_name_en' in product:
            name = product.get('product_name_en', '')
        
        # Skip products without a name
        if not name:
            return None
            
        # Extract barcode
        code = product.get('code', '')
        
        # Extract brand
        brands = product.get('brands', '')
        
        # Extract NOVA score
        nova_group = None
        if 'nutriments' in product and 'nova-group' in product['nutriments']:
            nova_group = product['nutriments']['nova-group']
        elif 'nova_group' in product:
            nova_group = product['nova_group']
            
        # Extract nutrients
        nutrients = {}
        if 'nutriments' in product:
            nutriments = product['nutriments']
            nutrients = {
                'calories': nutriments.get('energy-kcal_100g', 0),
                'protein': nutriments.get('proteins_100g', 0),
                'carbohydrates': nutriments.get('carbohydrates_100g', 0),
                'fat': nutriments.get('fat_100g', 0),
                'sodium': nutriments.get('sodium_100g', 0),
                'sugar': nutriments.get('sugars_100g', 0),
                'saturated_fat': nutriments.get('saturated-fat_100g', 0),
                'serving_size': product.get('serving_size', '')
            }
        
        # Extract ingredients
        ingredients_array = []
        if 'ingredients_text' in product and product['ingredients_text']:
            ingredients_text = product['ingredients_text']
            ingredients_array = [i.strip() for i in ingredients_text.split(',') if i.strip()]
        
        # Extract Nutri-Score data
        nutriscore_score = None
        nutriscore_grade = None
        
        # Get Nutri-Score score (numeric value)
        if 'nutriscore_score' in product and product['nutriscore_score']:
            try:
                nutriscore_score = int(float(product['nutriscore_score']))
            except (ValueError, TypeError):
                pass
                
        # Get Nutri-Score grade (letter: a, b, c, d, e)
        if 'nutriscore_grade' in product and product['nutriscore_grade'] and product['nutriscore_grade'] != 'unknown':
            nutriscore_grade = product['nutriscore_grade'].lower()
            # Validate that it's a valid grade (a-e)
            if nutriscore_grade not in ['a', 'b', 'c', 'd', 'e']:
                nutriscore_grade = None
        
        # Create the food item
        food_item = {
            'name': name,
            'brand': brands,
            'barcode': code,
            'nova_score': nova_group if nova_group is not None else 0,
            'nutriscore_score': nutriscore_score,
            'nutriscore_grade': nutriscore_grade,
            'ingredients': ingredients_array,
            'nutrients': nutrients,
            'verified': True,
            'source': 'open_food_facts'
        }
        
        return food_item
    except Exception as e:
        print(f"Error converting product: {e}")
        return None

def upload_batch_to_supabase(batch):
    """Upload a batch of food items to Supabase"""
    if not batch:
        return True
        
    endpoint = f"{SUPABASE_URL}/rest/v1/foods"
    
    headers = {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_KEY,
        'Authorization': f'Bearer {SUPABASE_KEY}',
        'Prefer': 'resolution=merge-duplicates'
    }
    
    try:
        response = requests.post(endpoint, json=batch, headers=headers)
        if response.status_code >= 200 and response.status_code < 300:
            return True
        else:
            print(f"Error uploading batch: {response.status_code}")
            print(response.text)
            return False
    except Exception as e:
        print(f"Exception during upload: {e}")
        return False

def process_mongodb_dump():
    """Process the MongoDB dump file and import to Supabase"""
    print(f"Processing MongoDB dump at {MONGODB_DUMP_PATH}")
    
    try:
        # Check if the file exists
        if not os.path.exists(MONGODB_DUMP_PATH):
            print(f"Error: File not found at {MONGODB_DUMP_PATH}")
            return
            
        # Read the BSON data
        with open(MONGODB_DUMP_PATH, 'rb') as f:
            data = f.read()
            
        # Decode BSON data
        print("Decoding BSON data...")
        products = decode_all(data)
        print(f"Found {len(products)} products in the dump")
        
        # Limit the number of products if specified
        if MAX_PRODUCTS:
            products = products[:MAX_PRODUCTS]
            print(f"Limited to {MAX_PRODUCTS} products")
        
        # Process products in batches
        batch = []
        total_imported = 0
        
        print("Starting import process...")
        for product in tqdm(products):
            food_item = convert_to_food_item(product)
            
            if food_item:
                batch.append(food_item)
                
                # Upload batch when it reaches the batch size
                if len(batch) >= BATCH_SIZE:
                    success = upload_batch_to_supabase(batch)
                    if success:
                        total_imported += len(batch)
                        print(f"Imported {total_imported} products so far")
                    batch = []
                    # Add a small delay to avoid overwhelming the server
                    time.sleep(0.5)
        
        # Upload any remaining products
        if batch:
            success = upload_batch_to_supabase(batch)
            if success:
                total_imported += len(batch)
        
        print(f"Import completed. Total products imported: {total_imported}")
        
    except Exception as e:
        print(f"Error processing MongoDB dump: {e}")

if __name__ == "__main__":
    print("Starting Open Food Facts import...")
    process_mongodb_dump()
    print("Done!")
