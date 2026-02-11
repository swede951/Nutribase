//  FibreCardView.swift
//  nutribase
//
//  Created on 06/02/2026.
//

import SwiftUI
import Combine

struct FibreCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    var isPreview: Bool = false
    
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    @ObservedObject private var userProfile = UserProfile.shared
    
    @State private var selectedDate = Date()
    @AppStorage("fibreCardViewMode") private var viewMode: ViewMode = .daily
    @State private var last7DaysData: [DayData] = []
    @State private var showingDetailView = false
    
    private static let previewDaysData: [DayData] = [
        DayData(date: Date(), consumed: 12, dayLetter: "S"),
        DayData(date: Date(), consumed: 18, dayLetter: "S"),
        DayData(date: Date(), consumed: 22, dayLetter: "M"),
        DayData(date: Date(), consumed: 15, dayLetter: "T"),
        DayData(date: Date(), consumed: 20, dayLetter: "W"),
        DayData(date: Date(), consumed: 17, dayLetter: "T"),
        DayData(date: Date(), consumed: 14, dayLetter: "F")
    ]
    private var previewFibreTarget: Int { 30 }
    private var previewFibreConsumed: Int { 16 }
    
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
    
    var fibreTarget: Int {
        if isPreview { return previewFibreTarget }
        return userProfile.fibreGoalGrams > 0 ? userProfile.fibreGoalGrams : 30
    }
    
    var fibreConsumed: Int {
        if isPreview { return previewFibreConsumed }
        return Int(DailyNutritionCache.shared.getDaySummary(for: selectedDate).fibre)
    }
    
    var fibreIncludesEstimates: Bool {
        if isPreview { return false }
        return DailyNutritionCache.shared.getDaySummary(for: selectedDate).fibreIncludesEstimates
    }
    
    private var fibreConsumedText: String {
        return "\(fibreConsumed)g"
    }
    
    private var displayData: [DayData] {
        if isPreview { return Self.previewDaysData }
        return last7DaysData
    }
    
    var fibreRemaining: Int {
        return fibreTarget - fibreConsumed
    }
    
    var progressPercentage: Double {
        let raw = Double(fibreConsumed) / Double(fibreTarget)
        return min(max(raw, 0), 1.0)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            FixedSizeCard(title: "Fibre", onCardTap: isPreview ? nil : {
                showingDetailView = true
            }) {
                if viewMode == .daily {
                    VStack(spacing: 0) {
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(fibreConsumedText)
                                    .font(.system(size: 28, weight: .bold))
                                
                                Text("/ \(fibreTarget)g")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.accessibleSecondary)
                            }
                            
                            ProgressView(value: progressPercentage)
                                .progressViewStyle(LinearProgressViewStyle(tint: CardType.fibre.color))
                            
                            Text("\(fibreRemaining > 0 ? "\(fibreRemaining)g remaining" : "Goal exceeded by \(abs(fibreRemaining))g")")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(fibreRemaining > 0 ? .secondary : .orange)
                        }
                        
                        Spacer()
                    }
                } else {
                    VStack(alignment: .center, spacing: 8) {
                        Spacer()
                        
                        let barHeight: CGFloat = 40
                        let maxRatio: CGFloat = 1.2
                        let targetLineOffset = barHeight * (1.0 - 1.0 / maxRatio)
                        
                        ZStack(alignment: .top) {
                            HStack(alignment: .bottom, spacing: 6) {
                                ForEach(displayData) { dayData in
                                    VStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.appInsetBackground)
                                            .frame(width: 12, height: barHeight)
                                            .overlay(
                                                GeometryReader { geometry in
                                                    VStack(spacing: 0) {
                                                        Spacer(minLength: 0)
                                                        
                                                        let progress = CGFloat(dayData.consumed) / CGFloat(fibreTarget) / maxRatio
                                                        if progress > 0 {
                                                            RoundedRectangle(cornerRadius: 2)
                                                                .fill(CardType.fibre.color)
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
                            
                            Rectangle()
                                .fill(Color.appCardBackground)
                                .frame(height: 2)
                                .offset(y: targetLineOffset)
                        }
                        
                        Text("\(fibreConsumedText) / \(fibreTarget)g")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 12)
                    }
                }
            }
            .onAppear {
                if !isPreview {
                    // Force cache refresh to ensure fibre data is current
                    DailyNutritionCache.shared.invalidateDate(selectedDate)
                    load7DaysData()
                    // Prefetch fiber estimates for foods missing fiber data
                    let calendar = Calendar.current
                    let todayEntries = foodLogManager.entries.filter { calendar.isDate($0.dateAdded, inSameDayAs: selectedDate) }
                    FiberEstimationService.shared.prefetchEstimates(for: todayEntries)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .foodLogUpdated)) { _ in
                if !isPreview {
                    DailyNutritionCache.shared.invalidateDate(Date())
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
                FibreDetailView(foodLogManager: foodLogManager, userProfile: userProfile)
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
                let consumed = foodLogManager.totalFibreForDay(date: dayStart)
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
    
    private func calculateTotalFibre() -> Int {
        let calendar = Calendar.current
        let dayEntries = foodLogManager.entries.filter { calendar.isDate($0.dateAdded, inSameDayAs: selectedDate) }
        
        return Int(dayEntries.reduce(0.0) { total, entry in
            return total + entry.totalFibre
        })
    }
}

#Preview {
    FibreCardView()
        .frame(width: 180, height: 120)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
}
