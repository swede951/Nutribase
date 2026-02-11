//  FatCardView.swift
//  nutribase
//
//  Created on 17/06/2025.
//

import SwiftUI
import Combine

struct FatCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    var isPreview: Bool = false
    
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    @ObservedObject private var userProfile = UserProfile.shared
    
    @State private var selectedDate = Date()
    @AppStorage("fatCardViewMode") private var viewMode: ViewMode = .daily
    @State private var last7DaysData: [DayData] = []
    @State private var showingDetailView = false
    
    private static let previewDaysData: [DayData] = [
        DayData(date: Date(), consumed: 35, dayLetter: "S"),
        DayData(date: Date(), consumed: 55, dayLetter: "S"),
        DayData(date: Date(), consumed: 70, dayLetter: "M"),
        DayData(date: Date(), consumed: 45, dayLetter: "T"),
        DayData(date: Date(), consumed: 60, dayLetter: "W"),
        DayData(date: Date(), consumed: 50, dayLetter: "T"),
        DayData(date: Date(), consumed: 40, dayLetter: "F")
    ]
    private var previewFatTarget: Int { 70 }
    private var previewFatConsumed: Int { 45 }
    
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
    
    // Computed property for fat target in grams
    var fatTarget: Int {
        if isPreview { return previewFatTarget }
        return userProfile.fatGoalGrams > 0 ? userProfile.fatGoalGrams : 70
    }
    
    // Calculate fat consumed from food log - now uses shared cache
    var fatConsumed: Int {
        if isPreview { return previewFatConsumed }
        return Int(DailyNutritionCache.shared.getDaySummary(for: selectedDate).fat)
    }
    
    private var displayData: [DayData] {
        if isPreview { return Self.previewDaysData }
        return last7DaysData
    }
    
    var fatRemaining: Int {
        return fatTarget - fatConsumed
    }
    
    var progressPercentage: Double {
        return Double(fatConsumed) / Double(fatTarget)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            FixedSizeCard(title: "Fat", onCardTap: isPreview ? nil : {
                showingDetailView = true
            }) {
                if viewMode == .daily {
                    VStack(spacing: 0) {
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(fatConsumed)g")
                                    .font(.system(size: 28, weight: .bold))
                                
                                Text("/ \(fatTarget)g")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.accessibleSecondary)
                            }
                            
                            ProgressView(value: progressPercentage)
                                .progressViewStyle(LinearProgressViewStyle(tint: CardType.fat.color))
                            
                            Text("\(fatRemaining > 0 ? "\(fatRemaining)g remaining" : "Goal exceeded by \(abs(fatRemaining))g")")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(fatRemaining > 0 ? .secondary : .orange)
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
                                            .fill(Color.appInsetBackground)
                                            .frame(width: 12, height: barHeight)
                                            .overlay(
                                                GeometryReader { geometry in
                                                    VStack(spacing: 0) {
                                                        Spacer(minLength: 0)
                                                        
                                                        // Colored fill from bottom
                                                        let progress = CGFloat(dayData.consumed) / CGFloat(fatTarget) / maxRatio
                                                        if progress > 0 {
                                                            RoundedRectangle(cornerRadius: 2)
                                                                .fill(CardType.fat.color)
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
                        
                        Text("\(fatConsumed)g / \(fatTarget)g")
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
                FatDetailView(foodLogManager: foodLogManager, userProfile: userProfile)
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
        
        for dayOffset in (0..<7).reversed() {
            if let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let dayLetter = getDayLetter(for: dayStart)
                let consumed = foodLogManager.totalFatForDay(date: dayStart)
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
