//
//  CalorieTargetCardView.swift
//  nutribase
//
//  Created on 03/06/2025.
//

import SwiftUI
import Combine
import Charts

struct CalorieTargetCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    // Preview mode - uses static data, no interactions
    var isPreview: Bool = false
    
    // Use FoodLogManager to get real calorie data
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    
    // Use UserProfile to get the user's calorie target
    @ObservedObject private var userProfile = UserProfile.shared
    
    // State to track the selected date (defaults to today)
    @State private var selectedDate = Date()
    @AppStorage("calorieCardViewMode") private var viewMode: ViewMode = .daily
    @State private var last7DaysData: [DayData] = []
    @State private var showingDetailView = false
    
    // Static preview data for Widget Gallery
    private static let previewDaysData: [DayData] = [
        DayData(date: Date(), consumed: 1200, dayLetter: "S"),
        DayData(date: Date(), consumed: 1800, dayLetter: "S"),
        DayData(date: Date(), consumed: 2100, dayLetter: "M"),
        DayData(date: Date(), consumed: 1500, dayLetter: "T"),
        DayData(date: Date(), consumed: 2200, dayLetter: "W"),
        DayData(date: Date(), consumed: 1900, dayLetter: "T"),
        DayData(date: Date(), consumed: 1600, dayLetter: "F")
    ]
    
    // Preview computed properties
    private var previewCalorieTarget: Int { 2000 }
    private var previewCaloriesConsumed: Int { 1450 }
    
    enum ViewMode: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
    }
    
    struct DayData: Identifiable {
        let id = UUID()
        let date: Date
        let consumed: Int
        let dayLetter: String
    }
    
    // Computed property for calorie target
    var calorieTarget: Int {
        if isPreview { return previewCalorieTarget }
        return userProfile.dailyCalorieGoal > 0 ? userProfile.dailyCalorieGoal : 2000
    }
    
    // Calculate calories consumed from food log - now uses shared cache
    var caloriesConsumed: Int {
        if isPreview { return previewCaloriesConsumed }
        // Use DailyNutritionCache for faster access
        return DailyNutritionCache.shared.getDaySummary(for: selectedDate).calories
    }
    
    var caloriesRemaining: Int {
        return calorieTarget - caloriesConsumed
    }
    
    var progressPercentage: Double {
        return Double(caloriesConsumed) / Double(calorieTarget)
    }
    
    // Data for weekly view
    private var displayData: [DayData] {
        if isPreview { return Self.previewDaysData }
        return last7DaysData
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            FixedSizeCard(title: "Calories", onCardTap: isPreview ? nil : {
                showingDetailView = true
            }) {
                if viewMode == .daily {
                    VStack(spacing: 0) {
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(caloriesConsumed)")
                                    .font(.system(size: 28, weight: .bold))
                                
                                Text("/ \(calorieTarget)")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.accessibleSecondary)
                            }
                            
                            ProgressView(value: progressPercentage)
                                .progressViewStyle(LinearProgressViewStyle(tint: progressPercentage > 1.0 ? .red : Color(red: 0.6, green: 0.2, blue: 0.8)))
                                .animation(.easeInOut(duration: 0.8), value: progressPercentage)
                            
                            Text("\(caloriesRemaining > 0 ? "\(caloriesRemaining) remaining" : "Goal exceeded by \(abs(caloriesRemaining))")")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(caloriesRemaining > 0 ? .secondary : .red)
                        }
                        
                        Spacer()
                    }
                } else {
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
                                                        
                                                        // Purple fill from bottom
                                                        let progress = CGFloat(dayData.consumed) / CGFloat(calorieTarget) / maxRatio
                                                        if progress > 0 {
                                                            RoundedRectangle(cornerRadius: 2)
                                                                .fill(Color(red: 0.6, green: 0.2, blue: 0.8))
                                                                .frame(width: 12, height: min(geometry.size.height * progress, geometry.size.height))
                                                        }
                                                    }
                                                }
                                            )
                                        
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
                        
                        Text("\(caloriesConsumed) / \(calorieTarget)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 12)
                    }
                }
            }
            .onAppear {
                if !isPreview {
                    load7DaysData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .foodLogUpdated)) { _ in
                if !isPreview {
                    self.selectedDate = Date()
                    load7DaysData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .nutritionGoalsUpdated)) { _ in
                if !isPreview {
                    self.selectedDate = Date()
                    load7DaysData()
                }
            }
            .sheet(isPresented: $showingDetailView) {
                CaloriesDetailView(foodLogManager: foodLogManager, userProfile: userProfile)
            }
            
            if !isPreview {
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
    
    private func load7DaysData() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var daysData: [DayData] = []
        
        // Use DailyNutritionCache for faster access
        for dayOffset in (0..<7).reversed() {
            if let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let dayLetter = getDayLetter(for: dayStart)
                let consumed = DailyNutritionCache.shared.getDaySummary(for: dayStart).calories
                daysData.append(DayData(date: dayStart, consumed: consumed, dayLetter: dayLetter))
            }
        }
        
        last7DaysData = daysData.sorted { $0.date < $1.date }
    }
    
    private func getDayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        let dayName = formatter.string(from: date)
        return String(dayName.prefix(1))
    }
}

#Preview {
    CalorieTargetCardView()
        .frame(width: 180, height: 120)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
}
