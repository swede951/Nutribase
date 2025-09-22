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
        static let searchOnlyApiKey = "TozhqOtg2gh7kLUUeteL8LVTtuKRv9gq"
        
        // Admin API key for write operations (adding/updating foods)
        // This key has documents:* permissions
        static let adminApiKey = "t5mEztNYGfzSotyavuBpucB5rPmtEMh_admin"
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
        print("🔍 TypesenseService: Searching for barcode: \(barcode)")
        
        // Build URL with query parameters (GET request like the browser)
        var components = URLComponents(string: "\(TypesenseConfig.apiURL)/collections/foods/documents/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: barcode),
            URLQueryItem(name: "query_by", value: "barcode"),
            URLQueryItem(name: "filter_by", value: "barcode:=\(barcode)"),
            URLQueryItem(name: "per_page", value: "10")
        ]
        
        guard let url = components.url else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        print("🔍 Request URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(TypesenseConfig.searchOnlyApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        // Execute request
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ TypesenseService: Network error: \(error)")
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                print("❌ TypesenseService: No data received")
                completion(nil, NSError(domain: "TypesenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            
            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔍 TypesenseService: Raw response: \(responseString)")
            }
            
            do {
                // Parse response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🔍 TypesenseService: Parsed JSON: \(json)")
                    
                    if let hits = json["hits"] as? [[String: Any]] {
                        print("🔍 TypesenseService: Found \(hits.count) hits")
                        
                        if !hits.isEmpty,
                           let document = hits[0]["document"] as? [String: Any] {
                            print("🔍 TypesenseService: First document keys: \(document.keys.sorted())")
                            print("🔍 TypesenseService: Full document: \(document)")
                    
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
                    
                    // Extract nutrient values directly from nutrients_text field
                    var nutrientsText: [String: Any] = [:]
                    if let nutrientsTextStr = document["nutrients_text"] as? String,
                       let nutrientsData = nutrientsTextStr.data(using: .utf8) {
                        if let nutrientsJson = try? JSONSerialization.jsonObject(with: nutrientsData) as? [String: Any] {
                            nutrientsText = nutrientsJson
                            print("🔍 TypesenseService: Parsed nutrients_text: \(nutrientsText)")
                        }
                    }
                    // Debug removed for performance
                    
                    // Handle different number types from JSON
                    let calories: Int
                    if let caloriesNum = nutrientsText["calories"] as? NSNumber {
                        calories = caloriesNum.intValue
                    } else if let caloriesDouble = nutrientsText["calories"] as? Double {
                        calories = Int(caloriesDouble)
                    } else if let caloriesInt = nutrientsText["calories"] as? Int {
                        calories = caloriesInt
                    } else {
                        calories = 0
                    }
                    
                    let protein: Double
                    if let proteinNum = nutrientsText["protein"] as? NSNumber {
                        protein = proteinNum.doubleValue
                    } else if let proteinDouble = nutrientsText["protein"] as? Double {
                        protein = proteinDouble
                    } else {
                        protein = 0.0
                    }
                    
                    let carbs: Double
                    if let carbsNum = nutrientsText["carbohydrates"] as? NSNumber {
                        carbs = carbsNum.doubleValue
                    } else if let carbsDouble = nutrientsText["carbohydrates"] as? Double {
                        carbs = carbsDouble
                    } else {
                        carbs = 0.0
                    }
                    
                    let fat: Double
                    if let fatNum = nutrientsText["fat"] as? NSNumber {
                        fat = fatNum.doubleValue
                    } else if let fatDouble = nutrientsText["fat"] as? Double {
                        fat = fatDouble
                    } else {
                        fat = 0.0
                    }
                    let servingSize = nutrientsText["serving_size"] as? String ?? document["serving_size"] as? String
                    let servingsPerPackage = nutrientsText["servings_per_package"] as? Double
                    let servingType = document["serving_type"] as? String
                    
                    // Debug removed for performance
                    
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
                            print("🔍 TypesenseService: No hits found for barcode \(barcode)")
                            completion(nil, nil)
                            return
                        }
                    } else {
                        print("❌ TypesenseService: No hits array in response")
                        completion(nil, nil)
                        return
                    }
                } else {
                    print("❌ TypesenseService: Failed to parse JSON response")
                    completion(nil, nil)
                    return
                }
            } catch {
                print("❌ TypesenseService: JSON parsing error: \(error)")
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
    
    /// Add a new food item to the Typesense database
    /// - Parameters:
    ///   - foodItem: The food item to add
    ///   - ingredients: List of ingredients
    ///   - completion: Completion handler with success flag and optional error message
    func addFoodToTypesense(_ foodItem: FoodItem, ingredients: [String] = [], completion: @escaping (Bool, String?) -> Void) {
        print("==== STARTING ADD FOOD TO TYPESENSE ====")
        print("Food name: \(foodItem.name)")
        
        // Create the nutrients object as a JSON string
        let nutrientsDict: [String: Any] = [
            "calories": foodItem.calories,
            "protein": foodItem.protein,
            "carbohydrates": foodItem.carbs,
            "fat": foodItem.fat,
            "serving_size": foodItem.servingSize ?? "100g",
            "servings_per_package": foodItem.servingsPerPackage ?? 1.0
        ]
        
        // Convert nutrients to JSON string
        guard let nutrientsData = try? JSONSerialization.data(withJSONObject: nutrientsDict),
              let nutrientsJsonString = String(data: nutrientsData, encoding: .utf8) else {
            completion(false, "Failed to serialize nutrients data")
            return
        }
        
        // Create the food item document
        var document: [String: Any] = [
            "name": foodItem.name,
            "nova_score": foodItem.novaScore,
            "nutrients": nutrientsJsonString,
            "verified": true,
            "serving_type": foodItem.servingType ?? "weight",
            "ingredients_text": ingredients.joined(separator: ", ")
        ]
        
        // Add brand name and barcode if available
        if let brandName = foodItem.brandName, !brandName.isEmpty {
            document["brand"] = brandName
        }
        
        if let barcode = foodItem.barcode, !barcode.isEmpty {
            document["barcode"] = barcode
        }
        
        // Convert document to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: document) else {
            completion(false, "Failed to serialize document data")
            return
        }
        
        // Create URL request
        guard let url = URL(string: "\(TypesenseConfig.apiURL)/collections/foods/documents") else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(TypesenseConfig.adminApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        // Debug: Print the request details
        print("🍽️ Adding food item to Typesense: \(foodItem.name)")
        print("📡 Request URL: \(url)")
        print("📦 Request body: \(String(data: jsonData, encoding: .utf8) ?? "<invalid JSON>")")
        
        // Execute request
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                completion(false, "Invalid response")
                return
            }
            
            print("📊 Response status code: \(httpResponse.statusCode)")
            
            // Check status code
            if (200...299).contains(httpResponse.statusCode) {
                print("✅ Food item added to Typesense successfully")
                completion(true, nil)
            } else {
                // Try to parse error message
                var errorMessage = "Failed with status code: \(httpResponse.statusCode)"
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("❌ Error response: \(responseString)")
                    errorMessage = responseString
                }
                completion(false, errorMessage)
            }
        }
        
        task.resume()
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
                    
                    // Extract nutrient values directly from nutrients_text field
                    var nutrientsText: [String: Any] = [:]
                    if let nutrientsTextStr = document["nutrients_text"] as? String,
                       let nutrientsData = nutrientsTextStr.data(using: .utf8) {
                        if let nutrientsJson = try? JSONSerialization.jsonObject(with: nutrientsData) as? [String: Any] {
                            nutrientsText = nutrientsJson
                            print("🔍 TypesenseService: Parsed nutrients_text: \(nutrientsText)")
                        }
                    }
                    // Debug removed for performance
                    
                    // Handle different number types from JSON
                    let calories: Int
                    if let caloriesNum = nutrientsText["calories"] as? NSNumber {
                        calories = caloriesNum.intValue
                    } else if let caloriesDouble = nutrientsText["calories"] as? Double {
                        calories = Int(caloriesDouble)
                    } else if let caloriesInt = nutrientsText["calories"] as? Int {
                        calories = caloriesInt
                    } else {
                        calories = 0
                    }
                    
                    let protein: Double
                    if let proteinNum = nutrientsText["protein"] as? NSNumber {
                        protein = proteinNum.doubleValue
                    } else if let proteinDouble = nutrientsText["protein"] as? Double {
                        protein = proteinDouble
                    } else {
                        protein = 0.0
                    }
                    
                    let carbs: Double
                    if let carbsNum = nutrientsText["carbohydrates"] as? NSNumber {
                        carbs = carbsNum.doubleValue
                    } else if let carbsDouble = nutrientsText["carbohydrates"] as? Double {
                        carbs = carbsDouble
                    } else {
                        carbs = 0.0
                    }
                    
                    let fat: Double
                    if let fatNum = nutrientsText["fat"] as? NSNumber {
                        fat = fatNum.doubleValue
                    } else if let fatDouble = nutrientsText["fat"] as? Double {
                        fat = fatDouble
                    } else {
                        fat = 0.0
                    }
                    let servingSize = nutrientsText["serving_size"] as? String ?? document["serving_size"] as? String
                    let servingsPerPackage = nutrientsText["servings_per_package"] as? Double
                    let servingType = document["serving_type"] as? String
                    
                    // Debug removed for performance
                    
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
