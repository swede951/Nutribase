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
        static let productsCollection = "foods"  // Open Food Facts products
        static let ingredientsCollection = "foods_ingredients"  // USDA ingredients
        
        // SECURITY: Always use Firebase Functions in production
        // API keys are stored securely in Firebase Secret Manager
        static let useSecureCloudMode = true
        
        // Placeholder for legacy direct mode (disabled - will fail if used)
        // Direct API calls are disabled for security reasons
        static let searchOnlyApiKey = "DISABLED_USE_FIREBASE_FUNCTIONS"
    }
    
    // Search intent types
    private enum SearchIntent {
        case ingredient  // Simple ingredient search (chicken, rice, etc.)
        case product     // Branded/prepared product search
        case mixed       // Unclear intent - search both
    }
    
    // Region name to ISO code mapping
    private func regionToISOCode(_ region: String) -> String {
        let mapping: [String: String] = [
            "United Kingdom": "gb",
            "United States": "us",
            "Ireland": "ie",
            "France": "fr",
            "Germany": "de",
            "Spain": "es",
            "Italy": "it",
            "Netherlands": "nl",
            "Belgium": "be",
            "Sweden": "se",
            "Norway": "no",
            "Denmark": "dk",
            "Poland": "pl",
            "Portugal": "pt",
            "Switzerland": "ch",
            "Austria": "at",
            "Australia": "au",
            "Canada": "ca",
            "New Zealand": "nz",
            "All Regions": "all"
        ]
        return mapping[region, default: region.lowercased()]
    }
    
    // MARK: - Script/Alphabet Filtering
    
    /// Check if a region uses Latin alphabet
    private func regionUsesLatinAlphabet(_ region: String) -> Bool {
        let latinRegions = [
            "United Kingdom", "United States", "Ireland", "France", "Germany",
            "Spain", "Italy", "Netherlands", "Belgium", "Sweden", "Norway",
            "Denmark", "Poland", "Portugal", "Switzerland", "Austria",
            "Australia", "Canada", "New Zealand"
        ]
        return latinRegions.contains(region)
    }
    
    /// Check if text contains primarily non-Latin characters (Cyrillic, Chinese, Arabic, etc.)
    private func containsNonLatinCharacters(_ text: String) -> Bool {
        // Count Latin vs non-Latin alphabetic characters
        var latinCount = 0
        var nonLatinCount = 0
        
        for scalar in text.unicodeScalars {
            if CharacterSet.letters.contains(scalar) {
                // Check if it's a basic Latin letter (A-Z, a-z) or extended Latin (accented chars)
                if (scalar.value >= 0x0041 && scalar.value <= 0x007A) ||  // Basic Latin
                   (scalar.value >= 0x00C0 && scalar.value <= 0x024F) ||  // Latin Extended
                   (scalar.value >= 0x1E00 && scalar.value <= 0x1EFF) {   // Latin Extended Additional
                    latinCount += 1
                } else {
                    nonLatinCount += 1
                }
            }
        }
        
        // If more than 30% of alphabetic characters are non-Latin, filter it out
        let totalLetters = latinCount + nonLatinCount
        guard totalLetters > 0 else { return false }
        
        return Double(nonLatinCount) / Double(totalLetters) > 0.3
    }
    
    /// Filter out foods with non-Latin names for Latin-alphabet regions
    private func filterByRegionScript(_ foods: [FoodItem]) -> [FoodItem] {
        let preferredRegion = UserDefaults.standard.string(forKey: "preferredFoodRegion") ?? "All Regions"
        
        // Only filter if user has selected a Latin-alphabet region
        guard preferredRegion != "All Regions" && regionUsesLatinAlphabet(preferredRegion) else {
            return foods
        }
        
        let filtered = foods.filter { food in
            // Check food name for non-Latin characters
            if containsNonLatinCharacters(food.name) {
                print("🔤 Filtered out non-Latin food: \(food.name)")
                return false
            }
            
            // Also check brand name if present
            if let brandName = food.brandName, containsNonLatinCharacters(brandName) {
                print("🔤 Filtered out non-Latin brand: \(brandName) - \(food.name)")
                return false
            }
            
            return true
        }
        
        if filtered.count < foods.count {
            print("🔤 Script filter removed \(foods.count - filtered.count) non-Latin results")
        }
        
        return filtered
    }
    
    // MARK: - Search Result Caching
    // NOTE: UK/US food synonyms are now configured server-side in Typesense
    // via the typesenseManageSynonyms Firebase Function (see setup-synonyms.js)
    
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
    
    // MARK: - Helper Methods
    
    /// Clean up brand name - removes duplicates and takes the first meaningful brand
    private func cleanBrandName(_ rawBrand: String?) -> String? {
        guard let brand = rawBrand, !brand.isEmpty else { return nil }
        
        // Split by comma and clean each part
        let parts = brand.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Return the first non-empty part, or nil if none
        return parts.first { !$0.isEmpty }
    }
    
    // MARK: - Public Methods
    
    /// Detect search intent based on query characteristics
    private func detectSearchIntent(_ query: String) -> SearchIntent {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = queryLower.split(separator: " ").map(String.init)
        
        // Brand keywords (UK + global)
        let brandKeywords = [
            // UK retailers
            "tesco", "sainsbury", "sainsburys", "asda", "morrisons", "waitrose",
            "marks", "spencer", "m&s", "coop", "co-op", "aldi", "lidl", "iceland",
            // US/Global
            "walmart", "target", "kroger", "costco", "trader", "joe", "whole foods",
            // Major food brands
            "nestle", "kraft", "heinz", "kellogg", "mars", "cadbury", "coca-cola",
            "pepsi", "unilever", "danone", "ferrero", "mondelez",
            // Fast food
            "mcdonald", "kfc", "burger king", "subway", "starbucks", "domino",
            "pizza hut", "taco bell", "wendy", "chick-fil-a", "popeyes"
        ]
        
        // Prepared/product/packaging keywords
        let productKeywords = [
            "wrap", "nuggets", "nugget", "bucket", "shake", "bar", "meal", "ready",
            "frozen", "microwave", "instant", "packet", "tin", "can", "bottle",
            "pack", "box", "tub", "pot", "sachet", "pouch",
            "pizza", "burger", "sandwich", "burrito", "taco", "fries",
            "prepared", "cooked", "baked", "fried", "grilled", "roasted",
            "flavored", "flavoured", "seasoned", "marinated", "breaded",
            "stuffed", "filled", "topped", "glazed", "smoked", "cured"
        ]
        
        // Check for brand keywords
        for brand in brandKeywords {
            if queryLower.contains(brand) {
                print("🎯 PRODUCT intent detected: brand keyword '\(brand)'")
                return .product
            }
        }
        
        // Check for product/prepared keywords
        for keyword in productKeywords {
            if tokens.contains(keyword) || queryLower.contains(keyword) {
                print("🎯 PRODUCT intent detected: product keyword '\(keyword)'")
                return .product
            }
        }
        
        // Short queries (1-3 tokens) without brand/product keywords = ingredient intent
        if tokens.count <= 3 {
            print("🥕 INGREDIENT intent detected: short query (\(tokens.count) tokens)")
            return .ingredient
        }
        
        // Longer queries (4+ tokens) without brand/product keywords = mixed intent
        print("🔀 MIXED intent detected: longer query (\(tokens.count) tokens) without clear signals")
        return .mixed
    }
    
    /// Search for foods matching the given query with enhanced search capabilities
    func searchFoods(query: String, completion: @escaping ([FoodItem]?, Error?) -> Void) {
        guard !query.isEmpty else {
            completion([], nil)
            return
        }
        // Check cache first
        let cacheKey = query.lowercased()
        if let cachedResult = searchCache[cacheKey], !cachedResult.isExpired {
            print("📦 Returning cached results for: \(query) (\(cachedResult.results.count) items)")
            // Apply cached serving information to cached search results
            let foodsWithCache = FoodServingCacheService.shared.applyCachedServingInfo(to: cachedResult.results)
            DispatchQueue.main.async {
                completion(foodsWithCache, nil)
            }
            return
        }
        
        // NOTE: Synonyms are now handled server-side by Typesense (see setup-synonyms.js)
        // Strip % from query for Typesense (non-word character that pollutes results)
        // Client-side ranking still uses the original query for contextual matching
        let typesenseQuery = query.replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
        
        // SECURE MODE: Route through Firebase Functions (API keys stay on server)
        if TypesenseConfig.useSecureCloudMode {
            print("🔒 Secure search via Firebase Functions for: \(query)")
            performSecureCloudSearch(query: typesenseQuery, cacheKey: cacheKey, originalQuery: query, completion: completion)
            return
        }
        
        // DIRECT MODE: For development/testing only
        print("🔍 Direct Typesense search for: \(query)")
        
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
        
        // Detect search intent (use original query for intent detection)
        let intent = detectSearchIntent(query)
        
        // Perform two-lane search based on intent
        performTwoLaneSearch(query: query, intent: intent, cacheKey: cacheKey, completion: completion)
    }
    
    /// Perform search via Firebase Functions (secure - API keys stay on server)
    /// - Parameters:
    ///   - query: Cleaned query sent to Typesense (% stripped)
    ///   - cacheKey: Cache key for storing results
    ///   - originalQuery: Original user query used for client-side ranking (preserves % tokens)
    ///   - completion: Results callback
    private func performSecureCloudSearch(query: String, cacheKey: String, originalQuery: String? = nil, completion: @escaping ([FoodItem]?, Error?) -> Void) {
        // Build multi-search request for two-lane search
        let searches: [[String: Any]] = [
            // Ingredients collection
            [
                "collection": TypesenseConfig.ingredientsCollection,
                "q": query,
                "query_by": "name,brand,name_norm,brand_norm",
                "query_by_weights": "5,3,4,2",
                "num_typos": "2",
                "prefix": "true",
                "per_page": "50",
                "sort_by": "_text_match(buckets:10):desc,popularity:desc,quality_score:desc"
            ],
            // Products collection
            [
                "collection": TypesenseConfig.productsCollection,
                "q": query,
                "query_by": "name,brand,name_norm,brand_norm,ingredients_text",
                "query_by_weights": "5,3,4,2,1",
                "num_typos": "2",
                "prefix": "true",
                "per_page": "50",
                "sort_by": "_text_match(buckets:10):desc,popularity:desc,quality_score:desc"
            ]
        ]
        
        TypesenseCloudService.shared.multiSearch(searches: searches) { [weak self] result in
            switch result {
            case .success(let searchResults):
                var allFoods: [FoodItem] = []
                
                // Parse results from both collections, tagging each with its data source
                // searchResults[0] = ingredients (USDA), searchResults[1] = products (branded)
                let dataSources = ["usda", "brand"]
                for (index, searchResult) in searchResults.enumerated() {
                    let source = index < dataSources.count ? dataSources[index] : "unknown"
                    for hit in searchResult.hits {
                        if let document = hit["document"] as? [String: Any],
                           let food = self?.parseFoodDocument(document, dataSource: source) {
                            allFoods.append(food)
                        }
                    }
                }
                
                // Deduplicate and rank (use original query for ranking to preserve % tokens)
                let rankingQuery = originalQuery ?? query
                let rankedFoods = self?.rankFoodsByRelevanceAndQuality(allFoods, query: rankingQuery) ?? allFoods
                let uniqueFoods = self?.deduplicateFoods(rankedFoods) ?? rankedFoods
                let topResults = Array(uniqueFoods.prefix(50))
                
                // Cache results
                self?.searchCache[cacheKey] = CachedSearchResult(results: topResults, timestamp: Date())
                
                // Apply cached serving info
                let foodsWithCache = FoodServingCacheService.shared.applyCachedServingInfo(to: topResults)
                
                DispatchQueue.main.async {
                    completion(foodsWithCache, nil)
                }
                
            case .failure(let error):
                print("❌ Secure cloud search failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    /// Parse a Typesense document into a FoodItem
    private func parseFoodDocument(_ doc: [String: Any], dataSource: String = "unknown") -> FoodItem? {
        guard let name = doc["name"] as? String else { return nil }
        
        let calories = doc["calories"] as? Int ?? Int(doc["calories"] as? Double ?? 0)
        let protein = doc["protein"] as? Double ?? Double(doc["protein"] as? Int ?? 0)
        // Check "carbohydrates" first (database field name), then fall back to "carbs"
        let carbs: Double = {
            if let val = doc["carbohydrates"] as? Double { return val }
            if let val = doc["carbohydrates"] as? Int { return Double(val) }
            if let val = doc["carbs"] as? Double { return val }
            if let val = doc["carbs"] as? Int { return Double(val) }
            return 0.0
        }()
        let fat = doc["fat"] as? Double ?? Double(doc["fat"] as? Int ?? 0)
        
        return FoodItem(
            name: name,
            brandName: cleanBrandName(doc["brand"] as? String),
            barcode: doc["barcode"] as? String ?? doc["id"] as? String,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            novaScore: doc["nova_final"] as? Int ?? doc["nova_score"] as? Int ?? 0,
            novaScoreIsEstimated: doc["nova_source"] as? String == "estimated",
            nutriScoreGrade: doc["nutriscore_grade"] as? String,
            nutriScoreIsEstimated: false,
            servingSize: doc["serving_size"] as? String,
            servingsPerPackage: doc["servings_per_package"] as? Double,
            servingType: doc["serving_unit"] as? String,
            fiber: doc["fiber"] as? Double,
            sugar: doc["sugar"] as? Double,
            sodium: doc["sodium"] as? Double,
            saturatedFat: doc["saturated_fat"] as? Double,
            ingredients: doc["ingredients_text"] as? String,
            countries: doc["countries"] as? [String],
            dataSource: dataSource
        )
    }
    
    /// Deduplicate foods by name+brand
    private func deduplicateFoods(_ foods: [FoodItem]) -> [FoodItem] {
        var seen = Set<String>()
        return foods.filter { food in
            let key = "\(food.name.lowercased())_\(food.brandName?.lowercased() ?? "")"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }
    
    /// Perform two-lane search: query both collections and merge results
    private func performTwoLaneSearch(query: String, intent: SearchIntent, cacheKey: String, completion: @escaping ([FoodItem]?, Error?) -> Void) {
        let group = DispatchGroup()
        var ingredientResults: [FoodItem] = []
        var productResults: [FoodItem] = []
        var searchErrors: [Error] = []
        
        // Determine which collections to search based on intent
        let searchIngredients = intent == .ingredient || intent == .mixed
        let searchProducts = intent == .product || intent == .mixed
        
        print("🔍 Two-lane search: ingredients=\(searchIngredients), products=\(searchProducts)")
        
        // Search for ingredients using strict ingredient query
        if searchIngredients {
            group.enter()
            performIngredientSearch(
                query: query,
                retryCount: 0
            ) { foods, error in
                if let foods = foods {
                    ingredientResults = foods
                    print("✅ Ingredients lane: \(foods.count) results")
                } else if let error = error {
                    searchErrors.append(error)
                }
                group.leave()
            }
        }
        
        // Search for products using brand-friendly product query
        if searchProducts {
            group.enter()
            performProductSearch(
                query: query,
                retryCount: 0
            ) { foods, error in
                if let foods = foods {
                    productResults = foods
                    print("✅ Products lane: \(foods.count) results")
                } else if let error = error {
                    searchErrors.append(error)
                }
                group.leave()
            }
        }
        
        // Wait for both searches to complete
        group.notify(queue: .main) {
            // If both searches failed, return error
            if ingredientResults.isEmpty && productResults.isEmpty && !searchErrors.isEmpty {
                completion(nil, searchErrors.first)
                return
            }
            
            // Merge and rank results based on intent
            let mergedResults = self.mergeAndRankResults(
                ingredientResults: ingredientResults,
                productResults: productResults,
                query: query,
                intent: intent
            )
            
            print("✅ Two-lane search complete: \(mergedResults.count) total results")
            
            // Apply cached serving information
            let foodsWithCache = FoodServingCacheService.shared.applyCachedServingInfo(to: mergedResults)
            
            // Cache the results
            self.searchCache[cacheKey] = CachedSearchResult(results: mergedResults, timestamp: Date())
            
            completion(foodsWithCache, nil)
        }
    }
    
    /// Merge and rank results from both lanes based on intent
    private func mergeAndRankResults(
        ingredientResults: [FoodItem],
        productResults: [FoodItem],
        query: String,
        intent: SearchIntent
    ) -> [FoodItem] {
        var allResults: [FoodItem] = []
        
        switch intent {
        case .ingredient:
            // Ingredient intent: prioritize ingredients heavily, add some products at end
            print("🥕 Ranking for INGREDIENT intent")
            allResults = ingredientResults + productResults.prefix(10)  // Take only top 10 products
            
        case .product:
            // Product intent: prioritize products heavily, add some ingredients at end
            print("🎯 Ranking for PRODUCT intent")
            allResults = productResults + ingredientResults.prefix(5)  // Take only top 5 ingredients
            
        case .mixed:
            // Mixed intent: interleave results, slight preference for ingredients
            print("🔀 Ranking for MIXED intent")
            // Take top results from each, ingredients first
            let maxIngredients = min(25, ingredientResults.count)
            let maxProducts = min(25, productResults.count)
            allResults = Array(ingredientResults.prefix(maxIngredients)) + Array(productResults.prefix(maxProducts))
        }
        
        // Apply smart 0-calorie filtering
        let filteredResults = filterZeroCalorieEntries(allResults)
        
        // Re-rank all results by relevance and quality
        let rankedResults = rankFoodsByRelevanceAndQuality(filteredResults, query: query)
        
        // Limit final results to 50
        return Array(rankedResults.prefix(50))
    }
    
    /// Perform strict ingredient search with fallback
    private func performIngredientSearch(
        query: String,
        retryCount: Int,
        completion: @escaping ([FoodItem]?, Error?) -> Void
    ) {
        // First try: strict ingredient search
        performIngredientSearchInternal(
            query: query,
            strictMode: true,
            retryCount: retryCount
        ) { foods, error in
            if let foods = foods, foods.count >= 5 {
                // Success with strict search
                completion(foods, nil)
            } else {
                // Fallback: widen to include products
                print("⚠️ Ingredient search returned < 5 results (\(foods?.count ?? 0)), using fallback")
                self.performIngredientSearchInternal(
                    query: query,
                    strictMode: false,
                    retryCount: retryCount,
                    completion: completion
                )
            }
        }
    }
    
    /// Internal ingredient search with configurable strictness
    private func performIngredientSearchInternal(
        query: String,
        strictMode: Bool,
        retryCount: Int,
        completion: @escaping ([FoodItem]?, Error?) -> Void
    ) {
        // Build the URL for the search endpoint (search both collections)
        let urlString = "\(TypesenseConfig.apiURL)/multi_search"
        guard let url = URL(string: urlString) else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        // Get region preference
        let preferredRegion = UserDefaults.standard.string(forKey: "preferredFoodRegion") ?? "All Regions"
        
        // Build filter_by query
        var filters: [String] = ["calories:>0"]  // Always filter out foods with 0 calories
        
        // Strict mode: only ingredients. Fallback: ingredients + products
        if strictMode {
            filters.append("food_kind:=ingredient")
        } else {
            filters.append("food_kind:=[ingredient,product]")
        }
        
        // Add region filter if not "All Regions"
        if preferredRegion != "All Regions" {
            let countryCode = regionToISOCode(preferredRegion)
            filters.append("country_codes:=[\(countryCode)]")
            print("🌍 Filtering search by region code: \(countryCode)")
        }
        
        let filterString = filters.joined(separator: " && ")
        
        // Build multi-search request body
        let searches: [[String: Any]] = [
            // Search ingredients collection
            [
                "collection": TypesenseConfig.ingredientsCollection,
                "q": query,
                "query_by": "name_norm,name",
                "query_by_weights": "100,50",  // Boost normalized name heavily
                "filter_by": filterString,
                "drop_tokens_threshold": strictMode ? 0 : 1,
                "num_typos": 1,
                "prefix": "true,true",
                "prioritize_exact_match": true,
                "prioritize_token_position": true,
                "per_page": 50,
                "sort_by": "_text_match(buckets:10):desc,popularity:desc,quality_score:desc"
            ],
            // Search products collection (only in non-strict mode with widened filter)
            strictMode ? [:] : [
                "collection": TypesenseConfig.productsCollection,
                "q": query,
                "query_by": "name_norm,name",
                "query_by_weights": "100,50",
                "filter_by": filterString,  // Use same widened filter as ingredients collection
                "drop_tokens_threshold": 1,
                "num_typos": 1,
                "prefix": "true,true",
                "prioritize_exact_match": true,
                "prioritize_token_position": true,
                "per_page": 50,
                "sort_by": "_text_match(buckets:10):desc,popularity:desc,quality_score:desc"
            ]
        ].filter { !$0.isEmpty }
        
        let requestBody: [String: Any] = ["searches": searches]
        
        print("🥕 Ingredient search (strict=\(strictMode)): \(searches.count) collection(s)")
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(TypesenseConfig.searchOnlyApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        // Set request body
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(nil, error)
            return
        }
        
        // Execute the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Check for network errors with retry logic
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                
                // Retry for network errors (timeout, connection issues)
                if retryCount < 2 && (error as NSError).code != NSURLErrorCancelled {
                    print("🔄 Retrying search due to network error (attempt \(retryCount + 1)/3)...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount + 1)) {
                        self.performIngredientSearchInternal(query: query, strictMode: strictMode, retryCount: retryCount + 1, completion: completion)
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
                            self.performIngredientSearchInternal(query: query, strictMode: strictMode, retryCount: retryCount + 1, completion: completion)
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
                        self.performIngredientSearchInternal(query: query, strictMode: strictMode, retryCount: retryCount + 1, completion: completion)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil, NSError(domain: "TypesenseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                    }
                }
                return
            }
            
            do {
                // Parse multi-search response
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                print("📝 Multi-search response received")
                
                guard let results = jsonResponse?["results"] as? [[String: Any]] else {
                    print("❌ No results array in multi-search response")
                    DispatchQueue.main.async {
                        completion([], nil)
                    }
                    return
                }
                
                // Combine all hits from all searches
                var foods: [FoodItem] = []
                for (index, result) in results.enumerated() {
                    guard let hits = result["hits"] as? [[String: Any]] else {
                        print("⚠️ No hits in search result \(index)")
                        continue
                    }
                    print("📊 Search \(index): \(hits.count) hits")
                
                    for hit in hits {
                    guard let document = hit["document"] as? [String: Any],
                          let name = document["name"] as? String else {
                        continue
                    }
                    
                    print("🍎 Processing food: \(name)")
                    
                    // Extract basic information
                    let brandName = self.cleanBrandName(document["brand"] as? String)
                    let barcode = document["barcode"] as? String
                    let novaScore = document["nova_score"] as? Int ?? 0
                    let nutriScoreGrade = document["nutriscore_grade"] as? String
                    print("  🎯 Nutriscore_grade field: \(nutriScoreGrade ?? "nil")")
                    
                    // Extract nutritional values with improved parsing
                    var calories = 0
                    var protein = 0.0
                    var carbs = 0.0
                    var fat = 0.0
                    
                    // Extract micronutrients - NEW!
                    var fiber: Double? = nil
                    var sugar: Double? = nil
                    var sodium: Double? = nil
                    var saturatedFat: Double? = nil
                    
                    // Extract nutrition data directly from document fields (simplified schema)
                    calories = (document["calories"] as? Int) ?? Int(document["calories"] as? String ?? "0") ?? 0
                    protein = (document["protein"] as? Double) ?? Double(document["protein"] as? String ?? "0") ?? 0.0
                    carbs = (document["carbohydrates"] as? Double) ?? Double(document["carbohydrates"] as? String ?? "0") ?? 0.0
                    fat = (document["fat"] as? Double) ?? Double(document["fat"] as? String ?? "0") ?? 0.0
                    
                    // Extract micronutrients from direct fields (handle strings and numbers)
                    fiber = (document["fiber"] as? Double) ?? Double(document["fiber"] as? String ?? "") ?? nil
                    sugar = (document["sugar"] as? Double) ?? Double(document["sugar"] as? String ?? "") ?? nil
                    sodium = (document["sodium"] as? Double) ?? Double(document["sodium"] as? String ?? "") ?? nil
                    saturatedFat = (document["saturated_fat"] as? Double) ?? Double(document["saturated_fat"] as? String ?? "") ?? nil
                    
                    print("  📊 Parsed nutrition data for \(name):")
                    print("    calories: \(calories)")
                    print("    protein: \(protein)g")
                    print("    carbohydrates: \(carbs)g")
                    print("    fat: \(fat)g")
                    if let fiber = fiber { print("    fiber: \(fiber)g") }
                    if let sugar = sugar { print("    sugar: \(sugar)g") }
                    if let sodium = sodium { print("    sodium: \(sodium)g") }
                    if let saturatedFat = saturatedFat { print("    saturated_fat: \(saturatedFat)g") }
                    
                    // Handle serving size from direct document fields
                    var servingSize: String? = nil
                    if let servingSizeNum = document["serving_size"] as? NSNumber {
                        servingSize = "\(servingSizeNum)"
                        print("  📏 Found serving_size (number): \(servingSize!)")
                    } else if let servingSizeStr = document["serving_size"] as? String {
                        servingSize = servingSizeStr
                        print("  📏 Found serving_size (string): \(servingSize!)")
                    } else {
                        print("  ❌ No serving_size field found")
                    }
                    
                    let servingType = document["serving_unit"] as? String
                    if let servingType = servingType {
                        print("  📏 Found serving_unit: \(servingType)")
                    } else {
                        print("  ❌ No serving_unit field found")
                    }
                    
                    // Parse ingredients (not used in FoodItem creation but kept for potential future use)
                    let _ = {
                        if let ingredientsArray = document["ingredients"] as? [String] {
                            return ingredientsArray
                        } else if let ingredientsText = document["ingredients_text"] as? String {
                            return ingredientsText.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                        }
                        return [String]()
                    }()
                    
                    // Debug micronutrients
                    var micronutrientCount = 0
                    if fiber != nil { micronutrientCount += 1 }
                    if sugar != nil { micronutrientCount += 1 }
                    if sodium != nil { micronutrientCount += 1 }
                    if saturatedFat != nil { micronutrientCount += 1 }
                    
                    if micronutrientCount > 0 {
                        print("  🥗 Found \(micronutrientCount) micronutrients for \(name)")
                    }
                    
                    // Extract region information
                    let countries = document["countries"] as? [String]
                    let purchasePlaces = document["purchase_places"] as? String
                    let origins = document["origins"] as? String
                    
                    if let countries = countries, !countries.isEmpty {
                        print("  🌍 Countries: \(countries.joined(separator: ", "))")
                    }
                    
                    // Create FoodItem with micronutrients and region data
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
                        servingType: servingType,
                        fiber: fiber,
                        sugar: sugar,
                        sodium: sodium,
                        saturatedFat: saturatedFat,
                        countries: countries,
                        purchasePlaces: purchasePlaces,
                        origins: origins
                    )
                    
                        foods.append(food)
                    }
                }
                
                print("✅ Found \(foods.count) foods matching query: \(query)")
                
                // Apply smart 0-calorie filtering before ranking
                let filteredFoods = self.filterZeroCalorieEntries(foods)
                print("📊 After 0-calorie filtering: \(filteredFoods.count) foods remain")
                
                // Filter out non-Latin script foods for Latin-alphabet regions
                let scriptFilteredFoods = self.filterByRegionScript(filteredFoods)
                
                // Apply MyFitnessPal-style semantic relevance ranking + nutritional completeness
                let semanticallyRankedFoods = self.rankFoodsByRelevanceAndQuality(scriptFilteredFoods, query: query)
                
                // DISABLED: SearchRankingService was overwriting our semantic scores
                // Instead, semantic relevance is the primary ranking factor
                let rankedFoods = semanticallyRankedFoods
                
                // Return results (caching happens at the two-lane search level)
                DispatchQueue.main.async {
                    completion(rankedFoods, nil)
                }
                
            } catch {
                print("❌ JSON parsing error: \(error.localizedDescription)")
                
                // Retry logic for parsing errors
                if retryCount < 2 {
                    print("🔄 Retrying search (attempt \(retryCount + 1)/3)...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount + 1)) {
                        self.performIngredientSearchInternal(query: query, strictMode: strictMode, retryCount: retryCount + 1, completion: completion)
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
    
    /// Perform brand-friendly product search
    private func performProductSearch(
        query: String,
        retryCount: Int,
        completion: @escaping ([FoodItem]?, Error?) -> Void
    ) {
        // Build the URL for multi-search endpoint
        let urlString = "\(TypesenseConfig.apiURL)/multi_search"
        guard let url = URL(string: urlString) else {
            completion(nil, NSError(domain: "TypesenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        // Get region preference
        let preferredRegion = UserDefaults.standard.string(forKey: "preferredFoodRegion") ?? "All Regions"
        
        // Build filter_by query for products
        var filters: [String] = ["calories:>0", "food_kind:=product"]
        
        // Add region filter if not "All Regions"
        if preferredRegion != "All Regions" {
            let countryCode = regionToISOCode(preferredRegion)
            filters.append("country_codes:=[\(countryCode)]")
            print("🌍 Filtering search by region code: \(countryCode)")
        }
        
        let filterString = filters.joined(separator: " && ")
        
        // Build multi-search request body
        let searches: [[String: Any]] = [
            // Search products collection (brand-friendly)
            [
                "collection": TypesenseConfig.productsCollection,
                "q": query,
                "query_by": "brand_norm,name_norm,brand,name",
                "query_by_weights": "100,90,50,40",  // Boost brand fields for products
                "filter_by": filterString,
                "drop_tokens_threshold": 1,
                "num_typos": 2,  // More lenient for products
                "prefix": "true,true,true,true",
                "prioritize_exact_match": true,
                "prioritize_token_position": true,
                "per_page": 50,
                "sort_by": "_text_match(buckets:10):desc,popularity:desc,quality_score:desc"
            ],
            // Also search ingredients collection for product-tagged items
            [
                "collection": TypesenseConfig.ingredientsCollection,
                "q": query,
                "query_by": "name_norm,name",
                "query_by_weights": "100,50",
                "filter_by": "calories:>0 && food_kind:=product" + (preferredRegion != "All Regions" ? " && country_codes:=[\(regionToISOCode(preferredRegion))]" : ""),
                "drop_tokens_threshold": 1,
                "num_typos": 2,
                "prefix": "true,true",
                "prioritize_exact_match": true,
                "prioritize_token_position": true,
                "per_page": 50,
                "sort_by": "_text_match(buckets:10):desc,popularity:desc,quality_score:desc"
            ]
        ]
        
        let requestBody: [String: Any] = ["searches": searches]
        
        print("🎯 Product search: \(searches.count) collection(s)")
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(TypesenseConfig.searchOnlyApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        // Set request body
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(nil, error)
            return
        }
        
        // Execute the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Check for network errors with retry logic
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                
                if retryCount < 2 && (error as NSError).code != NSURLErrorCancelled {
                    print("🔄 Retrying search due to network error (attempt \(retryCount + 1)/3)...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount + 1)) {
                        self.performProductSearch(query: query, retryCount: retryCount + 1, completion: completion)
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
                    
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Error response: \(responseString)")
                    }
                    
                    if retryCount < 2 && httpResponse.statusCode >= 500 {
                        print("🔄 Retrying search due to server error (attempt \(retryCount + 1)/3)...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount + 1)) {
                            self.performProductSearch(query: query, retryCount: retryCount + 1, completion: completion)
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
                
                if retryCount < 2 {
                    print("🔄 Retrying search due to missing data (attempt \(retryCount + 1)/3)...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount + 1)) {
                        self.performProductSearch(query: query, retryCount: retryCount + 1, completion: completion)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil, NSError(domain: "TypesenseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                    }
                }
                return
            }
            
            do {
                // Parse multi-search response
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                print("📝 Multi-search response received")
                
                guard let results = jsonResponse?["results"] as? [[String: Any]] else {
                    print("❌ No results array in multi-search response")
                    DispatchQueue.main.async {
                        completion([], nil)
                    }
                    return
                }
                
                // Combine all hits from all searches
                var foods: [FoodItem] = []
                for (index, result) in results.enumerated() {
                    guard let hits = result["hits"] as? [[String: Any]] else {
                        print("⚠️ No hits in search result \(index)")
                        continue
                    }
                    print("📊 Search \(index): \(hits.count) hits")
                
                    for hit in hits {
                        guard let document = hit["document"] as? [String: Any],
                              let name = document["name"] as? String else {
                            continue
                        }
                        
                        // Extract basic information
                        let brandName = self.cleanBrandName(document["brand"] as? String)
                        let barcode = document["barcode"] as? String
                        let novaScore = document["nova_score"] as? Int ?? 0
                        let nutriScoreGrade = document["nutriscore_grade"] as? String
                        
                        // Extract nutritional values
                        let calories = (document["calories"] as? Int) ?? Int(document["calories"] as? String ?? "0") ?? 0
                        let protein = (document["protein"] as? Double) ?? Double(document["protein"] as? String ?? "0") ?? 0.0
                        let carbs = (document["carbohydrates"] as? Double) ?? Double(document["carbohydrates"] as? String ?? "0") ?? 0.0
                        let fat = (document["fat"] as? Double) ?? Double(document["fat"] as? String ?? "0") ?? 0.0
                        
                        // Extract micronutrients
                        let fiber = (document["fiber"] as? Double) ?? Double(document["fiber"] as? String ?? "") ?? nil
                        let sugar = (document["sugar"] as? Double) ?? Double(document["sugar"] as? String ?? "") ?? nil
                        let sodium = (document["sodium"] as? Double) ?? Double(document["sodium"] as? String ?? "") ?? nil
                        let saturatedFat = (document["saturated_fat"] as? Double) ?? Double(document["saturated_fat"] as? String ?? "") ?? nil
                        
                        // Handle serving size
                        var servingSize: String? = nil
                        if let servingSizeNum = document["serving_size"] as? NSNumber {
                            servingSize = "\(servingSizeNum)"
                        } else if let servingSizeStr = document["serving_size"] as? String {
                            servingSize = servingSizeStr
                        }
                        
                        let servingType = document["serving_unit"] as? String
                        
                        // Extract region information
                        let countries = document["countries"] as? [String]
                        let purchasePlaces = document["purchase_places"] as? String
                        let origins = document["origins"] as? String
                        
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
                            servingType: servingType,
                            fiber: fiber,
                            sugar: sugar,
                            sodium: sodium,
                            saturatedFat: saturatedFat,
                            countries: countries,
                            purchasePlaces: purchasePlaces,
                            origins: origins
                        )
                        
                        foods.append(food)
                    }
                }
                
                print("✅ Found \(foods.count) products matching query: \(query)")
                
                // Apply smart 0-calorie filtering
                let filteredFoods = self.filterZeroCalorieEntries(foods)
                
                // Filter out non-Latin script foods for Latin-alphabet regions
                let scriptFilteredFoods = self.filterByRegionScript(filteredFoods)
                
                // Apply ranking
                let rankedFoods = self.rankFoodsByRelevanceAndQuality(scriptFilteredFoods, query: query)
                
                DispatchQueue.main.async {
                    completion(rankedFoods, nil)
                }
                
            } catch {
                print("❌ JSON parsing error: \(error.localizedDescription)")
                
                if retryCount < 2 {
                    print("🔄 Retrying search (attempt \(retryCount + 1)/3)...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount + 1)) {
                        self.performProductSearch(query: query, retryCount: retryCount + 1, completion: completion)
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
        
        // Record meal-type preference for personalized ranking
        let currentMealType = UserDefaults.standard.string(forKey: "currentMealType") ?? ""
        if !currentMealType.isEmpty {
            SearchRankingService.shared.recordFoodSelection(
                foodId: food.id.uuidString,
                foodName: food.name,
                mealType: currentMealType
            )
        }
        
        // Increment global popularity in Typesense (the flywheel)
        incrementPopularity(for: food)
    }
    
    /// Increment popularity counter in Typesense for a selected food
    /// This creates a "flywheel" effect - search gets better as more people use it
    private func incrementPopularity(for food: FoodItem) {
        // Use barcode as document ID (that's how OFF products are indexed)
        // For USDA items without barcode, skip popularity update
        guard let barcode = food.barcode, !barcode.isEmpty else {
            print("⚠️ Cannot increment popularity: no barcode (likely USDA ingredient)")
            return
        }
        
        // SECURE MODE: Route through Firebase Functions
        if TypesenseConfig.useSecureCloudMode {
            TypesenseCloudService.shared.incrementPopularity(
                documentId: barcode,
                collection: TypesenseConfig.productsCollection
            )
            return
        }
        
        // DIRECT MODE: For development only (requires admin key in app - not secure)
        print("⚠️ Direct popularity update disabled in production")
    }
    
    /// Calculate serving size practicality score - boost foods with custom serving sizes
    private func calculateServingSizeScore(_ food: FoodItem) -> Double {
        var score: Double = 0.0
        
        // Check if food has a custom serving size (not just generic 100g)
        if let servingSize = food.servingSize, !servingSize.isEmpty {
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
            }
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
                return 25.0
            }
        }
        
        for brand in majorBrands {
            if brandLower.contains(brand) {
                return 15.0
            }
        }
        
        for brand in wellKnownBrands {
            if brandLower.contains(brand) {
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
        } else if hasNovaScore {
            // MEDIUM BOOST: Foods with NOVA score only
            score += 20.0
        } else if hasNutriScore {
            // MEDIUM BOOST: Foods with Nutri-Score only
            score += 20.0
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
        
        var score: Double = 0.0
        
        // Normalize % tokens for matching: "5%" → "5" for word matching
        // but keep original for contextual scoring (e.g. "5% fat")
        let queryWords = queryLower.split(separator: " ").map(String.init)
        let normalizedQueryWords = queryWords.map { $0.replacingOccurrences(of: "%", with: "") }.filter { !$0.isEmpty }
        let nameWords = nameLower.split(separator: " ").map(String.init)
        let normalizedNameWords = nameWords.map { $0.replacingOccurrences(of: "%", with: "") }
        
        // 1. EXACT MATCH BONUS (highest priority)
        if nameLower == queryLower {
            score += 500.0
        }
        
        // 2. SINGLE WORD MATCH (e.g., "pasta" query matching "pasta" name)
        if queryWords.count == 1 && nameWords.count == 1 && queryWords[0] == nameWords[0] {
            score += 400.0
        }
        
        // 3. SIMPLICITY BONUS — scaled by query length
        // For single-word queries, simple names are better ("pasta" → "Pasta")
        // For multi-word queries (3+), the user wants something specific — reduce simplicity bias
        let wordCount = nameWords.count
        let isSpecificQuery = queryWords.count >= 3
        
        if wordCount == 1 {
            score += isSpecificQuery ? 50.0 : 200.0
        } else if wordCount == 2 {
            score += isSpecificQuery ? 40.0 : 100.0
        } else if wordCount == 3 {
            score += isSpecificQuery ? 30.0 : 50.0
        } else if wordCount <= 5 {
            score += 20.0
        }
        
        // 4. SIMPLE/GENERIC FOOD PRIORITIZATION (MyFitnessPal's key strategy)
        if food.brandName == nil || food.brandName?.isEmpty == true {
            score += 80.0
        }
        
        // 5. SEMANTIC WORD MATCHING + QUERY COVERAGE REWARD
        var matchedQueryWords = 0
        for queryWord in normalizedQueryWords {
            var wordMatched = false
            for nameWord in normalizedNameWords {
                if nameWord.contains(queryWord) {
                    score += 20.0
                    wordMatched = true
                    
                    if nameWord.hasPrefix(queryWord) {
                        score += 10.0
                    }
                    if nameWord == queryWord {
                        score += 15.0
                    }
                    break // Only count best match per query word
                }
            }
            if wordMatched { matchedQueryWords += 1 }
        }
        
        // QUERY COVERAGE BONUS: reward results that match a high % of query words
        // A result matching 3/3 query words gets +150; matching 1/3 gets +50
        if normalizedQueryWords.count > 0 {
            let coverage = Double(matchedQueryWords) / Double(normalizedQueryWords.count)
            score += coverage * 150.0
        }
        
        // 6. PENALIZE PROCESSED/PREPARED FOODS — but only if keyword is NOT in user's query
        let processedKeywords = ["bake", "stuffed", "filled", "strips", "fajita", "seasoned", "marinated", "breaded", "fried", "cooked", "prepared", "florentine", "parmesan", "swiss", "grilled", "boneless", "meal", "ready"]
        for keyword in processedKeywords {
            if nameLower.contains(keyword) && !queryLower.contains(keyword) {
                score -= 50.0 // Reduced from -100 and now context-aware
            }
        }
        
        // 6b. LIGHTLY PENALIZE BRANDED FOODS (but don't eliminate them)
        if food.brandName != nil && !food.brandName!.isEmpty {
            score -= 5.0
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
        
        // 14. MEAL-TYPE PERSONALIZATION (boost foods commonly logged for this meal type)
        let currentMealType = UserDefaults.standard.string(forKey: "currentMealType") ?? ""
        if !currentMealType.isEmpty {
            let mealPrefs = SearchRankingService.shared.getMealTypePreference(for: food.id.uuidString, mealType: currentMealType)
            let mealTypeBonus = min(Double(mealPrefs) * 15.0, 60.0) // Cap at +60
            score += mealTypeBonus
        }
        
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
        let urlString = "\(TypesenseConfig.apiURL)/collections/\(TypesenseConfig.productsCollection)"
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
        let urlString = "\(TypesenseConfig.apiURL)/collections/\(TypesenseConfig.productsCollection)/documents/search"
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
        print("🔍 Barcode search for: \(barcode)")
        
        // Use secure Firebase Functions route for barcode lookup
        TypesenseCloudService.shared.lookupBarcode(barcode: barcode) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let document):
                guard let document = document,
                      let name = document["name"] as? String else {
                    print("❌ No barcode match found for: \(barcode)")
                    DispatchQueue.main.async {
                        completion(nil, nil)
                    }
                    return
                }
                
                // Extract the same data as in regular search
                let brandName = self.cleanBrandName(document["brand"] as? String)
                let foundBarcode = document["barcode"] as? String
                let novaScore = document["nova_score"] as? Int ?? 0
                let nutriScoreGrade = document["nutriscore_grade"] as? String
                
                print("  🏷️ Food metadata:")
                print("    name: \(name)")
                print("    brand: \(brandName ?? "No brand")")
                print("    barcode: \(foundBarcode ?? "No barcode")")
                print("    nova_score: \(novaScore)")
                print("    nutriscore_grade: \(nutriScoreGrade ?? "No grade")")
                
                // Extract nutrition data using same logic as regular search
                let calories = (document["calories"] as? Int) ?? Int(document["calories"] as? String ?? "0") ?? 0
                let protein = (document["protein"] as? Double) ?? Double(document["protein"] as? String ?? "0") ?? 0.0
                let carbs = (document["carbohydrates"] as? Double) ?? Double(document["carbohydrates"] as? String ?? "0") ?? 0.0
                let fat = (document["fat"] as? Double) ?? Double(document["fat"] as? String ?? "0") ?? 0.0
                
                // Extract micronutrients using same logic as regular search
                let fiber = (document["fiber"] as? Double) ?? Double(document["fiber"] as? String ?? "") ?? nil
                let sugar = (document["sugar"] as? Double) ?? Double(document["sugar"] as? String ?? "") ?? nil
                let sodium = (document["sodium"] as? Double) ?? Double(document["sodium"] as? String ?? "") ?? nil
                let saturatedFat = (document["saturated_fat"] as? Double) ?? Double(document["saturated_fat"] as? String ?? "") ?? nil
                
                print("  📊 Parsed nutrition data:")
                print("    calories: \(calories)")
                print("    protein: \(protein)g")
                print("    carbohydrates: \(carbs)g")
                print("    fat: \(fat)g")
                
                // Handle serving size from direct document fields
                var servingSize: String? = nil
                if let servingSizeNum = document["serving_size"] as? NSNumber {
                    servingSize = "\(servingSizeNum)"
                } else if let servingSizeStr = document["serving_size"] as? String {
                    servingSize = servingSizeStr
                }
                
                let servingType = document["serving_unit"] as? String
                
                // Extract region information
                let countries = document["countries"] as? [String]
                let purchasePlaces = document["purchase_places"] as? String
                let origins = document["origins"] as? String
                
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
                    servingType: servingType,
                    fiber: fiber,
                    sugar: sugar,
                    sodium: sodium,
                    saturatedFat: saturatedFat,
                    countries: countries,
                    purchasePlaces: purchasePlaces,
                    origins: origins
                )
                
                // Apply cached serving information to the found food
                let foodWithCache = FoodServingCacheService.shared.applyCachedServingInfo(to: [food]).first ?? food
                
                DispatchQueue.main.async {
                    completion(foodWithCache, nil)
                }
                
            case .failure(let error):
                print("❌ Barcode lookup error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    // MARK: - Add New Product
    
    /// Add a new product to the Typesense database
    func addNewProduct(
        name: String,
        brandName: String?,
        barcode: String?,
        calories: Int,
        protein: Double,
        carbohydrates: Double,
        fat: Double,
        fiber: Double? = nil,
        sugar: Double? = nil,
        sodium: Double? = nil,
        saturatedFat: Double? = nil,
        servingSize: String? = nil,
        servingsPerPackage: Double? = nil,
        servingType: String? = nil,
        ingredients: String = "",
        novaScore: Int = 1,
        nutriScoreGrade: String? = nil
    ) async throws -> String {
        
        print("🍎 Adding new product to Typesense: \(name)")
        
        // Create unique ID for the product
        let productId = UUID().uuidString
        
        // Build the document for Typesense
        var document: [String: Any] = [
            "id": productId,
            "name": name,
            "calories": calories,
            "protein": protein,
            "carbohydrates": carbohydrates,
            "fat": fat,
            "nova_score": novaScore,
            "user_contributed": true,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Add optional fields
        if let brandName = brandName, !brandName.isEmpty {
            document["brand"] = brandName
        }
        
        if let barcode = barcode, !barcode.isEmpty {
            document["barcode"] = barcode
        }
        
        if let fiber = fiber {
            document["fiber"] = fiber
        }
        
        if let sugar = sugar {
            document["sugar"] = sugar
        }
        
        if let sodium = sodium {
            document["sodium"] = sodium
        }
        
        if let saturatedFat = saturatedFat {
            document["saturated_fat"] = saturatedFat
        }
        
        if let servingSize = servingSize, !servingSize.isEmpty {
            document["serving_size"] = servingSize
        }
        
        if let servingsPerPackage = servingsPerPackage {
            document["servings_per_package"] = servingsPerPackage
        }
        
        if let servingType = servingType, !servingType.isEmpty {
            document["serving_type"] = servingType
        }
        
        if !ingredients.isEmpty {
            document["ingredients"] = ingredients
        }
        
        if let nutriScoreGrade = nutriScoreGrade, !nutriScoreGrade.isEmpty {
            document["nutriscore_grade"] = nutriScoreGrade
        }
        
        // Build the URL for adding documents
        let urlString = "\(TypesenseConfig.apiURL)/collections/\(TypesenseConfig.productsCollection)/documents"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "TypesenseDirectService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(TypesenseConfig.searchOnlyApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        // Convert document to JSON
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: document)
            request.httpBody = jsonData
            
            print("📤 Submitting document: \(String(data: jsonData, encoding: .utf8) ?? "Unable to encode")")
        } catch {
            throw NSError(domain: "TypesenseDirectService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode document: \(error.localizedDescription)"])
        }
        
        // Perform the request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 201 {
                    // Success - document created
                    print("✅ Product added successfully with ID: \(productId)")
                    return productId
                } else {
                    // Handle error response
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ Failed to add product. Status: \(httpResponse.statusCode), Error: \(errorMessage)")
                    throw NSError(domain: "TypesenseDirectService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to add product: \(errorMessage)"])
                }
            } else {
                throw NSError(domain: "TypesenseDirectService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw error
        }
    }
}
