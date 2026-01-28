//
//  CurrentWeightCardView.swift
//  nutribase
//
//  Created on 03/06/2025.
//

import SwiftUI

struct CurrentWeightCardView: View {
    var isPreview: Bool = false
    var customPreviewWeight: Double? = nil  // Optional custom weight for onboarding
    
    // Use WeightLogManager to access weight data
    @ObservedObject private var weightLogManager = WeightLogManager.shared
    
    // Preview data - use custom weight if provided, otherwise default
    private var previewWeight: Double { customPreviewWeight ?? 85.0 }
    private var previewWeeklyRate: Double { 0.0 }  // No rate yet for new users
    
    // Computed property to get the most recent weight entry by date
    private var mostRecentEntry: WeightLogEntry? {
        if isPreview { return nil }
        return weightLogManager.weightEntries.max(by: { $0.date < $1.date })
    }
    
    // Get the latest moving average value
    private var latestMovingAverage: Double? {
        return mostRecentEntry?.movingAverage
    }
    
    // Computed property to get the previous week's weight entry
    private var previousWeekEntry: WeightLogEntry? {
        guard let mostRecent = mostRecentEntry else { return nil }
        
        // Look for an entry approximately 7 days before the most recent one
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: mostRecent.date) ?? Date()
        
        // Find the entry closest to one week ago
        return weightLogManager.weightEntries.first { entry in
            entry.date <= oneWeekAgo
        }
    }
    
    // Calculate weight difference between current and previous week moving averages
    private var weightDifference: Double {
        guard let current = mostRecentEntry?.movingAverage,
              let previous = previousWeekEntry?.movingAverage else {
            return 0.0
        }
        return current - previous
    }
    
    var body: some View {
        FixedSizeCard(title: "Weight") {
            VStack(alignment: .leading, spacing: 8) {
                if isPreview {
                    // Preview mode with static data
                    Text("\(String(format: "%.1f", previewWeight)) kg")
                        .font(.system(size: 28, weight: .bold))
                    
                    if previewWeeklyRate != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .foregroundColor(Color(hex: "#5ec5ff"))
                                .font(.caption)
                            
                            Text("\(String(format: "%.1f", previewWeeklyRate)) kg")
                                .foregroundColor(Color(hex: "#5ec5ff"))
                                .font(.caption)
                            
                            Text("Weekly Rate")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.accessibleSecondary)
                        }
                    } else {
                        Text("Your starting weight")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.accessibleSecondary)
                    }
                } else if let currentEntry = mostRecentEntry, let movingAvg = latestMovingAverage {
                    // Display moving average weight with consistent typography
                    Text("\(String(format: "%.1f", movingAvg)) kg")
                        .font(.system(size: 28, weight: .bold))
                    
                    // Display weekly rate if available
                    if let weeklyRate = currentEntry.weeklyRate {
                        HStack(spacing: 4) {
                            Image(systemName: weeklyRate < 0 ? "arrow.down" : "arrow.up")
                                .foregroundColor(Color(hex: "#5ec5ff"))
                                .font(.caption)
                            
                            Text("\(String(format: "%.1f", abs(weeklyRate))) kg")
                                .foregroundColor(Color(hex: "#5ec5ff"))
                                .font(.caption)
                            
                            Text("Weekly Rate")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.accessibleSecondary)
                        }
                    }
                } else {
                    // No weight entries yet
                    Text("No data")
                        .font(.custom("Montserrat-Bold", size: 28))
                        .foregroundColor(.secondary)
                    
                    Text("Add a weight entry")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    CurrentWeightCardView()
        .frame(width: 180, height: 120)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
}
