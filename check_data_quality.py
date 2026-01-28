#!/usr/bin/env python3
"""
Check Data Quality in Typesense Collection
Identifies products without names and other data quality issues
"""

import requests
import json
import time

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

def get_collection_stats():
    """Get basic collection statistics"""
    print("📊 Getting collection statistics...")
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}"
    headers = get_headers()
    
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            info = response.json()
            total_docs = info.get('num_documents', 0)
            print(f"✅ Total documents in collection: {total_docs:,}")
            return total_docs
        else:
            print(f"❌ Error getting collection info: {response.status_code}")
            print(response.text)
            return 0
    except Exception as e:
        print(f"❌ Exception: {e}")
        return 0

def search_products_without_names():
    """Search for products that might not have proper names"""
    print("\n🔍 Searching for products without names...")
    
    # Search for products with empty or very short names
    search_params = {
        'q': '*',
        'query_by': 'name',
        'filter_by': 'name:=""',  # Empty names
        'per_page': 50,
        'page': 1
    }
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}/documents/search"
    headers = get_headers()
    
    try:
        response = requests.get(url, headers=headers, params=search_params)
        if response.status_code == 200:
            results = response.json()
            found = results.get('found', 0)
            print(f"📋 Products with empty names: {found}")
            
            if found > 0:
                print("\nSample products with empty names:")
                for hit in results.get('hits', [])[:5]:
                    doc = hit['document']
                    print(f"  ID: {doc.get('id')}, Name: '{doc.get('name', '')}', Brand: '{doc.get('brand', '')}'")
            
            return found
        else:
            print(f"❌ Error searching: {response.status_code}")
            print(response.text)
            return 0
    except Exception as e:
        print(f"❌ Exception: {e}")
        return 0

def search_products_with_short_names():
    """Search for products with very short names (might be incomplete)"""
    print("\n🔍 Searching for products with very short names...")
    
    # Search for products and check name length in results
    search_params = {
        'q': '*',
        'query_by': 'name',
        'per_page': 250,  # Get more results to analyze
        'page': 1
    }
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}/documents/search"
    headers = get_headers()
    
    short_names = []
    
    try:
        response = requests.get(url, headers=headers, params=search_params)
        if response.status_code == 200:
            results = response.json()
            
            for hit in results.get('hits', []):
                doc = hit['document']
                name = doc.get('name', '')
                if len(name) <= 2:  # Very short names
                    short_names.append({
                        'id': doc.get('id'),
                        'name': name,
                        'brand': doc.get('brand', ''),
                        'barcode': doc.get('barcode', '')
                    })
            
            print(f"📋 Products with very short names (≤2 chars): {len(short_names)}")
            
            if short_names:
                print("\nSample products with short names:")
                for product in short_names[:10]:
                    print(f"  ID: {product['id']}, Name: '{product['name']}', Brand: '{product['brand']}', Barcode: '{product['barcode']}'")
            
            return len(short_names)
        else:
            print(f"❌ Error searching: {response.status_code}")
            return 0
    except Exception as e:
        print(f"❌ Exception: {e}")
        return 0

def sample_random_products():
    """Sample some random products to check overall data quality"""
    print("\n📋 Sampling random products for quality check...")
    
    search_params = {
        'q': '*',
        'query_by': 'name',
        'per_page': 20,
        'page': 1
    }
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}/documents/search"
    headers = get_headers()
    
    try:
        response = requests.get(url, headers=headers, params=search_params)
        if response.status_code == 200:
            results = response.json()
            
            print("Sample products:")
            for i, hit in enumerate(results.get('hits', [])[:10], 1):
                doc = hit['document']
                name = doc.get('name', '')
                brand = doc.get('brand', '')
                calories = doc.get('calories', 0)
                protein = doc.get('protein', 0)
                
                print(f"  {i}. Name: '{name}' | Brand: '{brand}' | Calories: {calories} | Protein: {protein}g")
            
            return True
        else:
            print(f"❌ Error sampling: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False

def delete_products_without_names():
    """Delete products that don't have proper names"""
    print("\n🗑️  Would you like to delete products without names?")
    
    # First, let's see how many we're dealing with
    empty_names = search_products_without_names()
    short_names = search_products_with_short_names()
    
    total_problematic = empty_names + short_names
    
    if total_problematic == 0:
        print("✅ No products found without proper names!")
        return
    
    print(f"\n📊 Summary:")
    print(f"  - Products with empty names: {empty_names}")
    print(f"  - Products with very short names: {short_names}")
    print(f"  - Total problematic products: {total_problematic}")
    
    response = input(f"\nDelete these {total_problematic} products? (y/N): ")
    if response.lower() != 'y':
        print("❌ Deletion cancelled")
        return
    
    print("🔄 Deletion feature would be implemented here...")
    print("💡 For safety, manual deletion is recommended through Typesense dashboard")

def main():
    """Main data quality check"""
    print("🔍 Typesense Data Quality Checker")
    print("=" * 50)
    
    # Get basic stats
    total_docs = get_collection_stats()
    if total_docs == 0:
        print("❌ Could not access collection")
        return
    
    # Check for products without names
    empty_names = search_products_without_names()
    
    # Check for products with very short names
    short_names = search_products_with_short_names()
    
    # Sample some products
    sample_random_products()
    
    # Summary
    print(f"\n📊 SUMMARY:")
    print(f"  - Total products: {total_docs:,}")
    print(f"  - Products with empty names: {empty_names}")
    print(f"  - Products with very short names: {short_names}")
    
    if empty_names + short_names == 0:
        print("✅ All products have proper names!")
    else:
        print(f"⚠️  {empty_names + short_names} products may need attention")
        
        # Offer to clean up
        if empty_names + short_names > 0:
            delete_products_without_names()

if __name__ == "__main__":
    main()
