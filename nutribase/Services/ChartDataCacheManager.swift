import Foundation
import Combine

/// Centralized cache manager for chart data across all detail views.
/// Persists in memory across view lifecycle and invalidates when data changes.
class ChartDataCacheManager: ObservableObject {
    static let shared = ChartDataCacheManager()
    
    // MARK: - Cache Structures
    
    /// Cached weekly macro data (calories, protein, carbs, fat)
    struct WeeklyMacroCache: Codable {
        let weekOffset: Int
        let dailyData: [String: Int]      // Day abbreviation -> value
        let hasEntries: [String: Bool]    // Day abbreviation -> has data
        let weeklyAverage: Double
        let weeklyTotal: Int
        let timestamp: Date
        let dataHash: Int                 // Hash of source data for validation
    }
    
    /// Cached monthly macro data
    struct MonthlyMacroCache: Codable {
        let monthOffset: Int
        let dailyData: [Int: Int]         // Day number -> value
        let hasEntries: [Int: Bool]       // Day number -> has data
        let monthlyAverage: Double
        let monthlyTotal: Int
        let timestamp: Date
        let dataHash: Int
    }
    
    /// Cached steps data
    struct WeeklyStepsCache {
        let weekOffset: Int
        let dailyData: [String: Int]
        let hasData: [String: Bool]
        let weeklyAverage: Double
        let weeklyTotal: Int
        let timestamp: Date
    }
    
    struct MonthlyStepsCache {
        let monthOffset: Int
        let dailyData: [Int: Int]
        let hasData: [Int: Bool]
        let monthlyAverage: Double
        let monthlyTotal: Int
        let timestamp: Date
    }
    
    /// Cached NOVA groups data
    struct WeeklyNovaCache {
        let weekOffset: Int
        let dailyData: [String: [Int: Int]]  // Day -> [NovaGroup: count]
        let hasEntries: [String: Bool]
        let weeklyAverage: [Int: Double]     // NovaGroup -> average
        let timestamp: Date
        let dataHash: Int
    }
    
    // MARK: - Cache Storage
    
    // Macro caches by type
    private var caloriesWeeklyCache: [Int: WeeklyMacroCache] = [:]
    private var caloriesMonthlyCache: [Int: MonthlyMacroCache] = [:]
    
    private var proteinWeeklyCache: [Int: WeeklyMacroCache] = [:]
    private var proteinMonthlyCache: [Int: MonthlyMacroCache] = [:]
    
    private var carbsWeeklyCache: [Int: WeeklyMacroCache] = [:]
    private var carbsMonthlyCache: [Int: MonthlyMacroCache] = [:]
    
    private var fatWeeklyCache: [Int: WeeklyMacroCache] = [:]
    private var fatMonthlyCache: [Int: MonthlyMacroCache] = [:]
    
    // Steps caches
    private var stepsWeeklyCache: [Int: WeeklyStepsCache] = [:]
    private var stepsMonthlyCache: [Int: MonthlyStepsCache] = [:]
    
    // NOVA cache
    private var novaWeeklyCache: [Int: WeeklyNovaCache] = [:]
    
    // Cache expiration time (in seconds) - data older than this will be refreshed
    private let cacheExpirationTime: TimeInterval = 3600 // 1 hour
    
    // Current data hash for validation
    private var currentFoodDataHash: Int = 0
    private var currentStepsDataHash: Int = 0
    
    // Debounce tracking to prevent repeated invalidation
    private var lastFoodCacheInvalidation: Date = .distantPast
    private var lastAllCacheInvalidation: Date = .distantPast
    private let invalidationDebounceInterval: TimeInterval = 1.0 // 1 second
    
    // Cancellables for subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        // Invalidate food-related caches when food log is updated
        NotificationCenter.default.publisher(for: .foodLogUpdated)
            .sink { [weak self] _ in
                self?.invalidateFoodCaches()
            }
            .store(in: &cancellables)
        
        // Invalidate when nutrition goals change
        NotificationCenter.default.publisher(for: .nutritionGoalsUpdated)
            .sink { [weak self] _ in
                self?.invalidateFoodCaches()
            }
            .store(in: &cancellables)
        
