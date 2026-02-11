import SwiftUI
import UIKit // Required for CardStyle

struct NovaGroupsDetailView: View {
    @ObservedObject var foodLogManager: FoodLogManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    
    private var viewBackground: Color {
        Color.appBackground
    }
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    /// Bar empty background: provides contrast against card background
    private var barEmptyBackground: Color {
        Color.appInsetBackground
    }
    
    @State private var currentWeekOffset: Int = 0
    @State private var animationOpacity: Double = 1.0
    
    // State for tooltip display
    @State private var activeTooltipDay: String? = nil
    
    // Store positions of each day's bar for tooltip positioning
    @State private var barPositions: [CGFloat] = Array(repeating: 0, count: 7)
    
    // State to track the selected week (0 = current week, -1 = last week, etc.)
    @State private var weekOffset = 0
    
    // State for slide animation
    @State private var slideOffset: CGFloat = 0
    @State private var slideOpacity: Double = 1
    @State private var isAnimating = false
    @State private var animationDirection = 0 // -1 for left, 1 for right
    @State private var nextWeekOffset: Int? = nil // Tracks the week offset for the card being swiped in
    
    // Cache for weekly data to avoid recalculating on every swipe
    @State private var weeklyDataCache: [Int: WeeklyNovaData] = [:]
    
    // State for week selector scroll position
    @State private var scrolledWeekID: Int? = 0
    
    // Loading state for initial data computation
    @State private var isLoading: Bool = true
    
    // Struct to hold pre-computed weekly data
    struct WeeklyNovaData {
        let percentages: [Double] // Percentages for groups 1-4
        let dailyData: [String: [Double]] // Day -> [group1%, group2%, group3%, group4%]
        let hasEntries: [String: Bool] // Day -> hasEntries
    }
    
    // Colors for each NOVA group
    private let novaColors: [Color] = [
        Color(hex: "#3f993f"),      // Group 1 - Unprocessed - darker green
        Color(hex: "#b7ce0d"),      // Group 2 - Processed ingredients - lime green
        Color(hex: "#f28e16"),      // Group 3 - Processed - orange
        Color(hex: "#e4032f")       // Group 4 - Ultra-processed - bright red
    ]
    
    // Gauge colors (red to green, left to right)
    private let gaugeColors: [Color] = [
        Color(hex: "#e4032f"),      // Red (0-20)
        Color(hex: "#f28e16"),      // Orange (20-40)
        Color(hex: "#f7c700"),      // Yellow (40-60)
        Color(hex: "#b7ce0d"),      // Lime (60-80)
        Color(hex: "#3f993f")       // Green (80-100)
    ]
    
