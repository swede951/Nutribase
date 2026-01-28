//
//  AINutrientEstimationService.swift
//  nutribase
//
//  Created by Cascade on 2025-01-07.
//

import Foundation
import FirebaseFunctions

/// Service for AI-powered estimation of missing nutrient values (sugar, fiber)
class AINutrientEstimationService: ObservableObject {
    static let shared = AINutrientEstimationService()
    
    private let functions = Functions.functions()
    
    // Cache for estimated values to avoid repeated API calls
    // Long cache duration since nutritional content doesn't change
    private var estimateCache: [String: NutrientEstimate] = [:]
    private let cacheExpirationDays: Double = 90 // 3 months
    
    // Rate limiting and error tracking
    private var isPrefetching = false
    private var lastPrefetchAttempt: Date?
    private var consecutiveFailures = 0
    private var failedItemKeys: Set<String> = []
    private var lastFailureTime: Date?
    private let prefetchCooldownSeconds: Double = 30  // Wait 30 seconds between prefetch attempts
    private let failureCooldownMinutes: Double = 5    // Wait 5 minutes after errors before retrying
    
    struct NutrientEstimate: Codable {
        let sugar: Double
        let fiber: Double
        let timestamp: Date
        
        var isExpired: Bool {
            // 90 days expiration - nutritional content doesn't change
            // This ensures consistent scores when comparing historical weeks
            Date().timeIntervalSince(timestamp) > 90 * 24 * 60 * 60
        }
    }
    
    struct FoodInput {
        let id: String
        let name: String
        let brand: String?
    }
    
    private init() {
        loadCache()
    }
    
    // MARK: - Public Methods
    
    /// Get estimated nutrients for a single food item
    /// Returns cached value if available, otherwise uses keyword fallback
    func getEstimate(for food: FoodItem) -> NutrientEstimate? {
        let cacheKey = createCacheKey(name: food.name, brand: food.brandName)
        
        if let cached = estimateCache[cacheKey], !cached.isExpired {
            return cached
        }
        
        return nil
    }
    
    /// Batch estimate nutrients for multiple foods using AI
    /// This is async and should be called when calculating gut health metrics
    func estimateNutrients(for foods: [FoodInput]) async throws -> [String: NutrientEstimate] {
        // Filter out foods that are already cached
        let uncachedFoods = foods.filter { food in
            let cacheKey = createCacheKey(name: food.name, brand: food.brand)
            if let cached = estimateCache[cacheKey], !cached.isExpired {
                return false
            }
            return true
        }
        
        guard !uncachedFoods.isEmpty else {
            // All foods are cached, return from cache
            var results: [String: NutrientEstimate] = [:]
            for food in foods {
                let cacheKey = createCacheKey(name: food.name, brand: food.brand)
                if let cached = estimateCache[cacheKey] {
                    results[food.id] = cached
                }
            }
            return results
        }
        
        // Prepare data for Firebase function
        let foodData = uncachedFoods.map { food in
            [
                "name": food.name,
                "brand": food.brand ?? ""
            ]
        }
        
        // Call Firebase function
        let result = try await functions.httpsCallable("aiNutrientEstimate").call(["foods": foodData])
        
        guard let response = result.data as? [String: Any],
              let success = response["success"] as? Bool,
              success,
              let estimates = response["estimates"] as? [[String: Any]] else {
            throw NSError(domain: "AINutrientEstimation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from AI service"])
        }
        
        // Process and cache results
        var results: [String: NutrientEstimate] = [:]
        
        for (index, food) in uncachedFoods.enumerated() {
            guard index < estimates.count else { break }
            
            let estimateData = estimates[index]
            let sugar = estimateData["sugar"] as? Double ?? 2.0
            let fiber = estimateData["fiber"] as? Double ?? 2.0
            
            let estimate = NutrientEstimate(sugar: sugar, fiber: fiber, timestamp: Date())
            
            let cacheKey = createCacheKey(name: food.name, brand: food.brand)
            estimateCache[cacheKey] = estimate
            results[food.id] = estimate
        }
        
        // Add cached results for foods that were already in cache
        for food in foods {
            if results[food.id] == nil {
                let cacheKey = createCacheKey(name: food.name, brand: food.brand)
                if let cached = estimateCache[cacheKey] {
                    results[food.id] = cached
                }
            }
        }
        
