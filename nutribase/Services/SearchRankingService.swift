//
//  SearchRankingService.swift
//  nutribase
//
//  Created on 16/07/2025.
//

import Foundation

/// Service for improving search results by ranking them based on user context and preferences
class SearchRankingService {
    static let shared = SearchRankingService()
    
    // Keys for storing data in UserDefaults
    private let foodSelectionFrequencyKey = "foodSelectionFrequency"
    private let mealTypePreferencesKey = "mealTypePreferences"
    
    // Track how often each food is selected
    private var foodSelectionFrequency: [String: Int] = [:]
    
    // Track which foods are commonly selected for specific meal types
    private var mealTypePreferences: [String: [String: Int]] = [:]
    
    init() {
        loadData()
    }
    
    // Load saved data from UserDefaults
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: foodSelectionFrequencyKey),
           let frequency = try? JSONDecoder().decode([String: Int].self, from: data) {
            foodSelectionFrequency = frequency
        }
        
        if let data = UserDefaults.standard.data(forKey: mealTypePreferencesKey),
           let preferences = try? JSONDecoder().decode([String: [String: Int]].self, from: data) {
            mealTypePreferences = preferences
        }
    }
    
    // Save data to UserDefaults
    private func saveData() {
        if let data = try? JSONEncoder().encode(foodSelectionFrequency) {
            UserDefaults.standard.set(data, forKey: foodSelectionFrequencyKey)
        }
        
        if let data = try? JSONEncoder().encode(mealTypePreferences) {
            UserDefaults.standard.set(data, forKey: mealTypePreferencesKey)
        }
    }
    
    // Record when a user selects a food item for a specific meal type
    func recordFoodSelection(foodId: String, foodName: String, mealType: String) {
        // Update general food selection frequency
        let currentCount = foodSelectionFrequency[foodId] ?? 0
        foodSelectionFrequency[foodId] = currentCount + 1
        
        // Update meal type specific preferences
        var mealPreferences = mealTypePreferences[mealType] ?? [:]
        let currentMealCount = mealPreferences[foodId] ?? 0
        mealPreferences[foodId] = currentMealCount + 1
        mealTypePreferences[mealType] = mealPreferences
        
        // Save the updated data
        saveData()
    }
    
    // Rank search results based on user preferences, context, and nutritional completeness
    func rankSearchResults(foods: [FoodItem], mealType: String) -> [FoodItem] {
        // Create a copy of the foods array that we can sort
        var rankedFoods = foods
        
        // Sort the foods based on a combined ranking score
        rankedFoods.sort { food1, food2 in
            // User preference score
            let preferenceScore1 = calculateRelevanceScore(for: food1.id.uuidString, mealType: mealType)
            let preferenceScore2 = calculateRelevanceScore(for: food2.id.uuidString, mealType: mealType)
            
            // Nutritional completeness score
            let nutritionalScore1 = calculateNutritionalCompletenessScore(for: food1)
            let nutritionalScore2 = calculateNutritionalCompletenessScore(for: food2)
            
            // Combined score with nutritional completeness weighted at 40% of the total score
            // This gives significant weight to foods with more complete nutritional information
            let totalScore1 = (preferenceScore1 * 0.6) + (nutritionalScore1 * 0.4)
            let totalScore2 = (preferenceScore2 * 0.6) + (nutritionalScore2 * 0.4)
            
            return totalScore1 > totalScore2
        }
        
        return rankedFoods
    }
    
    // Calculate a relevance score for a food item based on user history, context, and nutritional completeness
    private func calculateRelevanceScore(for foodId: String, mealType: String) -> Double {
        var score: Double = 0
        
        // Factor 1: How often the user has selected this food overall
        let selectionFrequency = Double(foodSelectionFrequency[foodId] ?? 0)
        score += selectionFrequency * 0.5
        
        // Factor 2: How often the user has selected this food for this specific meal type
        let mealSpecificFrequency = Double(mealTypePreferences[mealType]?[foodId] ?? 0)
        score += mealSpecificFrequency * 1.0
        
        return score
    }
    
    // Calculate a nutritional completeness score for a food item
    // This evaluates how much nutritional information is available for the food
    func calculateNutritionalCompletenessScore(for food: FoodItem) -> Double {
        var score: Double = 0
        
        // Base nutritional data (always required)
        // These are required fields so we don't need to check if they exist
        
        // Additional nutritional data (optional)
        if food.nutriScoreGrade != nil { score += 1.0 }
        if food.novaScore > 0 { score += 1.0 }
        if food.servingSize != nil { score += 0.5 }
        if food.servingsPerPackage != nil { score += 0.5 }
        if food.servingType != nil { score += 0.5 }
        if food.brandName != nil { score += 0.3 }
        if food.barcode != nil { score += 0.2 }
        
        return score
    }
    
    // Rank food items by nutritional completeness only
    func rankByNutritionalCompleteness(foods: [FoodItem]) -> [FoodItem] {
        // Create a copy of the foods array that we can sort
        var rankedFoods = foods
        
        // Sort the foods based on nutritional completeness score
        rankedFoods.sort { food1, food2 in
            let score1 = calculateNutritionalCompletenessScore(for: food1)
            let score2 = calculateNutritionalCompletenessScore(for: food2)
            return score1 > score2
        }
        
        return rankedFoods
    }
    
    // Reset all user preference data
    func resetUserPreferences() {
        foodSelectionFrequency.removeAll()
        mealTypePreferences.removeAll()
        saveData()
    }
}