    // Names for each NOVA group
    private let novaGroupNames = [
        "Unprocessed",
        "Ingredients",
        "Processed",
        "Ultra"
    ]
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        
        NavigationView {
            ZStack {
                viewBackground
                    .ignoresSafeArea()
                
                if isLoading {
                    // Show loading indicator while data is being computed
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading NOVA data...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                        
                        // Week selector carousel at the top
                        weekSelectorCarousel
                        
                        // NOVA Score Gauge Card
                        novaScoreGaugeCard(for: currentWeekOffset)
                            .padding(.horizontal)
                        
                        // Weekly chart card (static, updates based on selected week)
                        weeklyChartCard(for: currentWeekOffset)
                            .padding(.horizontal)
                            .opacity(animationOpacity)
                        
                        // NOVA group percentages
                        VStack(alignment: .leading, spacing: 16) {
                            // Title
                            Text("NOVA Group Distribution")
                                .font(.headline)
                                .padding(.bottom, 4)
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                ForEach(0..<4, id: \.self) { index in
                                    novaGroupPercentageView(
                                        percentage: getCachedWeeklyPercentage(for: index, weekOffset: currentWeekOffset),
                                        groupName: novaGroupNames[index],
                                        color: novaColors[index]
                                    )
                                }
                            }
                        }
                        .opacity(animationOpacity)
                        .padding(.horizontal)
                        
                        // NOVA classification explanation
                        novaExplanationView
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.appBackground)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("NOVA Groups")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                // Pre-compute data for current week and adjacent weeks asynchronously
                await precomputeInitialData()
            }
        }
    }
    
    // Pre-compute data for the current week and adjacent weeks
    private func precomputeInitialData() async {
        // Check if global cache already has data (pre-warmed by card view)
        if let globalCache = ChartDataCacheManager.shared.getWeeklyNovaCache(weekOffset: 0) {
            // Convert global cache format to our local format
            let percentages = (1...4).map { globalCache.weeklyAverage[$0] ?? 0.0 }
            var dailyData: [String: [Double]] = [:]
            var hasEntries: [String: Bool] = [:]
            
            for (day, data) in globalCache.dailyData {
                let dayTotal = data.values.reduce(0, +)
                if dayTotal > 0 {
                    dailyData[day] = (1...4).map { Double(data[$0] ?? 0) / Double(dayTotal) * 100.0 }
                } else {
                    dailyData[day] = [0, 0, 0, 0]
                }
            }
            hasEntries = globalCache.hasEntries
            
            let cachedData = WeeklyNovaData(
                percentages: percentages,
                dailyData: dailyData,
                hasEntries: hasEntries
            )
            
            await MainActor.run {
                weeklyDataCache[0] = cachedData
                isLoading = false
            }
        } else {
            // Compute current week first (most important)
            let currentData = await computeWeeklyData(for: 0)
            await MainActor.run {
                weeklyDataCache[0] = currentData
                isLoading = false
            }
        }
        
        // Pre-compute adjacent weeks in background
        Task.detached(priority: .background) {
            let lastWeekData = await self.computeWeeklyData(for: -1)
            await MainActor.run {
                self.weeklyDataCache[-1] = lastWeekData
            }
        }
    }
    
    // Helper function to update current week with animation
    private func updateCurrentWeek(to offset: Int) {
        if currentWeekOffset != offset {
            // Pre-compute data for the new week in background if not cached
            if weeklyDataCache[offset] == nil {
                Task.detached(priority: .userInitiated) {
                    let data = await computeWeeklyData(for: offset)
                    await MainActor.run {
                        weeklyDataCache[offset] = data
                    }
                }
            }
            
            withAnimation(.easeInOut(duration: 0.2)) {
                animationOpacity = 0.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                currentWeekOffset = offset
                withAnimation(.easeInOut(duration: 0.2)) {
                    animationOpacity = 1.0
                }
            }
        }
    }
    
    // Compute all data for a week in background
    private func computeWeeklyData(for offset: Int) async -> WeeklyNovaData {
        let days = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
        var dailyData: [String: [Double]] = [:]
        var hasEntries: [String: Bool] = [:]
        var totalGroupCalories = [0, 0, 0, 0]
        var totalCalories = 0
        
        // Calculate data for each day
        for day in days {
            let date = getDateForDay(day, weekOffset: offset)
            let entries = getAllEntriesForDate(date)
            hasEntries[day] = !entries.isEmpty
            
            if !entries.isEmpty {
                // Expand meals into component foods for accurate NOVA scoring
                let expandedFoods = foodLogManager.expandedFoodItems(for: entries)
                
                let dayTotalCalories = expandedFoods.reduce(0) { $0 + $1.calories }
                totalCalories += dayTotalCalories
                
                var dayPercentages: [Double] = []
                for group in 1...4 {
                    let groupCalories = expandedFoods.reduce(0) { result, food in
                        let foodNovaScore = food.novaScore > 0 ?
                            food.novaScore :
                            NovaScoreService.shared.predictNovaScoreByName(food.name)
                        return result + (foodNovaScore == group ? food.calories : 0)
                    }
                    totalGroupCalories[group - 1] += groupCalories
                    let percentage = dayTotalCalories > 0 ? (Double(groupCalories) / Double(dayTotalCalories) * 100.0) : 0
                    dayPercentages.append(percentage)
                }
                dailyData[day] = dayPercentages
            } else {
                dailyData[day] = [0, 0, 0, 0]
            }
        }
        
        // Calculate weekly percentages
        let weeklyPercentages = totalGroupCalories.map { groupCal in
            totalCalories > 0 ? (Double(groupCal) / Double(totalCalories) * 100.0) : 0
        }
        
        return WeeklyNovaData(
            percentages: weeklyPercentages,
            dailyData: dailyData,
            hasEntries: hasEntries
        )
    }
    
    // Weekly stacked bar chart
    // Create a complete card for a specific week offset
    private func weeklyChartCard(for offset: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card header (date is now in week selector)
            Text("Weekly Average")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.top, 12)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            
            // Weekly chart for the specific week
            weeklyStackedBarChart(for: offset)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    // Create the stacked bar chart for a specific week offset
    private func weeklyStackedBarChart(for offset: Int) -> some View {
        VStack(spacing: 20) {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    // Main chart content
                    HStack(alignment: .bottom, spacing: 0) {
                        // Y-axis labels
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("100%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(height: geometry.size.height / 5)
                            Text("75%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(height: geometry.size.height / 5)
                            Text("50%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(height: geometry.size.height / 5)
                            Text("25%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(height: geometry.size.height / 5)
                            Text("0%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(height: geometry.size.height / 5)
                        }
                        .frame(width: 40)
                        
                        // Chart area
                        ZStack(alignment: .bottom) {
                            // Grid lines
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(0..<5) { i in
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 1)
                                        .frame(maxWidth: .infinity)
                                    
                                    if i < 4 {
                                        Spacer()
                                            .frame(height: geometry.size.height / 5 - 1)
                                    }
                                }
                            }
                            .frame(height: geometry.size.height)
                            
                            // Bars
                            HStack(alignment: .bottom, spacing: 0) {
                                ForEach(getDaysOfWeek(for: offset), id: \.self) { day in
                                    VStack(spacing: 4) {
                                        // State for long press
                                        let hasEntries = getCachedHasEntries(day: day, weekOffset: offset)
                                        
                                        // Stacked bar
                                        ZStack(alignment: .bottom) {
                                            // Background
                                            Rectangle()
                                                .fill(barEmptyBackground)
                                                .frame(height: geometry.size.height * 0.8) // Reduce height to match grid lines
                                            
                                            // Stacked segments
                                            VStack(spacing: 0) {
                                                if hasEntries {
                                                    // Draw segments from bottom to top (Group 1 at bottom, Group 4 at top)
                                                    // This ensures proper stacking order
                                                    let segments = (1...4).map { group -> (group: Int, height: CGFloat) in
                                                        let height = getCachedBarSegmentHeight(
                                                            day: day,
                                                            novaGroup: group,
                                                            maxHeight: geometry.size.height,
                                                            weekOffset: offset
                                                        )
                                                        return (group: group, height: height)
                                                    }
                                                    
                                                    // Draw in reverse order (Group 1 at bottom)
                                                    ForEach(segments.indices, id: \.self) { index in
                                                        let segment = segments[index]
                                                        Rectangle()
                                                            .fill(novaColors[segment.group - 1])
                                                            .frame(height: segment.height)
                                                    }
                                                } else {
                                                    // Empty placeholder for days with no entries
                                                    Rectangle()
                                                        .fill(Color.clear)
                                                        .frame(height: 0)
                                                }
                                            }
                                        }
                                        .frame(width: 30)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .contentShape(Rectangle())
                                        .onLongPressGesture(minimumDuration: 0.2, pressing: { isPressing in
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                activeTooltipDay = isPressing && hasEntries ? day : nil
                                            }
                                        }, perform: {})
                                        
                                        // Day label
                                        Text(day)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    // Store the bar position for tooltip positioning
                                    .background(GeometryReader { geo in
                                        Color.clear.onAppear {
                                            if let index = getDaysOfWeek(for: offset).firstIndex(of: day) {
                                                let barFrame = geo.frame(in: .named("chartCoordinateSpace"))
                                                // Store the position for later use
                                                if barPositions[index] != barFrame.midX {
                                                    barPositions[index] = barFrame.midX
                                                }
                                            }
                                        }
                                    })
                                }
                            }
                        }
                    }
                    
                    // Tooltip overlay - appears above all other content
                    if let activeDay = activeTooltipDay, 
                       let dayIndex = getDaysOfWeek(for: offset).firstIndex(of: activeDay),
                       barPositions.count > dayIndex {
                        DayDetailTooltip(
                            day: activeDay,
                            novaPercentages: getCachedDailyPercentages(day: activeDay, weekOffset: offset),
                            novaGroupNames: novaGroupNames,
                            novaColors: novaColors,
                            width: 150
                        )
                        .position(x: barPositions[dayIndex], y: geometry.size.height / 2 - 100)
                        .transition(.opacity)
                        .zIndex(100) // Ensure it's above everything else
                    }
                }
                .coordinateSpace(name: "chartCoordinateSpace")
            }
            .frame(height: 180)
            
            // Legend
            HStack(spacing: 16) {
                ForEach(0..<4) { index in
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(novaColors[index])
                            .frame(width: 12, height: 12)
                        
                        Text("Group \(index + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
        }
    }
}

// NOVA group percentages view
private func novaGroupPercentageView(percentage: Double, groupName: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        HStack {
            Text("\(Int(percentage))%")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(groupName)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    // NOVA explanation view
    private var novaExplanationView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About NOVA Classification")
                .font(.headline)
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                novaGroupExplanation(
                    number: 1,
                    name: "Unprocessed or minimally processed foods",
                    description: "Natural foods with minimal processing like fresh fruits, vegetables, grains, and meats.",
                    color: novaColors[0]
                )
                
                novaGroupExplanation(
                    number: 2,
                    name: "Processed culinary ingredients",
                    description: "Substances derived from Group 1 foods or nature, like oils, butter, sugar, and salt.",
                    color: novaColors[1]
                )
                
                novaGroupExplanation(
                    number: 3,
                    name: "Processed foods",
                    description: "Made by adding Group 2 ingredients to Group 1 foods, like canned vegetables, cheese, and fresh bread.",
                    color: novaColors[2]
                )
                
                novaGroupExplanation(
                    number: 4,
                    name: "Ultra-processed foods",
                    description: "Industrial formulations with five or more ingredients, often including additives not used in home cooking.",
                    color: novaColors[3]
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    // NOVA group explanation item
    private func novaGroupExplanation(number: Int, name: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Group number indicator
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(color)
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - NOVA Score Gauge
    
    // Calculate the overall NOVA score (0-100, higher is better)
    private func calculateNovaScore(for weekOffset: Int) -> Double {
        let group1 = getCachedWeeklyPercentage(for: 0, weekOffset: weekOffset)
        let group2 = getCachedWeeklyPercentage(for: 1, weekOffset: weekOffset)
        let group3 = getCachedWeeklyPercentage(for: 2, weekOffset: weekOffset)
        // Group 4 contributes 0 points
        
        // Weighted formula: Group1 = 100%, Group2 = 75%, Group3 = 50%, Group4 = 0%
        let score = group1 + (group2 * 0.75) + (group3 * 0.50)
        return min(100, max(0, score))
    }
    
    // Get score description based on value
    private func getScoreDescription(_ score: Double) -> String {
        switch score {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        case 20..<40: return "Poor"
        default: return "Needs Improvement"
        }
    }
    
    // Get score color based on value
    private func getScoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return gaugeColors[4] // Green
        case 60..<80: return gaugeColors[3]  // Lime
        case 40..<60: return gaugeColors[2]  // Yellow
        case 20..<40: return gaugeColors[1]  // Orange
        default: return gaugeColors[0]       // Red
        }
    }
    
    // Week selector carousel
    private var weekSelectorCarousel: some View {
        let cardWidth: CGFloat = 170
        
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(-10...0, id: \.self) { offset in
                    weekSelectorCard(for: offset)
                        .frame(width: cardWidth)
                        .id(offset)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrolledWeekID)
        .scrollTargetBehavior(.viewAligned)
        .safeAreaPadding(.horizontal, (UIScreen.main.bounds.width - cardWidth) / 2)
        .defaultScrollAnchor(.trailing)
        .onChange(of: scrolledWeekID) { oldValue, newValue in
            if let newValue = newValue, newValue != currentWeekOffset {
                updateCurrentWeek(to: newValue)
            }
        }
        .onAppear {
            // Pre-cache current week and adjacent weeks
            Task {
                for offset in [-1, 0, 1] {
                    if weeklyDataCache[offset] == nil {
                        let data = await computeWeeklyData(for: offset)
                        weeklyDataCache[offset] = data
                    }
                }
            }
        }
        .frame(height: 50)
    }
    
    // Individual week selector card
    private func weekSelectorCard(for offset: Int) -> some View {
        let isSelected = offset == currentWeekOffset
        
        return Text(weekDateRangeString(for: offset))
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "#35b8ff") : cardBackground)
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrolledWeekID = offset
                }
            }
    }
    
    // NOVA Score Gauge Card
    private func novaScoreGaugeCard(for weekOffset: Int) -> some View {
        let score = calculateNovaScore(for: weekOffset)
        
        return VStack(spacing: 8) {
            // Title only (date is now in week selector)
            Text("NOVA Score")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .padding(.horizontal, 16)
            
            // Gauge
            VStack(spacing: 0) {
                NovaScoreGauge(score: score, gaugeColors: gaugeColors)
                    .frame(height: 120)
                
                // Score display below the gauge
                Text("\(Int(score))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(getScoreColor(score))
                    .offset(y: -28)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .opacity(animationOpacity)
    }
    
    // MARK: - Helper Methods
    
    // Get days of week in order (Monday to Sunday)
    private func getDaysOfWeek(for offset: Int = 0) -> [String] {
        return ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
    }
    
    // Calculate the bar segment height for a specific day and NOVA group
    private func calculateBarSegmentHeight(day: String, novaGroup: Int, maxHeight: CGFloat, weekOffset: Int = 0) -> CGFloat {
        let percentage = calculateDailyPercentage(for: day, novaGroup: novaGroup, weekOffset: weekOffset)
        return CGFloat(percentage / 100.0) * (maxHeight * 0.8) // Adjust to 80% of max height to align with grid lines
    }
    
    // Calculate the percentage of calories from a specific NOVA group for a specific day
    private func calculateDailyPercentage(for day: String, novaGroup: Int, weekOffset: Int = 0) -> Double {
        // Get the date for the specified day with the correct week offset
        let date = getDateForDay(day, weekOffset: weekOffset)
        
        // Get all entries for that date
        let entries = getAllEntriesForDate(date)
        
        // If no entries, return 0
        if entries.isEmpty {
            return 0
        }
        
        // Expand meals into component foods for accurate NOVA scoring
        let expandedFoods = foodLogManager.expandedFoodItems(for: entries)
        
        // Calculate total calories for the day
        let totalCalories = expandedFoods.reduce(0) { $0 + $1.calories }
        
        // Calculate calories from the specified NOVA group using expanded foods
        let groupCalories = expandedFoods.reduce(0) { result, food in
            let foodNovaScore = food.novaScore > 0 ? 
                food.novaScore : 
                NovaScoreService.shared.predictNovaScoreByName(food.name)
            
            return result + (foodNovaScore == novaGroup ? food.calories : 0)
        }
        
        // Calculate percentage
        return totalCalories > 0 ? (Double(groupCalories) / Double(totalCalories) * 100.0) : 0
    }
    
    // Check if there are any food entries for a specific day
    private func hasFoodEntriesForDay(_ day: String, weekOffset: Int = 0) -> Bool {
        let date = getDateForDay(day, weekOffset: weekOffset)
        let entries = getAllEntriesForDate(date)
        return !entries.isEmpty
    }
    
    // Animate the transition between weeks with a slide effect
    private func animateWeekTransition(direction: Int) {
        // Only proceed if not already animating
        if isAnimating {
            return
        }
        
        // Set animation direction (-1 for left swipe, 1 for right swipe)
        animationDirection = direction
        isAnimating = true
        
        // Only allow right swipe if not at current week
        if direction > 0 && weekOffset >= 0 {
            isAnimating = false
            return
        }
        
        // Set the next week offset
        nextWeekOffset = weekOffset + direction
        
        let screenWidth = UIScreen.main.bounds.width
        
        // Determine if we're going to an older week (more negative offset)
        let goingToOlderWeek = (nextWeekOffset ?? 0) < weekOffset
        
        // Step 1: Slide current card out completely
        withAnimation(.easeOut(duration: 0.3)) {
            // When going to an older week (more negative offset), current card slides left
            // When going to a newer week (less negative offset), current card slides right
            slideOffset = goingToOlderWeek ? -screenWidth : screenWidth
            slideOpacity = 0
        }
        
        // Step 2: Update week offset after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            weekOffset = nextWeekOffset ?? weekOffset
            slideOffset = 0
            slideOpacity = 1
            nextWeekOffset = nil
            
            // Reset animation state after completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isAnimating = false
                animationDirection = 0
            }
        }
    }
    
    // Get cached weekly percentage or calculate if not cached
    private func getCachedWeeklyPercentage(for groupIndex: Int, weekOffset: Int) -> Double {
        if let cached = weeklyDataCache[weekOffset] {
            return cached.percentages[groupIndex]
        }
        // Fallback to direct calculation if not cached
        return calculateWeeklyPercentage(for: groupIndex + 1, weekOffset: weekOffset)
    }
    
    // Get cached daily percentages
    private func getCachedDailyPercentages(day: String, weekOffset: Int) -> [Double] {
        if let cached = weeklyDataCache[weekOffset],
           let dailyData = cached.dailyData[day] {
            return dailyData
        }
        // Fallback to direct calculation
        return (1...4).map { calculateDailyPercentage(for: day, novaGroup: $0, weekOffset: weekOffset) }
    }
    
    // Get cached has entries status
    private func getCachedHasEntries(day: String, weekOffset: Int) -> Bool {
        if let cached = weeklyDataCache[weekOffset],
           let hasEntries = cached.hasEntries[day] {
            return hasEntries
        }
        // Fallback to direct calculation
        return hasFoodEntriesForDay(day, weekOffset: weekOffset)
    }
    
    // Get cached bar segment height
    private func getCachedBarSegmentHeight(day: String, novaGroup: Int, maxHeight: CGFloat, weekOffset: Int) -> CGFloat {
        if let cached = weeklyDataCache[weekOffset],
           let dailyData = cached.dailyData[day] {
            let percentage = dailyData[novaGroup - 1]
            return CGFloat(percentage / 100.0) * (maxHeight * 0.8)
        }
        // Fallback to direct calculation
        return calculateBarSegmentHeight(day: day, novaGroup: novaGroup, maxHeight: maxHeight, weekOffset: weekOffset)
    }
    
    // Calculate the weekly percentage for a specific NOVA group with a specific week offset
    private func calculateWeeklyPercentage(for novaGroup: Int, weekOffset: Int = 0) -> Double {
        let days = getDaysOfWeek(for: weekOffset)
        var totalGroupCalories = 0
        var totalCalories = 0
        
        // Sum up calories for each day
        for day in days {
            let date = getDateForDay(day, weekOffset: weekOffset)
            let entries = getAllEntriesForDate(date)
            
            // Expand meals into component foods for accurate NOVA scoring
            let expandedFoods = foodLogManager.expandedFoodItems(for: entries)
            
            // Add to total calories
            let dayTotalCalories = expandedFoods.reduce(0) { $0 + $1.calories }
            totalCalories += dayTotalCalories
            
            // Add to group calories using expanded food items
            let dayGroupCalories = expandedFoods.reduce(0) { result, food in
                let foodNovaScore = food.novaScore > 0 ? 
                    food.novaScore : 
                    NovaScoreService.shared.predictNovaScoreByName(food.name)
                
                return result + (foodNovaScore == novaGroup ? food.calories : 0)
            }
            totalGroupCalories += dayGroupCalories
        }
        
        // Calculate percentage
        return totalCalories > 0 ? (Double(totalGroupCalories) / Double(totalCalories) * 100.0) : 0
    }
    
    // Helper to get all entries for a date across all meal types
    private func getAllEntriesForDate(_ date: Date) -> [FoodEntry] {
        // Common meal types in the app
        let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snacks"]
        
        // Collect entries from all meal types
        var allEntries: [FoodEntry] = []
        for mealType in mealTypes {
            allEntries.append(contentsOf: foodLogManager.entries(for: date, mealType: mealType))
        }
        
        return allEntries
    }
    
    // Calculate the offset for the next card based on swipe direction and progress
    private func calculateNextCardOffset() -> CGFloat {
        guard let nextOffset = nextWeekOffset else { return UIScreen.main.bounds.width }
        
        let screenWidth = UIScreen.main.bounds.width
        let isGoingBack = nextOffset < weekOffset // Going back in time (right swipe)
        
        if isGoingBack {
            // Next card starts from the right and slides in from right to left
            return screenWidth + slideOffset
        } else {
            // Next card starts from the left and slides in from left to right
            return -screenWidth + slideOffset
        }
    }
    
    // Get the date range string for a specific week offset
    private func weekDateRangeString(for offset: Int = 0) -> String {
        let calendar = Calendar.current
        
        // Get the start of the current week (Monday) - matching getDateForDay logic
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday == 1 ? 6 : weekday - 2 // Adjust for Monday start (weekday 1 = Sunday, 2 = Monday)
        
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
            return "Week of \(formatDate(today))"
        }
        
        // Apply the week offset
        guard let selectedWeekStart = calendar.date(byAdding: .day, value: 7 * offset, to: currentWeekStart),
              let selectedWeekEnd = calendar.date(byAdding: .day, value: 6, to: selectedWeekStart) else {
            return "Week of \(formatDate(today))"
        }
        
        return "\(formatDate(selectedWeekStart)) - \(formatDate(selectedWeekEnd))"
    }
    
    // Format date as MMM d (e.g., "Jul 23")
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    // Scroll to current week in carousel
    private func scrollToCurrentWeek() {
        // This will be handled by the ScrollViewReader if we add it
        // For now, the carousel will start at the current week (offset 0)
    }
    
    // Get the date for a specific day abbreviation in the selected week
    private func getDateForDay(_ day: String, weekOffset: Int = 0) -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        // Get the start of the current week (Monday)
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday == 1 ? 6 : weekday - 2 // Adjust for Monday start (weekday 1 = Sunday, 2 = Monday)
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
            return today
        }
        
        // Apply the week offset to get the selected week's start date
        guard let selectedWeekStart = calendar.date(byAdding: .day, value: 7 * weekOffset, to: currentWeekStart) else {
            return today
        }
        
        // Map day string to weekday integer (0 = Monday, 1 = Tuesday, etc.)
        let dayMap = ["M": 0, "Tu": 1, "W": 2, "Th": 3, "F": 4, "Sa": 5, "Su": 6]
        guard let dayOffset = dayMap[day] else { return today }
        
        // Create a date for the target day in the selected week
        return calendar.date(byAdding: .day, value: dayOffset, to: selectedWeekStart) ?? today
    }
}

