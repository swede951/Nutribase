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
    request.addValue(TypesenseConfig.searchOnlyApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
    
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
                guard let id = document["id"] as? String,
                      let name = document["name"] as? String else {
                    completion(nil, NSError(domain: "TypesenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid document format"]))
                    return
                }
                
                // Extract other fields
                let brand = document["brand"] as? String
                let barcode = document["barcode"] as? String
                let novaScore = document["nova_score"] as? Int
                let nutriScoreGrade = document["nutriscore_grade"] as? String
                
                // Parse ingredients
                var ingredients: [String] = []
                if let ingredientsArray = document["ingredients"] as? [String] {
                    ingredients = ingredientsArray
                } else if let ingredientsText = document["ingredients_text"] as? String {
                    ingredients = ingredientsText.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
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
                // No results found
                completion(nil, nil)
            }
        } catch {
            completion(nil, error)
        }
    }
    
    task.resume()
}
