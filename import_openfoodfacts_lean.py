#!/usr/bin/env python3
"""
Open Food Facts to Typesense LEAN Import Script
Only imports the ~20 fields that the Nutribase app actually uses.
This reduces RAM usage significantly compared to the full schema.

Fields included (matching TypesenseDirectService.swift):
- id, name, brand, barcode
- calories, protein, carbohydrates, fat
- fiber, sugar, sodium, saturated_fat
- nova_score, nutriscore_grade, nutriscore_score
- serving_size, categories, ingredients, allergens, countries
"""

import os
import json
import requests
from tqdm import tqdm
import time
import gzip
from datetime import datetime

# Typesense configuration
TYPESENSE_CONFIG = {
    'api_url': 'https://h8ugnjal1c65sm2op-1.a1.typesense.net',
    'admin_api_key': 'iCrX1bLheI7cTr2USV764ElrD3dG3lL3',
    'collection_name': 'foods'
}

# JSON file path - pointing to the downloaded file in Downloads
JSON_FILE_PATH = os.path.expanduser("~/Downloads/openfoodfacts-products.jsonl.gz")

# Import configuration
BATCH_SIZE = 1000
MAX_PRODUCTS = None  # Set to a number to limit imports for testing

def get_typesense_headers():
    """Get headers for Typesense API requests"""
    return {
        'Content-Type': 'application/json',
        'X-TYPESENSE-API-KEY': TYPESENSE_CONFIG['admin_api_key']
    }

def delete_collection():
    """Delete the existing collection"""
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}"
    headers = get_typesense_headers()
    
    try:
        response = requests.delete(url, headers=headers)
        if response.status_code == 200:
            print("✅ Existing collection deleted successfully")
            return True
        elif response.status_code == 404:
            print("ℹ️ Collection does not exist, nothing to delete")
            return True
        else:
            print(f"❌ Error deleting collection: {response.status_code}")
            print(response.text)
            return False
    except Exception as e:
        print(f"❌ Exception deleting collection: {e}")
        return False

def create_lean_collection():
    """Create the collection with lean schema - only fields the app uses"""
    url = f"{TYPESENSE_CONFIG['api_url']}/collections"
    headers = get_typesense_headers()
    
    # Lean schema matching TypesenseDirectService.swift field names exactly
    schema = {
        "name": TYPESENSE_CONFIG['collection_name'],
        "fields": [
            # Basic info - searchable
            {"name": "name", "type": "string", "facet": False},
            {"name": "brand", "type": "string", "facet": False, "optional": True},
            {"name": "barcode", "type": "string", "facet": False, "optional": True},
            
            # Macronutrients (per 100g)
            {"name": "calories", "type": "int32", "facet": False},
            {"name": "protein", "type": "float", "facet": False, "optional": True},
            {"name": "carbohydrates", "type": "float", "facet": False, "optional": True},
            {"name": "fat", "type": "float", "facet": False, "optional": True},
            
            # Key micronutrients the app uses
            {"name": "fiber", "type": "float", "facet": False, "optional": True},
            {"name": "sugar", "type": "float", "facet": False, "optional": True},
            {"name": "sodium", "type": "float", "facet": False, "optional": True},
            {"name": "saturated_fat", "type": "float", "facet": False, "optional": True},
            
            # Scoring systems
            {"name": "nova_score", "type": "int32", "facet": True, "optional": True},
            {"name": "nutriscore_grade", "type": "string", "facet": True, "optional": True},
            {"name": "nutriscore_score", "type": "int32", "facet": False, "optional": True},
            
            # Serving info
            {"name": "serving_size", "type": "string", "facet": False, "optional": True},
            
            # Arrays for search and filtering
            {"name": "categories", "type": "string[]", "facet": True, "optional": True},
            {"name": "ingredients", "type": "string[]", "facet": False, "optional": True},
            {"name": "allergens", "type": "string[]", "facet": True, "optional": True},
            {"name": "countries", "type": "string[]", "facet": True, "optional": True},
        ],
        "default_sorting_field": "calories"
    }
    
    try:
        response = requests.post(url, headers=headers, json=schema)
        if response.status_code == 201:
            print("✅ Lean collection created successfully")
            print(f"   Schema has {len(schema['fields'])} fields (down from 40+)")
            return True
        else:
            print(f"❌ Error creating collection: {response.status_code}")
            print(response.text)
            return False
    except Exception as e:
        print(f"❌ Exception creating collection: {e}")
        return False

def safe_float(value, default=0.0):
    """Safely convert value to float"""
    if value is None or value == '':
        return default
    try:
        return float(value)
    except (ValueError, TypeError):
        return default

