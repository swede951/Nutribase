#!/usr/bin/env python3
"""
Optimized Open Food Facts to Typesense Import Script
Only imports essential fields to reduce database size by ~57%
"""

import os
import json
import requests
from tqdm import tqdm
import time
import gzip
from datetime import datetime
from data_cleaning import FoodDataCleaner

# Typesense configuration
TYPESENSE_CONFIG = {
    'api_url': 'https://h8ugnjal1c65sm2op-1.a1.typesense.net',
    'admin_api_key': 'iCrX1bLheI7cTr2USV764ElrD3dG3lL3',
    'collection_name': 'foods'  # Replace existing collection
}

# JSONL file path
JSONL_FILE_PATH = os.path.expanduser("~/Downloads/openfoodfacts-products.jsonl.gz")

# Import configuration
BATCH_SIZE = 10000  # Very large batch size for fastest imports
MAX_PRODUCTS = None  # Set to None to import all products

def get_typesense_headers():
    """Get headers for Typesense API requests"""
    return {
        'Content-Type': 'application/json',
        'X-TYPESENSE-API-KEY': TYPESENSE_CONFIG['admin_api_key']
    }

def delete_existing_collection():
    """Delete the existing foods collection to free up space"""
    print("🗑️  Deleting existing collection to free up memory...")
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}"
    headers = get_typesense_headers()
    
    try:
        response = requests.delete(url, headers=headers)
        if response.status_code in [200, 404]:  # 404 means collection doesn't exist
            print("✅ Existing collection deleted successfully")
            return True
        else:
            print(f"❌ Error deleting collection: {response.status_code}")
            print(response.text)
            return False
    except Exception as e:
        print(f"❌ Exception deleting collection: {e}")
        return False

def create_optimized_collection_schema():
    """Create optimized collection schema with only essential fields"""
    print("📋 Creating optimized collection schema...")
    
    schema = {
        "name": TYPESENSE_CONFIG['collection_name'],
        "fields": [
            # Essential fields
            {"name": "id", "type": "string"},
            {"name": "name", "type": "string"},
            {"name": "brand", "type": "string", "optional": True},
            {"name": "barcode", "type": "string", "optional": True, "index": True},
            
            # Core nutrients (most important for nutrition tracking)
            {"name": "calories", "type": "float", "optional": True},
            {"name": "protein", "type": "float", "optional": True},
            {"name": "carbohydrates", "type": "float", "optional": True},
            {"name": "fat", "type": "float", "optional": True},
            {"name": "saturated_fat", "type": "float", "optional": True},
            {"name": "fiber", "type": "float", "optional": True},
            {"name": "sugar", "type": "float", "optional": True},
            {"name": "sodium", "type": "float", "optional": True},
            
            # Useful metadata
            {"name": "categories", "type": "string[]", "optional": True},
            {"name": "ingredients", "type": "string[]", "optional": True},
            {"name": "allergens", "type": "string[]", "optional": True},
            {"name": "serving_size", "type": "string", "optional": True},
            {"name": "countries", "type": "string[]", "optional": True},
            
            # Quality scores
            {"name": "nova_score", "type": "int32", "optional": True},
            {"name": "nutriscore_grade", "type": "string", "optional": True},
            {"name": "nutriscore_score", "type": "int32", "optional": True},
            
            # NOVA estimation fields (Step 2.5)
            {"name": "nova_estimated", "type": "int32", "optional": True},
            {"name": "nova_source", "type": "string", "optional": True, "facet": True},
            {"name": "nova_confidence", "type": "float", "optional": True},
            {"name": "nova_final", "type": "int32", "optional": True, "facet": True},  # nova_score ?? nova_estimated
            
            # Additional fields for estimation
            {"name": "ingredients_text", "type": "string", "optional": True},  # Joined ingredients for search
            {"name": "serving_unit", "type": "string", "optional": True},  # Derived from serving_size
            
            # Step 1: Correctness fields
            {"name": "country_codes", "type": "string[]", "optional": True, "facet": True},
            
            # Step 2: Smart fields
            {"name": "name_norm", "type": "string", "optional": True},
            {"name": "brand_norm", "type": "string", "optional": True},
            {"name": "food_kind", "type": "string", "optional": True, "facet": True},
            {"name": "is_generic", "type": "bool", "optional": True, "facet": True},
            {"name": "quality_score", "type": "int32"},
            {"name": "popularity", "type": "int32", "optional": True},
            {"name": "source", "type": "string", "optional": True, "facet": True}
        ],
        "default_sorting_field": "quality_score"
    }
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections"
    headers = get_typesense_headers()
    
    try:
        response = requests.post(url, headers=headers, json=schema)
        if response.status_code == 201:
            print("✅ Optimized collection schema created successfully")
            print(f"📊 Schema has {len(schema['fields'])} fields (vs 46 in original)")
            return True
        else:
            print(f"❌ Error creating collection: {response.status_code}")
            print(response.text)
            return False
    except Exception as e:
        print(f"❌ Exception creating collection: {e}")
        return False

