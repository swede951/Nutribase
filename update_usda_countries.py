#!/usr/bin/env python3
"""
Update USDA foods in Typesense to be available in all regions
"""

import json
import requests

# Typesense configuration
TYPESENSE_HOST = "h8ugnjal1c65sm2op-1.a1.typesense.net"
TYPESENSE_PORT = "443"
TYPESENSE_PROTOCOL = "https"
TYPESENSE_API_KEY = "XFUtZgUhzP4hzOO8pnU89yG2PWyDuHPN"  # Admin API key
TYPESENSE_COLLECTION = "foods"

# List of major regions to make USDA foods available globally
GLOBAL_COUNTRIES = [
    "United States",
    "United Kingdom", 
    "Canada",
    "Australia",
    "France",
    "Germany",
    "Spain",
    "Italy",
    "Netherlands",
    "Belgium",
    "Switzerland",
    "Sweden",
    "Norway",
    "Denmark",
    "Ireland",
    "New Zealand",
    "All Regions"  # Add this to ensure it shows for "All Regions" filter
]

def get_usda_foods():
    """Fetch all USDA foods from Typesense"""
    url = f"{TYPESENSE_PROTOCOL}://{TYPESENSE_HOST}:{TYPESENSE_PORT}/collections/{TYPESENSE_COLLECTION}/documents/search"
    headers = {
        "X-TYPESENSE-API-KEY": TYPESENSE_API_KEY,
        "Content-Type": "application/json"
    }
    
    params = {
        "q": "*",
        "query_by": "name",
        "filter_by": "brand:=USDA",
        "per_page": 250  # Get all USDA foods
    }
    
    response = requests.get(url, headers=headers, params=params)
    
    if response.status_code == 200:
        data = response.json()
        hits = data.get('hits', [])
        foods = [hit['document'] for hit in hits]
        print(f"Found {len(foods)} USDA foods")
        return foods
    else:
        print(f"Error fetching USDA foods: {response.status_code} - {response.text}")
        return []

def update_food_countries(food_id):
    """Update a single food's countries to be global"""
    url = f"{TYPESENSE_PROTOCOL}://{TYPESENSE_HOST}:{TYPESENSE_PORT}/collections/{TYPESENSE_COLLECTION}/documents/{food_id}"
    headers = {
        "X-TYPESENSE-API-KEY": TYPESENSE_API_KEY,
        "Content-Type": "application/json"
    }
    
    # Update only the countries field
    update_data = {
        "countries": GLOBAL_COUNTRIES
    }
    
    response = requests.patch(url, headers=headers, json=update_data)
    
    return response.status_code == 200

def main():
    print("Fetching USDA foods from Typesense...")
    usda_foods = get_usda_foods()
    
    if not usda_foods:
        print("No USDA foods found or error occurred")
        return
    
    print(f"\nUpdating {len(usda_foods)} USDA foods to be available globally...")
    print(f"Adding countries: {', '.join(GLOBAL_COUNTRIES)}\n")
    
    successful = 0
    failed = 0
    
    for i, food in enumerate(usda_foods):
        food_id = food['id']
        food_name = food['name']
        
        if update_food_countries(food_id):
            successful += 1
            print(f"✓ [{i+1}/{len(usda_foods)}] Updated: {food_name}")
        else:
            failed += 1
            print(f"✗ [{i+1}/{len(usda_foods)}] Failed: {food_name}")
    
    print(f"\n{'='*60}")
    print(f"Update complete!")
    print(f"Successfully updated: {successful}")
    print(f"Failed: {failed}")
    print(f"{'='*60}")
    print(f"\nUSDA foods are now available in all regions!")

if __name__ == "__main__":
    main()
