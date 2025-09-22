#!/usr/bin/env python3
"""
Open Food Facts Incremental Import (for future updates)
This script uses delta files or timestamp filtering for incremental updates.
Only run this AFTER you've done the initial full import with tracking.
"""

import os
import json
import time
import requests
from tqdm import tqdm
from datetime import datetime, timezone, timedelta
import gzip

# Supabase configuration
SUPABASE_URL = "https://owmwxzkzqrbhhiofzgmm.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93bXd4emt6cXJiaGhpb2Z6Z21tIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzI0MjEwMiwiZXhwIjoyMDYyODE4MTAyfQ.5XKQo-XEWaRXVUPP4wdRj5W-KA9vluuZJPtwIknJo4k"

# Metadata file to track last import
METADATA_FILE = "last_import_metadata.json"
BATCH_SIZE = 50

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

def download_and_process_delta_file(filename):
    """Download and process a single delta file"""
    url = f"https://static.openfoodfacts.org/data/delta/{filename}"
    
    try:
        print(f"📥 Downloading {filename}...")
        response = requests.get(url)
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
                    converted = convert_mongodb_to_food_item(product)
                    if converted:
                        products.append(converted)
                except json.JSONDecodeError:
                    continue
        
        print(f"✅ Processed {len(products)} products from {filename}")
        return products
        
    except Exception as e:
        print(f"❌ Error processing {filename}: {e}")
        return []

def convert_mongodb_to_food_item(product):
    """Convert MongoDB product to Supabase food item format"""
    try:
        # Extract basic information
        name = product.get('product_name', '')
        if not name and 'product_name_en' in product:
            name = product.get('product_name_en', '')
        
        if not name:
            return None
            
        code = product.get('code', '')
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
                'calories': int(nutriments.get('energy-kcal_100g', 0)) if nutriments.get('energy-kcal_100g') else 0,
                'protein': float(nutriments.get('proteins_100g', 0)) if nutriments.get('proteins_100g') else 0.0,
                'carbohydrates': float(nutriments.get('carbohydrates_100g', 0)) if nutriments.get('carbohydrates_100g') else 0.0,
                'fat': float(nutriments.get('fat_100g', 0)) if nutriments.get('fat_100g') else 0.0,
                'sodium': float(nutriments.get('sodium_100g', 0)) if nutriments.get('sodium_100g') else 0.0,
                'sugar': float(nutriments.get('sugars_100g', 0)) if nutriments.get('sugars_100g') else 0.0,
                'saturated_fat': float(nutriments.get('saturated-fat_100g', 0)) if nutriments.get('saturated-fat_100g') else 0.0,
                'serving_size': product.get('serving_size', ''),
                'servings_per_package': None
            }
        
        # Extract ingredients
        ingredients_array = []
        if 'ingredients_text' in product and product['ingredients_text']:
            ingredients_text = product['ingredients_text']
            ingredients_array = [i.strip() for i in ingredients_text.split(',') if i.strip()]
        
        # Extract Nutri-Score data
        nutriscore_score = None
        nutriscore_grade = None
        
        if 'nutriscore_score' in product and product['nutriscore_score']:
            try:
                nutriscore_score = int(float(product['nutriscore_score']))
            except (ValueError, TypeError):
                pass
                
        if 'nutriscore_grade' in product and product['nutriscore_grade'] and product['nutriscore_grade'] != 'unknown':
            nutriscore_grade = product['nutriscore_grade'].lower()
            if nutriscore_grade not in ['a', 'b', 'c', 'd', 'e']:
                nutriscore_grade = None
        
        # Get last modified timestamp
        last_modified = product.get('last_modified_t')
        if last_modified:
            # Convert Unix timestamp to ISO format
            last_modified = datetime.fromtimestamp(last_modified, timezone.utc).isoformat()
        
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
            'source': 'open_food_facts',
            'last_modified_off': last_modified
        }
        
        return food_item
    except Exception as e:
        print(f"Error converting product: {e}")
        return None

