import Foundation
import Combine
import SwiftUI

// Notification names for authentication events
extension Notification.Name {
    static let userDidSignIn = Notification.Name("userDidSignIn")
    static let userDidSignOut = Notification.Name("userDidSignOut")
}

// Configuration for Supabase
struct SupabaseConfig {
    // Replace these with your actual Supabase project details
    static let apiURL = "https://owmwxzkzqrbhhiofzgmm.supabase.co"
    static let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93bXd4emt6cXJiaGhpb2Z6Z21tIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzI0MjEwMiwiZXhwIjoyMDYyODE4MTAyfQ.5XKQo-XEWaRXVUPP4wdRj5W-KA9vluuZJPtwIknJo4k"
}

// User authentication model
struct AuthUser: Codable, Identifiable {
    let id: String
    let email: String
    let created_at: String
}

// Authentication response model
struct AuthResponse: Codable {
    let access_token: String
    let refresh_token: String
    let user: AuthUser
}

// Authentication error model
struct AuthError: Codable {
    let error: String
    let error_description: String?
}

// Helper struct for nutrients - directly matches Supabase JSON structure
struct NutrientInfo: Codable {
    let fat: Double?
    let protein: Double?
    let calories: Int?
    let carbohydrates: Double?
    let serving_size: String?
    let servings_per_package: Double?
    let sodium: Double?
    let sugar: Double?
    let saturated_fat: Double?
}

// Food item from Supabase
struct SupabaseFoodItem: Codable, Identifiable {
    // Properties from Supabase database
    let id: String
    let name: String
    let brand: String?
    let barcode: String?
    let nova_score: Int?
    let nutriscore_grade: String?
    let ingredients: [String]?
    let nutrients: NutrientInfo?
    let verified: Bool?
    let user_id: String?
    let created_at: String?
    let updated_at: String?
    
    // Convert to our app's FoodItem model
    func toFoodItem() -> FoodItem {
        // Only use the actual NOVA score from the database, no prediction
        let actualNovaScore = nova_score ?? 0
        return FoodItem(
            name: name,
            brandName: brand,
            barcode: barcode,
            calories: nutrients?.calories ?? 0,
            protein: nutrients?.protein ?? 0.0,
            carbs: nutrients?.carbohydrates ?? 0.0,
            fat: nutrients?.fat ?? 0.0,
            novaScore: actualNovaScore,
            nutriScoreGrade: nutriscore_grade
        )
    }
}

