#!/usr/bin/env python3
"""
Print the headers from the Open Food Facts CSV file
"""

import os
import csv

# CSV file path
CSV_FILE_PATH = os.path.expanduser("~/Documents/en.openfoodfacts.org.products.csv")

def print_csv_headers():
    """
    Print the headers from the CSV file
    """
    try:
        print(f"Opening CSV file at {CSV_FILE_PATH}")
        
        # Check if file exists
        if not os.path.exists(CSV_FILE_PATH):
            print(f"Error: CSV file not found at {CSV_FILE_PATH}")
            return
        
        with open(CSV_FILE_PATH, 'r', encoding='utf-8') as file:
            # Read just the first line to get headers
            reader = csv.reader(file, delimiter='\t')
            headers = next(reader)
            
            print(f"\nFound {len(headers)} headers in the CSV file:")
            for i, header in enumerate(headers):
                print(f"{i+1}. {header}")
            
            # Print some specific headers we're interested in
            print("\nSpecific headers of interest:")
            barcode_headers = [h for h in headers if 'code' in h.lower() or 'barcode' in h.lower()]
            for header in barcode_headers:
                print(f"- {header}")
                
    except Exception as e:
        print(f"Error reading CSV headers: {e}")

if __name__ == "__main__":
    print_csv_headers()