def upload_to_supabase(food_items):
    """Upload food items to Supabase using upsert"""
    if not food_items:
        return True
        
    endpoint = f"{SUPABASE_URL}/rest/v1/foods"
    
    headers = {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_KEY,
        'Authorization': f'Bearer {SUPABASE_KEY}',
        'Prefer': 'resolution=merge-duplicates'
    }
    
    # Process in batches
    batches = [food_items[i:i + BATCH_SIZE] for i in range(0, len(food_items), BATCH_SIZE)]
    successful_uploads = 0
    
    for i, batch in enumerate(batches):
        try:
            response = requests.post(endpoint, headers=headers, json=batch)
            if response.status_code == 201:
                successful_uploads += len(batch)
                print(f"✅ Batch {i+1}/{len(batches)} uploaded successfully")
            else:
                print(f"❌ Batch {i+1} failed: {response.status_code}")
                print(response.text[:200])
            
            time.sleep(0.5)  # Rate limiting
            
        except Exception as e:
            print(f"❌ Error uploading batch {i+1}: {e}")
    
    return successful_uploads > 0

def run_incremental_update():
    """Run incremental update using delta files"""
    print("🔄 Starting incremental update...")
    
    # Load last import metadata
    metadata = load_import_metadata()
    if not metadata:
        print("❌ No previous import found. Please run full import first.")
        return
    
    last_import = metadata.get('last_import_date')
    print(f"📅 Last import: {last_import}")
    
    # Get available delta files
    delta_files = get_available_delta_files()
    if not delta_files:
        print("❌ No delta files available")
        return
    
    print(f"📁 Found {len(delta_files)} delta files")
    
    # Parse last import timestamp
    try:
        last_import_dt = datetime.fromisoformat(last_import.replace('Z', '+00:00'))
        last_import_ts = int(last_import_dt.timestamp())
    except:
        print("❌ Invalid last import timestamp")
        return
    
    # Filter delta files that are newer than last import
    relevant_files = []
    for filename in delta_files:
        start_ts, end_ts = parse_delta_filename(filename)
        if start_ts and start_ts > last_import_ts:
            relevant_files.append((filename, start_ts, end_ts))
    
    if not relevant_files:
        print("✅ No new updates available")
        return
    
    # Sort by timestamp
    relevant_files.sort(key=lambda x: x[1])
    print(f"📥 Processing {len(relevant_files)} delta files...")
    
    total_products = 0
    latest_timestamp = last_import_ts
    
    # Process each delta file
    for filename, start_ts, end_ts in relevant_files:
        products = download_and_process_delta_file(filename)
        if products:
            if upload_to_supabase(products):
                total_products += len(products)
                latest_timestamp = max(latest_timestamp, end_ts)
        
        time.sleep(1)  # Rate limiting between files
    
    # Update metadata
    if total_products > 0:
        updated_metadata = metadata.copy()
        updated_metadata.update({
            'last_import_date': datetime.now(timezone.utc).isoformat(),
            'last_incremental_update': datetime.now(timezone.utc).isoformat(),
            'products_updated_incremental': total_products,
            'latest_delta_timestamp': latest_timestamp
        })
        save_import_metadata(updated_metadata)
        
        print(f"✅ Incremental update completed!")
        print(f"📊 Products updated: {total_products}")
    else:
        print("⚠️  No products were updated")

if __name__ == "__main__":
    print("🚀 Starting Open Food Facts incremental update...")
    
    # Check if we have previous import metadata
    metadata = load_import_metadata()
    if not metadata:
        print("❌ No previous import found.")
        print("Please run 'import_openfoodfacts_with_tracking.py' first to do a full import.")
        exit(1)
    
    # Check if last import was recent enough for delta files
    last_import = metadata.get('last_import_date')
    if last_import:
        try:
            last_import_dt = datetime.fromisoformat(last_import.replace('Z', '+00:00'))
            days_ago = (datetime.now(timezone.utc) - last_import_dt).days
            
            if days_ago > 14:
                print(f"⚠️  Last import was {days_ago} days ago.")
                print("Delta files are only available for the last 14 days.")
                print("You may need to run a full import instead.")
                
                response = input("Continue with incremental update anyway? (y/N): ")
                if response.lower() != 'y':
                    print("❌ Update cancelled.")
                    exit(1)
        except:
            pass
    
    run_incremental_update()
    print("✅ Done!")
