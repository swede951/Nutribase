#!/usr/bin/env python3
"""
Import USDA Foundation Foods data into Typesense with data cleaning
Collection: foods_ingredients
"""

import json
import requests
import sys
import os
from data_cleaning import FoodDataCleaner

# Typesense configuration
TYPESENSE_HOST = "h8ugnjal1c65sm2op-1.a1.typesense.net"
TYPESENSE_PORT = "443"
TYPESENSE_PROTOCOL = "https"
TYPESENSE_API_KEY = "iCrX1bLheI7cTr2USV764ElrD3dG3lL3"  # Admin API key
TYPESENSE_COLLECTION = "foods_ingredients"

def get_nutrient_value(food_nutrients, nutrient_number):
    """Extract nutrient value by nutrient number"""
    for nutrient in food_nutrients:
        if nutrient.get('nutrient', {}).get('number') == nutrient_number:
            return nutrient.get('amount')
    return None

def transform_usda_food(usda_food):
    """Transform USDA food item to raw format (before cleaning)"""
    
    # Extract nutrients
    food_nutrients = usda_food.get('foodNutrients', [])
    
    # Get key nutrients (using USDA nutrient numbers) - keep as raw values
    calories = get_nutrient_value(food_nutrients, '208')  # Energy (kcal)
    protein = get_nutrient_value(food_nutrients, '203')  # Protein
    carbs = get_nutrient_value(food_nutrients, '205')  # Carbohydrate
    fat = get_nutrient_value(food_nutrients, '204')  # Total lipid (fat)
    saturated_fat = get_nutrient_value(food_nutrients, '606')  # Saturated fat
    fiber = get_nutrient_value(food_nutrients, '291')  # Fiber
    sugar = get_nutrient_value(food_nutrients, '269')  # Sugars
    sodium = get_nutrient_value(food_nutrients, '307')  # Sodium
    
    # Get serving size from foodPortions if available
    serving_size = "100g"  # Default
    serving_unit = "g"
    food_portions = usda_food.get('foodPortions', [])
    if food_portions:
        portion = food_portions[0]
        measure_unit = portion.get('measureUnit', {}).get('name', 'serving')
        amount = portion.get('amount', 1.0)
        gram_weight = portion.get('gramWeight', 100)
        if measure_unit and amount:
            serving_size = f"{int(amount)} {measure_unit} ({int(gram_weight)}g)"
            serving_unit = measure_unit
    
    # Create raw document (before cleaning)
    raw_doc = {
        "id": str(usda_food.get('fdcId')),
        "name": usda_food.get('description', ''),
        "brand": "USDA",  # Mark as USDA data
        "barcode": None,
        "calories": calories,
        "protein": protein,
        "carbohydrates": carbs,
        "fat": fat,
        "saturated_fat": saturated_fat,
        "fiber": fiber,
        "sugar": sugar,
        "sodium": sodium,
        "allergens": [],
        "categories": [usda_food.get('foodCategory', {}).get('description', 'General')],
        "ingredients": [],
        "serving_size": serving_size,
        "serving_unit": serving_unit,
        # Make USDA foods globally available
        "countries": ["United States", "United Kingdom", "Canada", "Australia", 
                     "France", "Germany", "Spain", "Italy", "Netherlands", "Belgium", 
                     "Switzerland", "Sweden", "Norway", "Denmark", "Ireland", 
                     "New Zealand", "All Regions"],
        "nova_score": 1,  # Foundation/SR Legacy foods are minimally processed
        "nutriscore_grade": None,
        "nutriscore_score": None
    }
    
    return raw_doc

def import_to_typesense(documents, batch_size=100):
    """Import documents to Typesense in batches using upsert mode"""
    
    # Use upsert action to update existing documents
    url = f"{TYPESENSE_PROTOCOL}://{TYPESENSE_HOST}:{TYPESENSE_PORT}/collections/{TYPESENSE_COLLECTION}/documents/import?action=upsert"
    headers = {
        "X-TYPESENSE-API-KEY": TYPESENSE_API_KEY,
        "Content-Type": "text/plain"
    }
    
    total_imported = 0
    total_failed = 0
    
    # Process in batches
    for i in range(0, len(documents), batch_size):
        batch = documents[i:i + batch_size]
        
        # Convert to JSONL format (one JSON object per line)
        jsonl_data = "\n".join([json.dumps(doc) for doc in batch])
        
        # Import batch
        response = requests.post(url, headers=headers, data=jsonl_data)
        
        if response.status_code == 200:
            # Parse response to count successes/failures
            results = response.text.strip().split('\n')
            for result in results:
                result_json = json.loads(result)
                if result_json.get('success'):
                    total_imported += 1
                else:
                    total_failed += 1
                    print(f"Failed to import: {result_json.get('error')}")
        else:
            print(f"❌ Batch import failed: {response.status_code} - {response.text[:500]}")
            total_failed += len(batch)
        
        if (i + batch_size) % 1000 == 0 or (i + batch_size) >= len(documents):
            print(f"📊 Progress: {min(i + batch_size, len(documents))}/{len(documents)} processed")
    
    return total_imported, total_failed

