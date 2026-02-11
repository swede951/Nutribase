import SwiftUI

enum NovaGroupsSizeMode: String, CaseIterable {
    case compact = "1×1"
    case wide = "2×1"
}

// Custom wrapper to match the standard DashboardCardView styling
struct NovaCardWrapper<Content: View>: View {
    let content: Content
    @Binding var showingDetailView: Bool
    @Binding var showingInfo: Bool
    let isPreview: Bool
    
    init(showingDetailView: Binding<Bool>, showingInfo: Binding<Bool>, isPreview: Bool = false, @ViewBuilder content: () -> Content) {
        self._showingDetailView = showingDetailView
        self._showingInfo = showingInfo
        self.isPreview = isPreview
        self.content = content()
    }
    
    var body: some View {
        // Don't pass tap actions in preview mode to allow drag gestures to work
        FixedSizeCard(
            title: "NOVA Groups",
            showInfoButton: false,
            onCardTap: isPreview ? nil : { showingDetailView = true }
        ) {
            content
        }
    }
}

struct NovaGroupsCardView: View {
    var isPreview: Bool = false
    
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    @AppStorage("novaGroupsSizeMode") private var sizeMode: NovaGroupsSizeMode = .wide
    
    // State for showing the detailed view
    @State private var showingDetailView = false
    
    // Info button action
    @State private var showingInfo = false
    
    // State to track the selected week (0 = current week, -1 = last week, etc.)
    @State private var weekOffset = 0
    
    // Cached weekday data to avoid recalculating on every render
    @State private var cachedWeekdayData: [(day: String, score: Double, distribution: [Int: Double])] = []
    @State private var lastEntriesCount: Int = 0
    
    // Preview data
    private var previewWeekdayData: [(day: String, score: Double, distribution: [Int: Double])] {
        [
            (day: "S", score: 0.8, distribution: [1: 0.6, 2: 0.1, 3: 0.2, 4: 0.1]),
            (day: "S", score: 0.7, distribution: [1: 0.5, 2: 0.15, 3: 0.2, 4: 0.15]),
            (day: "M", score: 0.85, distribution: [1: 0.7, 2: 0.1, 3: 0.1, 4: 0.1]),
            (day: "T", score: 0.6, distribution: [1: 0.4, 2: 0.2, 3: 0.25, 4: 0.15]),
            (day: "W", score: 0.75, distribution: [1: 0.55, 2: 0.15, 3: 0.2, 4: 0.1]),
            (day: "T", score: 0.9, distribution: [1: 0.75, 2: 0.1, 3: 0.1, 4: 0.05]),
            (day: "F", score: 0.65, distribution: [1: 0.45, 2: 0.15, 3: 0.25, 4: 0.15])
        ]
    }
    
    // NOVA group colors
    private let novaColors: [Int: Color] = [
        1: Color(hex: "#3f993f"),      // Unprocessed - darker green
        2: Color(hex: "#b7ce0d"),      // Processed culinary ingredients - lime green
        3: Color(hex: "#f28e16"),      // Processed foods - orange
        4: Color(hex: "#d4455a")       // Ultra-processed foods - desaturated red
    ]
    
    // Use cached weekday data
    private var weekdayData: [(day: String, score: Double, distribution: [Int: Double])] {
        if isPreview { return previewWeekdayData }
        return cachedWeekdayData
    }
    
