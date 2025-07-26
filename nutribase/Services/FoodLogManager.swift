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
        guard let originalServingSize = foodItem.servingSize else { return false }
        
        // Check if the original serving size contains our current serving size and unit
        let originalLower = originalServingSize.lowercased()
        let currentSize = String(format: "%.1f", servingSize).replacingOccurrences(of: ".0", with: "")
        let currentUnit = servingUnit.lowercased()
        
        return originalLower.contains(currentSize) && originalLower.contains(currentUnit)
    }
    
    var totalCalories: Int {
        return NutritionCalculator.calculateCalories(
            foodCalories: foodItem.calories,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize
        )
    }
}

// Manager class for food log entries
class FoodLogManager: ObservableObject {
    static let shared = FoodLogManager()
    
    @Published var entries: [FoodEntry] = []
    
    private init() {
        // Load saved entries when initialized
        loadEntries()
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
        
        // Post notification for views to update
        NotificationCenter.default.post(name: .foodLogUpdated, object: nil)
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
    
    // Save entries to UserDefaults
    private func saveEntries() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: "foodEntries")
        }
    }
    
    // Load entries from UserDefaults
    private func loadEntries() {
        if let savedEntries = UserDefaults.standard.data(forKey: "foodEntries"),
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
