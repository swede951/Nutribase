#!/usr/bin/env python3
"""
Import USDA Foundation Foods data into Typesense
"""

import json
import requests
import sys
import os

# Typesense configuration
TYPESENSE_HOST = "h8ugnjal1c65sm2op-1.a1.typesense.net"
TYPESENSE_PORT = "443"
TYPESENSE_PROTOCOL = "https"
TYPESENSE_API_KEY = "XFUtZgUhzP4hzOO8pnU89yG2PWyDuHPN"  # Admin API key
TYPESENSE_COLLECTION = "foods"

def get_nutrient_value(food_nutrients, nutrient_number):
    """Extract nutrient value by nutrient number"""
    for nutrient in food_nutrients:
        if nutrient.get('nutrient', {}).get('number') == nutrient_number:
            return nutrient.get('amount', 0)
    return 0

def transform_usda_food(usda_food):
    """Transform USDA food item to Typesense format"""
    
    # Extract nutrients
    food_nutrients = usda_food.get('foodNutrients', [])
    
    # Get key nutrients (using USDA nutrient numbers)
    calories = int(get_nutrient_value(food_nutrients, '208'))  # Energy (kcal)
    protein = round(get_nutrient_value(food_nutrients, '203'), 1)  # Protein
    carbs = round(get_nutrient_value(food_nutrients, '205'), 1)  # Carbohydrate
    fat = round(get_nutrient_value(food_nutrients, '204'), 1)  # Total lipid (fat)
    saturated_fat = round(get_nutrient_value(food_nutrients, '606'), 1)  # Saturated fat
    fiber = round(get_nutrient_value(food_nutrients, '291'), 1)  # Fiber
    sugar = round(get_nutrient_value(food_nutrients, '269'), 1)  # Sugars
    sodium = round(get_nutrient_value(food_nutrients, '307'), 1)  # Sodium
    
    # Get serving size from foodPortions if available
    serving_size = "100g"  # Default
    food_portions = usda_food.get('foodPortions', [])
    if food_portions:
        portion = food_portions[0]
        measure_unit = portion.get('measureUnit', {}).get('name', 'serving')
        amount = portion.get('amount', 1.0)
        gram_weight = portion.get('gramWeight', 100)
        if measure_unit and amount:
            serving_size = f"{int(amount)} {measure_unit} ({int(gram_weight)}g)"
    
    # Transform to Typesense format
    typesense_doc = {
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
        "countries": ["United States", "United Kingdom", "Canada", "Australia", "France", "Germany", "Spain", "Italy", "Netherlands", "Belgium", "Switzerland", "Sweden", "Norway", "Denmark", "Ireland", "New Zealand", "All Regions"],  # Make USDA foods globally available
        "nova_score": 1,  # Foundation/SR Legacy foods are minimally processed
        "nutriscore_grade": None,
        "nutriscore_score": None
    }
    
    return typesense_doc

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
            print(f"Batch import failed: {response.status_code} - {response.text}")
            total_failed += len(batch)
        
        print(f"Progress: {min(i + batch_size, len(documents))}/{len(documents)} processed")
    
    return total_imported, total_failed

def main():
    # Read USDA data - try SR Legacy first, then Foundation Foods
    sr_legacy_file = 'FoodData_Central_sr_legacy_food_json_2018-04.json'
    foundation_file = 'FoodData_Central_foundation_food_json_2025-04-24.json'
    
    if os.path.exists(sr_legacy_file):
        print("Reading USDA SR Legacy Foods data...")
        with open(sr_legacy_file, 'r') as f:
            usda_data = json.load(f)
        # Check if it's a dict with a 'SRLegacyFoods' key or a list
        if isinstance(usda_data, dict):
            foods = usda_data.get('SRLegacyFoods', usda_data.get('foods', []))
        else:
            foods = usda_data
    elif os.path.exists(foundation_file):
        print("Reading USDA Foundation Foods data...")
        with open(foundation_file, 'r') as f:
            usda_data = json.load(f)
        # Check if it's a dict with a 'FoundationFoods' key or a list
        if isinstance(usda_data, dict):
            foods = usda_data.get('FoundationFoods', usda_data.get('foods', []))
        else:
            foods = usda_data
    else:
        print("Error: No USDA data file found!")
        return
    
    print(f"Found {len(foods)} foods in USDA data")
    
    # Transform foods
    print("Transforming foods to Typesense format...")
    typesense_docs = []
    for food in foods:
        try:
            doc = transform_usda_food(food)
            # Only include foods with calories > 0 (complete nutrition data)
            if doc['calories'] > 0:
                typesense_docs.append(doc)
        except Exception as e:
            print(f"Error transforming food {food.get('fdcId')}: {e}")
    
    print(f"Transformed {len(typesense_docs)} foods with complete nutrition data")
    
    # Save to file for review
    print("Saving transformed data to usda_foods_typesense.json...")
    with open('usda_foods_typesense.json', 'w') as f:
        json.dump(typesense_docs[:10], f, indent=2)  # Save first 10 for review
    
    print("\nFirst food item preview:")
    print(json.dumps(typesense_docs[0], indent=2))
    
    # Ask for confirmation before importing
    print(f"\nReady to import {len(typesense_docs)} foods to Typesense.")
    print("Please update TYPESENSE_API_KEY in the script before proceeding.")
    
    if TYPESENSE_API_KEY == "YOUR_API_KEY_HERE":
        print("\nERROR: Please set your Typesense API key in the script first!")
        print("Update the TYPESENSE_API_KEY variable at the top of this script.")
        return
    
    response = input("Continue with import? (yes/no): ")
    if response.lower() != 'yes':
        print("Import cancelled.")
        return
    
    # Import to Typesense
    print("\nImporting to Typesense...")
    imported, failed = import_to_typesense(typesense_docs)
    
    print(f"\nImport complete!")
    print(f"Successfully imported: {imported}")
    print(f"Failed: {failed}")

if __name__ == "__main__":
    main()
