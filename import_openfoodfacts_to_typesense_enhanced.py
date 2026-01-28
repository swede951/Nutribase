#!/usr/bin/env python3
"""
Enhanced Open Food Facts to Typesense Import Script (JSONL Format)
Imports comprehensive nutrient data including vitamins, minerals, and micronutrients
that top nutrition apps like Cronometer and MyFitnessPal track.
Uses JSONL format as required by Typesense for JSON document collections.
Optimized for smaller upload size by excluding environmental scores and image URLs.
"""

import os
import json
import csv
import requests
from tqdm import tqdm
import time
import gzip
from datetime import datetime

# Typesense configuration
TYPESENSE_CONFIG = {
    'api_url': 'https://h8ugnjal1c65sm2op-1.a1.typesense.net',
    'admin_api_key': 'iCrX1bLheI7cTr2USV764ElrD3dG3lL3',  # Your admin API key
    'collection_name': 'foods'
}

# JSONL file path (JSON Lines format for Typesense)
JSONL_FILE_PATH = os.path.expanduser("~/Documents/openfoodfacts-products.jsonl.gz")

# Import configuration
BATCH_SIZE = 1000  # Increased batch size for faster imports
MAX_PRODUCTS = None  # Set to None to import all products

def get_typesense_headers():
    """Get headers for Typesense API requests"""
    return {
        'Content-Type': 'application/json',
        'X-TYPESENSE-API-KEY': TYPESENSE_CONFIG['admin_api_key']
    }

def delete_existing_collection():
    """Delete the existing foods collection to free up space"""
    print("🗑️  Deleting existing collection...")
    
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

