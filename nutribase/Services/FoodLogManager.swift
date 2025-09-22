import Foundation
import SwiftUI
import Combine

// Food entry model
struct FoodEntry: Identifiable, Codable {
    let id: UUID
    let foodItem: FoodItem
    let mealType: String
    let servingSize: Double
    let servingUnit: String
    let numberOfServings: Double
    let dateAdded: Date
    
    // Check if using original serving size from database
    private var isUsingOriginalServingSize: Bool {
        guard let originalServingSize = foodItem.servingSize else { 
            print("🔍 isUsingOriginalServingSize: No original serving size, returning false")
            return false 
        }
        
        // Check if the original serving size contains our current serving size and unit
        let originalLower = originalServingSize.lowercased()
        let currentSize = String(format: "%.1f", servingSize).replacingOccurrences(of: ".0", with: "")
        let currentUnit = servingUnit.lowercased()
        
        let result = originalLower.contains(currentSize) && originalLower.contains(currentUnit)
        
        print("🔍 isUsingOriginalServingSize for \(foodItem.name):")
        print("   - originalServingSize: '\(originalServingSize)' -> '\(originalLower)'")
        print("   - currentSize: \(servingSize) -> '\(currentSize)'")
        print("   - currentUnit: '\(servingUnit)' -> '\(currentUnit)'")
        print("   - contains size: \(originalLower.contains(currentSize))")
        print("   - contains unit: \(originalLower.contains(currentUnit))")
        print("   - result: \(result)")
        
        return result
    }
    
    var totalCalories: Int {
        print("🍿 totalCalories for \(foodItem.name):")
        print("   - foodCalories: \(foodItem.calories)")
        print("   - servingSize: \(servingSize)")
        print("   - servingUnit: \(servingUnit)")
        print("   - numberOfServings: \(numberOfServings)")
        print("   - isOriginalServingSize: \(isUsingOriginalServingSize)")
        print("   - servingDescription: \(foodItem.servingSize ?? "nil")")
        print("   - servingQuantity: \(foodItem.servingsPerPackage ?? 0)")
        
        let result = NutritionCalculator.calculateCalories(
            foodCalories: foodItem.calories,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize,
            servingDescription: foodItem.servingSize,
            servingQuantity: foodItem.servingsPerPackage
        )
        
        print("   - calculated result: \(result) calories")
        return result
    }
    
    var totalProtein: Double {
        print("🔍 FoodEntry.totalProtein called for \(foodItem.name)")
        print("   - foodItem.protein: \(foodItem.protein)")
        print("   - servingSize: \(servingSize)")
        print("   - servingUnit: \(servingUnit)")
        print("   - numberOfServings: \(numberOfServings)")
        print("   - isUsingOriginalServingSize: \(isUsingOriginalServingSize)")
        print("   - servingDescription: \(foodItem.servingSize ?? "nil")")
        
        let result = NutritionCalculator.calculateMacro(
            macroValue: foodItem.protein,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize,
            servingDescription: foodItem.servingSize,
            servingQuantity: foodItem.servingsPerPackage
        )
        print("FoodEntry.totalProtein: \(foodItem.name) - protein=\(foodItem.protein), result=\(result)")
        return result
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
        print("FoodEntry.totalCarbs: \(foodItem.name) - carbs=\(foodItem.carbs), result=\(result)")
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
        print("FoodEntry.totalFat: \(foodItem.name) - fat=\(foodItem.fat), result=\(result)")
        return result
    }
}

// Manager class for food log entries
class FoodLogManager: ObservableObject {
    static let shared = FoodLogManager()
    
    @Published var entries: [FoodEntry] = []
    
    // Persistent streak data
    @Published private var persistentStreak: Int = 0
    @Published private var lastLoggedDate: Date? = nil
    
    // Keys for UserDefaults storage
    private var streakKey: String {
        // Simplified - use local storage only
        print("[FoodLogManager] Using local storage for food logs")
        return "foodLogStreak_default"
    }
    
    private var lastLoggedDateKey: String {
        return "lastLoggedDate_default"
    }
    
    // Reference to the Supabase service for user authentication
    private let supabaseService = SupabaseService.shared
    
    // Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // Key for UserDefaults storage (user-specific)
    private var foodEntriesKey: String {
        return "foodEntries_default"
    }
    
    private init() {
        loadEntries()
        loadStreakData()
        
        // Subscribe to authentication changes to sync streak data
        NotificationCenter.default.publisher(for: .userDidSignIn)
            .sink { [weak self] _ in
                self?.loadStreakFromSupabase()
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
    func addEntry(foodItem: FoodItem, mealType: String, servingSize: Double, servingUnit: String, numberOfServings: Double, date: Date = Date()) {
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
        saveEntries()
        
        // Update streak when adding an entry
        updateStreakOnEntryAdded(newEntry.dateAdded)
        
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
        let calendar = Calendar.current
        let dayEntries = entries.filter { calendar.isDate($0.dateAdded, inSameDayAs: date) }
        return dayEntries.reduce(0) { $0 + $1.totalCalories }
    }
    
    func totalProteinForDay(date: Date) -> Int {
        let calendar = Calendar.current
        let dayEntries = entries.filter { calendar.isDate($0.dateAdded, inSameDayAs: date) }
        let total = dayEntries.reduce(0.0) { $0 + $1.totalProtein }
        print("FoodLogManager.totalProteinForDay: \(dayEntries.count) entries, total=\(total)")
        return Int(total)
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
        let calendar = Calendar.current
        let dayEntries = entries.filter { calendar.isDate($0.dateAdded, inSameDayAs: date) }
        let total = dayEntries.reduce(0.0) { $0 + $1.totalFat }
        print("FoodLogManager.totalFatForDay: \(dayEntries.count) entries, total=\(total)")
        return Int(total)
    }
    
    func totalCarbsForDay(date: Date) -> Int {
        let calendar = Calendar.current
        let dayEntries = entries.filter { calendar.isDate($0.dateAdded, inSameDayAs: date) }
        let total = dayEntries.reduce(0.0) { $0 + $1.totalCarbs }
        print("FoodLogManager.totalCarbsForDay: \(dayEntries.count) entries, total=\(total)")
        return Int(total)
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
    
    // Load streak data from Supabase on sign-in
    private func loadStreakFromSupabase() {
        // Streak sync disabled - use local values
        print("[FoodLogManager] Using local streak values")
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
}
