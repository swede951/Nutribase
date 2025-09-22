//
//  StepsCardView.swift
//  nutribase
//
//  Created by Cascade on 2025-07-25.
//

import SwiftUI

struct StepsCardView: View {
    @ObservedObject private var activityManager = ActivityManager.shared
    @State private var isLoading = false
    
    // State to track the selected date (defaults to today)
    @State private var selectedDate = Date()
    
    var body: some View {
        ZStack {
            // Background container that takes full card space
            VStack(alignment: .leading, spacing: 0) {
                // Header with standardized top spacing
                HStack {
                    Text("Steps")
                        .font(.custom("Montserrat-SemiBold", size: 17))
                    Spacer()
                }
                .padding(.bottom, 4)
                
                // Invisible spacer to maintain card structure
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
            
            // Centered content overlay for full card height
            VStack {
                if isLoading {
                    VStack(alignment: .center, spacing: 4) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(formatSteps(activityManager.currentActivity.steps))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            refreshData()
        }
        // Listen for date changes
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            // Reset to today's data when the day changes
            self.selectedDate = Date()
            refreshData()
        }
    }
    
    private func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }
    
    private func refreshData() {
        isLoading = true
        activityManager.refreshActivityData()
        
        // Set a timeout to prevent indefinite loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
        }
    }
}

#Preview {
    StepsCardView()
        .cardStyle()
        .frame(width: 200, height: 120)
}
