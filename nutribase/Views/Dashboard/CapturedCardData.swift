//
//  CapturedCardData.swift
//  nutribase
//
//  Data structure to capture real card data when entering edit mode.
//  This data is captured once when edit is toggled, not continuously updated.
//

import SwiftUI

/// Holds captured data for all dashboard cards at the moment edit mode is entered
class CapturedCardData: ObservableObject {
    static let shared = CapturedCardData()
    
    // MARK: - Weight Data
    @Published var currentWeight: Double = 0.0
    @Published var weeklyWeightRate: Double = 0.0
    @Published var weightUnit: String = "kg"
    @Published var hasWeightData: Bool = false
    
    // MARK: - Weight Chart Data
    @Published var weightChartPoints: [(date: Date, weight: Double)] = []
    
    // MARK: - Calorie Data
    @Published var caloriesConsumed: Int = 0
    @Published var calorieTarget: Int = 2000
    @Published var weeklyCalorieData: [(day: String, consumed: Int)] = []
    
    // MARK: - Protein Data
    @Published var proteinConsumed: Int = 0
    @Published var proteinTarget: Int = 150
    @Published var weeklyProteinData: [(day: String, consumed: Int)] = []
    
    // MARK: - Carbs Data
    @Published var carbsConsumed: Int = 0
    @Published var carbsTarget: Int = 250
    @Published var weeklyCarbsData: [(day: String, consumed: Int)] = []
    
    // MARK: - Fat Data
    @Published var fatConsumed: Int = 0
    @Published var fatTarget: Int = 65
    @Published var weeklyFatData: [(day: String, consumed: Int)] = []
    
    // MARK: - Fibre Data
    @Published var fibreConsumed: Int = 0
    @Published var fibreTarget: Int = 30
    @Published var weeklyFibreData: [(day: String, consumed: Int)] = []
    
    // MARK: - Steps Data
    @Published var stepsCount: Int = 0
    @Published var stepsTarget: Int = 10000
    @Published var weeklyStepsData: [(day: String, steps: Int)] = []
    
    // MARK: - NOVA Groups Data
    @Published var novaDistribution: [Int: Double] = [1: 0.55, 2: 0.15, 3: 0.20, 4: 0.10]
    @Published var weeklyNovaData: [(day: String, distribution: [Int: Double])] = []
    
    // MARK: - Nutri-Score Data
    @Published var nutriScoreDistribution: [String: Double] = ["A": 0.43, "B": 0.31, "C": 0.16, "D": 0.06, "E": 0.02]
    @Published var weeklyNutriScoreData: [(day: String, distribution: [String: Double])] = []
    
    // MARK: - Gut Health Data
    @Published var gutHealthScore: Double = 0.0
    @Published var fiberScore: Double = 0.0
    @Published var upfScore: Double = 0.0
    @Published var fermentedScore: Double = 0.0
    @Published var fatQualityScore: Double = 0.0
    
    private init() {}
    
    /// Capture all current data from managers
    /// Completion is called on main thread after all async data (e.g. HealthKit steps) is ready
    func captureCurrentData(completion: (() -> Void)? = nil) {
        captureWeightData()
        captureCalorieData()
        captureProteinData()
        captureCarbsData()
        captureFatData()
        captureFibreData()
        captureNovaData()
        captureNutriScoreData()
        captureGutHealthData()
        captureStepsData(completion: completion)
    }
    
    // MARK: - Capture Methods
    
    private func captureWeightData() {
        let weightManager = WeightLogManager.shared
        
        if let mostRecent = weightManager.weightEntries.max(by: { $0.date < $1.date }) {
            currentWeight = mostRecent.movingAverage
            hasWeightData = true
            
            // Use entry's stored weekly rate (matches CurrentWeightCardView)
            if let storedRate = mostRecent.weeklyRate {
                weeklyWeightRate = storedRate
            } else {
                weeklyWeightRate = 0.0
            }
            
            // Capture chart points (All time - no date filter)
            weightChartPoints = weightManager.weightEntries
                .sorted { $0.date < $1.date }
                .map { (date: $0.date, weight: $0.movingAverage) }
        } else {
            hasWeightData = false
            currentWeight = 0.0
            weeklyWeightRate = 0.0
            weightChartPoints = []
        }
    }
    
    private func captureCalorieData() {
        let userProfile = UserProfile.shared
        let cache = DailyNutritionCache.shared
        
        calorieTarget = userProfile.dailyCalorieGoal > 0 ? userProfile.dailyCalorieGoal : 2000
        caloriesConsumed = cache.getDaySummary(for: Date()).calories
        
        // Capture weekly data
        weeklyCalorieData = getLast7DaysData { date in
            (getDayLetter(for: date), cache.getDaySummary(for: date).calories)
        }
    }
    