def main():
    print("🚀 USDA to Typesense Import with Data Cleaning")
    print("=" * 60)
    
    # Read USDA data - try SR Legacy first, then Foundation Foods
    sr_legacy_file = 'FoodData_Central_sr_legacy_food_json_2018-04.json'
    foundation_file = os.path.expanduser('~/Downloads/FoodData_Central_foundation_food_json_2025-12-18.json')
    
    if os.path.exists(sr_legacy_file):
        print(f"📁 Reading USDA SR Legacy Foods data from {sr_legacy_file}...")
        with open(sr_legacy_file, 'r') as f:
            usda_data = json.load(f)
        # Check if it's a dict with a 'SRLegacyFoods' key or a list
        if isinstance(usda_data, dict):
            foods = usda_data.get('SRLegacyFoods', usda_data.get('foods', []))
        else:
            foods = usda_data
    elif os.path.exists(foundation_file):
        print(f"📁 Reading USDA Foundation Foods data from {foundation_file}...")
        with open(foundation_file, 'r') as f:
            usda_data = json.load(f)
        # Check if it's a dict with a 'FoundationFoods' key or a list
        if isinstance(usda_data, dict):
            foods = usda_data.get('FoundationFoods', usda_data.get('foods', []))
        else:
            foods = usda_data
    else:
        print("❌ Error: No USDA data file found!")
        print(f"   Looking for: {sr_legacy_file} or {foundation_file}")
        return
    
    print(f"✅ Found {len(foods)} foods in USDA data")
    
    # Transform foods
    print("\n🔧 Transforming foods to raw format...")
    raw_docs = []
    for food in foods:
        try:
            doc = transform_usda_food(food)
            raw_docs.append(doc)
        except Exception as e:
            print(f"❌ Error transforming food {food.get('fdcId')}: {e}")
    
    print(f"✅ Transformed {len(raw_docs)} raw documents")
    
    # Apply data cleaning pipeline
    print("\n🧹 Applying data cleaning pipeline (Step 1 + Step 2)...")
    cleaned_docs = []
    
    for i, raw_doc in enumerate(raw_docs):
        try:
            cleaned = FoodDataCleaner.clean_document(raw_doc, source='usda')
            
            # Only include foods with calories (complete nutrition data)
            if cleaned.get('calories') and cleaned['calories'] > 0:
                cleaned_docs.append(cleaned)
            
            # Progress indicator
            if (i + 1) % 1000 == 0:
                print(f"  Cleaned {i + 1}/{len(raw_docs)} documents...")
                
        except Exception as e:
            print(f"❌ Error cleaning document {raw_doc.get('id')}: {e}")
    
    print(f"✅ Cleaned {len(cleaned_docs)} documents with complete nutrition data")
    
    # Show sample cleaned document
    if cleaned_docs:
        print("\n📋 Sample cleaned document:")
        sample = cleaned_docs[0]
        print(json.dumps({
            'id': sample.get('id'),
            'name': sample.get('name'),
            'brand': sample.get('brand'),
            'name_norm': sample.get('name_norm'),
            'brand_norm': sample.get('brand_norm'),
            'calories': sample.get('calories'),
            'protein': sample.get('protein'),
            'country_codes': sample.get('country_codes'),
            'food_kind': sample.get('food_kind'),
            'is_generic': sample.get('is_generic'),
            'quality_score': sample.get('quality_score'),
            'popularity': sample.get('popularity')
        }, indent=2))
    
    # Ask for confirmation before importing
    print(f"\n⚠️  Ready to import {len(cleaned_docs)} foods to Typesense collection '{TYPESENSE_COLLECTION}'")
    print("   This will upsert documents (update existing, insert new)")
    
    response = input("\nContinue with import? (yes/no): ")
    if response.lower() != 'yes':
        print("❌ Import cancelled.")
        return
    
    # Import to Typesense
    print("\n📤 Importing to Typesense...")
    imported, failed = import_to_typesense(cleaned_docs)
    
    print(f"\n{'='*60}")
    print(f"✅ Import complete!")
    print(f"   Successfully imported: {imported}")
    print(f"   Failed: {failed}")
    print(f"   Collection: {TYPESENSE_COLLECTION}")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
