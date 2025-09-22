#!/usr/bin/env python3
"""
Check for Nutri-Score data in the Open Food Facts CSV file
"""

import os
import csv
import sys

# Increase CSV field size limit to handle large fields
csv.field_size_limit(sys.maxsize)

# CSV file path
CSV_FILE_PATH = os.path.expanduser("~/Documents/en.openfoodfacts.org.products.csv")

def check_nutriscore_data():
    """
    Check for Nutri-Score data in the CSV file
    """
    try:
        print(f"Checking for Nutri-Score data in CSV file...")
        
        # Check if file exists
        if not os.path.exists(CSV_FILE_PATH):
            print(f"Error: CSV file not found at {CSV_FILE_PATH}")
            return
        
        with open(CSV_FILE_PATH, 'r', encoding='utf-8') as file:
            # Read headers first
            reader = csv.reader(file, delimiter='\t')
            headers = next(reader)
            
            # Find Nutri-Score related headers
            nutriscore_headers = [h for h in headers if 'nutri' in h.lower()]
            
            print(f"\nFound {len(nutriscore_headers)} Nutri-Score related headers:")
            for header in nutriscore_headers:
                print(f"- {header}")
                
            # Sample some rows to see Nutri-Score data
            print("\nSampling Nutri-Score data from 5 rows:")
            print("-" * 70)
            
            # Reset file pointer and skip header
            file.seek(0)
            next(reader)
            
            # Sample rows
            sample_count = 0
            for i, row in enumerate(reader):
                if i >= 100:  # Skip some rows to get more variety
                    if sample_count >= 5:
                        break
                        
                    # Check if this row has Nutri-Score data
                    has_data = False
                    for header in nutriscore_headers:
                        if header in headers:
                            idx = headers.index(header)
                            if idx < len(row) and row[idx]:
                                has_data = True
                                break
                    
                    if has_data:
                        sample_count += 1
                        print(f"Row {i}:")
                        print(f"  Product: {row[headers.index('product_name')] if 'product_name' in headers and headers.index('product_name') < len(row) else 'Unknown'}")
                        print(f"  Brand: {row[headers.index('brands')] if 'brands' in headers and headers.index('brands') < len(row) else 'Unknown'}")
                        
                        for header in nutriscore_headers:
                            if header in headers:
                                idx = headers.index(header)
                                if idx < len(row):
                                    print(f"  {header}: {row[idx]}")
                        print()
                
    except Exception as e:
        print(f"Error checking Nutri-Score data: {e}")

if __name__ == "__main__":
    check_nutriscore_data()