        // Save cache
        saveCache()
        
        print("🤖 AI estimated nutrients for \(uncachedFoods.count) foods")
        
        return results
    }
    
    /// Pre-fetch estimates for foods that are missing sugar/fiber data
    /// Call this when loading gut health view to warm up the cache
    func prefetchEstimates(for entries: [FoodEntry]) {
        // Rate limiting: prevent concurrent prefetch operations
        guard !isPrefetching else { return }
        
        // Rate limiting: enforce cooldown between attempts
        if let lastAttempt = lastPrefetchAttempt {
            let elapsed = Date().timeIntervalSince(lastAttempt)
            if elapsed < prefetchCooldownSeconds {
                return
            }
        }
        
        // If we've had recent failures, wait longer before retrying
        if consecutiveFailures > 0, let lastFailure = lastFailureTime {
            let failureCooldown = failureCooldownMinutes * 60 * Double(min(consecutiveFailures, 5))
            if Date().timeIntervalSince(lastFailure) < failureCooldown {
                return
            }
        }
        
        let foodsNeedingEstimates = entries.compactMap { entry -> FoodInput? in
            let hasSugar = entry.foodItem.sugar != nil && entry.foodItem.sugar! > 0
            let hasFiber = entry.foodItem.fiber != nil && entry.foodItem.fiber! > 0
            
            if !hasSugar || !hasFiber {
                let cacheKey = createCacheKey(name: entry.foodItem.name, brand: entry.foodItem.brandName)
                // Skip items that are cached or have recently failed
                if estimateCache[cacheKey] == nil || estimateCache[cacheKey]!.isExpired {
                    if !failedItemKeys.contains(cacheKey) {
                        return FoodInput(
                            id: entry.id.uuidString,
                            name: entry.foodItem.name,
                            brand: entry.foodItem.brandName
                        )
                    }
                }
            }
            return nil
        }
        
        guard !foodsNeedingEstimates.isEmpty else { return }
        
        isPrefetching = true
        lastPrefetchAttempt = Date()
        
        // Batch in groups of 20
        let batches = stride(from: 0, to: foodsNeedingEstimates.count, by: 20).map {
            Array(foodsNeedingEstimates[$0..<min($0 + 20, foodsNeedingEstimates.count)])
        }
        
        Task {
            var hasError = false
            
            for batch in batches {
                do {
                    _ = try await estimateNutrients(for: batch)
                    // Reset failure count on success
                    consecutiveFailures = 0
                } catch {
                    hasError = true
                    consecutiveFailures += 1
                    lastFailureTime = Date()
                    
                    // Track failed items so we don't retry them immediately
                    for food in batch {
                        let cacheKey = createCacheKey(name: food.name, brand: food.brand)
                        failedItemKeys.insert(cacheKey)
                    }
                    
                    // Only log once per batch, not per item
                    if consecutiveFailures <= 3 {
                        print("⚠️ AI nutrient estimation unavailable (attempt \(consecutiveFailures))")
                    }
                    
                    // Stop processing more batches if we're getting errors
                    break
                }
            }
            
            isPrefetching = false
            
            // Clear failed items after cooldown period (they'll be retried later)
            if !hasError {
                failedItemKeys.removeAll()
            }
        }
    }
    
    // MARK: - Cache Management
    
    private func createCacheKey(name: String, brand: String?) -> String {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBrand = (brand ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(normalizedName)|\(normalizedBrand)"
    }
    
    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: "ai_nutrient_estimate_cache"),
              let decoded = try? JSONDecoder().decode([String: NutrientEstimate].self, from: data) else {
            return
        }
        
        // Filter out expired entries
        estimateCache = decoded.filter { !$0.value.isExpired }
    }
    
    private func saveCache() {
        // Limit cache size
        if estimateCache.count > 500 {
            let sorted = estimateCache.sorted { $0.value.timestamp > $1.value.timestamp }
            estimateCache = Dictionary(uniqueKeysWithValues: Array(sorted.prefix(300)))
        }
        
        if let encoded = try? JSONEncoder().encode(estimateCache) {
            UserDefaults.standard.set(encoded, forKey: "ai_nutrient_estimate_cache")
        }
    }
    
    func clearCache() {
        estimateCache.removeAll()
        UserDefaults.standard.removeObject(forKey: "ai_nutrient_estimate_cache")
    }
}
