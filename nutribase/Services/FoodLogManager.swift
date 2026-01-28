import Foundation
import SwiftUI
import Combine

// Food entry model
struct FoodEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let foodItem: FoodItem
    let mealType: String
    let servingSize: Double
    let servingUnit: String
    let numberOfServings: Double
    let dateAdded: Date
    
    // Check if using original serving size from database
    private var isUsingOriginalServingSize: Bool {
        // "serving", "servings", or "meal" unit types mean original serving size was selected
        let unitLower = servingUnit.lowercased()
        if unitLower == "serving" || unitLower == "servings" || unitLower == "meal" {
            return true
        }
        
        guard let originalServingSize = foodItem.servingSize else { 
            return false 
        }
        
        let originalLower = originalServingSize.lowercased()
        let currentSize = String(format: "%.0f", servingSize)
        let currentUnit = servingUnit.lowercased()
        
        return originalLower.contains(currentSize) && originalLower.contains(currentUnit)
    }
    
    var totalCalories: Int {
        return NutritionCalculator.calculateCalories(
            foodCalories: foodItem.calories,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize,
            servingDescription: foodItem.servingSize,
            servingQuantity: foodItem.servingsPerPackage
        )
    }
    
    var totalProtein: Double {
        return NutritionCalculator.calculateMacro(
            macroValue: foodItem.protein,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize,
            servingDescription: foodItem.servingSize,
            servingQuantity: foodItem.servingsPerPackage
        )
    }
    
    var totalCarbs: Double {
        let result = NutritionCalculator.calculateMacro(
            macroValue: foodItem.carbs,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize,
            servingDescription: foodItem.servingSize,
            servingQuantity: foodItem.servingsPerPackage
        )
        return result
    }
    
    var totalFat: Double {
        let result = NutritionCalculator.calculateMacro(
            macroValue: foodItem.fat,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize,
            servingDescription: foodItem.servingSize,
            servingQuantity: foodItem.servingsPerPackage
        )
        return result
    }
}

// Manager class for food log entries
class FoodLogManager: ObservableObject {
    static let shared = FoodLogManager()
    
    @Published var entries: [FoodEntry] = [] {
        didSet {
            // Invalidate caches when entries change
            dailyTotalsCache.removeAll()
            GutHealthScoreService.shared.invalidateCache()
        }
    }
    
    // Cache for daily totals to avoid repeated calculations
    private var dailyTotalsCache: [String: DailyTotals] = [:]
    
    private struct DailyTotals {
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
    }
    
    @Published private var persistentStreak: Int = 0
    @Published private var lastLoggedDate: Date? = nil
    