def safe_int(value, default=0):
    """Safely convert value to int"""
    if value is None or value == '':
        return default
    try:
        return int(float(value))
    except (ValueError, TypeError):
        return default

def parse_array_field(value):
    """Parse comma-separated string into array"""
    if not value or value == '':
        return []
    if isinstance(value, list):
        return [str(item).strip() for item in value if item]
    return [item.strip() for item in str(value).split(',') if item.strip()]

def convert_to_lean_document(product, doc_id):
    """Convert JSON product to lean Typesense document - only fields the app uses"""
    try:
        # Skip products without essential data
        name = product.get('product_name', '').strip()
        if not name and 'product_name_en' in product:
            name = product.get('product_name_en', '').strip()
        if not name:
            return None
        
        # Use Open Food Facts _id or barcode as document ID
        off_id = product.get('_id', '').strip()
        barcode = product.get('code', '').strip()
        stable_id = off_id if off_id else barcode
        if not stable_id:
            stable_id = str(doc_id)
        
        # Get nutriments data
        nutriments = product.get('nutriments', {})
        
        # Build lean document with exact field names matching the app
        doc = {
            'id': stable_id,
            'name': name,
            'brand': product.get('brands', '').strip() or None,
            'barcode': barcode or None,
            
            # Macronutrients (per 100g)
            'calories': safe_int(nutriments.get('energy-kcal_100g')),
            'protein': safe_float(nutriments.get('proteins_100g')),
            'carbohydrates': safe_float(nutriments.get('carbohydrates_100g')),
            'fat': safe_float(nutriments.get('fat_100g')),
            
            # Key micronutrients the app uses
            'fiber': safe_float(nutriments.get('fiber_100g')) or None,
            'sugar': safe_float(nutriments.get('sugars_100g')) or None,
            'sodium': safe_float(nutriments.get('sodium_100g')) or None,
            'saturated_fat': safe_float(nutriments.get('saturated-fat_100g')) or None,
            
            # Scoring systems
            'nova_score': safe_int(nutriments.get('nova-group')) or safe_int(product.get('nova_group')) or None,
            'nutriscore_grade': product.get('nutriscore_grade', '').lower() if product.get('nutriscore_grade') and product.get('nutriscore_grade') != 'unknown' else None,
            'nutriscore_score': safe_int(product.get('nutriscore_score')) or None,
            
            # Serving info
            'serving_size': product.get('serving_size', '').strip() or None,
            
            # Arrays for search and filtering
            'categories': parse_array_field(product.get('categories', '')) or None,
            'ingredients': parse_array_field(product.get('ingredients_text', '')) or None,
            'allergens': parse_array_field(product.get('allergens', '')) or None,
            'countries': parse_array_field(product.get('countries', '')) or None,
        }
        
        # Remove None values to save space
        doc = {k: v for k, v in doc.items() if v is not None}
        
        # Ensure required fields exist
        if 'calories' not in doc:
            doc['calories'] = 0
            
        return doc
        
    except Exception as e:
        return None

def upload_batch(documents):
    """Upload a batch of documents to Typesense"""
    if not documents:
        return 0, 0
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}/documents/import?action=create"
    headers = get_typesense_headers()
    headers['Content-Type'] = 'text/plain'
    
    # Convert documents to JSONL format
    jsonl_data = '\n'.join([json.dumps(doc) for doc in documents])
    
    try:
        response = requests.post(url, headers=headers, data=jsonl_data)
        if response.status_code == 200:
            # Parse response to count successes and failures
            results = response.text.strip().split('\n')
            success_count = 0
            error_count = 0
            for result in results:
                try:
                    result_json = json.loads(result)
                    if result_json.get('success', False):
                        success_count += 1
                    else:
                        error_count += 1
                except:
                    error_count += 1
            return success_count, error_count
        else:
            print(f"❌ Error uploading batch: {response.status_code}")
            print(response.text[:500])
            return 0, len(documents)
    except Exception as e:
        print(f"❌ Exception uploading batch: {e}")
        return 0, len(documents)

