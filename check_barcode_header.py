#!/usr/bin/env python3
"""
Check which header in the CSV file contains the specific barcode
"""

import os
import csv
import sys

# Increase CSV field size limit to handle large fields
csv.field_size_limit(sys.maxsize)

# CSV file path
CSV_FILE_PATH = os.path.expanduser("~/Documents/en.openfoodfacts.org.products.csv")

# Target barcode
TARGET_BARCODE = "5010035068352"

def check_barcode_header():
    """
    Check which header in the CSV file contains the target barcode
    """
    try:
        print(f"Searching for barcode '{TARGET_BARCODE}' in CSV file...")
        
        # Check if file exists
        if not os.path.exists(CSV_FILE_PATH):
            print(f"Error: CSV file not found at {CSV_FILE_PATH}")
            return
        
        with open(CSV_FILE_PATH, 'r', encoding='utf-8') as file:
            # Read headers first
            reader = csv.reader(file, delimiter='\t')
            headers = next(reader)
            
            # Continue reading rows
            for i, row in enumerate(reader):
                # Check if any column contains our target barcode
                for col_idx, value in enumerate(row):
                    if value == TARGET_BARCODE:
                        header_name = headers[col_idx] if col_idx < len(headers) else "Unknown"
                        print(f"\n✅ Found barcode '{TARGET_BARCODE}' in CSV file!")
                        print(f"Header name: {header_name}")
                        print(f"Column index: {col_idx}")
                        
                        # Print some context about the row
                        print("\nRow details:")
                        for j, header in enumerate(headers[:10]):  # Print first 10 headers for context
                            if j < len(row):
                                print(f"{header}: {row[j]}")
                        
                        # Additional product details if available
                        product_name_idx = headers.index('product_name') if 'product_name' in headers else -1
                        brand_idx = headers.index('brands') if 'brands' in headers else -1
                        
                        if product_name_idx >= 0 and product_name_idx < len(row):
                            print(f"Product name: {row[product_name_idx]}")
                        
                        if brand_idx >= 0 and brand_idx < len(row):
                            print(f"Brand: {row[brand_idx]}")
                        
                        return
                
                # Print progress every 10,000 rows
                if i % 10000 == 0 and i > 0:
                    print(f"Processed {i:,} rows...")
        
        print(f"\n❌ Barcode '{TARGET_BARCODE}' not found in CSV file.")
    
    except Exception as e:
        print(f"Error searching CSV file: {e}")

if __name__ == "__main__":
    check_barcode_header()
