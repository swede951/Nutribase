//
//  WeightChartCache.swift
//  nutribase
//
//  Created by Cascade on 2025-08-24.
//

import Foundation

class WeightChartCache: ObservableObject {
    static let shared = WeightChartCache()
    
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "WeightChartCachedData"
    private let lastUpdateKey = "WeightChartLastUpdate"
    private let cacheExpiryHours: Double = 24 // Cache expires after 24 hours
    
    @Published var cachedWeeklyAverages: [WeightLogEntry] = []
    @Published var isLoaded = false
    
    private init() {
        loadCachedData()
    }
    
    // MARK: - Public Methods
    
    func getCachedData() -> [WeightLogEntry] {
        if isCacheValid() {
            return cachedWeeklyAverages
        }
        return []
    }
    
    func updateCache(with entries: [WeightLogEntry]) {
        DispatchQueue.main.async {
            self.cachedWeeklyAverages = entries
            self.isLoaded = true
        }
        saveCachedData()
    }
    
    func invalidateCache() {
        DispatchQueue.main.async {
            self.cachedWeeklyAverages = []
            self.isLoaded = false
        }
        userDefaults.removeObject(forKey: cacheKey)
        userDefaults.removeObject(forKey: lastUpdateKey)
    }
    
    func isCacheValid() -> Bool {
        guard let lastUpdate = userDefaults.object(forKey: lastUpdateKey) as? Date else {
            return false
        }
        
        let hoursSinceUpdate = Date().timeIntervalSince(lastUpdate) / 3600
        return hoursSinceUpdate < cacheExpiryHours && !cachedWeeklyAverages.isEmpty
    }
    
    // MARK: - Private Methods
    
    private func loadCachedData() {
        guard let data = userDefaults.data(forKey: cacheKey) else {
            isLoaded = true
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            cachedWeeklyAverages = try decoder.decode([WeightLogEntry].self, from: data)
            isLoaded = true
        } catch {
            print("Failed to load cached weight chart data: \(error)")
            invalidateCache()
        }
    }
    
    private func saveCachedData() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cachedWeeklyAverages)
            userDefaults.set(data, forKey: cacheKey)
            userDefaults.set(Date(), forKey: lastUpdateKey)
        } catch {
            print("Failed to save weight chart data to cache: \(error)")
        }
    }
}