        // Handle user sign in/out
        NotificationCenter.default.publisher(for: .userDidSignIn)
            .sink { [weak self] _ in
                self?.invalidateAllCaches()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .userDidSignOut)
            .sink { [weak self] _ in
                self?.invalidateAllCaches()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Cache Invalidation
    
    /// Invalidate all food-related caches (calories, macros, NOVA)
    func invalidateFoodCaches() {
        // Debounce: skip if invalidated recently
        let now = Date()
        guard now.timeIntervalSince(lastFoodCacheInvalidation) > invalidationDebounceInterval else {
            return
        }
        lastFoodCacheInvalidation = now
        
        caloriesWeeklyCache.removeAll()
        caloriesMonthlyCache.removeAll()
        proteinWeeklyCache.removeAll()
        proteinMonthlyCache.removeAll()
        carbsWeeklyCache.removeAll()
        carbsMonthlyCache.removeAll()
        fatWeeklyCache.removeAll()
        fatMonthlyCache.removeAll()
        novaWeeklyCache.removeAll()
        
        currentFoodDataHash = 0
        
        print("📊 ChartDataCacheManager: Food caches invalidated")
    }
    
    /// Invalidate steps caches
    func invalidateStepsCaches() {
        stepsWeeklyCache.removeAll()
        stepsMonthlyCache.removeAll()
        currentStepsDataHash = 0
        
        print("📊 ChartDataCacheManager: Steps caches invalidated")
    }
    
    /// Invalidate all caches
    func invalidateAllCaches() {
        // Debounce: skip if invalidated recently
        let now = Date()
        guard now.timeIntervalSince(lastAllCacheInvalidation) > invalidationDebounceInterval else {
            return
        }
        lastAllCacheInvalidation = now
        lastFoodCacheInvalidation = now // Also update food cache timestamp
        
        caloriesWeeklyCache.removeAll()
        caloriesMonthlyCache.removeAll()
        proteinWeeklyCache.removeAll()
        proteinMonthlyCache.removeAll()
        carbsWeeklyCache.removeAll()
        carbsMonthlyCache.removeAll()
        fatWeeklyCache.removeAll()
        fatMonthlyCache.removeAll()
        novaWeeklyCache.removeAll()
        stepsWeeklyCache.removeAll()
        stepsMonthlyCache.removeAll()
        
        currentFoodDataHash = 0
        currentStepsDataHash = 0
        
        print("📊 ChartDataCacheManager: All caches invalidated")
    }
    
    /// Invalidate cache for a specific week/month
    func invalidateWeek(_ offset: Int, for type: MacroType) {
        switch type {
        case .calories:
            caloriesWeeklyCache.removeValue(forKey: offset)
        case .protein:
            proteinWeeklyCache.removeValue(forKey: offset)
        case .carbs:
            carbsWeeklyCache.removeValue(forKey: offset)
        case .fat:
            fatWeeklyCache.removeValue(forKey: offset)
        }
    }
    
    // MARK: - Macro Type Enum
    
    enum MacroType {
        case calories
        case protein
        case carbs
        case fat
    }
    
    // MARK: - Weekly Macro Cache Access
    
    /// Get cached weekly macro data, or nil if not cached/expired
    func getWeeklyMacroCache(for type: MacroType, weekOffset: Int) -> WeeklyMacroCache? {
        let cache: WeeklyMacroCache?
        
        switch type {
        case .calories:
            cache = caloriesWeeklyCache[weekOffset]
        case .protein:
            cache = proteinWeeklyCache[weekOffset]
        case .carbs:
            cache = carbsWeeklyCache[weekOffset]
        case .fat:
            cache = fatWeeklyCache[weekOffset]
        }
        
        // Check if cache is valid (not expired)
        if let cache = cache {
            let age = Date().timeIntervalSince(cache.timestamp)
            if age < cacheExpirationTime {
                return cache
            }
        }
        
        return nil
    }
    
    /// Store weekly macro data in cache
    func setWeeklyMacroCache(_ cache: WeeklyMacroCache, for type: MacroType) {
        switch type {
        case .calories:
            caloriesWeeklyCache[cache.weekOffset] = cache
        case .protein:
            proteinWeeklyCache[cache.weekOffset] = cache
        case .carbs:
            carbsWeeklyCache[cache.weekOffset] = cache
        case .fat:
            fatWeeklyCache[cache.weekOffset] = cache
        }
    }
    
    // MARK: - Monthly Macro Cache Access
    
    /// Get cached monthly macro data
    func getMonthlyMacroCache(for type: MacroType, monthOffset: Int) -> MonthlyMacroCache? {
        let cache: MonthlyMacroCache?
        
        switch type {
        case .calories:
            cache = caloriesMonthlyCache[monthOffset]
        case .protein:
            cache = proteinMonthlyCache[monthOffset]
        case .carbs:
            cache = carbsMonthlyCache[monthOffset]
        case .fat:
            cache = fatMonthlyCache[monthOffset]
        }
        
        if let cache = cache {
            let age = Date().timeIntervalSince(cache.timestamp)
            if age < cacheExpirationTime {
                return cache
            }
        }
        
        return nil
    }
    
    /// Store monthly macro data in cache
    func setMonthlyMacroCache(_ cache: MonthlyMacroCache, for type: MacroType) {
        switch type {
        case .calories:
            caloriesMonthlyCache[cache.monthOffset] = cache
        case .protein:
            proteinMonthlyCache[cache.monthOffset] = cache
        case .carbs:
            carbsMonthlyCache[cache.monthOffset] = cache
        case .fat:
            fatMonthlyCache[cache.monthOffset] = cache
        }
    }
    
    // MARK: - Steps Cache Access
    
    /// Get cached weekly steps data
    func getWeeklyStepsCache(weekOffset: Int) -> WeeklyStepsCache? {
        if let cache = stepsWeeklyCache[weekOffset] {
            let age = Date().timeIntervalSince(cache.timestamp)
            if age < cacheExpirationTime {
                return cache
            }
        }
        return nil
    }
    
    /// Store weekly steps data in cache
    func setWeeklyStepsCache(_ cache: WeeklyStepsCache) {
        stepsWeeklyCache[cache.weekOffset] = cache
    }
    
    /// Get cached monthly steps data
    func getMonthlyStepsCache(monthOffset: Int) -> MonthlyStepsCache? {
        if let cache = stepsMonthlyCache[monthOffset] {
            let age = Date().timeIntervalSince(cache.timestamp)
            if age < cacheExpirationTime {
                return cache
            }
        }
        return nil
    }
    
    /// Store monthly steps data in cache
    func setMonthlyStepsCache(_ cache: MonthlyStepsCache) {
        stepsMonthlyCache[cache.monthOffset] = cache
    }
    
    // MARK: - NOVA Cache Access
    
    /// Get cached weekly NOVA data
    func getWeeklyNovaCache(weekOffset: Int) -> WeeklyNovaCache? {
        if let cache = novaWeeklyCache[weekOffset] {
            let age = Date().timeIntervalSince(cache.timestamp)
            if age < cacheExpirationTime {
                return cache
            }
        }
        return nil
    }
    
    /// Store weekly NOVA data in cache
    func setWeeklyNovaCache(_ cache: WeeklyNovaCache) {
        novaWeeklyCache[cache.weekOffset] = cache
    }
    
    // MARK: - Cache Statistics
    
    /// Get cache statistics for debugging
    func getCacheStats() -> String {
        let stats = """
        📊 Cache Statistics:
        - Calories Weekly: \(caloriesWeeklyCache.count) entries
        - Calories Monthly: \(caloriesMonthlyCache.count) entries
        - Protein Weekly: \(proteinWeeklyCache.count) entries
        - Protein Monthly: \(proteinMonthlyCache.count) entries
        - Carbs Weekly: \(carbsWeeklyCache.count) entries
        - Carbs Monthly: \(carbsMonthlyCache.count) entries
        - Fat Weekly: \(fatWeeklyCache.count) entries
        - Fat Monthly: \(fatMonthlyCache.count) entries
        - Steps Weekly: \(stepsWeeklyCache.count) entries
        - Steps Monthly: \(stepsMonthlyCache.count) entries
        - NOVA Weekly: \(novaWeeklyCache.count) entries
        """
        return stats
    }
    
    // MARK: - Convenience Methods
    
    /// Check if we have valid cache for a week
    func hasValidWeeklyCache(for type: MacroType, weekOffset: Int) -> Bool {
        return getWeeklyMacroCache(for: type, weekOffset: weekOffset) != nil
    }
    
    /// Check if we have valid cache for a month
    func hasValidMonthlyCache(for type: MacroType, monthOffset: Int) -> Bool {
        return getMonthlyMacroCache(for: type, monthOffset: monthOffset) != nil
    }
    
    /// Pre-warm cache for common offsets (current and adjacent weeks)
    func prewarmCache(for type: MacroType, weekOffsets: [Int] = [-1, 0, 1]) {
        // This would be called from detail views to pre-load adjacent weeks
        // Implementation depends on the data source
    }
}

// MARK: - Notification Names Extension

extension Notification.Name {
    static let chartCacheInvalidated = Notification.Name("chartCacheInvalidated")
}