    // Calculate NOVA scores and distribution for each day (last 7 days)
    private func calculateWeekdayData() -> [(day: String, score: Double, distribution: [Int: Double])] {
        var data: [(day: String, score: Double, distribution: [Int: Double])] = []
        
        for daysAgo in (0..<7).reversed() {
            // Get the date for this day (last 7 days)
            let date = getDateForLastDays(daysAgo: daysAgo)
            
            // Get day letter
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: date)
            let dayLetters = ["S", "M", "T", "W", "T", "F", "S"] // Sunday = 1, Monday = 2, etc.
            let dayLetter = dayLetters[weekday - 1]
            
            // Get entries for this date (all meal types)
            let entries = getAllEntriesForDate(date)
            
            if entries.isEmpty {
                data.append((day: dayLetter, score: 0.0, distribution: [:]))
            } else {
                // Expand meals into component foods for accurate NOVA scoring
                let expandedFoods = foodLogManager.expandedFoodItems(for: entries)
                
                // Calculate total calories from expanded foods
                let totalCalories = expandedFoods.reduce(0) { $0 + $1.calories }
                
                // Initialize distribution counters for each NOVA group
                var groupCalories: [Int: Double] = [1: 0, 2: 0, 3: 0, 4: 0]
                
                // Calculate weighted score and group distribution using expanded foods
                var weightedScore = 0.0
                for food in expandedFoods {
                    let novaScore = food.novaScore > 0 ? 
                        food.novaScore : 
                        NovaScoreService.shared.predictNovaScoreByName(food.name)
                    
                    // Add calories to the appropriate NOVA group
                    groupCalories[novaScore, default: 0] += Double(food.calories)
                    
                    // Invert the NOVA score (1 is best, 4 is worst)
                    let invertedScore = 5.0 - Double(novaScore)
                    
                    // Weight by calories
                    let entryWeight = Double(food.calories) / Double(totalCalories)
                    weightedScore += entryWeight * invertedScore / 4.0 // Normalize to 0-1
                }
                
                // Convert calorie counts to percentages
                var distribution: [Int: Double] = [:]
                for (group, calories) in groupCalories {
                    distribution[group] = calories / Double(totalCalories)
                }
                
                data.append((day: dayLetter, score: weightedScore, distribution: distribution))
            }
        }
        