    private func captureProteinData() {
        let userProfile = UserProfile.shared
        let cache = DailyNutritionCache.shared
        
        proteinTarget = userProfile.proteinGoalGrams > 0 ? userProfile.proteinGoalGrams : 150
        proteinConsumed = Int(cache.getDaySummary(for: Date()).protein)
        
        weeklyProteinData = getLast7DaysData { date in
            (getDayLetter(for: date), Int(cache.getDaySummary(for: date).protein))
        }
    }
    
    private func captureCarbsData() {
        let userProfile = UserProfile.shared
        let cache = DailyNutritionCache.shared
        
        carbsTarget = userProfile.carbGoalGrams > 0 ? userProfile.carbGoalGrams : 250
        carbsConsumed = Int(cache.getDaySummary(for: Date()).carbs)
        
        weeklyCarbsData = getLast7DaysData { date in
            (getDayLetter(for: date), Int(cache.getDaySummary(for: date).carbs))
        }
    }
    
    private func captureFatData() {
        let userProfile = UserProfile.shared
        let cache = DailyNutritionCache.shared
        
        fatTarget = userProfile.fatGoalGrams > 0 ? userProfile.fatGoalGrams : 65
        fatConsumed = Int(cache.getDaySummary(for: Date()).fat)
        
        weeklyFatData = getLast7DaysData { date in
            (getDayLetter(for: date), Int(cache.getDaySummary(for: date).fat))
        }
    }
    
    private func captureFibreData() {
        let userProfile = UserProfile.shared
        let cache = DailyNutritionCache.shared
        
        fibreTarget = userProfile.fibreGoalGrams > 0 ? userProfile.fibreGoalGrams : 30
        fibreConsumed = Int(cache.getDaySummary(for: Date()).fibre)
        
        weeklyFibreData = getLast7DaysData { date in
            (getDayLetter(for: date), Int(cache.getDaySummary(for: date).fibre))
        }
    }
    
    private func captureStepsData(completion: (() -> Void)? = nil) {
        let activityManager = ActivityManager.shared
        let healthKitManager = HealthKitManager.shared
        
        stepsTarget = UserDefaults.standard.integer(forKey: "stepsGoal")
        if stepsTarget == 0 { stepsTarget = 10000 }
        stepsCount = activityManager.currentActivity.steps
        
        // Fetch actual per-day HealthKit data (matches StepsCardView.refreshData)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let group = DispatchGroup()
        
        // Use indexed array to preserve day ordering despite async completions
        var indexedData: [(index: Int, day: String, steps: Int)] = []
        let lock = NSLock()
        
        for i in 0..<7 {
            let dayOffset = 6 - i  // oldest first: 6 days ago, 5, 4, ... 0
            group.enter()
            if let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                let dayLetter = getDayLetter(for: dayStart)
                
                healthKitManager.fetchStepsForDateRange(start: dayStart, end: dayEnd) { steps, error in
                    lock.lock()
                    indexedData.append((index: i, day: dayLetter, steps: steps))
                    lock.unlock()
                    group.leave()
                }
            } else {
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            let sorted = indexedData.sorted { $0.index < $1.index }
            self?.weeklyStepsData = sorted.map { (day: $0.day, steps: $0.steps) }
            completion?()
        }
    }
    
    private func captureNovaData() {
        let foodLogManager = FoodLogManager.shared
        
        // Calculate weekly NOVA distribution over last 7 days (matches NovaGroupsCardView.calculateWeeklyPercentage)
        var totalCalories = 0
        var groupCalories: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0]
        let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snacks"]
        
        for daysAgo in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            
            // Get entries using same method as real card (by meal type)
            var allEntries: [FoodEntry] = []
            for mealType in mealTypes {
                allEntries.append(contentsOf: foodLogManager.entries(for: date, mealType: mealType))
            }
            
