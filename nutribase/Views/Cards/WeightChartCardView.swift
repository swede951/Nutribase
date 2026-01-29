//
//  WeightChartCardView.swift
//  nutribase
//
//  Rewritten for performance: Canvas-based detail chart with scrubbing
//

import SwiftUI
import Charts   // still used for the tiny dashboard preview only

// MARK: - Dashboard Card (unchanged UI, lightweight Chart)

enum WeightChartSizeMode: String, CaseIterable {
    case compact = "1×1"
    case expanded = "2×3"
}

struct WeightChartCardView: View {
    var isPreview: Bool = false
    var customPreviewWeight: Double? = nil  // Optional custom weight for onboarding flat line
    
    @ObservedObject private var weightLogManager = WeightLogManager.shared
    @State private var showingDetailView = false
    @AppStorage("weightChartSizeMode") private var sizeMode: WeightChartSizeMode = .compact
    
    // Cache for dashboard preview data (compact mode)
    @State private var cachedRecentWeights: [WeightLogEntry] = []
    @State private var lastEntriesHash: Int = 0
    
    // Expanded mode state (detailed chart with scrubbing)
    @State private var expandedSelectedTimeFrame: TimeFrame = .allTime
    @State private var expandedPoints: [WeightLogEntry] = []
    @State private var expandedXDomain: ClosedRange<Date> = Date()...Date()
    @State private var expandedYDomain: ClosedRange<Double> = 0...100
    @State private var expandedSelectedIndex: Int? = nil
    @State private var expandedIsLoading = true
    @State private var expandedSmoothedDataCache: [TimeFrame: [WeightLogEntry]] = [:]
    @State private var expandedLastDataHash: Int = 0
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    
    // Static preview data for Widget Gallery - use custom weight if provided (flat line)
    private var previewWeights: [(date: Date, weight: Double)] {
        let calendar = Calendar.current
        let today = Date()
        
        // If custom weight provided, show flat line at that weight
        if let customWeight = customPreviewWeight {
            return [
                (calendar.date(byAdding: .day, value: -60, to: today)!, customWeight),
                (calendar.date(byAdding: .day, value: -30, to: today)!, customWeight),
                (today, customWeight)
            ]
        }
        
        // Default preview with declining trend
        return [
            (calendar.date(byAdding: .day, value: -60, to: today)!, 88.5),
            (calendar.date(byAdding: .day, value: -50, to: today)!, 87.8),
            (calendar.date(byAdding: .day, value: -40, to: today)!, 87.2),
            (calendar.date(byAdding: .day, value: -30, to: today)!, 86.5),
            (calendar.date(byAdding: .day, value: -20, to: today)!, 86.0),
            (calendar.date(byAdding: .day, value: -10, to: today)!, 85.5),
            (today, 85.0)
        ]
    }

    /// Always show 3 months for dashboard preview
    private var dashboardTimeframe: TimeFrame {
        return .threeMonths
    }

    /// Recent smoothed data for the small preview chart (3 months) - cached
    private var recentWeights: [WeightLogEntry] {
        return cachedRecentWeights
    }
    
    /// Update cached data if entries changed
    private func updateCacheIfNeeded() {
        let allEntries = weightLogManager.allEntries
        let currentHash = allEntries.map { $0.id.hashValue }.reduce(0, ^)
        
        if currentHash != lastEntriesHash {
            let sorted = allEntries.sorted { $0.date < $1.date }
            if !sorted.isEmpty {
                cachedRecentWeights = smoothedTrendForDashboard(from: sorted, timeframe: dashboardTimeframe)
            } else {
                cachedRecentWeights = []
            }
            lastEntriesHash = currentHash
        }
    }

    /// Y-range for the preview chart
    private var yAxisRange: ClosedRange<Double> {
        guard !cachedRecentWeights.isEmpty else { return 0 ... 100 }
        let weights = cachedRecentWeights.map { $0.weight }
        let minW = weights.min() ?? 0
        let maxW = weights.max() ?? 100
        let range = maxW - minW
        let padding = max(range * 0.05, 2.0)
        return (minW - padding)...(maxW + padding)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            FixedSizeCard(
                title: "Weight Chart",
                onCardTap: isPreview ? nil : {
                    showingDetailView = true
                },
                customHeight: (sizeMode == .expanded && !isPreview) ? 482 : nil  // 150×3 + 16×2 (three cards + two spacings)
            ) {
            VStack(alignment: .leading, spacing: 8) {
                if sizeMode == .expanded && !isPreview {
                    // Expanded mode: Full detailed chart with scrubbing
                    expandedChartContent
                } else if recentWeights.count >= 2 {
                    // Compact mode: Simple canvas chart
                    Canvas { context, size in
                        drawDashboardChart(in: context, size: size)
                    }
                    .frame(height: 80)
                    .overlay(
                        GeometryReader { geometry in
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                            }
                            .stroke(Color.primary, lineWidth: 1.5)
                        }
                    )
                } else if let entry = recentWeights.first {
                    // Single-point preview (straight line)
                    let previewData = [
                        (date: Calendar.current.date(byAdding: .day, value: -7, to: entry.date) ?? entry.date,
                         weight: entry.weight * 0.98),
                        (date: entry.date, weight: entry.weight)
                    ]

                    Chart(previewData, id: \.date) { pt in
                        LineMark(
                            x: .value("Date", pt.date),
                            y: .value("Weight", pt.weight)
                        )
                        .foregroundStyle(Color(hex: "#5ec5ff").opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis {
                        AxisMarks(position: .bottom, values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.gray.opacity(0.2))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.gray.opacity(0.2))
                        }
                    }
                    .chartYScale(domain: yAxisRange)
                    .frame(height: 80)
                    .overlay(
                        GeometryReader { geometry in
                            Path { path in
                                // Y-axis (left line)
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                                // X-axis (bottom line)
                                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                            }
                            .stroke(Color.primary, lineWidth: 1.5)
                        }
                    )
                } else if isPreview {
                    // Preview mode with static data - show gridlines and axis
                    // Calculate Y domain from actual preview data
                    let weights = previewWeights.map { $0.weight }
                    let minWeight = weights.min() ?? 85.0
                    let maxWeight = weights.max() ?? 85.0
                    let range = maxWeight - minWeight
                    let padding = max(range * 0.1, 1.0)
                    let yMin = minWeight - padding
                    let yMax = maxWeight + padding
                    
                    Chart(previewWeights, id: \.date) { pt in
                        LineMark(
                            x: .value("Date", pt.date),
                            y: .value("Weight", pt.weight)
                        )
                        .foregroundStyle(Color(hex: "#5ec5ff").opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis {
                        AxisMarks(position: .bottom, values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.gray.opacity(0.3))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.gray.opacity(0.3))
                        }
                    }
                    .chartYScale(domain: yMin...yMax)
                    .frame(height: 80)
                    .overlay(
                        GeometryReader { geometry in
                            Path { path in
                                // Y-axis (left line)
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                                // X-axis (bottom line)
                                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                            }
                            .stroke(Color.primary, lineWidth: 1.5)
                        }
                    )
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Not enough data")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                }
            }
        }
        .onAppear {
            if !isPreview {
                updateCacheIfNeeded()
                if sizeMode == .expanded {
                    haptic.prepare()
                    loadExpandedData()
                }
            }
        }
        .onChange(of: weightLogManager.allEntries.count) { oldValue, newValue in
            if !isPreview {
                updateCacheIfNeeded()
                if sizeMode == .expanded {
                    loadExpandedData()
                }
            }
        }
        .onChange(of: sizeMode) { oldValue, newMode in
            if newMode == .expanded && !isPreview {
                haptic.prepare()
                loadExpandedData()
            }
        }
        .sheet(isPresented: $showingDetailView) {
            WeightChartDetailView()
        }
            
            if !isPreview {
                Menu {
                    ForEach(WeightChartSizeMode.allCases, id: \.self) { mode in
                        Button(action: {
                            sizeMode = mode
                            NotificationCenter.default.post(name: NSNotification.Name("WeightChartSizeModeChanged"), object: nil)
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
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Expanded Chart Content (2x2 mode)
    
    @ViewBuilder
    private var expandedChartContent: some View {
        VStack(spacing: 4) {
            if expandedIsLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if expandedPoints.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("Not enough data")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Full CanvasChart with scrubbing - taller for 2x3 layout
                CanvasChart(
                    points: expandedPoints,
                    xDomain: expandedXDomain,
                    yDomain: expandedYDomain,
                    timeframe: expandedSelectedTimeFrame,
                    chartHeight: 380,
                    selectedIndex: $expandedSelectedIndex
                )
                
                // X-axis labels
                expandedXAxisLabels
                    .frame(height: 16)
                
                // Timeframe buttons
                expandedTimeFrameButtons
                    .frame(height: 36)
            }
        }
    }
    
    private var expandedXAxisLabels: some View {
        let labels = expandedAxisLabels()
        
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(labels, id: \.0) { (date, label) in
                    let xPos = expandedXPosition(for: date, in: CGSize(width: geo.size.width - 40, height: 0))
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                        .position(x: xPos + 40, y: 8)
                }
            }
        }
    }
    
    private func expandedAxisLabels() -> [(Date, String)] {
        guard !expandedPoints.isEmpty else { return [] }
        
        let formatter = DateFormatter()
        formatter.locale = .current
        
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: expandedXDomain.lowerBound, to: expandedXDomain.upperBound).day ?? 0
        
        if days <= 7 {
            formatter.dateFormat = "EEE"
        } else if days <= 90 {
            formatter.dateFormat = "MMM"
        } else if days <= 365 {
            formatter.dateFormat = "MMMMM" // Single letter month (J, F, M, A, etc.)
        } else {
            formatter.dateFormat = "yyyy"
        }
        
        // Generate labels based on timeframe
        var result: [(Date, String)] = []
        
        if days > 365 {
            // Year labels
            let startYear = calendar.component(.year, from: expandedXDomain.lowerBound)
            let endYear = calendar.component(.year, from: expandedXDomain.upperBound)
            
            for year in startYear...endYear {
                if let yearDate = calendar.date(from: DateComponents(year: year, month: 7, day: 1)) {
                    if yearDate >= expandedXDomain.lowerBound && yearDate <= expandedXDomain.upperBound {
                        result.append((yearDate, "\(year)"))
                    }
                }
            }
        } else if days > 30 {
            // Month labels - one per month, positioned in the middle
            let startComponents = calendar.dateComponents([.year, .month], from: expandedXDomain.lowerBound)
            let endComponents = calendar.dateComponents([.year, .month], from: expandedXDomain.upperBound)
            
            if let startDate = calendar.date(from: startComponents),
               let endDate = calendar.date(from: endComponents) {
                var currentDate = startDate
                var seenMonths = Set<String>()
                while currentDate <= endDate {
                    let monthKey = "\(calendar.component(.year, from: currentDate))-\(calendar.component(.month, from: currentDate))"
                    if !seenMonths.contains(monthKey) {
                        if let midMonth = calendar.date(bySetting: .day, value: 15, of: currentDate) {
                            result.append((midMonth, formatter.string(from: currentDate)))
                            seenMonths.insert(monthKey)
                        }
                    }
                    if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) {
                        currentDate = nextMonth
                    } else {
                        break
                    }
                }
            }
        } else if days > 7 {
            // 1M view - show each month label once in the middle
            let startComponents = calendar.dateComponents([.year, .month], from: expandedXDomain.lowerBound)
            let endComponents = calendar.dateComponents([.year, .month], from: expandedXDomain.upperBound)
            
            if let startDate = calendar.date(from: startComponents),
               let endDate = calendar.date(from: endComponents) {
                var currentDate = startDate
                var seenMonths = Set<String>()
                while currentDate <= endDate {
                    let monthKey = "\(calendar.component(.year, from: currentDate))-\(calendar.component(.month, from: currentDate))"
                    if !seenMonths.contains(monthKey) {
                        if let midMonth = calendar.date(bySetting: .day, value: 15, of: currentDate) {
                            result.append((midMonth, formatter.string(from: currentDate)))
                            seenMonths.insert(monthKey)
                        }
                    }
                    if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) {
                        currentDate = nextMonth
                    } else {
                        break
                    }
                }
            }
        } else {
            // Week view - day labels evenly spaced
            let count = min(5, expandedPoints.count)
            let step = max(1, expandedPoints.count / count)
            for i in stride(from: 0, to: expandedPoints.count, by: step) {
                let date = expandedPoints[i].date
                result.append((date, formatter.string(from: date)))
            }
        }
        
        return result
    }
    
