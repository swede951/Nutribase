#!/usr/bin/env python3
"""
Find products with non-English alphabet names in Typesense collection
"""

import requests
import json
import re
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

def is_english_alphabet(text):
    """Check if text contains primarily English alphabet characters"""
    if not text:
        return True
    
    # Remove common punctuation and numbers
    cleaned = re.sub(r'[0-9\s\-\.\,\(\)\[\]\'\"\&\%\+\!\?\:\;\/\\]', '', text)
    
    if not cleaned:
        return True
    
    # Count English alphabet characters
    english_chars = len(re.findall(r'[a-zA-Z]', cleaned))
    total_chars = len(cleaned)
    
    # Consider it English if at least 70% are English alphabet characters
    english_ratio = english_chars / total_chars if total_chars > 0 else 1
    return english_ratio >= 0.7

def search_products_batch(page=1, per_page=250):
    """Search for a batch of products"""
    search_params = {
        'q': '*',
        'query_by': 'name',
        'per_page': per_page,
        'page': page
    }
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{TYPESENSE_CONFIG['collection_name']}/documents/search"
    headers = get_headers()
    
    try:
        response = requests.get(url, headers=headers, params=search_params)
        if response.status_code == 200:
            return response.json()
        else:
            print(f"❌ Error searching page {page}: {response.status_code}")
            return None
    except Exception as e:
        print(f"❌ Exception on page {page}: {e}")
        return None

def analyze_non_english_products(max_pages=20):
    """Analyze products to find non-English names"""
    print(f"🔍 Analyzing products for non-English names (checking {max_pages} pages)...")
    
    non_english_products = []
    total_checked = 0
    
    for page in range(1, max_pages + 1):
        print(f"📄 Processing page {page}...")
        
        results = search_products_batch(page)
        if not results:
            break
        
        hits = results.get('hits', [])
        if not hits:
            break
        
        for hit in hits:
            doc = hit['document']
            name = doc.get('name', '')
            total_checked += 1
            
            if not is_english_alphabet(name):
                non_english_products.append({
                    'id': doc.get('id'),
                    'name': name,
                    'brand': doc.get('brand', ''),
                    'barcode': doc.get('barcode', ''),
                    'countries': doc.get('countries', [])
                })
        
        # Rate limiting
        time.sleep(0.1)
    
    return non_english_products, total_checked

def categorize_by_script(products):
    """Categorize non-English products by script/language"""
    categories = {
        'arabic': [],
        'chinese': [],
        'cyrillic': [],
        'japanese': [],
        'korean': [],
        'thai': [],
        'hebrew': [],
        'other': []
    }
    
    for product in products:
        name = product['name']
        
        if re.search(r'[\u0600-\u06FF\u0750-\u077F]', name):  # Arabic
            categories['arabic'].append(product)
        elif re.search(r'[\u4e00-\u9fff]', name):  # Chinese
            categories['chinese'].append(product)
        elif re.search(r'[\u0400-\u04FF]', name):  # Cyrillic
            categories['cyrillic'].append(product)
        elif re.search(r'[\u3040-\u309F\u30A0-\u30FF]', name):  # Japanese
            categories['japanese'].append(product)
        elif re.search(r'[\uAC00-\uD7AF]', name):  # Korean
            categories['korean'].append(product)
        elif re.search(r'[\u0E00-\u0E7F]', name):  # Thai
            categories['thai'].append(product)
        elif re.search(r'[\u0590-\u05FF]', name):  # Hebrew
            categories['hebrew'].append(product)
        else:
            categories['other'].append(product)
    
    return categories

def display_results(categories, total_checked, total_non_english):
    """Display the analysis results"""
    print(f"\n📊 ANALYSIS RESULTS:")
    print(f"  - Total products checked: {total_checked:,}")
    print(f"  - Non-English products found: {total_non_english:,}")
    print(f"  - Percentage non-English: {(total_non_english/total_checked)*100:.2f}%")
    
    print(f"\n🌍 BREAKDOWN BY SCRIPT/LANGUAGE:")
    for script, products in categories.items():
        if products:
            print(f"  - {script.capitalize()}: {len(products)} products")
            
            # Show samples
            print(f"    Samples:")
            for product in products[:3]:
                countries = ', '.join(product['countries'][:2]) if product['countries'] else 'Unknown'
                print(f"      • '{product['name']}' (Brand: {product['brand'] or 'N/A'}, Countries: {countries})")
            
            if len(products) > 3:
                print(f"      ... and {len(products) - 3} more")
            print()

def offer_cleanup_options(categories, total_non_english):
    """Offer options to clean up non-English products"""
    if total_non_english == 0:
        print("✅ No non-English products found!")
        return
    
    print(f"🧹 CLEANUP OPTIONS:")
    print(f"1. Keep all products (recommended for international app)")
    print(f"2. Remove all non-English products ({total_non_english:,} products)")
    print(f"3. Remove specific languages/scripts")
    print(f"4. Export list for manual review")
    
    choice = input("\nChoose an option (1-4): ").strip()
    
    if choice == '1':
        print("✅ Keeping all products - great for international users!")
    elif choice == '2':
        print("⚠️  This would remove a significant amount of data.")
        print("💡 Consider keeping products for international markets.")
    elif choice == '3':
        print("📝 You could selectively remove specific scripts:")
        for script, products in categories.items():
            if products:
                print(f"   - Remove {len(products)} {script} products?")
    elif choice == '4':
        print("📄 Export functionality would save the list to a file for review.")
    else:
        print("❌ Invalid choice")

def main():
    """Main analysis function"""
    print("🌍 Non-English Product Name Analyzer")
    print("=" * 50)
    
    # Analyze products
    non_english_products, total_checked = analyze_non_english_products(max_pages=40)
    
    if not non_english_products:
        print("✅ All checked products have English alphabet names!")
        return
    
    # Categorize by script
    categories = categorize_by_script(non_english_products)
    
    # Display results
    display_results(categories, total_checked, len(non_english_products))
    
    # Offer cleanup options
    offer_cleanup_options(categories, len(non_english_products))

if __name__ == "__main__":
    main()
