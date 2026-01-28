#!/usr/bin/env python3
"""
Open Food Facts Incremental Update for Typesense
Updates the Typesense foods collection with new/modified products from Open Food Facts delta files.
Uses upsert mode to add new products without deleting existing ones.
"""

import os
import json
import time
import requests
import gzip
from tqdm import tqdm
from datetime import datetime, timezone, timedelta

# Typesense configuration
TYPESENSE_CONFIG = {
    'api_url': 'https://h8ugnjal1c65sm2op-1.a1.typesense.net',
    'admin_api_key': 'iCrX1bLheI7cTr2USV764ElrD3dG3lL3',
    'collection_name': 'foods'
}

# Metadata file to track last import
METADATA_FILE = "typesense_import_metadata.json"
BATCH_SIZE = 1000

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

def get_available_delta_files():
    """Get list of available delta files from Open Food Facts"""
    try:
        response = requests.get("https://static.openfoodfacts.org/data/delta/index.txt")
        if response.status_code == 200:
            files = [line.strip() for line in response.text.strip().split('\n') if line.strip()]
            return files
        else:
            print(f"❌ Error fetching delta index: {response.status_code}")
            return []
    except Exception as e:
        print(f"❌ Error fetching delta files: {e}")
        return []

def parse_delta_filename(filename):
    """Parse delta filename to extract timestamps"""
    # Format: products.{start_timestamp}.{end_timestamp}.json.gz
    try:
        parts = filename.replace('.json.gz', '').split('.')
        if len(parts) >= 3:
            start_ts = int(parts[-2])
            end_ts = int(parts[-1])
            return start_ts, end_ts
    except:
        pass
    return None, None

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

def convert_product_to_typesense(product):
    """Convert Open Food Facts product to Typesense document"""
    try:
        # Get product name
        name = product.get('product_name', '').strip()
        if not name and 'product_name_en' in product:
            name = product.get('product_name_en', '').strip()
        if not name:
            return None
        
        # Use Open Food Facts _id as primary identifier (most reliable)
        # Falls back to barcode if _id not available
        off_id = product.get('_id', '').strip()
        barcode = product.get('code', '').strip()
        
        # Prefer _id, then barcode - need at least one
        doc_id = off_id if off_id else barcode
        if not doc_id:
            return None
        
        nutriments = product.get('nutriments', {})
        
        doc = {
            'id': doc_id,  # Use OFF _id or barcode as unique ID for upserts
            'name': name,
            'brand': product.get('brands', '').strip(),
            'barcode': barcode,
            'categories': parse_array_field(product.get('categories', '')),
            'ingredients': parse_array_field(product.get('ingredients_text', '')),
            'allergens': parse_array_field(product.get('allergens', '')),
            
            # Macronutrients
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
            
            # Vitamins
            'vitamin_a': safe_float(nutriments.get('vitamin-a_100g')),
            'vitamin_d': safe_float(nutriments.get('vitamin-d_100g')),
            'vitamin_e': safe_float(nutriments.get('vitamin-e_100g')),
            'vitamin_k': safe_float(nutriments.get('vitamin-k_100g')),
            'vitamin_c': safe_float(nutriments.get('vitamin-c_100g')),
            'vitamin_b1': safe_float(nutriments.get('vitamin-b1_100g')),
            'vitamin_b2': safe_float(nutriments.get('vitamin-b2_100g')),
            'vitamin_b3': safe_float(nutriments.get('vitamin-pp_100g')),
            'vitamin_b5': safe_float(nutriments.get('pantothenic-acid_100g')),
            'vitamin_b6': safe_float(nutriments.get('vitamin-b6_100g')),
            'vitamin_b7': safe_float(nutriments.get('biotin_100g')),
            'vitamin_b9': safe_float(nutriments.get('folates_100g')),
            'vitamin_b12': safe_float(nutriments.get('vitamin-b12_100g')),
            
            # Minerals
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
            
            # Scores
            'nova_score': safe_int(nutriments.get('nova-group')) or safe_int(product.get('nova_group')),
            'nutriscore_grade': product.get('nutriscore_grade', '').lower() if product.get('nutriscore_grade') and product.get('nutriscore_grade') != 'unknown' else None,
            'nutriscore_score': safe_int(product.get('nutriscore_score')),
            
            # Additional fields
            'serving_size': product.get('serving_size', '').strip(),
            'countries': parse_array_field(product.get('countries', '')),
            'last_modified': product.get('last_modified_datetime', '').strip(),
            'data_quality': safe_float(product.get('completeness'))
        }
        
        # Remove empty fields
        doc = {k: v for k, v in doc.items() if v is not None and v != '' and v != []}
        
        return doc
        
    except Exception as e:
        return None