// Tooltip view for displaying detailed percentages on long press
struct DayDetailTooltip: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let day: String
    let novaPercentages: [Double]
    let novaGroupNames: [String]
    let novaColors: [Color]
    let width: CGFloat
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(day)
                .font(.headline)
                .padding(.bottom, 4)
            
            // Display NOVA groups in order from 1 to 4
            ForEach(0..<4) { index in
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(novaColors[index])
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                    
                    Text("Group \(index + 1)")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(novaPercentages[index]))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(novaColors[index])
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
        )
        .frame(width: width)
    }
}

// 240-degree gauge view with needle
struct NovaScoreGauge: View {
    let score: Double // 0-100
    let gaugeColors: [Color]
    
    // 240 degree arc: starts at 150° (bottom-left), ends at 30° (bottom-right)
    // 0 score = 150° (left), 100 score = 390° (30° = 360+30)
    private var needleRotation: Double {
        // Map 0-100 to 150 to 390 degrees (240 degree sweep)
        return 150.0 + (score / 100.0) * 240.0
    }
    
    var body: some View {
        GeometryReader { geometry in
            let centerY = geometry.size.height * 0.6 // Move center up a bit for 240° arc
            let center = CGPoint(x: geometry.size.width / 2, y: centerY)
            let radius = min(geometry.size.width / 2, geometry.size.height * 0.8) - 10
            let innerRadius = radius * 0.70
            let segmentAngle = 240.0 / 5.0 // 48 degrees per segment
            
            ZStack {
                // Draw colored segments (5 segments, 48 degrees each = 240/5)
                ForEach(0..<5, id: \.self) { index in
                    Path { path in
                        // Start at 150° (bottom-left), sweep 240° clockwise to 390° (30°)
                        let startAngle = Angle(degrees: 150.0 + Double(index) * segmentAngle)
                        let endAngle = Angle(degrees: 150.0 + Double(index + 1) * segmentAngle - 2) // Small gap
                        
                        path.addArc(center: center, radius: radius,
                                    startAngle: startAngle, endAngle: endAngle,
                                    clockwise: false)
                        path.addArc(center: center, radius: innerRadius,
                                    startAngle: endAngle, endAngle: startAngle,
                                    clockwise: true)
                        path.closeSubpath()
                    }
                    .fill(gaugeColors[index])
                }
                
                // Needle
                Path { path in
                    let needleLength = radius * 0.80
                    let needleWidth: CGFloat = 6
                    
                    // Needle pointer (triangle)
                    let angle = Angle(degrees: needleRotation).radians
                    let tipX = center.x + cos(angle) * needleLength
                    let tipY = center.y + sin(angle) * needleLength
                    
                    let leftAngle = angle + .pi / 2
                    let rightAngle = angle - .pi / 2
                    let baseLeftX = center.x + cos(leftAngle) * (needleWidth * 0.6)
                    let baseLeftY = center.y + sin(leftAngle) * (needleWidth * 0.6)
                    let baseRightX = center.x + cos(rightAngle) * (needleWidth * 0.6)
                    let baseRightY = center.y + sin(rightAngle) * (needleWidth * 0.6)
                    
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: baseLeftX, y: baseLeftY))
                    path.addLine(to: CGPoint(x: baseRightX, y: baseRightY))
                    path.closeSubpath()
                }
                .fill(Color(.label))
                
                // Center dot
                Circle()
                    .fill(Color(.label))
                    .frame(width: 12, height: 12)
                    .position(center)
                
                Circle()
                    .fill(Color.appCardBackground)
                    .frame(width: 6, height: 6)
                    .position(center)
                
                // Scale labels at arc ends
                let labelRadius = radius + 12
                let startLabelAngle = Angle(degrees: 150).radians
                let endLabelAngle = Angle(degrees: 30).radians
                
                Text("0")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .position(
                        x: center.x + cos(startLabelAngle) * labelRadius,
                        y: center.y + sin(startLabelAngle) * labelRadius
                    )
                
                Text("100")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .position(
                        x: center.x + cos(endLabelAngle) * labelRadius,
                        y: center.y + sin(endLabelAngle) * labelRadius
                    )
            }
        }
    }
}

#Preview {
    NovaGroupsDetailView(foodLogManager: FoodLogManager.shared)
}
