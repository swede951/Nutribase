//
//  DailyGoalsCardView.swift
//  nutribase
//
//  Dashboard card wrapper for Daily Goals
//

import SwiftUI

struct DailyGoalsCardView: View {
    var isPreview: Bool = false
    
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    @ObservedObject private var userProfile = UserProfile.shared
    
    // Preview data
    private var previewProtein: Int { 85 }
    private var previewCarbs: Int { 180 }
    private var previewFat: Int { 45 }
    private var previewCalories: Int { 1450 }
    private var previewNova4: Double { 15.0 }
    
    // Get today's meals for calculations
    private var todaysMeals: [FoodEntry] {
        if isPreview { return [] }
        let today = Calendar.current.startOfDay(for: Date())
        return foodLogManager.entries.filter { entry in
            Calendar.current.isDate(entry.dateAdded, inSameDayAs: today)
        }
    }
    
    // Get expanded food items for accurate calculations
    private var expandedFoodItems: [FoodLogManager.ExpandedFoodItem] {
        if isPreview { return [] }
        return foodLogManager.expandedFoodItems(for: todaysMeals)
    }
    
    // Calculate today's totals from expanded food items
    private var proteinConsumed: Int {
        if isPreview { return previewProtein }
        let total = expandedFoodItems.reduce(0.0) { $0 + $1.protein }
        return Int(total)
    }
    
    private var carbsConsumed: Int {
        if isPreview { return previewCarbs }
        let total = expandedFoodItems.reduce(0.0) { $0 + $1.carbs }
        return Int(total)
    }
    
    private var fatConsumed: Int {
        if isPreview { return previewFat }
        let total = expandedFoodItems.reduce(0.0) { $0 + $1.fat }
        return Int(total)
    }
    
    private var caloriesConsumed: Int {
        if isPreview { return previewCalories }
        let total = expandedFoodItems.reduce(0) { $0 + $1.calories }
        return total
    }
    
    // NOVA 4 calculation from expanded food items
    private var nova4Percentage: Double {
        if isPreview { return previewNova4 }
        let totalCals = Double(caloriesConsumed)
        guard totalCals > 0 else { return 0 }
        
        var nova4Cals = 0
        for item in expandedFoodItems {
            let novaScore = item.novaScore > 0 ? item.novaScore : NovaScoreService.shared.predictNovaScoreByName(item.name)
            if novaScore == 4 {
                nova4Cals += item.calories
            }
        }
        
        return (Double(nova4Cals) / totalCals) * 100
    }
    
    // Goals from user profile
    private var proteinGoal: Int {
        userProfile.proteinGoalGrams > 0 ? userProfile.proteinGoalGrams : 150
    }
    
    private var carbsGoal: Int {
        userProfile.carbGoalGrams > 0 ? userProfile.carbGoalGrams : 300
    }
    
    private var fatGoal: Int {
        userProfile.fatGoalGrams > 0 ? userProfile.fatGoalGrams : 65
    }
    
    private var caloriesGoal: Int {
        userProfile.dailyCalorieGoal > 0 ? userProfile.dailyCalorieGoal : 2000
    }
    
    private var nova4Goal: Double {
        20.0 // Default 20% target
    }
    
    var body: some View {
        DailyGoalsCard(
            isPreview: isPreview,
            proteinConsumed: proteinConsumed,
            proteinGoal: proteinGoal,
            selectedDate: Date(), // Always show today's data
            nova4Percentage: nova4Percentage,
            nova4Goal: nova4Goal,
            caloriesConsumed: caloriesConsumed,
            caloriesGoal: caloriesGoal,
            carbsConsumed: carbsConsumed,
            carbsGoal: carbsGoal,
            fatConsumed: fatConsumed,
            fatGoal: fatGoal
        )
    }
}

#Preview {
    DailyGoalsCardView()
        .padding()
}