# Removed safe_float and safe_int - now handled by data_cleaning module

def parse_array_field(value):
    """Parse comma-separated string into array"""
    if not value or value == '':
        return []
    return [item.strip() for item in str(value).split(',') if item.strip()]

def convert_json_to_optimized_document(product, doc_id):
    """Convert JSON product to raw document (before cleaning pipeline)"""
    try:
        # Skip products without essential data
        name = product.get('product_name', '').strip()
        if not name and 'product_name_en' in product:
            name = product.get('product_name_en', '').strip()
        if not name:
            return None
        
        # Get nutriments data
        nutriments = product.get('nutriments', {})
        
        # Create raw document (cleaning pipeline will handle type coercion)
        raw_doc = {
            'id': str(doc_id),
            'name': name,
            'brand': product.get('brands', '').strip() or None,
            'barcode': product.get('code', '').strip() or None,
            
            # Core nutrients (keep as raw values - cleaning pipeline handles type coercion)
            'calories': nutriments.get('energy-kcal_100g'),
            'protein': nutriments.get('proteins_100g'),
            'carbohydrates': nutriments.get('carbohydrates_100g'),
            'fat': nutriments.get('fat_100g'),
            'saturated_fat': nutriments.get('saturated-fat_100g'),
            'fiber': nutriments.get('fiber_100g'),
            'sugar': nutriments.get('sugars_100g'),
            'sodium': nutriments.get('sodium_100g'),
            
            # Useful metadata
            'categories': parse_array_field(product.get('categories', '')),
            'ingredients': parse_array_field(product.get('ingredients_text', '')),
            'ingredients_text': product.get('ingredients_text', '').strip() or None,  # Keep full text for NOVA estimation
            'allergens': parse_array_field(product.get('allergens', '')),
            'serving_size': product.get('serving_size', '').strip() or None,
            'serving_unit': None,  # OFF doesn't usually have separate unit field
            'countries': parse_array_field(product.get('countries', '')),
            
            # Quality scores (raw values)
            'nova_score': nutriments.get('nova-group') or product.get('nova_group'),
            'nutriscore_grade': product.get('nutriscore_grade', '').lower() if product.get('nutriscore_grade') and product.get('nutriscore_grade') != 'unknown' else None,
            'nutriscore_score': product.get('nutriscore_score')
        }
        
        # Apply data cleaning pipeline (Step 1 + Step 2)
        cleaned_doc = FoodDataCleaner.clean_document(raw_doc, source='openfoodfacts')
        
        # Only keep documents with quality_score > 20 (basic nutrition data)
        if cleaned_doc.get('quality_score', 0) < 20:
            return None
        
        # Remove empty optional fields to save space
        cleaned_doc = {k: v for k, v in cleaned_doc.items() if v is not None and v != '' and v != []}
        
        return cleaned_doc
        
    except Exception as e:
        print(f"Error converting product: {e}")
        return None

