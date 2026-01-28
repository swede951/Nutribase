//
//  StepsCardView.swift
//  nutribase
//
//  Created by Cascade on 2025-07-25.
//

import SwiftUI

struct StepsCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    var isPreview: Bool = false
    
    @ObservedObject private var activityManager = ActivityManager.shared
    @ObservedObject private var healthKitManager = HealthKitManager.shared
    @AppStorage("stepsCardViewMode") private var viewMode: ViewMode = .weekly
    @State private var isLoading = false
    @State private var last7DaysSteps: [DaySteps] = []
    @State private var showingMenu = false
    @State private var showingDetailView = false
    
    private static let previewDaysSteps: [DaySteps] = [
        DaySteps(date: Date(), steps: 6500, dayLetter: "S"),
        DaySteps(date: Date(), steps: 8200, dayLetter: "S"),
        DaySteps(date: Date(), steps: 12000, dayLetter: "M"),
        DaySteps(date: Date(), steps: 7500, dayLetter: "T"),
        DaySteps(date: Date(), steps: 9800, dayLetter: "W"),
        DaySteps(date: Date(), steps: 11200, dayLetter: "T"),
        DaySteps(date: Date(), steps: 5400, dayLetter: "F")
    ]
    private var previewSteps: Int { 7850 }
    private var previewGoal: Int { 10000 }
    
    enum ViewMode: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
    }
    
    // Steps goal (default 10,000 steps)
    var stepsGoal: Int {
        return UserDefaults.standard.integer(forKey: "stepsGoal") > 0 ? 
               UserDefaults.standard.integer(forKey: "stepsGoal") : 10000
    }
    
    var currentSteps: Int {
        if isPreview { return previewSteps }
        return activityManager.currentActivity.steps
    }
    
    private var displayData: [DaySteps] {
        if isPreview { return Self.previewDaysSteps }
        return last7DaysSteps
    }
    
    var stepsRemaining: Int {
        return stepsGoal - currentSteps
    }
    
    var progressPercentage: Double {
        return Double(currentSteps) / Double(stepsGoal)
    }
    
    struct DaySteps: Identifiable {
        let id = UUID()
        let date: Date
        let steps: Int
        let dayLetter: String
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            FixedSizeCard(title: "Steps", onCardTap: isPreview ? nil : {
                showingDetailView = true
            }) {
            if isLoading {
                VStack(alignment: .center, spacing: 4) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Loading...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewMode == .daily {
                // Daily view - similar to macro cards
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(formatSteps(currentSteps))
                            .font(.system(size: 32, weight: .bold))
                        
                        ProgressView(value: progressPercentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#35b8ff")))
                        
                        Text(stepsRemaining > 0 ? 
                             "\(formatSteps(stepsRemaining)) remaining" : 
                             "Goal achieved!")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(stepsRemaining > 0 ? .secondary : .green)
                    }
                    
                    Spacer()
                }
            } else {
                // Weekly view - 7-day bar chart
                VStack(alignment: .center, spacing: 8) {
                    Spacer()
                    
                    // Custom bar chart with grey backgrounds and target line
                    let barHeight: CGFloat = 40
                    let maxRatio: CGFloat = 1.2 // 120% of target
                    // Target line position: at 100% (target), which is 1/1.2 = 83.3% of max height
                    let targetLineOffset = barHeight * (1.0 - 1.0 / maxRatio)
                    
                    ZStack(alignment: .top) {
                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(displayData) { dayData in
                                VStack(spacing: 4) {
                                    // Grey background bar (full height)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 12, height: barHeight)
                                        .overlay(
                                            GeometryReader { geometry in
                                                VStack(spacing: 0) {
                                                    Spacer(minLength: 0)
                                                    
                                                    // Colored fill from bottom
                                                    let progress = CGFloat(dayData.steps) / CGFloat(stepsGoal) / maxRatio
                                                    if progress > 0 {
                                                        RoundedRectangle(cornerRadius: 2)
                                                            .fill(Color(hex: "#35b8ff"))
                                                            .frame(width: 12, height: min(geometry.size.height * progress, geometry.size.height))
                                                    }
                                                }
                                            }
                                        )
                                    
                                    // Day letter
                                    Text(dayData.dayLetter)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Target line at correct position (100% of target = 83.3% up from bottom)
                        Rectangle()
                            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                            .frame(height: 2)
                            .offset(y: targetLineOffset)
                    }
                    
                    // Daily tracker
                    Text("\(formatSteps(currentSteps)) / \(formatSteps(stepsGoal))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 12)
                }
            }
        }
        .onAppear {
            if !isPreview { refreshData() }
        }
        // Listen for date changes
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            if !isPreview { refreshData() }
        }
        .sheet(isPresented: $showingDetailView) {
            StepsDetailView(activityManager: activityManager, healthKitManager: healthKitManager)
        }
            
            if !isPreview {
                // Menu button overlay in top right
                Menu {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Button(mode.rawValue) {
                            viewMode = mode
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
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
        
        // Fetch last 7 days of steps
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var daysData: [DaySteps] = []
        let group = DispatchGroup()
        
        for dayOffset in (0..<7).reversed() {
            group.enter()
            if let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                
                healthKitManager.fetchStepsForDateRange(start: dayStart, end: dayEnd) { steps, error in
                    let dayLetter = self.getDayLetter(for: dayStart)
                    let daySteps = DaySteps(date: dayStart, steps: steps, dayLetter: dayLetter)
                    daysData.append(daySteps)
                    group.leave()
                }
            } else {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.last7DaysSteps = daysData.sorted { $0.date < $1.date }
            self.isLoading = false
        }
    }
    
    private func getDayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        let dayName = formatter.string(from: date)
        return String(dayName.prefix(1))
    }
}

#Preview {
    StepsCardView()
        .cardStyle()
        .frame(width: 200, height: 120)
}
