#!/usr/bin/env python3
"""
Add Nutri-Score columns to the Supabase foods table
"""

import requests

# Supabase configuration
SUPABASE_URL = "https://owmwxzkzqrbhhiofzgmm.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93bXd4emt6cXJiaGhpb2Z6Z21tIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzI0MjEwMiwiZXhwIjoyMDYyODE4MTAyfQ.5XKQo-XEWaRXVUPP4wdRj5W-KA9vluuZJPtwIknJo4k"

def add_nutriscore_columns():
    """
    Add Nutri-Score columns to the Supabase foods table
    
    Note: This uses the PostgREST API to execute SQL commands through Supabase's REST API
    """
    print("Adding Nutri-Score columns to the foods table...")
    
    # First, let's check if the columns already exist
    check_endpoint = f"{SUPABASE_URL}/rest/v1/rpc/check_columns_exist"
    check_payload = {
        "table_name": "foods",
        "column_names": ["nutriscore_score", "nutriscore_grade"]
    }
    
    headers = {
        'apikey': SUPABASE_KEY,
        'Authorization': f'Bearer {SUPABASE_KEY}',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation'
    }
    
    try:
        # First, let's try a simpler approach - get one row to see the schema
        get_endpoint = f"{SUPABASE_URL}/rest/v1/foods?limit=1"
        response = requests.get(get_endpoint, headers=headers)
        
        if response.status_code == 200:
            # Check if columns exist in the response
            sample_row = response.json()
            if sample_row:
                has_score = 'nutriscore_score' in sample_row[0]
                has_grade = 'nutriscore_grade' in sample_row[0]
                
                if has_score and has_grade:
                    print("✅ Nutri-Score columns already exist in the foods table")
                    return True
        
        # If we're here, we need to add the columns
        # We'll use the SQL API to add the columns
        sql_endpoint = f"{SUPABASE_URL}/rest/v1/rpc/execute_sql"
        
        # Add nutriscore_score column (integer, nullable)
        score_sql = "ALTER TABLE foods ADD COLUMN IF NOT EXISTS nutriscore_score INTEGER NULL;"
        score_payload = {"sql_query": score_sql}
        
        score_response = requests.post(sql_endpoint, json=score_payload, headers=headers)
        if score_response.status_code in [200, 201, 204]:
            print("✅ Added nutriscore_score column")
        else:
            print(f"❌ Failed to add nutriscore_score column: {score_response.status_code}")
            print(score_response.text)
            return False
        
        # Add nutriscore_grade column (char(1), nullable)
        grade_sql = "ALTER TABLE foods ADD COLUMN IF NOT EXISTS nutriscore_grade VARCHAR(1) NULL;"
        grade_payload = {"sql_query": grade_sql}
        
        grade_response = requests.post(sql_endpoint, json=grade_payload, headers=headers)
        if grade_response.status_code in [200, 201, 204]:
            print("✅ Added nutriscore_grade column")
            return True
        else:
            print(f"❌ Failed to add nutriscore_grade column: {grade_response.status_code}")
            print(grade_response.text)
            return False
            
    except Exception as e:
        print(f"Error adding Nutri-Score columns: {e}")
        return False

if __name__ == "__main__":
    add_nutriscore_columns()
