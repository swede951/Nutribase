#!/usr/bin/env python3
"""
Check for Nutri-Score data in the Open Food Facts CSV file with improved sampling
"""

import os
import csv
import sys
import random

# Increase CSV field size limit to handle large fields
csv.field_size_limit(sys.maxsize)

# CSV file path
CSV_FILE_PATH = os.path.expanduser("~/Documents/en.openfoodfacts.org.products.csv")

def check_nutriscore_data():
    """
    Check for Nutri-Score data in the CSV file with better sampling
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
            
            # Count rows with Nutri-Score data
            print("\nCounting rows with Nutri-Score data...")
            
            # Reset file pointer and skip header
            file.seek(0)
            next(reader)
            
            # Sample rows with actual Nutri-Score data
            rows_with_data = []
            total_rows = 0
            rows_with_score = 0
            rows_with_grade = 0
            
            # Process first 10,000 rows to find examples
            for i, row in enumerate(reader):
                if i >= 10000:
                    break
                    
                total_rows += 1
                
                # Check for nutriscore_score and nutriscore_grade
                has_score = False
                has_grade = False
                
                if 'nutriscore_score' in headers:
                    score_idx = headers.index('nutriscore_score')
                    if score_idx < len(row) and row[score_idx]:
                        has_score = True
                        rows_with_score += 1
                
                if 'nutriscore_grade' in headers:
                    grade_idx = headers.index('nutriscore_grade')
                    if grade_idx < len(row) and row[grade_idx] and row[grade_idx] != 'unknown':
                        has_grade = True
                        rows_with_grade += 1
                
                # Save rows with both score and grade
                if has_score and has_grade:
                    product_name = row[headers.index('product_name')] if 'product_name' in headers and headers.index('product_name') < len(row) else 'Unknown'
                    brand = row[headers.index('brands')] if 'brands' in headers and headers.index('brands') < len(row) else 'Unknown'
                    
                    row_data = {
                        'index': i,
                        'product_name': product_name,
                        'brand': brand,
                        'nutriscore_data': {}
                    }
                    
                    for header in nutriscore_headers:
                        if header in headers:
                            idx = headers.index(header)
                            if idx < len(row):
                                row_data['nutriscore_data'][header] = row[idx]
                    
                    rows_with_data.append(row_data)
            
            # Print statistics
            print(f"\nProcessed {total_rows:,} rows:")
            print(f"- Rows with nutriscore_score: {rows_with_score:,} ({rows_with_score/total_rows*100:.2f}%)")
            print(f"- Rows with nutriscore_grade: {rows_with_grade:,} ({rows_with_grade/total_rows*100:.2f}%)")
            print(f"- Rows with both score and grade: {len(rows_with_data):,} ({len(rows_with_data)/total_rows*100:.2f}%)")
            
            # Sample 5 rows with Nutri-Score data
            print("\nSampling 5 products with Nutri-Score data:")
            print("-" * 70)
            
            # Get random sample if we have enough data
            sample_rows = random.sample(rows_with_data, min(5, len(rows_with_data)))
            
            for row_data in sample_rows:
                print(f"Row {row_data['index']}:")
                print(f"  Product: {row_data['product_name']}")
                print(f"  Brand: {row_data['brand']}")
                
                for header, value in row_data['nutriscore_data'].items():
                    if value:  # Only print non-empty values
                        print(f"  {header}: {value}")
                print()
                
    except Exception as e:
        print(f"Error checking Nutri-Score data: {e}")

if __name__ == "__main__":
    check_nutriscore_data()
