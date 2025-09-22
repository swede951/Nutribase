//
//  CalorieTargetCardView.swift
//  nutribase
//
//  Created on 03/06/2025.
//

import SwiftUI
import Combine

struct CalorieTargetCardView: View {
    // Use FoodLogManager to get real calorie data
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    
    // Use UserProfile to get the user's calorie target
    @ObservedObject private var userProfile = UserProfile.shared
    
    // Computed property for calorie target
    var calorieTarget: Int {
        return userProfile.dailyCalorieGoal > 0 ? userProfile.dailyCalorieGoal : 2000
    }
    
    // State to track the selected date (defaults to today)
    @State private var selectedDate = Date()
    
    // Calculate calories consumed from food log
    var caloriesConsumed: Int {
        return foodLogManager.totalCaloriesForDay(date: selectedDate)
    }
    
    var caloriesRemaining: Int {
        return calorieTarget - caloriesConsumed
    }
    
    var progressPercentage: Double {
        return Double(caloriesConsumed) / Double(calorieTarget)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with standardized top spacing
            HStack {
                Text("Calorie Target")
                    .font(.custom("Montserrat-SemiBold", size: 17))
                Spacer()
            }
            .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 8) {
                // Calorie information
                HStack {
                    Text("\(caloriesConsumed)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("/ \(calorieTarget)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: progressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressPercentage > 1.0 ? .red : Color(red: 0.6, green: 0.2, blue: 0.8)))
                
                Text("\(caloriesRemaining > 0 ? "\(caloriesRemaining) remaining" : "Goal exceeded by \(abs(caloriesRemaining))")")
                    .font(.caption)
                    .foregroundColor(caloriesRemaining > 0 ? .secondary : .red)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .frame(height: 120)
        .onTapGesture {
            // Navigate to food log when tapped
            NotificationCenter.default.post(name: .navigateToFoodLog, object: nil)
        }
        // Listen for food log updates
        .onReceive(NotificationCenter.default.publisher(for: .foodLogUpdated)) { _ in
            // Force view to refresh by updating the date slightly
            // This is a workaround since structs don't have objectWillChange
            self.selectedDate = Date()
        }
        // Listen for nutrition goals updates
        .onReceive(NotificationCenter.default.publisher(for: .nutritionGoalsUpdated)) { _ in
            // Force view to refresh when nutrition goals change
            self.selectedDate = Date()
        }
    }
}

#Preview {
    CalorieTargetCardView()
        .frame(width: 180, height: 120)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
}
