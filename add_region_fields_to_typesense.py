#!/usr/bin/env python3
"""
Script to extract region data from OpenFoodFacts JSONL and prepare for Typesense upload.
This script adds countries, purchase_places, and origins fields to existing Typesense documents.
"""

import json
import gzip
from typing import Dict, List, Optional

def parse_countries(countries_str: Optional[str], countries_tags: Optional[List[str]]) -> Optional[List[str]]:
    """
    Parse countries from either the countries string or countries_tags array.
    Returns a clean list of country names.
    """
    if not countries_str and not countries_tags:
        return None
    
    result = []
    
    # Parse from countries string (e.g., "United States, Canada")
    if countries_str:
        countries = [c.strip() for c in countries_str.split(',')]
        result.extend(countries)
    
    # Parse from countries_tags (e.g., ["en:united-states", "en:canada"])
    if countries_tags:
        for tag in countries_tags:
            # Remove language prefix and convert to title case
            country = tag.split(':')[-1].replace('-', ' ').title()
            if country not in result:
                result.append(country)
    
    return result if result else None

def extract_region_data(input_file: str, output_file: str, limit: Optional[int] = None):
    """
    Extract region data from OpenFoodFacts JSONL and create a JSONL file
    with barcode -> region mapping for Typesense updates.
    
    Args:
        input_file: Path to openfoodfacts-products.jsonl.gz
        output_file: Path to output JSONL file with region data
        limit: Optional limit on number of products to process
    """
    processed = 0
    with_regions = 0
    
    print(f"📖 Reading from: {input_file}")
    print(f"📝 Writing to: {output_file}")
    
    with gzip.open(input_file, 'rt', encoding='utf-8') as infile, \
         open(output_file, 'w', encoding='utf-8') as outfile:
        
        for line_num, line in enumerate(infile, 1):
            if limit and processed >= limit:
                break
            
            try:
                product = json.loads(line)
                
                # Extract barcode (required)
                barcode = product.get('code')
                if not barcode:
                    continue
                
                # Extract region fields
                countries = parse_countries(
                    product.get('countries'),
                    product.get('countries_tags')
                )
                purchase_places = product.get('purchase_places', '').strip() or None
                origins = product.get('origins', '').strip() or None
                
                # Only include products with at least one region field
                if countries or purchase_places or origins:
                    # Note: We use barcode as the key for matching, not id
                    # Typesense will match on barcode field during upsert
                    region_data = {
                        'barcode': str(barcode)  # Match on barcode field
                    }
                    
                    if countries:
                        region_data['countries'] = countries
                    if purchase_places:
                        region_data['purchase_places'] = purchase_places
                    if origins:
                        region_data['origins'] = origins
                    
                    outfile.write(json.dumps(region_data) + '\n')
                    with_regions += 1
                
                processed += 1
                
                # Progress update every 10,000 products
                if processed % 10000 == 0:
                    print(f"  Processed: {processed:,} | With regions: {with_regions:,} ({with_regions/processed*100:.1f}%)")
            
            except json.JSONDecodeError:
                print(f"⚠️  Skipping invalid JSON on line {line_num}")
                continue
            except Exception as e:
                print(f"⚠️  Error processing line {line_num}: {e}")
                continue
    
    print(f"\n✅ Complete!")
    print(f"   Total processed: {processed:,}")
    print(f"   Products with region data: {with_regions:,} ({with_regions/processed*100:.1f}%)")
    print(f"   Output file: {output_file}")

def generate_typesense_schema():
    """
    Generate the Typesense schema update command for adding region fields.
    """
    schema_update = {
        "fields": [
            {
                "name": "countries",
                "type": "string[]",
                "optional": True,
                "facet": True
            },
            {
                "name": "purchase_places",
                "type": "string",
                "optional": True
            },
            {
                "name": "origins",
                "type": "string",
                "optional": True
            }
        ]
    }
    
    print("\n📋 Typesense Schema Update")
    print("=" * 60)
    print("Add these fields to your Typesense collection schema:")
    print(json.dumps(schema_update, indent=2))
    print("\nOr use the Typesense API to update the schema:")
    print("PATCH /collections/{collection_name}")
    print(json.dumps(schema_update, indent=2))

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Extract region data from OpenFoodFacts for Typesense')
    parser.add_argument('--input', default='openfoodfacts-products.jsonl.gz',
                       help='Input JSONL.gz file (default: openfoodfacts-products.jsonl.gz)')
    parser.add_argument('--output', default='region_data_for_typesense.jsonl',
                       help='Output JSONL file (default: region_data_for_typesense.jsonl)')
    parser.add_argument('--limit', type=int, default=None,
                       help='Limit number of products to process (for testing)')
    parser.add_argument('--schema-only', action='store_true',
                       help='Only print the schema update, don\'t process data')
    
    args = parser.parse_args()
    
    if args.schema_only:
        generate_typesense_schema()
    else:
        extract_region_data(args.input, args.output, args.limit)
        print("\n" + "=" * 60)
        generate_typesense_schema()
        print("\n" + "=" * 60)
        print("\n📤 Next Steps:")
        print("1. Update your Typesense schema with the fields above")
        print("2. Upload the region data using Typesense import API:")
        print(f"   curl -X POST 'http://localhost:8108/collections/{{collection_name}}/documents/import?action=upsert&upsert_fields=barcode' \\")
        print(f"        -H 'X-TYPESENSE-API-KEY: {{api_key}}' \\")
        print(f"        --data-binary @{args.output}")
        print("\n   Note: upsert_fields=barcode tells Typesense to match on barcode field, not id")