    private func expandedXPosition(for date: Date, in size: CGSize) -> CGFloat {
        let total = expandedXDomain.upperBound.timeIntervalSince(expandedXDomain.lowerBound)
        guard total > 0 else { return 0 }
        let t = date.timeIntervalSince(expandedXDomain.lowerBound) / total
        return CGFloat(t) * size.width
    }
    
    private var expandedTimeFrameButtons: some View {
        HStack(spacing: 8) {
            ForEach(TimeFrame.allCases, id: \.self) { tf in
                Button {
                    if tf != expandedSelectedTimeFrame {
                        expandedSelectedTimeFrame = tf
                        expandedSelectedIndex = nil
                        loadExpandedData()
                    }
                } label: {
                    Text(tf.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(expandedSelectedTimeFrame == tf ? .white : .blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(expandedSelectedTimeFrame == tf ? Color.blue : Color.blue.opacity(0.1))
                        )
                }
            }
        }
    }
    
    // MARK: - Expanded Data Loading
    
    private func loadExpandedData() {
        let all = weightLogManager.allEntries.sorted { $0.date < $1.date }
        guard !all.isEmpty else {
            expandedPoints = []
            expandedIsLoading = false
            return
        }
        
        let currentHash = all.map { $0.id.hashValue }.reduce(0, ^)
        let dataChanged = currentHash != expandedLastDataHash
        
        // Determine effective smoothing timeframe
        let smoothingTimeframe: TimeFrame
        if expandedSelectedTimeFrame == .allTime, let firstDate = all.first?.date, let lastDate = all.last?.date {
            let calendar = Calendar.current
            let days = calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
            
            if days <= 7 {
                smoothingTimeframe = .oneWeek
            } else if days <= 30 {
                smoothingTimeframe = .oneMonth
            } else if days <= 90 {
                smoothingTimeframe = .threeMonths
            } else if days <= 365 {
                smoothingTimeframe = .oneYear
            } else {
                smoothingTimeframe = .allTime
            }
        } else {
            smoothingTimeframe = expandedSelectedTimeFrame
        }
        
        // Check cache
        if !dataChanged, let cached = expandedSmoothedDataCache[smoothingTimeframe] {
            applyExpandedSmoothedData(cached, all: all)
            return
        }
        
        expandedIsLoading = true
        
        Task(priority: .userInitiated) {
            let smoothed = smoothedTrendForDashboard(from: all, timeframe: smoothingTimeframe)
            
            await MainActor.run {
                expandedSmoothedDataCache[smoothingTimeframe] = smoothed
                expandedLastDataHash = currentHash
                applyExpandedSmoothedData(smoothed, all: all)
            }
        }
    }
    
    private func applyExpandedSmoothedData(_ smoothed: [WeightLogEntry], all: [WeightLogEntry]) {
        guard let lastDate = all.last?.date else {
            expandedPoints = []
            expandedIsLoading = false
            return
        }
        
        let firstDate: Date
        if expandedSelectedTimeFrame == .allTime {
            firstDate = all.first?.date ?? lastDate
        } else if let days = expandedSelectedTimeFrame.days {
            firstDate = Calendar.current.date(byAdding: .day, value: -days, to: lastDate) ?? lastDate
        } else {
            firstDate = all.first?.date ?? lastDate
        }
        
        let weights = smoothed.map { $0.weight }
        let minW = weights.min() ?? 0
        let maxW = weights.max() ?? 100
        let range = maxW - minW
        let padding = max(range * 0.15, 0.5)
        let yRange = (minW - padding)...(maxW + padding)
        
        expandedPoints = smoothed
        expandedXDomain = firstDate...lastDate
        expandedYDomain = yRange
        expandedSelectedIndex = nil
        expandedIsLoading = false
    }
    
    // MARK: - Dashboard Chart Drawing (3M style, no labels)
    
    private func drawDashboardChart(in context: GraphicsContext, size: CGSize) {
        guard recentWeights.count >= 2 else { return }
        
        // Draw gridlines first (background)
        drawDashboardGrid(in: context, size: size)
        
        // Draw the weight line
        drawDashboardLine(in: context, size: size)
    }
    
    private func drawDashboardGrid(in context: GraphicsContext, size: CGSize) {
        let range = yAxisRange.upperBound - yAxisRange.lowerBound
        
        // Determine Y-axis interval (same logic as detailed chart)
        let interval: Double
        if range <= 3.0 {
            interval = 0.2
        } else if range <= 7.0 {
            interval = 0.5
        } else if range <= 10.0 {
            interval = 1.0
        } else {
            interval = 2.0
        }
        
        // Generate Y-axis gridline values
        let minRounded = (yAxisRange.lowerBound / interval).rounded(.down) * interval
        var labels: [Double] = []
        var current = minRounded
        while current <= yAxisRange.upperBound {
            if current >= yAxisRange.lowerBound {
                labels.append(current)
            }
            current += interval
        }
        
        // Draw horizontal gridlines
        var gridPath = Path()
        for value in labels {
            let y = yPositionDashboard(for: value, in: size)
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(gridPath, with: .color(Color.gray.opacity(0.4)), lineWidth: 1.0)
        
        // Draw vertical monthly gridlines (3M style)
        guard let firstDate = recentWeights.first?.date,
              let lastDate = recentWeights.last?.date else { return }
        
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month], from: firstDate)
        let endComponents = calendar.dateComponents([.year, .month], from: lastDate)
        
        if let startDate = calendar.date(from: startComponents),
           let endDate = calendar.date(from: endComponents) {
            
            var monthPath = Path()
            var currentDate = startDate
            
            while currentDate <= endDate {
                if currentDate >= firstDate && currentDate <= lastDate {
                    let x = xPositionDashboard(for: currentDate, in: size, firstDate: firstDate, lastDate: lastDate)
                    monthPath.move(to: CGPoint(x: x, y: 0))
                    monthPath.addLine(to: CGPoint(x: x, y: size.height))
                }
                
                if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) {
                    currentDate = nextMonth
                } else {
                    break
                }
            }
            
            context.stroke(monthPath, with: .color(Color.gray.opacity(0.4)), lineWidth: 1.0)
        }
    }
    
    private func drawDashboardLine(in context: GraphicsContext, size: CGSize) {
        guard recentWeights.count >= 2 else { return }
        guard let firstDate = recentWeights.first?.date,
              let lastDate = recentWeights.last?.date else { return }
        
        var path = Path()
        
        for (index, entry) in recentWeights.enumerated() {
            let x = xPositionDashboard(for: entry.date, in: size, firstDate: firstDate, lastDate: lastDate)
            let y = yPositionDashboard(for: entry.weight, in: size)
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        context.stroke(
            path,
            with: .color(Color(hex: "#5ec5ff")),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
    }
    
    private func xPositionDashboard(for date: Date, in size: CGSize, firstDate: Date, lastDate: Date) -> CGFloat {
        let total = lastDate.timeIntervalSince(firstDate)
        guard total > 0 else { return 0 }
        let t = date.timeIntervalSince(firstDate) / total
        return CGFloat(t) * size.width
    }
    
    private func yPositionDashboard(for weight: Double, in size: CGSize) -> CGFloat {
        let range = yAxisRange.upperBound - yAxisRange.lowerBound
        guard range > 0 else { return size.height / 2 }
        let normalized = (weight - yAxisRange.lowerBound) / range
        return size.height - (CGFloat(normalized) * size.height)
    }
    
    // MARK: - Smoothing for Dashboard
    
    /// Apply same smoothing algorithm as detailed view for dashboard preview
    private func smoothedTrendForDashboard(from allEntries: [WeightLogEntry], timeframe: TimeFrame) -> [WeightLogEntry] {
        guard !allEntries.isEmpty else { return [] }
        
        let sorted = allEntries.sorted { $0.date < $1.date }
        let params = timeframe.smoothingParameters
        
        // Build daily series with gap filling from full history
        let daily = buildDailySeriesForDashboard(from: sorted)
        
        // Apply DES + turning damping + MA polish
        let trend = buildTrendFromDailyForDashboard(
            daily: daily,
            alpha: params.alpha,
            beta: params.beta,
            window: params.windowSize,
            turning: params.turning
        )
        
        // Map to WeightLogEntry
        var fullResult: [WeightLogEntry] = []
        fullResult.reserveCapacity(daily.count)
        
        for (index, day) in daily.enumerated() {
            let smoothedWeight = trend[index]
            fullResult.append(
                WeightLogEntry(
                    id: UUID(),
                    date: day.date,
                    weight: smoothedWeight,
                    movingAverage: smoothedWeight,
                    weeklyRate: nil,
                    notes: nil
                )
            )
        }
        
        // Trim to timeframe (3 months)
        if let days = timeframe.days, let fullEnd = fullResult.last?.date {
            let calendar = Calendar.current
            let cutoff = calendar.date(byAdding: .day, value: -days, to: fullEnd) ?? fullEnd
            return fullResult.filter { $0.date >= cutoff }
        }
        
        return fullResult
    }
    
    /// Build daily series with gap filling
    private func buildDailySeriesForDashboard(from entries: [WeightLogEntry]) -> [(date: Date, weight: Double)] {
        guard !entries.isEmpty else { return [] }
        
        let calendar = Calendar.current
        let sorted = entries.sorted { $0.date < $1.date }
        
        guard let firstDate = sorted.first?.date,
              let lastDate = sorted.last?.date else { return [] }
        
        let startDay = calendar.startOfDay(for: firstDate)
        let endDay = calendar.startOfDay(for: lastDate)
        
        var result: [(date: Date, weight: Double)] = []
        var currentDate = startDay
        var entryIndex = 0
        
        while currentDate <= endDay {
            let currentDay = calendar.startOfDay(for: currentDate)
            
            // Find entry for this day
            while entryIndex < sorted.count {
                let entryDay = calendar.startOfDay(for: sorted[entryIndex].date)
                if entryDay == currentDay {
                    result.append((date: currentDay, weight: sorted[entryIndex].weight))
                    entryIndex += 1
                    break
                } else if entryDay > currentDay {
                    // Gap - interpolate
                    if let prevWeight = result.last?.weight {
                        result.append((date: currentDay, weight: prevWeight))
                    }
                    break
                } else {
                    entryIndex += 1
                }
            }
            
            if entryIndex >= sorted.count && currentDay < endDay {
                // Fill remaining days with last weight
                if let lastWeight = result.last?.weight {
                    result.append((date: currentDay, weight: lastWeight))
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return result
    }
    
    /// Build trend using DES + turning damping + MA polish
    private func buildTrendFromDailyForDashboard(
        daily: [(date: Date, weight: Double)],
        alpha: Double,
        beta: Double,
        window: Int,
        turning: Double
    ) -> [Double] {
        guard !daily.isEmpty else { return [] }
        
        let weights = daily.map { $0.weight }
        
        // Stage 1: Double Exponential Smoothing
        var level = weights[0]
        var trend = 0.0
        var smoothed = [level]
        
        for i in 1..<weights.count {
            let prevLevel = level
            level = alpha * weights[i] + (1 - alpha) * (level + trend)
            trend = beta * (level - prevLevel) + (1 - beta) * trend
            smoothed.append(level + trend)
        }
        
        // Stage 2: Turning point damping
        var damped = smoothed
        if smoothed.count > 2 {
            for i in 1..<(smoothed.count - 1) {
                let prev = smoothed[i - 1]
                let curr = smoothed[i]
                let next = smoothed[i + 1]
                
                let isTurning = (curr > prev && curr > next) || (curr < prev && curr < next)
                if isTurning {
                    damped[i] = curr * (1 - turning) + (prev + next) / 2 * turning
                }
            }
        }
        
        // Stage 3: Moving average polish
        let halfWindow = window / 2
        var polished = damped
        
        for i in 0..<damped.count {
            let start = max(0, i - halfWindow)
            let end = min(damped.count - 1, i + halfWindow)
            let slice = damped[start...end]
            polished[i] = slice.reduce(0, +) / Double(slice.count)
        }
        
        return polished
    }
}

// MARK: - Timeframe

enum TimeFrame: String, CaseIterable {
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case oneYear = "1Y"
    case allTime = "All"

    var days: Int? {
        switch self {
        case .oneWeek: return 7
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .oneYear: return 365
        case .allTime: return nil
        }
    }
    
    /// Parameters for Happy Scale-style smoothing
    /// α (alpha): 0.06-0.20 range - level smoothing
    /// β (beta): 0.03-0.10 range - trend smoothing
    /// windowSize: 5-13 for centered MA polish
    /// turning: 0.2-0.6 - turning point damping strength
    var smoothingParameters: (alpha: Double, beta: Double, windowSize: Int, turning: Double) {
        switch self {
        case .oneWeek:
            // Most responsive for short-term tracking
            return (alpha: 0.45, beta: 0.25, windowSize: 3, turning: 0.2)
        case .oneMonth:
            // Balanced responsiveness
            return (alpha: 0.35, beta: 0.18, windowSize: 5, turning: 0.3)
        case .threeMonths:
            // Medium smooth
            return (alpha: 0.26, beta: 0.11, windowSize: 7, turning: 0.3)
        case .oneYear:
            // Smooth trend focus
            return (alpha: 0.26, beta: 0.11, windowSize: 31, turning: 0.55)
        case .allTime:
            // Very smooth for long-term patterns
            return (alpha: 0.18, beta: 0.07, windowSize: 37, turning: 0.75)
        }
    }
}

// MARK: - Detail View (Canvas-based, smooth scrubbing)

struct WeightChartDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var weightLogManager = WeightLogManager.shared
    
    private var viewBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }

    @State private var selectedTimeFrame: TimeFrame = .allTime
    @State private var points: [WeightLogEntry] = []
    @State private var xDomain: ClosedRange<Date> = Date()...Date()
    @State private var yDomain: ClosedRange<Double> = 0...100

    @State private var selectedIndex: Int? = nil
    @State private var isLoading = true
    
    // Cache for smoothed data per timeframe to avoid recalculation
    @State private var smoothedDataCache: [TimeFrame: [WeightLogEntry]] = [:]
    @State private var lastDataHash: Int = 0

    // For simple throttling / haptics
    @State private var lastSelectedIndex: Int? = nil
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    // MARK: - Derived stats

    private var statsData: [WeightLogEntry] {
        // For stats we want real entries in this timeframe (unsmoothed)
        let all = weightLogManager.allEntries.sorted { $0.date < $1.date }
        guard !all.isEmpty else { return [] }

        if selectedTimeFrame == .allTime {
            return all
        }

        if let days = selectedTimeFrame.days,
           let latest = all.last?.date {
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: latest) ?? latest
            return all.filter { $0.date >= cutoff }
        }

        return all
    }

    // MARK: - Lifecycle

    var body: some View {
        NavigationView {
            ZStack {
                viewBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if isLoading {
                            VStack(spacing: 16) {
                                ProgressView().scaleEffect(1.2)
                                Text("Loading weight data…")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else if points.isEmpty {
                            noDataView
                        } else {
                            chartSection
                            statisticsSection
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("Weight Chart Details")
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
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                haptic.prepare()
                loadForCurrentTimeframe()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Chart section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weight Trends")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.leading, 14)
                .padding(.top, 14)

            VStack(spacing: 0) {
                // Chart card
                VStack(spacing: 0) {
                    CanvasChart(
                        points: points,
                        xDomain: xDomain,
                        yDomain: yDomain,
                        timeframe: selectedTimeFrame,
                        enableGestures: true,  // Enable crosshair in detail view
                        selectedIndex: $selectedIndex
                    )
                    .id("\(points.count)-\(selectedTimeFrame.rawValue)")  // Force redraw on data change

                    // X-axis labels (simple, but matches overall feel)
                    xAxisLabelsView
                }

                timeFrameButtons
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: Color.black.opacity(0.08),
                        radius: 8, x: 0, y: 2
                    )
            )
        }
    }

    // MARK: - X-axis labels

    private var xAxisLabelsView: some View {
        let labels = axisLabels()
        let effectiveTimeframe = effectiveTimeframeForAllTime()

        // For 1M, 3M, 1Y, and All timeframes, position labels based on actual dates
        if effectiveTimeframe == .oneMonth || effectiveTimeframe == .oneYear || effectiveTimeframe == .threeMonths || effectiveTimeframe == .allTime {
            return AnyView(
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        ForEach(labels, id: \.0) { (date, label) in
                            let xPos = xPosition(for: date, in: CGSize(width: geo.size.width - 40, height: 0))
                            Text(label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                                .position(x: xPos + 40, y: 10) // +40 for Y-axis label offset
                        }
                    }
                }
                .frame(height: 20)
                .padding(.top, 8)
            )
        } else {
            // For 1W timeframe, use evenly distributed HStack
            return AnyView(
                HStack {
                    ForEach(labels, id: \.0) { (date, label) in
                        Text(label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 8)
            )
        }
    }

    /// Decide what to show on the X axis based on timeframe
    private func axisLabels() -> [(Date, String)] {
        guard !points.isEmpty else { return [] }

        let formatter = DateFormatter()
        formatter.locale = .current

        // Use effective timeframe for All Time views
        let effectiveTimeframe = effectiveTimeframeForAllTime()
        
        switch effectiveTimeframe {
        case .oneWeek:
            formatter.dateFormat = "EEE"
        case .oneMonth:
            formatter.dateFormat = "MMM" // Month abbreviation (Jan, Feb, etc.)
        case .threeMonths:
            formatter.dateFormat = "MMM" // Month abbreviation (Jan, Feb, etc.)
        case .oneYear:
            formatter.dateFormat = "MMMMM" // Single letter month (J, F, M, A, etc.)
        case .allTime:
            formatter.dateFormat = "yyyy"
        }

        // For All Time (>365 days), show year labels positioned in the middle of each year
        if effectiveTimeframe == .allTime {
            var result: [(Date, String)] = []
            let calendar = Calendar.current
            
            // Get start and end years from actual data
            let startYear = calendar.component(.year, from: xDomain.lowerBound)
            let endYear = calendar.component(.year, from: xDomain.upperBound)
            
            for year in startYear...endYear {
                // Position label at July 1st (middle of year)
                if let yearMid = calendar.date(from: DateComponents(year: year, month: 7, day: 1)) {
                    // Only include if the year has data within it
                    let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
                    let yearEnd = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!
                    
                    // Check if this year overlaps with our data range
                    if yearEnd >= xDomain.lowerBound && yearStart <= xDomain.upperBound {
                        result.append((yearMid, "\(year)"))
                    }
                }
            }
            
            return result
        }
        
        // For 1M, 3M, and 1Y, show all months with labels positioned in the middle
        if effectiveTimeframe == .oneMonth || effectiveTimeframe == .oneYear || effectiveTimeframe == .threeMonths {
            var result: [(Date, String)] = []
            let calendar = Calendar.current
            
            // Get start and end months
            let startComponents = calendar.dateComponents([.year, .month], from: xDomain.lowerBound)
            let endComponents = calendar.dateComponents([.year, .month], from: xDomain.upperBound)
            
            if let startDate = calendar.date(from: startComponents),
               let endDate = calendar.date(from: endComponents) {
                
                var currentDate = startDate
                
                // Add label for each month, positioned in the middle of the month
                while currentDate <= endDate {
                    // Only show label if the 1st of this month is within the data range
                    // (i.e., there's a gridline for this month)
                    if currentDate >= xDomain.lowerBound && currentDate <= xDomain.upperBound {
                        // Position label at day 15 (middle of month)
                        if let midMonth = calendar.date(bySetting: .day, value: 15, of: currentDate) {
                            result.append((midMonth, formatter.string(from: currentDate)))
                        }
                    }
                    
                    // Move to next month
                    if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) {
                        currentDate = nextMonth
                    } else {
                        break
                    }
                }
            }
            
            return result
        }
        
        // For 1W: evenly spaced day labels
        let count = max(3, min(6, points.count))
        let step = max(1, points.count / (count - 1))

        var result: [(Date, String)] = []
        for i in stride(from: 0, to: points.count, by: step) {
            let idx = min(i, points.count - 1)
            let date = points[idx].date
            result.append((date, formatter.string(from: date)))
        }

        // Ensure end label is included
        if let last = points.last {
            let label = formatter.string(from: last.date)
            if result.last?.1 != label {
                result.append((last.date, label))
            }
        }

        return result
    }
    
    // MARK: - Helper functions
    
    /// Determine appropriate display mode for All Time based on actual data range
    private func effectiveTimeframeForAllTime() -> TimeFrame {
        guard selectedTimeFrame == .allTime, !points.isEmpty else {
            return selectedTimeFrame
        }
        
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: xDomain.lowerBound, to: xDomain.upperBound).day ?? 0
        
        if days <= 7 {
            return .oneWeek
        } else if days <= 30 {
            return .oneMonth
        } else if days <= 90 {
            return .threeMonths
        } else if days <= 365 {
            return .oneYear
        } else {
            return .allTime  // Keep as yearly for >365 days
        }
    }
    
    private func xPosition(for date: Date, in size: CGSize) -> CGFloat {
        let total = xDomain.upperBound.timeIntervalSince(xDomain.lowerBound)
        guard total > 0 else { return 0 }
        let t = date.timeIntervalSince(xDomain.lowerBound) / total
        return CGFloat(t) * size.width
    }

    // MARK: - Timeframe buttons

    private var timeFrameButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeFrame.allCases, id: \.self) { tf in
                    Button {
                        if tf != selectedTimeFrame {
                            selectedTimeFrame = tf
                            selectedIndex = nil
                            loadForCurrentTimeframe()
                        }
                    } label: {
                        Text(tf.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedTimeFrame == tf ? .white : .blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedTimeFrame == tf ? Color.blue : Color.blue.opacity(0.1))
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Statistics section

    private var statisticsSection: some View {
        let data = statsData

        return VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.leading, 14)
                .padding(.top, 14)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatCard(
                    title: "Current",
                    value: data.last.map { String(format: "%.1f kg", $0.weight) } ?? "—",
                    color: .blue
                )

                StatCard(
                    title: "Highest",
                    value: data.map { $0.weight }.max().map { String(format: "%.1f kg", $0) } ?? "—",
                    color: .red
                )

                StatCard(
                    title: "Lowest",
                    value: data.map { $0.weight }.min().map { String(format: "%.1f kg", $0) } ?? "—",
                    color: .green
                )

                StatCard(
                    title: "Change",
                    value: changeText(for: data),
                    color: changeColor(for: data)
                )
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.9)
        }
    }

    private func changeText(for data: [WeightLogEntry]) -> String {
        guard let first = data.first?.weight, let last = data.last?.weight else { return "—" }
        let diff = last - first
        let sign = diff >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", diff)) kg"
    }

    private func changeColor(for data: [WeightLogEntry]) -> Color {
        guard let first = data.first?.weight, let last = data.last?.weight else { return .secondary }
        return (last - first) >= 0 ? .red : .green
    }

    // MARK: - No data view

    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Weight Data")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start logging your weight to see your progress chart here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Data prep

    private func loadForCurrentTimeframe() {
        let all = weightLogManager.allEntries.sorted { $0.date < $1.date }
        guard !all.isEmpty else {
            self.points = []
            self.isLoading = false
            return
        }
        
        // Calculate data hash to detect changes
        let currentHash = all.map { $0.id.hashValue }.reduce(0, ^)
        let dataChanged = currentHash != lastDataHash
        
        // Determine the effective smoothing timeframe
        let smoothingTimeframe: TimeFrame
        if self.selectedTimeFrame == .allTime, let firstDate = all.first?.date, let lastDate = all.last?.date {
            let calendar = Calendar.current
            let days = calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
            
            if days <= 7 {
                smoothingTimeframe = .oneWeek
            } else if days <= 30 {
                smoothingTimeframe = .oneMonth
            } else if days <= 90 {
                smoothingTimeframe = .threeMonths
            } else if days <= 365 {
                smoothingTimeframe = .oneYear
            } else {
                smoothingTimeframe = .allTime
            }
        } else {
            smoothingTimeframe = self.selectedTimeFrame
        }
        
        // Check cache first - if data hasn't changed and we have cached results, use them
        if !dataChanged, let cached = smoothedDataCache[smoothingTimeframe] {
            // Use cached data - instant display
            applySmoothedData(cached, all: all)
            return
        }
        
        // Need to compute - show loading indicator
        isLoading = true
        
        Task(priority: .userInitiated) {
            let smoothed = self.smoothedTrend(from: all, timeframe: smoothingTimeframe)
            
            await MainActor.run {
                // Update cache
                self.smoothedDataCache[smoothingTimeframe] = smoothed
                self.lastDataHash = currentHash
                
                // Apply the data
                self.applySmoothedData(smoothed, all: all)
            }
        }
    }
    
    private func applySmoothedData(_ smoothed: [WeightLogEntry], all: [WeightLogEntry]) {
        guard let lastDate = all.last?.date else {
            self.points = []
            self.isLoading = false
            return
        }
        
        // X-axis should span the full requested timeframe, not just available data
        let firstDate: Date
        if self.selectedTimeFrame == .allTime {
            firstDate = all.first?.date ?? lastDate
        } else if let days = self.selectedTimeFrame.days {
            firstDate = Calendar.current.date(byAdding: .day, value: -days, to: lastDate) ?? lastDate
        } else {
            firstDate = all.first?.date ?? lastDate
        }

        let weights = smoothed.map { $0.weight }
        let minW = weights.min() ?? 0
        let maxW = weights.max() ?? 100
        let range = maxW - minW
        // Reduced padding: 15% of range with minimum of 0.5kg
        let padding = max(range * 0.15, 0.5)
        let yRange = (minW - padding)...(maxW + padding)

        self.points = smoothed
        self.xDomain = firstDate...lastDate
        self.yDomain = yRange
        self.selectedIndex = nil
        self.isLoading = false
    }
    
    // MARK: - Happy Scale 4-Stage Algorithm (Complete Specification)
    
    /// STAGE 0: Build daily series with gradient-based gap filling
    private func buildDailySeries(from entries: [WeightLogEntry]) -> [(date: Date, weight: Double)] {
        guard let first = entries.first?.date,
              let last = entries.last?.date else { return [] }
        
        var daily: [(date: Date, weight: Double)] = []
        var idx = 0
        let n = entries.count
        let calendar = Calendar.current
        
        var current = calendar.startOfDay(for: first)
        let endDate = calendar.startOfDay(for: last)
        
        while current <= endDate {
            // Move idx until entries[idx].date >= current
            while idx < n && calendar.startOfDay(for: entries[idx].date) < current {
                idx += 1
            }
            
            let w: Double
            
            if idx < n && calendar.isDate(entries[idx].date, inSameDayAs: current) {
                // Exact match
                w = entries[idx].weight
            } else {
                // In a gap - interpolate
                let prevIdx = idx - 1
                let nextIdx = idx
                
                if prevIdx >= 0 && nextIdx < n {
                    // Linear interpolation between prev and next
                    let prev = entries[prevIdx]
                    let next = entries[nextIdx]
                    
                    let totalDays = calendar.dateComponents([.day], from: prev.date, to: next.date).day ?? 1
                    let daysFromPrev = calendar.dateComponents([.day], from: prev.date, to: current).day ?? 0
                    let t = max(0.0, min(1.0, Double(daysFromPrev) / Double(totalDays)))
                    
                    w = prev.weight + t * (next.weight - prev.weight)
                } else if prevIdx >= 0 {
                    // After last reading → hold forward
                    w = entries[prevIdx].weight
                } else {
                    // Before first reading
                    w = entries[nextIdx].weight
                }
            }
            
            daily.append((date: current, weight: w))
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        
        return daily
    }
    
    /// STAGE 1 & 2: DES with STRONG turning point damping (affects α, β, and slope)
    private func desWithStrongTurning(
        values: [Double],
        alpha: Double,
        beta: Double,
        turning: Double
    ) -> [Double] {
        let n = values.count
        guard n >= 2 else { return values }
        
        var level = values[0]
        var trend = values[1] - values[0]
        var result = Array(repeating: 0.0, count: n)
        
        var prevDelta = values[1] - values[0]
        
        for i in 0..<n {
            let x = values[i]
            let delta = i > 0 ? x - values[i - 1] : prevDelta
            
            // Detect slope reversal (sign flip)
            let isTurning = (i > 1 &&
                           ((delta > 0 && prevDelta < 0) || (delta < 0 && prevDelta > 0)) &&
                           delta != 0 && prevDelta != 0)
            
            var a = alpha
            var b = beta
            
            if isTurning {
                // Nonlinear punch for stronger damping
                let t = turning * turning
                a = alpha * (1 - 0.85 * t)  // Reduce alpha
                b = beta * (1 - 0.90 * t)   // Reduce beta even more
                trend *= (1 - 0.70 * t)     // Flatten slope
            }
            
            let prevLevel = level
            level = a * x + (1 - a) * (level + trend)
            trend = b * (level - prevLevel) + (1 - b) * trend
            
            // Clamp slope to prevent runaway
            trend = min(1.5, max(-1.5, trend))
            
            result[i] = level + trend
            prevDelta = delta
        }
        
        return result
    }
    
    /// STAGE 3: Centered moving average polish
    private func movingAverage(values: [Double], window: Int) -> [Double] {
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
    
    /// Complete pipeline: daily series → DES → MA → output
    private func buildTrendFromDaily(
        daily: [(date: Date, weight: Double)],
        alpha: Double,
        beta: Double,
        window: Int,
        turning: Double
    ) -> [Double] {
        let raw = daily.map { $0.weight }
        let des = desWithStrongTurning(values: raw, alpha: alpha, beta: beta, turning: turning)
        return movingAverage(values: des, window: window)
    }
    
    /// Build Happy Scale-style smooth trend line using complete 4-stage algorithm
    /// CRITICAL: Must be called with ALL entries, then trim result to timeframe
    private func smoothedTrend(
        from allEntries: [WeightLogEntry],
        timeframe: TimeFrame,
        trimToTimeframe: Bool = true
    ) -> [WeightLogEntry] {
        guard !allEntries.isEmpty else { return [] }
        
        let sorted = allEntries.sorted { $0.date < $1.date }
        let params = timeframe.smoothingParameters
        
        // STAGE 0: Build daily series with gap filling FROM FULL HISTORY
        // This is critical - gap filling needs previous data to interpolate
        let daily = buildDailySeries(from: sorted)
        
        // STAGES 1-3: DES + turning damping + MA polish on FULL series
        let trend = buildTrendFromDaily(
            daily: daily,
            alpha: params.alpha,
            beta: params.beta,
            window: params.windowSize,
            turning: params.turning
        )
        
        // Map full trend to WeightLogEntry
        var fullResult: [WeightLogEntry] = []
        fullResult.reserveCapacity(daily.count)
        
        for (index, day) in daily.enumerated() {
            let smoothedWeight = trend[index]
            
            fullResult.append(
                WeightLogEntry(
                    id: UUID(),
                    date: day.date,
                    weight: smoothedWeight,
                    movingAverage: smoothedWeight,
                    weeklyRate: nil,
                    notes: nil
                )
            )
        }
        
        // NOW trim to timeframe (like Python does)
        if trimToTimeframe, timeframe != .allTime, let days = timeframe.days,
           let fullEnd = fullResult.last?.date {
            let calendar = Calendar.current
            let cutoff = calendar.date(byAdding: .day, value: -days, to: fullEnd) ?? fullEnd
            return fullResult.filter { $0.date >= cutoff }
        }
        
        return fullResult
    }

}

// MARK: - Canvas Chart View

private struct CanvasChart: View {
    let points: [WeightLogEntry]
    let xDomain: ClosedRange<Date>
    let yDomain: ClosedRange<Double>
    let timeframe: TimeFrame
    var chartHeight: CGFloat = 320  // Default height, can be overridden
    var enableGestures: Bool = false  // Disable by default for dashboard scrolling

    @Binding var selectedIndex: Int?
    
    // Haptic feedback - throttled to avoid rate-limit errors
    @State private var lastSelectedIndex: Int? = nil
    @State private var lastHapticTime: Date = .distantPast
    private let selectionHaptic = UISelectionFeedbackGenerator()
    private let hapticThrottleInterval: TimeInterval = 0.05 // 50ms minimum between haptics

    private let gridLineCount = 5
    
    /// Determine appropriate display mode for All Time based on actual data range
    private func effectiveTimeframeForAllTime() -> TimeFrame {
        guard timeframe == .allTime, !points.isEmpty else {
            return timeframe
        }
        
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: xDomain.lowerBound, to: xDomain.upperBound).day ?? 0
        
        if days <= 7 {
            return .oneWeek
        } else if days <= 30 {
            return .oneMonth
        } else if days <= 90 {
            return .threeMonths
        } else if days <= 365 {
            return .oneYear
        } else {
            return .allTime  // Keep as yearly for >365 days
        }
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            // Calculate effective timeframe for All Time views before Canvas
            let effectiveTimeframe = effectiveTimeframeForAllTime()

            ZStack(alignment: .leading) {
                // Main chart (line + grid) - offset to make room for Y-axis labels
                Canvas { context, canvasSize in
                    drawGrid(in: context, size: canvasSize, timeframe: timeframe, effectiveTimeframe: effectiveTimeframe)
                    drawLine(in: context, size: canvasSize)
                }
                .frame(height: size.height)
                .padding(.leading, 40) // Space for Y-axis labels

                // Y-axis labels
                yAxisLabels(height: size.height)
                    .frame(width: 40, alignment: .trailing)

                // Crosshair overlay (separate layer)
                if let idx = selectedIndex, points.indices.contains(idx) {
                    crosshair(for: points[idx], in: CGSize(width: size.width - 40, height: size.height))
                        .offset(x: 40) // Offset to account for Y-axis labels
                }
            }
            // Conditionally enable gestures (disabled on dashboard for scrolling)
            .allowsHitTesting(enableGestures)
            .onTapGesture { location in
                guard enableGestures else { return }
                let adjustedX = location.x - 40
                let chartSize = CGSize(width: size.width - 40, height: size.height)
                let idx = index(for: adjustedX, width: chartSize.width)
                
                if points.indices.contains(idx) {
                    if selectedIndex == idx {
                        selectedIndex = nil
                    } else {
                        selectedIndex = idx
                        selectionHaptic.selectionChanged()
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        guard enableGestures else { return }
                        let horizontalDistance = abs(value.translation.width)
                        let verticalDistance = abs(value.translation.height)
                        guard horizontalDistance > verticalDistance else { return }
                        
                        let chartWidth = size.width - 40
                        let adjustedX = value.location.x - 40
                        let clamped = max(0, min(chartWidth, adjustedX))
                        let ratio = clamped / chartWidth
                        let idx = Int(round(ratio * CGFloat(points.count - 1)))
                        let clampedIdx = max(0, min(points.count - 1, idx))
                        
                        if clampedIdx != selectedIndex {
                            selectedIndex = clampedIdx
                            if lastSelectedIndex != clampedIdx {
                                let now = Date()
                                if now.timeIntervalSince(lastHapticTime) >= hapticThrottleInterval {
                                    selectionHaptic.selectionChanged()
                                    lastHapticTime = now
                                }
                                lastSelectedIndex = clampedIdx
                            }
                        }
                    }
                    .onEnded { _ in
                        guard enableGestures else { return }
                        selectedIndex = nil
                        lastSelectedIndex = nil
                    }
            )
        }
        .frame(height: chartHeight)
    }
    
    // MARK: - Y-axis labels
    
    private func yAxisLabels(height: CGFloat) -> some View {
        GeometryReader { _ in
            let range = yDomain.upperBound - yDomain.lowerBound
            let interval = yAxisInterval(for: range)
            let labels = generateYAxisLabels(range: range, interval: interval)
            
            ZStack(alignment: .trailing) {
                ForEach(labels, id: \.self) { value in
                    let y = yPosition(for: value, in: CGSize(width: 0, height: height))
                    
                    Text(String(format: "%.1f", value))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                        .position(x: 30, y: y)
                }
            }
        }
    }
    
    /// Determine Y-axis interval based on range
    private func yAxisInterval(for range: Double) -> Double {
        if range <= 3.0 {
            return 0.2
        } else if range <= 7.0 {
            return 0.5
        } else if range <= 10.0 {
            return 1.0
        } else {
            return 2.0
        }
    }
    
    /// Generate Y-axis label values
    private func generateYAxisLabels(range: Double, interval: Double) -> [Double] {
        var labels: [Double] = []
        
        // Round min to nearest interval
        let minRounded = (yDomain.lowerBound / interval).rounded(.down) * interval
        
        var current = minRounded
        while current <= yDomain.upperBound {
            if current >= yDomain.lowerBound {
                labels.append(current)
            }
            current += interval
        }
        
        return labels
    }

    // MARK: - Drawing helpers

    private func drawGrid(in context: GraphicsContext, size: CGSize, timeframe: TimeFrame, effectiveTimeframe: TimeFrame) {
        guard !points.isEmpty else { return }

        var gridPath = Path()

        // Horizontal gridlines - align with Y-axis labels
        let range = yDomain.upperBound - yDomain.lowerBound
        let interval = yAxisInterval(for: range)
        let labels = generateYAxisLabels(range: range, interval: interval)
        
        for value in labels {
            let y = yPosition(for: value, in: size)
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: size.width, y: y))
        }

        // All horizontal gridlines with Y-axis labels use consistent style
        context.stroke(gridPath, with: .color(Color.gray.opacity(0.4)), lineWidth: 1.0)
        
        // Add intermediate gridlines when labels are every 2kg
        if interval == 2.0 {
            var intermediateGridPath = Path()
            
            // Generate intermediate gridlines at 1kg intervals
            let minRounded = (yDomain.lowerBound / 1.0).rounded(.down) * 1.0
            var current = minRounded
            
            while current <= yDomain.upperBound {
                // Only draw if this is NOT a label position (labels are at 2kg intervals)
                let isLabelPosition = labels.contains(where: { abs($0 - current) < 0.01 })
                
                if !isLabelPosition && current >= yDomain.lowerBound {
                    let y = yPosition(for: current, in: size)
                    intermediateGridPath.move(to: CGPoint(x: 0, y: y))
                    intermediateGridPath.addLine(to: CGPoint(x: size.width, y: y))
                }
                current += 1.0
            }
            
            // Draw intermediate gridlines with lighter style
            context.stroke(intermediateGridPath, with: .color(Color.gray.opacity(0.15)), lineWidth: 0.5)
        }
        
        // Add intermediate gridlines when labels are every 1kg
        if interval == 1.0 {
            var intermediateGridPath = Path()
            
            // Generate intermediate gridlines at 0.5kg intervals
            let minRounded = (yDomain.lowerBound / 0.5).rounded(.down) * 0.5
            var current = minRounded
            
            while current <= yDomain.upperBound {
                // Only draw if this is NOT a label position (labels are at 1kg intervals)
                let isLabelPosition = labels.contains(where: { abs($0 - current) < 0.01 })
                
                if !isLabelPosition && current >= yDomain.lowerBound {
                    let y = yPosition(for: current, in: size)
                    intermediateGridPath.move(to: CGPoint(x: 0, y: y))
                    intermediateGridPath.addLine(to: CGPoint(x: size.width, y: y))
                }
                current += 0.5
            }
            
            // Draw intermediate gridlines with lighter style
            context.stroke(intermediateGridPath, with: .color(Color.gray.opacity(0.15)), lineWidth: 0.5)
        }
        
        // Add intermediate gridlines when labels are every 0.2kg (0-3kg range)
        if interval == 0.2 {
            var intermediateGridPath = Path()
            
            // Generate intermediate gridlines at 0.1kg intervals
            let minRounded = (yDomain.lowerBound / 0.1).rounded(.down) * 0.1
            var current = minRounded
            
            while current <= yDomain.upperBound {
                // Only draw if this is NOT a label position (labels are at 0.2kg intervals)
                let isLabelPosition = labels.contains(where: { abs($0 - current) < 0.01 })
                
                if !isLabelPosition && current >= yDomain.lowerBound {
                    let y = yPosition(for: current, in: size)
                    intermediateGridPath.move(to: CGPoint(x: 0, y: y))
                    intermediateGridPath.addLine(to: CGPoint(x: size.width, y: y))
                }
                current += 0.1
            }
            
            // Draw intermediate gridlines with lighter style
            context.stroke(intermediateGridPath, with: .color(Color.gray.opacity(0.15)), lineWidth: 0.5)
        }
        
        // Add intermediate gridlines when labels are every 0.5kg (3-7kg range)
        if interval == 0.5 {
            var intermediateGridPath = Path()
            
            // Generate intermediate gridlines at 0.1kg intervals
            let minRounded = (yDomain.lowerBound / 0.1).rounded(.down) * 0.1
            var current = minRounded
            
            while current <= yDomain.upperBound {
                // Only draw if this is NOT a label position (labels are at 0.5kg intervals)
                let isLabelPosition = labels.contains(where: { abs($0 - current) < 0.01 })
                
                if !isLabelPosition && current >= yDomain.lowerBound {
                    let y = yPosition(for: current, in: size)
                    intermediateGridPath.move(to: CGPoint(x: 0, y: y))
                    intermediateGridPath.addLine(to: CGPoint(x: size.width, y: y))
                }
                current += 0.1
            }
            
            // Draw intermediate gridlines with lighter style
            context.stroke(intermediateGridPath, with: .color(Color.gray.opacity(0.15)), lineWidth: 0.5)
        }
        
        // Vertical month markers for 1M, 3M, and 1Y timeframes
        if effectiveTimeframe == .oneMonth || effectiveTimeframe == .oneYear || effectiveTimeframe == .threeMonths {
            let calendar = Calendar.current
            var monthPath = Path()
            
            // Get the start and end months
            let startComponents = calendar.dateComponents([.year, .month], from: xDomain.lowerBound)
            let endComponents = calendar.dateComponents([.year, .month], from: xDomain.upperBound)
            
            if let startDate = calendar.date(from: startComponents),
               let endDate = calendar.date(from: endComponents) {
                
                var currentDate = startDate
                
                // Draw a line for the 1st of each month
                while currentDate <= endDate {
                    if currentDate >= xDomain.lowerBound && currentDate <= xDomain.upperBound {
                        let x = xPosition(for: currentDate, in: size)
                        monthPath.move(to: CGPoint(x: x, y: 0))
                        monthPath.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    
                    // Move to next month
                    if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) {
                        currentDate = nextMonth
                    } else {
                        break
                    }
                }
                
                // Draw month markers with consistent prominent style
                context.stroke(monthPath, with: .color(Color.gray.opacity(0.4)), lineWidth: 1.0)
            }
        }
        
        // Daily vertical gridlines for 1W and 1M timeframes
        if effectiveTimeframe == .oneWeek || effectiveTimeframe == .oneMonth {
            let calendar = Calendar.current
            var dailyPath = Path()
            
            // Get start and end dates
            let startDate = calendar.startOfDay(for: xDomain.lowerBound)
            let endDate = calendar.startOfDay(for: xDomain.upperBound)
            
            var currentDate = startDate
            
            // Draw a line for each day
            while currentDate <= endDate {
                if currentDate >= xDomain.lowerBound && currentDate <= xDomain.upperBound {
                    let x = xPosition(for: currentDate, in: size)
                    dailyPath.move(to: CGPoint(x: x, y: 0))
                    dailyPath.addLine(to: CGPoint(x: x, y: size.height))
                }
                
                // Move to next day
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                    currentDate = nextDay
                } else {
                    break
                }
            }
            
            // Draw daily gridlines with different styles
            if effectiveTimeframe == .oneWeek {
                context.stroke(dailyPath, with: .color(Color.gray.opacity(0.4)), lineWidth: 1.0)
            } else {
                context.stroke(dailyPath, with: .color(Color.gray.opacity(0.25)), lineWidth: 0.5)
            }
        }
        
        // Weekly gridlines for 1M timeframe (Mondays - between month markers and daily lines)
        // Visual hierarchy: Month (0.4, 1.0) > Week (0.35, 0.75) > Daily (0.25, 0.5)
        if effectiveTimeframe == .oneMonth {
            let calendar = Calendar.current
            var weekPath = Path()
            
            // Find first Monday in range
            var currentDate = calendar.startOfDay(for: xDomain.lowerBound)
            while calendar.component(.weekday, from: currentDate) != 2 { // 2 = Monday
                guard let next = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = next
            }
            
            // Iterate through Mondays
            while currentDate <= xDomain.upperBound {
                // Skip if this is the 1st of the month (already drawn as month marker)
                let dayOfMonth = calendar.component(.day, from: currentDate)
                if dayOfMonth != 1 && currentDate >= xDomain.lowerBound {
                    let x = xPosition(for: currentDate, in: size)
                    weekPath.move(to: CGPoint(x: x, y: 0))
                    weekPath.addLine(to: CGPoint(x: x, y: size.height))
                }
                
                guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) else { break }
                currentDate = nextWeek
            }
            
            context.stroke(weekPath, with: .color(Color.gray.opacity(0.35)), lineWidth: 0.75)
        }
        
        // Vertical year markers for All time view if data spans multiple years
        if effectiveTimeframe == .allTime {
            let calendar = Calendar.current
            let startYear = calendar.component(.year, from: xDomain.lowerBound)
            let endYear = calendar.component(.year, from: xDomain.upperBound)
            
            if endYear > startYear {
                var yearPath = Path()
                
                // Draw a line for each year boundary
                for year in (startYear + 1)...endYear {
                    if let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) {
                        // Only draw if within the domain
                        if yearStart >= xDomain.lowerBound && yearStart <= xDomain.upperBound {
                            let x = xPosition(for: yearStart, in: size)
                            yearPath.move(to: CGPoint(x: x, y: 0))
                            yearPath.addLine(to: CGPoint(x: x, y: size.height))
                        }
                    }
                }
                
                // Draw year markers with slightly more visible line
                context.stroke(yearPath, with: .color(Color.gray.opacity(0.4)), lineWidth: 1.0)
                
                // SUB-LINES: Monthly markers for All Time (lighter, between year markers)
                // Performance: Single path, skip Jan 1st (already drawn as year marker)
                var monthSubPath = Path()
                let startComponents = calendar.dateComponents([.year, .month], from: xDomain.lowerBound)
                
                if let iterStart = calendar.date(from: startComponents) {
                    var currentDate = iterStart
                    
                    while currentDate <= xDomain.upperBound {
                        // Skip January (month 1) - already drawn as year marker
                        let month = calendar.component(.month, from: currentDate)
                        if month != 1 && currentDate >= xDomain.lowerBound {
                            let x = xPosition(for: currentDate, in: size)
                            monthSubPath.move(to: CGPoint(x: x, y: 0))
                            monthSubPath.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        
                        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) else { break }
                        currentDate = nextMonth
                    }
                    
                    context.stroke(monthSubPath, with: .color(Color.gray.opacity(0.15)), lineWidth: 0.5)
                }
            }
        }
        
        // SUB-LINES: Weekly markers for 3M timeframe (between month markers)
        // Performance: Single path, skip 1st of month (already drawn as month marker)
        if effectiveTimeframe == .threeMonths {
            let calendar = Calendar.current
            var weekSubPath = Path()
            
            // Find first Monday in range
            var currentDate = calendar.startOfDay(for: xDomain.lowerBound)
            while calendar.component(.weekday, from: currentDate) != 2 { // 2 = Monday
                guard let next = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = next
            }
            
            // Iterate through Mondays
            while currentDate <= xDomain.upperBound {
                // Skip if this is the 1st of the month (already drawn as month marker)
                let dayOfMonth = calendar.component(.day, from: currentDate)
                if dayOfMonth != 1 && currentDate >= xDomain.lowerBound {
                    let x = xPosition(for: currentDate, in: size)
                    weekSubPath.move(to: CGPoint(x: x, y: 0))
                    weekSubPath.addLine(to: CGPoint(x: x, y: size.height))
                }
                
                guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) else { break }
                currentDate = nextWeek
            }
            
            context.stroke(weekSubPath, with: .color(Color.gray.opacity(0.15)), lineWidth: 0.5)
        }
        
        // SUB-LINES: Weekly markers for 1Y timeframe (between month markers)
        // Performance: Single path, skip 1st of month, draw every 2 weeks to avoid clutter
        if effectiveTimeframe == .oneYear {
            let calendar = Calendar.current
            var weekSubPath = Path()
            
            // Find first Monday in range
            var currentDate = calendar.startOfDay(for: xDomain.lowerBound)
            while calendar.component(.weekday, from: currentDate) != 2 { // 2 = Monday
                guard let next = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = next
            }
            
            // Iterate through every 2nd Monday (bi-weekly) to reduce clutter
            while currentDate <= xDomain.upperBound {
                // Skip if within 3 days of 1st of month (too close to month marker)
                let dayOfMonth = calendar.component(.day, from: currentDate)
                if dayOfMonth > 3 && dayOfMonth < 28 && currentDate >= xDomain.lowerBound {
                    let x = xPosition(for: currentDate, in: size)
                    weekSubPath.move(to: CGPoint(x: x, y: 0))
                    weekSubPath.addLine(to: CGPoint(x: x, y: size.height))
                }
                
                // Move 2 weeks forward
                guard let nextBiWeek = calendar.date(byAdding: .weekOfYear, value: 2, to: currentDate) else { break }
                currentDate = nextBiWeek
            }
            
            context.stroke(weekSubPath, with: .color(Color.gray.opacity(0.12)), lineWidth: 0.5)
        }
    }

    private func drawLine(in context: GraphicsContext, size: CGSize) {
        guard points.count >= 2 else { return }

        let dates = points.map { $0.date }
        let values = points.map { $0.weight }
        
        // Apply densified monotone spline (Stage 4)
        let (splineDates, splineValues) = monotoneSpline(
            dates: dates,
            values: values,
            samplesPerSegment: 8
        )
        
        // Convert densified points to CGPoints
        var path = Path()
        
        if splineDates.count > 0 {
            let firstPoint = CGPoint(
                x: xPosition(for: splineDates[0], in: size),
                y: yPosition(for: splineValues[0], in: size)
            )
            path.move(to: firstPoint)
            
            for i in 1..<splineDates.count {
                let point = CGPoint(
                    x: xPosition(for: splineDates[i], in: size),
                    y: yPosition(for: splineValues[i], in: size)
                )
                path.addLine(to: point)
            }
        }

        context.stroke(
            path,
            with: .color(.blue),
            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        )
    }
    
    /// STAGE 4: Densified Fritsch-Carlson monotone cubic spline
    /// Creates smooth interpolation with 8 samples per segment (matches Python spec)
    private func monotoneSpline(
        dates: [Date],
        values: [Double],
        samplesPerSegment: Int = 8
    ) -> (dates: [Date], values: [Double]) {
        let n = dates.count
        guard n >= 2 else { return (dates, values) }
        
        // Convert dates to days from start
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
        
        // Add final point
        outX.append(xs.last!)
        outY.append(ys.last!)
        
        // Convert back to dates
        let outDates = outX.map { Date(timeInterval: $0 * 86400.0, since: firstDate) }
        
        return (dates: outDates, values: outY)
    }

    // MARK: - Coordinate transforms

    private func xPosition(for date: Date, in size: CGSize) -> CGFloat {
        let total = xDomain.upperBound.timeIntervalSince(xDomain.lowerBound)
        guard total > 0 else { return 0 }
        let t = date.timeIntervalSince(xDomain.lowerBound) / total
        return CGFloat(t) * size.width
    }

    private func yPosition(for value: Double, in size: CGSize) -> CGFloat {
        let range = yDomain.upperBound - yDomain.lowerBound
        guard range > 0 else { return size.height / 2 }
        let normalized = (value - yDomain.lowerBound) / range
        return size.height - CGFloat(normalized) * size.height
    }

    private func index(for x: CGFloat, width: CGFloat) -> Int {
        guard !points.isEmpty else { return 0 }
        let clamped = max(0, min(width, x))
        let ratio = clamped / width
        let idx = Int(round(ratio * CGFloat(points.count - 1)))
        return max(0, min(points.count - 1, idx))
    }

    // MARK: - Crosshair

    @ViewBuilder
    private func crosshair(for point: WeightLogEntry, in size: CGSize) -> some View {
        let x = xPosition(for: point.date, in: size)
        let y = yPosition(for: point.weight, in: size)

        ZStack {
            Rectangle()
                .fill(Color.blue.opacity(0.4))
                .frame(width: 1, height: size.height)
                .position(x: x, y: size.height / 2)

            Rectangle()
                .fill(Color.blue.opacity(0.4))
                .frame(width: size.width, height: 1)
                .position(x: size.width / 2, y: y)

            Circle()
                .fill(Color.blue)
                .frame(width: 10, height: 10)
                .position(x: x, y: y)

            VStack(spacing: 2) {
                Text(point.date, format: .dateTime.day().month().year())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                Text(String(format: "%.1f kg", point.weight))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
            )
            .position(x: x, y: max(28, y - 36))
        }
    }
}

