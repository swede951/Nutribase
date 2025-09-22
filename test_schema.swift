#!/usr/bin/env swift

import Foundation

// Simple script to inspect Typesense schema
let service = TypesenseDirectService.shared

print("🔍 Inspecting Typesense schema...")

service.inspectSchema { schema, error in
    if let error = error {
        print("❌ Error: \(error.localizedDescription)")
    } else if let schema = schema {
        print("✅ Schema retrieved successfully!")
        
        // Print the full schema for analysis
        if let data = try? JSONSerialization.data(withJSONObject: schema, options: .prettyPrinted),
           let jsonString = String(data: data, encoding: .utf8) {
            print("\n📋 Full Schema:")
            print(jsonString)
        }
    }
    
    // Exit the script
    exit(0)
}

// Keep the script running
RunLoop.main.run()
