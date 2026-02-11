//  ProteinCardView.swift
//  nutribase
//
//  Created on 17/06/2025.
//

import SwiftUI
import Combine

struct ProteinCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    // Preview mode - uses static data, no interactions
    var isPreview: Bool = false
    
    // Use FoodLogManager to get real protein data
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    
    // Use UserProfile to get the user's protein target
    @ObservedObject private var userProfile = UserProfile.shared
    
    // State to track the selected date (defaults to today)
    @State private var selectedDate = Date()
    @AppStorage("proteinCardViewMode") private var viewMode: ViewMode = .daily
    @State private var showingMenu = false
    @State private var last7DaysData: [DayData] = []
    @State private var showingDetailView = false
    
    // Static preview data for Widget Gallery
    private static let previewDaysData: [DayData] = [
        DayData(date: Date(), consumed: 30, dayLetter: "S"),
        DayData(date: Date(), consumed: 45, dayLetter: "S"),
        DayData(date: Date(), consumed: 55, dayLetter: "M"),
        DayData(date: Date(), consumed: 40, dayLetter: "T"),
        DayData(date: Date(), consumed: 60, dayLetter: "W"),
        DayData(date: Date(), consumed: 50, dayLetter: "T"),
        DayData(date: Date(), consumed: 35, dayLetter: "F")
    ]
    private var previewProteinTarget: Int { 120 }
    private var previewProteinConsumed: Int { 75 }
    
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
    
    // Computed property for protein target in grams
    var proteinTarget: Int {
        if isPreview { return previewProteinTarget }
        return userProfile.proteinGoalGrams > 0 ? userProfile.proteinGoalGrams : 50
    }
    
    // Calculate protein consumed from food log - now uses shared cache
    var proteinConsumed: Int {
        if isPreview { return previewProteinConsumed }
        return Int(DailyNutritionCache.shared.getDaySummary(for: selectedDate).protein)
    }
    
    // Data for weekly view
    private var displayData: [DayData] {
        if isPreview { return Self.previewDaysData }
        return last7DaysData
    }
    
    var proteinRemaining: Int {
        return proteinTarget - proteinConsumed
    }
    
    var progressPercentage: Double {
        return Double(proteinConsumed) / Double(proteinTarget)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            FixedSizeCard(title: "Protein", onCardTap: isPreview ? nil : {
                showingDetailView = true
            }) {
                if viewMode == .daily {
                    // Daily view
                    VStack(spacing: 0) {
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(proteinConsumed)g")
                                    .font(.system(size: 28, weight: .bold))
                                
                                Text("/ \(proteinTarget)g")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.accessibleSecondary)
                            }
                            
                            ProgressView(value: progressPercentage)
                                .progressViewStyle(LinearProgressViewStyle(tint: CardType.protein.color))
                                .animation(.easeInOut(duration: 0.8), value: progressPercentage)
                            
                            Text("\(proteinRemaining > 0 ? "\(proteinRemaining)g remaining" : "Goal exceeded by \(abs(proteinRemaining))g")")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(proteinRemaining > 0 ? .secondary : .orange)
                        }
                        
                        Spacer()
                    }
                } else {
                    // Weekly view
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
                                            .fill(Color.appInsetBackground)
                                            .frame(width: 12, height: barHeight)
                                            .overlay(
                                                GeometryReader { geometry in
                                                    VStack(spacing: 0) {
                                                        Spacer(minLength: 0)
                                                        
                                                        // Purple fill from bottom
                                                        let progress = CGFloat(dayData.consumed) / CGFloat(proteinTarget) / maxRatio
                                                        if progress > 0 {
                                                            RoundedRectangle(cornerRadius: 2)
                                                                .fill(CardType.protein.color)
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
                                .fill(Color.appCardBackground)
                                .frame(height: 2)
                                .offset(y: targetLineOffset)
                        }
                        
                        Text("\(proteinConsumed)g / \(proteinTarget)g")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 12)
                    }
                }
            }
            .onAppear {
                if !isPreview { load7DaysData() }
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
                ProteinDetailView(foodLogManager: foodLogManager, userProfile: userProfile)
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
                        .padding(.bottom, 16)
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
                let consumed = Int(DailyNutritionCache.shared.getDaySummary(for: dayStart).protein)
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
    
    // Calculate total protein consumed for the day
    private func calculateTotalProtein() -> Int {
        let calendar = Calendar.current
        let dayEntries = foodLogManager.entries.filter { calendar.isDate($0.dateAdded, inSameDayAs: selectedDate) }
        
        return Int(dayEntries.reduce(0.0) { total, entry in
            return total + entry.totalProtein
        })
    }
}

#Preview {
    ProteinCardView()
        .frame(width: 180, height: 120)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
}