    // Keys for UserDefaults storage (user-specific)
    private var streakKey: String {
        if let authenticatedUser = FirebaseAuthService.shared.currentUser {
            return "foodLogStreak_\(authenticatedUser.id)"
        } else {
            // Fallback to local UUID for offline usage
            if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
                return "foodLogStreak_\(localUserId)"
            }
            return "foodLogStreak_default"
        }
    }
    
    private var lastLoggedDateKey: String {
        if let authenticatedUser = FirebaseAuthService.shared.currentUser {
            return "lastLoggedDate_\(authenticatedUser.id)"
        } else {
            // Fallback to local UUID for offline usage
            if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
                return "lastLoggedDate_\(localUserId)"
            }
            return "lastLoggedDate_default"
        }
    }
    
    // Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // Key for UserDefaults storage (user-specific)
    private var foodEntriesKey: String {
        if let authenticatedUser = FirebaseAuthService.shared.currentUser {
            return "foodEntries_\(authenticatedUser.id)"
        } else {
            // Fallback to local UUID for offline usage
            if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
                return "foodEntries_\(localUserId)"
            }
            return "foodEntries_default"
        }
    }
    
    private init() {
        loadEntries()
        loadStreakData()
        
        // Subscribe to authentication changes to reload user-specific data
        NotificationCenter.default.publisher(for: .userDidSignIn)
            .sink { [weak self] _ in
                // Reload entries for the new user
                self?.loadEntries()
                self?.loadStreakData()
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .userDidSignOut)
            .sink { [weak self] _ in
                // Reload entries for guest mode
                self?.loadEntries()
                self?.loadStreakData()
            }
            .store(in: &cancellables)
            
        // Set up authentication notification observers
        setupAuthenticationObservers()
    }
    
    // Set up authentication notification observers
    private func setupAuthenticationObservers() {
        // Listen for user sign-in events
        NotificationCenter.default.publisher(for: .userDidSignIn)
            .sink { [weak self] _ in
                self?.clearCurrentUserData()
                self?.loadEntries()
            }
            .store(in: &cancellables)
        
        // Listen for user sign-out events
        NotificationCenter.default.publisher(for: .userDidSignOut)
            .sink { [weak self] _ in
                self?.clearCurrentUserData()
                self?.loadEntries()
            }
            .store(in: &cancellables)
    }
    
    // Clear current user's food data from memory
    private func clearCurrentUserData() {
        entries.removeAll()
    }
    
    // Find an entry by its ID
    func entry(withID id: UUID) -> FoodEntry? {
        return entries.first { $0.id == id }
    }
    
    // Add a new food entry
    func addEntry(foodItem: FoodItem, mealType: String, servingSize: Double, servingUnit: String, numberOfServings: Double, date: Date = Date(), selectedServingSizeOption: String? = nil) {
        // Quick Add entries should never be stacked - each is a separate entry
        let isQuickAdd = foodItem.name == "Quick Add"
        
        // Check if there's already an entry for the same food, meal type, and date
        let calendar = Calendar.current
        if !isQuickAdd, let existingEntryIndex = entries.firstIndex(where: { entry in
            // Compare food items by name and brand (since UUIDs might be different)
            let sameFood = entry.foodItem.name == foodItem.name && 
                          entry.foodItem.brandName == foodItem.brandName
            let sameMeal = entry.mealType == mealType
            let sameDate = calendar.isDate(entry.dateAdded, inSameDayAs: date)
            let sameServingUnit = entry.servingUnit == servingUnit
            
            return sameFood && sameMeal && sameDate && sameServingUnit
        }) {
            // Update existing entry by adding the new serving quantity
            let existingEntry = entries[existingEntryIndex]
            let updatedEntry = FoodEntry(
                id: existingEntry.id, // Keep the same ID
                foodItem: existingEntry.foodItem,
                mealType: existingEntry.mealType,
                servingSize: existingEntry.servingSize,
                servingUnit: existingEntry.servingUnit,
                numberOfServings: existingEntry.numberOfServings + numberOfServings,
                dateAdded: existingEntry.dateAdded
            )
            
            entries[existingEntryIndex] = updatedEntry
            print("🔄 Updated existing entry: \(foodItem.name) - New total servings: \(updatedEntry.numberOfServings)")
        } else {
            // Create new entry if no existing one found
            let newEntry = FoodEntry(
                id: UUID(),
                foodItem: foodItem,
                mealType: mealType,
                servingSize: servingSize,
                servingUnit: servingUnit,
                numberOfServings: numberOfServings,
                dateAdded: date
            )
            
            entries.append(newEntry)
            print("➕ Added new entry: \(foodItem.name) - Servings: \(numberOfServings)")
        }
        
        saveEntries()
        
        // Cache the serving information for future use
        FoodServingCacheService.shared.cacheServingInfo(
            for: foodItem,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            selectedServingSizeOption: selectedServingSizeOption
        )
        
        // Update streak when adding an entry
        updateStreakOnEntryAdded(date)
        
        // Post notification for views to update
        NotificationCenter.default.post(name: .foodLogUpdated, object: nil)
    }
    
    // Update streak when a new entry is added
    private func updateStreakOnEntryAdded(_ entryDate: Date) {
        let today = Calendar.current.startOfDay(for: Date())
        let entryDay = Calendar.current.startOfDay(for: entryDate)
        
        // Only update streak for entries added today
        guard Calendar.current.isDate(entryDay, inSameDayAs: today) else { return }
        
        if lastLoggedDate == nil {
            // First entry ever
            persistentStreak = 1
            lastLoggedDate = today
        } else {
            let lastLoggedDay = Calendar.current.startOfDay(for: lastLoggedDate!)
            let daysDifference = Calendar.current.dateComponents([.day], from: lastLoggedDay, to: today).day ?? 0
            
            if daysDifference == 0 {
                // Same day, no change to streak
                return
            } else if daysDifference == 1 {
                // Next day, increment streak
                persistentStreak += 1
                lastLoggedDate = today
            } else {
                // Gap in days, reset streak to 1
                persistentStreak = 1
                lastLoggedDate = today
            }
        }
        
        saveStreakData()
        // Streak sync disabled
        print("[FoodLogManager] Streak updated locally to \(persistentStreak)")
    }
    
    // Update an existing food entry
    func updateEntry(id: UUID, servingSize: Double, servingUnit: String, numberOfServings: Double) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            // Create updated entry with the same ID and food item but new serving info
            let updatedEntry = FoodEntry(
                id: id,
                foodItem: entries[index].foodItem,
                mealType: entries[index].mealType,
                servingSize: servingSize,
                servingUnit: servingUnit,
                numberOfServings: numberOfServings,
                dateAdded: entries[index].dateAdded
            )
            
            // Replace the old entry with the updated one
            entries[index] = updatedEntry
            saveEntries()
            
            // Post notification for views to update
            NotificationCenter.default.post(name: .foodLogUpdated, object: nil)
        }
    }
    
    // Delete a food entry
    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        saveEntries()
        
        // Post notification for views to update
        NotificationCenter.default.post(name: .foodLogUpdated, object: nil)
    }
    
    // Get entries for a specific date and meal type
    func entries(for date: Date, mealType: String) -> [FoodEntry] {
        let calendar = Calendar.current
        return entries.filter { entry in
            calendar.isDate(entry.dateAdded, inSameDayAs: date) && entry.mealType == mealType
        }
    }
    
    // Calculate total calories for a meal on a specific date
    func totalCalories(for date: Date, mealType: String) -> Int {
        let mealEntries = entries(for: date, mealType: mealType)
        return mealEntries.reduce(0) { $0 + $1.totalCalories }
    }
    
    // Calculate total calories for an entire day across all meal types
    func totalCaloriesForDay(date: Date) -> Int {
        return getDailyTotals(for: date).calories
    }
    
    func totalProteinForDay(date: Date) -> Int {
        return getDailyTotals(for: date).protein
    }
    
    // Get cached daily totals or calculate and cache them
    private func getDailyTotals(for date: Date) -> DailyTotals {
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: date).timeIntervalSince1970.description
        
        // Return cached value if available
        if let cached = dailyTotalsCache[dateKey] {
            return cached
        }
        
        // Get entries for the date and expand meals into component foods
        let dayEntries = entries.filter { calendar.isDate($0.dateAdded, inSameDayAs: date) }
        let expandedItems = expandedFoodItems(for: dayEntries)
        
        // Calculate all totals from expanded food items
        let totals = DailyTotals(
            calories: expandedItems.reduce(0) { $0 + $1.calories },
            protein: Int(expandedItems.reduce(0.0) { $0 + $1.protein }),
            carbs: Int(expandedItems.reduce(0.0) { $0 + $1.carbs }),
            fat: Int(expandedItems.reduce(0.0) { $0 + $1.fat })
        )
        
        // Cache the result
        dailyTotalsCache[dateKey] = totals
        return totals
    }
    
    // Calculate current logging streak (consecutive days with food entries)
    func calculateLoggingStreak() -> Int {
        let calendar = Calendar.current
        let today = Date()
        
        // Get all unique dates with food entries, sorted newest first
        let uniqueDates = Set(entries.map { calendar.startOfDay(for: $0.dateAdded) })
        let sortedDates = uniqueDates.sorted(by: >)
        
        guard !sortedDates.isEmpty else { return 0 }
        
        var streak = 0
        var currentDate = calendar.startOfDay(for: today)
        
        // Check if today has entries, if not, streak is 0
        if !sortedDates.contains(currentDate) {
            return 0
        }
        
        // Count consecutive days backwards from today
        for date in sortedDates {
            if calendar.isDate(date, inSameDayAs: currentDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                // If there's a gap, stop counting
                break
            }
        }
        
        return streak
    }
    
    func totalFatForDay(date: Date) -> Int {
        return getDailyTotals(for: date).fat
    }
    
    func totalCarbsForDay(date: Date) -> Int {
        return getDailyTotals(for: date).carbs
    }
    
    // Get the current logging streak as a computed property
    var currentStreak: Int {
        updateStreakIfNeeded()
        return persistentStreak
    }
    
    // Update streak based on current date and last logged date
    private func updateStreakIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        
        // If no last logged date, calculate from scratch
        guard let lastLogged = lastLoggedDate else {
            let calculatedStreak = calculateLoggingStreak()
            if calculatedStreak > 0 {
                persistentStreak = calculatedStreak
                lastLoggedDate = today
                saveStreakData()
                // Streak sync disabled
                print("[FoodLogManager] Streak updated locally to \(calculatedStreak)")
            }
            return
        }
        
        let lastLoggedDay = Calendar.current.startOfDay(for: lastLogged)
        let daysDifference = Calendar.current.dateComponents([.day], from: lastLoggedDay, to: today).day ?? 0
        
        if daysDifference == 0 {
            // Same day, no change needed
            return
        } else if daysDifference == 1 {
            // Next day - check if we have entries for today
            if hasEntriesForDate(Date()) {
                persistentStreak += 1
                lastLoggedDate = today
                saveStreakData()
                // Streak sync disabled
                print("[FoodLogManager] Streak updated locally to \(persistentStreak)")
            } else {
                // No entries today, streak might be broken
                // We'll check this when entries are added
            }
        } else if daysDifference > 1 {
            // Gap in days - streak is broken, reset to 0
            if hasEntriesForDate(Date()) {
                persistentStreak = 1
                lastLoggedDate = today
            } else {
                persistentStreak = 0
                lastLoggedDate = nil
            }
            saveStreakData()
            // Streak sync disabled
            print("[FoodLogManager] Streak updated locally to \(persistentStreak)")
        }
    }
    
    // Check if a specific date has any food entries
    private func hasEntriesForDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return entries.contains { calendar.isDate($0.dateAdded, inSameDayAs: date) }
    }
    
    /// Represents a food item with its nutrition and scores for dashboard calculations
    struct ExpandedFoodItem {
        let name: String
        let calories: Int
        let protein: Double
        let carbs: Double
        let fat: Double
        let novaScore: Int
        let novaScoreIsEstimated: Bool
        let nutriScoreGrade: String?
        let nutriScoreIsEstimated: Bool
    }
    
    /// Expands food entries into individual food items, expanding meals into their component foods
    /// This should be used for dashboard calculations (NOVA, Nutri-Score, Gut Health) to get accurate per-food data
    func expandedFoodItems(for entries: [FoodEntry]) -> [ExpandedFoodItem] {
        var expandedItems: [ExpandedFoodItem] = []
        
        for entry in entries {
            // Check if this entry is a meal (using the isMeal flag on FoodItem)
            if entry.foodItem.isMeal, let savedMeal = SavedMealsManager.shared.meals.first(where: { $0.name == entry.foodItem.name }) {
                // Expand meal into component foods
                for mealFood in savedMeal.foods {
                    // Scale nutrition by number of servings
                    let scaledCalories = Int(Double(mealFood.calories) * entry.numberOfServings)
                    let scaledProtein = mealFood.protein * entry.numberOfServings
                    let scaledCarbs = mealFood.carbs * entry.numberOfServings
                    let scaledFat = mealFood.fat * entry.numberOfServings
                    
                    expandedItems.append(ExpandedFoodItem(
                        name: mealFood.foodName,
                        calories: scaledCalories,
                        protein: scaledProtein,
                        carbs: scaledCarbs,
                        fat: scaledFat,
                        novaScore: mealFood.novaScore,
                        novaScoreIsEstimated: mealFood.novaScoreIsEstimated,
                        nutriScoreGrade: mealFood.nutriScoreGrade,
                        nutriScoreIsEstimated: mealFood.nutriScoreIsEstimated
                    ))
                }
            } else {
                // Regular food item - add directly
                expandedItems.append(ExpandedFoodItem(
                    name: entry.foodItem.name,
                    calories: entry.totalCalories,
                    protein: entry.totalProtein,
                    carbs: entry.totalCarbs,
                    fat: entry.totalFat,
                    novaScore: entry.foodItem.novaScore,
                    novaScoreIsEstimated: entry.foodItem.novaScoreIsEstimated,
                    nutriScoreGrade: entry.foodItem.nutriScoreGrade,
                    nutriScoreIsEstimated: entry.foodItem.nutriScoreIsEstimated
                ))
            }
        }
        
        return expandedItems
    }
    
    // Load streak data from UserDefaults
    private func loadStreakData() {
        persistentStreak = UserDefaults.standard.integer(forKey: streakKey)
        
        if let savedDate = UserDefaults.standard.object(forKey: lastLoggedDateKey) as? Date {
            lastLoggedDate = savedDate
        }
    }
    
    // Save streak data to UserDefaults
    private func saveStreakData() {
        UserDefaults.standard.set(persistentStreak, forKey: streakKey)
        
        if let lastLogged = lastLoggedDate {
            UserDefaults.standard.set(lastLogged, forKey: lastLoggedDateKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastLoggedDateKey)
        }
    }
    
    // Clear all food data for the current user
    func clearAllData() {
        entries.removeAll()
        UserDefaults.standard.removeObject(forKey: foodEntriesKey)
        
        // Post notification for views to update
        NotificationCenter.default.post(name: .foodLogUpdated, object: nil)
    }
    
    // Save entries to UserDefaults
    private func saveEntries() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: foodEntriesKey)
        }
    }
    
    // Load entries from UserDefaults
    private func loadEntries() {
        if let savedEntries = UserDefaults.standard.data(forKey: foodEntriesKey),
           let decodedEntries = try? JSONDecoder().decode([FoodEntry].self, from: savedEntries) {
            entries = decodedEntries
        }
    }
}

// Notification name extension
extension Notification.Name {
    static let foodLogUpdated = Notification.Name("foodLogUpdated")
    static let navigateToFoodLog = Notification.Name("navigateToFoodLog")
    static let exitEditMode = Notification.Name("exitEditMode")
}
