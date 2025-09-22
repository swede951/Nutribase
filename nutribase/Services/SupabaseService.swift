import Foundation
import Combine

// Configuration for Supabase connection
struct SupabaseConfig {
    static let apiURL = "https://owmwxzkzqrbhhiofzgmm.supabase.co"
    static let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93bXd4emt6cXJiaGhpb2Z6Z21tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDcyNDIxMDIsImV4cCI6MjA2MjgxODEwMn0.NkZ7ffPEG6BT_xNEsWsbDc0BoOQrpYUDDLJ0hwDX5-0"
}

// Simple service for basic Supabase operations
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    @Published var isLoading = false
    
    // Custom URLSession configured for HTTP/1.1
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 1
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    // MARK: - User Profile Methods
    
    func saveUserProfile(_ profileData: [String: Any], completion: @escaping (Bool) -> Void) {
        // First try to update existing record
        updateUserProfile(profileData) { updateSuccess in
            if updateSuccess {
                completion(true)
            } else {
                // If update fails, try insert
                self.insertUserProfile(profileData, completion: completion)
            }
        }
    }
    
    private func updateUserProfile(_ profileData: [String: Any], completion: @escaping (Bool) -> Void) {
        guard let userId = profileData["user_id"] as? String,
              let url = URL(string: "\(SupabaseConfig.apiURL)/rest/v1/user_settings?user_id=eq.\(userId)") else {
            completion(false)
            return
        }
        
        var headers: [String: String] = [
            "Content-Type": "application/json",
            "apikey": SupabaseConfig.apiKey,
            "Connection": "close"
        ]
        
        if let accessToken = SimpleAuthService.shared.accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: profileData)
            HTTP1Client.patch(url: url.absoluteString, headers: headers, body: bodyData) { data, response, error in
                DispatchQueue.main.async {
                    if let httpResponse = response {
                        if httpResponse.statusCode == 401 {
                            // Token expired, try to refresh
                            SimpleAuthService.shared.refreshAccessToken { refreshSuccess in
                                if refreshSuccess {
                                    // Retry with new token
                                    self.updateUserProfile(profileData, completion: completion)
                                } else {
                                    completion(false)
                                }
                            }
                            return
                        } else if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                            print("✅ Profile updated in Supabase")
                            completion(true)
                            return
                        } else if httpResponse.statusCode == 404 {
                            // No existing record found, signal to try insert
                            completion(false)
                            return
                        }
                    }
                    completion(false)
                }
            }
        } catch {
            completion(false)
        }
    }
    
    private func insertUserProfile(_ profileData: [String: Any], completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(SupabaseConfig.apiURL)/rest/v1/user_settings") else {
            completion(false)
            return
        }
        
        var headers: [String: String] = [
            "Content-Type": "application/json",
            "apikey": SupabaseConfig.apiKey,
            "Connection": "close"
        ]
        
        if let accessToken = SimpleAuthService.shared.accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: profileData)
            HTTP1Client.post(url: url.absoluteString, headers: headers, body: bodyData) { data, response, error in
                DispatchQueue.main.async {
                    if let httpResponse = response {
                        if httpResponse.statusCode == 409 {
                            // Duplicate key - record already exists, this is actually success
                            print("✅ Profile already exists in Supabase (409 expected)")
                            completion(true)
                            return
                        } else if httpResponse.statusCode == 201 {
                            print("✅ Profile inserted to Supabase")
                            completion(true)
                            return
                        }
                    }
                    
                    if let error = error {
                        print("❌ Profile insert error: \(error.localizedDescription)")
                    }
                    completion(false)
                }
            }
        } catch {
            print("❌ Failed to encode profile data: \(error)")
            completion(false)
        }
    }
    
    func loadUserProfile(completion: @escaping ([String: Any]?) -> Void) {
        // Get the current authenticated user ID
        guard let currentUser = SimpleAuthService.shared.currentUser,
              let url = URL(string: "\(SupabaseConfig.apiURL)/rest/v1/user_settings?user_id=eq.\(currentUser.id)&limit=1") else {
            print("❌ No authenticated user or invalid URL for profile fetch")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.setValue("close", forHTTPHeaderField: "Connection")
        
        // Get JWT token for authentication
        var headers: [String: String] = [
            "apikey": SupabaseConfig.apiKey,
            "Connection": "close"
        ]
        
        // Add Authorization header if user is authenticated
        if let accessToken = SimpleAuthService.shared.accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        
        HTTP1Client.get(url: url.absoluteString, headers: headers) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Profile fetch error: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let profileData = jsonArray.first {
                    DispatchQueue.main.async {
                        completion(profileData)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            } catch {
                print("❌ Failed to parse profile data: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - Weight Logs Methods
    
    func saveWeightLogs(_ weightLogs: [[String: Any]], completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(SupabaseConfig.apiURL)/rest/v1/weight_logs") else {
            completion(false)
            return
        }
        
        var headers: [String: String] = [
            "Content-Type": "application/json",
            "apikey": SupabaseConfig.apiKey,
            "Connection": "close",
            "Prefer": "resolution=merge-duplicates"
        ]
        
        if let accessToken = SimpleAuthService.shared.accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: weightLogs)
            HTTP1Client.post(url: url.absoluteString, headers: headers, body: bodyData) { data, response, error in
                DispatchQueue.main.async {
                    if let httpResponse = response {
                        print("[SupabaseService] Weight logs save response: \(httpResponse.statusCode)")
                        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 || httpResponse.statusCode == 409 {
                            print("✅ Weight logs saved to Supabase (\(weightLogs.count) entries)")
                            completion(true)
                            return
                        } else if httpResponse.statusCode == 401 {
                            print("❌ JWT token expired, attempting refresh...")
                            SimpleAuthService.shared.refreshAccessToken { success in
                                if success {
                                    // Retry the request with new token
                                    self.saveWeightLogs(weightLogs, completion: completion)
                                } else {
                                    completion(false)
                                }
                            }
                            return
                        }
                    }
                    
                    if let error = error {
                        print("❌ Weight logs save error: \(error.localizedDescription)")
                    }
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Weight logs save response: \(responseString)")
                    }
                    completion(false)
                }
            }
        } catch {
            print("❌ Failed to encode weight logs: \(error)")
            completion(false)
        }
    }
    
    func loadWeightLogs(completion: @escaping ([[String: Any]]?) -> Void) {
        guard let url = URL(string: "\(SupabaseConfig.apiURL)/rest/v1/weight_logs?order=date.desc&limit=100") else {
            completion(nil)
            return
        }
        
        var headers: [String: String] = [
            "apikey": SupabaseConfig.apiKey,
            "Connection": "close"
        ]
        
        if let accessToken = SimpleAuthService.shared.accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        
        HTTP1Client.get(url: url.absoluteString, headers: headers) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Weight logs fetch error: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // Debug: Print raw response to identify malformed JSON
            if let responseString = String(data: data, encoding: .utf8) {
                print("📦 Raw weight logs response: \(responseString.prefix(500))...")
            }
            
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    DispatchQueue.main.async {
                        completion(jsonArray)
                    }
                } else {
                    print("❌ Weight logs response is not a valid JSON array")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            } catch {
                print("❌ Failed to parse weight logs: \(error)")
                // Try to clean the JSON by removing potential problematic characters
                if let responseString = String(data: data, encoding: .utf8) {
                    let cleanedString = responseString.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
                    if let cleanedData = cleanedString.data(using: .utf8) {
                        do {
                            if let jsonArray = try JSONSerialization.jsonObject(with: cleanedData) as? [[String: Any]] {
                                print("✅ Successfully parsed cleaned JSON")
                                DispatchQueue.main.async {
                                    completion(jsonArray)
                                }
                                return
                            }
                        } catch {
                            print("❌ Even cleaned JSON failed to parse: \(error)")
                        }
                    }
                }
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    func deleteWeightLogs(_ weightLogs: [[String: Any]], completion: @escaping (Bool) -> Void) {
        guard !weightLogs.isEmpty else {
            completion(true)
            return
        }
        
        // Delete entries one by one using user_id and date as composite key
        deleteWeightLogsBatch(weightLogs, currentIndex: 0, completion: completion)
    }
    
    private func deleteWeightLogsBatch(_ weightLogs: [[String: Any]], currentIndex: Int, completion: @escaping (Bool) -> Void) {
        guard currentIndex < weightLogs.count else {
            completion(true)
            return
        }
        
        let weightLog = weightLogs[currentIndex]
        guard let userId = weightLog["user_id"] as? String,
              let date = weightLog["date"] as? String else {
            // Skip invalid entry and continue
            deleteWeightLogsBatch(weightLogs, currentIndex: currentIndex + 1, completion: completion)
            return
        }
        
        let encodedUserId = userId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? userId
        let encodedDate = date.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? date
        
        guard let url = URL(string: "\(SupabaseConfig.apiURL)/rest/v1/weight_logs?user_id=eq.\(encodedUserId)&date=eq.\(encodedDate)") else {
            deleteWeightLogsBatch(weightLogs, currentIndex: currentIndex + 1, completion: completion)
            return
        }
        
        var headers: [String: String] = [
            "apikey": SupabaseConfig.apiKey,
            "Connection": "close"
        ]
        
        if let accessToken = SimpleAuthService.shared.accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        
        HTTP1Client.delete(url: url.absoluteString, headers: headers) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response {
                    if httpResponse.statusCode == 204 || httpResponse.statusCode == 404 {
                        print("✅ Weight log deleted from Supabase: \(date)")
                        // Continue with next entry
                        self.deleteWeightLogsBatch(weightLogs, currentIndex: currentIndex + 1, completion: completion)
                        return
                    } else if httpResponse.statusCode == 401 {
                        print("❌ JWT token expired during deletion, attempting refresh...")
                        SimpleAuthService.shared.refreshAccessToken { success in
                            if success {
                                // Retry the deletion with new token
                                self.deleteWeightLogsBatch(weightLogs, currentIndex: currentIndex, completion: completion)
                            } else {
                                completion(false)
                            }
                        }
                        return
                    }
                }
                
                if let error = error {
                    print("❌ Weight log deletion error: \(error.localizedDescription)")
                }
                
                // Continue with next entry even if this one failed
                self.deleteWeightLogsBatch(weightLogs, currentIndex: currentIndex + 1, completion: completion)
            }
        }
    }
    
    // MARK: - Weight Phases Methods
    
    func saveWeightPhases(_ phases: [[String: Any]], completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(SupabaseConfig.apiURL)/rest/v1/weight_phases") else {
            completion(false)
            return
        }
        
        var headers: [String: String] = [
            "Content-Type": "application/json",
            "apikey": SupabaseConfig.apiKey,
            "Connection": "close",
            "Prefer": "resolution=merge-duplicates"
        ]
        
        if let accessToken = SimpleAuthService.shared.accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: phases)
            HTTP1Client.post(url: url.absoluteString, headers: headers, body: bodyData) { data, response, error in
                DispatchQueue.main.async {
                    if let httpResponse = response {
                        print("[SupabaseService] Weight phases save response: \(httpResponse.statusCode)")
                        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 || httpResponse.statusCode == 409 {
                            print("✅ Weight phases saved to Supabase (\(phases.count) phases)")
                            completion(true)
                            return
                        } else if httpResponse.statusCode == 401 {
                            print("❌ JWT token expired, attempting refresh...")
                            SimpleAuthService.shared.refreshAccessToken { success in
                                if success {
                                    self.saveWeightPhases(phases, completion: completion)
                                } else {
                                    completion(false)
                                }
                            }
                            return
                        }
                    }
                    
                    if let error = error {
                        print("❌ Weight phases save error: \(error.localizedDescription)")
                    }
                    completion(false)
                }
            }
        } catch {
            print("❌ Failed to encode weight phases: \(error)")
            completion(false)
        }
    }
    
    func loadWeightPhases(completion: @escaping ([[String: Any]]?) -> Void) {
        guard let currentUser = SimpleAuthService.shared.currentUser,
              let url = URL(string: "\(SupabaseConfig.apiURL)/rest/v1/weight_phases?user_id=eq.\(currentUser.id)&order=start_date.asc") else {
            print("❌ No authenticated user or invalid URL for weight phases fetch")
            completion(nil)
            return
        }
        
        var headers: [String: String] = [
            "apikey": SupabaseConfig.apiKey,
            "Connection": "close"
        ]
        
        if let accessToken = SimpleAuthService.shared.accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        
        HTTP1Client.get(url: url.absoluteString, headers: headers) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Weight phases fetch error: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    DispatchQueue.main.async {
                        completion(jsonArray)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            } catch {
                print("❌ Failed to parse weight phases: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    func updateWeightPhase(_ phaseData: [String: Any], completion: @escaping (Bool) -> Void) {
        guard let phaseId = phaseData["id"] as? String,
              let url = URL(string: "\(SupabaseConfig.apiURL)/rest/v1/weight_phases?id=eq.\(phaseId)") else {
            completion(false)
            return
        }
        
        var headers: [String: String] = [
            "Content-Type": "application/json",
            "apikey": SupabaseConfig.apiKey,
            "Connection": "close"
        ]
        
        if let accessToken = SimpleAuthService.shared.accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: phaseData)
            HTTP1Client.patch(url: url.absoluteString, headers: headers, body: bodyData) { data, response, error in
                DispatchQueue.main.async {
                    if let httpResponse = response {
                        if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                            print("✅ Weight phase updated in Supabase")
                            completion(true)
                            return
                        } else if httpResponse.statusCode == 401 {
                            SimpleAuthService.shared.refreshAccessToken { refreshSuccess in
                                if refreshSuccess {
                                    self.updateWeightPhase(phaseData, completion: completion)
                                } else {
                                    completion(false)
                                }
                            }
                            return
                        }
                    }
                    completion(false)
                }
            }
        } catch {
            completion(false)
        }
    }
    
    func deleteWeightPhase(_ phaseId: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(SupabaseConfig.apiURL)/rest/v1/weight_phases?id=eq.\(phaseId)") else {
            completion(false)
            return
        }
        
        var headers: [String: String] = [
            "apikey": SupabaseConfig.apiKey,
            "Connection": "close"
        ]
        
        if let accessToken = SimpleAuthService.shared.accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        
        HTTP1Client.delete(url: url.absoluteString, headers: headers) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response {
                    if httpResponse.statusCode == 204 || httpResponse.statusCode == 404 {
                        print("✅ Weight phase deleted from Supabase")
                        completion(true)
                        return
                    } else if httpResponse.statusCode == 401 {
                        SimpleAuthService.shared.refreshAccessToken { success in
                            if success {
                                self.deleteWeightPhase(phaseId, completion: completion)
                            } else {
                                completion(false)
                            }
                        }
                        return
                    }
                }
                
                if let error = error {
                    print("❌ Weight phase deletion error: \(error.localizedDescription)")
                }
                completion(false)
            }
        }
    }
}
