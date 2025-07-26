//
//  CurrentWeightCardView.swift
//  nutribase
//
//  Created on 03/06/2025.
//

import SwiftUI

struct CurrentWeightCardView: View {
    // Use WeightLogManager to access weight data
    @ObservedObject private var weightLogManager = WeightLogManager.shared
    
    // Computed property to get the most recent weight entry
    private var mostRecentEntry: WeightLogEntry? {
        return weightLogManager.weightEntries.first
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
    
    // Calculate weight difference between current and previous week
    private var weightDifference: Double {
        guard let current = mostRecentEntry?.weight,
              let previous = previousWeekEntry?.weight else {
            return 0.0
        }
        return current - previous
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with standardized top spacing
            HStack {
                Text("Weight")
                    .font(.custom("Montserrat-Bold", size: 17))
                Spacer()
            }
            .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 8) {
                // Weight information
                if let currentEntry = mostRecentEntry {
                    // Display current weight
                    Text("\(String(format: "%.1f", currentEntry.weight)) kg")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Display weight change if we have a previous entry
                    if let _ = previousWeekEntry, weightDifference != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: weightDifference < 0 ? "arrow.down" : "arrow.up")
                                .foregroundColor(weightDifference < 0 ? .green : .red)
                            
                            Text("\(String(format: "%.1f", abs(weightDifference))) kg")
                                .foregroundColor(weightDifference < 0 ? .green : .red)
                                .font(.caption)
                            
                            Text("from last week")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("No previous data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // No weight entries yet
                    Text("No data")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text("Add a weight entry")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(height: 120)
    }
}

#Preview {
    CurrentWeightCardView()
        .frame(width: 180, height: 120)
        .padding()
}
