import Foundation
import Network

// A very basic HTTP client that avoids iOS's automatic HTTP/3 negotiation
class BasicHTTPClient {
    
    static func post(url: String, headers: [String: String], body: Data, completion: @escaping (Data?, Error?) -> Void) {
        guard let url = URL(string: url) else {
            completion(nil, NSError(domain: "BasicHTTPClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        // Create a very basic URLSession configuration
        let config = URLSessionConfiguration.default
        
        // Disable all modern protocols and features
        config.protocolClasses = []
        config.httpMaximumConnectionsPerHost = 1
        config.allowsCellularAccess = true
        config.allowsConstrainedNetworkAccess = false
        config.allowsExpensiveNetworkAccess = false
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringCacheData
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        
        let session = URLSession(configuration: config)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        
        // Add headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Force connection close to prevent keep-alive
        request.setValue("close", forHTTPHeaderField: "Connection")
        
        print("🌐 Making request to: \(url)")
        print("📤 Headers: \(headers)")
        
        session.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status: \(httpResponse.statusCode)")
                print("📡 Response headers: \(httpResponse.allHeaderFields)")
            }
            
            if let error = error {
                print("❌ Network error: \(error)")
            }
            
            if let data = data {
                print("📥 Response data: \(String(data: data, encoding: .utf8) ?? "No readable data")")
            }
            
            completion(data, error)
        }.resume()
    }
}