def create_enhanced_collection_schema():
    """Create enhanced collection schema with comprehensive nutrient fields"""
    print("📋 Creating enhanced collection schema...")
    
    schema = {
        "name": TYPESENSE_CONFIG['collection_name'],
        "fields": [
            # Basic product information
            {"name": "id", "type": "string"},
            {"name": "name", "type": "string"},
            {"name": "brand", "type": "string", "optional": True},
            {"name": "barcode", "type": "string", "optional": True, "index": True},
            {"name": "categories", "type": "string[]", "optional": True},
            {"name": "ingredients", "type": "string[]", "optional": True},
            {"name": "allergens", "type": "string[]", "optional": True},
            
            # Macronutrients (per 100g)
            {"name": "calories", "type": "float", "optional": True},
            {"name": "protein", "type": "float", "optional": True},
            {"name": "carbohydrates", "type": "float", "optional": True},
            {"name": "fat", "type": "float", "optional": True},
            {"name": "saturated_fat", "type": "float", "optional": True},
            {"name": "trans_fat", "type": "float", "optional": True},
            {"name": "fiber", "type": "float", "optional": True},
            {"name": "sugar", "type": "float", "optional": True},
            {"name": "sodium", "type": "float", "optional": True},
            {"name": "cholesterol", "type": "float", "optional": True},
            
            # Fat-soluble vitamins (per 100g)
            {"name": "vitamin_a", "type": "float", "optional": True},
            {"name": "vitamin_d", "type": "float", "optional": True},
            {"name": "vitamin_e", "type": "float", "optional": True},
            {"name": "vitamin_k", "type": "float", "optional": True},
            
            # Water-soluble vitamins (per 100g)
            {"name": "vitamin_c", "type": "float", "optional": True},
            {"name": "vitamin_b1", "type": "float", "optional": True},  # Thiamine
            {"name": "vitamin_b2", "type": "float", "optional": True},  # Riboflavin
            {"name": "vitamin_b3", "type": "float", "optional": True},  # Niacin
            {"name": "vitamin_b5", "type": "float", "optional": True},  # Pantothenic acid
            {"name": "vitamin_b6", "type": "float", "optional": True},
            {"name": "vitamin_b7", "type": "float", "optional": True},  # Biotin
            {"name": "vitamin_b9", "type": "float", "optional": True},  # Folate
            {"name": "vitamin_b12", "type": "float", "optional": True},
            
            # Essential minerals (per 100g)
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
            
            # Scoring systems
            {"name": "nova_score", "type": "int32", "optional": True},
            {"name": "nutriscore_grade", "type": "string", "optional": True},
            {"name": "nutriscore_score", "type": "int32", "optional": True},
            
            # Additional useful fields
            {"name": "serving_size", "type": "string", "optional": True},
            {"name": "countries", "type": "string[]", "optional": True},
            {"name": "last_modified", "type": "string", "optional": True},
            {"name": "data_quality", "type": "float", "optional": True}
        ]
    }
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections"
    headers = get_typesense_headers()
    
    try:
        response = requests.post(url, headers=headers, json=schema)
        if response.status_code == 201:
            print("✅ Enhanced collection schema created successfully")
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
        # This enables future incremental updates to match existing documents
        off_id = product.get('_id', '').strip()
        barcode = product.get('code', '').strip()
        stable_id = off_id if off_id else barcode
        if not stable_id:
            stable_id = str(doc_id)  # Fallback to sequential ID
        
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
            'vitamin_b1': safe_float(nutriments.get('vitamin-b1_100g')),  # Thiamine
            'vitamin_b2': safe_float(nutriments.get('vitamin-b2_100g')),  # Riboflavin
            'vitamin_b3': safe_float(nutriments.get('vitamin-pp_100g')),  # Niacin (pp = niacin)
            'vitamin_b5': safe_float(nutriments.get('pantothenic-acid_100g')),
            'vitamin_b6': safe_float(nutriments.get('vitamin-b6_100g')),
            'vitamin_b7': safe_float(nutriments.get('biotin_100g')),
            'vitamin_b9': safe_float(nutriments.get('folates_100g')),  # Folate
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
        print(f"Error converting row: {e}")
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
    """Process the JSONL file and import to Typesense"""
    print(f"📁 Processing JSONL file at {JSONL_FILE_PATH}")
    
    if not os.path.exists(JSONL_FILE_PATH):
        print(f"❌ Error: JSONL file not found at {JSONL_FILE_PATH}")
        print("Please download it from: https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz")
        return False
    
    batch = []
    total_imported = 0
    doc_id = 1
    
    print("🔄 Processing JSONL data...")
    
    try:
        # Handle both gzipped and regular JSONL files
        if JSONL_FILE_PATH.endswith('.gz'):
            file_handle = gzip.open(JSONL_FILE_PATH, 'rt', encoding='utf-8')
        else:
            file_handle = open(JSONL_FILE_PATH, 'r', encoding='utf-8')
        
        with file_handle as file:
            for line_num, line in enumerate(tqdm(file, desc="Processing products")):
                if MAX_PRODUCTS and total_imported >= MAX_PRODUCTS:
                    break
                
                try:
                    # Parse JSON line
                    product = json.loads(line.strip())
                    document = convert_json_to_typesense_document(product, doc_id)
                    if document:
                        batch.append(document)
                        doc_id += 1
                        
                        # Upload batch when it reaches batch size
                        if len(batch) >= BATCH_SIZE:
                            if upload_batch_to_typesense(batch):
                                total_imported += len(batch)
                                print(f"✅ Imported {total_imported} products so far")
                            else:
                                print(f"❌ Failed to upload batch at {total_imported}")
                            batch = []
                            time.sleep(0.1)  # Rate limiting
                            
                except json.JSONDecodeError:
                    # Skip invalid JSON lines
                    continue
            
            # Upload remaining documents
            if batch:
                if upload_batch_to_typesense(batch):
                    total_imported += len(batch)
                    print(f"✅ Final batch uploaded. Total: {total_imported}")
        
        print(f"🎉 Import completed! Total products imported: {total_imported}")
        return True
        
    except Exception as e:
        print(f"❌ Error processing CSV: {e}")
        return False

def main():
    """Main import process"""
    print("🚀 Starting Enhanced Open Food Facts to Typesense Import")
    print("⚠️  This will delete and recreate your foods collection")
    
    # Confirm before proceeding
    response = input("Continue? (y/N): ")
    if response.lower() != 'y':
        print("❌ Import cancelled")
        return
    
    # API key is already configured
    
    start_time = time.time()
    
    # Step 1: Delete existing collection
    if not delete_existing_collection():
        print("❌ Failed to delete existing collection")
        return
    
    # Step 2: Create enhanced schema
    if not create_enhanced_collection_schema():
        print("❌ Failed to create collection schema")
        return
    
    # Step 3: Import data
    if not process_jsonl_file():
        print("❌ Failed to import data")
        return
    
    end_time = time.time()
    print(f"⏱️  Total time: {end_time - start_time:.2f} seconds")
    print("✅ Enhanced import completed successfully!")

if __name__ == "__main__":
    main()
