#!/usr/bin/env python3
"""
Open Food Facts Full Import to Typesense - Version 2
Complete reimport with stable IDs for future incremental updates.
Matches all fields expected by the Nutribase iOS app.

Required fields for app compatibility:
- id (stable: barcode or OFF _id)
- name, brand, barcode
- calories, protein, carbohydrates, fat
- fiber, sugar, sodium, saturated_fat
- nova_score, nutriscore_grade, nutriscore_score
- serving_size, serving_unit
- countries (for region filtering)
- ingredients (for NOVA prediction)
- categories, allergens
- last_modified
"""

import os
import json
import time
import requests
import gzip
from tqdm import tqdm
from datetime import datetime, timezone

# Typesense configuration
TYPESENSE_CONFIG = {
    'api_url': 'https://h8ugnjal1c65sm2op-1.a1.typesense.net',
    'admin_api_key': 'iCrX1bLheI7cTr2USV764ElrD3dG3lL3',
    'collection_name': 'foods'
}

# File path - download from https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz
JSONL_FILE_PATH = os.path.expanduser("~/Downloads/openfoodfacts-products.jsonl.gz")

# Import configuration
BATCH_SIZE = 10000  # Larger batches for faster import
MAX_PRODUCTS = None  # Set to a number for testing, None for full import

# Metadata file for tracking imports
METADATA_FILE = "typesense_import_metadata.json"

def get_typesense_headers():
    """Get headers for Typesense API requests"""
    return {
        'Content-Type': 'application/json',
        'X-TYPESENSE-API-KEY': TYPESENSE_CONFIG['admin_api_key']
    }

def get_collection_info():
    """Get current collection statistics"""
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}"
    headers = get_typesense_headers()
    
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            info = response.json()
            return info.get('num_documents', 0)
    except Exception as e:
        print(f"❌ Error getting collection info: {e}")
    return 0

def delete_existing_collection():
    """Delete the existing foods collection"""
    print("🗑️  Deleting existing collection...")
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}"
    headers = get_typesense_headers()
    
    try:
        response = requests.delete(url, headers=headers)
        if response.status_code in [200, 404]:
            print("✅ Existing collection deleted (or didn't exist)")
            return True
        else:
            print(f"❌ Error deleting collection: {response.status_code}")
            print(response.text)
            return False
    except Exception as e:
        print(f"❌ Exception deleting collection: {e}")
        return False