// MARK: - Helpers

/// Simple weekly averaging to keep long ranges lightweight
private enum WeeklyAverageHelper {
    static func weeklyAverages(from entries: [WeightLogEntry]) -> [WeightLogEntry] {
        guard !entries.isEmpty else { return [] }

        let sorted = entries.sorted { $0.date < $1.date }
        let calendar = Calendar.current

        var result: [WeightLogEntry] = []
        var bucket: [WeightLogEntry] = []
        var currentWeek: Date?

        for e in sorted {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: e.date)?.start

            if currentWeek == nil {
                currentWeek = weekStart
                bucket = [e]
            } else if weekStart == currentWeek {
                bucket.append(e)
            } else {
                if let avg = makeAverage(from: bucket) {
                    result.append(avg)
                }
                currentWeek = weekStart
                bucket = [e]
            }
        }

        if let avg = makeAverage(from: bucket) {
            result.append(avg)
        }
        return result
    }

    private static func makeAverage(from entries: [WeightLogEntry]) -> WeightLogEntry? {
        guard !entries.isEmpty else { return nil }
        let avg = entries.map { $0.weight }.reduce(0, +) / Double(entries.count)
        let middleDate = entries[entries.count / 2].date
        return WeightLogEntry(
            id: UUID(),
            date: middleDate,
            weight: avg,
            movingAverage: avg,
            weeklyRate: nil,
            notes: "Weekly Average"
        )
    }
}

