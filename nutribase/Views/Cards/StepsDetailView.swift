import SwiftUI
import Charts

struct StepsDetailView: View {
    @ObservedObject var activityManager: ActivityManager
    @ObservedObject var healthKitManager: HealthKitManager
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    
    private var viewBackground: Color {
        Color.appBackground
    }
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    @State private var currentWeekOffset: Int = 0
    @State private var animationOpacity: Double = 1.0
    
    // State for tooltip display
    @State private var activeTooltipDay: String? = nil
    @State private var activeTooltipMonthDay: Int? = nil
    @State private var barPositions: [CGFloat] = Array(repeating: 0, count: 7)
    @State private var monthBarPositions: [CGFloat] = Array(repeating: 0, count: 31)
    
    // View mode state
    enum ViewMode: String, CaseIterable {
        case weekly = "Weekly"
        case monthly = "Monthly"
    }
    @State private var viewMode: ViewMode = .weekly
    
    // Shared cache manager for persistent caching across view lifecycle
    private let cacheManager = ChartDataCacheManager.shared
    
    // Local cache for immediate access (synced with shared cache)
    @State private var weeklyDataCache: [Int: WeeklyStepsData] = [:]
    @State private var isLoadingWeek = false
    
    // Cache for monthly data
    @State private var monthlyDataCache: [Int: MonthlyStepsData] = [:]
    @State private var isLoadingMonth = false
    
    // Struct to hold pre-computed weekly data
    struct WeeklyStepsData {
        let dailyData: [String: Int] // Day -> steps
        let hasData: [String: Bool] // Day -> hasData
        let weeklyAverage: Double
        let weeklyTotal: Int
    }
    
    // Struct to hold pre-computed monthly data
    struct MonthlyStepsData {
        let dailyData: [Int: Int] // Day number -> steps
        let hasData: [Int: Bool] // Day number -> hasData
        let monthlyAverage: Double
        let monthlyTotal: Int
    }
    
