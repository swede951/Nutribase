import Foundation
import Network

class HTTP1Client {
    static func get(url: String, headers: [String: String], completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
        guard let parsedURL = URL(string: url),
              let host = parsedURL.host else {
            completion(nil, nil, NSError(domain: "HTTP1Client", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        let port = parsedURL.port ?? (parsedURL.scheme == "https" ? 443 : 80)
        let path = parsedURL.path.isEmpty ? "/" : parsedURL.path
        let query = parsedURL.query.map { "?\($0)" } ?? ""
        
        // Create HTTP/1.1 GET request manually
        var httpRequest = "GET \(path)\(query) HTTP/1.1\r\n"
        httpRequest += "Host: \(host)\r\n"
        httpRequest += "Connection: close\r\n"
        
        // Add custom headers
        for (key, value) in headers {
            httpRequest += "\(key): \(value)\r\n"
        }
        
        httpRequest += "\r\n"
        
        // Convert to data
        let requestData = httpRequest.data(using: .utf8) ?? Data()
        
        print("🌐 HTTP/1.1 GET Request:")
        print(httpRequest)
        
        // Use NWConnection for raw TCP/TLS
        let connection: NWConnection
        
        if parsedURL.scheme == "https" {
            let tlsOptions = NWProtocolTLS.Options()
            let tcpOptions = NWProtocolTCP.Options()
            let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
            connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)), using: parameters)
        } else {
            let parameters = NWParameters.tcp
            connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)), using: parameters)
        }
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✅ Connection established")
                // Send the request
                connection.send(content: requestData, completion: .contentProcessed { error in
                    if let error = error {
                        print("❌ Send error: \(error)")
                        completion(nil, nil, error)
                        return
                    }
                    
                    // Read the response
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 1048576) { data, _, isComplete, error in
                        connection.cancel()
                        
                        if let error = error {
                            print("❌ Receive error: \(error)")
                            completion(nil, nil, error)
                            return
                        }
                        
                        guard let data = data else {
                            completion(nil, nil, NSError(domain: "HTTP1Client", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                            return
                        }
                        
                        // Parse HTTP response
                        let responseString = String(data: data, encoding: .utf8) ?? ""
                        print("📥 Raw response:")
                        print(responseString)
                        
                        let (httpResponse, responseBody) = parseHTTPResponse(data: data, url: parsedURL)
                        completion(responseBody, httpResponse, nil)
                    }
                })
                
            case .failed(let error):
                print("❌ Connection failed: \(error)")
                completion(nil, nil, error)
                
            case .cancelled:
                print("🚫 Connection cancelled")
                
            default:
                break
            }
        }
        
        connection.start(queue: .global())
    }
    
    static func post(url: String, headers: [String: String], body: Data, completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
        guard let parsedURL = URL(string: url),
              let host = parsedURL.host else {
            completion(nil, nil, NSError(domain: "HTTP1Client", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        let port = parsedURL.port ?? (parsedURL.scheme == "https" ? 443 : 80)
        let path = parsedURL.path.isEmpty ? "/" : parsedURL.path
        let query = parsedURL.query.map { "?\($0)" } ?? ""
        
        // Create HTTP/1.1 request manually
        var httpRequest = "POST \(path)\(query) HTTP/1.1\r\n"
        httpRequest += "Host: \(host)\r\n"
        httpRequest += "Connection: close\r\n"
        
        // Add custom headers
        for (key, value) in headers {
            httpRequest += "\(key): \(value)\r\n"
        }
        
        httpRequest += "Content-Length: \(body.count)\r\n"
        httpRequest += "\r\n"
        
        // Convert to data and append body
        var requestData = httpRequest.data(using: .utf8) ?? Data()
        requestData.append(body)
        
        print("🌐 HTTP/1.1 Request:")
        print(httpRequest)
        print("📤 Body: \(String(data: body, encoding: .utf8) ?? "Binary data")")
        
        // Use NWConnection for raw TCP/TLS
        let connection: NWConnection
        
        if parsedURL.scheme == "https" {
            let tlsOptions = NWProtocolTLS.Options()
            let tcpOptions = NWProtocolTCP.Options()
            let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
            connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)), using: parameters)
        } else {
            let parameters = NWParameters.tcp
            connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)), using: parameters)
        }
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✅ Connection established")
                // Send the request
                connection.send(content: requestData, completion: .contentProcessed { error in
                    if let error = error {
                        print("❌ Send error: \(error)")
                        completion(nil, nil, error)
                        return
                    }
                    
                    // Read the response
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 1048576) { data, _, isComplete, error in
                        connection.cancel()
                        
                        if let error = error {
                            print("❌ Receive error: \(error)")
                            completion(nil, nil, error)
                            return
                        }
                        
                        guard let data = data else {
                            completion(nil, nil, NSError(domain: "HTTP1Client", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                            return
                        }
                        
                        // Parse HTTP response
                        let responseString = String(data: data, encoding: .utf8) ?? ""
                        print("📥 Raw response:")
                        print(responseString)
                        
                        let (httpResponse, responseBody) = parseHTTPResponse(data: data, url: parsedURL)
                        completion(responseBody, httpResponse, nil)
                    }
                })
                
            case .failed(let error):
                print("❌ Connection failed: \(error)")
                completion(nil, nil, error)
                
            case .cancelled:
                print("🚫 Connection cancelled")
                
            default:
                break
            }
        }
        
        connection.start(queue: .global())
    }
    
    static func patch(url: String, headers: [String: String], body: Data, completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
        guard let parsedURL = URL(string: url),
              let host = parsedURL.host else {
            completion(nil, nil, NSError(domain: "HTTP1Client", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        let port = parsedURL.port ?? (parsedURL.scheme == "https" ? 443 : 80)
        let path = parsedURL.path.isEmpty ? "/" : parsedURL.path
        let query = parsedURL.query.map { "?\($0)" } ?? ""
        
        // Create HTTP/1.1 PATCH request manually
        var httpRequest = "PATCH \(path)\(query) HTTP/1.1\r\n"
        httpRequest += "Host: \(host)\r\n"
        httpRequest += "Connection: close\r\n"
        
        // Add custom headers
        for (key, value) in headers {
            httpRequest += "\(key): \(value)\r\n"
        }
        
        httpRequest += "Content-Length: \(body.count)\r\n"
        httpRequest += "\r\n"
        
        // Convert to data and append body
        var requestData = httpRequest.data(using: .utf8) ?? Data()
        requestData.append(body)
        
        print("🌐 HTTP/1.1 PATCH Request:")
        print(httpRequest)
        print("📤 Body: \(String(data: body, encoding: .utf8) ?? "Binary data")")
        
        // Use NWConnection for raw TCP/TLS
        let connection: NWConnection
        
        if parsedURL.scheme == "https" {
            let tlsOptions = NWProtocolTLS.Options()
            let tcpOptions = NWProtocolTCP.Options()
            let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
            connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)), using: parameters)
        } else {
            let parameters = NWParameters.tcp
            connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)), using: parameters)
        }
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✅ Connection established")
                // Send the request
                connection.send(content: requestData, completion: .contentProcessed { error in
                    if let error = error {
                        print("❌ Send error: \(error)")
                        completion(nil, nil, error)
                        return
                    }
                    
                    // Read the response
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 1048576) { data, _, isComplete, error in
                        connection.cancel()
                        
                        if let error = error {
                            print("❌ Receive error: \(error)")
                            completion(nil, nil, error)
                            return
                        }
                        
                        guard let data = data else {
                            completion(nil, nil, NSError(domain: "HTTP1Client", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                            return
                        }
                        
                        // Parse HTTP response
                        let responseString = String(data: data, encoding: .utf8) ?? ""
                        print("📥 Raw response:")
                        print(responseString)
                        
                        let (httpResponse, responseBody) = parseHTTPResponse(data: data, url: parsedURL)
                        completion(responseBody, httpResponse, nil)
                    }
                })
                
            case .failed(let error):
                print("❌ Connection failed: \(error)")
                completion(nil, nil, error)
                
            case .cancelled:
                print("🚫 Connection cancelled")
                
            default:
                break
            }
        }
        
        connection.start(queue: .global())
    }
    
    static func delete(url: String, headers: [String: String], completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
        guard let parsedURL = URL(string: url),
              let host = parsedURL.host else {
            completion(nil, nil, NSError(domain: "HTTP1Client", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        let port = parsedURL.port ?? (parsedURL.scheme == "https" ? 443 : 80)
        let path = parsedURL.path.isEmpty ? "/" : parsedURL.path
        let query = parsedURL.query.map { "?\($0)" } ?? ""
        
        // Create HTTP/1.1 DELETE request manually
        var httpRequest = "DELETE \(path)\(query) HTTP/1.1\r\n"
        httpRequest += "Host: \(host)\r\n"
        httpRequest += "Connection: close\r\n"
        
        // Add custom headers
        for (key, value) in headers {
            httpRequest += "\(key): \(value)\r\n"
        }
        
        httpRequest += "\r\n"
        
        // Convert to data
        let requestData = httpRequest.data(using: .utf8) ?? Data()
        
        print("🌐 HTTP/1.1 DELETE Request:")
        print(httpRequest)
        
        // Use NWConnection for raw TCP/TLS
        let connection: NWConnection
        
        if parsedURL.scheme == "https" {
            let tlsOptions = NWProtocolTLS.Options()
            let tcpOptions = NWProtocolTCP.Options()
            let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
            connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)), using: parameters)
        } else {
            let parameters = NWParameters.tcp
            connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)), using: parameters)
        }
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✅ Connection established")
                // Send the request
                connection.send(content: requestData, completion: .contentProcessed { error in
                    if let error = error {
                        print("❌ Send error: \(error)")
                        completion(nil, nil, error)
                        return
                    }
                    
                    // Read the response
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 1048576) { data, _, isComplete, error in
                        connection.cancel()
                        
                        if let error = error {
                            print("❌ Receive error: \(error)")
                            completion(nil, nil, error)
                            return
                        }
                        
                        guard let data = data else {
                            completion(nil, nil, NSError(domain: "HTTP1Client", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                            return
                        }
                        
                        // Parse HTTP response
                        let responseString = String(data: data, encoding: .utf8) ?? ""
                        print("📥 Raw response:")
                        print(responseString)
                        
                        let (httpResponse, responseBody) = parseHTTPResponse(data: data, url: parsedURL)
                        completion(responseBody, httpResponse, nil)
                    }
                })
                
            case .failed(let error):
                print("❌ Connection failed: \(error)")
                completion(nil, nil, error)
                
            case .cancelled:
                print("🚫 Connection cancelled")
                
            default:
                break
            }
        }
        
        connection.start(queue: .global())
    }
    
    private static func parseHTTPResponse(data: Data, url: URL) -> (HTTPURLResponse?, Data?) {
        let responseString = String(data: data, encoding: .utf8) ?? ""
        
        // Split by double CRLF to separate headers from body
        let parts = responseString.components(separatedBy: "\r\n\r\n")
        guard parts.count >= 2 else {
            print("❌ Invalid HTTP response format")
            return (nil, nil)
        }
        
        let headerPart = parts[0]
        var bodyPart = parts.dropFirst().joined(separator: "\r\n\r\n")
        
        let headerLines = headerPart.components(separatedBy: "\r\n")
        guard let statusLine = headerLines.first,
              let statusCode = extractStatusCode(from: statusLine) else {
            print("❌ Could not parse status line: \(headerLines.first ?? "none")")
            return (nil, nil)
        }
        
        print("✅ Parsed status code: \(statusCode)")
        
        // Handle chunked transfer encoding - remove chunk size indicators
        if bodyPart.contains("\r\n") {
            let lines = bodyPart.components(separatedBy: "\r\n")
            var cleanBody = ""
            
            for line in lines {
                // Skip lines that are just hex numbers (chunk sizes)
                if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                
                // Check if line is a hex number (chunk size)
                if Int(line.trimmingCharacters(in: .whitespacesAndNewlines), radix: 16) != nil {
                    continue
                }
                
                // This should be actual content
                cleanBody += line
            }
            
            bodyPart = cleanBody
        }
        
        print("📦 Clean body: \(bodyPart.prefix(100))...") // Show first 100 chars
        
        // Create body data
        let bodyData = bodyPart.data(using: .utf8)
        
        // Create HTTPURLResponse
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: [:]
        )
        
        return (response, bodyData)
    }
    
    private static func extractStatusCode(from statusLine: String) -> Int? {
        print("🔍 Status line: '\(statusLine)'")
        let components = statusLine.components(separatedBy: " ")
        print("🔍 Components: \(components)")
        guard components.count >= 2 else { 
            print("❌ Not enough components in status line")
            return nil 
        }
        let statusCode = Int(components[1])
        print("🔍 Extracted status code: \(statusCode ?? -1)")
        return statusCode
    }
}
