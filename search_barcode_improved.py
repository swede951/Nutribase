#!/usr/bin/env python3
"""
Search for a specific barcode in the Open Food Facts CSV file with improved field size handling
"""

import os
import csv
import sys
import requests

# Increase CSV field size limit to handle large fields
csv.field_size_limit(sys.maxsize)

# CSV file path
CSV_FILE_PATH = os.path.expanduser("~/Documents/en.openfoodfacts.org.products.csv")

# Supabase configuration
SUPABASE_URL = "https://owmwxzkzqrbhhiofzgmm.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93bXd4emt6cXJiaGhpb2Z6Z21tIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzI0MjEwMiwiZXhwIjoyMDYyODE4MTAyfQ.5XKQo-XEWaRXVUPP4wdRj5W-KA9vluuZJPtwIknJo4k"

# Target barcode
TARGET_BARCODE = "5010035068352"

def search_in_csv():
    """
    Search for the target barcode in the CSV file
    """
    try:
        print(f"Searching for barcode '{TARGET_BARCODE}' in CSV file...")
        
        # Check if file exists
        if not os.path.exists(CSV_FILE_PATH):
            print(f"Error: CSV file not found at {CSV_FILE_PATH}")
            return
        
        found = False
        with open(CSV_FILE_PATH, 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file, delimiter='\t')
            
            for i, row in enumerate(reader):
                code = row.get('code', '')
                if code == TARGET_BARCODE:
                    found = True
                    print(f"\n✅ Found barcode '{TARGET_BARCODE}' in CSV file!")
                    print(f"Product name: {row.get('product_name', 'Unknown')}")
                    print(f"Brand: {row.get('brands', 'Unknown')}")
                    break
                
                # Print progress every 10,000 rows
                if i % 10000 == 0 and i > 0:
                    print(f"Processed {i:,} rows...")
        
        if not found:
            print(f"\n❌ Barcode '{TARGET_BARCODE}' not found in CSV file.")
    
    except Exception as e:
        print(f"Error searching CSV file: {e}")

def search_in_supabase():
    """
    Search for the target barcode in Supabase
    """
    print(f"\nSearching for barcode '{TARGET_BARCODE}' in Supabase...")
    
    endpoint = f"{SUPABASE_URL}/rest/v1/foods"
    
    # Exact match query
    params = {
        'select': '*',
        'barcode': f"eq.{TARGET_BARCODE}"
    }
    
    headers = {
        'apikey': SUPABASE_KEY,
        'Authorization': f'Bearer {SUPABASE_KEY}'
    }
    
    try:
        response = requests.get(endpoint, params=params, headers=headers)
        
        if response.status_code == 200:
            results = response.json()
            if results:
                print(f"✅ Found barcode '{TARGET_BARCODE}' in Supabase!")
                print(f"Product name: {results[0].get('name', 'Unknown')}")
                print(f"Brand: {results[0].get('brand', 'Unknown')}")
            else:
                print(f"❌ Barcode '{TARGET_BARCODE}' not found in Supabase.")
                
                # Try a search with ilike to see if it's stored with leading zeros
                print("\nTrying alternative search with pattern matching...")
                alt_params = {
                    'select': '*',
                    'barcode': f"ilike.%{TARGET_BARCODE}%"
                }
                
                alt_response = requests.get(endpoint, params=alt_params, headers=headers)
                if alt_response.status_code == 200:
                    alt_results = alt_response.json()
                    if alt_results:
                        print(f"✅ Found similar barcodes in Supabase:")
                        for item in alt_results:
                            print(f"  - Barcode: {item.get('barcode', 'Unknown')}")
                            print(f"    Product: {item.get('name', 'Unknown')}")
                            print(f"    Brand: {item.get('brand', 'Unknown')}")
                    else:
                        print("No similar barcodes found.")
        else:
            print(f"Error searching Supabase: {response.status_code}")
            print(response.text)
    except Exception as e:
        print(f"Error querying Supabase: {e}")

if __name__ == "__main__":
    search_in_csv()
    search_in_supabase()
