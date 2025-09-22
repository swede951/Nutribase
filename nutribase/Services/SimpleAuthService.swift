import Foundation
import Combine

// Simple user structure
struct SimpleAuthUser: Codable {
    let id: String
    let email: String?
}

// Simple auth response structure
struct SimpleAuthResponse: Codable {
    let access_token: String
    let refresh_token: String
    let user: SimpleAuthUser
}

// Simple, focused authentication service
class SimpleAuthService: ObservableObject {
    static let shared = SimpleAuthService()
    
    @Published var isAuthenticated = false
    @Published var authError: String?
    @Published var isLoading = false
    
    private let accessTokenKey = "supabase_access_token"
    private let refreshTokenKey = "supabase_refresh_token"
    private let userKey = "supabase_user"
    
    var accessToken: String?
    var refreshToken: String?
    var currentUser: SimpleAuthUser?
    
    private init() {
        loadAuthState()
    }
    
    // Simple sign-in method
    func signIn(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        authError = nil
        
        let url = "\(SupabaseConfig.apiURL)/auth/v1/token?grant_type=password"
        
        // Headers
        let headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(SupabaseConfig.apiKey)",
            "apikey": SupabaseConfig.apiKey
        ]
        
        // JSON body (no grant_type in body since it's in URL)
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            DispatchQueue.main.async {
                self.isLoading = false
                completion(false, "Failed to encode request body")
            }
            return
        }
        
        print("🚀 Using HTTP/1.1 client to avoid protocol violations...")
        
        // Use HTTP/1.1 client to bypass URLSession HTTP/3 issues
        HTTP1Client.post(url: url, headers: headers, body: bodyData) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("❌ HTTP/1.1 request failed: \(error.localizedDescription)")
                    self?.authError = error.localizedDescription
                    completion(false, error.localizedDescription)
                    return
                }
                
                guard let data = data else {
                    let errorMessage = "No data received"
                    self?.authError = errorMessage
                    completion(false, errorMessage)
                    return
                }
                
                guard let httpResponse = response else {
                    print("❌ Invalid response object")
                    self?.authError = "Invalid response"
                    completion(false, "Invalid response")
                    return
                }
                
                print("🔄 HTTP status code: \(httpResponse.statusCode)")
                
                let responseString = String(data: data, encoding: .utf8) ?? "(no response string)"
                print("📦 Response body: \(responseString)")
                
                // First try to decode as successful AuthResponse (regardless of status code)
                // Try to decode as SimpleAuthResponse
                do {
                    let authResponse = try JSONDecoder().decode(SimpleAuthResponse.self, from: data)
                    print("✅ Auth success: \(authResponse.user.email ?? "unknown")")
                    self?.saveAuthState(authResponse)
                    
                    // Post notification for UserProfile
                    NotificationCenter.default.post(name: NSNotification.Name("userDidSignIn"), object: nil)
                    
                    completion(true, nil)
                    return
                } catch {
                    print("❌ JSON decode as AuthResponse failed: \(error)")
                }
                
                // If that fails, try to decode as error response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let message = json["msg"] as? String ?? json["message"] as? String ?? "Authentication failed"
                    self?.authError = message
                    completion(false, message)
                } else {
                    self?.authError = "Authentication failed: \(responseString)"
                    completion(false, "Authentication failed: \(responseString)")
                }
            }
        }
    }
    

    private func saveAuthState(_ auth: SimpleAuthResponse) {
        self.accessToken = auth.access_token
        self.refreshToken = auth.refresh_token
        self.currentUser = auth.user
        self.isAuthenticated = true
        self.authError = nil
        
        // Save to UserDefaults
        UserDefaults.standard.set(auth.access_token, forKey: accessTokenKey)
        UserDefaults.standard.set(auth.refresh_token, forKey: refreshTokenKey)
        if let userData = try? JSONEncoder().encode(auth.user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
        
        // Notify other parts of the app
        NotificationCenter.default.post(name: .userDidSignIn, object: nil)
    }
    
    private func loadAuthState() {
        accessToken = UserDefaults.standard.string(forKey: accessTokenKey)
        refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey)
        
        if let userData = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(SimpleAuthUser.self, from: userData) {
            currentUser = user
            isAuthenticated = true
        }
    }
    
    func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = refreshToken else {
            completion(false)
            return
        }
        
        let url = "\(SupabaseConfig.apiURL)/auth/v1/token?grant_type=refresh_token"
        
        let headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(SupabaseConfig.apiKey)",
            "apikey": SupabaseConfig.apiKey
        ]
        
        let body: [String: Any] = [
            "refresh_token": refreshToken
        ]
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(false)
            return
        }
        
        HTTP1Client.post(url: url, headers: headers, body: bodyData) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let data = data,
                      let authResponse = try? JSONDecoder().decode(SimpleAuthResponse.self, from: data) else {
                    completion(false)
                    return
                }
                
                self?.saveAuthState(authResponse)
                completion(true)
            }
        }
    }
    
    func signOut() {
        accessToken = nil
        refreshToken = nil
        currentUser = nil
        isAuthenticated = false
        authError = nil
        
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        
        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
    }
}

// Notification extensions
extension Notification.Name {
    static let userDidSignIn = Notification.Name("userDidSignIn")
    static let userDidSignOut = Notification.Name("userDidSignOut")
}