def create_collection_schema():
    """Create collection schema matching app requirements"""
    print("📋 Creating collection schema...")
    
    schema = {
        "name": TYPESENSE_CONFIG['collection_name'],
        "fields": [
            # Core identification (id uses barcode for stable upserts)
            {"name": "id", "type": "string"},
            {"name": "name", "type": "string"},
            {"name": "brand", "type": "string", "optional": True},
            {"name": "barcode", "type": "string", "optional": True, "index": True},
            
            # Macronutrients (per 100g) - REQUIRED by app
            {"name": "calories", "type": "float", "optional": True},
            {"name": "protein", "type": "float", "optional": True},
            {"name": "carbohydrates", "type": "float", "optional": True},
            {"name": "fat", "type": "float", "optional": True},
            
            # Micronutrients (per 100g) - used by app
            {"name": "fiber", "type": "float", "optional": True},
            {"name": "sugar", "type": "float", "optional": True},
            {"name": "sodium", "type": "float", "optional": True},
            {"name": "saturated_fat", "type": "float", "optional": True},
            {"name": "cholesterol", "type": "float", "optional": True},
            {"name": "trans_fat", "type": "float", "optional": True},
            
            # Scoring systems - REQUIRED by app
            {"name": "nova_score", "type": "int32", "optional": True},
            {"name": "nutriscore_grade", "type": "string", "optional": True},
            {"name": "nutriscore_score", "type": "int32", "optional": True},
            
            # Serving information - used by app
            {"name": "serving_size", "type": "string", "optional": True},
            {"name": "serving_unit", "type": "string", "optional": True},
            
            # Region/location - REQUIRED for region filtering
            {"name": "countries", "type": "string[]", "optional": True},
            {"name": "purchase_places", "type": "string", "optional": True},
            {"name": "origins", "type": "string", "optional": True},
            
            # Ingredients and categories
            {"name": "ingredients", "type": "string[]", "optional": True},
            {"name": "ingredients_text", "type": "string", "optional": True},
            {"name": "categories", "type": "string[]", "optional": True},
            {"name": "allergens", "type": "string[]", "optional": True},
            
            # Vitamins (per 100g) - for future expansion
            {"name": "vitamin_a", "type": "float", "optional": True},
            {"name": "vitamin_c", "type": "float", "optional": True},
            {"name": "vitamin_d", "type": "float", "optional": True},
            {"name": "vitamin_e", "type": "float", "optional": True},
            {"name": "vitamin_k", "type": "float", "optional": True},
            {"name": "vitamin_b1", "type": "float", "optional": True},
            {"name": "vitamin_b2", "type": "float", "optional": True},
            {"name": "vitamin_b3", "type": "float", "optional": True},
            {"name": "vitamin_b5", "type": "float", "optional": True},
            {"name": "vitamin_b6", "type": "float", "optional": True},
            {"name": "vitamin_b7", "type": "float", "optional": True},
            {"name": "vitamin_b9", "type": "float", "optional": True},
            {"name": "vitamin_b12", "type": "float", "optional": True},
            
            # Minerals (per 100g) - for future expansion
            {"name": "calcium", "type": "float", "optional": True},
            {"name": "iron", "type": "float", "optional": True},
            {"name": "magnesium", "type": "float", "optional": True},
            {"name": "phosphorus", "type": "float", "optional": True},
            {"name": "potassium", "type": "float", "optional": True},
            {"name": "zinc", "type": "float", "optional": True},
            {"name": "copper", "type": "float", "optional": True},
            {"name": "manganese", "type": "float", "optional": True},
            {"name": "selenium", "type": "float", "optional": True},
            {"name": "iodine", "type": "float", "optional": True},
            
            # Metadata
            {"name": "last_modified", "type": "string", "optional": True},
            {"name": "data_quality", "type": "float", "optional": True}
        ]
    }
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections"
    headers = get_typesense_headers()
    
    try:
        response = requests.post(url, headers=headers, json=schema)
        if response.status_code == 201:
            print("✅ Collection schema created successfully")
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

