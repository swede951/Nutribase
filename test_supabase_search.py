#!/usr/bin/env python3
"""
Test script to verify Supabase search functionality
"""

import requests
import json
import sys

# Supabase configuration - same as in your import script
SUPABASE_URL = "https://owmwxzkzqrbhhiofzgmm.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93bXd4emt6cXJiaGhpb2Z6Z21tIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzI0MjEwMiwiZXhwIjoyMDYyODE4MTAyfQ.5XKQo-XEWaRXVUPP4wdRj5W-KA9vluuZJPtwIknJo4k"

def test_search(query):
    """
    Test different search query formats with Supabase
    """
    print(f"\n🔍 Testing search for: '{query}'")
    
    # Headers for all requests
    headers = {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_KEY,
        'Authorization': f'Bearer {SUPABASE_KEY}'
    }
    
    # Test 1: Simple equality search
    url1 = f"{SUPABASE_URL}/rest/v1/foods?select=*&name=eq.{query}"
    print(f"\nTest 1: Exact match\nURL: {url1}")
    response = requests.get(url1, headers=headers)
    print(f"Status: {response.status_code}")
    results = response.json()
    print(f"Results: {len(results)} items found")
    if results:
        print(f"First item: {results[0]['name']}")
    
    # Test 2: ILIKE search with % wildcards
    url2 = f"{SUPABASE_URL}/rest/v1/foods?select=*&name=ilike.%{query}%"
    print(f"\nTest 2: ILIKE with wildcards\nURL: {url2}")
    response = requests.get(url2, headers=headers)
    print(f"Status: {response.status_code}")
    results = response.json()
    print(f"Results: {len(results)} items found")
    if results:
        print(f"First item: {results[0]['name']}")
    
    # Test 3: OR search with both name and brand
    url3 = f"{SUPABASE_URL}/rest/v1/foods?select=*&or=(name.ilike.%{query}%,brand.ilike.%{query}%)"
    print(f"\nTest 3: OR search with name and brand\nURL: {url3}")
    response = requests.get(url3, headers=headers)
    print(f"Status: {response.status_code}")
    results = response.json()
    print(f"Results: {len(results)} items found")
    if results:
        print(f"First item: {results[0]['name']}")
    
    # Test 4: Full text search (if available)
    url4 = f"{SUPABASE_URL}/rest/v1/rpc/search_foods"
    data = {"search_term": query}
    print(f"\nTest 4: Full text search RPC\nURL: {url4}")
    print(f"Data: {data}")
    try:
        response = requests.post(url4, headers=headers, json=data)
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            results = response.json()
            print(f"Results: {len(results)} items found")
            if results:
                print(f"First item: {results[0]['name']}")
        else:
            print("RPC function might not exist")
    except Exception as e:
        print(f"Error: {e}")
    
    # Test 5: Count total items in database
    url5 = f"{SUPABASE_URL}/rest/v1/foods?select=count"
    print(f"\nTest 5: Count total items\nURL: {url5}")
    response = requests.get(url5, headers=headers)
    print(f"Status: {response.status_code}")
    results = response.json()
    print(f"Total items in database: {results[0]['count'] if results else 'unknown'}")

if __name__ == "__main__":
    # Get search query from command line or use default
    query = sys.argv[1] if len(sys.argv) > 1 else "cheese"
    test_search(query)
