import SwiftUI
import Charts

struct FibreDetailView: View {
    @ObservedObject var foodLogManager: FoodLogManager
    @ObservedObject var userProfile: UserProfile
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    
    private var viewBackground: Color {
        Color.appBackground
    }
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    @State private var currentWeekOffset: Int = 0
    @State private var currentMonthOffset: Int = 0
    @State private var scrolledWeekID: Int? = 0
    @State private var animationOpacity: Double = 1.0
    
    @State private var activeTooltipDay: String? = nil
    @State private var barPositions: [CGFloat] = Array(repeating: 0, count: 7)
    
    enum ViewMode: String, CaseIterable {
        case weekly = "Weekly"
        case monthly = "Monthly"
    }
    @State private var viewMode: ViewMode = .weekly
    
    private let cacheManager = ChartDataCacheManager.shared
    
    @State private var weeklyDataCache: [Int: WeeklyMacroData] = [:]
    @State private var monthlyDataCache: [Int: MonthlyMacroData] = [:]
    @State private var monthlyChartDataCache: [Int: [MonthDayFibreData]] = [:]
    
    struct WeeklyMacroData {
        let dailyData: [String: Int]
        let hasEntries: [String: Bool]
        let weeklyAverage: Double
        let weeklyTotal: Int
    }
    
    struct MonthlyMacroData {
        let dailyData: [Int: Int]
        let hasEntries: [Int: Bool]
        let monthlyAverage: Double
        let monthlyTotal: Int
    }
    
