import SwiftUI
import Charts

struct FatDetailView: View {
    @ObservedObject var foodLogManager: FoodLogManager
    @ObservedObject var userProfile: UserProfile
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    
    private var viewBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    @State private var currentWeekOffset: Int = 0
    @State private var currentMonthOffset: Int = 0
    @State private var animationOpacity: Double = 1.0
    
    // State for tooltip display
    @State private var activeTooltipDay: String? = nil
    @State private var barPositions: [CGFloat] = Array(repeating: 0, count: 7)
    
    // View mode state
    enum ViewMode: String, CaseIterable {
        case weekly = "Weekly"
        case monthly = "Monthly"
    }
    @State private var viewMode: ViewMode = .weekly
    
    // Shared cache manager for persistent caching across view lifecycle
    private let cacheManager = ChartDataCacheManager.shared
    
    // Local cache for immediate access (synced with shared cache)
    @State private var weeklyDataCache: [Int: WeeklyMacroData] = [:]
    @State private var monthlyDataCache: [Int: MonthlyMacroData] = [:]
    
    // Pre-computed chart data cache to avoid recalculating on every render
    @State private var monthlyChartDataCache: [Int: [MonthDayFatData]] = [:]
    
    // Struct to hold pre-computed weekly data
    struct WeeklyMacroData {
        let dailyData: [String: Int] // Day -> grams consumed
        let hasEntries: [String: Bool] // Day -> hasEntries
        let weeklyAverage: Double
        let weeklyTotal: Int
    }
    
    // Struct to hold pre-computed monthly data
    struct MonthlyMacroData {
        let dailyData: [Int: Int] // Day number -> grams consumed
        let hasEntries: [Int: Bool] // Day number -> hasEntries
        let monthlyAverage: Double
        let monthlyTotal: Int
    }
    