def convert_product_to_typesense(product):
    """Convert Open Food Facts product to Typesense document"""
    try:
        # Get product name (required)
        name = product.get('product_name', '').strip()
        if not name:
            name = product.get('product_name_en', '').strip()
        if not name:
            return None
        
        # Get stable ID: prefer barcode, fallback to OFF _id
        barcode = product.get('code', '').strip()
        off_id = product.get('_id', '').strip()
        stable_id = barcode if barcode else off_id
        if not stable_id:
            return None  # Must have an ID
        
        # Get nutriments
        nutriments = product.get('nutriments', {})
        
        # Build document with all fields the app expects
        doc = {
            # Core identification
            'id': stable_id,
            'name': name,
            'brand': product.get('brands', '').strip(),
            'barcode': barcode,
            
            # Macronutrients (per 100g)
            'calories': safe_float(nutriments.get('energy-kcal_100g')),
            'protein': safe_float(nutriments.get('proteins_100g')),
            'carbohydrates': safe_float(nutriments.get('carbohydrates_100g')),
            'fat': safe_float(nutriments.get('fat_100g')),
            
            # Micronutrients (per 100g)
            'fiber': safe_float(nutriments.get('fiber_100g')),
            'sugar': safe_float(nutriments.get('sugars_100g')),
            'sodium': safe_float(nutriments.get('sodium_100g')),
            'saturated_fat': safe_float(nutriments.get('saturated-fat_100g')),
            'cholesterol': safe_float(nutriments.get('cholesterol_100g')),
            'trans_fat': safe_float(nutriments.get('trans-fat_100g')),
            
            # Scoring systems
            'nova_score': safe_int(nutriments.get('nova-group')) or safe_int(product.get('nova_group')),
            'nutriscore_grade': product.get('nutriscore_grade', '').lower() if product.get('nutriscore_grade') and product.get('nutriscore_grade') not in ['unknown', 'not-applicable'] else None,
            'nutriscore_score': safe_int(product.get('nutriscore_score')) if product.get('nutriscore_score') else None,
            
            # Serving information
            'serving_size': product.get('serving_size', '').strip(),
            'serving_unit': product.get('serving_quantity', ''),
            
            # Region/location for filtering
            'countries': parse_array_field(product.get('countries', '')),
            'purchase_places': product.get('purchase_places', '').strip(),
            'origins': product.get('origins', '').strip(),
            
            # Ingredients and categories
            'ingredients': parse_array_field(product.get('ingredients_text', '')),
            'ingredients_text': product.get('ingredients_text', '').strip(),
            'categories': parse_array_field(product.get('categories', '')),
            'allergens': parse_array_field(product.get('allergens', '')),
            
            # Vitamins (per 100g)
            'vitamin_a': safe_float(nutriments.get('vitamin-a_100g')),
            'vitamin_c': safe_float(nutriments.get('vitamin-c_100g')),
            'vitamin_d': safe_float(nutriments.get('vitamin-d_100g')),
            'vitamin_e': safe_float(nutriments.get('vitamin-e_100g')),
            'vitamin_k': safe_float(nutriments.get('vitamin-k_100g')),
            'vitamin_b1': safe_float(nutriments.get('vitamin-b1_100g')),
            'vitamin_b2': safe_float(nutriments.get('vitamin-b2_100g')),
            'vitamin_b3': safe_float(nutriments.get('vitamin-pp_100g')),  # Niacin
            'vitamin_b5': safe_float(nutriments.get('pantothenic-acid_100g')),
            'vitamin_b6': safe_float(nutriments.get('vitamin-b6_100g')),
            'vitamin_b7': safe_float(nutriments.get('biotin_100g')),
            'vitamin_b9': safe_float(nutriments.get('folates_100g')),
            'vitamin_b12': safe_float(nutriments.get('vitamin-b12_100g')),
            
            # Minerals (per 100g)
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
            
            # Metadata
            'last_modified': product.get('last_modified_datetime', '').strip(),
            'data_quality': safe_float(product.get('completeness'))
        }
        
        # Remove empty/zero fields to save space (keep required fields)
        required_fields = {'id', 'name'}
        doc = {k: v for k, v in doc.items() if k in required_fields or (v is not None and v != '' and v != [] and v != 0 and v != 0.0)}
        
        # Always include id and name
        doc['id'] = stable_id
        doc['name'] = name
        
        return doc
        
    except Exception as e:
        return None

def upload_batch_to_typesense(documents):
    """Upload a batch of documents to Typesense"""
    if not documents:
        return 0
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}/documents/import?action=upsert"
    headers = get_typesense_headers()
    headers['Content-Type'] = 'text/plain'
    
    # Convert to JSONL
    jsonl_data = '\n'.join([json.dumps(doc) for doc in documents])
    
    try:
        response = requests.post(url, headers=headers, data=jsonl_data, timeout=120)
        if response.status_code == 200:
            # Count successful imports
            results = response.text.strip().split('\n')
            successful = sum(1 for r in results if '"success":true' in r)
            return successful
        else:
            print(f"❌ Error uploading batch: {response.status_code}")
            print(response.text[:500])
            return 0
    except Exception as e:
        print(f"❌ Exception uploading batch: {e}")
        return 0

def save_import_metadata(metadata):
    """Save import metadata for future incremental updates"""
    with open(METADATA_FILE, 'w') as f:
        json.dump(metadata, f, indent=2)
    print(f"💾 Metadata saved to {METADATA_FILE}")

