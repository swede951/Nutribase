//  ProteinCardView.swift
//  nutribase
//
//  Created on 17/06/2025.
//

import SwiftUI
import Combine

struct ProteinCardView: View {
    // Use FoodLogManager to get real protein data
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    
    // Use UserProfile to get the user's protein target
    @ObservedObject private var userProfile = UserProfile.shared
    
    // State to track the selected date (defaults to today)
    @State private var selectedDate = Date()
    
    // Computed property for protein target in grams
    var proteinTarget: Int {
        return userProfile.proteinGoalGrams > 0 ? userProfile.proteinGoalGrams : 50
    }
    
    // Calculate protein consumed from food log
    var proteinConsumed: Int {
        return calculateTotalProtein()
    }
    
    var proteinRemaining: Int {
        return proteinTarget - proteinConsumed
    }
    
    var progressPercentage: Double {
        return Double(proteinConsumed) / Double(proteinTarget)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with standardized top spacing
            HStack {
                Text("Protein")
                    .font(.custom("Montserrat-Bold", size: 17))
                Spacer()
            }
            .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(proteinConsumed)g")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("/ \(proteinTarget)g")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: progressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: CardType.protein.color))
                
                Text("\(proteinRemaining > 0 ? "\(proteinRemaining)g remaining" : "Goal exceeded by \(abs(proteinRemaining))g")")
                    .font(.caption)
                    .foregroundColor(proteinRemaining > 0 ? .secondary : .orange)
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
    
    // Calculate total protein consumed for the day
    private func calculateTotalProtein() -> Int {
        let calendar = Calendar.current
        let dayEntries = foodLogManager.entries.filter { calendar.isDate($0.dateAdded, inSameDayAs: selectedDate) }
        
        return Int(dayEntries.reduce(0.0) { total, entry in
            let baseAmount = entry.foodItem.protein * entry.numberOfServings
            let sizeRatio = entry.servingSize / 100.0
            return total + (baseAmount * sizeRatio)
        })
    }
}

#Preview {
    ProteinCardView()
        .frame(width: 180, height: 120)
        .padding()
}