def process_json_file():
    """Process the JSON/JSONL file and import to Typesense"""
    print(f"📁 Processing file at {JSON_FILE_PATH}")
    
    if not os.path.exists(JSON_FILE_PATH):
        print(f"❌ Error: File not found at {JSON_FILE_PATH}")
        return False
    
    batch = []
    total_success = 0
    total_errors = 0
    doc_id = 1
    
    print("🔄 Processing data with LEAN schema...")
    
    try:
        # Handle gzipped files
        if JSON_FILE_PATH.endswith('.gz'):
            file_handle = gzip.open(JSON_FILE_PATH, 'rt', encoding='utf-8')
        else:
            file_handle = open(JSON_FILE_PATH, 'r', encoding='utf-8')
        
        with file_handle as file:
            # Try to detect if it's a single JSON array or JSONL format
            first_char = file.read(1)
            file.seek(0)
            
            if first_char == '[':
                # It's a JSON array
                print("📋 Detected JSON array format, loading...")
                data = json.load(file)
                products = data if isinstance(data, list) else [data]
                
                for product in tqdm(products, desc="Processing products"):
                    if MAX_PRODUCTS and (total_success + total_errors) >= MAX_PRODUCTS:
                        break
                    
                    document = convert_to_lean_document(product, doc_id)
                    if document:
                        batch.append(document)
                        doc_id += 1
                        
                        if len(batch) >= BATCH_SIZE:
                            success, errors = upload_batch(batch)
                            total_success += success
                            total_errors += errors
                            batch = []
                            time.sleep(0.1)
            else:
                # It's JSONL format (one JSON object per line)
                print("📋 Detected JSONL format, streaming...")
                for line_num, line in enumerate(tqdm(file, desc="Processing products")):
                    if MAX_PRODUCTS and (total_success + total_errors) >= MAX_PRODUCTS:
                        break
                    
                    try:
                        product = json.loads(line.strip())
                        document = convert_to_lean_document(product, doc_id)
                        if document:
                            batch.append(document)
                            doc_id += 1
                            
                            if len(batch) >= BATCH_SIZE:
                                success, errors = upload_batch(batch)
                                total_success += success
                                total_errors += errors
                                if (total_success + total_errors) % 100000 == 0:
                                    print(f"✅ Processed {total_success + total_errors} products ({total_success} success, {total_errors} errors)")
                                batch = []
                                time.sleep(0.05)
                    except json.JSONDecodeError:
                        continue
        
        # Upload remaining documents
        if batch:
            success, errors = upload_batch(batch)
            total_success += success
            total_errors += errors
        
        print(f"\n🎉 Import completed!")
        print(f"✅ Successfully imported: {total_success}")
        print(f"❌ Errors: {total_errors}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error processing file: {e}")
        import traceback
        traceback.print_exc()
        return False

def check_collection_stats():
    """Check collection statistics"""
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}"
    headers = get_typesense_headers()
    
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            data = response.json()
            print(f"📊 Collection stats:")
            print(f"   Documents: {data.get('num_documents', 0)}")
            print(f"   Fields: {len(data.get('fields', []))}")
            return True
        return False
    except Exception as e:
        print(f"❌ Error checking stats: {e}")
        return False

def main():
    """Main import process"""
    print("🚀 Starting Open Food Facts LEAN Import")
    print("📋 This will DELETE the existing collection and create a new one")
    print("📋 The new schema only includes fields the app actually uses (~20 fields)")
    print(f"📁 Source file: {JSON_FILE_PATH}")
    
    # Check if file exists
    if not os.path.exists(JSON_FILE_PATH):
        print(f"\n❌ File not found at: {JSON_FILE_PATH}")
        print("Please ensure the openfoodfacts-products.jsonl.gz file is in your Downloads folder")
        return
    
    # Get file size
    file_size = os.path.getsize(JSON_FILE_PATH) / (1024 * 1024 * 1024)
    print(f"📦 File size: {file_size:.2f} GB")
    
    # Confirm before proceeding
    print("\n⚠️  WARNING: This will DELETE all existing food data!")
    response = input("Continue with import? (y/N): ")
    if response.lower() != 'y':
        print("❌ Import cancelled")
        return
    
    start_time = time.time()
    
    # Step 1: Delete existing collection
    print("\n📦 Step 1: Deleting existing collection...")
    if not delete_collection():
        print("❌ Failed to delete collection")
        return
    
    # Step 2: Create new lean collection
    print("\n📦 Step 2: Creating lean collection schema...")
    if not create_lean_collection():
        print("❌ Failed to create collection")
        return
    
    # Step 3: Import data
    print("\n📦 Step 3: Importing data...")
    if process_json_file():
        end_time = time.time()
        duration = end_time - start_time
        hours = int(duration // 3600)
        minutes = int((duration % 3600) // 60)
        seconds = int(duration % 60)
        print(f"\n⏱️  Total time: {hours}h {minutes}m {seconds}s")
        
        # Show final stats
        print("\n📊 Final collection stats:")
        check_collection_stats()
        
        print("\n✅ Lean import completed successfully!")
        print("🔍 Your app's food search should work exactly as before")
    else:
        print("❌ Import failed")

if __name__ == "__main__":
    main()