            let expandedFoods = foodLogManager.expandedFoodItems(for: allEntries)
            for food in expandedFoods {
                let novaScore = food.novaScore > 0 ?
                    food.novaScore :
                    NovaScoreService.shared.predictNovaScoreByName(food.name)
                groupCalories[novaScore, default: 0] += food.calories
                totalCalories += food.calories
            }
        }
        
        // Convert to percentages (matching real card)
        if totalCalories > 0 {
            novaDistribution = [
                1: Double(groupCalories[1, default: 0]) / Double(totalCalories),
                2: Double(groupCalories[2, default: 0]) / Double(totalCalories),
                3: Double(groupCalories[3, default: 0]) / Double(totalCalories),
                4: Double(groupCalories[4, default: 0]) / Double(totalCalories)
            ]
        } else {
            novaDistribution = [:]
        }
        
        // Weekly per-day data (for bars)
        weeklyNovaData = getLast7DaysData { date in
            var allEntries: [FoodEntry] = []
            for mealType in mealTypes {
                allEntries.append(contentsOf: foodLogManager.entries(for: date, mealType: mealType))
            }
            let expandedFoods = foodLogManager.expandedFoodItems(for: allEntries)
            let dayTotalCalories = expandedFoods.reduce(0.0) { $0 + Double($1.calories) }
            guard dayTotalCalories > 0 else { return (getDayLetter(for: date), [:]) }
            
            var distribution: [Int: Double] = [1: 0, 2: 0, 3: 0, 4: 0]
            for food in expandedFoods {
                let novaScore = food.novaScore > 0 ?
                    food.novaScore :
                    NovaScoreService.shared.predictNovaScoreByName(food.name)
                distribution[novaScore, default: 0] += Double(food.calories) / dayTotalCalories
            }
            return (getDayLetter(for: date), distribution)
        }
    }
    
    private func captureNutriScoreData() {
        let foodLogManager = FoodLogManager.shared
        let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snacks"]
        
        // Calculate weekly Nutri-Score distribution by ITEM COUNT (matches NutriScoreCardView.weeklyGradePercentages)
        // Real card counts food items per grade, NOT calorie-weighted
        var totalGradeCounts: [String: Int] = ["A": 0, "B": 0, "C": 0, "D": 0, "E": 0]
        var totalItems = 0
        
        // Also collect per-day data for bars
        var perDayData: [(day: String, distribution: [String: Double])] = []
        
        for daysAgo in (0..<7).reversed() {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            let dayLetter = getDayLetter(for: date)
            
            var allEntries: [FoodEntry] = []
            for mealType in mealTypes {
                allEntries.append(contentsOf: foodLogManager.entries(for: date, mealType: mealType))
            }
            
            // Count items per grade (matching real card which counts items, not calories)
            var dayCounts: [String: Int] = ["A": 0, "B": 0, "C": 0, "D": 0, "E": 0]
            var dayTotal = 0
            
            for entry in allEntries {
                if entry.foodItem.isMeal, let savedMeal = SavedMealsManager.shared.meals.first(where: { $0.name == entry.foodItem.name }) {
                    for mealFood in savedMeal.foods {
                        if let grade = mealFood.nutriScoreGrade?.uppercased(), ["A", "B", "C", "D", "E"].contains(grade) {
                            dayCounts[grade, default: 0] += 1
                            dayTotal += 1
                        }
                    }
                } else {
                    if let grade = entry.foodItem.nutriScoreGrade?.uppercased(), ["A", "B", "C", "D", "E"].contains(grade) {
                        dayCounts[grade, default: 0] += 1
                        dayTotal += 1
                    }
                }
            }
            
            // Add to weekly totals
            for (grade, count) in dayCounts {
                totalGradeCounts[grade, default: 0] += count
            }
            totalItems += dayTotal
            
            // Convert day counts to fractions for bar display
            var dayDistribution: [String: Double] = [:]
            if dayTotal > 0 {
                for (grade, count) in dayCounts {
                    dayDistribution[grade] = Double(count) / Double(dayTotal)
                }
            }
            perDayData.append((day: dayLetter, distribution: dayDistribution))
        }
        
        // Convert weekly totals to fractions (matches NutriScoreCardView.weeklyGradePercentages)
        if totalItems > 0 {
            nutriScoreDistribution = [:]
            for (grade, count) in totalGradeCounts {
                nutriScoreDistribution[grade] = Double(count) / Double(totalItems)
            }
        } else {
            nutriScoreDistribution = [:]
        }
        
        weeklyNutriScoreData = perDayData
    }
    
    private func captureGutHealthData() {
        let gutHealthService = GutHealthScoreService.shared
        let foodLogManager = FoodLogManager.shared
        
        let metrics = gutHealthService.calculateWeeklyMetrics(weekOffset: 0, entries: foodLogManager.entries)
        gutHealthScore = metrics.overallScore
        fiberScore = (metrics.fiberDiversityTotal / 35.0) * 100
        upfScore = (metrics.upfLoadTotal / 30.0) * 100
        fermentedScore = (metrics.fermentedPrebioticTotal / 20.0) * 100
        fatQualityScore = (metrics.fatQualityTotal / 15.0) * 100
    }
    
    // MARK: - Helper Methods
    
    private func getLast7DaysData<T>(_ transform: (Date) -> (String, T)) -> [(day: String, T)] {
        var result: [(day: String, T)] = []
        for daysAgo in (0..<7).reversed() {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            let (day, value) = transform(date)
            result.append((day: day, value))
        }
        return result
    }
    
    private func getDayLetter(for date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
        return dayLetters[weekday - 1]
    }
    
}
