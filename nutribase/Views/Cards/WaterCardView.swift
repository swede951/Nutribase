//
//  WaterCardView.swift
//  nutribase
//
//  Created on 16/07/2025.
//

import SwiftUI
import Combine

struct WaterCardView: View {
    // Use UserProfile to get the user's water target
    @ObservedObject private var userProfile = UserProfile.shared
    
    // State to track the selected date (defaults to today)
    @State private var selectedDate = Date()
    
    // State for water intake (would normally come from a WaterManager)
    @AppStorage("dailyWaterIntake") private var dailyWaterIntake: Double = 0.0
    
    // Computed property for water target in liters
    var waterTarget: Double {
        return userProfile.waterGoalLiters > 0 ? userProfile.waterGoalLiters : 2.0
    }
    
    var waterRemaining: Double {
        return waterTarget - dailyWaterIntake
    }
    
    var progressPercentage: Double {
        return dailyWaterIntake / waterTarget
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with standardized top spacing
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.blue)
                Text("Water")
                    .font(.custom("Montserrat-SemiBold", size: 17))
                Spacer()
            }
            .padding(.bottom, 4)
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(format: "%.1fL", dailyWaterIntake))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("/ \(String(format: "%.1fL", waterTarget))")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: progressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                
                Text(waterRemaining > 0 ? 
                     "\(String(format: "%.1fL", waterRemaining)) remaining" : 
                     "Goal exceeded by \(String(format: "%.1fL", abs(waterRemaining)))L")
                    .font(.caption)
                    .foregroundColor(waterRemaining > 0 ? .secondary : .green)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(height: 120)
        .onTapGesture {
            // This would navigate to water tracking view in a real app
            // For now, just increment water intake for demo purposes
            withAnimation {
                dailyWaterIntake += 0.25
                if dailyWaterIntake > 5.0 {
                    dailyWaterIntake = 0.0
                }
            }
        }
        // Reset water intake at midnight
        .onAppear {
            checkAndResetWaterIntake()
        }
    }
    
    // Function to check if we need to reset the water intake (new day)
    private func checkAndResetWaterIntake() {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        
        let lastResetDateKey = "lastWaterResetDate"
        let today = calendar.startOfDay(for: Date())
        
        if let lastResetDateData = defaults.object(forKey: lastResetDateKey) as? Data,
           let lastResetDate = try? JSONDecoder().decode(Date.self, from: lastResetDateData) {
            
            // If last reset was not today, reset the counter
            if !calendar.isDate(lastResetDate, inSameDayAs: today) {
                dailyWaterIntake = 0.0
                saveLastResetDate(today)
            }
        } else {
            // First time using the app, save today as reset date
            saveLastResetDate(today)
        }
    }
    
    private func saveLastResetDate(_ date: Date) {
        if let encoded = try? JSONEncoder().encode(date) {
            UserDefaults.standard.set(encoded, forKey: "lastWaterResetDate")
        }
    }
}

#Preview {
    WaterCardView()
        .frame(width: 180, height: 120)
        .padding()
}
