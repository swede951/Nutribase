import Foundation
import SwiftUI

// Cached serving information for a food item
struct CachedServingInfo: Codable {
    let foodId: String // Unique identifier for the food (name + brand + barcode)
    let servingSize: Double
    let servingUnit: String
    let numberOfServings: Double
    let selectedServingSizeOption: String?
    let lastUsed: Date
    
    init(foodId: String, servingSize: Double, servingUnit: String, numberOfServings: Double, selectedServingSizeOption: String? = nil) {
        self.foodId = foodId
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.numberOfServings = numberOfServings
        self.selectedServingSizeOption = selectedServingSizeOption
        self.lastUsed = Date()
    }
}

// Service to manage cached serving information for foods
class FoodServingCacheService: ObservableObject {
    static let shared = FoodServingCacheService()
    
    private let userDefaults = UserDefaults.standard
    private let maxCacheSize = 500 // Maximum number of cached foods
    
    // User-specific cache key
    private var cacheKey: String {
        if let authenticatedUser = FirebaseAuthService.shared.currentUser {
            return "foodServingCache_\(authenticatedUser.id)"
        } else {
            // Fallback to local UUID for offline usage
            if let existingId = UserDefaults.standard.string(forKey: "current_user_id") {
                return "foodServingCache_\(existingId)"
            } else {
                let newId = UUID().uuidString
                UserDefaults.standard.set(newId, forKey: "current_user_id")
                return "foodServingCache_\(newId)"
            }
        }
    }
    
    private var cache: [String: CachedServingInfo] = [:]
    
    private init() {
        loadCache()
        
        // Subscribe to authentication changes to reload user-specific cache
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthenticationChange),
            name: .userDidSignIn,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthenticationChange),
            name: .userDidSignOut,
            object: nil
        )
    }
    
    @objc private func handleAuthenticationChange() {
        // Clear current cache and reload for new user
        cache.removeAll()
        loadCache()
    }
    
    // Generate a unique identifier for a food item
    private func generateFoodId(for food: FoodItem) -> String {
        var components: [String] = [food.name.lowercased()]
        
        if let brand = food.brandName, !brand.isEmpty {
            components.append(brand.lowercased())
        }
        
        if let barcode = food.barcode, !barcode.isEmpty {
            components.append(barcode)
        }
        
        return components.joined(separator: "|")
    }
    
    // Cache serving information for a food item
    func cacheServingInfo(for food: FoodItem, servingSize: Double, servingUnit: String, numberOfServings: Double, selectedServingSizeOption: String? = nil) {
        let foodId = generateFoodId(for: food)
        let cachedInfo = CachedServingInfo(
            foodId: foodId,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            selectedServingSizeOption: selectedServingSizeOption
        )
        
        cache[foodId] = cachedInfo
        
        // Trim cache if it gets too large
        trimCacheIfNeeded()
        
        // Save to UserDefaults
        saveCache()
        
        print("🗄️ Cached serving info for \(food.name): \(numberOfServings) × \(servingSize)\(servingUnit)")
    }
    
    // Get cached serving information for a food item
    func getCachedServingInfo(for food: FoodItem) -> CachedServingInfo? {
        let foodId = generateFoodId(for: food)
        return cache[foodId]
    }
    
    // Create a FoodItem with cached serving information
    func createFoodItemWithCache(from originalFood: FoodItem) -> FoodItem {
        guard let cachedInfo = getCachedServingInfo(for: originalFood) else {
            return originalFood
        }
        
        // Create a new FoodItem with the cached serving information
        return FoodItem(
            name: originalFood.name,
            brandName: originalFood.brandName,
            barcode: originalFood.barcode,
            calories: originalFood.calories,
            protein: originalFood.protein,
            carbs: originalFood.carbs,
            fat: originalFood.fat,
            novaScore: originalFood.novaScore,
            nutriScoreGrade: originalFood.nutriScoreGrade,
            servingSize: originalFood.servingSize,
            servingsPerPackage: originalFood.servingsPerPackage,
            servingType: originalFood.servingType,
            cachedServingSize: cachedInfo.servingSize,
            cachedServingUnit: cachedInfo.servingUnit,
            cachedNumberOfServings: cachedInfo.numberOfServings,
            cachedSelectedServingSizeOption: cachedInfo.selectedServingSizeOption
        )
    }
    
    // Apply cached serving information to a list of food items
    func applyCachedServingInfo(to foods: [FoodItem]) -> [FoodItem] {
        return foods.map { createFoodItemWithCache(from: $0) }
    }
    
    // Check if a food item has cached serving information
    func hasCachedServingInfo(for food: FoodItem) -> Bool {
        let foodId = generateFoodId(for: food)
        return cache[foodId] != nil
    }
    
    // Remove cached serving information for a food item
    func removeCachedServingInfo(for food: FoodItem) {
        let foodId = generateFoodId(for: food)
        cache.removeValue(forKey: foodId)
        saveCache()
        
        print("🗑️ Removed cached serving info for \(food.name)")
    }
    
    // Clear all cached serving information
    func clearAllCache() {
        cache.removeAll()
        userDefaults.removeObject(forKey: cacheKey)
        
        print("🗑️ Cleared all cached serving information")
    }
    
    // Trim cache to maximum size by removing oldest entries
    private func trimCacheIfNeeded() {
        guard cache.count > maxCacheSize else { return }
        
        // Sort by last used date and remove oldest entries
        let sortedEntries = cache.sorted { $0.value.lastUsed < $1.value.lastUsed }
        let entriesToRemove = sortedEntries.prefix(cache.count - maxCacheSize)
        
        for (foodId, _) in entriesToRemove {
            cache.removeValue(forKey: foodId)
        }
        
        print("🗄️ Trimmed food serving cache to \(cache.count) entries")
    }
    
    // Load cache from UserDefaults
    private func loadCache() {
        guard let data = userDefaults.data(forKey: cacheKey),
              let decodedCache = try? JSONDecoder().decode([String: CachedServingInfo].self, from: data) else {
            cache = [:]
            return
        }
        
        cache = decodedCache
        print("🗄️ Loaded \(cache.count) cached serving entries")
    }
    
    // Save cache to UserDefaults
    private func saveCache() {
        guard let encodedData = try? JSONEncoder().encode(cache) else {
            print("❌ Failed to encode food serving cache")
            return
        }
        
        userDefaults.set(encodedData, forKey: cacheKey)
    }
    
    // Get cache statistics for debugging
    func getCacheStats() -> (count: Int, oldestEntry: Date?, newestEntry: Date?) {
        guard !cache.isEmpty else {
            return (count: 0, oldestEntry: nil, newestEntry: nil)
        }
        
        let dates = cache.values.map { $0.lastUsed }
        return (
            count: cache.count,
            oldestEntry: dates.min(),
            newestEntry: dates.max()
        )
    }
}
