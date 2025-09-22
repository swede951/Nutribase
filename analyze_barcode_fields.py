#!/usr/bin/env python3
"""
Analyze the Open Food Facts CSV file to find potential barcode fields
"""

import os
import csv
import re

# CSV file path
CSV_FILE_PATH = os.path.expanduser("~/Documents/en.openfoodfacts.org.products.csv")

# Number of rows to sample
SAMPLE_SIZE = 100

def is_potential_barcode(value):
    """Check if a value looks like a barcode"""
    if not value:
        return False
        
    # EAN-13 is 13 digits, UPC is 12 digits, but we'll be flexible
    if len(value) < 8 or len(value) > 14:
        return False
        
    # Barcodes are typically all digits
    if not re.match(r'^\d+$', value):
        return False
        
    return True

def analyze_potential_barcode_fields():
    """
    Analyze the CSV file to find columns that might contain barcodes
    """
    try:
        print(f"Analyzing CSV file at {CSV_FILE_PATH}")
        
        # Check if file exists
        if not os.path.exists(CSV_FILE_PATH):
            print(f"Error: CSV file not found at {CSV_FILE_PATH}")
            return
        
        with open(CSV_FILE_PATH, 'r', encoding='utf-8') as file:
            reader = csv.reader(file, delimiter='\t')
            headers = next(reader)
            
            # Initialize counters for each column
            barcode_counts = {header: 0 for header in headers}
            total_rows = 0
            
            # Sample rows to analyze
            for i, row in enumerate(reader):
                if i >= SAMPLE_SIZE:
                    break
                    
                total_rows += 1
                
                # Check each column for potential barcode values
                for j, value in enumerate(row):
                    if j < len(headers) and is_potential_barcode(value):
                        barcode_counts[headers[j]] += 1
            
            # Calculate percentage of rows with potential barcodes in each column
            print(f"\nAnalyzed {total_rows} rows. Columns that might contain barcodes:")
            print("=" * 70)
            print(f"{'Column Name':<30} {'Count':<10} {'Percentage':<10} {'Example Value'}")
            print("-" * 70)
            
            # Sort by count (descending)
            sorted_counts = sorted(barcode_counts.items(), key=lambda x: x[1], reverse=True)
            
            # Reset file pointer and skip header
            file.seek(0)
            next(reader)
            
            # Get example values for top fields
            example_values = {}
            for i, row in enumerate(reader):
                if i >= 1:  # Just get the first row for examples
                    break
                for j, value in enumerate(row):
                    if j < len(headers):
                        example_values[headers[j]] = value
            
            # Print results for fields with at least one potential barcode
            for header, count in sorted_counts:
                if count > 0:
                    percentage = (count / total_rows) * 100
                    example = example_values.get(header, "")
                    if len(example) > 20:
                        example = example[:17] + "..."
                    print(f"{header:<30} {count:<10} {percentage:<10.2f}% {example}")
                
    except Exception as e:
        print(f"Error analyzing CSV file: {e}")

if __name__ == "__main__":
    analyze_potential_barcode_fields()
