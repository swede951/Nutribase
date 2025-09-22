#!/usr/bin/env python3
"""
Split Open Food Facts CSV file into 4 smaller files
"""

import os
import csv
import math
import sys
from tqdm import tqdm

# Increase CSV field size limit
csv.field_size_limit(sys.maxsize)

# Source CSV file path
SOURCE_CSV_PATH = os.path.expanduser("~/Documents/en.openfoodfacts.org.products.csv")

# Output directory
OUTPUT_DIR = os.path.expanduser("~/Documents")

# Number of files to split into
NUM_FILES = 4

def split_csv_file():
    """
    Split the large CSV file into 4 smaller files
    """
    print(f"Splitting CSV file at {SOURCE_CSV_PATH} into {NUM_FILES} files...")
    
    # Check if source file exists
    if not os.path.exists(SOURCE_CSV_PATH):
        print(f"Error: Source CSV file not found at {SOURCE_CSV_PATH}")
        return False
    
    try:
        # First, count total rows to determine split size
        total_rows = 0
        with open(SOURCE_CSV_PATH, 'r', encoding='utf-8') as csvfile:
            reader = csv.reader(csvfile, delimiter='\t')
            # Skip header row in count
            next(reader)
            for _ in reader:
                total_rows += 1
        
        print(f"Total rows in CSV: {total_rows}")
        
        # Calculate rows per file (approximately)
        rows_per_file = math.ceil(total_rows / NUM_FILES)
        print(f"Each file will contain approximately {rows_per_file} rows")
        
        # Open the source file again
        with open(SOURCE_CSV_PATH, 'r', encoding='utf-8') as csvfile:
            reader = csv.reader(csvfile, delimiter='\t')
            
            # Get header row
            header = next(reader)
            
            # Process each chunk
            for file_num in range(1, NUM_FILES + 1):
                output_file = os.path.join(OUTPUT_DIR, f"food_data_part{file_num}.csv")
                print(f"Creating file {file_num}/{NUM_FILES}: {output_file}")
                
                with open(output_file, 'w', encoding='utf-8', newline='') as outfile:
                    writer = csv.writer(outfile, delimiter=',')
                    
                    # Write header to each file
                    writer.writerow(header)
                    
                    # Write rows for this chunk
                    rows_written = 0
                    with tqdm(total=rows_per_file, desc=f"File {file_num}") as pbar:
                        for row in reader:
                            writer.writerow(row)
                            rows_written += 1
                            pbar.update(1)
                            
                            # Stop when we've written enough rows for this file
                            if rows_written >= rows_per_file and file_num < NUM_FILES:
                                break
                
                print(f"Wrote {rows_written} rows to {output_file}")
        
        print("Split complete!")
        return True
        
    except Exception as e:
        print(f"Error splitting CSV file: {e}")
        return False

if __name__ == "__main__":
    split_csv_file()