def download_and_process_delta_file(filename):
    """Download and process a single delta file"""
    url = f"https://static.openfoodfacts.org/data/delta/{filename}"
    
    try:
        print(f"📥 Downloading {filename}...")
        response = requests.get(url, timeout=60)
        if response.status_code != 200:
            print(f"❌ Error downloading {filename}: {response.status_code}")
            return []
        
        # Decompress and parse JSON
        decompressed = gzip.decompress(response.content)
        products = []
        
        # Each line is a JSON object
        for line in decompressed.decode('utf-8').strip().split('\n'):
            if line.strip():
                try:
                    product = json.loads(line)
                    converted = convert_product_to_typesense(product)
                    if converted:
                        products.append(converted)
                except json.JSONDecodeError:
                    continue
        
        print(f"✅ Processed {len(products)} valid products from {filename}")
        return products
        
    except Exception as e:
        print(f"❌ Error processing {filename}: {e}")
        return []

def upsert_to_typesense(documents):
    """Upsert documents to Typesense (insert or update)"""
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
            print(f"❌ Error upserting batch: {response.status_code}")
            print(response.text[:300])
            return 0
    except Exception as e:
        print(f"❌ Exception upserting batch: {e}")
        return 0

def run_incremental_update():
    """Run incremental update using delta files"""
    print("\n🔄 Starting incremental update from Open Food Facts...")
    
    # Get current collection stats
    current_count = get_collection_info()
    print(f"📊 Current collection has {current_count:,} documents")
    
    # Load last import metadata
    metadata = load_import_metadata()
    last_import = metadata.get('last_import_date')
    
    if last_import:
        print(f"📅 Last update: {last_import}")
    else:
        print("📅 No previous incremental update found")
        # If no metadata, use 14 days ago as default
        last_import = (datetime.now(timezone.utc) - timedelta(days=14)).isoformat()
        print(f"📅 Using default: {last_import}")
    
    # Get available delta files
    delta_files = get_available_delta_files()
    if not delta_files:
        print("❌ No delta files available from Open Food Facts")
        return
    
    print(f"📁 Found {len(delta_files)} delta files available")
    
    # Parse last import timestamp
    try:
        last_import_dt = datetime.fromisoformat(last_import.replace('Z', '+00:00'))
        last_import_ts = int(last_import_dt.timestamp())
    except:
        # Default to 14 days ago
        last_import_ts = int((datetime.now(timezone.utc) - timedelta(days=14)).timestamp())
    
    # Filter delta files newer than last import
    relevant_files = []
    for filename in delta_files:
        start_ts, end_ts = parse_delta_filename(filename)
        if start_ts and start_ts > last_import_ts:
            relevant_files.append((filename, start_ts, end_ts))
    
    if not relevant_files:
        print("✅ No new updates available - database is up to date!")
        return
    
    # Sort by timestamp
    relevant_files.sort(key=lambda x: x[1])
    print(f"\n📥 Found {len(relevant_files)} delta files with new data to process")
    
    total_products = 0
    total_uploaded = 0
    latest_timestamp = last_import_ts
    
    # Process each delta file
    for i, (filename, start_ts, end_ts) in enumerate(relevant_files):
        print(f"\n--- Processing file {i+1}/{len(relevant_files)} ---")
        products = download_and_process_delta_file(filename)
        
        if products:
            # Upload in batches
            for j in range(0, len(products), BATCH_SIZE):
                batch = products[j:j + BATCH_SIZE]
                uploaded = upsert_to_typesense(batch)
                total_uploaded += uploaded
                
            total_products += len(products)
            latest_timestamp = max(latest_timestamp, end_ts)
        
        time.sleep(0.5)  # Rate limiting between files
    
    # Update metadata
    updated_metadata = {
        'last_import_date': datetime.now(timezone.utc).isoformat(),
        'last_incremental_update': datetime.now(timezone.utc).isoformat(),
        'products_processed': total_products,
        'products_uploaded': total_uploaded,
        'latest_delta_timestamp': latest_timestamp,
        'delta_files_processed': len(relevant_files)
    }
    save_import_metadata(updated_metadata)
    
    # Get updated stats
    new_count = get_collection_info()
    
    print(f"\n{'='*50}")
    print(f"✅ Incremental update completed!")
    print(f"📊 Products processed: {total_products:,}")
    print(f"📤 Products uploaded/updated: {total_uploaded:,}")
    print(f"📁 Delta files processed: {len(relevant_files)}")
    print(f"📈 Collection size: {current_count:,} → {new_count:,} ({new_count - current_count:+,})")
    print(f"💾 Metadata saved to {METADATA_FILE}")
    print(f"{'='*50}")

if __name__ == "__main__":
    print("🚀 Open Food Facts → Typesense Incremental Update")
    print("=" * 50)
    
    # Show what we're about to do
    print("\nThis script will:")
    print("1. Check for new delta files from Open Food Facts")
    print("2. Download and process only new/updated products")
    print("3. Upsert them to your Typesense collection")
    print("4. Track the update timestamp for future runs")
    print("\n⚠️  This will NOT delete any existing products")
    
    response = input("\nContinue? (y/N): ")
    if response.lower() != 'y':
        print("❌ Update cancelled")
        exit(1)
    
    start_time = time.time()
    run_incremental_update()
    end_time = time.time()
    
    print(f"\n⏱️  Total time: {end_time - start_time:.1f} seconds")
    print("✅ Done!")
