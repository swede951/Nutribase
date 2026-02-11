//
//  YearCalendarView.swift
//  nutribase
//
//  Created on 24/08/2025.
//

import SwiftUI
import Charts

// Simple SwiftUI Calendar implementation
public struct YearCalendarView: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var phaseManager = WeightPhaseManager.shared
    @StateObject private var weightManager = WeightLogManager.shared
    
    // Performance: Use cached calendar and formatters
    private let performanceCache = PerformanceCache.shared
    
    // Dashboard-matching colors
    private var scrollBackground: Color {
        Color.appBackground
    }
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    // MARK: - Cached Data for Performance
    @State private var phaseLookup: [String: WeightPhase?] = [:]
    @State private var chartDataReady = false
    @State private var cachedYearEntries: [WeightLogEntry] = []
    @State private var cachedYearPhases: [WeightPhase] = []
    @State private var cachedSmoothedEntries: [WeightLogEntry] = []
    @State private var cachedMinWeight: Double = 60
    @State private var cachedMaxWeight: Double = 80
    
    // Performance: Pre-computed month grid cache for the year
    @State private var cachedMonthGrids: [Int: MonthGridData] = [:]
    @State private var monthGridsReady = false
    
    @State private var currentYear = Calendar.current.component(.year, from: Date())
    
    // Crosshair interaction
    @State private var selectedIndex: Int? = nil
    @State private var lastSelectedIndex: Int? = nil
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    
    public init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
    }
    private let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                             "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    
    // Performance: Use cached calendar
    private var calendar: Calendar {
        performanceCache.calendar
    }
    
    // Cached date formatter for phase lookup
    private static let phaseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    // MARK: - Phase Lookup Cache
    private func buildPhaseLookup() {
        var lookup: [String: WeightPhase?] = [:]
        let cal = performanceCache.calendar
        
        // Pre-compute phase for every day in the year
        guard let yearStart = cal.date(from: DateComponents(year: currentYear, month: 1, day: 1)),
              let yearEnd = cal.date(from: DateComponents(year: currentYear, month: 12, day: 31)) else { return }
        
        var current = yearStart
        while current <= yearEnd {
            let key = Self.phaseDateFormatter.string(from: current)
            lookup[key] = phaseManager.phase(for: current)
            current = cal.date(byAdding: .day, value: 1, to: current)!
        }
        
        phaseLookup = lookup
    }
    
    // MARK: - Pre-computed Month Grid Data
    struct MonthGridData {
        let daysInMonth: Int
        let startingSpaces: Int
        let rows: Int
        let dates: [Date?] // All dates for the month grid (nil for empty cells)
        let phaseColors: [Color] // Pre-computed phase colors for each cell
    }
    
    private func buildMonthGridCache() {
        var grids: [Int: MonthGridData] = [:]
        let cal = performanceCache.calendar
        
        for monthIndex in 0..<12 {
            guard let monthDate = cal.date(from: DateComponents(year: currentYear, month: monthIndex + 1, day: 1)) else { continue }
            
            let daysInMonth = cal.range(of: .day, in: .month, for: monthDate)?.count ?? 30
            let firstWeekday = cal.component(.weekday, from: monthDate)
            let startingSpaces = (firstWeekday == 1) ? 6 : firstWeekday - 2
            let totalCells = startingSpaces + daysInMonth
            let rows = (totalCells + 6) / 7
            
            // Pre-compute all dates and phase colors
            var dates: [Date?] = []
            var phaseColors: [Color] = []
            
            for row in 0..<rows {
                for col in 0..<7 {
                    let cellIndex = row * 7 + col
                    let dayNumber = cellIndex - startingSpaces + 1
                    
                    if cellIndex < startingSpaces || dayNumber > daysInMonth {
                        dates.append(nil)
                        phaseColors.append(.clear)
                    } else {
                        let dayDate = cal.date(from: DateComponents(year: currentYear, month: monthIndex + 1, day: dayNumber))
                        dates.append(dayDate)
                        
                        if let date = dayDate {
                            let phase = getCachedPhase(for: date)
                            let isToday = cal.isDateInToday(date)
                            let color = isToday ? Color.red.opacity(0.1) : (phase?.color.swiftUIColor.opacity(0.6) ?? Color.clear)
                            phaseColors.append(color)
                        } else {
                            phaseColors.append(.clear)
                        }
                    }
                }
            }
            
            grids[monthIndex] = MonthGridData(
                daysInMonth: daysInMonth,
                startingSpaces: startingSpaces,
                rows: rows,
                dates: dates,
                phaseColors: phaseColors
            )
        }
        
        cachedMonthGrids = grids
        monthGridsReady = true
    }
    
    private func getCachedPhase(for date: Date) -> WeightPhase? {
        let key = Self.phaseDateFormatter.string(from: date)
        return phaseLookup[key] ?? nil
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Year header with navigation
                HStack {
                    Button(action: {
                        currentYear -= 1
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    .padding(.leading, 20)
                    
                    Spacer()
                    
                    Text(String(currentYear))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        currentYear += 1
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    .padding(.trailing, 20)
                }
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                // Months grid - 4 rows x 3 columns
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { row in
                            HStack(spacing: 8) {
                                ForEach(0..<3, id: \.self) { col in
                                    let monthIndex = row * 3 + col
                                    if monthIndex < 12 {
                                        monthView(for: monthIndex)
                                            .frame(maxWidth: .infinity)
                                            .id("month-\(currentYear)-\(monthIndex)")
                                    }
                                }
                            }
                        }
                        
                        // Weight Chart with Phase Backgrounds
                        yearWeightChartCard
                            .padding(.top, 10)
                            .id("chart-\(currentYear)")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .id("calendar-grid-\(currentYear)")
                }
            }
            .background(scrollBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                // Build caches on background, assign on main
                await buildCachesAsync()
                await prepareChartData()
            }
            .onChange(of: currentYear) { oldValue, newValue in
                chartDataReady = false
                monthGridsReady = false
                
                Task {
                    await buildCachesAsync()
                    await prepareChartData()
                }
            }
        }
    }
    
    // Build phase lookup and month grid caches on background thread
    private func buildCachesAsync() async {
        let year = currentYear
        let phases = phaseManager.phases
        let cal = performanceCache.calendar
        
        // Compute on background
        let (lookup, grids) = await Task.detached(priority: .userInitiated) {
            // Phase lookup
            var lookup: [String: WeightPhase?] = [:]
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            
            guard let yearStart = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
                  let yearEnd = cal.date(from: DateComponents(year: year, month: 12, day: 31)) else {
                return (lookup, [Int: MonthGridData]())
            }
            
            var current = yearStart
            while current <= yearEnd {
                let key = fmt.string(from: current)
                lookup[key] = phases.first { phase in
                    current >= phase.startDate && current <= phase.effectiveEndDate
                }
                current = cal.date(byAdding: .day, value: 1, to: current)!
            }
            
            // Month grids
            var grids: [Int: MonthGridData] = [:]
            for monthIndex in 0..<12 {
                guard let monthDate = cal.date(from: DateComponents(year: year, month: monthIndex + 1, day: 1)) else { continue }
                let daysInMonth = cal.range(of: .day, in: .month, for: monthDate)?.count ?? 30
                let firstWeekday = cal.component(.weekday, from: monthDate)
                let startingSpaces = (firstWeekday == 1) ? 6 : firstWeekday - 2
                let totalCells = startingSpaces + daysInMonth
                let rows = (totalCells + 6) / 7
                
                var dates: [Date?] = []
                var phaseColors: [Color] = []
                
                for row in 0..<rows {
                    for col in 0..<7 {
                        let cellIndex = row * 7 + col
                        let dayNumber = cellIndex - startingSpaces + 1
                        if cellIndex < startingSpaces || dayNumber > daysInMonth {
                            dates.append(nil)
                            phaseColors.append(.clear)
                        } else {
                            let dayDate = cal.date(from: DateComponents(year: year, month: monthIndex + 1, day: dayNumber))
                            dates.append(dayDate)
                            if let date = dayDate {
                                let key = fmt.string(from: date)
                                let phase = lookup[key] ?? nil
                                let isToday = cal.isDateInToday(date)
                                let color = isToday ? Color.red.opacity(0.1) : (phase?.color.swiftUIColor.opacity(0.6) ?? Color.clear)
                                phaseColors.append(color)
                            } else {
                                phaseColors.append(.clear)
                            }
                        }
                    }
                }
                
                grids[monthIndex] = MonthGridData(
                    daysInMonth: daysInMonth, startingSpaces: startingSpaces,
                    rows: rows, dates: dates, phaseColors: phaseColors
                )
            }
            
            return (lookup, grids)
        }.value
        
        await MainActor.run {
            phaseLookup = lookup
            cachedMonthGrids = grids
            monthGridsReady = true
        }
    }
    
    // Determine smoothing timeframe based on actual data duration in the year
    private func effectiveTimeframe(yearStart: Date, yearEnd: Date) -> TimeFrame {
        let effectiveEnd = min(yearEnd, Date())
        let days = calendar.dateComponents([.day], from: yearStart, to: effectiveEnd).day ?? 0
        if days <= 7 { return .oneWeek }
        else if days <= 30 { return .oneMonth }
        else if days <= 90 { return .threeMonths }
        else if days <= 365 { return .oneYear }
        else { return .allTime }
    }
    
    // MARK: - Async Data Preparation
    private func prepareChartData() async {
        let yearStart = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1)) ?? Date()
        let yearEnd = calendar.date(from: DateComponents(year: currentYear, month: 12, day: 31)) ?? Date()
        let effectiveEnd = min(yearEnd, Date())
        
        // Capture data needed for background computation
        let allWeightEntries = weightManager.allEntries
        let allPhases = phaseManager.phases
        let timeframe = effectiveTimeframe(yearStart: yearStart, yearEnd: yearEnd)
        
        // Run heavy computation on background thread
        let result = await Task.detached(priority: .userInitiated) { [self] () -> (entries: [WeightLogEntry], phases: [WeightPhase], smoothed: [WeightLogEntry], minW: Double, maxW: Double) in
            let entries = allWeightEntries.filter { entry in
                entry.date >= yearStart && entry.date <= effectiveEnd
            }.sorted { $0.date < $1.date }
            
            let phases = allPhases.filter { phase in
                phase.startDate <= yearEnd && phase.effectiveEndDate >= yearStart
            }.sorted { $0.startDate < $1.startDate }
            
            // Use ALL entries for smoothing (full history context), then trim
            let sorted = allWeightEntries.sorted { $0.date < $1.date }
            let fullSmoothed = sorted.count >= 2 ? self.smoothedTrend(from: sorted, timeframe: timeframe) : []
            
            var smoothed = fullSmoothed.filter { $0.date >= yearStart && $0.date <= effectiveEnd }
            
            // Interpolate at start boundary so line continues from previous year
            if let firstDate = smoothed.first?.date, firstDate > yearStart, !fullSmoothed.isEmpty {
                if let startWeight = self.interpolateWeight(at: yearStart, from: fullSmoothed) {
                    smoothed.insert(WeightLogEntry(
                        id: UUID(), date: yearStart, weight: startWeight, movingAverage: startWeight
                    ), at: 0)
                }
            }
            
            let weights = smoothed.map { $0.weight }
            let rawMin = weights.min() ?? 60
            let rawMax = weights.max() ?? 80
            let range = rawMax - rawMin
            let padding = max(range * 0.15, 0.5)
            
            return (entries, phases, smoothed, rawMin - padding, rawMax + padding)
        }.value
        
        await MainActor.run {
            cachedYearEntries = result.entries
            cachedYearPhases = result.phases
            cachedSmoothedEntries = result.smoothed
            cachedMinWeight = result.minW
            cachedMaxWeight = result.maxW
            chartDataReady = true
        }
    }
    
    // Interpolate a weight value at a target date from sorted entries
    private func interpolateWeight(at targetDate: Date, from entries: [WeightLogEntry]) -> Double? {
        guard !entries.isEmpty else { return nil }
        if targetDate <= entries.first!.date { return entries.first!.weight }
        if targetDate >= entries.last!.date { return entries.last!.weight }
        for i in 0..<(entries.count - 1) {
            let before = entries[i], after = entries[i + 1]
            if before.date <= targetDate && after.date >= targetDate {
                let total = after.date.timeIntervalSince(before.date)
                guard total > 0 else { return before.weight }
                let t = targetDate.timeIntervalSince(before.date) / total
                return before.weight + t * (after.weight - before.weight)
            }
        }
        return entries.last!.weight
    }
    
    private func monthView(for monthIndex: Int) -> some View {
        // Performance: Use pre-computed grid data if available
        let gridData = cachedMonthGrids[monthIndex]
        let daysInMonth = gridData?.daysInMonth ?? 30
        let startingSpaces = gridData?.startingSpaces ?? 0
        let rows = gridData?.rows ?? 5
        
        let monthTitle = Text(monthNames[monthIndex])
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.primary)
            .frame(height: 20, alignment: .bottom)
        
        let calendarGrid = VStack(spacing: 2) {
            ForEach(Array(0..<rows), id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(Array(0..<7), id: \.self) { col in
                        // Performance: Use cached data
                        cachedDayCell(row: row, col: col, monthIndex: monthIndex, gridData: gridData)
                    }
                }
                .background(
                    // Performance: Use cached phase colors
                    cachedPhaseRowBackground(row: row, monthIndex: monthIndex, gridData: gridData)
                )
            }
        }
        .frame(height: 100)
        
        return VStack(spacing: 4) {
            monthTitle
            calendarGrid
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        )
    }
    
    // Performance: Optimized day cell using cached data
    @ViewBuilder
    private func cachedDayCell(row: Int, col: Int, monthIndex: Int, gridData: MonthGridData?) -> some View {
        let cellIndex = row * 7 + col
        
        if let grid = gridData, cellIndex < grid.dates.count, let dayDate = grid.dates[cellIndex] {
            let dayNumber = calendar.component(.day, from: dayDate)
            let isSelected = calendar.isDate(dayDate, inSameDayAs: selectedDate)
            let isToday = calendar.isDateInToday(dayDate)
            let textColor: Color = isSelected ? .white : (isToday ? .red : .primary)
            
            Text("\(dayNumber)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(textColor)
                .frame(width: 14, height: 14)
                .background(Color.clear)
        } else {
            Text("")
                .frame(width: 14, height: 14)
        }
    }
    
    // Performance: Optimized phase row background using cached colors
    private func cachedPhaseRowBackground(row: Int, monthIndex: Int, gridData: MonthGridData?) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(0..<7), id: \.self) { col in
                let cellIndex = row * 7 + col
                
                if let grid = gridData, cellIndex < grid.phaseColors.count {
                    let baseColor = grid.phaseColors[cellIndex]
                    
                    // Get adjacent colors for connected backgrounds
                    let leftColor = col > 0 && (cellIndex - 1) < grid.phaseColors.count ? grid.phaseColors[cellIndex - 1] : Color.clear
                    let rightColor = col < 6 && (cellIndex + 1) < grid.phaseColors.count ? grid.phaseColors[cellIndex + 1] : Color.clear
                    
                    // Simplified connected background (colors match = connected)
                    let leftConnected = baseColor != .clear && leftColor == baseColor
                    let rightConnected = baseColor != .clear && rightColor == baseColor
                    
                    Rectangle()
                        .fill(baseColor)
                        .frame(width: 16, height: 14)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: leftConnected ? 0 : 3,
                                bottomLeadingRadius: leftConnected ? 0 : 3,
                                bottomTrailingRadius: rightConnected ? 0 : 3,
                                topTrailingRadius: rightConnected ? 0 : 3
                            )
                        )
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16, height: 14)
                }
            }
        }
    }
    
    @ViewBuilder
    private func dayCell(row: Int, col: Int, monthIndex: Int, startingSpaces: Int, daysInMonth: Int) -> some View {
        let cellIndex = row * 7 + col
        let dayNumber = cellIndex - startingSpaces + 1
        
        if cellIndex < startingSpaces || dayNumber > daysInMonth {
            Text("")
                .frame(width: 14, height: 14)
        } else {
            let dayDate = calendar.date(from: DateComponents(year: currentYear, month: monthIndex + 1, day: dayNumber)) ?? Date()
            let isSelected = calendar.isDate(dayDate, inSameDayAs: selectedDate)
            let isToday = calendar.isDateInToday(dayDate)
            
            let textColor: Color = isSelected ? .white : (isToday ? .red : .primary)
            
            Text("\(dayNumber)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(textColor)
                .frame(width: 14, height: 14)
                .background(Color.clear)
        }
    }
    
    private func phaseRowBackground(row: Int, monthIndex: Int, startingSpaces: Int, daysInMonth: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(0..<7), id: \.self) { col in
                let cellIndex = row * 7 + col
                let dayNumber = cellIndex - startingSpaces + 1
                
                if cellIndex >= startingSpaces && dayNumber <= daysInMonth {
                    let dayDate = calendar.date(from: DateComponents(year: currentYear, month: monthIndex + 1, day: dayNumber)) ?? Date()
                    let phaseForDate = getCachedPhase(for: dayDate)
                    let isToday = calendar.isDateInToday(dayDate)
                    
                    // Get adjacent phase info for connected backgrounds
                    let leftPhase = col > 0 ? getPhaseForCell(row: row, col: col - 1, monthIndex: monthIndex, startingSpaces: startingSpaces, daysInMonth: daysInMonth) : nil
                    let rightPhase = col < 6 ? getPhaseForCell(row: row, col: col + 1, monthIndex: monthIndex, startingSpaces: startingSpaces, daysInMonth: daysInMonth) : nil
                    
                    let baseColor = isToday ? Color.red.opacity(0.1) : (phaseForDate?.color.swiftUIColor.opacity(0.6) ?? Color.clear)
                    
                    // Create connected background shape
                    let leftConnected = phaseForDate?.id == leftPhase?.id && phaseForDate != nil
                    let rightConnected = phaseForDate?.id == rightPhase?.id && phaseForDate != nil
                    
                    Rectangle()
                        .fill(baseColor)
                        .frame(width: 16, height: 14)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: leftConnected ? 0 : 3,
                                bottomLeadingRadius: leftConnected ? 0 : 3,
                                bottomTrailingRadius: rightConnected ? 0 : 3,
                                topTrailingRadius: rightConnected ? 0 : 3
                            )
                        )
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16, height: 14)
                }
            }
        }
    }
    
    private func getPhaseForCell(row: Int, col: Int, monthIndex: Int, startingSpaces: Int, daysInMonth: Int) -> WeightPhase? {
        let cellIndex = row * 7 + col
        let dayNumber = cellIndex - startingSpaces + 1
        
        guard cellIndex >= startingSpaces && dayNumber <= daysInMonth else { return nil }
        guard let cellDate = calendar.date(from: DateComponents(year: currentYear, month: monthIndex + 1, day: dayNumber)) else { return nil }
        
        return getCachedPhase(for: cellDate)
    }
    
    // MARK: - Year Weight Chart with Phase Backgrounds
    
    private var yearWeightChartCard: some View {
        let yearStart = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1)) ?? Date()
        let yearEnd = calendar.date(from: DateComponents(year: currentYear, month: 12, day: 31)) ?? Date()
        
        // Use cached data instead of recalculating
        let yearEntries = cachedYearEntries
        let yearPhases = cachedYearPhases
        let minWeight = cachedMinWeight
        let maxWeight = cachedMaxWeight
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Weight Progress")
                .font(.headline)
                .foregroundColor(.primary)
            
            if !chartDataReady {
                // Show loading state while data is being prepared
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading chart...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
            } else if yearEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No weight entries in \(String(currentYear))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
            } else {
                // Canvas-based chart matching WeightChartCardView style
                VStack(spacing: 0) {
                    GeometryReader { geo in
                        let chartSize = CGSize(width: geo.size.width - 40, height: geo.size.height)
                        
                        ZStack(alignment: .leading) {
                            // Canvas for grid, phases, and line
                            Canvas { context, size in
                                // Draw grid lines (horizontal at Y labels, vertical at month starts)
                                drawYearChartGrid(in: context, size: size, minWeight: minWeight, maxWeight: maxWeight, yearStart: yearStart, yearEnd: yearEnd)
                                
                                // Draw phase backgrounds
                                drawPhaseBackgrounds(in: context, size: size, phases: yearPhases, yearStart: yearStart, yearEnd: yearEnd, minWeight: minWeight, maxWeight: maxWeight)
                                
                                // Draw weight line using cached smoothed data
                                drawCachedWeightLine(in: context, size: size, yearStart: yearStart, yearEnd: yearEnd, minWeight: minWeight, maxWeight: maxWeight)
                            }
                            .frame(width: chartSize.width, height: chartSize.height)
                            .offset(x: 40) // Space for Y-axis labels
                            .overlay(
                                crosshairOverlay(chartSize: chartSize, yearStart: yearStart, yearEnd: yearEnd, minWeight: minWeight, maxWeight: maxWeight)
                                    .offset(x: 40)
                            )
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        handleChartDrag(at: value.location, chartSize: chartSize)
                                    }
                                    .onEnded { _ in
                                        selectedIndex = nil
                                        lastSelectedIndex = nil
                                    }
                            )
                            
                            // Y-axis labels
                            yAxisLabelsView(height: chartSize.height, minWeight: minWeight, maxWeight: maxWeight)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                    .frame(height: 180)
                    
                    // X-axis labels (months)
                    xAxisMonthLabels(yearStart: yearStart)
                        .padding(.leading, 40)
                        .padding(.top, 4)
                }
            }
            
            // Phase Legend
            if !yearPhases.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Phases")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ForEach(yearPhases) { phase in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(phase.swiftUIColor.opacity(0.6))
                                .frame(width: 16, height: 16)
                            
                            Text(phase.name)
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Canvas Drawing Functions
    
    private func drawYearChartGrid(in context: GraphicsContext, size: CGSize, minWeight: Double, maxWeight: Double, yearStart: Date, yearEnd: Date) {
        var gridPath = Path()
        
        // Calculate Y-axis intervals to match labels
        let range = maxWeight - minWeight
        let interval = yAxisInterval(for: range)
        let labels = generateYAxisLabels(minWeight: minWeight, maxWeight: maxWeight, interval: interval)
        
        // Horizontal grid lines aligned with Y-axis labels
        for value in labels {
            let normalized = (value - minWeight) / range
            let y = size.height - CGFloat(normalized) * size.height
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: size.width, y: y))
        }
        
        // Vertical grid lines at start of each month
        let totalTime = yearEnd.timeIntervalSince(yearStart)
        let cal = Calendar.current
        
        for month in 1...12 {
            if let monthStart = cal.date(from: DateComponents(year: currentYear, month: month, day: 1)) {
                let x = CGFloat(monthStart.timeIntervalSince(yearStart) / totalTime) * size.width
                gridPath.move(to: CGPoint(x: x, y: 0))
                gridPath.addLine(to: CGPoint(x: x, y: size.height))
            }
        }
        
        context.stroke(gridPath, with: .color(Color.gray.opacity(0.3)), lineWidth: 0.5)
    }
    
    private func drawPhaseBackgrounds(in context: GraphicsContext, size: CGSize, phases: [WeightPhase], yearStart: Date, yearEnd: Date, minWeight: Double, maxWeight: Double) {
        let totalTime = yearEnd.timeIntervalSince(yearStart)
        
        for phase in phases {
            let phaseStart = max(phase.startDate, yearStart)
            let phaseEnd = min(phase.effectiveEndDate, yearEnd)
            
            let startX = CGFloat(phaseStart.timeIntervalSince(yearStart) / totalTime) * size.width
            let endX = CGFloat(phaseEnd.timeIntervalSince(yearStart) / totalTime) * size.width
            
            let rect = CGRect(x: startX, y: 0, width: endX - startX, height: size.height)
            context.fill(Path(rect), with: .color(phase.swiftUIColor.opacity(0.6)))
        }
    }
    
    private func drawWeightLine(in context: GraphicsContext, size: CGSize, entries: [WeightLogEntry], yearStart: Date, yearEnd: Date, minWeight: Double, maxWeight: Double) {
        guard entries.count >= 2 else { return }
        
        // Apply smoothing algorithm (same as WeightChartCardView 1Y timeframe)
        let smoothedEntries = smoothedTrend(from: entries)
        
        let dates = smoothedEntries.map { $0.date }
        let values = smoothedEntries.map { $0.weight }
        
        // Apply densified monotone spline (same as WeightChartCardView)
        let (splineDates, splineValues) = monotoneSpline(dates: dates, values: values, samplesPerSegment: 8)
        
        var path = Path()
        
        if splineDates.count > 0 {
            let firstPoint = CGPoint(
                x: xPositionForYear(date: splineDates[0], yearStart: yearStart, yearEnd: yearEnd, width: size.width),
                y: yPositionForYear(value: splineValues[0], minWeight: minWeight, maxWeight: maxWeight, height: size.height)
            )
            path.move(to: firstPoint)
            
            for i in 1..<splineDates.count {
                let point = CGPoint(
                    x: xPositionForYear(date: splineDates[i], yearStart: yearStart, yearEnd: yearEnd, width: size.width),
                    y: yPositionForYear(value: splineValues[i], minWeight: minWeight, maxWeight: maxWeight, height: size.height)
                )
                path.addLine(to: point)
            }
        }
        
        context.stroke(path, with: .color(.blue), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
    }
    
    // Optimized version using cached smoothed data
    private func drawCachedWeightLine(in context: GraphicsContext, size: CGSize, yearStart: Date, yearEnd: Date, minWeight: Double, maxWeight: Double) {
        guard cachedSmoothedEntries.count >= 2 else { return }
        
        let dates = cachedSmoothedEntries.map { $0.date }
        let values = cachedSmoothedEntries.map { $0.weight }
        
        // Apply densified monotone spline
        let (splineDates, splineValues) = monotoneSpline(dates: dates, values: values, samplesPerSegment: 8)
        
        var path = Path()
        
        if splineDates.count > 0 {
            let firstPoint = CGPoint(
                x: xPositionForYear(date: splineDates[0], yearStart: yearStart, yearEnd: yearEnd, width: size.width),
                y: yPositionForYear(value: splineValues[0], minWeight: minWeight, maxWeight: maxWeight, height: size.height)
            )
            path.move(to: firstPoint)
            
            for i in 1..<splineDates.count {
                let point = CGPoint(
                    x: xPositionForYear(date: splineDates[i], yearStart: yearStart, yearEnd: yearEnd, width: size.width),
                    y: yPositionForYear(value: splineValues[i], minWeight: minWeight, maxWeight: maxWeight, height: size.height)
                )
                path.addLine(to: point)
            }
        }
        
        context.stroke(path, with: .color(.blue), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
    }
    
    // MARK: - Smoothing Algorithm (matching WeightChartCardView parameters)
    
    /// Build smooth trend using same 4-stage algorithm as WeightChartCardView
    private func smoothedTrend(from entries: [WeightLogEntry], timeframe: TimeFrame = .oneYear) -> [WeightLogEntry] {
        guard !entries.isEmpty else { return [] }
        
        let sorted = entries.sorted { $0.date < $1.date }
        
        // Use timeframe-specific smoothing parameters
        let params = timeframe.smoothingParameters
        let alpha = params.alpha
        let beta = params.beta
        let windowSize = params.windowSize
        let turning = params.turning
        
        // STAGE 0: Build daily series with gap filling
        let daily = buildDailySeries(from: sorted)
        
        // STAGES 1-3: DES + turning damping + MA polish
        let trend = buildTrendFromDaily(daily: daily, alpha: alpha, beta: beta, window: windowSize, turning: turning)
        
        // Map to WeightLogEntry
        var result: [WeightLogEntry] = []
        for (index, day) in daily.enumerated() {
            result.append(WeightLogEntry(
                id: UUID(),
                date: day.date,
                weight: trend[index],
                movingAverage: trend[index],
                weeklyRate: nil,
                notes: nil
            ))
        }
        
        return result
    }
    
    /// STAGE 0: Build daily series with gradient-based gap filling
    private func buildDailySeries(from entries: [WeightLogEntry]) -> [(date: Date, weight: Double)] {
        guard let first = entries.first?.date,
              let last = entries.last?.date else { return [] }
        
        var daily: [(date: Date, weight: Double)] = []
        var idx = 0
        let n = entries.count
        let cal = Calendar.current
        
        var current = cal.startOfDay(for: first)
        let endDate = cal.startOfDay(for: last)
        
        while current <= endDate {
            while idx < n && cal.startOfDay(for: entries[idx].date) < current {
                idx += 1
            }
            
            let w: Double
            
            if idx < n && cal.isDate(entries[idx].date, inSameDayAs: current) {
                w = entries[idx].weight
            } else {
                let prevIdx = idx - 1
                let nextIdx = idx
                
                if prevIdx >= 0 && nextIdx < n {
                    let prev = entries[prevIdx]
                    let next = entries[nextIdx]
                    let totalDays = cal.dateComponents([.day], from: prev.date, to: next.date).day ?? 1
                    let daysFromPrev = cal.dateComponents([.day], from: prev.date, to: current).day ?? 0
                    let t = max(0.0, min(1.0, Double(daysFromPrev) / Double(totalDays)))
                    w = prev.weight + t * (next.weight - prev.weight)
                } else if prevIdx >= 0 {
                    w = entries[prevIdx].weight
                } else {
                    w = entries[nextIdx].weight
                }
            }
            
            daily.append((date: current, weight: w))
            current = cal.date(byAdding: .day, value: 1, to: current)!
        }
        
        return daily
    }
    
    /// STAGE 1 & 2: DES with turning point damping
    private func desWithStrongTurning(values: [Double], alpha: Double, beta: Double, turning: Double) -> [Double] {
        let n = values.count
        guard n >= 2 else { return values }
        
        var level = values[0]
        var trend = values[1] - values[0]
        var result = Array(repeating: 0.0, count: n)
        var prevDelta = values[1] - values[0]
        
        for i in 0..<n {
            let x = values[i]
            let delta = i > 0 ? x - values[i - 1] : prevDelta
            
            let isTurning = (i > 1 &&
                           ((delta > 0 && prevDelta < 0) || (delta < 0 && prevDelta > 0)) &&
                           delta != 0 && prevDelta != 0)
            
            var a = alpha
            var b = beta
            
            if isTurning {
                let t = turning * turning
                a = alpha * (1 - 0.85 * t)
                b = beta * (1 - 0.90 * t)
                trend *= (1 - 0.70 * t)
            }
            
            let prevLevel = level
            level = a * x + (1 - a) * (level + trend)
            trend = b * (level - prevLevel) + (1 - b) * trend
            trend = min(1.5, max(-1.5, trend))
            
            result[i] = level + trend
            prevDelta = delta
        }
        
        return result
    }
    
    /// STAGE 3: Centered moving average polish
    private func movingAverageSmooth(values: [Double], window: Int) -> [Double] {
        guard window > 1, values.count > 1 else { return values }
        
        let w = window % 2 == 0 ? window + 1 : window
        let radius = w / 2
        let n = values.count
        var out = Array(repeating: 0.0, count: n)
        
        for i in 0..<n {
            let start = max(0, i - radius)
            let end = min(n - 1, i + radius)
            let slice = values[start...end]
            out[i] = slice.reduce(0, +) / Double(slice.count)
        }
        
        return out
    }
    
    /// Complete pipeline: daily series → DES → MA
    private func buildTrendFromDaily(daily: [(date: Date, weight: Double)], alpha: Double, beta: Double, window: Int, turning: Double) -> [Double] {
        let raw = daily.map { $0.weight }
        let des = desWithStrongTurning(values: raw, alpha: alpha, beta: beta, turning: turning)
        return movingAverageSmooth(values: des, window: window)
    }
    
    // MARK: - Monotone Spline (matching WeightChartCardView exactly)
    
    private func monotoneSpline(dates: [Date], values: [Double], samplesPerSegment: Int = 8) -> (dates: [Date], values: [Double]) {
        let n = dates.count
        guard n >= 2 else { return (dates, values) }
        
        let firstDate = dates[0]
        let xs = dates.map { $0.timeIntervalSince(firstDate) / 86400.0 }
        let ys = values
        
        // Secant slopes
        var d: [Double] = []
        for i in 0..<(n-1) {
            let dx = xs[i+1] - xs[i]
            let dy = ys[i+1] - ys[i]
            d.append(dx != 0 ? dy / dx : 0)
        }
        
        // Tangents
        var m = Array(repeating: 0.0, count: n)
        m[0] = d[0]
        for i in 1..<(n-1) {
            m[i] = 0.5 * (d[i-1] + d[i])
        }
        m[n-1] = d[n-2]
        
        // Fritsch-Carlson correction for monotonicity
        for i in 0..<(n-1) {
            if abs(d[i]) < 1e-8 {
                m[i] = 0
                m[i+1] = 0
            } else {
                let a = m[i] / d[i]
                let b = m[i+1] / d[i]
                let s = a*a + b*b
                if s > 9.0 {
                    let t = 3.0 / sqrt(s)
                    m[i] = t * a * d[i]
                    m[i+1] = t * b * d[i]
                }
            }
        }
        
        // Densify with cubic Hermite interpolation
        var outX: [Double] = []
        var outY: [Double] = []
        
        for i in 0..<(n-1) {
            let x0 = xs[i]
            let x1 = xs[i+1]
            let y0 = ys[i]
            let y1 = ys[i+1]
            let dx = x1 - x0
            
            for k in 0..<samplesPerSegment {
                let t = Double(k) / Double(samplesPerSegment)
                let t2 = t * t
                let t3 = t2 * t
                
                // Hermite basis functions
                let h00 = 2*t3 - 3*t2 + 1
                let h10 = t3 - 2*t2 + t
                let h01 = -2*t3 + 3*t2
                let h11 = t3 - t2
                
                let y = h00*y0 + h10*dx*m[i] + h01*y1 + h11*dx*m[i+1]
                let x = x0 + t*dx
                
                outX.append(x)
                outY.append(y)
            }
        }
        
        outX.append(xs.last!)
        outY.append(ys.last!)
        
        let outDates = outX.map { Date(timeInterval: $0 * 86400.0, since: firstDate) }
        return (dates: outDates, values: outY)
    }
    
    // MARK: - Coordinate Transforms
    
    private func xPositionForYear(date: Date, yearStart: Date, yearEnd: Date, width: CGFloat) -> CGFloat {
        let total = yearEnd.timeIntervalSince(yearStart)
        guard total > 0 else { return 0 }
        let t = date.timeIntervalSince(yearStart) / total
        return CGFloat(t) * width
    }
    
    private func yPositionForYear(value: Double, minWeight: Double, maxWeight: Double, height: CGFloat) -> CGFloat {
        let range = maxWeight - minWeight
        guard range > 0 else { return height / 2 }
        let normalized = (value - minWeight) / range
        return height - CGFloat(normalized) * height
    }
    
    // MARK: - Axis Labels
    
    private func yAxisLabelsView(height: CGFloat, minWeight: Double, maxWeight: Double) -> some View {
        let range = maxWeight - minWeight
        let interval = yAxisInterval(for: range)
        let labels = generateYAxisLabels(minWeight: minWeight, maxWeight: maxWeight, interval: interval)
        
        return GeometryReader { _ in
            ZStack(alignment: .trailing) {
                ForEach(labels, id: \.self) { value in
                    let normalized = (value - minWeight) / range
                    let y = height - CGFloat(normalized) * height
                    
                    Text(String(format: "%.1f", value))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                        .position(x: 30, y: y)
                }
            }
        }
    }
    
    private func yAxisInterval(for range: Double) -> Double {
        if range <= 3.0 { return 0.5 }
        else if range <= 7.0 { return 1.0 }
        else if range <= 15.0 { return 2.0 }
        else { return 5.0 }
    }
    
    private func generateYAxisLabels(minWeight: Double, maxWeight: Double, interval: Double) -> [Double] {
        var labels: [Double] = []
        let minRounded = (minWeight / interval).rounded(.up) * interval
        var current = minRounded
        while current <= maxWeight {
            labels.append(current)
            current += interval
        }
        return labels
    }
    
    private func xAxisMonthLabels(yearStart: Date) -> some View {
        let monthLabels = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
        
        return HStack(spacing: 0) {
            ForEach(0..<12, id: \.self) { month in
                Text(monthLabels[month])
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Crosshair Overlay
    
    @ViewBuilder
    private func crosshairOverlay(chartSize: CGSize, yearStart: Date, yearEnd: Date, minWeight: Double, maxWeight: Double) -> some View {
        if let idx = selectedIndex,
           idx < cachedSmoothedEntries.count {
            let entry = cachedSmoothedEntries[idx]
            
            let x = xPositionForYear(date: entry.date, yearStart: yearStart, yearEnd: yearEnd, width: chartSize.width)
            let y = yPositionForYear(value: entry.weight, minWeight: minWeight, maxWeight: maxWeight, height: chartSize.height)
            
            ZStack {
                // Vertical crosshair line
                Rectangle()
                    .fill(Color.blue.opacity(0.4))
                    .frame(width: 1, height: chartSize.height)
                    .position(x: x, y: chartSize.height / 2)
                
                // Horizontal crosshair line
                Rectangle()
                    .fill(Color.blue.opacity(0.4))
                    .frame(width: chartSize.width, height: 1)
                    .position(x: chartSize.width / 2, y: y)
                
                // Data point circle
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
                    .position(x: x, y: y)
                
                // Value label
                VStack(spacing: 2) {
                    Text(entry.date, format: .dateTime.day().month().year())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(String(format: "%.1f kg", entry.weight))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.appCardBackground)
                        .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                )
                .position(x: x, y: max(28, y - 36))
            }
        }
    }
    
    // MARK: - Drag Handling
    
    private func handleChartDrag(at location: CGPoint, chartSize: CGSize) {
        // Account for Y-axis label offset (40px)
        let xInChart = location.x - 40
        
        guard xInChart >= 0, xInChart <= chartSize.width else {
            selectedIndex = nil
            return
        }
        
        guard !cachedSmoothedEntries.isEmpty else {
            selectedIndex = nil
            return
        }
        
        // Calculate target date based on position in chart
        let yearStart = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1)) ?? Date()
        let yearEnd = calendar.date(from: DateComponents(year: currentYear, month: 12, day: 31)) ?? Date()
        let totalTime = yearEnd.timeIntervalSince(yearStart)
        
        guard totalTime > 0 else { return }
        
        let t = Double(xInChart / chartSize.width)
        let targetDate = Date(timeInterval: t * totalTime, since: yearStart)
        
        // Find closest data point by date
        var closestIndex = 0
        var minDistance = abs(cachedSmoothedEntries[0].date.timeIntervalSince(targetDate))
        
        for (index, entry) in cachedSmoothedEntries.enumerated() {
            let distance = abs(entry.date.timeIntervalSince(targetDate))
            if distance < minDistance {
                minDistance = distance
                closestIndex = index
            }
        }
        
        if selectedIndex != closestIndex {
            selectedIndex = closestIndex
            
            // Haptic feedback when changing selection
            if lastSelectedIndex != closestIndex {
                haptic.impactOccurred()
                lastSelectedIndex = closestIndex
            }
        }
    }
}

