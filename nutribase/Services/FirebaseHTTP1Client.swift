import Foundation
import Network

/// HTTP/1.1 client for Firebase Analytics to bypass iOS HTTP/3 issues
class FirebaseHTTP1Client {
    
    static func sendBatchLog(
        url: String,
        apiKey: String,
        payload: [String: Any],
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard let parsedURL = URL(string: url),
              let host = parsedURL.host,
              let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            completion(false, NSError(domain: "FirebaseHTTP1Client", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid request"]))
            return
        }
        
        let port = parsedURL.port ?? 443
        let path = parsedURL.path.isEmpty ? "/" : parsedURL.path
        let query = parsedURL.query.map { "?\($0)" } ?? ""
        
        // Create HTTP/1.1 POST request
        var httpRequest = "POST \(path)\(query) HTTP/1.1\r\n"
        httpRequest += "Host: \(host)\r\n"
        httpRequest += "Connection: close\r\n"
        httpRequest += "Content-Type: application/json\r\n"
        httpRequest += "X-Goog-Api-Key: \(apiKey)\r\n"
        httpRequest += "Content-Length: \(jsonData.count)\r\n"
        httpRequest += "\r\n"
        
        var requestData = httpRequest.data(using: .utf8) ?? Data()
        requestData.append(jsonData)
        
        #if DEBUG
        print("🔥 Firebase HTTP/1.1 Request to \(host)")
        #endif
        
        // Use NWConnection for HTTPS
        let tlsOptions = NWProtocolTLS.Options()
        let parameters = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)), using: parameters)
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: requestData, completion: .contentProcessed { error in
                    if let error = error {
                        completion(false, error)
                        return
                    }
                    
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 1048576) { data, _, _, error in
                        connection.cancel()
                        
                        if let error = error {
                            completion(false, error)
                            return
                        }
                        
                        guard let data = data else {
                            completion(false, NSError(domain: "FirebaseHTTP1Client", code: -2, userInfo: [NSLocalizedDescriptionKey: "No response"]))
                            return
                        }
                        
                        let responseString = String(data: data, encoding: .utf8) ?? ""
                        let statusCode = extractStatusCode(from: responseString)
                        
                        #if DEBUG
                        print("📥 Firebase response status: \(statusCode)")
                        #endif
                        
                        completion(200...299 ~= statusCode, nil)
                    }
                })
                
            case .failed(let error):
                completion(false, error)
                
            default:
                break
            }
        }
        
        connection.start(queue: .global())
    }
    
    private static func extractStatusCode(from response: String) -> Int {
        let lines = response.components(separatedBy: "\r\n")
        guard let statusLine = lines.first else { return -1 }
        
        let components = statusLine.components(separatedBy: " ")
        guard components.count >= 2 else { return -1 }
        
        return Int(components[1]) ?? -1
    }
}