/// Savitzky-Golay smoother (Happy Scale, Fitbit, Garmin style)
/// Preserves peaks and valleys better than simple moving average
private enum SavitzkyGolaySmoother {
    
    /// Apply Savitzky-Golay smoothing with optional median pre-filtering and double-pass
    static func smooth(
        _ entries: [WeightLogEntry],
        windowSize: Int,
        polynomialOrder: Int = 2,
        useMedianPrefilter: Bool = true,
        useDoublePass: Bool = true
    ) -> [WeightLogEntry] {
        guard entries.count > windowSize else { return entries }
        
        let sorted = entries.sorted { $0.date < $1.date }
        
        // Step 1: Median pre-filtering to remove spikes (optional)
        let prefiltered = useMedianPrefilter ? medianFilter(sorted, windowSize: 3) : sorted
        
        // Step 2: Forward pass Savitzky-Golay
        let forwardSmoothed = applySavitzkyGolay(prefiltered, windowSize: windowSize, polynomialOrder: polynomialOrder)
        
        // Step 3: Backward pass for even smoother results (optional)
        if useDoublePass {
            let reversed = forwardSmoothed.reversed()
            let backwardSmoothed = applySavitzkyGolay(Array(reversed), windowSize: windowSize, polynomialOrder: polynomialOrder)
            return backwardSmoothed.reversed()
        }
        
        return forwardSmoothed
    }
    