    var fatTarget: Int {
        return userProfile.fatGoalGrams > 0 ? userProfile.fatGoalGrams : 70
    }
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        
        NavigationView {
            ZStack {
                viewBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Weekly chart carousel with snap behavior
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 20) {
                                    // Generate cards chronologically: oldest (-10) on left, newest (0) on right
                                    ForEach(-10...0, id: \.self) { offset in
                                        weeklyChartCard(for: offset)
                                            .frame(width: screenWidth * 0.85, height: 280)
                                            .fixedSize()
                                            .id(offset)
                                    }
                                }
                                .padding(.horizontal, screenWidth * 0.075)
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.viewAligned)
                            .defaultScrollAnchor(.trailing)
                            .onScrollTargetVisibilityChange(idType: Int.self) { visibleIDs in
                                if let centerID = visibleIDs.first {
                                    self.updateCurrentWeek(to: centerID)
                                }
                            }
                            .onAppear {
                                // Pre-cache current week first, then adjacent weeks in parallel
                                Task(priority: .userInitiated) {
                                    // Load current week first for immediate display
                                    if weeklyDataCache[0] == nil {
                                        let data = await computeWeeklyData(for: 0)
                                        await MainActor.run { weeklyDataCache[0] = data }
                                    }
                                    
                                    // Then load adjacent weeks in parallel
                                    await withTaskGroup(of: (Int, WeeklyMacroData).self) { group in
                                        for offset in [-1, 1] {
                                            if weeklyDataCache[offset] == nil {
                                                group.addTask {
                                                    let data = await computeWeeklyData(for: offset)
                                                    return (offset, data)
                                                }
                                            }
                                        }
                                        for await (offset, data) in group {
                                            await MainActor.run { weeklyDataCache[offset] = data }
                                        }
                                    }
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    proxy.scrollTo(0, anchor: .center)
                                }
                            }
                            .frame(height: 320)
                        }
                        
                        // Statistics
                        VStack(alignment: .leading, spacing: 16) {
                            Text("\(viewMode == .weekly ? "Weekly" : "Monthly") Statistics")
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                statisticCard(
                                    title: "Average",
                                    value: "\(Int(viewMode == .weekly ? getCachedWeeklyAverage(weekOffset: currentWeekOffset) : getCachedMonthlyAverage(monthOffset: currentMonthOffset)))g",
                                    subtitle: "per day",
                                    color: CardType.fat.color
                                )
                                
                                statisticCard(
                                    title: "Target",
                                    value: "\(fatTarget)g",
                                    subtitle: "per day",
                                    color: .secondary
                                )
                            }
                        }
                        .opacity(animationOpacity)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("Fat Details")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            Picker("View Mode", selection: $viewMode) {
                                ForEach(ViewMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.primary)
                                .padding(8)
                        }
                        
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onChange(of: viewMode) { oldMode, newMode in
                if newMode == .monthly {
                    preloadMonthlyData()
                }
            }
        }
    }
    
    // Preload monthly data for current and adjacent months
    private func preloadMonthlyData() {
        Task(priority: .userInitiated) {
            if monthlyDataCache[0] == nil {
                if let cached = loadMonthlyFromSharedCache(monthOffset: 0) {
                    await MainActor.run {
                        monthlyDataCache[0] = cached
                        buildMonthlyChartDataCache(for: 0)
                    }
                } else {
                    let data = await computeMonthlyData(for: 0)
                    await MainActor.run {
                        monthlyDataCache[0] = data
                        saveMonthlyToSharedCache(data, monthOffset: 0)
                        buildMonthlyChartDataCache(for: 0)
                    }
                }
            } else {
                await MainActor.run { buildMonthlyChartDataCache(for: 0) }
            }
            
            await withTaskGroup(of: (Int, MonthlyMacroData).self) { group in
                for offset in [-1, -2, -3] {
                    if monthlyDataCache[offset] == nil {
                        group.addTask {
                            if let cached = self.loadMonthlyFromSharedCache(monthOffset: offset) {
                                return (offset, cached)
                            }
                            let data = await self.computeMonthlyData(for: offset)
                            return (offset, data)
                        }
                    }
                }
                for await (offset, data) in group {
                    await MainActor.run {
                        monthlyDataCache[offset] = data
                        saveMonthlyToSharedCache(data, monthOffset: offset)
                        buildMonthlyChartDataCache(for: offset)
                    }
                }
            }
        }
    }
    
    // Helper function to update current week/month with animation
    private func updateCurrentWeek(to offset: Int) {
        let hasChanged = viewMode == .weekly ? (currentWeekOffset != offset) : (currentMonthOffset != offset)
        
        if hasChanged {
            activeTooltipDay = nil
            
            withAnimation(.easeInOut(duration: 0.2)) {
                animationOpacity = 0.8
            }
            
            Task(priority: .userInitiated) {
                if viewMode == .weekly {
                    if weeklyDataCache[offset] == nil {
                        if let cached = self.loadFromSharedCache(weekOffset: offset) {
                            weeklyDataCache[offset] = cached
                        } else {
                            let data = await self.computeWeeklyData(for: offset)
                            self.saveToSharedCache(data, weekOffset: offset)
                            weeklyDataCache[offset] = data
                        }
                    }
                } else {
                    if monthlyDataCache[offset] == nil {
                        if let cached = self.loadMonthlyFromSharedCache(monthOffset: offset) {
                            monthlyDataCache[offset] = cached
                            buildMonthlyChartDataCache(for: offset)
                        } else {
                            let data = await self.computeMonthlyData(for: offset)
                            self.saveMonthlyToSharedCache(data, monthOffset: offset)
                            monthlyDataCache[offset] = data
                            buildMonthlyChartDataCache(for: offset)
                        }
                    } else if monthlyChartDataCache[offset] == nil {
                        buildMonthlyChartDataCache(for: offset)
                    }
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if viewMode == .weekly {
                    currentWeekOffset = offset
                } else {
                    currentMonthOffset = offset
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    animationOpacity = 1.0
                }
            }
        }
    }
    
    // Compute all data for a week in background
    private func computeWeeklyData(for offset: Int) async -> WeeklyMacroData {
        let days = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
        var dailyData: [String: Int] = [:]
        var hasEntries: [String: Bool] = [:]
        var weeklyTotal = 0
        var daysWithData = 0
        
        for day in days {
            let date = getDateForDay(day, weekOffset: offset)
            let fat = foodLogManager.totalFatForDay(date: date)
            let entries = getAllEntriesForDate(date)
            
            dailyData[day] = fat
            hasEntries[day] = !entries.isEmpty
            
            if !entries.isEmpty {
                weeklyTotal += fat
                daysWithData += 1
            }
        }
        
        let weeklyAverage = daysWithData > 0 ? Double(weeklyTotal) / Double(daysWithData) : 0
        
        return WeeklyMacroData(
            dailyData: dailyData,
            hasEntries: hasEntries,
            weeklyAverage: weeklyAverage,
            weeklyTotal: weeklyTotal
        )
    }
    
    // Compute monthly data with proper average calculation (only days with entries)
    private func computeMonthlyData(for offset: Int) async -> MonthlyMacroData {
        let calendar = Calendar.current
        let today = Date()
        
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let targetMonth = calendar.date(byAdding: .month, value: offset, to: currentMonthStart),
              let monthRange = calendar.range(of: .day, in: .month, for: targetMonth) else {
            return MonthlyMacroData(dailyData: [:], hasEntries: [:], monthlyAverage: 0, monthlyTotal: 0)
        }
        
        var dailyData: [Int: Int] = [:]
        var hasEntries: [Int: Bool] = [:]
        var monthlyTotal = 0
        var daysWithData = 0
        
        for day in 1...monthRange.count {
            guard let dayDate = calendar.date(byAdding: .day, value: day - 1, to: targetMonth) else { continue }
            
            let fat = foodLogManager.totalFatForDay(date: dayDate)
            let entries = getAllEntriesForDate(dayDate)
            
            dailyData[day] = fat
            hasEntries[day] = !entries.isEmpty
            
            if !entries.isEmpty {
                monthlyTotal += fat
                daysWithData += 1
            }
        }
        
        let monthlyAverage = daysWithData > 0 ? Double(monthlyTotal) / Double(daysWithData) : 0
        
        return MonthlyMacroData(
            dailyData: dailyData,
            hasEntries: hasEntries,
            monthlyAverage: monthlyAverage,
            monthlyTotal: monthlyTotal
        )
    }
    
    // Create a complete card for a specific week offset
    private func weeklyChartCard(for offset: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card header with period navigation
            HStack {
                Text(viewMode == .weekly ? "Weekly Average" : "Monthly Average")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Date display
                Text(viewMode == .weekly ? weekDateRangeString(for: offset) : monthDateRangeString(for: offset))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            
            // Chart based on view mode
            if viewMode == .weekly {
                weeklyBarChart(for: offset)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                monthlyBarChart(for: offset)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    // Data struct for Swift Charts
    struct DayFatData: Identifiable {
        let id = UUID()
        let day: String
        let dayIndex: Int
        let grams: Int
        let hasEntries: Bool
    }
    
    // Get chart data for a specific week
    private func getWeeklyChartData(for offset: Int) -> [DayFatData] {
        let days = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
        return days.enumerated().map { index, day in
            DayFatData(
                day: day,
                dayIndex: index,
                grams: getCachedDailyValue(day: day, weekOffset: offset),
                hasEntries: getCachedHasEntries(day: day, weekOffset: offset)
            )
        }
    }
    
    // Data struct for monthly chart with Date for proper Swift Charts handling
    struct MonthDayFatData: Identifiable {
        var id: Int { day }  // Stable ID based on day number
        let date: Date
        let day: Int
        let grams: Int
        let hasEntries: Bool
    }
    
    // Get chart data for a specific month with actual Date values (cached)
    private func getMonthlyChartData(for offset: Int) -> [MonthDayFatData] {
        // Return cached chart data if available
        if let cached = monthlyChartDataCache[offset] {
            return cached
        }
        
        let calendar = Calendar.current
        let today = Date()
        
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let targetMonthStart = calendar.date(byAdding: .month, value: offset, to: currentMonthStart) else {
            return []
        }
        
        let cachedData = monthlyDataCache[offset]
        
        return getDaysOfMonth(for: offset).compactMap { day in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: targetMonthStart) else {
                return nil
            }
            let fat = cachedData?.dailyData[day] ?? 0
            let hasEntries = cachedData?.hasEntries[day] ?? false
            
            return MonthDayFatData(
                date: date,
                day: day,
                grams: fat,
                hasEntries: hasEntries
            )
        }
    }
    
    // Build and cache chart data for a month offset
    private func buildMonthlyChartDataCache(for offset: Int) {
        let calendar = Calendar.current
        let today = Date()
        
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let targetMonthStart = calendar.date(byAdding: .month, value: offset, to: currentMonthStart) else {
            return
        }
        
        let cachedData = monthlyDataCache[offset]
        let result = getDaysOfMonth(for: offset).compactMap { day -> MonthDayFatData? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: targetMonthStart) else {
                return nil
            }
            let fat = cachedData?.dailyData[day] ?? 0
            let hasEntries = cachedData?.hasEntries[day] ?? false
            
            return MonthDayFatData(
                date: date,
                day: day,
                grams: fat,
                hasEntries: hasEntries
            )
        }
        
        monthlyChartDataCache[offset] = result
    }
    
    // Create the bar chart for a specific week offset using custom implementation
    private func weeklyBarChart(for offset: Int) -> some View {
        let chartData = getWeeklyChartData(for: offset)
        let maxValue = fatTarget * 12 / 10
        let roundedMax = Int(ceil(Double(maxValue) / 10.0) * 10)
        let barEmptyBackground = Color(.systemGray5).opacity(0.5)
        
        return VStack(spacing: 20) {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    // Grid lines
                    VStack(spacing: 0) {
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
                    .allowsHitTesting(false)
                    
                    // Y-axis labels
                    VStack(spacing: 0) {
                        ForEach(0..<5) { i in
                            let value = roundedMax - (roundedMax * i / 4)
                            Text("\(value)")
                                .font(.caption)
                                .foregroundColor(.primary)
                                .frame(height: i < 4 ? geometry.size.height / 5 : 0, alignment: .top)
                        }
                    }
                    .frame(height: geometry.size.height)
                    .allowsHitTesting(false)
                    
                    // Bars
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(chartData) { item in
                            VStack(spacing: 4) {
                                // Bar
                                ZStack(alignment: .bottom) {
                                    // Background
                                    Rectangle()
                                        .fill(barEmptyBackground)
                                        .frame(height: geometry.size.height * 0.8)
                                    
                                    // Data bar
                                    if item.hasEntries {
                                        let barHeight = geometry.size.height * 0.8 * CGFloat(min(item.grams, roundedMax)) / CGFloat(roundedMax)
                                        Rectangle()
                                            .fill(CardType.fat.color)
                                            .frame(height: max(barHeight, 0))
                                    }
                                }
                                .frame(width: 30)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if activeTooltipDay == item.day {
                                        activeTooltipDay = nil
                                    }
                                }
                                .onLongPressGesture(minimumDuration: 0.4, pressing: { isPressing in
                                    if isPressing && item.hasEntries {
                                        activeTooltipDay = item.day
                                    }
                                }, perform: { })
                                .overlay(alignment: .top) {
                                    if activeTooltipDay == item.day && item.hasEntries {
                                        Text("\(item.grams)g")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .frame(minWidth: 70)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(Color.black.opacity(0.8))
                                            )
                                            .offset(y: -35)
                                            .transition(.opacity)
                                            .zIndex(100)
                                    }
                                }
                                
                                // Day label
                                Text(item.day)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.leading, 40)
                    .offset(y: 19)
                    
                    // Target line
                    let targetY = geometry.size.height * 0.8 * (1 - CGFloat(fatTarget) / CGFloat(roundedMax)) + 19
                    Rectangle()
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color.black)
                        .frame(height: 2)
                        .offset(y: targetY)
                        .allowsHitTesting(false)
                }
                .coordinateSpace(name: "fatChartSpace")
            }
            .frame(height: 180)
            
            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(CardType.fat.color)
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                    
                    Text("Consumed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 12, height: 2)
                    
                    Text("Target (\(fatTarget)g)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // Statistic card view
    private func statisticCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    
    // MARK: - Helper Methods
    
    private func getDaysOfWeek(for offset: Int = 0) -> [String] {
        return ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
    }
    
    private func getCachedDailyValue(day: String, weekOffset: Int) -> Int {
        if let cached = weeklyDataCache[weekOffset],
           let value = cached.dailyData[day] {
            return value
        }
        // Return 0 if not cached - data will load async
        return 0
    }
    
    private func getCachedHasEntries(day: String, weekOffset: Int) -> Bool {
        if let cached = weeklyDataCache[weekOffset],
           let hasEntries = cached.hasEntries[day] {
            return hasEntries
        }
        // Return false if not cached - data will load async
        return false
    }
    
    private func getCachedWeeklyAverage(weekOffset: Int) -> Double {
        if let cached = weeklyDataCache[weekOffset] {
            return cached.weeklyAverage
        }
        return 0
    }
    
    private func getCachedWeeklyTotal(weekOffset: Int) -> Int {
        if let cached = weeklyDataCache[weekOffset] {
            return cached.weeklyTotal
        }
        return 0
    }
    
    private func getCachedMonthlyAverage(monthOffset: Int) -> Double {
        if let cached = monthlyDataCache[monthOffset] {
            return cached.monthlyAverage
        }
        return 0
    }
    
    private func getCachedMonthlyTotal(monthOffset: Int) -> Int {
        if let cached = monthlyDataCache[monthOffset] {
            return cached.monthlyTotal
        }
        return 0
    }
    
    private func getDateForDay(_ day: String, weekOffset: Int = 0) -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        // Get the start of the current week (Monday)
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday == 1 ? 6 : weekday - 2
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
            return today
        }
        
        // Apply week offset
        guard let targetWeekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart) else {
            return today
        }
        
        // Map day string to weekday integer
        let dayMap = ["M": 0, "Tu": 1, "W": 2, "Th": 3, "F": 4, "Sa": 5, "Su": 6]
        guard let dayOffset = dayMap[day] else { return today }
        
        return calendar.date(byAdding: .day, value: dayOffset, to: targetWeekStart) ?? today
    }
    
    private func getAllEntriesForDate(_ date: Date) -> [FoodEntry] {
        let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snacks"]
        var allEntries: [FoodEntry] = []
        for mealType in mealTypes {
            allEntries.append(contentsOf: foodLogManager.entries(for: date, mealType: mealType))
        }
        return allEntries
    }
    
    private func weekDateRangeString(for offset: Int = 0) -> String {
        let calendar = Calendar.current
        let today = Date()
        
        // Get Monday of current week
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday == 1 ? 6 : weekday - 2
        guard let currentMonday = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
            return ""
        }
        
        // Apply offset
        guard let targetMonday = calendar.date(byAdding: .weekOfYear, value: offset, to: currentMonday),
              let targetSunday = calendar.date(byAdding: .day, value: 6, to: targetMonday) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startString = formatter.string(from: targetMonday)
        let endString = formatter.string(from: targetSunday)
        
        return "\(startString) - \(endString)"
    }
    
    private func monthDateRangeString(for offset: Int = 0) -> String {
        let calendar = Calendar.current
        let today = Date()
        
        // Get first day of current month
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else {
            return ""
        }
        
        // Apply offset to get target month
        guard let targetMonth = calendar.date(byAdding: .month, value: offset, to: currentMonthStart) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        return formatter.string(from: targetMonth)
    }
    
    // Create the bar chart using Swift Charts with Date-based x-axis (Health app style)
    private func monthlyBarChart(for offset: Int) -> some View {
        let chartData = getMonthlyChartData(for: offset)
        let maxValue = fatTarget * 12 / 10
        let roundedMax = Int(ceil(Double(maxValue) / 10.0) * 10)
        let barColor = CardType.fat.color
        
        // Calculate date range for x-axis scale
        let calendar = Calendar.current
        let today = Date()
        
        // Get the actual month start date for proper label positioning
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? Date()
        let targetMonthStart = calendar.date(byAdding: .month, value: offset, to: currentMonthStart) ?? Date()
        
        // Set x-axis to always span 31 days for consistent label spacing
        let xAxisStart = targetMonthStart
        let xAxisEnd = calendar.date(byAdding: .day, value: 31, to: targetMonthStart) ?? targetMonthStart
        
        // Calculate specific axis label dates from month start (days 1, 5, 10, 15, 20, 25, 30)
        // All labels will be within 31-day range
        let axisLabelDates: [Date] = [1, 5, 10, 15, 20, 25, 30].compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: targetMonthStart)
        }
        
        return VStack(spacing: 20) {
            Chart {
                // Single ForEach drawing both background and data bars per day
                ForEach(chartData) { item in
                    // Background bar (grey, full height)
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        yStart: .value("Start", 0),
                        yEnd: .value("End", roundedMax)
                    )
                    .foregroundStyle(Color(.systemGray5).opacity(0.5))
                    
                    // Data bar (colored, actual value) - drawn on top
                    if item.hasEntries {
                        BarMark(
                            x: .value("Date", item.date, unit: .day),
                            yStart: .value("Start", 0),
                            yEnd: .value("End", min(item.grams, roundedMax))
                        )
                        .foregroundStyle(barColor)
                    }
                }
                
                // Target line
                RuleMark(y: .value("Target", fatTarget))
                    .foregroundStyle(colorScheme == .dark ? Color(.systemGray6) : Color.black)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }
            .chartYScale(domain: 0...roundedMax)
            .chartXScale(domain: xAxisStart...xAxisEnd)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, roundedMax/4, roundedMax/2, roundedMax*3/4, roundedMax]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)")
                                .font(.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: axisLabelDates) { value in
                    if let date = value.as(Date.self) {
                        let day = calendar.component(.day, from: date)
                        let xOffset: CGFloat = (day >= 20) ? -5 : -4
                        AxisValueLabel(format: .dateTime.day())
                            .font(.caption)
                            .offset(x: xOffset)
                    }
                }
            }
            .frame(height: 180)
            
            // Legend
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(barColor)
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                    Text("Consumed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color.black)
                        .frame(width: 20, height: 2)
                    Text("Target (\(fatTarget)g)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // Helper function to get days of the month (auto-scales to only show days with potential data)
    private func getDaysOfMonth(for offset: Int) -> [Int] {
        let calendar = Calendar.current
        let today = Date()
        
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else {
            return Array(1...30)
        }
        
        guard let targetMonth = calendar.date(byAdding: .month, value: offset, to: currentMonthStart) else {
            return Array(1...30)
        }
        
        let range = calendar.range(of: .day, in: .month, for: targetMonth) ?? 1..<31
        let daysInMonth = Array(range)
        
        // For current month (offset == 0), only show days up to today
        if offset == 0 {
            let todayDay = calendar.component(.day, from: today)
            return daysInMonth.filter { $0 <= todayDay }
        }
        
        // For past months, show all days
        return daysInMonth
    }
    
    // Helper function to get monthly daily value
    private func getMonthlyDailyValue(day: Int, monthOffset: Int) -> Int {
        let calendar = Calendar.current
        let today = Date()
        
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else {
            return 0
        }
        
        guard let targetMonth = calendar.date(byAdding: .month, value: monthOffset, to: currentMonthStart),
              let targetDate = calendar.date(byAdding: .day, value: day - 1, to: targetMonth) else {
            return 0
        }
        
        let dayEntries = foodLogManager.entries.filter { calendar.isDate($0.dateAdded, inSameDayAs: targetDate) }
        return Int(dayEntries.reduce(0.0) { $0 + $1.totalFat })
    }
    
    // Helper function to check if day has entries in month
    private func getMonthlyHasEntries(day: Int, monthOffset: Int) -> Bool {
        return getMonthlyDailyValue(day: day, monthOffset: monthOffset) > 0
    }
    
    // MARK: - Shared Cache Integration
    
    /// Load weekly data from shared cache
    private func loadFromSharedCache(weekOffset: Int) -> WeeklyMacroData? {
        guard let cached = cacheManager.getWeeklyMacroCache(for: .fat, weekOffset: weekOffset) else {
            return nil
        }
        return WeeklyMacroData(
            dailyData: cached.dailyData,
            hasEntries: cached.hasEntries,
            weeklyAverage: cached.weeklyAverage,
            weeklyTotal: cached.weeklyTotal
        )
    }
    
    /// Save weekly data to shared cache
    private func saveToSharedCache(_ data: WeeklyMacroData, weekOffset: Int) {
        let cache = ChartDataCacheManager.WeeklyMacroCache(
            weekOffset: weekOffset,
            dailyData: data.dailyData,
            hasEntries: data.hasEntries,
            weeklyAverage: data.weeklyAverage,
            weeklyTotal: data.weeklyTotal,
            timestamp: Date(),
            dataHash: foodLogManager.entries.count
        )
        cacheManager.setWeeklyMacroCache(cache, for: .fat)
    }
    
    /// Load monthly data from shared cache
    private func loadMonthlyFromSharedCache(monthOffset: Int) -> MonthlyMacroData? {
        guard let cached = cacheManager.getMonthlyMacroCache(for: .fat, monthOffset: monthOffset) else {
            return nil
        }
        
        return MonthlyMacroData(
            dailyData: cached.dailyData,
            hasEntries: cached.hasEntries,
            monthlyAverage: cached.monthlyAverage,
            monthlyTotal: cached.monthlyTotal
        )
    }
    
    /// Save monthly data to shared cache
    private func saveMonthlyToSharedCache(_ data: MonthlyMacroData, monthOffset: Int) {
        let cache = ChartDataCacheManager.MonthlyMacroCache(
            monthOffset: monthOffset,
            dailyData: data.dailyData,
            hasEntries: data.hasEntries,
            monthlyAverage: data.monthlyAverage,
            monthlyTotal: data.monthlyTotal,
            timestamp: Date(),
            dataHash: foodLogManager.entries.count
        )
        cacheManager.setMonthlyMacroCache(cache, for: .fat)
    }
}
