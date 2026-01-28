#!/usr/bin/env python3
"""
Setup Typesense collections for food search
- Delete old 'foods' collection
- Create 'foods_ingredients' collection (USDA)
- Create 'foods' collection (Open Food Facts)
"""

import json
import requests

# Typesense configuration
TYPESENSE_HOST = "h8ugnjal1c65sm2op-1.a1.typesense.net"
TYPESENSE_PORT = "443"
TYPESENSE_PROTOCOL = "https"
TYPESENSE_API_KEY = "iCrX1bLheI7cTr2USV764ElrD3dG3lL3"  # Admin API key

def delete_collection(collection_name):
    """Delete a collection if it exists"""
    url = f"{TYPESENSE_PROTOCOL}://{TYPESENSE_HOST}:{TYPESENSE_PORT}/collections/{collection_name}"
    headers = {"X-TYPESENSE-API-KEY": TYPESENSE_API_KEY}
    
    print(f"\n🗑️  Deleting collection '{collection_name}'...")
    response = requests.delete(url, headers=headers)
    
    if response.status_code == 200:
        print(f"✅ Collection '{collection_name}' deleted successfully")
        return True
    elif response.status_code == 404:
        print(f"ℹ️  Collection '{collection_name}' does not exist (already deleted)")
        return True
    else:
        print(f"❌ Error deleting collection: {response.status_code}")
        print(f"   {response.text}")
        return False

def create_collection(schema_file):
    """Create a collection from schema file"""
    with open(schema_file, 'r') as f:
        schema = json.load(f)
    
    collection_name = schema['name']
    url = f"{TYPESENSE_PROTOCOL}://{TYPESENSE_HOST}:{TYPESENSE_PORT}/collections"
    headers = {
        "X-TYPESENSE-API-KEY": TYPESENSE_API_KEY,
        "Content-Type": "application/json"
    }
    
    print(f"\n📦 Creating collection '{collection_name}'...")
    print(f"   Schema file: {schema_file}")
    print(f"   Fields: {len(schema['fields'])}")
    
    response = requests.post(url, headers=headers, json=schema)
    
    if response.status_code == 201:
        print(f"✅ Collection '{collection_name}' created successfully")
        return True
    else:
        print(f"❌ Error creating collection: {response.status_code}")
        print(f"   {response.text}")
        return False

def main():
    print("=" * 80)
    print("TYPESENSE COLLECTION SETUP")
    print("=" * 80)
    
    # Step 1: Delete old 'foods' collection
    print("\n📍 STEP 1: Delete old 'foods' collection")
    if not delete_collection('foods'):
        print("⚠️  Warning: Failed to delete 'foods' collection, continuing anyway...")
    
    # Step 2: Create 'foods_ingredients' collection (USDA)
    print("\n📍 STEP 2: Create 'foods_ingredients' collection (USDA)")
    if not create_collection('schema_foods_ingredients.json'):
        print("❌ Failed to create 'foods_ingredients' collection")
        return False
    
    # Step 3: Create 'foods' collection (Open Food Facts)
    print("\n📍 STEP 3: Create 'foods' collection (Open Food Facts)")
    if not create_collection('schema_foods.json'):
        print("❌ Failed to create 'foods' collection")
        return False
    
    print("\n" + "=" * 80)
    print("✅ COLLECTION SETUP COMPLETE")
    print("=" * 80)
    print("\nNext steps:")
    print("1. Run: python3 import_usda_cleaned.py")
    print("2. Run: python3 import_openfoodfacts_optimized.py")
    return True

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