    /// Median filter to remove outliers/spikes
    private static func medianFilter(_ entries: [WeightLogEntry], windowSize: Int) -> [WeightLogEntry] {
        guard windowSize > 1 else { return entries }
        
        var result: [WeightLogEntry] = []
        let radius = windowSize / 2
        
        for i in entries.indices {
            let start = max(0, i - radius)
            let end = min(entries.count - 1, i + radius)
            let window = entries[start...end].map { $0.weight }.sorted()
            let median = window[window.count / 2]
            
            let base = entries[i]
            result.append(
                WeightLogEntry(
                    id: base.id,
                    date: base.date,
                    weight: median,
                    movingAverage: median,
                    weeklyRate: base.weeklyRate,
                    notes: base.notes
                )
            )
        }
        
        return result
    }
    
    /// Apply Savitzky-Golay filter
    private static func applySavitzkyGolay(
        _ entries: [WeightLogEntry],
        windowSize: Int,
        polynomialOrder: Int
    ) -> [WeightLogEntry] {
        guard windowSize > polynomialOrder else { return entries }
        
        // Ensure window size is odd
        let actualWindowSize = windowSize % 2 == 0 ? windowSize + 1 : windowSize
        let coefficients = getSavitzkyGolayCoefficients(windowSize: actualWindowSize, polynomialOrder: polynomialOrder)
        
        var result: [WeightLogEntry] = []
        let radius = actualWindowSize / 2
        
        for i in entries.indices {
            // Handle edge cases by using available data
            let actualStart = i - radius
            let actualEnd = i + radius
            
            var smoothedWeight = 0.0
            var coeffIndex = 0
            
            for j in actualStart...actualEnd {
                let dataIndex: Int
                if j < 0 {
                    dataIndex = 0 // Extend first value
                } else if j >= entries.count {
                    dataIndex = entries.count - 1 // Extend last value
                } else {
                    dataIndex = j
                }
                
                smoothedWeight += entries[dataIndex].weight * coefficients[coeffIndex]
                coeffIndex += 1
            }
            
            let base = entries[i]
            result.append(
                WeightLogEntry(
                    id: base.id,
                    date: base.date,
                    weight: smoothedWeight,
                    movingAverage: smoothedWeight,
                    weeklyRate: base.weeklyRate,
                    notes: base.notes
                )
            )
        }
        
        return result
    }
    
