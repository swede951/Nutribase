import Foundation

/// Service for estimating fiber content (per 100g) for foods that are missing fiber data.
/// Uses a 3-tier approach: Typesense similar food search → USDA database → category keyword fallback.
/// All estimates are cached locally to avoid repeated API calls.
class FiberEstimationService {
    static let shared = FiberEstimationService()
    
    // MARK: - Cache
    
    struct FiberEstimate: Codable {
        let fiberPer100g: Double
        let source: String // "typesense", "usda", "category"
        let matchedFoodName: String? // Name of the food that was matched (for Typesense)
        let timestamp: Date
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 90 * 24 * 60 * 60 // 90 days
        }
    }
    
    private var estimateCache: [String: FiberEstimate] = [:]
    private let userDefaultsKey = "fiber_estimation_cache"
    
    // Track in-flight Typesense lookups to avoid duplicate requests
    private var pendingLookups: Set<String> = []
    
    private init() {
        loadCache()
    }
    
    // MARK: - Public API
    
    /// Get estimated fiber per 100g for a food item (synchronous — returns cached or fallback value).
    /// Returns nil only if the food already has actual fiber data.
    func getEstimate(for food: FoodItem) -> FiberEstimate? {
        // Don't estimate if food already has fiber data
        guard food.fiber == nil else { return nil }
        
        // Skip meals and Quick Add
        guard !food.isMeal && food.name != "Quick Add" else { return nil }
        
        let key = cacheKey(for: food)
        
        // Return cached estimate if available
        if let cached = estimateCache[key], !cached.isExpired {
            return cached
        }
        
        // Tier 2: USDA database (synchronous)
        if let usdaFiber = lookupUSDA(for: food) {
            let estimate = FiberEstimate(
                fiberPer100g: usdaFiber,
                source: "usda",
                matchedFoodName: nil,
                timestamp: Date()
            )
            estimateCache[key] = estimate
            saveCache()
            return estimate
        }
        
        // Tier 3: Category keyword fallback (synchronous)
        let categoryFiber = estimateFromCategory(for: food)
        let estimate = FiberEstimate(
            fiberPer100g: categoryFiber,
            source: "category",
            matchedFoodName: nil,
            timestamp: Date()
        )
        estimateCache[key] = estimate
        saveCache()
        return estimate
    }
    
    /// Trigger async Typesense search for better estimates. Call this on view appear to warm up cache.
    /// When results arrive, posts .foodLogUpdated to refresh the UI with more accurate estimates.
    func prefetchEstimates(for entries: [FoodEntry]) {
        let entriesNeedingEstimates = entries.filter { entry in
            guard entry.foodItem.fiber == nil,
                  !entry.foodItem.isMeal,
                  entry.foodItem.name != "Quick Add" else { return false }
            
            let key = cacheKey(for: entry.foodItem)
            // Only search Typesense if we don't already have a Typesense-sourced estimate
            if let cached = estimateCache[key], !cached.isExpired, cached.source == "typesense" {
                return false
            }
            // Don't duplicate in-flight requests
            if pendingLookups.contains(key) {
                return false
            }
            return true
        }
        
        guard !entriesNeedingEstimates.isEmpty else { return }
        
        var updatedCount = 0
        let totalCount = entriesNeedingEstimates.count
        
        for entry in entriesNeedingEstimates {
            let key = cacheKey(for: entry.foodItem)
            pendingLookups.insert(key)
            
            TypesenseDirectService.shared.searchFoods(query: entry.foodItem.name) { [weak self] results, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.pendingLookups.remove(key)
                    
                    if let results = results {
                        // Find best match that has fiber data
                        let match = self.findBestFiberMatch(
                            for: entry.foodItem,
                            in: results
                        )
                        
                        if let match = match {
                            let estimate = FiberEstimate(
                                fiberPer100g: match.fiber!,
                                source: "typesense",
                                matchedFoodName: match.name,
                                timestamp: Date()
                            )
                            self.estimateCache[key] = estimate
                        }
                    }
                    
                    updatedCount += 1
                    if updatedCount >= totalCount {
                        self.saveCache()
                        // Refresh UI with better estimates
                        NotificationCenter.default.post(name: .foodLogUpdated, object: nil)
                    }
                }
            }
        }
    }
    
    // MARK: - Tier 1: Typesense Similar Food Search
    
    /// Find the best matching food with fiber data from Typesense search results
    private func findBestFiberMatch(for food: FoodItem, in results: [FoodItem]) -> FoodItem? {
        let foodNameLower = food.name.lowercased()
        let foodBrandLower = food.brandName?.lowercased()
        
        // Priority 1: Exact name + brand match with fiber
        if let exactMatch = results.first(where: {
            $0.fiber != nil &&
            $0.name.lowercased() == foodNameLower &&
            $0.brandName?.lowercased() == foodBrandLower
        }) {
            return exactMatch
        }
        
        // Priority 2: Exact name match with fiber (any brand)
        if let nameMatch = results.first(where: {
            $0.fiber != nil &&
            $0.name.lowercased() == foodNameLower
        }) {
            return nameMatch
        }
        
        // Priority 3: Name contains the search term with fiber
        // Pick the one with the most similar calorie count (best proxy for similar food)
        let containsMatches = results.filter {
            $0.fiber != nil &&
            ($0.name.lowercased().contains(foodNameLower) || foodNameLower.contains($0.name.lowercased()))
        }
        
        if !containsMatches.isEmpty {
            // Sort by calorie similarity
            let sortedByCalorieSimilarity = containsMatches.sorted {
                abs($0.calories - food.calories) < abs($1.calories - food.calories)
            }
            return sortedByCalorieSimilarity.first
        }
        
        // Priority 4: Any result with fiber data (first result is usually most relevant from Typesense ranking)
        return results.first(where: { $0.fiber != nil })
    }
    
    // MARK: - Tier 2: USDA Database Lookup
    
    /// Look up fiber from the USDA verified database via GutHealthScoreService
    private func lookupUSDA(for food: FoodItem) -> Double? {
        // Reuse GutHealthScoreService's USDA database
        let estimate = GutHealthScoreService.shared.estimateFiberForDebug(for: food)
        // GutHealthScoreService returns 2.0 as its default fallback — we only want USDA/AI matches here
        // Check if this is a real USDA match by seeing if the food name matches a USDA entry
        let searchText = food.name.lowercased()
        
        // If GutHealthScoreService returns something other than the default 2.0, it found a match
        // Or if it IS 2.0, verify it's a real match not the default
        if estimate != 2.0 {
            return estimate
        }
        
        // For the default 2.0 case, check AI cache which might have a real value
        if let aiEstimate = AINutrientEstimationService.shared.getEstimate(for: food) {
            return aiEstimate.fiber
        }
        
        return nil
    }
    
    // MARK: - Tier 3: Category Keyword Fallback
    
    /// Estimate fiber per 100g based on food category keywords
    private func estimateFromCategory(for food: FoodItem) -> Double {
        let searchText = "\(food.name) \(food.brandName ?? "")".lowercased()
        
        // High fiber foods (5-10g per 100g)
        let highFiberKeywords = ["lentil", "chickpea", "bean", "legume", "chia", "flax", "bran", "artichoke", "split pea", "dal"]
        for keyword in highFiberKeywords {
            if searchText.contains(keyword) { return 7.0 }
        }
        
        // Good fiber foods (3-5g per 100g)
        let goodFiberKeywords = ["broccoli", "avocado", "raspberry", "blackberry", "pear", "oat", "whole grain",
                                  "quinoa", "sweet potato", "brussels sprout", "kale", "spinach", "pea",
                                  "almond", "walnut", "pistachio", "coconut", "date", "fig", "prune"]
        for keyword in goodFiberKeywords {
            if searchText.contains(keyword) { return 4.0 }
        }
        
        // Moderate fiber foods (1.5-3g per 100g)
        let moderateFiberKeywords = ["apple", "banana", "orange", "blueberry", "strawberry", "carrot",
                                      "potato", "tomato", "bread", "rice", "pasta", "cereal", "mango",
                                      "peach", "grape", "corn", "pepper", "onion", "mushroom",
                                      "peanut butter", "granola", "muesli"]
        for keyword in moderateFiberKeywords {
            if searchText.contains(keyword) { return 2.0 }
        }
        
        // Low/no fiber foods (0-1g per 100g)
        let lowFiberKeywords = ["chicken", "beef", "pork", "lamb", "fish", "salmon", "tuna", "shrimp",
                                 "egg", "milk", "cheese", "yogurt", "butter", "cream", "oil",
                                 "steak", "bacon", "sausage", "ham", "turkey", "duck",
                                 "juice", "soda", "coffee", "tea", "water", "wine", "beer",
                                 "candy", "chocolate", "sugar", "syrup", "honey", "ice cream",
                                 "whey", "protein powder", "protein shake"]
        for keyword in lowFiberKeywords {
            if searchText.contains(keyword) { return 0.5 }
        }
        
        // Default: moderate estimate for unknown foods
        return 1.5
    }
    
    // MARK: - Cache Key
    
    private func cacheKey(for food: FoodItem) -> String {
        let name = food.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = (food.brandName ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(name)|\(brand)"
    }
    
    // MARK: - Persistence
    
    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: FiberEstimate].self, from: data) else {
            return
        }
        estimateCache = decoded.filter { !$0.value.isExpired }
    }
    
    private func saveCache() {
        // Limit cache size to 500 entries
        if estimateCache.count > 500 {
            let sorted = estimateCache.sorted { $0.value.timestamp > $1.value.timestamp }
            estimateCache = Dictionary(uniqueKeysWithValues: Array(sorted.prefix(300)))
        }
        
        if let encoded = try? JSONEncoder().encode(estimateCache) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    func clearCache() {
        estimateCache.removeAll()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
