//  FatCardView.swift
//  nutribase
//
//  Created on 17/06/2025.
//

import SwiftUI
import Combine

struct FatCardView: View {
    // Use FoodLogManager to get real fat data
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    
    // Use UserProfile to get the user's fat target
    @ObservedObject private var userProfile = UserProfile.shared
    
    // State to track the selected date (defaults to today)
    @State private var selectedDate = Date()
    
    // Computed property for fat target in grams
    var fatTarget: Int {
        return userProfile.fatGoalGrams > 0 ? userProfile.fatGoalGrams : 70
    }
    
    // Calculate fat consumed from food log
    var fatConsumed: Int {
        return foodLogManager.totalFatForDay(date: selectedDate)
    }
    
    var fatRemaining: Int {
        return fatTarget - fatConsumed
    }
    
    var progressPercentage: Double {
        return Double(fatConsumed) / Double(fatTarget)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with standardized top spacing
            HStack {
                Text("Fat")
                    .font(.custom("Montserrat-SemiBold", size: 17))
                Spacer()
            }
            .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(fatConsumed)g")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("/ \(fatTarget)g")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: progressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: CardType.fat.color))
                
                Text("\(fatRemaining > 0 ? "\(fatRemaining)g remaining" : "Goal exceeded by \(abs(fatRemaining))g")")
                    .font(.caption)
                    .foregroundColor(fatRemaining > 0 ? .secondary : .orange)
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
            // Force view to refresh
            self.selectedDate = Date()
        }
        // Listen for nutrition goals updates
        .onReceive(NotificationCenter.default.publisher(for: .nutritionGoalsUpdated)) { _ in
            // Force view to refresh when nutrition goals change
            self.selectedDate = Date()
        }
    }
    
    // Calculate total fat consumed for the day
    private func calculateTotalFat() -> Int {
        let calendar = Calendar.current
        let dayEntries = foodLogManager.entries.filter { calendar.isDate($0.dateAdded, inSameDayAs: selectedDate) }
        
        return Int(dayEntries.reduce(0.0) { total, entry in
            return total + entry.totalFat
        })
    }
}

#Preview {
    FatCardView()
        .frame(width: 180, height: 120)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
}