    /// Get Savitzky-Golay coefficients for given window size and polynomial order
    /// Pre-computed coefficients for common configurations
    private static func getSavitzkyGolayCoefficients(windowSize: Int, polynomialOrder: Int) -> [Double] {
        // Pre-computed coefficients for common cases (polynomial order 2)
        // These are normalized convolution coefficients
        
        switch (windowSize, polynomialOrder) {
        case (5, 2):
            return [-3, 12, 17, 12, -3].map { Double($0) / 35.0 }
        case (7, 2):
            return [-2, 3, 6, 7, 6, 3, -2].map { Double($0) / 21.0 }
        case (9, 2):
            return [-21, 14, 39, 54, 59, 54, 39, 14, -21].map { Double($0) / 231.0 }
        case (11, 2):
            return [-36, 9, 44, 69, 84, 89, 84, 69, 44, 9, -36].map { Double($0) / 429.0 }
        case (13, 2):
            return [-11, 0, 9, 16, 21, 24, 25, 24, 21, 16, 9, 0, -11].map { Double($0) / 143.0 }
        case (15, 2):
            return [-78, -13, 42, 87, 122, 147, 162, 167, 162, 147, 122, 87, 42, -13, -78].map { Double($0) / 1105.0 }
        case (21, 2):
            return [-171, -76, 9, 84, 149, 204, 249, 284, 309, 324, 329, 324, 309, 284, 249, 204, 149, 84, 9, -76, -171].map { Double($0) / 3059.0 }
        case (5, 3):
            return [5, -30, 75, 131, 75, -30, 5].map { Double($0) / 231.0 }
        case (7, 3):
            return [15, -55, 30, 135, 179, 135, 30, -55, 15].map { Double($0) / 429.0 }
        default:
            // Fallback to simple moving average if coefficients not pre-computed
            return Array(repeating: 1.0 / Double(windowSize), count: windowSize)
        }
    }
}

// MARK: - Stat Card (unchanged)

struct StatCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let color: Color
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    WeightChartCardView()
        .padding()
}