        return data
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            NovaCardWrapper(showingDetailView: $showingDetailView, showingInfo: $showingInfo, isPreview: isPreview) {
                if sizeMode == .compact && !isPreview {
                    // Compact mode: chart only
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(weekdayData.enumerated()), id: \.offset) { index, dayData in
                            WeekdayBar(day: dayData.day, score: dayData.score, novaDistribution: dayData.distribution, novaColors: novaColors)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                } else {
                    // Wide mode: percentages + chart
                    HStack(alignment: .center, spacing: 12) {
                        // Weekly average percentages stacked vertically on the left
                        VStack(spacing: 3) {
                            percentageView(value: calculateWeeklyPercentage(for: 1), label: "Unprocessed", color: novaColors[1] ?? .gray)
                            percentageView(value: calculateWeeklyPercentage(for: 2), label: "Ingredients", color: novaColors[2] ?? .gray)
                            percentageView(value: calculateWeeklyPercentage(for: 3), label: "Processed", color: novaColors[3] ?? .gray)
                            percentageView(value: calculateWeeklyPercentage(for: 4), label: "Ultra", color: novaColors[4] ?? .gray)
                        }
                        .frame(minWidth: 100) // Minimum width but flexible
                        
                        // Weekday bars on the right - more compact spacing
                        HStack(alignment: .bottom, spacing: 6) {
                            // Show all 7 days in order (oldest to newest, left to right)
                            ForEach(Array(weekdayData.enumerated()), id: \.offset) { index, dayData in
                                WeekdayBar(day: dayData.day, score: dayData.score, novaDistribution: dayData.distribution, novaColors: novaColors)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 50) // Use available space flexibly with increased height
                    }
                }
            }
            
            if !isPreview {
                Menu {
                    ForEach(NovaGroupsSizeMode.allCases, id: \.self) { mode in
                        Button(action: {
                            sizeMode = mode
                            NotificationCenter.default.post(name: NSNotification.Name("NovaGroupsSizeModeChanged"), object: nil)
                        }) {
                            HStack {
                                Text(mode.rawValue)
                                if sizeMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
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
        .sheet(isPresented: $showingDetailView) {
            NovaGroupsDetailView(foodLogManager: foodLogManager)
        }
        .allowsHitTesting(!isPreview)
        .onAppear {
            updateCacheIfNeeded()
            // Pre-warm the global cache for faster detail view opening
            prewarmGlobalCache()
        }
        .onChange(of: foodLogManager.entries.count) { _, _ in
            updateCacheIfNeeded()
            // Re-warm cache when data changes
            prewarmGlobalCache()
        }
    }
    
    // Update cache only when entries change
    private func updateCacheIfNeeded() {
        guard !isPreview else { return }
        let currentCount = foodLogManager.entries.count
        if currentCount != lastEntriesCount || cachedWeekdayData.isEmpty {
            cachedWeekdayData = calculateWeekdayData()
            lastEntriesCount = currentCount
        }
    }
    
    // Pre-warm the global ChartDataCacheManager for faster detail view opening
    private func prewarmGlobalCache() {
        guard !isPreview else { return }
        
        // Pre-compute NOVA data in background so detail view opens instantly
        Task.detached(priority: .background) {
            let days = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
            var dailyData: [String: [Int: Int]] = [:]
            var hasEntries: [String: Bool] = [:]
            var weeklyAverage: [Int: Double] = [1: 0, 2: 0, 3: 0, 4: 0]
            var totalCalories = 0
            var groupCalories: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0]
            
            for day in days {
                let date = await MainActor.run { self.getDateForDay(day) }
                let entries = await MainActor.run { self.getAllEntriesForDate(date) }
                hasEntries[day] = !entries.isEmpty
                
                if !entries.isEmpty {
                    let expandedFoods = await MainActor.run { self.foodLogManager.expandedFoodItems(for: entries) }
                    var dayData: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0]
                    
                    for food in expandedFoods {
                        let novaScore = food.novaScore > 0 ? 
                            food.novaScore : 
                            NovaScoreService.shared.predictNovaScoreByName(food.name)
                        dayData[novaScore, default: 0] += food.calories
                        groupCalories[novaScore, default: 0] += food.calories
                        totalCalories += food.calories
                    }
                    dailyData[day] = dayData
                } else {
                    dailyData[day] = [1: 0, 2: 0, 3: 0, 4: 0]
                }
            }
            
            // Calculate weekly averages
            if totalCalories > 0 {
                for group in 1...4 {
                    weeklyAverage[group] = Double(groupCalories[group, default: 0]) / Double(totalCalories) * 100.0
                }
            }
            
            // Store in global cache
            let cache = ChartDataCacheManager.WeeklyNovaCache(
                weekOffset: 0,
                dailyData: dailyData,
                hasEntries: hasEntries,
                weeklyAverage: weeklyAverage,
                timestamp: Date(),
                dataHash: totalCalories
            )
            
            await MainActor.run {
                ChartDataCacheManager.shared.setWeeklyNovaCache(cache)
            }
        }
    }
    
    // Get date for X days ago
    private func getDateForLastDays(daysAgo: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
    }
    
    // Helper function to create a percentage view with inactive state handling
    private func percentageView(value: Double, label: String, color: Color) -> some View {
        let isInactive = value == 0.0
        
        return HStack(alignment: .center, spacing: 4) {
            Text("\(Int(value))%")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isInactive ? color.opacity(0.3) : color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(isInactive ? .secondary.opacity(0.5) : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .opacity(isInactive ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isInactive)
    }
    
    // Calculate the percentage for a specific NOVA group over last 7 days
    private func calculateWeeklyPercentage(for novaGroup: Int) -> Double {
        if isPreview {
            switch novaGroup {
            case 1: return 55.0
            case 2: return 15.0
            case 3: return 20.0
            case 4: return 10.0
            default: return 0.0
            }
        }
        
        var totalGroupCalories = 0
        var totalCalories = 0
        
        // Sum up calories for last 7 days
        for daysAgo in 0..<7 {
            let date = getDateForLastDays(daysAgo: daysAgo)
            let entries = getAllEntriesForDate(date)
            
            // Expand meals into component foods for accurate NOVA scoring
            let expandedFoods = foodLogManager.expandedFoodItems(for: entries)
            
            // Add to total calories
            let dayTotalCalories = expandedFoods.reduce(0) { $0 + $1.calories }
            totalCalories += dayTotalCalories
            
            // Add to group calories using expanded foods
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
    
    // Week navigation view with arrows and date display
    private func weekNavigationView() -> some View {
        HStack {
            Button(action: {
                weekOffset -= 1
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text(weekDateRangeString())
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                if weekOffset < 0 {
                    weekOffset += 1
                }
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(weekOffset < 0 ? .blue : .gray)
            }
            .disabled(weekOffset >= 0)
        }
        .padding(.bottom, 8)
    }
    
    // Generate a string representation of the selected week's date range
    private func weekDateRangeString() -> String {
        let calendar = Calendar.current
        
        // Get the start of the current week (Sunday)
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday - 1 // 1 = Sunday
        
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
            return "Week of \(formatDate(today))"
        }
        
        // Apply the week offset
        guard let selectedWeekStart = calendar.date(byAdding: .day, value: 7 * weekOffset, to: currentWeekStart),
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
    
    // Get the date for a specific day abbreviation in the selected week
    private func getDateForDay(_ day: String) -> Date {
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
}

struct WeekdayBar: View {
    let day: String
    let score: Double
    let novaDistribution: [Int: Double]
    let novaColors: [Int: Color]
    
    init(day: String, score: Double, novaDistribution: [Int: Double] = [:], novaColors: [Int: Color]) {
        self.day = day
        self.score = score
        self.novaDistribution = novaDistribution
        self.novaColors = novaColors
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Background bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.appInsetBackground)
                .frame(width: 12, height: 50)
                .overlay(
                    // Stacked bars for each NOVA group
                    GeometryReader { geometry in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            
                            // If we have distribution data, show stacked bars
                            if !novaDistribution.isEmpty {
                                // Create a ZStack to apply clipping to the entire stack
                                ZStack(alignment: .bottom) {
                                    // Create a single stacked bar with all NOVA groups
                                    VStack(spacing: 0) {
                                        ForEach(1...4, id: \.self) { group in
                                            if let percentage = novaDistribution[group], percentage > 0 {
                                                Rectangle()
                                                    .fill(novaColors[group] ?? .gray)
                                                    .frame(width: 12, height: geometry.size.height * percentage)
                                            }
                                        }
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                            } else {
                                // Fallback to simple score representation
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.green.opacity(score))
                                    .frame(width: 12, height: max(4, geometry.size.height * score))
                            }
                        }
                    }
                )
            
            Text(day)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct NovaInfoView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text("About NOVA Classification")
                        .font(.headline)
                    
                    // Description
                    Text("NOVA is a food classification system that categorizes foods according to the extent and purpose of processing, rather than in terms of nutrients.")
                    
                    // Group 1
                    groupInfoView(number: 1, title: "Unprocessed or minimally processed foods", description: "Natural foods with minimal processing like fresh fruits, vegetables, grains, and meats.")
                    
                    // Group 2
                    groupInfoView(number: 2, title: "Processed culinary ingredients", description: "Substances derived from Group 1 foods or nature, like oils, butter, sugar, and salt.")
                    
                    // Group 3
                    groupInfoView(number: 3, title: "Processed foods", description: "Made by adding Group 2 ingredients to Group 1 foods, like canned vegetables, cheese, and fresh bread.")
                    
                    // Group 4
                    groupInfoView(number: 4, title: "Ultra-processed foods", description: "Industrial formulations with five or more ingredients, often including additives not used in home cooking.")
                    
                    // Footer
                    Text("Your daily NOVA score is calculated based on the proportion of unprocessed or minimally processed foods in your diet. Higher scores indicate a diet with more natural foods.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("NOVA Groups")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // Helper function to create consistent group info views
    private func groupInfoView(number: Int, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Group \(number): \(title)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack {
        NovaGroupsCardView()
            .frame(width: 350,height: 120)
            .padding()
    }
    .background(Color.appBackground)
}
