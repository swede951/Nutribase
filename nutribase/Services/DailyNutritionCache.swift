import Foundation
import Combine

/// High-performance centralized cache for daily nutrition data.
/// Eliminates redundant calculations across dashboard cards by computing once and sharing.
/// Each card can access pre-computed summaries instead of recalculating independently.
class DailyNutritionCache: ObservableObject {
    static let shared = DailyNutritionCache()
    
    // MARK: - Data Structures
    
    /// Complete nutrition summary for a single day
    struct DaySummary {
        let date: Date
        let calories: Int
        let protein: Double
        let carbs: Double
        let fat: Double
        let fibre: Double
        let fibreIncludesEstimates: Bool
        let novaDistribution: [Int: Int]  // NOVA group -> calorie count
        let nutriScoreDistribution: [String: Int]  // Grade -> count
        let entryCount: Int
        let mealBreakdown: [String: MealSummary]  // Meal type -> summary
        let computedAt: Date
    }
    
    /// Summary for a single meal
    struct MealSummary {
        let calories: Int
        let protein: Double
        let carbs: Double
        let fat: Double
        let fibre: Double
        let fibreIncludesEstimates: Bool
        let entryCount: Int
    }
    
    /// Weekly summary for dashboard cards
    struct WeeklySummary {
        let startDate: Date
        let endDate: Date
        let dailySummaries: [Date: DaySummary]
        let totalCalories: Int
        let averageCalories: Double
        let totalProtein: Double
        let averageProtein: Double
        let totalCarbs: Double
        let averageCarbs: Double
        let totalFat: Double
        let averageFat: Double
        let totalFibre: Double
        let averageFibre: Double
        let novaDistribution: [Int: Int]
        let daysWithData: Int
        let computedAt: Date
    }
    
    // MARK: - Cache Storage
    
    private var dailyCache: [String: DaySummary] = [:]  // Date string -> summary
    private var weeklyCache: [Int: WeeklySummary] = [:]  // Week offset -> summary
    
    // Cache expiration
    private let cacheExpirationTime: TimeInterval = 300  // 5 minutes for daily
    private let weeklyCacheExpirationTime: TimeInterval = 600  // 10 minutes for weekly
    
    // Debouncing
    private var lastInvalidationTime: Date = .distantPast
    private let invalidationDebounceInterval: TimeInterval = 0.5
    
    // Pre-warming state
    private var isPrewarming = false
    private var prewarmTask: Task<Void, Never>?
    
    // Subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        // Invalidate when food log changes
        NotificationCenter.default.publisher(for: .foodLogUpdated)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.invalidateAllCaches()
                self?.prewarmCommonDates()
            }
            .store(in: &cancellables)
        
        // Invalidate on user changes
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
    
    // MARK: - Cache Key Generation
    
    private func dateKey(for date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year!)-\(components.month!)-\(components.day!)"
    }
    
    // MARK: - Daily Summary Access
    
    /// Get cached daily summary, computing if necessary
    func getDaySummary(for date: Date) -> DaySummary {
        let key = dateKey(for: date)
        
        // Check cache validity
        if let cached = dailyCache[key] {
            let age = Date().timeIntervalSince(cached.computedAt)
            if age < cacheExpirationTime {
                return cached
            }
        }
        
        // Compute and cache
        let summary = computeDaySummary(for: date)
        dailyCache[key] = summary
        return summary
    }
    
    /// Get cached daily summary without computing (returns nil if not cached)
    func getCachedDaySummary(for date: Date) -> DaySummary? {
        let key = dateKey(for: date)
        guard let cached = dailyCache[key] else { return nil }
        
        let age = Date().timeIntervalSince(cached.computedAt)
        return age < cacheExpirationTime ? cached : nil
    }
    
    // MARK: - Weekly Summary Access
    
    /// Get weekly summary for dashboard cards
    func getWeeklySummary(weekOffset: Int = 0) -> WeeklySummary {
        // Check cache
        if let cached = weeklyCache[weekOffset] {
            let age = Date().timeIntervalSince(cached.computedAt)
            if age < weeklyCacheExpirationTime {
                return cached
            }
        }
        
        // Compute and cache
        let summary = computeWeeklySummary(weekOffset: weekOffset)
        weeklyCache[weekOffset] = summary
        return summary
    }
    
    // MARK: - Computation
    
    private func computeDaySummary(for date: Date) -> DaySummary {
        let foodLogManager = FoodLogManager.shared
        let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snacks"]
        
        var totalCalories = 0
        var totalProtein = 0.0
        var totalCarbs = 0.0
        var totalFat = 0.0
        var totalFibre = 0.0
        var novaDistribution: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0]
        var nutriScoreDistribution: [String: Int] = [:]
        var totalEntries = 0
        var mealBreakdown: [String: MealSummary] = [:]
        
        for mealType in mealTypes {
            let entries = foodLogManager.entries(for: date, mealType: mealType)
            let expandedFoods = foodLogManager.expandedFoodItems(for: entries)
            
            var mealCalories = 0
            var mealProtein = 0.0
            var mealCarbs = 0.0
            var mealFat = 0.0
            var mealFibre = 0.0
            var mealFibreHasEstimates = false
            
            for food in expandedFoods {
                mealCalories += food.calories
                mealProtein += food.protein
                mealCarbs += food.carbs
                mealFat += food.fat
                mealFibre += food.fibre
                if food.fibreIsEstimated { mealFibreHasEstimates = true }
                
                // NOVA distribution
                let novaScore = food.novaScore > 0 ? food.novaScore : 
                    NovaScoreService.shared.predictNovaScoreByName(food.name)
                novaDistribution[novaScore, default: 0] += food.calories
                
                // Nutri-Score distribution
                if let grade = food.nutriScoreGrade, !grade.isEmpty {
                    nutriScoreDistribution[grade, default: 0] += 1
                }
            }
            
            totalCalories += mealCalories
            totalProtein += mealProtein
            totalCarbs += mealCarbs
            totalFat += mealFat
            totalFibre += mealFibre
            totalEntries += entries.count
            
            mealBreakdown[mealType] = MealSummary(
                calories: mealCalories,
                protein: mealProtein,
                carbs: mealCarbs,
                fat: mealFat,
                fibre: mealFibre,
                fibreIncludesEstimates: mealFibreHasEstimates,
                entryCount: entries.count
            )
        }
        
        let fibreHasEstimates = mealBreakdown.values.contains { $0.fibreIncludesEstimates }
        
        return DaySummary(
            date: date,
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat,
            fibre: totalFibre,
            fibreIncludesEstimates: fibreHasEstimates,
            novaDistribution: novaDistribution,
            nutriScoreDistribution: nutriScoreDistribution,
            entryCount: totalEntries,
            mealBreakdown: mealBreakdown,
            computedAt: Date()
        )
    }
    
    private func computeWeeklySummary(weekOffset: Int) -> WeeklySummary {
        let calendar = Calendar.current
        let today = Date()
        
        // Get week start (Monday)
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday == 1 ? 6 : weekday - 2
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today),
              let targetWeekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart),
              let targetWeekEnd = calendar.date(byAdding: .day, value: 6, to: targetWeekStart) else {
            return emptyWeeklySummary()
        }
        
        var dailySummaries: [Date: DaySummary] = [:]
        var totalCalories = 0
        var totalProtein = 0.0
        var totalCarbs = 0.0
        var totalFat = 0.0
        var totalFibre = 0.0
        var novaDistribution: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0]
        var daysWithData = 0
        
        for dayOffset in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: targetWeekStart) else { continue }
            
            let daySummary = getDaySummary(for: dayDate)
            dailySummaries[dayDate] = daySummary
            
            if daySummary.entryCount > 0 {
                totalCalories += daySummary.calories
                totalProtein += daySummary.protein
                totalCarbs += daySummary.carbs
                totalFat += daySummary.fat
                totalFibre += daySummary.fibre
                daysWithData += 1
                
                for (group, calories) in daySummary.novaDistribution {
                    novaDistribution[group, default: 0] += calories
                }
            }
        }
        
        let avgDivisor = max(daysWithData, 1)
        
        return WeeklySummary(
            startDate: targetWeekStart,
            endDate: targetWeekEnd,
            dailySummaries: dailySummaries,
            totalCalories: totalCalories,
            averageCalories: Double(totalCalories) / Double(avgDivisor),
            totalProtein: totalProtein,
            averageProtein: totalProtein / Double(avgDivisor),
            totalCarbs: totalCarbs,
            averageCarbs: totalCarbs / Double(avgDivisor),
            totalFat: totalFat,
            averageFat: totalFat / Double(avgDivisor),
            totalFibre: totalFibre,
            averageFibre: totalFibre / Double(avgDivisor),
            novaDistribution: novaDistribution,
            daysWithData: daysWithData,
            computedAt: Date()
        )
    }
    
    private func emptyWeeklySummary() -> WeeklySummary {
        return WeeklySummary(
            startDate: Date(),
            endDate: Date(),
            dailySummaries: [:],
            totalCalories: 0,
            averageCalories: 0,
            totalProtein: 0,
            averageProtein: 0,
            totalCarbs: 0,
            averageCarbs: 0,
            totalFat: 0,
            averageFat: 0,
            totalFibre: 0,
            averageFibre: 0,
            novaDistribution: [:],
            daysWithData: 0,
            computedAt: Date()
        )
    }
    
    // MARK: - Cache Management
    
    /// Invalidate all caches
    func invalidateAllCaches() {
        let now = Date()
        guard now.timeIntervalSince(lastInvalidationTime) > invalidationDebounceInterval else { return }
        lastInvalidationTime = now
        
        dailyCache.removeAll()
        weeklyCache.removeAll()
        
        print("🗑️ DailyNutritionCache: All caches invalidated")
    }
    
    /// Invalidate cache for a specific date
    func invalidateDate(_ date: Date) {
        let key = dateKey(for: date)
        dailyCache.removeValue(forKey: key)
        
        // Also invalidate affected weekly caches
        weeklyCache.removeAll()
    }
    
    /// Pre-warm cache for common dates (today and last 7 days)
    func prewarmCommonDates() {
        prewarmTask?.cancel()
        
        prewarmTask = Task(priority: .utility) {
            guard !isPrewarming else { return }
            isPrewarming = true
            
            defer { isPrewarming = false }
            
            let calendar = Calendar.current
            let today = Date()
            
            // Pre-warm today and last 6 days
            for dayOffset in 0..<7 {
                if Task.isCancelled { break }
                
                if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                    _ = await MainActor.run {
                        _ = getDaySummary(for: date)
                    }
                }
            }
            
            // Pre-warm current week summary
            if !Task.isCancelled {
                await MainActor.run {
                    _ = getWeeklySummary(weekOffset: 0)
                }
            }
            
            print("🔥 DailyNutritionCache: Pre-warmed common dates")
        }
    }
    
    // MARK: - Convenience Accessors
    
    /// Quick access to today's calories
    var todayCalories: Int {
        return getDaySummary(for: Date()).calories
    }
    
    /// Quick access to today's protein
    var todayProtein: Double {
        return getDaySummary(for: Date()).protein
    }
    
    /// Quick access to today's carbs
    var todayCarbs: Double {
        return getDaySummary(for: Date()).carbs
    }
    
    /// Quick access to today's fat
    var todayFat: Double {
        return getDaySummary(for: Date()).fat
    }
    
    /// Quick access to today's fibre
    var todayFibre: Double {
        return getDaySummary(for: Date()).fibre
    }
    
    /// Quick access to today's NOVA distribution
    var todayNovaDistribution: [Int: Int] {
        return getDaySummary(for: Date()).novaDistribution
    }
    
    /// Get calorie percentage for NOVA group today
    func todayNovaPercentage(for group: Int) -> Double {
        let distribution = todayNovaDistribution
        let total = distribution.values.reduce(0, +)
        guard total > 0 else { return 0 }
        return Double(distribution[group, default: 0]) / Double(total) * 100.0
    }
    
    // MARK: - Debug
    
    func getCacheStats() -> String {
        return """
        📊 DailyNutritionCache Stats:
        - Daily entries: \(dailyCache.count)
        - Weekly entries: \(weeklyCache.count)
        - Is prewarming: \(isPrewarming)
        """
    }
}
