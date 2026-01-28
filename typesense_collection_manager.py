#!/usr/bin/env python3
"""
Typesense Collection Management Script
Helps manage Typesense collections - delete, create, and inspect
"""

import requests
import json

# Typesense configuration
TYPESENSE_CONFIG = {
    'api_url': 'https://h8ugnjal1c65sm2op-1.a1.typesense.net',
    'admin_api_key': 't5mEztNYGfzSotyavuBpucB5rPmtEMh_admin',  # Your admin API key
    'collection_name': 'foods'
}

def get_headers():
    """Get headers for Typesense API requests"""
    return {
        'Content-Type': 'application/json',
        'X-TYPESENSE-API-KEY': TYPESENSE_CONFIG['admin_api_key']
    }

def list_collections():
    """List all collections"""
    print("📋 Listing all collections...")
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections"
    headers = get_headers()
    
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            collections = response.json()
            print(f"Found {len(collections)} collections:")
            for collection in collections:
                name = collection.get('name', 'Unknown')
                num_docs = collection.get('num_documents', 0)
                print(f"  • {name}: {num_docs:,} documents")
            return collections
        else:
            print(f"❌ Error listing collections: {response.status_code}")
            print(response.text)
            return []
    except Exception as e:
        print(f"❌ Exception listing collections: {e}")
        return []

def get_collection_info(collection_name):
    """Get detailed information about a collection"""
    print(f"🔍 Getting info for collection: {collection_name}")
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{collection_name}"
    headers = get_headers()
    
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            info = response.json()
            print(f"Collection: {info.get('name')}")
            print(f"Documents: {info.get('num_documents', 0):,}")
            print(f"Fields: {len(info.get('fields', []))}")
            
            print("\nFields:")
            for field in info.get('fields', []):
                field_type = field.get('type', 'unknown')
                optional = ' (optional)' if field.get('optional') else ''
                print(f"  • {field.get('name')}: {field_type}{optional}")
            
            return info
        else:
            print(f"❌ Error getting collection info: {response.status_code}")
            print(response.text)
            return None
    except Exception as e:
        print(f"❌ Exception getting collection info: {e}")
        return None

def delete_collection(collection_name):
    """Delete a collection"""
    print(f"🗑️  Deleting collection: {collection_name}")
    
    # Confirm deletion
    response = input(f"Are you sure you want to delete '{collection_name}'? (y/N): ")
    if response.lower() != 'y':
        print("❌ Deletion cancelled")
        return False
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections/{collection_name}"
    headers = get_headers()
    
    try:
        response = requests.delete(url, headers=headers)
        if response.status_code in [200, 404]:  # 404 means already deleted
            print("✅ Collection deleted successfully")
            return True
        else:
            print(f"❌ Error deleting collection: {response.status_code}")
            print(response.text)
            return False
    except Exception as e:
        print(f"❌ Exception deleting collection: {e}")
        return False

def test_api_key():
    """Test if the API key is working"""
    print("🔑 Testing API key...")
    
    if TYPESENSE_CONFIG['admin_api_key'] == 'YOUR_ADMIN_API_KEY_HERE':
        print("❌ Please update the admin API key in the script")
        print("You can find it in your Typesense Cloud dashboard under 'Generate API Key'")
        return False
    
    url = f"{TYPESENSE_CONFIG['api_url']}/collections"
    headers = get_headers()
    
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            print("✅ API key is working!")
            return True
        else:
            print(f"❌ API key test failed: {response.status_code}")
            print(response.text)
            return False
    except Exception as e:
        print(f"❌ Exception testing API key: {e}")
        return False

def main():
    """Main menu"""
    print("🔧 Typesense Collection Manager")
    print("=" * 40)
    
    while True:
        print("\nOptions:")
        print("1. Test API key")
        print("2. List all collections")
        print("3. Get collection info")
        print("4. Delete collection")
        print("5. Exit")
        
        choice = input("\nEnter your choice (1-5): ").strip()
        
        if choice == '1':
            test_api_key()
        
        elif choice == '2':
            list_collections()
        
        elif choice == '3':
            collection_name = input("Enter collection name: ").strip()
            if collection_name:
                get_collection_info(collection_name)
        
        elif choice == '4':
            collection_name = input("Enter collection name to delete: ").strip()
            if collection_name:
                delete_collection(collection_name)
        
        elif choice == '5':
            print("👋 Goodbye!")
            break
        
        else:
            print("❌ Invalid choice. Please try again.")

if __name__ == "__main__":
    main()
