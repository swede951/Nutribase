import Foundation
import Combine

/// Service for interacting with Typesense search API
class TypesenseService: ObservableObject {
    // MARK: - Properties
    
    /// Configuration for Typesense
    private struct TypesenseConfig {
        static let apiURL = "https://h8ugnjal1c65sm2op-1.a1.typesense.net"
        
        // Use search-only API key for client-side operations
        // This key has documents:search and collections:get permissions
        static let searchOnlyApiKey = "t5mEztNYGfzSotyavuBpucB5rPmtEMh"
    }
    
    /// Shared instance for singleton access
    static let shared = TypesenseService()
    
    /// URL session for network requests
    private let session: URLSession
    
    // MARK: - Initialization
    
    private init() {
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
    }
    
    // MARK: - Search Methods
    
    /// Search for food items by barcode
    /// - Parameters:
    ///   - barcode: The barcode to search for
    ///   - completion: Completion handler with food item or error
    func searchByBarcode(barcode: String, completion: @escaping (FoodItem?, Error?) -> Void) {
        // Build search parameters for exact barcode match
        let searchParams: [String: Any] = [
            "q": barcode,
            "query_by": "barcode",
            "filter_by": "barcode:=\"\(barcode)\"" // Exact match filter
        ]
        
        // Convert parameters to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: searchParams) else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize search parameters"]))
            return
        }
        
