#!/usr/bin/env python3
"""
Open Food Facts to Typesense UPSERT Script
Updates existing foods and adds new ones without deleting the entire collection.
Uses the stable Open Food Facts ID/barcode as document ID for consistent updates.
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

# Metadata file to track imports
METADATA_FILE = "typesense_import_metadata.json"

def get_typesense_headers():
    """Get headers for Typesense API requests"""
    return {
        'Content-Type': 'application/json',
        'X-TYPESENSE-API-KEY': TYPESENSE_CONFIG['admin_api_key']
    }

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

def safe_float(value, default=0.0):
    """Safely convert value to float"""
    if not value or value == '':
        return default
    try:
        return float(value)
    except (ValueError, TypeError):
        return default

def safe_int(value, default=0):
    """Safely convert value to int"""
    if not value or value == '':
        return default
    try:
        return int(float(value))
    except (ValueError, TypeError):
        return default

def parse_array_field(value):
    """Parse comma-separated string into array"""
    if not value or value == '':
        return []
    return [item.strip() for item in str(value).split(',') if item.strip()]

def convert_json_to_typesense_document(product, doc_id):
    """Convert JSON product to Typesense document with comprehensive nutrient data"""
    try:
        # Skip products without essential data
        name = product.get('product_name', '').strip()
        if not name and 'product_name_en' in product:
            name = product.get('product_name_en', '').strip()
        if not name:
            return None
        
        # Use Open Food Facts _id or barcode as document ID for consistent upserts
        off_id = product.get('_id', '').strip()
        barcode = product.get('code', '').strip()
        stable_id = off_id if off_id else barcode
        if not stable_id:
            stable_id = str(doc_id)
        
        # Get nutriments data
        nutriments = product.get('nutriments', {})
        
        # Basic product information
        doc = {
            'id': stable_id,
            'name': name,
            'brand': product.get('brands', '').strip(),
            'barcode': barcode,
            'categories': parse_array_field(product.get('categories', '')),
            'ingredients': parse_array_field(product.get('ingredients_text', '')),
            'allergens': parse_array_field(product.get('allergens', '')),
            
            # Macronutrients (per 100g)
            'calories': safe_float(nutriments.get('energy-kcal_100g')),
            'protein': safe_float(nutriments.get('proteins_100g')),
            'carbohydrates': safe_float(nutriments.get('carbohydrates_100g')),
            'fat': safe_float(nutriments.get('fat_100g')),
            'saturated_fat': safe_float(nutriments.get('saturated-fat_100g')),
            'trans_fat': safe_float(nutriments.get('trans-fat_100g')),
            'fiber': safe_float(nutriments.get('fiber_100g')),
            'sugar': safe_float(nutriments.get('sugars_100g')),
            'sodium': safe_float(nutriments.get('sodium_100g')),
            'cholesterol': safe_float(nutriments.get('cholesterol_100g')),
            
            # Fat-soluble vitamins (per 100g)
            'vitamin_a': safe_float(nutriments.get('vitamin-a_100g')),
            'vitamin_d': safe_float(nutriments.get('vitamin-d_100g')),
            'vitamin_e': safe_float(nutriments.get('vitamin-e_100g')),
            'vitamin_k': safe_float(nutriments.get('vitamin-k_100g')),
            
            # Water-soluble vitamins (per 100g)
            'vitamin_c': safe_float(nutriments.get('vitamin-c_100g')),
            'vitamin_b1': safe_float(nutriments.get('vitamin-b1_100g')),
            'vitamin_b2': safe_float(nutriments.get('vitamin-b2_100g')),
            'vitamin_b3': safe_float(nutriments.get('vitamin-pp_100g')),
            'vitamin_b5': safe_float(nutriments.get('pantothenic-acid_100g')),
            'vitamin_b6': safe_float(nutriments.get('vitamin-b6_100g')),
            'vitamin_b7': safe_float(nutriments.get('biotin_100g')),
            'vitamin_b9': safe_float(nutriments.get('folates_100g')),
            'vitamin_b12': safe_float(nutriments.get('vitamin-b12_100g')),
            
            # Essential minerals (per 100g)
            'calcium': safe_float(nutriments.get('calcium_100g')),
            'iron': safe_float(nutriments.get('iron_100g')),
            'magnesium': safe_float(nutriments.get('magnesium_100g')),
            'phosphorus': safe_float(nutriments.get('phosphorus_100g')),
            'potassium': safe_float(nutriments.get('potassium_100g')),
            'zinc': safe_float(nutriments.get('zinc_100g')),
            'copper': safe_float(nutriments.get('copper_100g')),
            'manganese': safe_float(nutriments.get('manganese_100g')),
            'selenium': safe_float(nutriments.get('selenium_100g')),
            'iodine': safe_float(nutriments.get('iodine_100g')),
            
            # Scoring systems
            'nova_score': safe_int(nutriments.get('nova-group')) or safe_int(product.get('nova_group')),
            'nutriscore_grade': product.get('nutriscore_grade', '').lower() if product.get('nutriscore_grade') and product.get('nutriscore_grade') != 'unknown' else None,
            'nutriscore_score': safe_int(product.get('nutriscore_score')),
            
            # Additional fields
            'serving_size': product.get('serving_size', '').strip(),
            'countries': parse_array_field(product.get('countries', '')),
            'last_modified': product.get('last_modified_datetime', '').strip(),
            'data_quality': safe_float(product.get('completeness'))
        }
        
        # Remove empty optional fields to save space
        doc = {k: v for k, v in doc.items() if v is not None and v != '' and v != []}
        
        return doc
        
    except Exception as e:
        return None

def upload_batch_to_typesense_upsert(documents):
    """Upload a batch of documents to Typesense using UPSERT (update or create)"""
    if not documents:
        return 0, 0
    
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
        print("Please ensure the file is downloaded to your Downloads folder")
        return False
    
    batch = []
    total_success = 0
    total_errors = 0
    doc_id = 1
    
    print("🔄 Processing data (using UPSERT mode - will update existing and add new)...")
    
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
                # It's a JSON array - load the entire array
                print("📋 Detected JSON array format, loading...")
                data = json.load(file)
                products = data if isinstance(data, list) else [data]
                
                for product in tqdm(products, desc="Processing products"):
                    if MAX_PRODUCTS and (total_success + total_errors) >= MAX_PRODUCTS:
                        break
                    
                    document = convert_json_to_typesense_document(product, doc_id)
                    if document:
                        batch.append(document)
                        doc_id += 1
                        
                        if len(batch) >= BATCH_SIZE:
                            success, errors = upload_batch_to_typesense_upsert(batch)
                            total_success += success
                            total_errors += errors
                            print(f"✅ Processed {total_success + total_errors} products ({total_success} success, {total_errors} errors)")
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
                        document = convert_json_to_typesense_document(product, doc_id)
                        if document:
                            batch.append(document)
                            doc_id += 1
                            
                            if len(batch) >= BATCH_SIZE:
                                success, errors = upload_batch_to_typesense_upsert(batch)
                                total_success += success
                                total_errors += errors
                                if (total_success + total_errors) % 10000 == 0:
                                    print(f"✅ Processed {total_success + total_errors} products ({total_success} success, {total_errors} errors)")
                                batch = []
                                time.sleep(0.05)
                    except json.JSONDecodeError:
                        continue
        
        # Upload remaining documents
        if batch:
            success, errors = upload_batch_to_typesense_upsert(batch)
            total_success += success
            total_errors += errors
        
        print(f"\n🎉 Import completed!")
        print(f"✅ Successfully upserted: {total_success}")
        print(f"❌ Errors: {total_errors}")
        
        # Save metadata
        metadata = {
            'last_update': datetime.now().isoformat(),
            'total_success': total_success,
            'total_errors': total_errors,
            'source_file': JSON_FILE_PATH
        }
        save_import_metadata(metadata)
        
        return True
        
    except Exception as e:
        print(f"❌ Error processing file: {e}")
        import traceback
        traceback.print_exc()
        return False

def check_collection_exists():
    """Check if the foods collection exists"""
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}"
    headers = get_typesense_headers()
    
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            data = response.json()
            print(f"📊 Collection exists with {data.get('num_documents', 0)} documents")
            return True
        else:
            print("❌ Collection does not exist")
            return False
    except Exception as e:
        print(f"❌ Error checking collection: {e}")
        return False

def main():
    """Main update process"""
    print("🚀 Starting Open Food Facts Typesense UPDATE")
    print("📋 This will UPSERT data (update existing, add new) without deleting anything")
    print(f"📁 Source file: {JSON_FILE_PATH}")
    
    # Check if file exists
    if not os.path.exists(JSON_FILE_PATH):
        print(f"\n❌ File not found at: {JSON_FILE_PATH}")
        print("Please ensure the openfoodfacts-products.json.gz file is in your Downloads folder")
        return
    
    # Get file size
    file_size = os.path.getsize(JSON_FILE_PATH) / (1024 * 1024 * 1024)
    print(f"📦 File size: {file_size:.2f} GB")
    
    # Check collection
    print("\n📊 Checking existing collection...")
    check_collection_exists()
    
    # Load previous import metadata
    metadata = load_import_metadata()
    if metadata:
        print(f"📅 Last update: {metadata.get('last_update', 'Unknown')}")
        print(f"📊 Previous import: {metadata.get('total_success', 0)} successful")
    
    # Confirm before proceeding
    response = input("\nContinue with update? (y/N): ")
    if response.lower() != 'y':
        print("❌ Update cancelled")
        return
    
    start_time = time.time()
    
    if process_json_file():
        end_time = time.time()
        duration = end_time - start_time
        hours = int(duration // 3600)
        minutes = int((duration % 3600) // 60)
        seconds = int(duration % 60)
        print(f"\n⏱️  Total time: {hours}h {minutes}m {seconds}s")
        print("✅ Update completed successfully!")
    else:
        print("❌ Update failed")

if __name__ == "__main__":
    main()
