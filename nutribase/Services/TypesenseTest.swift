import Foundation

/// A simple utility class to test Typesense connectivity
class TypesenseTest {
    
    /// Test the Typesense connection with detailed logging
    static func testConnection() {
        // Configuration
        let apiURL = "https://h8ugnjal1c65sm2op-1.a1.typesense.net"
        let apiKey = "t5mEztNYGfzSotyavuBpucB5rPmtEMh"
        
        print("🔍 Testing Typesense connection...")
        print("🌐 API URL: \(apiURL)")
        print("🔑 API Key: \(apiKey.prefix(4))...")
        
        // 1. Test the health endpoint
        testHealthEndpoint(apiURL: apiURL, apiKey: apiKey)
        
        // 2. List all collections to verify names
        listAllCollections(apiURL: apiURL, apiKey: apiKey)
        
        // 3. Test collection existence
        testCollectionExists(apiURL: apiURL, apiKey: apiKey, collectionName: "foods")
        
        // 4. Test a simple search
        testSimpleSearch(apiURL: apiURL, apiKey: apiKey)
    }
    
    /// Test the health endpoint
    private static func testHealthEndpoint(apiURL: String, apiKey: String) {
        guard let url = URL(string: "\(apiURL)/health") else {
            print("❌ Invalid health URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        print("\n📡 Testing health endpoint: \(url.absoluteString)")
        
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Health check failed with error: \(error.localizedDescription)")
                semaphore.signal()
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Health check HTTP status: \(httpResponse.statusCode)")
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📝 Health check response: \(responseString)")
            }
            
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 10)
    }
    
    /// Test if a collection exists
    private static func testCollectionExists(apiURL: String, apiKey: String, collectionName: String) {
        guard let url = URL(string: "\(apiURL)/collections/\(collectionName)") else {
            print("❌ Invalid collection URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        print("\n📡 Testing collection existence: \(url.absoluteString)")
        
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Collection check failed with error: \(error.localizedDescription)")
                semaphore.signal()
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Collection check HTTP status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    print("✅ Collection '\(collectionName)' exists")
                } else {
                    print("❌ Collection '\(collectionName)' not found or not accessible")
                }
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📝 Collection check response: \(responseString)")
            }
            
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 10)
    }
    
    /// List all collections to verify their names
    private static func listAllCollections(apiURL: String, apiKey: String) {
        // Try with API key as query parameter
        guard var urlComponents = URLComponents(string: "\(apiURL)/collections") else {
            print("❌ Invalid collections URL")
            return
        }
        
        // Add API key as query parameter
        urlComponents.queryItems = [URLQueryItem(name: "x-typesense-api-key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            print("❌ Failed to create URL with query parameters")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Also set the header for good measure
        request.setValue(apiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        print("\n📡 Listing all collections: \(url.absoluteString)")
        
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Collection listing failed with error: \(error.localizedDescription)")
                semaphore.signal()
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Collection listing HTTP status: \(httpResponse.statusCode)")
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📝 Available collections: \(responseString)")
                
                // Try to parse the JSON to extract collection names
                do {
                    if let collections = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        print("📋 Collection names:")
                        for collection in collections {
                            if let name = collection["name"] as? String {
                                print("   - \(name)")
                            }
                        }
                    }
                } catch {
                    print("❌ Failed to parse collections JSON: \(error)")
                }
            }
            
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 10)
    }
    
    /// Test a simple search
    private static func testSimpleSearch(apiURL: String, apiKey: String) {
        // Try multiple collection names in case "foods" isn't the exact name
        let possibleCollectionNames = ["foods", "food", "Foods", "Food"]
        
        for collectionName in possibleCollectionNames {
            print("\n🔍 Testing search with collection name: \(collectionName)")
            searchInCollection(apiURL: apiURL, apiKey: apiKey, collectionName: collectionName)
        }
    }
    
    /// Search in a specific collection
    private static func searchInCollection(apiURL: String, apiKey: String, collectionName: String) {
        // Try with API key as query parameter
        guard var urlComponents = URLComponents(string: "\(apiURL)/collections/\(collectionName)/documents/search") else {
            print("❌ Invalid search URL")
            return
        }
        
        // Add API key as query parameter
        urlComponents.queryItems = [URLQueryItem(name: "x-typesense-api-key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            print("❌ Failed to create URL with query parameters")
            return
        }
        
        // Simple search parameters
        let searchParams: [String: Any] = [
            "q": "cheese",
            "query_by": "name",
            "per_page": 5
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: searchParams) else {
            print("❌ Failed to serialize search parameters")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        // Print request details
        print("📡 Testing search: \(url.absoluteString)")
        print("🔑 Using API key: \(apiKey)")
        print("📦 Search parameters: \(searchParams)")
        print("📝 Headers: Content-Type=application/json, X-TYPESENSE-API-KEY=\(apiKey.prefix(4))...")
        
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Search test failed with error: \(error.localizedDescription)")
                semaphore.signal()
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Search test HTTP status: \(httpResponse.statusCode)")
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📝 Search test response: \(responseString)")
            }
            
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 10)
    }
}
