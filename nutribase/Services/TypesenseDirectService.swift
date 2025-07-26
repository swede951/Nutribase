import Foundation
import Combine

/// Service for interacting with Typesense using direct HTTP requests
class TypesenseDirectService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = TypesenseDirectService()
    
    private init() {}
    
    // MARK: - Properties
    
    private struct TypesenseConfig {
        static let apiURL = "https://h8ugnjal1c65sm2op-1.a1.typesense.net"
        static let searchOnlyApiKey = "TozhqOtg2gh7kLUUeteL8LVTtuKRv9gq"
        static let collectionName = "foods"
    }
    
    // MARK: - Public Methods
    
    /// Search for foods matching the given query
    func searchFoods(query: String, completion: @escaping ([FoodItem]?, Error?) -> Void) {
        guard !query.isEmpty else {
            completion([], nil)
            return
        }
        
        print("🔍 Searching Typesense for: \(query) using direct HTTP")
        
        // Build the URL for the search endpoint
        let urlString = "\(TypesenseConfig.apiURL)/collections/\(TypesenseConfig.collectionName)/documents/search"
        guard var urlComponents = URLComponents(string: urlString) else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        // Add search parameters
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "query_by", value: "name"),
            URLQueryItem(name: "per_page", value: "20")
        ]
        
        guard let url = urlComponents.url else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL components"]))
            return
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Important: Use setValue instead of addValue for the API key header
        request.setValue(TypesenseConfig.searchOnlyApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        // Execute the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Check for network errors
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    let responseError = NSError(
                        domain: "TypesenseService",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"]
                    )
                    
                    // If we have response data, include it in the error
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Error response: \(responseString)")
                    }
                    
                    DispatchQueue.main.async {
                        completion(nil, responseError)
                    }
                    return
                }
            }
            
            // Ensure we have data
            guard let data = data else {
                print("❌ No data received")
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "TypesenseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                }
                return
            }
            
            do {
                // Parse the JSON response
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                print("📝 Raw Typesense response received")
                
                // Extract hits from the response
                guard let hits = jsonResponse?["hits"] as? [[String: Any]] else {
                    print("❌ No hits in response")
                    DispatchQueue.main.async {
                        completion([], nil) // Empty results but not an error
                    }
                    return
                }
                
                // Convert hits to FoodItem objects
                var foods: [FoodItem] = []
                
                for hit in hits {
                    guard let document = hit["document"] as? [String: Any],
                          let name = document["name"] as? String else {
                        continue
                    }
                    
                    // Extract other fields with safe type casting
                    let brandName = document["brand"] as? String
                    let barcode = document["barcode"] as? String
                    
                    // Extract nutritional data from nutrients_text JSON string
                    print("📊 Processing nutritional data for \(name)")
                    
                    // Initialize default values
                    var calories = 0
                    var protein: Double = 0
                    var carbs: Double = 0
                    var fat: Double = 0
                    var servingSize: String? = nil
                    var servingsPerPackage: Double? = nil
                    
                    // Try to get the nutrients_text field which contains all nutritional data as a JSON string
                    if let nutrientsText = document["nutrients_text"] as? String {
                        print("  ✅ Found nutrients_text: \(nutrientsText)")
                        
                        // Parse the JSON string into a dictionary
                        if let nutrientsData = nutrientsText.data(using: .utf8),
                           let nutrients = try? JSONSerialization.jsonObject(with: nutrientsData) as? [String: Any] {
                            
                            // Extract nutritional values
                            if let caloriesValue = nutrients["calories"] as? Int {
                                calories = caloriesValue
                                print("  - calories: \(calories)")
                            } else if let caloriesValue = nutrients["calories"] as? Double {
                                calories = Int(caloriesValue)
                                print("  - calories (from Double): \(calories)")
                            }
                            
                            if let proteinValue = nutrients["protein"] as? Double {
                                protein = proteinValue
                                print("  - protein: \(protein)")
                            } else if let proteinValue = nutrients["protein"] as? Int {
                                protein = Double(proteinValue)
                                print("  - protein (from Int): \(protein)")
                            }
                            
                            // Carbs might be stored as "carbohydrates" in the JSON
                            if let carbsValue = nutrients["carbohydrates"] as? Double {
                                carbs = carbsValue
                                print("  - carbs: \(carbs)")
                            } else if let carbsValue = nutrients["carbs"] as? Double {
                                carbs = carbsValue
                                print("  - carbs: \(carbs)")
                            } else if let carbsValue = nutrients["carbohydrates"] as? Int {
                                carbs = Double(carbsValue)
                                print("  - carbs (from Int): \(carbs)")
                            }
                            
                            if let fatValue = nutrients["fat"] as? Double {
                                fat = fatValue
                                print("  - fat: \(fat)")
                            } else if let fatValue = nutrients["fat"] as? Int {
                                fat = Double(fatValue)
                                print("  - fat (from Int): \(fat)")
                            }
                            
                            // Get serving information
                            servingSize = nutrients["serving_size"] as? String
                            servingsPerPackage = nutrients["servings_per_package"] as? Double
                        } else {
                            print("  ❌ Failed to parse nutrients_text JSON")
                        }
                    } else {
                        print("  ❌ No nutrients_text field found")
                    }
                    
                    // Get NOVA score and Nutri-Score grade
                    let novaScore = document["nova_score"] as? Int ?? 0
                    
                    // Nutri-Score grade might be stored as nutri_score or nutriscore_grade
                    var nutriScoreGrade = document["nutri_score"] as? String
                    if nutriScoreGrade == nil {
                        nutriScoreGrade = document["nutriscore_grade"] as? String
                    }
                    
                    // Use serving type from document if available
                    let servingType = document["serving_unit"] as? String
                    
                    // Create FoodItem
                    let food = FoodItem(
                        name: name,
                        brandName: brandName,
                        barcode: barcode,
                        calories: calories,
                        protein: protein,
                        carbs: carbs,
                        fat: fat,
                        novaScore: novaScore,
                        nutriScoreGrade: nutriScoreGrade,
                        servingSize: servingSize,
                        servingsPerPackage: servingsPerPackage,
                        servingType: servingType
                    )
                    
                    // Debug log for the created food item
                    print("✅ Created food item: \(name)")
                    print("  - calories: \(calories)")
                    print("  - protein: \(protein)g")
                    print("  - carbs: \(carbs)g")
                    print("  - fat: \(fat)g")
                    
                    foods.append(food)
                }
                
                print("✅ Found \(foods.count) foods matching query: \(query)")
                
                DispatchQueue.main.async {
                    completion(foods, nil)
                }
            } catch {
                print("❌ JSON parsing error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
        
        task.resume()
    }
    
    /// Test the connection to Typesense
    func testConnection(completion: @escaping (Bool, String?) -> Void) {
        print("🔍 Testing Typesense connection with direct HTTP...")
        
        // Build the URL for the health endpoint
        let urlString = "\(TypesenseConfig.apiURL)/health"
        guard let url = URL(string: urlString) else {
            completion(false, "Invalid URL")
            return
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Important: Use setValue instead of addValue for the API key header
        request.setValue(TypesenseConfig.searchOnlyApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        // Execute the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Check for network errors
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false, "Network error: \(error.localizedDescription)")
                }
                return
            }
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    // If we have response data, include it in the error
                    var errorMessage = "HTTP Error: \(httpResponse.statusCode)"
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Error response: \(responseString)")
                        errorMessage += " - \(responseString)"
                    }
                    
                    DispatchQueue.main.async {
                        completion(false, errorMessage)
                    }
                    return
                }
            }
            
            // Ensure we have data
            guard let data = data else {
                print("❌ No data received")
                DispatchQueue.main.async {
                    completion(false, "No data received")
                }
                return
            }
            
            do {
                // Parse the JSON response
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: [])
                let responseString = String(describing: jsonResponse)
                print("✅ Typesense health check successful: \(responseString)")
                
                DispatchQueue.main.async {
                    completion(true, "Connection successful")
                }
            } catch {
                print("❌ JSON parsing error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false, "JSON parsing error: \(error.localizedDescription)")
                }
            }
        }
        
        task.resume()
    }
    
    /// Search for a food by barcode
    func searchByBarcode(barcode: String, completion: @escaping (FoodItem?, Error?) -> Void) {
        print("🔍 Searching Typesense for barcode: \(barcode) using direct HTTP")
        
        // Build the URL for the search endpoint
        let urlString = "\(TypesenseConfig.apiURL)/collections/\(TypesenseConfig.collectionName)/documents/search"
        guard var urlComponents = URLComponents(string: urlString) else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        // Add search parameters for exact barcode match
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: barcode),
            URLQueryItem(name: "query_by", value: "barcode"),
            URLQueryItem(name: "filter_by", value: "barcode:=\"\(barcode)\""),
            URLQueryItem(name: "per_page", value: "1")
        ]
        
        guard let url = urlComponents.url else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL components"]))
            return
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Important: Use setValue instead of addValue for the API key header
        request.setValue(TypesenseConfig.searchOnlyApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        // Execute the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Check for network errors
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    let responseError = NSError(
                        domain: "TypesenseService",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"]
                    )
                    
                    // If we have response data, include it in the error
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Error response: \(responseString)")
                    }
                    
                    DispatchQueue.main.async {
                        completion(nil, responseError)
                    }
                    return
                }
            }
            
            // Ensure we have data
            guard let data = data else {
                print("❌ No data received")
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "TypesenseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                }
                return
            }
            
            do {
                // Parse the JSON response
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                print("📝 Raw Typesense barcode response received")
                
                // Extract hits from the response
                guard let hits = jsonResponse?["hits"] as? [[String: Any]], !hits.isEmpty,
                      let document = hits[0]["document"] as? [String: Any],
                      let name = document["name"] as? String else {
                    print("❌ No matching food found for barcode: \(barcode)")
                    DispatchQueue.main.async {
                        completion(nil, NSError(domain: "TypesenseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No food found with barcode: \(barcode)"]))
                    }
                    return
                }
                
                // Extract other fields with safe type casting
                let brandName = document["brand"] as? String
                let barcode = document["barcode"] as? String
                let novaScore = document["nova_score"] as? Int ?? 0
                let nutriScoreGrade = document["nutri_score"] as? String
                
                // Initialize default values
                var calories = 0
                var protein: Double = 0
                var carbs: Double = 0
                var fat: Double = 0
                
                // Try to get the nutrients_text field which contains all nutritional data as a JSON string
                if let nutrientsText = document["nutrients_text"] as? String {
                    print("  ✅ Found nutrients_text in barcode search: \(nutrientsText)")
                    
                    // Parse the JSON string into a dictionary
                    if let nutrientsData = nutrientsText.data(using: .utf8),
                       let nutrients = try? JSONSerialization.jsonObject(with: nutrientsData) as? [String: Any] {
                        
                        // Extract nutritional values
                        if let caloriesValue = nutrients["calories"] as? Int {
                            calories = caloriesValue
                        } else if let caloriesValue = nutrients["calories"] as? Double {
                            calories = Int(caloriesValue)
                        }
                        
                        if let proteinValue = nutrients["protein"] as? Double {
                            protein = proteinValue
                        } else if let proteinValue = nutrients["protein"] as? Int {
                            protein = Double(proteinValue)
                        }
                        
                        // Carbs might be stored as "carbohydrates" in the JSON
                        if let carbsValue = nutrients["carbohydrates"] as? Double {
                            carbs = carbsValue
                        } else if let carbsValue = nutrients["carbs"] as? Double {
                            carbs = carbsValue
                        } else if let carbsValue = nutrients["carbohydrates"] as? Int {
                            carbs = Double(carbsValue)
                        }
                        
                        if let fatValue = nutrients["fat"] as? Double {
                            fat = fatValue
                        } else if let fatValue = nutrients["fat"] as? Int {
                            fat = Double(fatValue)
                        }
                    } else {
                        print("  ❌ Failed to parse nutrients_text JSON in barcode search")
                    }
                } else {
                    // Fallback to direct fields if nutrients_text is not available
                    calories = document["calories"] as? Int ?? 0
                    protein = (document["protein"] as? NSNumber)?.doubleValue ?? 0
                    carbs = (document["carbs"] as? NSNumber)?.doubleValue ?? 0
                    fat = (document["fat"] as? NSNumber)?.doubleValue ?? 0
                    print("  ❌ No nutrients_text field found in barcode search, using direct fields")
                }
                
                // Handle serving size (could be number or string)
                var servingSize: String? = nil
                if let servingSizeNum = document["serving_size"] as? NSNumber {
                    servingSize = "\(servingSizeNum)"
                } else if let servingSizeStr = document["serving_size"] as? String {
                    servingSize = servingSizeStr
                }
                
                let servingType = document["serving_unit"] as? String
                
                // Create FoodItem
                let food = FoodItem(
                    name: name,
                    brandName: brandName,
                    barcode: barcode,
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    novaScore: novaScore,
                    nutriScoreGrade: nutriScoreGrade,
                    servingSize: servingSize,
                    servingsPerPackage: nil,
                    servingType: servingType
                )
                
                print("✅ Found food with barcode: \(barcode)")
                
                DispatchQueue.main.async {
                    completion(food, nil)
                }
            } catch {
                print("❌ JSON parsing error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
        
        task.resume()
    }
}