def upload_batch_to_typesense(documents):
    """Upload a batch of documents to Typesense"""
    if not documents:
        return True
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}/documents/import"
    headers = get_typesense_headers()
    headers['Content-Type'] = 'text/plain'
    
    # Convert documents to JSONL format
    jsonl_data = '\n'.join([json.dumps(doc) for doc in documents])
    
    try:
        response = requests.post(url, headers=headers, data=jsonl_data)
        if response.status_code == 200:
            return True
        else:
            print(f"❌ Error uploading batch: {response.status_code}")
            print(response.text[:500])
            return False
    except Exception as e:
        print(f"❌ Exception uploading batch: {e}")
        return False

def process_jsonl_file():
    """Process JSONL file and import to Typesense"""
    print(f"📁 Processing JSONL file at {JSONL_FILE_PATH}")
    
    if not os.path.exists(JSONL_FILE_PATH):
        print(f"❌ File not found: {JSONL_FILE_PATH}")
        return False
    
    try:
        print("🔄 Processing JSONL data with optimized fields...")
        print(f"📦 Batch size: {BATCH_SIZE:,} items")
        batch = []
        total_imported = 0
        total_processed = 0
        doc_id = 0
        
        with gzip.open(JSONL_FILE_PATH, 'rt', encoding='utf-8') as f:
            for line in f:
                try:
                    product = json.loads(line)
                    total_processed += 1
                    doc = convert_json_to_optimized_document(product, doc_id)
                    
                    if doc:
                        batch.append(doc)
                        doc_id += 1
                    
                    # Upload when batch is full
                    if len(batch) >= BATCH_SIZE:
                        if upload_batch_to_typesense(batch):
                            total_imported += len(batch)
                            print(f"✅ Batch {total_imported // BATCH_SIZE}: {len(batch):,} uploaded | Total imported: {total_imported:,} | Processed: {total_processed:,}")
                        batch = []
                    
                    # Progress indicator every 50k lines
                    if total_processed % 50000 == 0:
                        print(f"📊 Progress: Processed {total_processed:,} lines, imported {total_imported:,} products")
                    
                    # Limit products if MAX_PRODUCTS is set
                    if MAX_PRODUCTS and doc_id >= MAX_PRODUCTS:
                        break
                        
                except json.JSONDecodeError:
                    # Skip invalid JSON lines
                    continue
            
            # Upload remaining documents
            if batch:
                if upload_batch_to_typesense(batch):
                    total_imported += len(batch)
                    print(f"✅ Final batch uploaded: {len(batch):,} products")
        
        print(f"\n🎉 Cleaned import completed!")
        print(f"   Total processed: {total_processed:,} lines")
        print(f"   Total imported: {total_imported:,} products")
        return True
        
    except Exception as e:
        print(f"❌ Error processing JSONL: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Main import process"""
    print("🚀 Starting Open Food Facts Import with Data Cleaning")
    print("🧹 Applying Step 1 (correctness) + Step 2 (smart fields) cleaning pipeline")
    print(f"📊 Enhanced schema with name_norm, brand_norm, food_kind, quality_score, etc.")
    print("⚠️  This will DELETE and REPLACE your existing foods collection")
    
    # Confirm before proceeding
    response = input("Continue with optimized import? (y/N): ")
    if response.lower() != 'y':
        print("❌ Import cancelled")
        return
    
    start_time = time.time()
    
    # Step 1: Delete existing collection to free up memory
    if not delete_existing_collection():
        print("❌ Failed to delete existing collection")
        return
    
    # Step 2: Create optimized schema
    if not create_optimized_collection_schema():
        print("❌ Failed to create collection schema")
        return
    
    # Import data
    if not process_jsonl_file():
        print("❌ Failed to import data")
        return
    
    end_time = time.time()
    print(f"⏱️  Total time: {end_time - start_time:.2f} seconds")
    print("✅ Cleaned import completed successfully!")
    print("🧹 All documents processed through data cleaning pipeline!")
    print("📈 Quality scoring and smart fields added for intelligent search!")

if __name__ == "__main__":
    main()
