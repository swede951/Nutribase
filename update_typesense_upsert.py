#!/usr/bin/env python3
"""
Open Food Facts to Typesense UPSERT Script
Updates existing products and adds new ones without deleting the collection.
Uses the same lean schema as the original import.
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

# JSON file path - pointing to the new downloaded file
JSON_FILE_PATH = os.path.expanduser("~/Downloads/openfoodfacts-products.jsonl (1).gz")

# Import configuration
BATCH_SIZE = 20000  # Larger batches for faster processing
MAX_PRODUCTS = None  # Set to a number to limit imports for testing

def get_typesense_headers():
    """Get headers for Typesense API requests"""
    return {
        'Content-Type': 'application/json',
        'X-TYPESENSE-API-KEY': TYPESENSE_CONFIG['admin_api_key']
    }

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

def upload_batch_upsert(documents):
    """Upload a batch of documents to Typesense using UPSERT"""
    if not documents:
        return 0, 0
    
    # Use action=upsert to update existing and create new
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}/documents/import?action=upsert"
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
    """Process the JSON/JSONL file and upsert to Typesense"""
    print(f"📁 Processing file at {JSON_FILE_PATH}")
    
    if not os.path.exists(JSON_FILE_PATH):
        print(f"❌ Error: File not found at {JSON_FILE_PATH}")
        return False
    
    batch = []
    total_success = 0
    total_errors = 0
    doc_id = 1
    
    print("🔄 Processing data with UPSERT (update existing, add new)...")
    
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
                            success, errors = upload_batch_upsert(batch)
                            total_success += success
                            total_errors += errors
                            batch = []
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
                                success, errors = upload_batch_upsert(batch)
                                total_success += success
                                total_errors += errors
                                if (total_success + total_errors) % 100000 == 0:
                                    print(f"✅ Processed {total_success + total_errors} products ({total_success} success, {total_errors} errors)")
                                batch = []
                    except json.JSONDecodeError:
                        continue
        
        # Upload remaining documents
        if batch:
            success, errors = upload_batch_upsert(batch)
            total_success += success
            total_errors += errors
        
        print(f"\n🎉 Upsert completed!")
        print(f"✅ Successfully processed: {total_success}")
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
            return data.get('num_documents', 0)
        return 0
    except Exception as e:
        print(f"❌ Error checking stats: {e}")
        return 0

def main():
    """Main upsert process"""
    print("🚀 Starting Open Food Facts UPSERT")
    print("📋 This will UPDATE existing products and ADD new ones")
    print("📋 The existing collection will NOT be deleted")
    print(f"📁 Source file: {JSON_FILE_PATH}")
    
    # Check if file exists
    if not os.path.exists(JSON_FILE_PATH):
        print(f"\n❌ File not found at: {JSON_FILE_PATH}")
        print("Please ensure the openfoodfacts-products.jsonl (1).gz file is in your Downloads folder")
        return
    
    # Get file size
    file_size = os.path.getsize(JSON_FILE_PATH) / (1024 * 1024 * 1024)
    print(f"📦 File size: {file_size:.2f} GB")
    
    # Check current collection stats
    print("\n📊 Current collection stats (before upsert):")
    docs_before = check_collection_stats()
    
    start_time = time.time()
    
    # Process and upsert data
    print("\n📦 Starting upsert...")
    if process_json_file():
        end_time = time.time()
        duration = end_time - start_time
        hours = int(duration // 3600)
        minutes = int((duration % 3600) // 60)
        seconds = int(duration % 60)
        print(f"\n⏱️  Total time: {hours}h {minutes}m {seconds}s")
        
        # Show final stats
        print("\n📊 Final collection stats (after upsert):")
        docs_after = check_collection_stats()
        
        if docs_after > docs_before:
            print(f"📈 Added {docs_after - docs_before} new products")
        
        print("\n✅ Upsert completed successfully!")
    else:
        print("❌ Upsert failed")

if __name__ == "__main__":
    main()