        // Create URL request
        guard let url = URL(string: "\(TypesenseConfig.apiURL)/collections/foods/documents/search") else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // The API key should be sent as plain text in the header
        request.setValue(TypesenseConfig.searchOnlyApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        // Execute request
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "TypesenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            
            do {
                // Parse response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let hits = json["hits"] as? [[String: Any]],
                   !hits.isEmpty,
                   let document = hits[0]["document"] as? [String: Any] {
                    
                    // Extract required fields
                    guard let _ = document["id"] as? String,
                          let name = document["name"] as? String else {
                        completion(nil, NSError(domain: "TypesenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid document format"]))
                        return
                    }
                    
                    // Extract other fields
                    let brand = document["brand"] as? String
                    let barcode = document["barcode"] as? String
                    let novaScore = document["nova_score"] as? Int
                    let nutriScoreGrade = document["nutriscore_grade"] as? String
                    
                    // Parse nutrients JSON
                    var nutrients: [String: Double] = [:]
                    if let nutrientsStr = document["nutrients"] as? String,
                       let nutrientsData = nutrientsStr.data(using: .utf8) {
                        if let nutrientsJson = try? JSONSerialization.jsonObject(with: nutrientsData) as? [String: Any] {
                            for (key, value) in nutrientsJson {
                                if let doubleValue = value as? Double {
                                    nutrients[key] = doubleValue
                                } else if let stringValue = value as? String, let doubleValue = Double(stringValue) {
                                    nutrients[key] = doubleValue
                                }
                            }
                        }
                    }
                    
                    // Extract nutrient values with defaults
                    let calories = nutrients["calories"] != nil ? Int(nutrients["calories"]!) : 0
                    let protein = nutrients["protein"] ?? 0.0
                    let carbs = nutrients["carbohydrates"] ?? 0.0
                    let fat = nutrients["fat"] ?? 0.0
                    let servingSize = document["serving_size"] as? String
                    let servingsPerPackage = nutrients["servings_per_package"]
                    let servingType = document["serving_type"] as? String
                    
                    // Create FoodItem with required parameters
                    let foodItem = FoodItem(
                        name: name,
                        brandName: brand,
                        barcode: barcode,
                        calories: calories,
                        protein: protein,
                        carbs: carbs,
                        fat: fat,
                        novaScore: novaScore ?? 0,
                        nutriScoreGrade: nutriScoreGrade,
                        servingSize: servingSize,
                        servingsPerPackage: servingsPerPackage,
                        servingType: servingType
                    )
                    
                    completion(foodItem, nil)
                } else {
                    // No results found
                    completion(nil, nil)
                }
            } catch {
                completion(nil, error)
            }
        }
        
        task.resume()
    }
    
    /// Search for food items using Typesense
    /// - Parameters:
    ///   - query: The search query string
    ///   - limit: Maximum number of results to return
    ///   - completion: Completion handler with search results or error
    func searchFoods(query: String, limit: Int = 50, completion: @escaping ([FoodItem]?, Error?) -> Void) {
        // Normalize the query (lowercase, remove punctuation)
        let normalizedQuery = normalizeSearchQuery(query)
        
        // Build search parameters
        let searchParams: [String: Any] = [
            "q": normalizedQuery,
            "query_by": "name, brand, ingredients_text",
            "sort_by": "sort_score:desc",
            "per_page": limit,
            "highlight_full_fields": "name, brand, ingredients_text"
        ]
        
        // Convert parameters to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: searchParams) else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize search parameters"]))
            return
        }
        
        // Create URL request
        guard let url = URL(string: "\(TypesenseConfig.apiURL)/collections/foods/documents/search") else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // The API key should be sent as plain text in the header
        request.setValue(TypesenseConfig.searchOnlyApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        // Execute request
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "TypesenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            
            // Debug: Print raw response
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("📝 Raw Typesense response: \(rawResponse)")
            } else {
                print("⚠️ Could not decode response data as UTF-8 string")
            }
            
            do {
                // Parse response
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // Check for error message
                if let errorMessage = json?["message"] as? String {
                    print("⚠️ Typesense API error: \(errorMessage)")
                    completion(nil, NSError(domain: "TypesenseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Typesense API error: \(errorMessage)"]))
                    return
                }
                
                // Check for hits
                if let hits = json?["hits"] as? [[String: Any]] {
                    
                    // Convert Typesense documents to FoodItems
                    let foodItems = hits.compactMap { hit -> FoodItem? in
                        guard let document = hit["document"] as? [String: Any],
                              let _ = document["id"] as? String,
                              let name = document["name"] as? String else {
                            return nil
                        }
                        
                        // Extract other fields
                        let brand = document["brand"] as? String
                        let barcode = document["barcode"] as? String
                        let novaScore = document["nova_score"] as? Int
                        let nutriScoreGrade = document["nutriscore_grade"] as? String
                        
                        // Parse ingredients (for future use with NOVA classification)
                        // Currently unused but kept for future integration with NOVAClassificationService
                        var _: [String] = []
                        if let ingredientsArray = document["ingredients"] as? [String] {
                            _ = ingredientsArray
                        } else if let ingredientsText = document["ingredients_text"] as? String {
                            _ = ingredientsText.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                        }
                        
                        // Parse nutrients JSON
                        var nutrients: [String: Double] = [:]
                        if let nutrientsStr = document["nutrients"] as? String,
                           let nutrientsData = nutrientsStr.data(using: .utf8) {
                            if let nutrientsJson = try? JSONSerialization.jsonObject(with: nutrientsData) as? [String: Any] {
                                for (key, value) in nutrientsJson {
                                    if let doubleValue = value as? Double {
                                        nutrients[key] = doubleValue
                                    } else if let stringValue = value as? String, let doubleValue = Double(stringValue) {
                                        nutrients[key] = doubleValue
                                    }
                                }
                            }
                        }
                        
                        // Extract nutrient values with defaults
                        let calories = nutrients["calories"] != nil ? Int(nutrients["calories"]!) : 0
                        let protein = nutrients["protein"] ?? 0.0
                        let carbs = nutrients["carbohydrates"] ?? 0.0
                        let fat = nutrients["fat"] ?? 0.0
                        let servingSize = document["serving_size"] as? String
                        let servingsPerPackage = nutrients["servings_per_package"]
                        let servingType = document["serving_type"] as? String
                        
                        // Create FoodItem with required parameters
                        return FoodItem(
                            name: name,
                            brandName: brand,
                            barcode: barcode,
                            calories: calories,
                            protein: protein,
                            carbs: carbs,
                            fat: fat,
                            novaScore: novaScore ?? 0,
                            nutriScoreGrade: nutriScoreGrade,
                            servingSize: servingSize,
                            servingsPerPackage: servingsPerPackage,
                            servingType: servingType
                        )
                    }
                    
                    completion(foodItems, nil)
                } else {
                    completion(nil, NSError(domain: "TypesenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"]))
                }
            } catch {
                completion(nil, error)
            }
        }
        
        task.resume()
    }
    
    /// Search for food items using Typesense with Combine
    /// - Parameters:
    ///   - query: The search query string
    ///   - limit: Maximum number of results to return
    /// - Returns: A publisher with search results
    func searchFoodsPublisher(query: String, limit: Int = 50) -> AnyPublisher<[FoodItem], Error> {
        return Future<[FoodItem], Error> { promise in
            self.searchFoods(query: query, limit: limit) { foods, error in
                if let error = error {
                    promise(.failure(error))
                } else if let foods = foods {
                    promise(.success(foods))
                } else {
                    promise(.success([]))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Testing Methods
    
    /// Test connection to Typesense server
    /// - Parameter completion: Completion handler with success status and message
    func testConnection(completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "\(TypesenseConfig.apiURL)/health") else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // The API key should be sent as plain text in the header
        request.setValue(TypesenseConfig.searchOnlyApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, "Connection error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid response")
                return
            }
            
            if httpResponse.statusCode == 200 {
                completion(true, "Connection successful")
            } else {
                completion(false, "Server returned status code: \(httpResponse.statusCode)")
            }
        }
        
        task.resume()
    }
    
    // MARK: - Helper Methods
    
    /// Normalize search query by removing punctuation and converting to lowercase
    /// - Parameter query: The original query string
    /// - Returns: Normalized query string
    private func normalizeSearchQuery(_ query: String) -> String {
        // Convert to lowercase
        var normalizedQuery = query.lowercased()
        
        // Remove punctuation
        normalizedQuery = normalizedQuery.components(separatedBy: CharacterSet.punctuationCharacters).joined(separator: " ")
        
        // Remove extra whitespace
        normalizedQuery = normalizedQuery.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        return normalizedQuery
    }
    
    /// Get a specific food item by ID
    /// - Parameters:
    ///   - id: Food item ID
    ///   - completion: Completion handler with food item or error
    func getFoodById(id: String, completion: @escaping (FoodItem?, Error?) -> Void) {
        guard let url = URL(string: "\(TypesenseConfig.apiURL)/collections/foods/documents/\(id)") else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // The API key should be sent as plain text in the header
        request.setValue(TypesenseConfig.searchOnlyApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "TypesenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            
            do {
                if let document = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let _ = document["id"] as? String,
                   let name = document["name"] as? String {
                    
                    // Extract other fields
                    let brand = document["brand"] as? String
                    let barcode = document["barcode"] as? String
                    let novaScore = document["nova_score"] as? Int
                    let nutriScoreGrade = document["nutriscore_grade"] as? String
                    
                    // Parse ingredients (for future use with NOVA classification)
                    // Currently unused but kept for future integration with NOVAClassificationService
                    var _: [String] = []
                    if let ingredientsArray = document["ingredients"] as? [String] {
                        _ = ingredientsArray
                    } else if let ingredientsText = document["ingredients_text"] as? String {
                        _ = ingredientsText.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    }
                    
                    // Parse nutrients JSON
                    var nutrients: [String: Double] = [:]
                    if let nutrientsStr = document["nutrients"] as? String,
                       let nutrientsData = nutrientsStr.data(using: .utf8) {
                        if let nutrientsJson = try? JSONSerialization.jsonObject(with: nutrientsData) as? [String: Any] {
                            for (key, value) in nutrientsJson {
                                if let doubleValue = value as? Double {
                                    nutrients[key] = doubleValue
                                } else if let stringValue = value as? String, let doubleValue = Double(stringValue) {
                                    nutrients[key] = doubleValue
                                }
                            }
                        }
                    }
                    
                    // Extract nutrient values with defaults
                    let calories = nutrients["calories"] != nil ? Int(nutrients["calories"]!) : 0
                    let protein = nutrients["protein"] ?? 0.0
                    let carbs = nutrients["carbohydrates"] ?? 0.0
                    let fat = nutrients["fat"] ?? 0.0
                    let servingSize = document["serving_size"] as? String
                    let servingsPerPackage = nutrients["servings_per_package"]
                    let servingType = document["serving_type"] as? String
                    
                    // Create FoodItem with required parameters
                    let foodItem = FoodItem(
                        name: name,
                        brandName: brand,
                        barcode: barcode,
                        calories: calories,
                        protein: protein,
                        carbs: carbs,
                        fat: fat,
                        novaScore: novaScore ?? 0,
                        nutriScoreGrade: nutriScoreGrade,
                        servingSize: servingSize,
                        servingsPerPackage: servingsPerPackage,
                        servingType: servingType
                    )
                    
                    completion(foodItem, nil)
                } else {
                    completion(nil, NSError(domain: "TypesenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"]))
                }
            } catch {
                completion(nil, error)
            }
        }
        
        task.resume()
    }
}