    var stepsGoal: Int {
        return UserDefaults.standard.integer(forKey: "stepsGoal") > 0 ? 
               UserDefaults.standard.integer(forKey: "stepsGoal") : 10000
    }
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        
        NavigationView {
            ZStack {
                viewBackground
                    .ignoresSafeArea()
                
                if !healthKitManager.isAuthorized {
                    // Empty state when HealthKit is not connected
                    self.healthKitEmptyStateView
                } else {
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
                                // Pre-cache current week first (priority), then adjacent weeks in parallel
                                Task(priority: .userInitiated) {
                                    // Load current week first for immediate display
                                    if weeklyDataCache[0] == nil {
                                        let data = await computeWeeklyData(for: 0)
                                        await MainActor.run { weeklyDataCache[0] = data }
                                    }
                                    
                                    // Then load adjacent weeks in parallel
                                    await withTaskGroup(of: (Int, WeeklyStepsData).self) { group in
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
                                    value: formatSteps(Int(viewMode == .weekly ? getCachedWeeklyAverage(weekOffset: currentWeekOffset) : getCachedMonthlyAverage(monthOffset: currentWeekOffset))),
                                    subtitle: "per day",
                                    color: Color(hex: "#35b8ff")
                                )
                                
                                statisticCard(
                                    title: viewMode == .weekly ? "Weekly Total" : "Monthly Total",
                                    value: formatSteps(viewMode == .weekly ? getCachedWeeklyTotal(weekOffset: currentWeekOffset) : getCachedMonthlyTotal(monthOffset: currentWeekOffset)),
                                    subtitle: viewMode == .weekly ? "this week" : "this month",
                                    color: Color(hex: "#35b8ff")
                                )
                                
                                statisticCard(
                                    title: "Target",
                                    value: formatSteps(stepsGoal),
                                    subtitle: "per day",
                                    color: .secondary
                                )
                                
                                statisticCard(
                                    title: viewMode == .weekly ? "Weekly Goal" : "Monthly Goal",
                                    value: formatSteps(viewMode == .weekly ? stepsGoal * 7 : stepsGoal * 30),
                                    subtitle: "target",
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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("Steps Details")
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
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onChange(of: viewMode) { oldMode, newMode in
                // Pre-cache monthly data when switching to monthly view
                if newMode == .monthly {
                    Task(priority: .userInitiated) {
                        // Load current month first for immediate display
                        if monthlyDataCache[0] == nil {
                            let data = await computeMonthlyData(for: 0)
                            await MainActor.run { monthlyDataCache[0] = data }
                        }
                        
                        // Then load adjacent months in parallel
                        await withTaskGroup(of: (Int, MonthlyStepsData).self) { group in
                            for offset in [-1, 1] {
                                if monthlyDataCache[offset] == nil {
                                    group.addTask {
                                        let data = await computeMonthlyData(for: offset)
                                        return (offset, data)
                                    }
                                }
                            }
                            for await (offset, data) in group {
                                await MainActor.run { monthlyDataCache[offset] = data }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Helper function to update current week with animation
    private func updateCurrentWeek(to offset: Int) {
        if currentWeekOffset != offset {
            // Dismiss tooltip when scrolling to a new week
            activeTooltipDay = nil
            activeTooltipMonthDay = nil
            
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
    
    // Compute all data for a week in background using batch fetch
    private func computeWeeklyData(for offset: Int) async -> WeeklyStepsData {
        let days = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
        let calendar = Calendar.current
        
        // Get the start and end of the week
        let mondayDate = getDateForDay("M", weekOffset: offset)
        let weekStart = calendar.startOfDay(for: mondayDate)
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return WeeklyStepsData(dailyData: [:], hasData: [:], weeklyAverage: 0, weeklyTotal: 0)
        }
        
        // Batch fetch all days at once - much faster than individual queries
        let stepsData = await withCheckedContinuation { continuation in
            healthKitManager.fetchDailyStepsForRange(start: weekStart, end: weekEnd) { dailySteps in
                continuation.resume(returning: dailySteps)
            }
        }
        
        var dailyData: [String: Int] = [:]
        var hasData: [String: Bool] = [:]
        var weeklyTotal = 0
        var daysWithData = 0
        
        for (index, day) in days.enumerated() {
            guard let dayDate = calendar.date(byAdding: .day, value: index, to: weekStart) else { continue }
            let dayStart = calendar.startOfDay(for: dayDate)
            let steps = stepsData[dayStart] ?? 0
            
            dailyData[day] = steps
            hasData[day] = steps > 0
            
            if steps > 0 {
                weeklyTotal += steps
                daysWithData += 1
            }
        }
        
        let weeklyAverage = daysWithData > 0 ? Double(weeklyTotal) / Double(daysWithData) : 0
        
        return WeeklyStepsData(
            dailyData: dailyData,
            hasData: hasData,
            weeklyAverage: weeklyAverage,
            weeklyTotal: weeklyTotal
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
    struct DayStepsData: Identifiable {
        let id = UUID()
        let day: String
        let dayIndex: Int
        let steps: Int
        let hasData: Bool
    }
    
    // Get chart data for a specific week
    private func getWeeklyChartData(for offset: Int) -> [DayStepsData] {
        let days = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
        return days.enumerated().map { index, day in
            DayStepsData(
                day: day,
                dayIndex: index,
                steps: getCachedDailyValue(day: day, weekOffset: offset),
                hasData: getCachedHasData(day: day, weekOffset: offset)
            )
        }
    }
    
    // Data struct for monthly chart with Date for proper Swift Charts handling
    struct MonthDayStepsData: Identifiable {
        var id: Int { day }  // Stable ID based on day number
        let date: Date
        let day: Int
        let steps: Int
        let hasData: Bool
    }
    
    // Get chart data for a specific month with actual Date values - uses cached data for performance
    private func getMonthlyChartData(for offset: Int) -> [MonthDayStepsData] {
        let calendar = Calendar.current
        let today = Date()
        
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let targetMonthStart = calendar.date(byAdding: .month, value: offset, to: currentMonthStart) else {
            return []
        }
        
        // Use cached data if available for much better performance
        let cachedData = monthlyDataCache[offset]
        
        return getDaysOfMonth(for: offset).compactMap { day in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: targetMonthStart) else {
                return nil
            }
            
            // Use cached values if available
            let steps = cachedData?.dailyData[day] ?? 0
            let hasData = cachedData?.hasData[day] ?? false
            
            return MonthDayStepsData(
                date: date,
                day: day,
                steps: steps,
                hasData: hasData
            )
        }
    }
    
    // Create the bar chart for a specific week offset using custom implementation
    private func weeklyBarChart(for offset: Int) -> some View {
        let chartData = getWeeklyChartData(for: offset)
        let maxValue = stepsGoal * 12 / 10
        let roundedMax = Int(ceil(Double(maxValue) / 1000.0) * 1000)
        let barEmptyBackground = Color.appInsetBackground
        
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
                            Text(formatSteps(value))
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
                                    if item.hasData {
                                        let barHeight = geometry.size.height * 0.8 * CGFloat(min(item.steps, roundedMax)) / CGFloat(roundedMax)
                                        Rectangle()
                                            .fill(Color(hex: "#35b8ff"))
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
                                    if isPressing && item.hasData {
                                        activeTooltipDay = item.day
                                    }
                                }, perform: { })
                                .overlay(alignment: .top) {
                                    if activeTooltipDay == item.day && item.hasData {
                                        Text(formatSteps(item.steps))
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
                    let targetY = geometry.size.height * 0.8 * (1 - CGFloat(stepsGoal) / CGFloat(roundedMax)) + 19
                    Rectangle()
                        .fill(Color.primary)
                        .frame(height: 2)
                        .offset(y: targetY)
                        .allowsHitTesting(false)
                }
                .coordinateSpace(name: "stepsChartSpace")
            }
            .frame(height: 180)
            
            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color(hex: "#35b8ff"))
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                    
                    Text("Steps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 12, height: 2)
                    
                    Text("Target (\(formatSteps(stepsGoal)))")
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
    
    private func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
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
        return 0
    }
    
    private func getCachedHasData(day: String, weekOffset: Int) -> Bool {
        if let cached = weeklyDataCache[weekOffset],
           let hasData = cached.hasData[day] {
            return hasData
        }
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
        let maxValue = stepsGoal * 12 / 10
        let roundedMax = Int(ceil(Double(maxValue) / 1000.0) * 1000)
        let barColor = Color(hex: "#35b8ff")
        
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
                    .foregroundStyle(Color.appInsetBackground)
                    
                    // Data bar (colored, actual value) - drawn on top
                    if item.hasData {
                        BarMark(
                            x: .value("Date", item.date, unit: .day),
                            yStart: .value("Start", 0),
                            yEnd: .value("End", min(item.steps, roundedMax))
                        )
                        .foregroundStyle(barColor)
                    }
                }
                
                // Target line
                RuleMark(y: .value("Target", stepsGoal))
                    .foregroundStyle(Color.primary)
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
                            Text(formatSteps(intValue))
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
                    Text("Steps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 20, height: 2)
                    Text("Target (\(formatSteps(stepsGoal)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            loadMonthlyData(for: offset)
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
    
    // Helper function to get cached monthly daily steps
    private func getCachedMonthlyDailySteps(day: Int, monthOffset: Int) -> Int {
        if let cached = monthlyDataCache[monthOffset] {
            return cached.dailyData[day] ?? 0
        }
        return 0
    }
    
    // Helper function to check if day has data in month (cached)
    private func getCachedMonthlyHasData(day: Int, monthOffset: Int) -> Bool {
        if let cached = monthlyDataCache[monthOffset] {
            return cached.hasData[day] ?? false
        }
        return false
    }
    
    // Helper function to get cached monthly average
    private func getCachedMonthlyAverage(monthOffset: Int) -> Double {
        if let cached = monthlyDataCache[monthOffset] {
            return cached.monthlyAverage
        }
        return 0
    }
    
    // Helper function to get cached monthly total
    private func getCachedMonthlyTotal(monthOffset: Int) -> Int {
        if let cached = monthlyDataCache[monthOffset] {
            return cached.monthlyTotal
        }
        return 0
    }
    
    // Load monthly data asynchronously
    private func loadMonthlyData(for monthOffset: Int) {
        guard monthlyDataCache[monthOffset] == nil && !isLoadingMonth else { return }
        
        isLoadingMonth = true
        
        Task {
            let data = await computeMonthlyData(for: monthOffset)
            DispatchQueue.main.async {
                self.monthlyDataCache[monthOffset] = data
                self.isLoadingMonth = false
            }
        }
    }
    
    // Compute all data for a month in background using batch fetch
    private func computeMonthlyData(for offset: Int) async -> MonthlyStepsData {
        let calendar = Calendar.current
        let today = Date()
        
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let targetMonth = calendar.date(byAdding: .month, value: offset, to: currentMonthStart),
              let monthRange = calendar.range(of: .day, in: .month, for: targetMonth),
              let monthEnd = calendar.date(byAdding: .day, value: monthRange.count, to: targetMonth) else {
            return MonthlyStepsData(dailyData: [:], hasData: [:], monthlyAverage: 0, monthlyTotal: 0)
        }
        
        // Batch fetch all days at once - single query instead of 28-31 queries
        let stepsData = await withCheckedContinuation { continuation in
            healthKitManager.fetchDailyStepsForRange(start: targetMonth, end: monthEnd) { dailySteps in
                continuation.resume(returning: dailySteps)
            }
        }
        
        var dailyData: [Int: Int] = [:]
        var hasData: [Int: Bool] = [:]
        var monthlyTotal = 0
        var daysWithData = 0
        
        for day in 1...monthRange.count {
            guard let dayDate = calendar.date(byAdding: .day, value: day - 1, to: targetMonth) else { continue }
            let dayStart = calendar.startOfDay(for: dayDate)
            let steps = stepsData[dayStart] ?? 0
            
            dailyData[day] = steps
            hasData[day] = steps > 0
            
            if steps > 0 {
                monthlyTotal += steps
                daysWithData += 1
            }
        }
        
        let monthlyAverage = daysWithData > 0 ? Double(monthlyTotal) / Double(daysWithData) : 0
        
        return MonthlyStepsData(
            dailyData: dailyData,
            hasData: hasData,
            monthlyAverage: monthlyAverage,
            monthlyTotal: monthlyTotal
        )
    }
    
    // Empty state view when HealthKit is not connected
    private var healthKitEmptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#35b8ff"))
            
            // Title
            Text("Connect Apple Health")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            Text("To track your steps, you need to connect Nutribase to Apple Health.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                instructionRow(number: "1", text: "Open the Settings app on your iPhone")
                instructionRow(number: "2", text: "Scroll down and tap 'Health'")
                instructionRow(number: "3", text: "Tap 'Data Access & Devices'")
                instructionRow(number: "4", text: "Tap 'Nutribase'")
                instructionRow(number: "5", text: "Turn on 'Steps'")
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
            .padding(.horizontal, 24)
            
            // Request Permission Button
            Button(action: {
                self.healthKitManager.requestAuthorization { success, error in
                    if success {
                        print("HealthKit authorized successfully")
                    } else {
                        print("HealthKit authorization failed: \(error?.localizedDescription ?? "unknown error")")
                    }
                }
            }) {
                HStack {
                    Image(systemName: "heart.fill")
                    Text("Request Access")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#35b8ff"))
                )
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(.vertical, 40)
    }
    
    // Helper view for instruction rows
    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color(hex: "#35b8ff"))
                )
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

// Tooltip view for displaying daily steps values on long press
struct StepsTooltip: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let day: String
    let steps: Int
    let target: Int
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    var percentage: Int {
        guard target > 0 else { return 0 }
        return Int((Double(steps) / Double(target)) * 100)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dayName)
                .font(.headline)
                .padding(.bottom, 2)
            
            HStack(spacing: 8) {
                Text("Steps")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatSteps(steps))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#35b8ff"))
            }
            
            HStack(spacing: 8) {
                Text("Target")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatSteps(target))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Divider()
            
            HStack(spacing: 8) {
                Text("Progress")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(percentage)%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(percentage >= 100 ? .green : Color(hex: "#35b8ff"))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
        )
        .frame(width: 140)
    }
    
    private var dayName: String {
        let dayMap = [
            "M": "Monday",
            "Tu": "Tuesday",
            "W": "Wednesday",
            "Th": "Thursday",
            "F": "Friday",
            "Sa": "Saturday",
            "Su": "Sunday"
        ]
        return dayMap[day] ?? day
    }
    
    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            let thousands = Double(steps) / 1000.0
            return String(format: "%.1fk", thousands)
        }
        return "\(steps)"
    }
}
