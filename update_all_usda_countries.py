#!/usr/bin/env python3
"""
Update ALL USDA foods (both Foundation and SR Legacy) in Typesense to be available in all regions
"""

import json
import requests
import time

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
    "All Regions"
]

def get_all_usda_foods():
    """Fetch ALL USDA foods from Typesense (both Foundation and SR Legacy)"""
    url = f"{TYPESENSE_PROTOCOL}://{TYPESENSE_HOST}:{TYPESENSE_PORT}/collections/{TYPESENSE_COLLECTION}/documents/search"
    headers = {
        "X-TYPESENSE-API-KEY": TYPESENSE_API_KEY,
        "Content-Type": "application/json"
    }
    
    all_foods = []
    page = 1
    per_page = 250
    
    while True:
        params = {
            "q": "*",
            "query_by": "name",
            "filter_by": "brand:=USDA",
            "per_page": per_page,
            "page": page
        }
        
        response = requests.get(url, headers=headers, params=params)
        
        if response.status_code == 200:
            data = response.json()
            hits = data.get('hits', [])
            
            if not hits:
                break
                
            foods = [hit['document'] for hit in hits]
            all_foods.extend(foods)
            
            print(f"Fetched page {page}: {len(foods)} foods (total: {len(all_foods)})")
            
            # Check if there are more pages
            found = data.get('found', 0)
            if len(all_foods) >= found:
                break
                
            page += 1
            time.sleep(0.1)  # Small delay to avoid rate limiting
        else:
            print(f"Error fetching USDA foods: {response.status_code} - {response.text}")
            break
    
    return all_foods

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
    print("="*70)
    print("USDA Foods Global Update Script")
    print("="*70)
    print("\nFetching ALL USDA foods from Typesense...")
    print("(This includes both Foundation Foods and SR Legacy Foods)\n")
    
    usda_foods = get_all_usda_foods()
    
    if not usda_foods:
        print("\n❌ No USDA foods found or error occurred")
        return
    
    print(f"\n{'='*70}")
    print(f"Found {len(usda_foods)} USDA foods total")
    print(f"{'='*70}")
    print(f"\nUpdating ALL foods to be available globally...")
    print(f"Adding countries: {', '.join(GLOBAL_COUNTRIES[:5])}... and {len(GLOBAL_COUNTRIES)-5} more\n")
    
    successful = 0
    failed = 0
    
    for i, food in enumerate(usda_foods):
        food_id = food['id']
        food_name = food['name']
        
        if update_food_countries(food_id):
            successful += 1
            if i % 100 == 0 or i < 10:  # Show first 10 and every 100th
                print(f"✓ [{i+1}/{len(usda_foods)}] Updated: {food_name[:60]}")
        else:
            failed += 1
            print(f"✗ [{i+1}/{len(usda_foods)}] Failed: {food_name[:60]}")
        
        # Small delay every 50 requests to avoid rate limiting
        if (i + 1) % 50 == 0:
            time.sleep(0.5)
            print(f"   ... {successful} successful, {failed} failed so far ...")
    
    print(f"\n{'='*70}")
    print(f"Update complete!")
    print(f"{'='*70}")
    print(f"Successfully updated: {successful}")
    print(f"Failed: {failed}")
    print(f"{'='*70}")
    print(f"\n✅ ALL USDA foods are now available in all regions!")
    print(f"   Search for 'apple', 'banana', 'chicken', etc. to see them!\n")

if __name__ == "__main__":
    main()