    var fibreTarget: Int {
        return userProfile.fibreGoalGrams > 0 ? userProfile.fibreGoalGrams : 30
    }
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        
        NavigationView {
            ZStack {
                viewBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 20) {
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
                        .scrollPosition(id: $scrolledWeekID)
                        .defaultScrollAnchor(.trailing)
                        .onChange(of: scrolledWeekID) { _, newValue in
                            if let newValue = newValue {
                                updateCurrentWeek(to: newValue)
                            }
                        }
                        .onAppear {
                            // Prefetch fiber estimates for all entries in recent days
                            let calendar = Calendar.current
                            let recentEntries = foodLogManager.entries.filter {
                                let daysDiff = calendar.dateComponents([.day], from: $0.dateAdded, to: Date()).day ?? 0
                                return daysDiff <= 7
                            }
                            FiberEstimationService.shared.prefetchEstimates(for: recentEntries)
                            
                            // Pre-cache current week and several adjacent weeks in parallel
                            Task(priority: .userInitiated) {
                                await withTaskGroup(of: (Int, WeeklyMacroData).self) { group in
                                    for offset in -4...0 {
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
                        }
                        .frame(height: 320)
                        
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
                                    color: CardType.fibre.color
                                )
                                
                                statisticCard(
                                    title: "Target",
                                    value: "\(fibreTarget)g",
                                    subtitle: "per day",
                                    color: .secondary
                                )
                            }
                        }
                        .opacity(animationOpacity)
                        .padding(.horizontal)
                        
                        // MARK: - Daily Food Breakdown
                        dailyFoodBreakdownSection
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("Fibre Details")
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
                if newMode == .monthly {
                    preloadMonthlyData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .foodLogUpdated)) { _ in
                // Clear local caches and re-compute when food log data changes (e.g. fiber migration)
                weeklyDataCache.removeAll()
                monthlyDataCache.removeAll()
                monthlyChartDataCache.removeAll()
                Task(priority: .userInitiated) {
                    let data = await computeWeeklyData(for: currentWeekOffset)
                    await MainActor.run { weeklyDataCache[currentWeekOffset] = data }
                }
            }
        }
    }
    
    private func preloadMonthlyData() {
        Task(priority: .userInitiated) {
            if monthlyDataCache[0] == nil {
                let data = await computeMonthlyData(for: 0)
                await MainActor.run {
                    monthlyDataCache[0] = data
                    buildMonthlyChartDataCache(for: 0)
                }
            } else {
                await MainActor.run { buildMonthlyChartDataCache(for: 0) }
            }
            
            await withTaskGroup(of: (Int, MonthlyMacroData).self) { group in
                for offset in [-1, -2, -3] {
                    if monthlyDataCache[offset] == nil {
                        group.addTask {
                            let data = await self.computeMonthlyData(for: offset)
                            return (offset, data)
                        }
                    }
                }
                for await (offset, data) in group {
                    await MainActor.run {
                        monthlyDataCache[offset] = data
                        buildMonthlyChartDataCache(for: offset)
                    }
                }
            }
        }
    }
    
    private func updateCurrentWeek(to offset: Int) {
        let hasChanged = viewMode == .weekly ? (currentWeekOffset != offset) : (currentMonthOffset != offset)
        
        if hasChanged {
            activeTooltipDay = nil
            
            // Update state immediately for responsive UI (no delay)
            if viewMode == .weekly {
                currentWeekOffset = offset
            } else {
                currentMonthOffset = offset
            }
            
            // Pre-cache current and adjacent weeks in background
            Task(priority: .userInitiated) {
                if viewMode == .weekly {
                    if weeklyDataCache[offset] == nil {
                        let data = await self.computeWeeklyData(for: offset)
                        await MainActor.run { weeklyDataCache[offset] = data }
                    }
                    // Pre-cache adjacent weeks
                    for adjacent in [offset - 1, offset + 1] {
                        if weeklyDataCache[adjacent] == nil {
                            let data = await self.computeWeeklyData(for: adjacent)
                            await MainActor.run { weeklyDataCache[adjacent] = data }
                        }
                    }
                } else {
                    if monthlyDataCache[offset] == nil {
                        let data = await self.computeMonthlyData(for: offset)
                        await MainActor.run {
                            monthlyDataCache[offset] = data
                            buildMonthlyChartDataCache(for: offset)
                        }
                    } else if monthlyChartDataCache[offset] == nil {
                        await MainActor.run { buildMonthlyChartDataCache(for: offset) }
                    }
                }
            }
        }
    }
    
    private func computeWeeklyData(for offset: Int) async -> WeeklyMacroData {
        let days = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
        var dailyData: [String: Int] = [:]
        var hasEntries: [String: Bool] = [:]
        var weeklyTotal = 0
        var daysWithData = 0
        
        for day in days {
            let date = getDateForDay(day, weekOffset: offset)
            let fibre = foodLogManager.totalFibreForDay(date: date)
            let entries = getAllEntriesForDate(date)
            
            dailyData[day] = fibre
            hasEntries[day] = !entries.isEmpty
            
            if !entries.isEmpty {
                weeklyTotal += fibre
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
            
            let fibre = foodLogManager.totalFibreForDay(date: dayDate)
            let entries = getAllEntriesForDate(dayDate)
            
            dailyData[day] = fibre
            hasEntries[day] = !entries.isEmpty
            
            if !entries.isEmpty {
                monthlyTotal += fibre
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
    
    private func weeklyChartCard(for offset: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewMode == .weekly ? "Weekly Average" : "Monthly Average")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(viewMode == .weekly ? weekDateRangeString(for: offset) : monthDateRangeString(for: offset))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            
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
    
    struct DayFibreData: Identifiable {
        var id: Int { dayIndex }
        let day: String
        let dayIndex: Int
        let grams: Int
        let hasEntries: Bool
    }
    
    private func getWeeklyChartData(for offset: Int) -> [DayFibreData] {
        let days = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
        return days.enumerated().map { index, day in
            DayFibreData(
                day: day,
                dayIndex: index,
                grams: getCachedDailyValue(day: day, weekOffset: offset),
                hasEntries: getCachedHasEntries(day: day, weekOffset: offset)
            )
        }
    }
    
    struct MonthDayFibreData: Identifiable {
        var id: Int { day }
        let date: Date
        let day: Int
        let grams: Int
        let hasEntries: Bool
    }
    
    private func getMonthlyChartData(for offset: Int) -> [MonthDayFibreData] {
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
            let fibre = cachedData?.dailyData[day] ?? 0
            let hasEntries = cachedData?.hasEntries[day] ?? false
            
            return MonthDayFibreData(
                date: date,
                day: day,
                grams: fibre,
                hasEntries: hasEntries
            )
        }
    }
    
    private func buildMonthlyChartDataCache(for offset: Int) {
        let calendar = Calendar.current
        let today = Date()
        
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let targetMonthStart = calendar.date(byAdding: .month, value: offset, to: currentMonthStart) else {
            return
        }
        
        let cachedData = monthlyDataCache[offset]
        let result = getDaysOfMonth(for: offset).compactMap { day -> MonthDayFibreData? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: targetMonthStart) else {
                return nil
            }
            let fibre = cachedData?.dailyData[day] ?? 0
            let hasEntries = cachedData?.hasEntries[day] ?? false
            
            return MonthDayFibreData(
                date: date,
                day: day,
                grams: fibre,
                hasEntries: hasEntries
            )
        }
        
        monthlyChartDataCache[offset] = result
    }
    
    private func weeklyBarChart(for offset: Int) -> some View {
        let chartData = getWeeklyChartData(for: offset)
        let maxValue = fibreTarget * 12 / 10
        let roundedMax = Int(ceil(Double(maxValue) / 10.0) * 10)
        let barEmptyBackground = Color.appInsetBackground
        
        return VStack(spacing: 20) {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
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
                    
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(chartData) { item in
                            VStack(spacing: 4) {
                                ZStack(alignment: .bottom) {
                                    Rectangle()
                                        .fill(barEmptyBackground)
                                        .frame(height: geometry.size.height * 0.8)
                                    
                                    if item.hasEntries {
                                        let barHeight = geometry.size.height * 0.8 * CGFloat(min(item.grams, roundedMax)) / CGFloat(roundedMax)
                                        Rectangle()
                                            .fill(CardType.fibre.color)
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
                                
                                Text(item.day)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.leading, 40)
                    .offset(y: 19)
                    
                    let targetY = geometry.size.height * 0.8 * (1 - CGFloat(fibreTarget) / CGFloat(roundedMax)) + 19
                    Rectangle()
                        .fill(Color.primary)
                        .frame(height: 2)
                        .offset(y: targetY)
                        .allowsHitTesting(false)
                }
                .coordinateSpace(name: "fibreChartSpace")
            }
            .frame(height: 180)
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(CardType.fibre.color)
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                    
                    Text("Consumed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 12, height: 2)
                    
                    Text("Target (\(fibreTarget)g)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func monthlyBarChart(for offset: Int) -> some View {
        let chartData = getMonthlyChartData(for: offset)
        let maxValue = fibreTarget * 12 / 10
        let roundedMax = Int(ceil(Double(maxValue) / 10.0) * 10)
        let barEmptyBackground = Color.appInsetBackground
        
        return VStack(spacing: 12) {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
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
                    
                    HStack(alignment: .bottom, spacing: 1) {
                        ForEach(chartData) { item in
                            ZStack(alignment: .bottom) {
                                Rectangle()
                                    .fill(barEmptyBackground)
                                    .frame(height: geometry.size.height * 0.8)
                                
                                if item.hasEntries {
                                    let barHeight = geometry.size.height * 0.8 * CGFloat(min(item.grams, roundedMax)) / CGFloat(roundedMax)
                                    Rectangle()
                                        .fill(CardType.fibre.color)
                                        .frame(height: max(barHeight, 0))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.leading, 40)
                    .offset(y: 19)
                    
                    let targetY = geometry.size.height * 0.8 * (1 - CGFloat(fibreTarget) / CGFloat(roundedMax)) + 19
                    Rectangle()
                        .fill(Color.primary)
                        .frame(height: 2)
                        .offset(y: targetY)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 180)
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(CardType.fibre.color)
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                    
                    Text("Consumed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 12, height: 2)
                    
                    Text("Target (\(fibreTarget)g)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
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
    
    // MARK: - Daily Food Breakdown
    
    private var dailyFoodBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Breakdown")
                .font(.headline)
                .padding(.bottom, 4)
            
            let days = getWeekDatesForCurrentOffset()
            
            ForEach(days, id: \.date) { dayInfo in
                let entries = getAllEntriesForDate(dayInfo.date)
                let expandedItems = foodLogManager.expandedFoodItems(for: entries)
                let fibreItems = expandedItems.filter { $0.fibre > 0 }
                let dayHasEstimates = expandedItems.contains { $0.fibreIsEstimated }
                
                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(dayInfo.label)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            let dayTotal = Int(expandedItems.reduce(0.0) { $0 + $1.fibre })
                            let dayPrefix = dayHasEstimates ? "~" : ""
                            Text("\(dayPrefix)\(dayTotal)g")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(CardType.fibre.color)
                        }
                        
                        if fibreItems.isEmpty {
                            Text("No fibre data recorded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(Array(fibreItems.enumerated()), id: \.offset) { index, item in
                                HStack {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    let itemPrefix = item.fibreIsEstimated ? "~" : ""
                                    Text("\(itemPrefix)\(String(format: "%.1fg", item.fibre))")
                                        .font(.subheadline)
                                        .foregroundColor(item.fibreIsEstimated ? .orange : .secondary)
                                }
                                .padding(.vertical, 2)
                                
                                if index < fibreItems.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBackground)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                    )
                }
            }
        }
    }
    
    struct DayInfo {
        let date: Date
        let label: String
    }
    
    private func getWeekDatesForCurrentOffset() -> [DayInfo] {
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)
        if viewMode == .weekly {
            let days = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
            return days.reversed().compactMap { day in
                let date = getDateForDay(day, weekOffset: currentWeekOffset)
                let dateStart = calendar.startOfDay(for: date)
                // Don't show future dates (compare using start of day to ensure today is included)
                guard dateStart <= todayStart else { return nil }
                return DayInfo(date: date, label: Self.dayLabelFormatter.string(from: date))
            }
        } else {
            // Monthly: show last 7 days of data for the month
            let daysOfMonth = getDaysOfMonth(for: currentMonthOffset)
            guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                  let targetMonthStart = calendar.date(byAdding: .month, value: currentMonthOffset, to: currentMonthStart) else {
                return []
            }
            
            return daysOfMonth.reversed().prefix(14).compactMap { day in
                guard let date = calendar.date(byAdding: .day, value: day - 1, to: targetMonthStart) else { return nil }
                let dateStart = calendar.startOfDay(for: date)
                guard dateStart <= todayStart else { return nil }
                return DayInfo(date: date, label: Self.dayLabelFormatter.string(from: date))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getDaysOfWeek(for offset: Int = 0) -> [String] {
        return ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
    }
    
    private func getDaysOfMonth(for offset: Int) -> [Int] {
        let calendar = Calendar.current
        let today = Date()
        
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let targetMonth = calendar.date(byAdding: .month, value: offset, to: currentMonthStart),
              let monthRange = calendar.range(of: .day, in: .month, for: targetMonth) else {
            return []
        }
        
        return Array(1...monthRange.count)
    }
    
    private func getCachedDailyValue(day: String, weekOffset: Int) -> Int {
        if let cached = weeklyDataCache[weekOffset],
           let value = cached.dailyData[day] {
            return value
        }
        return 0
    }
    
    private func getCachedHasEntries(day: String, weekOffset: Int) -> Bool {
        if let cached = weeklyDataCache[weekOffset],
           let hasEntries = cached.hasEntries[day] {
            return hasEntries
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
        
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday == 1 ? 6 : weekday - 2
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
            return today
        }
        
        guard let targetWeekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart) else {
            return today
        }
        
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
        
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday == 1 ? 6 : weekday - 2
        guard let currentMonday = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
            return ""
        }
        
        guard let targetMonday = calendar.date(byAdding: .weekOfYear, value: offset, to: currentMonday),
              let targetSunday = calendar.date(byAdding: .day, value: 6, to: targetMonday) else {
            return ""
        }
        
        let startString = Self.weekRangeFormatter.string(from: targetMonday)
        let endString = Self.weekRangeFormatter.string(from: targetSunday)
        
        return "\(startString) - \(endString)"
    }
    
    private func monthDateRangeString(for offset: Int = 0) -> String {
        let calendar = Calendar.current
        let today = Date()
        
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let targetMonth = calendar.date(byAdding: .month, value: offset, to: currentMonthStart) else {
            return ""
        }
        
        return Self.monthRangeFormatter.string(from: targetMonth)
    }
    
    // MARK: - Static Date Formatters
    
    private static let weekRangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    private static let monthRangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private static let dayLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()
}

#Preview {
    FibreDetailView(foodLogManager: FoodLogManager.shared, userProfile: UserProfile.shared)
}
