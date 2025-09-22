import Foundation

/// Data structure for tracking user's food history (silent personalization)
struct FoodHistoryData: Codable {
    var frequency: Int
    var firstEaten: Date
    var lastEaten: Date
    var totalCalories: Int
}
import Combine

/// Service for interacting with Typesense using direct HTTP requests with enhanced search capabilities
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
    
    // MARK: - Search Result Caching
    
    private var searchCache: [String: CachedSearchResult] = [:]
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    private var hasInspectedSchema = false // Track if we've inspected the schema
    
    private struct CachedSearchResult {
        let results: [FoodItem]
        let timestamp: Date
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 300 // 5 minutes
        }
    }
    
    // MARK: - Public Methods
    
    /// Search for foods matching the given query with enhanced search capabilities
    func searchFoods(query: String, completion: @escaping ([FoodItem]?, Error?) -> Void) {
        guard !query.isEmpty else {
            completion([], nil)
            return
        }
        // Check cache first
        let cacheKey = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let cachedResult = searchCache[cacheKey], !cachedResult.isExpired {
            print("📦 Returning cached results for: \(query) (\(cachedResult.results.count) items)")
            DispatchQueue.main.async {
                completion(cachedResult.results, nil)
            }
            return
        }
        
        print("🔍 Enhanced Typesense search for: \(query) using direct HTTP")
        
        // One-time schema inspection to understand available fields (for debugging)
        if !hasInspectedSchema {
            hasInspectedSchema = true
            inspectSchema { schema, error in
                if let error = error {
                    print("⚠️ Schema inspection failed: \(error.localizedDescription)")
                } else {
                    print("📊 Schema inspection completed - check console for field details")
                }
            }
        }
        
        // Perform search with retry logic
        performSearchWithRetry(query: query, cacheKey: cacheKey, retryCount: 0, completion: completion)
    }
    
    /// Perform search with retry logic for better reliability
    private func performSearchWithRetry(query: String, cacheKey: String, retryCount: Int, completion: @escaping ([FoodItem]?, Error?) -> Void) {
        // Build the URL for the search endpoint
        let urlString = "\(TypesenseConfig.apiURL)/collections/\(TypesenseConfig.collectionName)/documents/search"
        guard var urlComponents = URLComponents(string: urlString) else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        // Enhanced search parameters with multi-field search, typo tolerance, and boosting
        urlComponents.queryItems = [
            // Multi-field search with industry-standard field boosting (name gets highest priority)
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "query_by", value: "name,brand,ingredients"),
            URLQueryItem(name: "query_by_weights", value: "10,5,2"), // Industry standard: name 10x, brand 5x, ingredients 2x
            
            // Typo tolerance - allow up to 2 typos for queries longer than 3 characters
            URLQueryItem(name: "typo_tokens_threshold", value: "1"),
            URLQueryItem(name: "num_typos", value: "2"),
            
            // Enable prefix matching for name and brand (better autocomplete experience)
            URLQueryItem(name: "prefix", value: "true,true,false"),
            
            // Increase results for better selection
            URLQueryItem(name: "per_page", value: "50"),
            
            // Optimal ranking using available sortable fields: text relevance first, then custom sort score
            URLQueryItem(name: "sort_by", value: "_text_match:desc,sort_score:desc"),
            
            // Highlight matching terms for better UX (optional)
            URLQueryItem(name: "highlight_full_fields", value: "name,brand")
        ]
        
        guard let url = urlComponents.url else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL components"]))
            return
        }
        
        // Create the request with timeout
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0 // 10 second timeout
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Important: Use setValue instead of addValue for the API key header
        request.setValue(TypesenseConfig.searchOnlyApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        // Execute the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Check for network errors with retry logic
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                
                // Retry for network errors (timeout, connection issues)
                if retryCount < 2 && (error as NSError).code != NSURLErrorCancelled {
                    print("🔄 Retrying search due to network error (attempt \(retryCount + 1)/3)...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount + 1)) {
                        self.performSearchWithRetry(query: query, cacheKey: cacheKey, retryCount: retryCount + 1, completion: completion)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
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
                    
                    // Retry for server errors (5xx) but not client errors (4xx)
                    if retryCount < 2 && httpResponse.statusCode >= 500 {
                        print("🔄 Retrying search due to server error (attempt \(retryCount + 1)/3)...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount + 1)) {
                            self.performSearchWithRetry(query: query, cacheKey: cacheKey, retryCount: retryCount + 1, completion: completion)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(nil, responseError)
                        }
                    }
                    return
                }
            }
            
            // Ensure we have data
            guard let data = data else {
                print("❌ No data received")
                
                // Retry for missing data
                if retryCount < 2 {
                    print("🔄 Retrying search due to missing data (attempt \(retryCount + 1)/3)...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount + 1)) {
                        self.performSearchWithRetry(query: query, cacheKey: cacheKey, retryCount: retryCount + 1, completion: completion)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil, NSError(domain: "TypesenseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                    }
                }
                return
            }
            
            do {
                // Parse the JSON response
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                print("📝 Raw Typesense response received")
                
                guard let hits = jsonResponse?["hits"] as? [[String: Any]] else {
                    print("❌ No hits found in response")
                    DispatchQueue.main.async {
                        completion([], nil)
                    }
                    return
                }
                
                var foods: [FoodItem] = []
                
                for hit in hits {
                    guard let document = hit["document"] as? [String: Any],
                          let name = document["name"] as? String else {
                        continue
                    }
                    
                    print("🍎 Processing food: \(name)")
                    
                    // Extract basic information
                    let brandName = document["brand"] as? String
                    let barcode = document["barcode"] as? String
                    let novaScore = document["nova_score"] as? Int ?? 0
                    let nutriScoreGrade = document["nutriscore_grade"] as? String
                    print("  🎯 Nutriscore_grade field: \(nutriScoreGrade ?? "nil")")
                    
                    // Extract nutritional values with improved parsing
                    var calories = 0
                    var protein = 0.0
                    var carbs = 0.0
                    var fat = 0.0
                    
                    // Try to parse nutrients from JSON string first
                    if let nutrientsText = document["nutrients_text"] as? String,
                       let nutrientsData = nutrientsText.data(using: .utf8),
                       let nutrients = try? JSONSerialization.jsonObject(with: nutrientsData) as? [String: Any] {
                        
                        print("  📊 Parsing nutrients from JSON string")
                        
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
                        } else if let carbsValue = nutrients["carbs"] as? Int {
                            carbs = Double(carbsValue)
                        }
                        
                        if let fatValue = nutrients["fat"] as? Double {
                            fat = fatValue
                        } else if let fatValue = nutrients["fat"] as? Int {
                            fat = Double(fatValue)
                        }
                        
                    } else {
                        // Fallback to direct fields if nutrients_text is not available
                        calories = document["calories"] as? Int ?? 0
                        protein = (document["protein"] as? NSNumber)?.doubleValue ?? 0
                        carbs = (document["carbs"] as? NSNumber)?.doubleValue ?? 0
                        fat = (document["fat"] as? NSNumber)?.doubleValue ?? 0
                        print("  ❌ No nutrients_text field found, using direct fields")
                    }
                    
                    // Handle serving size (could be number or string) - with debugging
                    var servingSize: String? = nil
                    var servingType: String? = nil
                    
                    // First try to get from nutrients_text JSON (if it was parsed above)
                    if let nutrientsText = document["nutrients_text"] as? String,
                       let nutrientsData = nutrientsText.data(using: .utf8),
                       let nutrients = try? JSONSerialization.jsonObject(with: nutrientsData) as? [String: Any] {
                        
                        if let servingSizeValue = nutrients["serving_size"] as? String {
                            servingSize = servingSizeValue
                            print("  📏 Found serving_size in nutrients_text: \(servingSizeValue)")
                        }
                        
                        if let servingUnitValue = nutrients["serving_unit"] as? String {
                            servingType = servingUnitValue
                            print("  📏 Found serving_unit in nutrients_text: \(servingUnitValue)")
                        }
                    }
                    
                    // Fallback to direct document fields if not found in nutrients_text
                    if servingSize == nil {
                        if let servingSizeNum = document["serving_size"] as? NSNumber {
                            servingSize = "\(servingSizeNum)"
                            print("  📏 Found serving_size (number): \(servingSize!)")
                        } else if let servingSizeStr = document["serving_size"] as? String {
                            servingSize = servingSizeStr
                            print("  📏 Found serving_size (string): \(servingSize!)")
                        } else {
                            print("  ❌ No serving_size field found in document or nutrients_text")
                        }
                    }
                    
                    if servingType == nil {
                        servingType = document["serving_unit"] as? String
                        if let servingType = servingType {
                            print("  📏 Found serving_unit: \(servingType)")
                        } else {
                            print("  ❌ No serving_unit field found in document or nutrients_text")
                        }
                    }
                    
                    // Parse ingredients
                    var ingredients: [String] = []
                    if let ingredientsArray = document["ingredients"] as? [String] {
                        ingredients = ingredientsArray
                    } else if let ingredientsText = document["ingredients_text"] as? String {
                        ingredients = ingredientsText.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    }
                    
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
                        servingType: servingType
                    )
                    
                    foods.append(food)
                }
                
                print("✅ Found \(foods.count) foods matching query: \(query)")
                
                // Apply smart 0-calorie filtering before ranking
                let filteredFoods = self.filterZeroCalorieEntries(foods)
                print("📊 After 0-calorie filtering: \(filteredFoods.count) foods remain")
                
                // Apply MyFitnessPal-style semantic relevance ranking + nutritional completeness
                let rankedFoods = self.rankFoodsByRelevanceAndQuality(filteredFoods, query: query)
                
                // Cache the results
                self.searchCache[cacheKey] = CachedSearchResult(results: rankedFoods, timestamp: Date())
                
                DispatchQueue.main.async {
                    completion(rankedFoods, nil)
                }
                
            } catch {
                print("❌ JSON parsing error: \(error.localizedDescription)")
                
                // Retry logic for parsing errors
                if retryCount < 2 {
                    print("🔄 Retrying search (attempt \(retryCount + 1)/3)...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount + 1)) {
                        self.performSearchWithRetry(query: query, cacheKey: cacheKey, retryCount: retryCount + 1, completion: completion)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
            }
        }
        
        task.resume()
    }
    
    /// Smart filtering to remove 0-calorie entries when other entries for the same food name have actual calories
    private func filterZeroCalorieEntries(_ foods: [FoodItem]) -> [FoodItem] {
        // Group foods by normalized name (case-insensitive, trimmed)
        var foodGroups: [String: [FoodItem]] = [:]
        
        for food in foods {
            let normalizedName = food.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if foodGroups[normalizedName] == nil {
                foodGroups[normalizedName] = []
            }
            foodGroups[normalizedName]?.append(food)
        }
        
        var filteredFoods: [FoodItem] = []
        
        for (foodName, foodGroup) in foodGroups {
            // Check if any foods in this group have calories > 0
            let hasNonZeroCalories = foodGroup.contains { $0.calories > 0 }
            
            if hasNonZeroCalories {
                // If some entries have calories, filter out the 0-calorie ones
                let nonZeroCalorieFoods = foodGroup.filter { $0.calories > 0 }
                filteredFoods.append(contentsOf: nonZeroCalorieFoods)
                
                let removedCount = foodGroup.count - nonZeroCalorieFoods.count
                if removedCount > 0 {
                    print("🚫 Filtered out \(removedCount) zero-calorie entries for '\(foodName)' (other entries have calories)")
                }
            } else {
                // If ALL entries are 0-calorie (like Coke Zero), keep them all
                filteredFoods.append(contentsOf: foodGroup)
                print("✅ Kept \(foodGroup.count) zero-calorie entries for '\(foodName)' (all entries are zero-calorie)")
            }
        }
        
        return filteredFoods
    }
    
    /// Rank foods by relevance and nutritional completeness
    private func rankFoodsByRelevanceAndQuality(_ foods: [FoodItem], query: String) -> [FoodItem] {
        return foods.sorted { food1, food2 in
            let relevanceScore1 = calculateSemanticRelevanceScore(food1, query: query)
            let relevanceScore2 = calculateSemanticRelevanceScore(food2, query: query)
            
            // Primary sort: semantic relevance
            if relevanceScore1 != relevanceScore2 {
                return relevanceScore1 > relevanceScore2
            }
            
            // Secondary sort: nutritional completeness
            let nutritionalScore1 = calculateNutritionalCompletenessScore(for: food1)
            let nutritionalScore2 = calculateNutritionalCompletenessScore(for: food2)
            return nutritionalScore1 > nutritionalScore2
        }
    }
    
    /// Regional brand preferences by country code
    private let regionalBrands: [String: [String]] = [
        "US": ["walmart", "great value", "target", "good & gather", "kroger", "simple truth", "safeway", "o organics", "whole foods", "365", "trader joe's", "kirkland", "costco"],
        "GB": ["tesco", "sainsbury's", "asda", "morrisons", "waitrose", "marks & spencer", "iceland", "aldi", "lidl", "co-op", "spar", "budgens"],
        "CA": ["loblaws", "president's choice", "no name", "metro", "sobeys", "compliments", "great value", "walmart"],
        "AU": ["woolworths", "coles", "iga", "aldi", "harris farm", "woolies"],
        "DE": ["aldi", "lidl", "rewe", "edeka", "kaufland", "netto", "penny"],
        "FR": ["carrefour", "leclerc", "intermarché", "super u", "auchan", "casino", "monoprix"]
    ]
    
    /// Get user's country code (simplified - in production, use CoreLocation)
    private func getUserCountryCode() -> String {
        let countryCode = Locale.current.region?.identifier ?? "US"
        print("🌍 Detected user country: \(countryCode)")
        return countryCode
    }
    
    /// User food history for personalized recommendations
    private func getUserFoodHistory() -> [String: FoodHistoryData] {
        guard let data = UserDefaults.standard.data(forKey: "userFoodHistory") else {
            return [:]
        }
        
        do {
            let history = try JSONDecoder().decode([String: FoodHistoryData].self, from: data)
            return history
        } catch {
            print("⚠️ Failed to decode food history: \(error)")
            return [:]
        }
    }
    
    /// Track when user adds a food to their log (call this when user logs food)
    func trackFoodSelection(_ food: FoodItem) {
        var history = getUserFoodHistory()
        let foodKey = "\(food.name)_\(food.brandName ?? "generic")"
        
        if var existingData = history[foodKey] {
            existingData.frequency += 1
            existingData.lastEaten = Date()
            history[foodKey] = existingData
        } else {
            history[foodKey] = FoodHistoryData(
                frequency: 1,
                firstEaten: Date(),
                lastEaten: Date(),
                totalCalories: food.calories
            )
        }
        
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: "userFoodHistory")
            print("📊 Tracked food selection: \(food.name) (frequency: \(history[foodKey]?.frequency ?? 1))")
        } catch {
            print("⚠️ Failed to encode food history: \(error)")
        }
    }
    
    /// Calculate serving size practicality score - boost foods with custom serving sizes
    private func calculateServingSizeScore(_ food: FoodItem) -> Double {
        var score: Double = 0.0
        
        // Check if food has a custom serving size (not just generic 100g)
        if let servingSize = food.servingSize, !servingSize.isEmpty {
            print("  🎯 Serving size boost for '\(food.name)': serving_size='\(servingSize)'")
            let servingSizeLower = servingSize.lowercased()
            
            // HIGH BOOST: Individual portions (bars, pieces, cups, etc.)
            let individualPortionKeywords = [
                "bar", "piece", "cup", "can", "bottle", "pack", "sachet", "pouch",
                "slice", "serving", "portion", "unit", "tablet", "capsule", "scoop",
                "stick", "tube", "pot", "tub", "container", "wrapper"
            ]
            
            for keyword in individualPortionKeywords {
                if servingSizeLower.contains(keyword) {
                    score += 30.0 // Strong boost for practical individual portions
                    print("    ✅ HIGH boost (+30) for individual portion keyword: '\(keyword)'")
                    break
                }
            }
            
            // MEDIUM BOOST: Specific weights that aren't 100g
            if servingSizeLower.contains("g") && !servingSizeLower.contains("100g") {
                // Extract numeric value to check if it's a practical serving size
                let numbers = servingSizeLower.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
                if let weight = numbers.first, weight > 0 && weight != 100 {
                    if weight <= 50 {
                        score += 25.0 // Small practical portions (cookies, chocolates)
                    } else if weight <= 200 {
                        score += 20.0 // Medium practical portions (yogurt, snack bars)
                    } else {
                        score += 15.0 // Larger but still specific portions
                    }
                }
            }
            
            // MEDIUM BOOST: Volume measurements (ml, fl oz, etc.)
            let volumeKeywords = ["ml", "cl", "l", "fl oz", "oz", "pint", "quart"]
            for keyword in volumeKeywords {
                if servingSizeLower.contains(keyword) {
                    score += 20.0 // Boost for specific volume measurements
                    break
                }
            }
            
            // SMALL BOOST: Any custom serving size is better than generic 100g
            if score == 0.0 {
                score += 10.0 // Fallback boost for any custom serving size
                print("    ✅ FALLBACK boost (+10) for any custom serving size")
            }
            
            print("    📊 Total serving size boost: +\(score)")
        } else {
            print("  ❌ No serving size data for '\(food.name)' - no boost applied")
        }
        
        return score
    }
    
    /// Calculate popular brand score - boost well-known brands when not specified in search
    private func calculatePopularBrandScore(_ brandName: String) -> Double {
        let brandLower = brandName.lowercased()
        
        // TIER 1: Global mega brands (+25 points)
        let globalBrands = [
            "coca-cola", "pepsi", "nestle", "unilever", "kraft", "heinz", "kellogg", 
            "general mills", "mars", "ferrero", "mondelez", "danone", "campbell", 
            "mcdonald", "kfc", "subway", "starbucks", "nike", "adidas"
        ]
        
        // TIER 2: Major food brands (+15 points)
        let majorBrands = [
            "oreo", "kit kat", "snickers", "twix", "m&m", "skittles", "haribo",
            "pringles", "doritos", "cheetos", "lay's", "ritz", "nabisco",
            "philadelphia", "hellmann", "knorr", "maggi", "nescafe", "lipton"
        ]
        
        // TIER 3: Well-known brands (+10 points)
        let wellKnownBrands = [
            "target", "walmart", "costco", "safeway", "kroger", "whole foods",
            "tesco", "sainsbury", "asda", "morrisons", "aldi", "lidl",
            "carrefour", "metro", "rewe", "edeka"
        ]
        
        for brand in globalBrands {
            if brandLower.contains(brand) {
                print("  🌟 GLOBAL brand boost (+25) for '\(brandName)'")
                return 25.0
            }
        }
        
        for brand in majorBrands {
            if brandLower.contains(brand) {
                print("  ⭐ MAJOR brand boost (+15) for '\(brandName)'")
                return 15.0
            }
        }
        
        for brand in wellKnownBrands {
            if brandLower.contains(brand) {
                print("  📈 KNOWN brand boost (+10) for '\(brandName)'")
                return 10.0
            }
        }
        
        return 0.0 // No boost for unknown brands
    }
    
    /// Calculate nutritional data quality score - boost foods with NOVA and/or Nutri-Score data
    private func calculateNutritionalDataScore(_ food: FoodItem) -> Double {
        var score: Double = 0.0
        
        let hasNovaScore = food.novaScore > 0
        let hasNutriScore = food.nutriScoreGrade != nil && !food.nutriScoreGrade!.isEmpty
        
        if hasNovaScore && hasNutriScore {
            // HIGHEST BOOST: Foods with both NOVA and Nutri-Score data
            score += 40.0
            print("  🏆 PREMIUM boost (+40) for '\(food.name)' - has both NOVA (\(food.novaScore)) and Nutri-Score (\(food.nutriScoreGrade!))")
        } else if hasNovaScore {
            // MEDIUM BOOST: Foods with NOVA score only
            score += 20.0
            print("  📊 NOVA boost (+20) for '\(food.name)' - has NOVA score: \(food.novaScore)")
        } else if hasNutriScore {
            // MEDIUM BOOST: Foods with Nutri-Score only
            score += 20.0
            print("  🎯 Nutri-Score boost (+20) for '\(food.name)' - has Nutri-Score: \(food.nutriScoreGrade!)")
        } else {
            print("  ❌ No nutritional quality data for '\(food.name)' - no boost applied")
        }
        
        return score
    }
    
    /// Calculate personalized relevance boost based on user's food history (contextually relevant)
    private func calculatePersonalizedScore(_ food: FoodItem, query: String) -> Double {
        let history = getUserFoodHistory()
        let foodKey = "\(food.name)_\(food.brandName ?? "generic")"
        
        guard let foodData = history[foodKey] else {
            return 0.0 // No history for this food
        }
        
        // Check if this food is contextually relevant to the search query
        let relevanceScore = calculateContextualRelevance(food: food, query: query)
        
        // Use a lower relevance threshold for all previously eaten foods
        if relevanceScore < 0.1 {
            print("  ❌ Previously eaten '\(food.name)' not relevant to query '\(query)' - no personal boost")
            return 0.0
        }
        
        var personalizedScore: Double = 0.0
        
        // Apply relevance multiplier to personalized scores
        let relevanceMultiplier = min(relevanceScore, 1.0)
        
        // Base boost for any previously eaten food that matches the search
        personalizedScore += 80.0 * relevanceMultiplier // Very strong boost for any previously eaten food
        
        // Frequency boost (more eaten = higher priority)
        if foodData.frequency >= 10 {
            personalizedScore += 50.0 * relevanceMultiplier // Frequently eaten food
        } else if foodData.frequency >= 5 {
            personalizedScore += 30.0 * relevanceMultiplier // Occasionally eaten
        } else if foodData.frequency >= 2 {
            personalizedScore += 20.0 * relevanceMultiplier // Previously eaten multiple times
        }
        
        // Recency boost (recently eaten = higher priority)
        let daysSinceLastEaten = Date().timeIntervalSince(foodData.lastEaten) / (24 * 60 * 60)
        if daysSinceLastEaten <= 7 {
            personalizedScore += 40.0 * relevanceMultiplier // Eaten in last week
        } else if daysSinceLastEaten <= 30 {
            personalizedScore += 20.0 * relevanceMultiplier // Eaten in last month
        }
        
        if personalizedScore > 0 {
            print("  🎯 PERSONAL boost (+\(String(format: "%.1f", personalizedScore))) for '\(food.name)' - eaten \(foodData.frequency) times, relevance: \(String(format: "%.2f", relevanceScore))")
        }
        
        return personalizedScore
    }
    
    /// Calculate how contextually relevant a food is to the search query
    private func calculateContextualRelevance(food: FoodItem, query: String) -> Double {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let nameLower = food.name.lowercased()
        let brandLower = food.brandName?.lowercased() ?? ""
        
        var relevance: Double = 0.0
        
        // Direct name match
        if nameLower.contains(queryLower) || queryLower.contains(nameLower) {
            relevance += 1.0
        }
        
        // Brand match
        if !brandLower.isEmpty && (brandLower.contains(queryLower) || queryLower.contains(brandLower)) {
            relevance += 0.8
        }
        
        // Word-level matching with improved similarity detection
        let queryWords = queryLower.split(separator: " ").map(String.init)
        let nameWords = nameLower.split(separator: " ").map(String.init)
        
        var wordMatches = 0
        for queryWord in queryWords {
            for nameWord in nameWords {
                // Exact match
                if nameWord == queryWord {
                    wordMatches += 2
                    break
                }
                // Contains match
                else if nameWord.contains(queryWord) || queryWord.contains(nameWord) {
                    wordMatches += 1
                    break
                }
                // Similar food type matching (e.g., "mince" matches "minced")
                else if (queryWord.contains("mince") && nameWord.contains("mince")) ||
                        (queryWord.contains("beef") && nameWord.contains("beef")) ||
                        (queryWord.contains("fat") && nameWord.contains("fat")) ||
                        (queryWord.contains("5%") && nameWord.contains("5%")) {
                    wordMatches += 1
                    break
                }
            }
        }
        
        if queryWords.count > 0 {
            relevance += Double(wordMatches) / Double(queryWords.count) * 0.6
        }
        
        return min(relevance, 1.0) // Cap at 1.0
    }
    
    /// Calculate a semantic relevance score for a food item based on the query (MyFitnessPal-style)
    private func calculateSemanticRelevanceScore(_ food: FoodItem, query: String) -> Double {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let nameLower = food.name.lowercased()
        let brandLower = food.brandName?.lowercased() ?? ""
        
        var score: Double = 0.0
        
        // 1. EXACT MATCH BONUS (highest priority)
        if nameLower == queryLower {
            score += 100.0
        }
        
        // 2. SIMPLE/GENERIC FOOD PRIORITIZATION (MyFitnessPal's key strategy)
        // Prioritize foods without brand names (generic/USDA foods)
        if food.brandName == nil || food.brandName?.isEmpty == true {
            score += 50.0
        }
        
        // 3. SEMANTIC WORD MATCHING
        let queryWords = queryLower.split(separator: " ").map(String.init)
        let nameWords = nameLower.split(separator: " ").map(String.init)
        
        // Bonus for each query word found in food name
        for queryWord in queryWords {
            for nameWord in nameWords {
                if nameWord.contains(queryWord) {
                    score += 20.0
                    
                    // Extra bonus if word starts with query (prefix match)
                    if nameWord.hasPrefix(queryWord) {
                        score += 10.0
                    }
                    
                    // Extra bonus for exact word match
                    if nameWord == queryWord {
                        score += 15.0
                    }
                }
            }
        }
        
        // 4. SIMPLICITY BONUS (fewer words = more basic ingredient)
        let wordCount = nameWords.count
        if wordCount <= 3 {
            score += 30.0 // "Chicken breast" > "Fajita chicken breast strips"
        } else if wordCount <= 5 {
            score += 15.0
        }
        
        // 5. HEAVILY PENALIZE PROCESSED/PREPARED FOODS (this is key!)
        let processedKeywords = ["stuffed", "filled", "strips", "fajita", "seasoned", "marinated", "breaded", "fried", "cooked", "prepared", "florentine", "parmesan", "swiss", "grilled", "boneless"]
        for keyword in processedKeywords {
            if nameLower.contains(keyword) {
                score -= 50.0 // Increased penalty for processed foods
            }
        }
        
        // 6. LIGHTLY PENALIZE BRANDED FOODS (but don't eliminate them)
        if food.brandName != nil && !food.brandName!.isEmpty {
            score -= 5.0 // Reduced penalty
        }
        
        // 7. BOOST RAW/FRESH INGREDIENTS
        let rawKeywords = ["raw", "fresh", "plain", "unseasoned"]
        for keyword in rawKeywords {
            if nameLower.contains(keyword) && queryLower.contains(keyword) {
                score += 25.0
            }
        }
        
        // 8. POSITION BONUS (if query appears early in name)
        if let range = nameLower.range(of: queryLower) {
            let position = nameLower.distance(from: nameLower.startIndex, to: range.lowerBound)
            if position == 0 {
                score += 40.0 // Query at start of name
            } else if position < 10 {
                score += 20.0 // Query near start
            }
        }
        
        // 9. POPULAR BRAND BOOSTING (when brand not in search query)
        if let brandName = food.brandName, !queryLower.contains(brandName.lowercased()) {
            let popularBrandScore = calculatePopularBrandScore(brandName)
            score += popularBrandScore
        }
        
        // 10. REGIONAL BRAND BOOSTING (practical relevance based on location)
        let userCountry = getUserCountryCode()
        if let brandName = food.brandName {
            if let regionalBrandList = regionalBrands[userCountry] {
                let brandLower = brandName.lowercased()
                
                // Check if brand matches any regional brands
                for regionalBrand in regionalBrandList {
                    if brandLower.contains(regionalBrand) {
                        score += 40.0 // Strong boost for regional brands (doubled from 20)
                        print("  🏪 REGIONAL brand boost (+40) for '\(brandName)' in \(userCountry)")
                        break
                    }
                }
            }
        } else {
            // FALLBACK: Boost generic/unbranded foods when no regional brands available
            // This helps when database lacks regional brand coverage
            score += 10.0 // Moderate boost for generic foods
        }
        
        // 11. SERVING SIZE PRACTICALITY BOOST
        let servingSizeScore = calculateServingSizeScore(food)
        score += servingSizeScore
        
        // 12. NUTRITIONAL DATA QUALITY BOOST
        let nutritionalDataScore = calculateNutritionalDataScore(food)
        score += nutritionalDataScore
        
        // 13. PERSONALIZED RANKING (silent - based on user's food history)
        let personalizedScore = calculatePersonalizedScore(food, query: query)
        score += personalizedScore
        
        return max(0, score) // Ensure non-negative score
    }
    
    /// Calculate a completeness score for a food item based on available nutritional quality data
    private func calculateNutritionalCompletenessScore(for food: FoodItem) -> Double {
        var score: Double = 0
        
        // Base score for having basic nutrition data (all foods should have this)
        if food.calories > 0 { score += 1.0 }
        if food.protein > 0 { score += 1.0 }
        if food.carbs > 0 { score += 1.0 }
        if food.fat > 0 { score += 1.0 }
        
        // Bonus points for quality indicators (these make foods more valuable to users)
        if food.novaScore > 0 { score += 2.0 } // NOVA score is very valuable for health-conscious users
        if food.nutriScoreGrade != nil && !food.nutriScoreGrade!.isEmpty { score += 2.0 } // Nutri-Score is premium data
        
        // Bonus for having brand information (usually indicates higher quality data)
        if food.brandName != nil && !food.brandName!.isEmpty { score += 1.0 }
        
        // Bonus for having serving size information (helps with portion control)
        if food.servingSize != nil && !food.servingSize!.isEmpty { score += 1.0 }
        
        return score
    }
    
    /// Clear the search cache (useful for memory management)
    func clearSearchCache() {
        searchCache.removeAll()
        print("🗑️ Search cache cleared")
    }
    
    /// Get cache statistics for debugging
    func getCacheStats() -> (count: Int, oldestEntry: Date?) {
        let oldestEntry = searchCache.values.map { $0.timestamp }.min()
        return (searchCache.count, oldestEntry)
    }
    
    /// Inspect the Typesense collection schema to see available fields
    func inspectSchema(completion: @escaping ([String: Any]?, Error?) -> Void) {
        print("🔍 Inspecting Typesense schema for available fields...")
        
        // Build the URL for the collection schema endpoint
        let urlString = "\(TypesenseConfig.apiURL)/collections/\(TypesenseConfig.collectionName)"
        guard let url = URL(string: urlString) else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(TypesenseConfig.searchOnlyApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        // Execute the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Schema inspection failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let responseError = NSError(
                    domain: "TypesenseService",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"]
                )
                DispatchQueue.main.async {
                    completion(nil, responseError)
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "TypesenseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                }
                return
            }
            
            do {
                let schema = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                if let fields = schema?["fields"] as? [[String: Any]] {
                    print("✅ Available Typesense fields:")
                    for field in fields {
                        if let name = field["name"] as? String,
                           let type = field["type"] as? String {
                            let facet = field["facet"] as? Bool ?? false
                            let sort = field["sort"] as? Bool ?? false
                            print("  - \(name) (\(type)) - Facet: \(facet), Sort: \(sort)")
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    completion(schema, nil)
                }
                
            } catch {
                print("❌ Schema parsing error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
        
        task.resume()
    }
    
    /// Test the connection to Typesense
    func testConnection(completion: @escaping (Bool, String?) -> Void) {
        print("🔍 Testing enhanced Typesense connection with direct HTTP...")
        
        // Build the URL for a simple search endpoint test
        let urlString = "\(TypesenseConfig.apiURL)/collections/\(TypesenseConfig.collectionName)/documents/search"
        guard var urlComponents = URLComponents(string: urlString) else {
            completion(false, "Invalid URL")
            return
        }
        
        // Simple test query
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: "test"),
            URLQueryItem(name: "query_by", value: "name"),
            URLQueryItem(name: "per_page", value: "1")
        ]
        
        guard let url = urlComponents.url else {
            completion(false, "Invalid URL components")
            return
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(TypesenseConfig.searchOnlyApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        // Execute the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Connection test failed: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        print("✅ Enhanced Typesense connection successful!")
                        completion(true, nil)
                    } else {
                        let errorMessage = "HTTP Error: \(httpResponse.statusCode)"
                        print("❌ Connection test failed: \(errorMessage)")
                        completion(false, errorMessage)
                    }
                } else {
                    completion(false, "Invalid response")
                }
            }
        }
        
        task.resume()
    }
    
    /// Search for foods by barcode with enhanced capabilities
    func searchByBarcode(barcode: String, completion: @escaping (FoodItem?, Error?) -> Void) {
        print("🔍 Enhanced Typesense barcode search for: \(barcode)")
        
        // Build the URL for the search endpoint
        let urlString = "\(TypesenseConfig.apiURL)/collections/\(TypesenseConfig.collectionName)/documents/search"
        guard var urlComponents = URLComponents(string: urlString) else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        // Enhanced barcode search parameters
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: barcode),
            URLQueryItem(name: "query_by", value: "barcode"),
            URLQueryItem(name: "filter_by", value: "barcode:=\(barcode)"), // Exact match filter
            URLQueryItem(name: "per_page", value: "1")
        ]
        
        guard let url = urlComponents.url else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL components"]))
            return
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(TypesenseConfig.searchOnlyApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        // Execute the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let responseError = NSError(
                    domain: "TypesenseService",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"]
                )
                DispatchQueue.main.async {
                    completion(nil, responseError)
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "TypesenseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                }
                return
            }
            
            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                guard let hits = jsonResponse?["hits"] as? [[String: Any]],
                      !hits.isEmpty,
                      let document = hits[0]["document"] as? [String: Any],
                      let name = document["name"] as? String else {
                    print("❌ No barcode match found for: \(barcode)")
                    DispatchQueue.main.async {
                        completion(nil, nil)
                    }
                    return
                }
                
                // Extract the same data as in regular search
                let brandName = document["brand"] as? String
                let foundBarcode = document["barcode"] as? String
                let novaScore = document["nova_score"] as? Int ?? 0
                let nutriScoreGrade = document["nutri_score_grade"] as? String
                
                var calories = 0
                var protein = 0.0
                var carbs = 0.0
                var fat = 0.0
                
                // Parse nutrition data
                if let nutrientsText = document["nutrients_text"] as? String,
                   let nutrientsData = nutrientsText.data(using: .utf8),
                   let nutrients = try? JSONSerialization.jsonObject(with: nutrientsData) as? [String: Any] {
                    
                    calories = (nutrients["calories"] as? Int) ?? Int((nutrients["calories"] as? Double) ?? 0)
                    protein = (nutrients["protein"] as? Double) ?? Double((nutrients["protein"] as? Int) ?? 0)
                    carbs = (nutrients["carbohydrates"] as? Double) ?? (nutrients["carbs"] as? Double) ?? Double((nutrients["carbohydrates"] as? Int) ?? 0)
                    fat = (nutrients["fat"] as? Double) ?? Double((nutrients["fat"] as? Int) ?? 0)
                } else {
                    calories = document["calories"] as? Int ?? 0
                    protein = (document["protein"] as? NSNumber)?.doubleValue ?? 0
                    carbs = (document["carbs"] as? NSNumber)?.doubleValue ?? 0
                    fat = (document["fat"] as? NSNumber)?.doubleValue ?? 0
                }
                
                var servingSize: String? = nil
                if let servingSizeNum = document["serving_size"] as? NSNumber {
                    servingSize = "\(servingSizeNum)"
                } else if let servingSizeStr = document["serving_size"] as? String {
                    servingSize = servingSizeStr
                }
                
                let servingType = document["serving_unit"] as? String
                
                var ingredients: [String] = []
                if let ingredientsArray = document["ingredients"] as? [String] {
                    ingredients = ingredientsArray
                } else if let ingredientsText = document["ingredients_text"] as? String {
                    ingredients = ingredientsText.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                }
                
                let food = FoodItem(
                    name: name,
                    brandName: brandName,
                    barcode: foundBarcode,
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    novaScore: novaScore,
                    nutriScoreGrade: nutriScoreGrade,
                    servingSize: servingSize,
                    servingType: servingType
                )
                
                print("✅ Found barcode match: \(name)")
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
