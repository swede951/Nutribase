import Foundation

/// A test class that uses the Typesense API directly with URLSession
class TypesenseClientTest {
    
    /// Test the Typesense connection with various authentication methods
    static func testConnection() {
        // Configuration
        let apiURL = "https://h8ugnjal1c65sm2op-1.a1.typesense.net"
        let apiKey = "t5mEztNYGfzSotyavuBpucB5rPmtEMh"
        
        print("\n🔄 Testing Typesense with multiple authentication methods...")
        
        // 1. Test with standard header
        testWithStandardHeader(apiURL: apiURL, apiKey: apiKey)
        
        // 2. Test with lowercase header
        testWithLowercaseHeader(apiURL: apiURL, apiKey: apiKey)
        
        // 3. Test with query parameter
        testWithQueryParameter(apiURL: apiURL, apiKey: apiKey)
        
        // 4. Test with both header and query parameter
        testWithBothMethods(apiURL: apiURL, apiKey: apiKey)
    }
    
    /// Test with standard X-TYPESENSE-API-KEY header
    private static func testWithStandardHeader(apiURL: String, apiKey: String) {
        print("\n🔍 Testing with standard header X-TYPESENSE-API-KEY")
        
        guard let url = URL(string: "\(apiURL)/collections") else {
            print("❌ Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error: \(error.localizedDescription)")
                semaphore.signal()
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 HTTP Status: \(httpResponse.statusCode)")
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📝 Response: \(responseString)")
            }
            
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 10)
    }
    
    /// Test with lowercase x-typesense-api-key header
    private static func testWithLowercaseHeader(apiURL: String, apiKey: String) {
        print("\n🔍 Testing with lowercase header x-typesense-api-key")
        
        guard let url = URL(string: "\(apiURL)/collections") else {
            print("❌ Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-typesense-api-key")
        
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error: \(error.localizedDescription)")
                semaphore.signal()
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 HTTP Status: \(httpResponse.statusCode)")
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📝 Response: \(responseString)")
            }
            
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 10)
    }
    
    /// Test with API key as query parameter
    private static func testWithQueryParameter(apiURL: String, apiKey: String) {
        print("\n🔍 Testing with API key as query parameter")
        
        guard var urlComponents = URLComponents(string: "\(apiURL)/collections") else {
            print("❌ Invalid URL")
            return
        }
        
        urlComponents.queryItems = [URLQueryItem(name: "x-typesense-api-key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            print("❌ Failed to create URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error: \(error.localizedDescription)")
                semaphore.signal()
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 HTTP Status: \(httpResponse.statusCode)")
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📝 Response: \(responseString)")
            }
            
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 10)
    }
    
    /// Test with both header and query parameter
    private static func testWithBothMethods(apiURL: String, apiKey: String) {
        print("\n🔍 Testing with both header and query parameter")
        
        guard var urlComponents = URLComponents(string: "\(apiURL)/collections") else {
            print("❌ Invalid URL")
            return
        }
        
        urlComponents.queryItems = [URLQueryItem(name: "x-typesense-api-key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            print("❌ Failed to create URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error: \(error.localizedDescription)")
                semaphore.signal()
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 HTTP Status: \(httpResponse.statusCode)")
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📝 Response: \(responseString)")
            }
            
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 10)
    }
}