def process_jsonl_file():
    """Process the JSONL file and import to Typesense"""
    print(f"\n📁 Processing JSONL file: {JSONL_FILE_PATH}")
    
    if not os.path.exists(JSONL_FILE_PATH):
        print(f"❌ Error: JSONL file not found at {JSONL_FILE_PATH}")
        print("\n📥 Please download the file from:")
        print("   https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz")
        print(f"\n   Save it to: {JSONL_FILE_PATH}")
        return False, 0
    
    batch = []
    total_imported = 0
    total_processed = 0
    errors = 0
    
    print("🔄 Processing products...")
    
    try:
        # Handle gzipped file
        if JSONL_FILE_PATH.endswith('.gz'):
            file_handle = gzip.open(JSONL_FILE_PATH, 'rt', encoding='utf-8')
        else:
            file_handle = open(JSONL_FILE_PATH, 'r', encoding='utf-8')
        
        with file_handle as file:
            for line in tqdm(file, desc="Processing products", unit=" products"):
                if MAX_PRODUCTS and total_imported >= MAX_PRODUCTS:
                    print(f"\n⚠️  Reached MAX_PRODUCTS limit ({MAX_PRODUCTS})")
                    break
                
                total_processed += 1
                
                try:
                    product = json.loads(line.strip())
                    document = convert_product_to_typesense(product)
                    
                    if document:
                        batch.append(document)
                        
                        # Upload batch when full
                        if len(batch) >= BATCH_SIZE:
                            uploaded = upload_batch_to_typesense(batch)
                            total_imported += uploaded
                            if uploaded < len(batch):
                                errors += len(batch) - uploaded
                            batch = []
                            
                            # Progress update every 10k products
                            if total_imported % 10000 == 0:
                                print(f"   📊 Progress: {total_imported:,} imported")
                            
                            time.sleep(0.05)  # Small delay to prevent rate limiting
                            
                except json.JSONDecodeError:
                    continue
                except Exception as e:
                    errors += 1
                    continue
            
            # Upload remaining batch
            if batch:
                uploaded = upload_batch_to_typesense(batch)
                total_imported += uploaded
                if uploaded < len(batch):
                    errors += len(batch) - uploaded
        
        return True, total_imported
        
    except Exception as e:
        print(f"❌ Error processing file: {e}")
        return False, total_imported

def main():
    """Main import process"""
    print("=" * 60)
    print("🚀 Open Food Facts → Typesense Full Import (v2)")
    print("=" * 60)
    
    # Show what we're about to do
    print("\nThis script will:")
    print("  1. Create a new 'foods' collection with the correct schema")
    print("  2. Import ALL products from Open Food Facts")
    print("  3. Use stable IDs (barcode) for future incremental updates")
    print(f"\n📦 Batch size: {BATCH_SIZE:,} products per batch")
    print(f"📁 Source file: {JSONL_FILE_PATH}")
    
    # Check if file exists
    if not os.path.exists(JSONL_FILE_PATH):
        print(f"\n❌ Source file not found!")
        print(f"\n📥 Please download it first:")
        print(f"   curl -o ~/Documents/openfoodfacts-products.jsonl.gz \\")
        print(f"        https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz")
        return
    
    # Get current stats
    current_count = get_collection_info()
    print(f"\n📊 Current collection has {current_count:,} documents")
    
    response = input("\nContinue with full reimport? (y/N): ")
    if response.lower() != 'y':
        print("❌ Import cancelled")
        return
    
    start_time = time.time()
    
    # Step 1: Create new schema (collection already deleted by user)
    if not create_collection_schema():
        print("❌ Failed to create collection schema")
        return
    
    time.sleep(1)  # Wait for schema creation
    
    # Step 3: Import data
    success, total_imported = process_jsonl_file()
    
    end_time = time.time()
    elapsed_time = end_time - start_time
    
    # Step 4: Save metadata for future incremental updates
    metadata = {
        'last_import_date': datetime.now(timezone.utc).isoformat(),
        'import_type': 'full',
        'total_products_imported': total_imported,
        'source_file': JSONL_FILE_PATH,
        'elapsed_time_seconds': elapsed_time
    }
    save_import_metadata(metadata)
    
    # Final stats
    new_count = get_collection_info()
    
    print("\n" + "=" * 60)
    print("✅ IMPORT COMPLETED!")
    print("=" * 60)
    print(f"📊 Products imported: {total_imported:,}")
    print(f"📈 Collection size: {new_count:,}")
    print(f"⏱️  Total time: {elapsed_time/60:.1f} minutes")
    print(f"⚡ Speed: {total_imported/elapsed_time:.0f} products/second")
    print("\n💡 Future incremental updates will now work correctly!")
    print("   Run: python3 update_typesense_incremental.py")
    print("=" * 60)

if __name__ == "__main__":
    main()
