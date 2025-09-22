import Foundation
import Network

// A raw HTTP/1.1 client that completely bypasses URLSession
class RawHTTPClient {
    
    static func post(url: String, headers: [String: String], body: Data, completion: @escaping (Data?, Error?) -> Void) {
        guard let url = URL(string: url),
              let host = url.host,
              let port = url.port ?? (url.scheme == "https" ? 443 : 80) as Int? else {
            completion(nil, NSError(domain: "RawHTTPClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        let path = url.path.isEmpty ? "/" : url.path
        let query = url.query.map { "?\($0)" } ?? ""
        
        // Build raw HTTP/1.1 request
        var httpRequest = "POST \(path)\(query) HTTP/1.1\r\n"
        httpRequest += "Host: \(host)\r\n"
        httpRequest += "Connection: close\r\n"
        httpRequest += "Content-Length: \(body.count)\r\n"
        
        for (key, value) in headers {
            httpRequest += "\(key): \(value)\r\n"
        }
        
        httpRequest += "\r\n"
        
        print("🌐 Raw HTTP request:")
        print(httpRequest)
        
        // Convert to data and append body
        guard var requestData = httpRequest.data(using: .utf8) else {
            completion(nil, NSError(domain: "RawHTTPClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request"]))
            return
        }
        requestData.append(body)
        
        // Use Network framework for raw TCP connection
        let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)), using: url.scheme == "https" ? .tls : .tcp)
        
        connection.start(queue: .global())
        
        connection.send(content: requestData, completion: .contentProcessed { error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            // Read response
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                connection.cancel()
                
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                guard let data = data else {
                    completion(nil, NSError(domain: "RawHTTPClient", code: -3, userInfo: [NSLocalizedDescriptionKey: "No response data"]))
                    return
                }
                
                // Parse HTTP response
                let responseString = String(data: data, encoding: .utf8) ?? ""
                print("📥 Raw HTTP response:")
                print(responseString)
                
                // Extract body from HTTP response
                if let bodyStart = responseString.range(of: "\r\n\r\n") {
                    let bodyString = String(responseString[bodyStart.upperBound...])
                    let bodyData = bodyString.data(using: .utf8) ?? Data()
                    completion(bodyData, nil)
                } else {
                    completion(data, nil)
                }
            }
        })
    }
}
