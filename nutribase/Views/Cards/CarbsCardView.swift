//  CarbsCardView.swift
//  nutribase
//
//  Created on 17/06/2025.
//

import SwiftUI
import Combine

struct CarbsCardView: View {
    // Use FoodLogManager to get real carbs data
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    
    // Use UserProfile to get the user's carbs target
    @ObservedObject private var userProfile = UserProfile.shared
    
    // State to track the selected date (defaults to today)
    @State private var selectedDate = Date()
    
    // Computed property for carbs target in grams
    var carbsTarget: Int {
        return userProfile.carbGoalGrams > 0 ? userProfile.carbGoalGrams : 250
    }
    
    // Calculate carbs consumed from food log
    var carbsConsumed: Int {
        return calculateTotalCarbs()
    }
    
    var carbsRemaining: Int {
        return carbsTarget - carbsConsumed
    }
    
    var progressPercentage: Double {
        return Double(carbsConsumed) / Double(carbsTarget)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with standardized top spacing
            HStack {
                Text("Carbs")
                    .font(.custom("Montserrat-Bold", size: 17))
                Spacer()
            }
            .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(carbsConsumed)g")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("/ \(carbsTarget)g")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: progressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: CardType.carbs.color))
                
                Text("\(carbsRemaining > 0 ? "\(carbsRemaining)g remaining" : "Goal exceeded by \(abs(carbsRemaining))g")")
                    .font(.caption)
                    .foregroundColor(carbsRemaining > 0 ? .secondary : .orange)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(height: 120)
        .onTapGesture {
            // Navigate to food log when tapped
            NotificationCenter.default.post(name: .navigateToFoodLog, object: nil)
        }
        // Listen for food log updates
        .onReceive(NotificationCenter.default.publisher(for: .foodLogUpdated)) { _ in
            // Force view to refresh
            self.selectedDate = Date()
        }
        // Listen for nutrition goals updates
        .onReceive(NotificationCenter.default.publisher(for: .nutritionGoalsUpdated)) { _ in
            // Force view to refresh when nutrition goals change
            self.selectedDate = Date()
        }
    }
    
    // Calculate total carbs consumed for the day
    private func calculateTotalCarbs() -> Int {
        let calendar = Calendar.current
        let dayEntries = foodLogManager.entries.filter { calendar.isDate($0.dateAdded, inSameDayAs: selectedDate) }
        
        return Int(dayEntries.reduce(0.0) { total, entry in
            let baseAmount = entry.foodItem.carbs * entry.numberOfServings
            let sizeRatio = entry.servingSize / 100.0
            return total + (baseAmount * sizeRatio)
        })
    }
}

#Preview {
    CarbsCardView()
        .frame(width: 180, height: 120)
        .padding()
}
