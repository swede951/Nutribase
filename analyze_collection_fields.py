#!/usr/bin/env python3
"""
Analyze Typesense collection fields and suggest optimizations
"""

import requests
import json

# Typesense configuration
TYPESENSE_CONFIG = {
    'api_url': 'https://h8ugnjal1c65sm2op-1.a1.typesense.net',
    'admin_api_key': 'iCrX1bLheI7cTr2USV764ElrD3dG3lL3',
    'collection_name': 'foods'
}

def get_headers():
    """Get headers for Typesense API requests"""
    return {
        'Content-Type': 'application/json',
        'X-TYPESENSE-API-KEY': TYPESENSE_CONFIG['admin_api_key']
    }

def get_collection_schema():
    """Get the collection schema and field information"""
    print("📋 Getting collection schema...")
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}"
    headers = get_headers()
    
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            info = response.json()
            fields = info.get('fields', [])
            
            print(f"✅ Collection has {len(fields)} fields")
            print(f"📊 Total documents: {info.get('num_documents', 0):,}")
            
            return fields
        else:
            print(f"❌ Error getting schema: {response.status_code}")
            return []
    except Exception as e:
        print(f"❌ Exception: {e}")
        return []

def analyze_field_usage():
    """Sample products to see which fields are actually populated"""
    print("\n🔍 Analyzing field usage in sample products...")
    
    search_params = {
        'q': '*',
        'query_by': 'name',
        'per_page': 100,
        'page': 1
    }
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}/documents/search"
    headers = get_headers()
    
    try:
        response = requests.get(url, headers=headers, params=search_params)
        if response.status_code == 200:
            results = response.json()
            hits = results.get('hits', [])
            
            # Analyze field population
            field_stats = {}
            total_products = len(hits)
            
            for hit in hits:
                doc = hit['document']
                for field, value in doc.items():
                    if field not in field_stats:
                        field_stats[field] = {'populated': 0, 'empty': 0, 'sample_values': []}
                    
                    if value and value != 0 and value != [] and value != '':
                        field_stats[field]['populated'] += 1
                        if len(field_stats[field]['sample_values']) < 3:
                            field_stats[field]['sample_values'].append(str(value)[:50])
                    else:
                        field_stats[field]['empty'] += 1
            
            return field_stats, total_products
        else:
            print(f"❌ Error sampling products: {response.status_code}")
            return {}, 0
    except Exception as e:
        print(f"❌ Exception: {e}")
        return {}, 0

def categorize_fields(fields, field_stats):
    """Categorize fields by importance and usage"""
    categories = {
        'essential': [],
        'important_nutrients': [],
        'vitamins': [],
        'minerals': [],
        'metadata': [],
        'rarely_used': [],
        'empty_or_sparse': []
    }
    
    for field in fields:
        field_name = field['name']
        field_type = field['type']
        
        # Get usage stats
        stats = field_stats.get(field_name, {'populated': 0, 'empty': 0})
        total = stats['populated'] + stats['empty']
        usage_rate = (stats['populated'] / total * 100) if total > 0 else 0
        
        field_info = {
            'name': field_name,
            'type': field_type,
            'usage_rate': usage_rate,
            'populated': stats['populated'],
            'sample_values': stats.get('sample_values', [])
        }
        
        # Categorize fields
        if field_name in ['id', 'name', 'barcode', 'brand']:
            categories['essential'].append(field_info)
        elif field_name in ['calories', 'protein', 'carbohydrates', 'fat', 'fiber', 'sugar', 'sodium']:
            categories['important_nutrients'].append(field_info)
        elif 'vitamin' in field_name:
            categories['vitamins'].append(field_info)
        elif field_name in ['calcium', 'iron', 'magnesium', 'phosphorus', 'potassium', 'zinc', 'copper', 'manganese', 'selenium', 'iodine']:
            categories['minerals'].append(field_info)
        elif field_name in ['categories', 'ingredients', 'allergens', 'countries', 'serving_size', 'nova_score', 'nutriscore_grade', 'nutriscore_score']:
            categories['metadata'].append(field_info)
        elif usage_rate < 10:  # Less than 10% populated
            categories['empty_or_sparse'].append(field_info)
        else:
            categories['rarely_used'].append(field_info)
    
    return categories

def display_field_analysis(categories):
    """Display the field analysis results"""
    print(f"\n📊 FIELD ANALYSIS BY CATEGORY:")
    
    for category, fields in categories.items():
        if not fields:
            continue
            
        print(f"\n🏷️  {category.upper().replace('_', ' ')} ({len(fields)} fields):")
        
        for field in fields:
            usage = f"{field['usage_rate']:.1f}%"
            sample = f" | Samples: {', '.join(field['sample_values'][:2])}" if field['sample_values'] else ""
            print(f"  • {field['name']} ({field['type']}) - {usage} populated{sample}")

def suggest_optimizations(categories):
    """Suggest field optimizations to reduce database size"""
    print(f"\n🎯 OPTIMIZATION SUGGESTIONS:")
    
    # Calculate potential savings
    empty_fields = categories.get('empty_or_sparse', [])
    rarely_used = categories.get('rarely_used', [])
    
    print(f"\n💾 FIELDS TO CONSIDER REMOVING:")
    
    if empty_fields:
        print(f"\n1. EMPTY/SPARSE FIELDS ({len(empty_fields)} fields):")
        for field in empty_fields:
            print(f"   • {field['name']} - only {field['usage_rate']:.1f}% populated")
        print(f"   💡 Removing these could save significant space")
    
    if rarely_used:
        print(f"\n2. RARELY USED FIELDS ({len(rarely_used)} fields):")
        for field in rarely_used:
            print(f"   • {field['name']} - {field['usage_rate']:.1f}% populated")
    
    # Suggest keeping essential fields
    essential = categories.get('essential', [])
    important = categories.get('important_nutrients', [])
    
    print(f"\n✅ FIELDS TO KEEP:")
    print(f"   • Essential: {len(essential)} fields (id, name, barcode, brand)")
    print(f"   • Important nutrients: {len(important)} fields (calories, protein, etc.)")
    
    # Ask about vitamins/minerals
    vitamins = categories.get('vitamins', [])
    minerals = categories.get('minerals', [])
    
    print(f"\n🤔 FIELDS TO EVALUATE:")
    print(f"   • Vitamins: {len(vitamins)} fields - keep for comprehensive nutrition tracking?")
    print(f"   • Minerals: {len(minerals)} fields - keep for comprehensive nutrition tracking?")

def main():
    """Main analysis function"""
    print("📊 Typesense Collection Field Analyzer")
    print("=" * 50)
    
    # Get schema
    fields = get_collection_schema()
    if not fields:
        return
    
    # Analyze field usage
    field_stats, total_sampled = analyze_field_usage()
    if not field_stats:
        return
    
    print(f"📈 Analyzed {total_sampled} sample products")
    
    # Categorize fields
    categories = categorize_fields(fields, field_stats)
    
    # Display analysis
    display_field_analysis(categories)
    
    # Suggest optimizations
    suggest_optimizations(categories)
    
    print(f"\n💡 NEXT STEPS:")
    print(f"   1. Review the empty/sparse fields for removal")
    print(f"   2. Decide on vitamin/mineral field importance")
    print(f"   3. Create optimized import script")
    print(f"   4. Re-import with reduced field set")

if __name__ == "__main__":
    main()
