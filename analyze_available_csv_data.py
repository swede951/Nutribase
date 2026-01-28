#!/usr/bin/env python3
"""
Analyze Open Food Facts CSV to identify additional data fields available
that we're not currently importing
"""

import os
import csv

# CSV file path
CSV_FILE_PATH = os.path.expanduser("~/Documents/en.openfoodfacts.org.products.csv")

# Currently imported fields from import_openfoodfacts_with_tracking.py
CURRENTLY_IMPORTED = {
    'code',
    'product_name', 
    'brands',
    'nova_group',
    'energy-kcal_100g',
    'proteins_100g',
    'carbohydrates_100g', 
    'fat_100g',
    'sodium_100g',
    'sugars_100g',
    'saturated-fat_100g',
    'serving_size',
    'ingredients_text',
    'nutriscore_score',
    'nutriscore_grade',
    'last_modified_datetime'
}

def analyze_csv_data():
    """Analyze what additional data is available in the CSV"""
    try:
        print(f"📁 Analyzing CSV file at {CSV_FILE_PATH}")
        
        if not os.path.exists(CSV_FILE_PATH):
            print(f"❌ Error: CSV file not found at {CSV_FILE_PATH}")
            print("Please download it from: https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv")
            return
        
        with open(CSV_FILE_PATH, 'r', encoding='utf-8') as file:
            reader = csv.reader(file, delimiter='\t')
            headers = next(reader)
            
            print(f"📊 Total columns in CSV: {len(headers)}")
            print(f"📊 Currently importing: {len(CURRENTLY_IMPORTED)} columns")
            
            # Find additional nutrient fields
            nutrient_fields = []
            for header in headers:
                if '_100g' in header and header not in CURRENTLY_IMPORTED:
                    nutrient_fields.append(header)
            
            # Find other interesting fields
            image_fields = [h for h in headers if 'image' in h.lower()]
            category_fields = [h for h in headers if 'categor' in h.lower()]
            packaging_fields = [h for h in headers if 'packaging' in h.lower()]
            allergen_fields = [h for h in headers if 'allergen' in h.lower()]
            eco_fields = [h for h in headers if 'eco' in h.lower()]
            
            print("\n🔬 ADDITIONAL NUTRIENT DATA AVAILABLE:")
            print(f"Found {len(nutrient_fields)} additional nutrient fields:")
            for field in sorted(nutrient_fields)[:20]:  # Show first 20
                print(f"  • {field}")
            if len(nutrient_fields) > 20:
                print(f"  ... and {len(nutrient_fields) - 20} more")
            
            print("\n🖼️  IMAGE DATA AVAILABLE:")
            for field in image_fields:
                print(f"  • {field}")
            
            print("\n📂 CATEGORY DATA AVAILABLE:")
            for field in category_fields:
                print(f"  • {field}")
            
            print("\n📦 PACKAGING DATA AVAILABLE:")
            for field in packaging_fields:
                print(f"  • {field}")
            
            print("\n⚠️  ALLERGEN DATA AVAILABLE:")
            for field in allergen_fields:
                print(f"  • {field}")
            
            print("\n🌱 ENVIRONMENTAL DATA AVAILABLE:")
            for field in eco_fields:
                print(f"  • {field}")
            
            # Sample some actual data
            print("\n📋 SAMPLING ACTUAL DATA (first 5 products):")
            file.seek(0)  # Reset to beginning
            reader = csv.DictReader(file, delimiter='\t')
            
            sample_fields = ['fiber_100g', 'vitamin-c_100g', 'calcium_100g', 'iron_100g', 
                           'image_url', 'categories', 'allergens', 'ecoscore_grade']
            
            for i, row in enumerate(reader):
                if i >= 5:
                    break
                print(f"\nProduct {i+1}: {row.get('product_name', 'Unknown')}")
                for field in sample_fields:
                    if field in row and row[field]:
                        print(f"  {field}: {row[field]}")
            
            # Recommend priority fields to add
            print("\n🎯 RECOMMENDED PRIORITY FIELDS TO ADD:")
            priority_fields = [
                'fiber_100g',
                'vitamin-c_100g', 
                'calcium_100g',
                'iron_100g',
                'cholesterol_100g',
                'trans-fat_100g',
                'image_url',
                'image_front_url',
                'categories',
                'allergens',
                'ecoscore_grade',
                'ecoscore_score'
            ]
            
            available_priority = [f for f in priority_fields if f in headers]
            for field in available_priority:
                print(f"  ✅ {field}")
            
            missing_priority = [f for f in priority_fields if f not in headers]
            if missing_priority:
                print("\n❌ Priority fields NOT available in CSV:")
                for field in missing_priority:
                    print(f"  • {field}")
                    
    except Exception as e:
        print(f"❌ Error analyzing CSV: {e}")

if __name__ == "__main__":
    analyze_csv_data()