// Service to interact with Supabase
// Notification name for search status updates
extension Notification.Name {
    static let fuzzySearchStatusChanged = Notification.Name("fuzzySearchStatusChanged")
    static let semanticSearchStatusChanged = Notification.Name("semanticSearchStatusChanged")
}

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    // Search status
    @Published var isFuzzySearchActive = false
    @Published var isSemanticSearchActive = false
    
    // Initialize with default values
    init() {
        // Try to restore authentication state from UserDefaults
        loadAuthState()
    }
    
    // MARK: - Authentication Methods
    
    // Load saved authentication state
    private func loadAuthState() {
        if let tokenData = UserDefaults.standard.string(forKey: accessTokenKey) {
            self.accessToken = tokenData
            self.isAuthenticated = true
        }
        
        if let refreshData = UserDefaults.standard.string(forKey: refreshTokenKey) {
            self.refreshToken = refreshData
        }
        
        if let userData = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(AuthUser.self, from: userData) {
            self.currentUser = user
        }
    }
    
    // Save authentication state
    private func saveAuthState(accessToken: String, refreshToken: String, user: AuthUser) {
        UserDefaults.standard.set(accessToken, forKey: accessTokenKey)
        UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
        
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
        
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.currentUser = user
        self.isAuthenticated = true
    }
    
    // Clear authentication state
    private func clearAuthState() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        
        self.accessToken = nil
        self.refreshToken = nil
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    // Sign in with email and password
    func signIn(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        let url = URL(string: "\(SupabaseConfig.apiURL)/auth/v1/token?grant_type=password")
        
        guard let requestUrl = url else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("\(SupabaseConfig.apiKey)", forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            // No need to unwrap self here
            
            DispatchQueue.main.async {
                if let error = error {
                    self.authError = error.localizedDescription
                    completion(false, error.localizedDescription)
                    return
                }
                
                guard let data = data else {
                    self.authError = "No data received"
                    completion(false, "No data received")
                    return
                }
                
                // Try to decode successful response
                if let authResponse = try? JSONDecoder().decode(AuthResponse.self, from: data) {
                    self.saveAuthState(
                        accessToken: authResponse.access_token,
                        refreshToken: authResponse.refresh_token,
                        user: authResponse.user
                    )
                    self.authError = nil
                    completion(true, nil)
                    return
                }
                
                // Try to decode error response
                if let authError = try? JSONDecoder().decode(AuthError.self, from: data) {
                    let errorMessage = authError.error_description ?? authError.error
                    self.authError = errorMessage
                    completion(false, errorMessage)
                    return
                }
                
                // Fallback error
                self.authError = "Unknown error occurred"
                completion(false, "Unknown error occurred")
            }
        }.resume()
    }
    
    // Sign up with email and password
    func signUp(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        let url = URL(string: "\(SupabaseConfig.apiURL)/auth/v1/signup")
        
        guard let requestUrl = url else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("\(SupabaseConfig.apiKey)", forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            // No need to unwrap self here
            
            DispatchQueue.main.async {
                if let error = error {
                    self.authError = error.localizedDescription
                    completion(false, error.localizedDescription)
                    return
                }
                
                guard let data = data else {
                    self.authError = "No data received"
                    completion(false, "No data received")
                    return
                }
                
                // Try to decode successful response
                if let authResponse = try? JSONDecoder().decode(AuthResponse.self, from: data) {
                    self.saveAuthState(
                        accessToken: authResponse.access_token,
                        refreshToken: authResponse.refresh_token,
                        user: authResponse.user
                    )
                    self.authError = nil
                    completion(true, nil)
                    return
                }
                
                // Try to decode error response
                if let authError = try? JSONDecoder().decode(AuthError.self, from: data) {
                    let errorMessage = authError.error_description ?? authError.error
                    self.authError = errorMessage
                    completion(false, errorMessage)
                    return
                }
                
                // Fallback error
                self.authError = "Unknown error occurred"
                completion(false, "Unknown error occurred")
            }
        }.resume()
    }
    
    // Sign out
    func signOut() {
        clearAuthState()
        isAuthenticated = false
        
        // Post notification that user signed out
        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
    }
    
    // Authentication state
    @Published var currentUser: AuthUser?
    @Published var isAuthenticated = false
    @Published var authError: String?
    
    // Token storage
    private var accessToken: String?
    private var refreshToken: String?
    
    // UserDefaults keys
    private let accessTokenKey = "supabase_access_token"
    private let refreshTokenKey = "supabase_refresh_token"
    private let userKey = "supabase_user"
    
    // MARK: - Weight Logs
    
    // Fetch weight logs for the current user
    func fetchWeightLogs(completion: @escaping ([WeightLogEntry]?, Error?) -> Void) {
        guard let accessToken = accessToken, let userId = currentUser?.id else {
            completion(nil, NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        let endpoint = "\(SupabaseConfig.apiURL)/rest/v1/weight_logs?user_id=eq.\(userId)&order=date.desc"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "SupabaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                }
                return
            }
            
            do {
                // Parse the response into WeightLogEntry objects
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                
                let entries = try decoder.decode([SupabaseWeightLogEntry].self, from: data)
                
                // Convert to app's WeightLogEntry model
                let weightEntries = entries.map { entry -> WeightLogEntry in
                    return WeightLogEntry(
                        id: UUID(uuidString: entry.id) ?? UUID(),
                        date: entry.date,
                        weight: entry.weight,
                        movingAverage: entry.moving_average ?? 0.0,
                        weeklyRate: entry.weekly_rate,
                        notes: entry.notes
                    )
                }
                
                DispatchQueue.main.async {
                    completion(weightEntries, nil)
                }
            } catch {
                print("Error decoding weight logs: \(error)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }.resume()
    }
    
    // Add a new weight log entry
    func addWeightLog(entry: WeightLogEntry, completion: @escaping (Bool, Error?) -> Void) {
        guard let accessToken = accessToken, let userId = currentUser?.id else {
            completion(false, NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        let endpoint = "\(SupabaseConfig.apiURL)/rest/v1/weight_logs"
        
        // Convert to Supabase model
        let supabaseEntry = SupabaseWeightLogEntry(
            id: entry.id.uuidString,
            user_id: userId,
            date: entry.date,
            weight: entry.weight,
            moving_average: entry.movingAverage,
            weekly_rate: entry.weeklyRate,
            notes: entry.notes
        )
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            
            let jsonData = try encoder.encode(supabaseEntry)
            request.httpBody = jsonData
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(false, error)
                    }
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    DispatchQueue.main.async {
                        completion(true, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, NSError(domain: "SupabaseService", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: "Failed to add weight log"]))
                    }
                }
            }.resume()
        } catch {
            completion(false, error)
        }
    }
    
    // Update an existing weight log entry
    func updateWeightLog(entry: WeightLogEntry, completion: @escaping (Bool, Error?) -> Void) {
        guard let accessToken = accessToken, let userId = currentUser?.id else {
            completion(false, NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        let endpoint = "\(SupabaseConfig.apiURL)/rest/v1/weight_logs?id=eq.\(entry.id.uuidString)"
        
        // Convert to Supabase model
        let supabaseEntry = SupabaseWeightLogEntry(
            id: entry.id.uuidString,
            user_id: userId,
            date: entry.date,
            weight: entry.weight,
            moving_average: entry.movingAverage,
            weekly_rate: entry.weeklyRate,
            notes: entry.notes
        )
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            
            let jsonData = try encoder.encode(supabaseEntry)
            request.httpBody = jsonData
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(false, error)
                    }
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    DispatchQueue.main.async {
                        completion(true, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, NSError(domain: "SupabaseService", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: "Failed to update weight log"]))
                    }
                }
            }.resume()
        } catch {
            completion(false, error)
        }
    }
    
    // Delete a weight log entry
    func deleteWeightLog(entryId: UUID, completion: @escaping (Bool, Error?) -> Void) {
        guard let accessToken = accessToken else {
            completion(false, NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        let endpoint = "\(SupabaseConfig.apiURL)/rest/v1/weight_logs?id=eq.\(entryId.uuidString)"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, error)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, NSError(domain: "SupabaseService", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: "Failed to delete weight log"]))
                }
            }
        }.resume()
    }
    
    // Supabase model for weight log entries
    private struct SupabaseWeightLogEntry: Codable {
        let id: String
        let user_id: String
        let date: Date
        let weight: Double
        let moving_average: Double?
        let weekly_rate: Double?
        let notes: String?
    }
    
    // MARK: - Database Connection Test
    
    func testDatabaseConnection(completion: @escaping (Bool, String) -> Void) {
        print("Testing Supabase database connection...")
        
        // Create URL components for a simple query
        var urlComponents = URLComponents(string: SupabaseConfig.apiURL)
        urlComponents?.path = "/rest/v1/foods"
        urlComponents?.queryItems = [
            URLQueryItem(name: "select", value: "count"),
            URLQueryItem(name: "limit", value: "1")
        ]
        
        guard let url = urlComponents?.url else {
            completion(false, "Invalid URL configuration")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SupabaseConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30 // Increased timeout
        request.cachePolicy = .useProtocolCachePolicy // Better caching strategy
        
        print("Connection test URL: \(url.absoluteString)")
        
        // Use retry mechanism for better network resilience
        SupabaseService.performRequestWithRetry(request, maxRetries: 3, currentAttempt: 0) { data, response, error in
            // Check for network errors
            if let error = error {
                print("Connection test failed with error: \(error.localizedDescription)")
                completion(false, "Network error: \(error.localizedDescription)")
                return
            }
            
            // Check HTTP status code
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid HTTP response")
                return
            }
            
            print("Connection test HTTP status: \(httpResponse.statusCode)")
            
            if !(200...299).contains(httpResponse.statusCode) {
                completion(false, "HTTP error: \(httpResponse.statusCode)")
                return
            }
            
            // Check if we have data
            guard let data = data else {
                completion(false, "No data received")
                return
            }
            
            // Print the raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Connection test response: \(jsonString)")
                
                // Try to get the count of items in the database
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                       let firstItem = json.first,
                       let count = firstItem["count"] as? Int {
                        completion(true, "Successfully connected to database. Found \(count) food items.")
                    } else {
                        completion(true, "Connected to database, but couldn't parse item count.")
                    }
                } catch {
                    completion(true, "Connected to database, but received unexpected response format.")
                }
            } else {
                completion(false, "Received data but couldn't convert to string")
            }
        }
    }
    
    // MARK: - Food Items
    
    @Published var foodItems: [FoodItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    // Local fallback data
    private let localFoodItems = [
        // Fruits
        FoodItem(name: "Apple", calories: 52, protein: 0.3, carbs: 14.0, fat: 0.2),
        FoodItem(name: "Banana", calories: 89, protein: 1.1, carbs: 22.8, fat: 0.3),
        FoodItem(name: "Orange", calories: 47, protein: 0.9, carbs: 11.8, fat: 0.1),
        FoodItem(name: "Strawberries", calories: 32, protein: 0.7, carbs: 7.7, fat: 0.3),
        FoodItem(name: "Blueberries", calories: 57, protein: 0.7, carbs: 14.5, fat: 0.3),
        
        // Proteins
        FoodItem(name: "Chicken Breast", calories: 165, protein: 31.0, carbs: 0.0, fat: 3.6),
        FoodItem(name: "Salmon", calories: 206, protein: 22.0, carbs: 0.0, fat: 13.0),
        FoodItem(name: "Tuna", calories: 130, protein: 29.0, carbs: 0.0, fat: 1.0),
        FoodItem(name: "Beef Steak", calories: 250, protein: 26.0, carbs: 0.0, fat: 17.0),
        FoodItem(name: "Tofu", calories: 76, protein: 8.0, carbs: 2.0, fat: 4.0),
        
        // Grains
        FoodItem(name: "Rice", calories: 130, protein: 2.7, carbs: 28.0, fat: 0.3),
        FoodItem(name: "Quinoa", calories: 120, protein: 4.4, carbs: 21.3, fat: 1.9),
        FoodItem(name: "Bread", calories: 75, protein: 2.6, carbs: 13.8, fat: 1.0),
        FoodItem(name: "Oatmeal", calories: 68, protein: 2.5, carbs: 12.0, fat: 1.4),
        FoodItem(name: "Pasta", calories: 131, protein: 5.0, carbs: 25.0, fat: 1.1),
        
        // Dairy
        FoodItem(name: "Egg", calories: 78, protein: 6.3, carbs: 0.6, fat: 5.3),
        FoodItem(name: "Greek Yogurt", calories: 59, protein: 10.0, carbs: 3.6, fat: 0.4),
        FoodItem(name: "Milk", calories: 42, protein: 3.4, carbs: 5.0, fat: 1.0),
        FoodItem(name: "Cheese", calories: 113, protein: 7.0, carbs: 0.4, fat: 9.0),
        
        // Vegetables
        FoodItem(name: "Avocado", calories: 160, protein: 2.0, carbs: 8.5, fat: 14.7),
        FoodItem(name: "Broccoli", calories: 31, protein: 2.5, carbs: 6.0, fat: 0.3),
        FoodItem(name: "Spinach", calories: 23, protein: 2.9, carbs: 3.6, fat: 0.4),
        FoodItem(name: "Kale", calories: 49, protein: 4.3, carbs: 8.8, fat: 0.9),
        
        // Beverages
        FoodItem(name: "Diet Coke", calories: 1, protein: 0.0, carbs: 0.0, fat: 0.0),
        FoodItem(name: "Orange Juice", calories: 45, protein: 0.7, carbs: 10.4, fat: 0.2),
        FoodItem(name: "Coffee", calories: 2, protein: 0.3, carbs: 0.0, fat: 0.0),
        FoodItem(name: "Espresso", calories: 3, protein: 0.2, carbs: 0.0, fat: 0.0),
        FoodItem(name: "Tripleshot Espresso", calories: 9, protein: 0.6, carbs: 0.0, fat: 0.0),
        FoodItem(name: "Latte", calories: 65, protein: 6.0, carbs: 9.0, fat: 0.0),
        FoodItem(name: "Cappuccino", calories: 80, protein: 5.0, carbs: 8.0, fat: 4.0),
        FoodItem(name: "Green Tea", calories: 2, protein: 0.0, carbs: 0.0, fat: 0.0),
        
        // Snacks
        FoodItem(name: "Almonds", calories: 164, protein: 6.0, carbs: 6.1, fat: 14.0),
        FoodItem(name: "Dark Chocolate", calories: 155, protein: 2.0, carbs: 13.0, fat: 9.0),
        FoodItem(name: "Popcorn", calories: 55, protein: 1.8, carbs: 10.6, fat: 0.7)
    ]
    
    func fetchFoodItems() {
        // Always load local data first to ensure we have something to display
        loadLocalFallbackData()
        
        // Then try to fetch from Supabase
        isLoading = true
        
        // Use a more reliable URL construction
        var urlComponents = URLComponents(string: SupabaseConfig.apiURL)
        urlComponents?.path = "/rest/v1/foods"
        urlComponents?.queryItems = [URLQueryItem(name: "select", value: "*")]
        
        print("Attempting to fetch foods from: \(SupabaseConfig.apiURL)/rest/v1/foods")
        
        guard let url = urlComponents?.url else {
            DispatchQueue.main.async { 
                SupabaseService.shared.errorMessage = "Invalid URL"
                SupabaseService.shared.isLoading = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SupabaseConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            DispatchQueue.main.async {
                SupabaseService.shared.isLoading = false
                
                // Check for network connectivity errors
                if let error = error {
                    print("Supabase API Error: \(error.localizedDescription)")
                    // We already loaded local data, so just log the error
                    return
                }
                
                // Check HTTP status code
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid HTTP response")
                    return
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    print("HTTP Error: \(httpResponse.statusCode)")
                    return
                }
                
                // Check if we have data
                guard let data = data else {
                    print("No data received")
                    return
                }
                
                do {
                    // Print the raw JSON for debugging
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Supabase API Response: \(jsonString)")
                        
                        // For search queries, print more detailed info
                        if request.url?.path.contains("/foods") == true {
                            print("Search query response length: \(jsonString.count) characters")
                            print("Search query found items: \(jsonString.contains("[{") ? "Yes" : "No")")
                        }
                    }
                    
                    let decoder = JSONDecoder()
                    // Configure decoder for Supabase date format
                    decoder.dateDecodingStrategy = .iso8601
                    
                    // Try to parse the response
                    let foodItems = try decoder.decode([SupabaseFoodItem].self, from: data)
                    if foodItems.isEmpty {
                        // Successfully parsed but no items
                        print("No food items found in database, using local data")
                    } else {
                        SupabaseService.shared.foodItems = foodItems.map { $0.toFoodItem() }
                        SupabaseService.shared.errorMessage = nil
                        print("Successfully parsed \(foodItems.count) food items")
                    }
                } catch let decodingError as DecodingError {
                    // Provide detailed information about decoding errors
                    print("Decoding error: \(decodingError)")
                    // We already loaded local data, so just log the error
                } catch {
                    print("JSON Parsing Error: \(error)")
                    // We already loaded local data, so just log the error
                }
            }
        }.resume()
    }
    
    
    /// Search for food items by name
    /// - Parameter query: The search query string
    func searchFoodItems(query: String) {
        // Always search local data first to ensure we have something to display
        searchLocalFallbackData(query: query)
        
        // Skip empty searches
        if query.isEmpty {
            return
        }
        
        // TEMPORARILY DISABLED: Supabase food search functionality
        // We're using TypesenseService exclusively for food search now
        // This method is kept as a stub for future reintegration
        DispatchQueue.main.async { 
            SupabaseService.shared.isLoading = false
            // Clear any previous error message
            SupabaseService.shared.errorMessage = nil
        }
    }
    
    // MARK: - Network Request Helper
    
    // Perform a network request with automatic retry on failure
    static func performRequestWithRetry(_ request: URLRequest, maxRetries: Int, currentAttempt: Int, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        print("🌐 Network request attempt \(currentAttempt + 1) of \(maxRetries + 1) to \(request.url?.absoluteString ?? "unknown URL")")
        
        URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            // Check for network errors that warrant a retry
            if let error = error as NSError?, currentAttempt < maxRetries {
                let networkErrorCodes = [
                    NSURLErrorTimedOut,
                    NSURLErrorCannotConnectToHost,
                    NSURLErrorNetworkConnectionLost,
                    NSURLErrorNotConnectedToInternet,
                    NSURLErrorDNSLookupFailed,
                    NSURLErrorCannotFindHost
                ]
                
                if networkErrorCodes.contains(error.code) {
                    // Calculate exponential backoff delay
                    let delay = pow(2.0, Double(currentAttempt)) * 0.5 // 0.5s, 1s, 2s
                    print("🔄 Retrying request after \(delay) seconds due to error: \(error.localizedDescription)")
                    
                    // Retry after delay with exponential backoff
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        SupabaseService.performRequestWithRetry(request, maxRetries: maxRetries, currentAttempt: currentAttempt + 1, completion: completion)
                    }
                    return
                }
            }
            
            // If we got here, either the request succeeded or we've exhausted retries
            completion(data, response, error)
        }.resume()
    }
    
    // Load local fallback data when network connection fails
    private func loadLocalFallbackData() {
        DispatchQueue.main.async { 
            SupabaseService.shared.foodItems = SupabaseService.shared.localFoodItems
        }
    } // Added closing bracket here
    
    // Add a new food item to the Supabase database
    func addFoodItem(_ foodItem: FoodItem, ingredients: [String] = [], completion: @escaping (Bool, String?) -> Void) {
        print("==== STARTING ADD FOOD ITEM REQUEST ====")
        print("Food name: \(foodItem.name)")
        print("Serving type: \(foodItem.servingType ?? "nil")")
        print("Serving size: \(foodItem.servingSize ?? "nil")")
        print("Servings per package: \(foodItem.servingsPerPackage ?? 0)")
        // Create the nutrients object
        let nutrients: [String: Any] = [
            "calories": foodItem.calories,
            "protein": foodItem.protein,
            "carbohydrates": foodItem.carbs,
            "fat": foodItem.fat,
            // Always include serving_size and servings_per_package with default values
            "serving_size": foodItem.servingSize ?? "100g",
            "servings_per_package": foodItem.servingsPerPackage ?? 1.0,
            // Include serving_type in the nutrients object instead of root level
            "serving_type": foodItem.servingType ?? "weight"
        ]
        
        print("📊 Nutrients dictionary: \(nutrients)")
        
        // Create the food item data
        var foodItemData: [String: Any] = [
            "name": foodItem.name,
            "nova_score": foodItem.novaScore,
            "nutrients": nutrients,
            "verified": false,
            "ingredients": ingredients
            // Moved serving_type into the nutrients object
        ]
        
        print("📦 Food item data: \(foodItemData)")
        
        // Add brand name and barcode if available
        if let brandName = foodItem.brandName, !brandName.isEmpty {
            foodItemData["brand_name"] = brandName
            print("👔 Added brand name: \(brandName)")
        }
        
        if let barcode = foodItem.barcode, !barcode.isEmpty {
            foodItemData["barcode"] = barcode
            print("📊 Added barcode: \(barcode)")
        }
        
        // Convert to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: foodItemData) else {
            completion(false, "Failed to serialize food data")
            return
        }
        
        // Create URL request
        var urlComponents = URLComponents(string: SupabaseConfig.apiURL)
        urlComponents?.path = "/rest/v1/foods"
        
        guard let url = urlComponents?.url else {
            print("❌ Invalid URL")
            completion(false, "Invalid URL")
            return
        }
        
        print("📡 Request URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SupabaseConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("return=representation", forHTTPHeaderField: "Prefer")
        
        // Debug: Print the request details
        print("🍽️ Adding food item: \(foodItem.name)")
        print("📡 Request URL: \(url)")
        print("📦 Request body: \(String(data: jsonData, encoding: .utf8) ?? "<invalid JSON>")")
        
        // Make the request
        print("🚀 Starting network request...")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            print("📲 Network response received")
            
            // Debug: Print response details
            if let data = data, let responseStr = String(data: data, encoding: .utf8) {
                print("📥 Response data: \(responseStr)")
            } else {
                print("⚠️ No response data received")
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔢 HTTP status code: \(httpResponse.statusCode)")
            } else {
                print("⚠️ Response is not an HTTP response")
            }
            
            DispatchQueue.main.async {
                // Check for network errors
                if let error = error {
                    print("❌ Network error: \(error.localizedDescription)")
                    completion(false, "Network error: \(error.localizedDescription)")
                    return
                }
                
                // Check HTTP status code
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid HTTP response")
                    completion(false, "Invalid HTTP response")
                    return
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    print("❌ HTTP Error: \(httpResponse.statusCode)")
                    if let data = data, let errorStr = String(data: data, encoding: .utf8) {
                        print("❌ Error details: \(errorStr)")
                        completion(false, "HTTP Error \(httpResponse.statusCode): \(errorStr)")
                    } else {
                        completion(false, "HTTP Error: \(httpResponse.statusCode)")
                    }
                    return
                }
                
                // Success!
                print("✅ Food item added successfully!")
                // Add the new food item to our local array
                self.foodItems.append(foodItem)
                completion(true, nil)
            }
        }
        
        print("🔄 Resuming task...")
        task.resume()
        print("✅ Task resumed")
        
        // Add a fallback completion in case the network request doesn't complete
        let requestStartTime = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            // Check if more than 10 seconds have passed since the request started
            if Date().timeIntervalSince(requestStartTime) >= 10 {
                print("⚠️ Network request timed out after 10 seconds")
                completion(false, "Network request timed out. Please check your internet connection and try again.")
            }
        }
    }

    // Search local fallback data when network connection fails
    private func searchLocalFallbackData(query: String) {
        DispatchQueue.main.async { 
            // No need to unwrap self here
            
            if query.isEmpty {
                // Even for recent items, apply nutritional completeness ranking
                self.foodItems = SearchRankingService.shared.rankByNutritionalCompleteness(foods: self.localFoodItems)
            } else {
                // Split the query into words for more flexible matching
                let searchTerms = query.lowercased().split(separator: " ").map(String.init)
                
                let filteredItems = self.localFoodItems.filter { food in
                    let foodName = food.name.lowercased()
                    
                    // Check if the entire query is contained in the food name
                    if foodName.contains(query.lowercased()) {
                        return true
                    }
                    
                    // Check if all search terms are found in the food name (in any order)
                    let allTermsFound = searchTerms.allSatisfy { term in
                        foodName.contains(term)
                    }
                    
                    return allTermsFound
                }
                
                // Apply user preference ranking if we have a current meal type
                if let currentMealType = UserDefaults.standard.string(forKey: "currentMealType") {
                    self.foodItems = SearchRankingService.shared.rankSearchResults(foods: filteredItems, mealType: currentMealType)
                } else {
                    // Even without meal context, still rank by nutritional completeness
                    self.foodItems = SearchRankingService.shared.rankByNutritionalCompleteness(foods: filteredItems)
                }
            }
        }
    }
    
    // Search for food by barcode
    func searchFoodByBarcode(barcode: String, completion: @escaping (FoodItem?, String?) -> Void) {
        // Clean and normalize the barcode - remove any non-numeric characters
        let cleanBarcode = barcode.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        print("Searching for barcode: \(barcode), cleaned: \(cleanBarcode)")
        
        // Try multiple barcode search strategies
        searchBarcodeExact(barcode: barcode) { (foodItem, error) in
            if let foodItem = foodItem {
                completion(foodItem, nil)
                return
            }
            
            // If exact match fails, try with cleaned barcode
            self.searchBarcodeExact(barcode: cleanBarcode) { (foodItem, error) in
                if let foodItem = foodItem {
                    completion(foodItem, nil)
                    return
                }
                
                // If both exact matches fail, try with LIKE operator
                self.searchBarcodeLike(barcode: cleanBarcode) { (foodItem, error) in
                    if let foodItem = foodItem {
                        completion(foodItem, nil)
                    } else {
                        completion(nil, "No food found with barcode \(barcode)")
                    }
                }
            }
        }
    }
    
    // Search for exact barcode match
    // Public method for searching by barcode, tries exact match first then falls back to LIKE search
    func searchBarcode(barcode: String, completion: @escaping (FoodItem?, String?) -> Void) {
        // Try exact match first
        searchBarcodeExact(barcode: barcode) { food, error in
            if let food = food {
                // Found an exact match
                completion(food, nil)
            } else {
                // Try LIKE search as fallback
                self.searchBarcodeLike(barcode: barcode, completion: completion)
            }
        }
    }
    
    private func searchBarcodeExact(barcode: String, completion: @escaping (FoodItem?, String?) -> Void) {
        var urlComponents = URLComponents(string: SupabaseConfig.apiURL)
        urlComponents?.path = "/rest/v1/foods"
        urlComponents?.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "barcode", value: "eq."+barcode)
        ]
        
        print("Trying exact barcode search: \(barcode)")
        print("Using URL pattern: \(urlComponents?.url?.absoluteString ?? "invalid URL")")
        
        
        guard let url = urlComponents?.url else {
            completion(nil, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SupabaseConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        // Use the retry mechanism for better reliability
        SupabaseService.performRequestWithRetry(request, maxRetries: 2, currentAttempt: 0) { data, response, error in
            self.processBarcodeResponse(data: data, response: response, error: error, barcode: barcode, completion: completion)
        }
    }
    
    // Search for barcode with LIKE operator for partial matches
    private func searchBarcodeLike(barcode: String, completion: @escaping (FoodItem?, String?) -> Void) {
        var urlComponents = URLComponents(string: SupabaseConfig.apiURL)
        urlComponents?.path = "/rest/v1/foods"
        
        // Use LIKE operator for more flexible matching
        urlComponents?.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "barcode", value: "like.*" + barcode + "*")
        ]
        
        print("Trying fuzzy barcode search with LIKE: \(barcode)")
        print("Using URL pattern: \(urlComponents?.url?.absoluteString ?? "invalid URL")")
        
        guard let url = urlComponents?.url else {
            completion(nil, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SupabaseConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        // Use the retry mechanism for better reliability
        SupabaseService.performRequestWithRetry(request, maxRetries: 2, currentAttempt: 0) { data, response, error in
            self.processBarcodeResponse(data: data, response: response, error: error, barcode: barcode, completion: completion)
        }
    }
    
    // Process barcode search response
    private func processBarcodeResponse(data: Data?, response: URLResponse?, error: Error?, barcode: String, completion: @escaping (FoodItem?, String?) -> Void) {
        // Check for network connectivity errors
        if let error = error {
            print("Barcode Search Error: \(error.localizedDescription)")
            completion(nil, error.localizedDescription)
            return
        }
        
        // Check HTTP status code
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Invalid HTTP response")
            completion(nil, "Invalid HTTP response")
            return
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            print("HTTP Error: \(httpResponse.statusCode)")
            
            // Try to extract more detailed error information
            if let data = data, let errorString = String(data: data, encoding: .utf8) {
                print("Error details: \(errorString)")
                completion(nil, "barcode not found HTTP error: \(httpResponse.statusCode) - \(errorString)")
            } else {
                completion(nil, "barcode not found HTTP error: \(httpResponse.statusCode)")
            }
            return
        }
        
        // Check if we have data
        guard let data = data else {
            print("No data received")
            completion(nil, "No data received")
            return
        }
        
        // Check if the response is an empty array
        if let jsonString = String(data: data, encoding: .utf8), jsonString == "[]" {
            print("Empty response - no food found with barcode \(barcode)")
            completion(nil, nil) // Return nil without error for empty results
            return
        }
        
        do {
            // Print the raw JSON for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Barcode Search Response: \(jsonString)")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Try to parse the response
            let foodItems = try decoder.decode([SupabaseFoodItem].self, from: data)
            if let foodItem = foodItems.first {
                completion(foodItem.toFoodItem(), nil)
            } else {
                completion(nil, nil) // Return nil without error for empty results
            }
        } catch {
            print("Barcode Search JSON Parsing Error: \(error)")
            
            // Try to provide more context about the parsing error
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to parse: \(jsonString)")
                completion(nil, "Error parsing food data: \(error.localizedDescription)")
            } else {
                completion(nil, "Error parsing food data")
            }
        }
    }
    }
    
    // MARK: - Search Strategy Methods
    
    // Strategy 1: Search using name field with ilike operator
    private func trySearchStrategy1(query: String, completion: @escaping (Bool) -> Void) {
        print("\n🔎 Strategy 1: Search by name with ilike")
        
        // Construct URL for strategy 1
        let baseURL = SupabaseConfig.apiURL + "/rest/v1/foods"
        let searchPattern = "%" + query + "%"
        let urlString = baseURL + "?select=*" + 
                       "&name=ilike." + searchPattern.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)! + 
                       "&limit=20"
        
        guard let url = URL(string: urlString) else {
            print("❌ Strategy 1: Invalid URL")
            completion(false)
            return
        }
        
        print("URL: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SupabaseConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        request.cachePolicy = .useProtocolCachePolicy
        
        // Perform the request
        SupabaseService.performRequestWithRetry(request, maxRetries: 2, currentAttempt: 0) { (data: Data?, response: URLResponse?, error: Error?) in
            // Process the response
            if let error = error {
                print("❌ Strategy 1 failed: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("❌ Strategy 1: HTTP error \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                completion(false)
                return
            }
            
            guard let data = data else {
                print("❌ Strategy 1: No data received")
                completion(false)
                return
            }
            
            do {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Strategy 1 response: \(jsonString.prefix(100))...")
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let foodItems = try decoder.decode([SupabaseFoodItem].self, from: data)
                if foodItems.isEmpty {
                    print("⚠️ Strategy 1: No food items found")
                    completion(false)
                    return
                }
                
                // Success - update the UI
                DispatchQueue.main.async {
                    SupabaseService.shared.foodItems = foodItems.map { $0.toFoodItem() }
                    SupabaseService.shared.isLoading = false
                    SupabaseService.shared.errorMessage = nil
                    print("✅ Strategy 1: Found \(foodItems.count) items")
                }
                completion(true)
            } catch {
                print("❌ Strategy 1: JSON parsing error - \(error)")
                completion(false)
            }
        }
    }
    
    // Strategy 2: Search using both name and brand fields with OR condition
    private func trySearchStrategy2(query: String, completion: @escaping (Bool) -> Void) {
        print("\n🔎 Strategy 2: Search by name OR brand")
        
        // Construct URL for strategy 2
        let baseURL = SupabaseConfig.apiURL + "/rest/v1/foods"
        let searchTerm = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = baseURL + "?select=*" + 
                       "&or=(name.ilike.%25" + searchTerm + "%25,brand.ilike.%25" + searchTerm + "%25)" + 
                       "&limit=20"
        
        guard let url = URL(string: urlString) else {
            print("❌ Strategy 2: Invalid URL")
            completion(false)
            return
        }
        
        print("URL: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SupabaseConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        request.cachePolicy = .useProtocolCachePolicy
        
        // Perform the request
        SupabaseService.performRequestWithRetry(request, maxRetries: 2, currentAttempt: 0) { (data: Data?, response: URLResponse?, error: Error?) in
            // Process the response
            if let error = error {
                print("❌ Strategy 2 failed: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("❌ Strategy 2: HTTP error \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                completion(false)
                return
            }
            
            guard let data = data else {
                print("❌ Strategy 2: No data received")
                completion(false)
                return
            }
            
            do {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Strategy 2 response: \(jsonString.prefix(100))...")
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let foodItems = try decoder.decode([SupabaseFoodItem].self, from: data)
                if foodItems.isEmpty {
                    print("⚠️ Strategy 2: No food items found")
                    completion(false)
                    return
                }
                
                // Success - update the UI
                DispatchQueue.main.async {
                    SupabaseService.shared.foodItems = foodItems.map { $0.toFoodItem() }
                    SupabaseService.shared.isLoading = false
                    SupabaseService.shared.errorMessage = nil
                    print("✅ Strategy 2: Found \(foodItems.count) items")
                }
                completion(true)
            } catch {
                print("❌ Strategy 2: JSON parsing error - \(error)")
                completion(false)
            }
        }
    }
    
    // Strategy 3: Search using a simple text match with exact format from memory
    
    // MARK: - TEMPORARILY STUBBED SEARCH METHODS
    // All search methods below are stubbed as part of temporarily removing Supabase food search functionality
    // These will be properly reintroduced later when Supabase search is reintegrated
    
    // Semantic Search: Uses vector embeddings to find foods with similar meaning
    private func trySemanticSearch(query: String, completion: @escaping (Bool) -> Void) {
        print("\n🧠 Semantic Search: Using vector embeddings for meaning-based search")
        
        // Construct URL for semantic search
        let baseURL = SupabaseConfig.apiURL + "/rest/v1/rpc/search_foods_by_embedding"
        
        // Validate the query
        if query.isEmpty {
            print("❌ Semantic Search: Empty query string")
            completion(false)
            return
        }
        
        // Create the request body for the RPC call
        // This assumes you have a PostgreSQL function set up for vector search
        let requestBody: [String: Any] = [
            "query_text": query,
            "match_threshold": 0.6,
            "match_count": 20
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("❌ Semantic Search: Failed to serialize request body")
            completion(false)
            return
        }
        
        guard let url = URL(string: baseURL) else {
            print("❌ Semantic Search: Invalid URL")
            completion(false)
            return
        }
        
        print("URL: \(baseURL)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SupabaseConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        request.cachePolicy = .useProtocolCachePolicy
        
        // Perform the request
        SupabaseService.performRequestWithRetry(request, maxRetries: 2, currentAttempt: 0) { (data: Data?, response: URLResponse?, error: Error?) in
            // Process the response
            if let error = error {
                print("❌ Semantic Search failed: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Semantic Search: No HTTP response")
                completion(false)
                return
            }
            
            // Check if the RPC function doesn't exist (404) or other error
            if httpResponse.statusCode == 404 {
                print("⚠️ Semantic Search: RPC function not found - this is expected if you haven't set up vector search")
                completion(false)
                return
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                print("❌ Semantic Search: HTTP error \(httpResponse.statusCode)")
                completion(false)
                return
            }
            
            guard let data = data else {
                print("❌ Semantic Search: No data received")
                completion(false)
                return
            }
            
            do {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Semantic Search response: \(jsonString.prefix(100))...")
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                // Try to decode the response as an array of food items
                let foodItems = try decoder.decode([SupabaseFoodItem].self, from: data)
                if foodItems.isEmpty {
                    print("⚠️ Semantic Search: No food items found")
                    completion(false)
                    return
                }
                
                // Success - update the UI
                DispatchQueue.main.async {
                    // Convert to food items
                    let convertedItems = foodItems.map { $0.toFoodItem() }
                    
                    // Apply user preference ranking if we have a current meal type
                    if let currentMealType = UserDefaults.standard.string(forKey: "currentMealType") {
                        SupabaseService.shared.foodItems = SearchRankingService.shared.rankSearchResults(foods: convertedItems, mealType: currentMealType)
                    } else {
                        // Even without meal context, still rank by nutritional completeness
                        SupabaseService.shared.foodItems = SearchRankingService.shared.rankByNutritionalCompleteness(foods: convertedItems)
                    }
                    
                    SupabaseService.shared.isLoading = false
                    SupabaseService.shared.errorMessage = nil
                    SupabaseService.shared.isSemanticSearchActive = true
                    SupabaseService.shared.isFuzzySearchActive = false
                    
                    // Post notification that semantic search is active
                    NotificationCenter.default.post(
                        name: .semanticSearchStatusChanged,
                        object: nil,
                        userInfo: ["active": true]
                    )
                    
                    print("✅ Semantic Search: Found \(foodItems.count) items")
                    completion(true)
                }
            } catch {
                print("❌ Semantic Search: Failed to decode response: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    // Fuzzy Search: Uses PostgreSQL's trigram similarity for fuzzy matching
    private func tryFuzzySearch(query: String, completion: @escaping (Bool) -> Void) {
        print("\n🔍 Fuzzy Search: Using PostgreSQL trigram similarity")
        
        // Construct URL for fuzzy search
        let baseURL = SupabaseConfig.apiURL + "/rest/v1/foods"
        
        // Clean and encode the query
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("❌ Fuzzy Search: Invalid query string")
            completion(false)
            return
        }
        
        // Build URL with trigram similarity search
        // Use similarity threshold of 0.3 (can be adjusted for more/less fuzzy results)
        let urlString = baseURL + "?select=*," + 
                       // Add similarity scores for name and brand
                       "similarity(name, '\(encodedQuery)') as name_sim," +
                       "similarity(brand, '\(encodedQuery)') as brand_sim," +
                       // Add combined score for sorting
                       "greatest(similarity(name, '\(encodedQuery)'), similarity(brand, '\(encodedQuery)')*0.8) as sim_score" +
                       // Search condition using similarity threshold
                       "&or=(similarity(name,'\(encodedQuery)')>0.3,similarity(brand,'\(encodedQuery)')>0.3)" +
                       // Order by similarity score (most similar first)
                       "&order=sim_score.desc" +
                       "&limit=20"
        
        guard let url = URL(string: urlString) else {
            print("❌ Fuzzy Search: Invalid URL")
            completion(false)
            return
        }
        
        print("URL: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SupabaseConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        request.cachePolicy = .useProtocolCachePolicy
        
        // Perform the request
        SupabaseService.performRequestWithRetry(request, maxRetries: 2, currentAttempt: 0) { (data: Data?, response: URLResponse?, error: Error?) in
            // Process the response
            if let error = error {
                print("❌ Fuzzy Search failed: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("❌ Fuzzy Search: HTTP error \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                completion(false)
                return
            }
            
            guard let data = data else {
                print("❌ Fuzzy Search: No data received")
                completion(false)
                return
            }
            
            do {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Fuzzy Search response: \(jsonString.prefix(100))...")
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let foodItems = try decoder.decode([SupabaseFoodItem].self, from: data)
                if foodItems.isEmpty {
                    print("⚠️ Fuzzy Search: No food items found")
                    completion(false)
                    return
                }
                
                // Success - update the UI
                DispatchQueue.main.async {
                    // Convert to food items
                    let convertedItems = foodItems.map { $0.toFoodItem() }
                    
                    // Apply user preference ranking if we have a current meal type
                    if let currentMealType = UserDefaults.standard.string(forKey: "currentMealType") {
                        SupabaseService.shared.foodItems = SearchRankingService.shared.rankSearchResults(foods: convertedItems, mealType: currentMealType)
                    } else {
                        // Even without meal context, still rank by nutritional completeness
                        SupabaseService.shared.foodItems = SearchRankingService.shared.rankByNutritionalCompleteness(foods: convertedItems)
                    }
                    
                    SupabaseService.shared.isLoading = false
                    SupabaseService.shared.errorMessage = nil
                    SupabaseService.shared.isFuzzySearchActive = true
                    
                    // Post notification that fuzzy search is active
                    NotificationCenter.default.post(
                        name: .fuzzySearchStatusChanged,
                        object: nil,
                        userInfo: ["active": true]
                    )
                    
                    print("✅ Fuzzy Search: Found \(foodItems.count) items")
                    completion(true)
                }
            } catch {
                print("❌ Fuzzy Search: Failed to decode response: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    // Full Text Search: Uses PostgreSQL's powerful full-text search capabilities
    private func tryFullTextSearch(query: String, completion: @escaping (Bool) -> Void) {
        print("\n🔎 Full Text Search: Using PostgreSQL full text search")
        
        // Construct URL for full text search
        let baseURL = SupabaseConfig.apiURL + "/rest/v1/foods"
        
        // Normalize the query: convert to lowercase and remove punctuation
        let normalizedQuery = query.lowercased()
            .components(separatedBy: CharacterSet.punctuationCharacters).joined(separator: " ")
        
        // Prepare search terms for tsquery
        // Convert spaces to :* & for prefix matching on each word
        let searchTerms = normalizedQuery.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "" }
            .joined(separator: ":* & ") + ":*"
        
        // Use the weighted search index (A=name, B=brand) for better ranking
        // This will prioritize matches in the name field over matches in the brand field
        let urlString = baseURL + "?select=*," + 
                       // Add a rank field to sort by relevance
                       "ts_rank(setweight(to_tsvector('english', coalesce(name,'')), 'A') || " + 
                       "setweight(to_tsvector('english', coalesce(brand,'')), 'B'), " + 
                       "to_tsquery('english', '" + searchTerms + "')) as rank" + 
                       // Search condition using the same weighted vectors
                       "&or=(setweight(to_tsvector('english', coalesce(name,'')), 'A') || " + 
                       "setweight(to_tsvector('english', coalesce(brand,'')), 'B') @@ " + 
                       "to_tsquery('english', '" + searchTerms + "'))" + 
                       // Order by rank (most relevant first)
                       "&order=rank.desc" + 
                       "&limit=20"
        
        guard let url = URL(string: urlString) else {
            print("❌ Full Text Search: Invalid URL")
            completion(false)
            return
        }
        
        print("URL: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SupabaseConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        request.cachePolicy = .useProtocolCachePolicy
        
        // Perform the request
        SupabaseService.performRequestWithRetry(request, maxRetries: 2, currentAttempt: 0) { (data: Data?, response: URLResponse?, error: Error?) in
            // Process the response
            if let error = error {
                print("❌ Full Text Search failed: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("❌ Full Text Search: HTTP error \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                completion(false)
                return
            }
            
            guard let data = data else {
                print("❌ Full Text Search: No data received")
                completion(false)
                return
            }
            
            do {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Full Text Search response: \(jsonString.prefix(100))...")
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let foodItems = try decoder.decode([SupabaseFoodItem].self, from: data)
                if foodItems.isEmpty {
                    print("⚠️ Full Text Search: No food items found")
                    completion(false)
                    return
                }
                
                // Success - update the UI
                DispatchQueue.main.async {
                    // Convert to food items
                    let convertedItems = foodItems.map { $0.toFoodItem() }
                    
                    // Apply user preference ranking if we have a current meal type
                    if let currentMealType = UserDefaults.standard.string(forKey: "currentMealType") {
                        SupabaseService.shared.foodItems = SearchRankingService.shared.rankSearchResults(foods: convertedItems, mealType: currentMealType)
                    } else {
                        // Even without meal context, still rank by nutritional completeness
                        SupabaseService.shared.foodItems = SearchRankingService.shared.rankByNutritionalCompleteness(foods: convertedItems)
                    }
                    
                    SupabaseService.shared.isLoading = false
                    SupabaseService.shared.errorMessage = nil
                    SupabaseService.shared.isFuzzySearchActive = false
                    
                    // Post notification that fuzzy search is not active
                    NotificationCenter.default.post(
                        name: .fuzzySearchStatusChanged,
                        object: nil,
                        userInfo: ["active": false]
                    )
                    
                    print("✅ Full Text Search: Found \(foodItems.count) items")
                    completion(true)
                }
            } catch {
                print("❌ Full Text Search: JSON parsing error - \(error)")
                completion(false)
            }
        }
    }
    
    private func trySearchStrategy3(query: String, completion: @escaping (Bool) -> Void) {
        print("\n🔎 Strategy 3: Search with exact format from memory")
        
        // Construct URL for strategy 3 - using the exact format that worked previously
        let baseURL = SupabaseConfig.apiURL + "/rest/v1/foods"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Use the exact format that worked previously according to memory
        let urlString = baseURL + "?select=*" + 
                       "&name=ilike.%" + encodedQuery + "%" + 
                       "&limit=20"
        
        guard let url = URL(string: urlString) else {
            print("❌ Strategy 3: Invalid URL")
            DispatchQueue.main.async {
                SupabaseService.shared.isLoading = false
            }
            completion(false)
            return
        }
        
        print("URL: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SupabaseConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        request.cachePolicy = .useProtocolCachePolicy
        
        // Perform the request
        SupabaseService.performRequestWithRetry(request, maxRetries: 2, currentAttempt: 0) { (data: Data?, response: URLResponse?, error: Error?) in
            // Process the response
            if let error = error {
                print("❌ Strategy 3 failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    SupabaseService.shared.isLoading = false
                }
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("❌ Strategy 3: HTTP error \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                DispatchQueue.main.async {
                    SupabaseService.shared.isLoading = false
                }
                completion(false)
                return
            }
            
            guard let data = data else {
                print("❌ Strategy 3: No data received")
                DispatchQueue.main.async {
                    SupabaseService.shared.isLoading = false
                }
                completion(false)
                return
            }
            
            do {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Strategy 3 response: \(jsonString.prefix(100))...")
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let foodItems = try decoder.decode([SupabaseFoodItem].self, from: data)
                if foodItems.isEmpty {
                    print("⚠️ Strategy 3: No food items found")
                    DispatchQueue.main.async {
                        SupabaseService.shared.isLoading = false
                    }
                    completion(false)
                    return
                }
                
                // Success - update the UI
                DispatchQueue.main.async {
                    // Convert to food items
                    let convertedItems = foodItems.map { $0.toFoodItem() }
                    
                    // Apply user preference ranking if we have a current meal type
                    if let currentMealType = UserDefaults.standard.string(forKey: "currentMealType") {
                        SupabaseService.shared.foodItems = SearchRankingService.shared.rankSearchResults(foods: convertedItems, mealType: currentMealType)
                    } else {
                        // Even without meal context, still rank by nutritional completeness
                        SupabaseService.shared.foodItems = SearchRankingService.shared.rankByNutritionalCompleteness(foods: convertedItems)
                    }
                    
                    SupabaseService.shared.isLoading = false
                    SupabaseService.shared.errorMessage = nil
                    print("✅ Strategy 3: Found \(foodItems.count) items")
                }
                completion(true)
            } catch {
                print("❌ Strategy 3: JSON parsing error - \(error)")
                DispatchQueue.main.async {
                    SupabaseService.shared.isLoading = false
                }
                completion(false)
            }
        }
    }
