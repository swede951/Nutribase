//
//  WeightChartCardView.swift
//  nutribase
//
//  Created by Cascade on 2025-07-24.
//

import SwiftUI
import Charts

struct WeightChartCardView: View {
    // MARK: - Dependencies
    @ObservedObject private var weightLogManager = WeightLogManager.shared
    @ObservedObject private var chartCache = WeightChartCache.shared
    
    // MARK: - State
    @State private var showingDetailView = false
    @State private var isLoadingData = false
    
    // MARK: - Computed Properties
    /// Recent weight entries for card preview (last year with weekly averaging)
    private var recentWeights: [WeightLogEntry] {
        let allEntries = weightLogManager.allEntries.sorted { $0.date < $1.date }
        
        guard let mostRecentDate = allEntries.last?.date else { return [] }
        
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: mostRecentDate) ?? mostRecentDate
        let filteredEntries = allEntries.filter { $0.date >= oneYearAgo }
        
        return calculateWeeklyAveragesForPreview(from: filteredEntries)
    }
    
    // MARK: - Helper Methods
    /// Calculate weekly averages for preview chart
    private func calculateWeeklyAveragesForPreview(from entries: [WeightLogEntry]) -> [WeightLogEntry] {
        guard !entries.isEmpty else { return entries }
        
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let calendar = Calendar.current
        var weeklyAverages: [WeightLogEntry] = []
        var currentWeekEntries: [WeightLogEntry] = []
        var currentWeekStart: Date?
        
        for entry in sortedEntries {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: entry.date)?.start
            
            if currentWeekStart == nil {
                currentWeekStart = weekStart
                currentWeekEntries = [entry]
            } else if weekStart == currentWeekStart {
                currentWeekEntries.append(entry)
            } else {
                // Process the completed week
                if let avgEntry = createWeeklyAverageForPreview(from: currentWeekEntries) {
                    weeklyAverages.append(avgEntry)
                }
                
                // Start new week
                currentWeekStart = weekStart
                currentWeekEntries = [entry]
            }
        }
        
        // Process the last week
        if let avgEntry = createWeeklyAverageForPreview(from: currentWeekEntries) {
            weeklyAverages.append(avgEntry)
        }
        
        return weeklyAverages
    }
    
    // Create a single weekly average entry for preview
    private func createWeeklyAverageForPreview(from entries: [WeightLogEntry]) -> WeightLogEntry? {
        guard !entries.isEmpty else { return nil }
        
        let averageWeight = entries.map { $0.weight }.reduce(0, +) / Double(entries.count)
        let middleDate = entries.sorted { $0.date < $1.date }[entries.count / 2].date
        
        return WeightLogEntry(
            id: UUID(),
            date: middleDate,
            weight: averageWeight,
            movingAverage: averageWeight,
            weeklyRate: nil,
            notes: "Weekly Average"
        )
    }
    
    // Calculate dynamic Y-axis range for better visibility
    private var yAxisRange: ClosedRange<Double> {
        guard !recentWeights.isEmpty else { return 0...100 }
        
        let weights = recentWeights.map { $0.weight }
        let minWeight = weights.min() ?? 0
        let maxWeight = weights.max() ?? 100
        
        // Add 5% padding above and below the actual range
        let range = maxWeight - minWeight
        let padding = max(range * 0.05, 2.0) // At least 2kg padding
        
        return (minWeight - padding)...(maxWeight + padding)
    }
    
    var body: some View {
        Button(action: {
            showingDetailView = true
        }) {
            VStack(alignment: .leading, spacing: 8) {
            // Header with standardized top spacing
            HStack {
                Text("Weight Chart")
                    .font(.custom("Montserrat-SemiBold", size: 17))
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.bottom, 4)
            
            // Chart content
            if recentWeights.count >= 2 {
                Chart(recentWeights) { entry in
                    // Main line chart with smooth curve
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", entry.weight)
                    )
                    .foregroundStyle(Color(red: 144/255, green: 191/255, blue: 255/255))
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                    
                    // Add thin X-axis line (horizontal) at the bottom
                    RuleMark(
                        y: .value("Bottom", yAxisRange.lowerBound)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .foregroundStyle(.gray)
                    
                    // Add thin Y-axis line (vertical)
                    RuleMark(
                        x: .value("Start", recentWeights.first?.date ?? Date())
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .foregroundStyle(.gray)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: yAxisRange)
                .frame(height: 70)
            } else if recentWeights.count == 1 {
                // Show a simple preview with just one entry
                let entry = recentWeights[0]
                let previewData = [
                    (date: Calendar.current.date(byAdding: .day, value: -7, to: entry.date) ?? entry.date, weight: entry.weight * 0.98),
                    (date: entry.date, weight: entry.weight)
                ]
                
                Chart(previewData, id: \.date) { dataPoint in
                    // Main line chart with smooth curve
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Weight", dataPoint.weight)
                    )
                    .foregroundStyle(Color(red: 144/255, green: 191/255, blue: 255/255))
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                    
                    // Add thin X-axis line (horizontal) at the bottom
                    RuleMark(
                        y: .value("Bottom", yAxisRange.lowerBound)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .foregroundStyle(.gray)
                    
                    // Add thin Y-axis line (vertical)
                    RuleMark(
                        x: .value("Start", previewData.first?.date ?? Date())
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .foregroundStyle(.gray)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: yAxisRange)
                .frame(height: 60)
            } else {
                // Placeholder when no data
                VStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("Not enough data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(height: 120)
        }
        .sheet(isPresented: $showingDetailView) {
            WeightChartDetailView()
        }
    }
}

enum TimeFrame: String, CaseIterable {
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case allTime = "All"
    
    var days: Int? {
        switch self {
        case .oneWeek: return 7
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .oneYear: return 365
        case .allTime: return nil
        }
    }
    
    
}

struct WeightChartDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var weightLogManager = WeightLogManager.shared
    @ObservedObject private var chartCache = WeightChartCache.shared
    @State private var isLoadingData = false
    @State private var selectedTimeFrame: TimeFrame = .allTime
    @State private var showChart = false
    @State private var isLoading = false
    @State private var scrollPosition: Date?
    
    /// Cached chart data for selected timeframe
    private var chartData: [WeightLogEntry] {
        chartCache.getCachedData()
    }
    
    // Get all available data for scrolling (not filtered by timeframe)
    private var allChartData: [WeightLogEntry] {
        return calculateWeeklyAverages(from: chartData)
    }
    
    // Get filtered weight entries based on selected time frame
    private var filteredData: [WeightLogEntry] {
        print("WeightChart: filteredData called with \(chartData.count) cached entries")
        let filteredData: [WeightLogEntry]
        
        if let days = selectedTimeFrame.days {
            // Find the most recent weight entry date
            guard let mostRecentDate = chartData.map({ $0.date }).max() else {
                print("WeightChart: No recent date found, returning all cached data")
                return chartData
            }
            
            // Calculate cutoff date from the most recent entry, not from today
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: mostRecentDate) ?? mostRecentDate
            filteredData = chartData.filter { $0.date >= cutoffDate }
            print("WeightChart: Filtered to \(filteredData.count) entries for \(selectedTimeFrame.rawValue)")
        } else {
            filteredData = chartData // All time
            print("WeightChart: Using all time data: \(filteredData.count) entries")
        }
        
        // Apply weekly averaging for better chart performance and readability
        return calculateWeeklyAverages(from: filteredData)
    }
    
    // Data to display in chart - use all data for scrollable timeframes, filtered for non-scrollable
    /// Chart data prepared for display
    private var displayChartData: [WeightLogEntry] {
        let data = chartData
        return data.isEmpty ? [] : data
    }
    
    // Calculate weekly averages to smooth the data
    private func calculateWeeklyAverages(from entries: [WeightLogEntry]) -> [WeightLogEntry] {
        guard !entries.isEmpty else { return entries }
        
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let calendar = Calendar.current
        var weeklyAverages: [WeightLogEntry] = []
        
        // Group entries by week
        var currentWeekEntries: [WeightLogEntry] = []
        var currentWeekStart: Date?
        
        for entry in sortedEntries {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: entry.date)?.start
            
            if currentWeekStart == nil {
                currentWeekStart = weekStart
                currentWeekEntries = [entry]
            } else if weekStart == currentWeekStart {
                currentWeekEntries.append(entry)
            } else {
                // Process the completed week
                if let avgEntry = createWeeklyAverage(from: currentWeekEntries) {
                    weeklyAverages.append(avgEntry)
                }
                
                // Start new week
                currentWeekStart = weekStart
                currentWeekEntries = [entry]
            }
        }
        
        // Process the last week
        if let avgEntry = createWeeklyAverage(from: currentWeekEntries) {
            weeklyAverages.append(avgEntry)
        }
        
        return weeklyAverages
    }
    
    // Create a single weekly average entry
    private func createWeeklyAverage(from entries: [WeightLogEntry]) -> WeightLogEntry? {
        guard !entries.isEmpty else { return nil }
        
        let averageWeight = entries.map { $0.weight }.reduce(0, +) / Double(entries.count)
        let middleDate = entries.sorted { $0.date < $1.date }[entries.count / 2].date
        
        return WeightLogEntry(
            id: UUID(),
            date: middleDate,
            weight: averageWeight,
            movingAverage: averageWeight,
            weeklyRate: nil,
            notes: "Weekly Average"
        )
    }
    
    // Sample data points for large datasets to improve chart performance
    private func sampleDataPoints(from entries: [WeightLogEntry], maxPoints: Int) -> [WeightLogEntry] {
        guard entries.count > maxPoints else { return entries }
        
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let step = Double(sortedEntries.count) / Double(maxPoints)
        var sampledEntries: [WeightLogEntry] = []
        
        for i in 0..<maxPoints {
            let index = Int(Double(i) * step)
            if index < sortedEntries.count {
                sampledEntries.append(sortedEntries[index])
            }
        }
        
        return sampledEntries
    }
    
    // Memoized calculations for better performance
    @State private var cachedWeightRange: (min: Double, max: Double) = (0, 100)
    @State private var cachedDateRange: (spansMultipleYears: Bool, yearStarts: [Date]) = (false, [])
    
    private var weightRange: (min: Double, max: Double) {
        return cachedWeightRange
    }
    
    private var dateRange: (spansMultipleYears: Bool, yearStarts: [Date]) {
        return cachedDateRange
    }
    
    // Calculate visible domain length based on timeframe (in days)
    private var timeframeDays: Int {
        switch selectedTimeFrame {
        case .oneWeek:
            return 7
        case .oneMonth:
            return 30
        case .threeMonths:
            return 90
        case .sixMonths:
            return 180
        case .oneYear:
            return 365
        case .allTime:
            // For all time, show everything without scrolling constraint
            guard !allChartData.isEmpty,
                  let firstDate = allChartData.map({ $0.date }).min(),
                  let lastDate = allChartData.map({ $0.date }).max() else {
                return 365
            }
            return Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 365
        }
    }
    
    // Calculate ranges when data loads or time frame changes
    private func calculateRanges() {
        let filteredData = chartData // Use the filtered data based on time frame
        
        guard !filteredData.isEmpty else {
            cachedWeightRange = (0, 100)
            cachedDateRange = (false, [])
            return
        }
        
        // Calculate weight range
        let weights = filteredData.map { $0.weight }
        let minWeight = weights.min() ?? 0
        let maxWeight = weights.max() ?? 100
        let padding = max((maxWeight - minWeight) * 0.05, 2.0)
        let adjustedMin = floor(minWeight - padding)
        let adjustedMax = maxWeight + padding
        cachedWeightRange = (adjustedMin, adjustedMax)
        
        // Calculate date range and month boundaries for 1Y timeline
        let dates = filteredData.map { $0.date }
        let minDate = dates.min() ?? Date()
        let maxDate = dates.max() ?? Date()
        let calendar = Calendar.current
        let minYear = calendar.component(.year, from: minDate)
        let maxYear = calendar.component(.year, from: maxDate)
        let spansMultipleYears = maxYear > minYear
        
        var monthStarts: [Date] = []
        
        // For 1Y timeline, generate monthly boundaries
        if selectedTimeFrame == .oneYear {
            let startOfMinMonth = calendar.dateInterval(of: .month, for: minDate)?.start ?? minDate
            let endOfMaxMonth = calendar.dateInterval(of: .month, for: maxDate)?.end ?? maxDate
            
            var currentMonth = calendar.date(byAdding: .month, value: 1, to: startOfMinMonth) ?? startOfMinMonth
            while currentMonth <= endOfMaxMonth {
                monthStarts.append(currentMonth)
                currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
            }
        } else if spansMultipleYears {
            // For other timelines, use year boundaries as before
            for year in (minYear + 1)...maxYear {
                if let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) {
                    monthStarts.append(yearStart)
                }
            }
        }
        
        cachedDateRange = (spansMultipleYears || selectedTimeFrame == .oneYear, monthStarts)
    }
    
    var body: some View {
        NavigationView {
            bodyContent
        }
    }
    
    private var bodyContent: some View {
        // Use ZStack to ensure background covers entire view
        ZStack {
            // Background layer
            Color.white.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !chartData.isEmpty {
                        chartSectionView
                        statisticsSection
                    } else {
                        noDataView
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Weight Chart Details")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.blue)
            }
        }
        .onAppear {
            loadDataAsync()
        }
    }
    
    private var chartSectionView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Chart Section - Title outside card
            Text("Weight Trend (\(selectedTimeFrame.rawValue))")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            // Chart and buttons inside card
            VStack(spacing: 0) {
                Group {
                    if selectedTimeFrame != .allTime {
                        ZStack(alignment: .leading) {
                            ScrollViewReader { proxy in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 0) {
                                        Chart(displayChartData, id: \.id) { entry in
                                            LineMark(
                                                x: .value("Date", entry.date),
                                                y: .value("Weight", entry.weight)
                                            )
                                            .foregroundStyle(Color.blue)
                                            .lineStyle(StrokeStyle(lineWidth: 2))
                                        }
                                        .frame(width: chartWidth, height: 300)
                                        .chartYScale(domain: dynamicYRange ?? 70...90, type: .linear)
                                        .id("chart-\(dynamicYRange?.lowerBound ?? 0)-\(dynamicYRange?.upperBound ?? 0)")
                                        .chartYAxis {
                                            // Hide Y-axis labels from chart since we'll show them separately
                                            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                            }
                                        }
                                        .chartXAxis(content: chartXAxisView)
                                        .chartXScale(domain: fullDateDomain)
                                        .clipped() // Ensure chart content doesn't overflow
                                        .id("scrollable-chart")
                                    }
                                }
                                .onAppear {
                                    // Scroll to the end (most recent date) when chart appears - no animation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        proxy.scrollTo("scrollable-chart", anchor: .trailing)
                                    }
                                }
                                .onChange(of: selectedTimeFrame) { _, _ in
                                    // Scroll to end when timeframe changes - no animation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        proxy.scrollTo("scrollable-chart", anchor: .trailing)
                                    }
                                }
                            }
                            .frame(height: 300)
                            
                            // Sticky Y-axis labels overlay
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(stickyYAxisLabels, id: \.self) { weight in
                                    Text("\(Int(weight)) kg")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 8)
                                        .frame(height: yAxisLabelHeight)
                                        .background(
                                            Rectangle()
                                                .fill(Color(.systemBackground).opacity(0.9))
                                                .frame(width: 50)
                                        )
                                }
                            }
                            .frame(height: 300, alignment: .leading)
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        if selectedTimeFrame == .oneYear {
                                            let newOffset = abs(value.translation.width)
                                            // Smooth continuous updates without threshold
                                            withAnimation(.linear(duration: 0.1)) {
                                                scrollOffset = newOffset
                                            }
                                            
                                            // Throttled Y-axis updates for performance
                                            throttledUpdateYDomain()
                                        }
                                    }
                            )
                            .onAppear {
                                print("🚀 Chart appeared - initializing Y-axis range")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    updateVisibleYDomain()
                                }
                            }
                            .onChange(of: selectedTimeFrame) { _, newTimeFrame in
                                if newTimeFrame == .oneYear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        updateVisibleYDomain()
                                    }
                                }
                            }
                        }
                    } else {
                        chartView
                            .frame(height: 300)
                            .chartYScale(domain: weightRange.min...weightRange.max)
                            .chartXAxis(content: chartXAxisView)
                            .chartYAxis(content: chartYAxisView)
                    }
                }
                
                timeFrameButtons
            }
            .padding()
            .cardStyle()
        }
    }
    
    // Y-axis labels for sticky display
    private var yAxisLabels: [Double] {
        let min = weightRange.min
        let max = weightRange.max
        let rangeSize = max - min
        
        var labels: [Double] = []
        let interval: Double
        
        if rangeSize > 6 {
            interval = 2.0 // Every 2kg for large ranges
        } else if rangeSize > 2 {
            interval = 1.0 // Every 1kg for medium ranges
        } else {
            interval = 0.5 // Every 0.5kg for small ranges
        }
        
        var currentWeight = min
        while currentWeight <= max {
            if currentWeight >= min {
                labels.append(currentWeight)
            }
            currentWeight += interval
        }
        
        return labels // Bottom to top (normal order)
    }
    
    // Dynamic Y-axis labels that update with the dynamic range
    private var dynamicYAxisLabels: [Double] {
        guard let range = dynamicYRange else { return [] }
        let min = range.lowerBound
        let max = range.upperBound
        let rangeSize = max - min
        
        var labels: [Double] = []
        let interval: Double
        
        if rangeSize > 6 {
            interval = 2.0 // Every 2kg for large ranges
        } else if rangeSize > 2 {
            interval = 1.0 // Every 1kg for medium ranges
        } else {
            interval = 0.5 // Every 0.5kg for small ranges
        }
        
        var currentWeight = min
        while currentWeight <= max {
            if currentWeight >= min {
                labels.append(currentWeight)
            }
            currentWeight += interval
        }
        
        return labels // Bottom to top (normal order)
    }
    
    // Preference key for tracking scroll offset
    struct ScrollOffsetPreferenceKey: PreferenceKey {
        static var defaultValue: CGPoint = .zero
        static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
            value = nextValue()
        }
    }
    
    // MARK: - Dynamic Y-Axis State
    @State private var scrollOffset: CGFloat = 0
    @State private var dynamicYRange: ClosedRange<Double>? = nil
    @State private var currentWindowData: [WeightLogEntry] = []
    @State private var updateTimer: Timer?
    
    // MARK: - Sticky Y-Axis Labels
    private var stickyYAxisLabels: [Double] {
        guard let range = dynamicYRange else { return [] }
        let step = (range.upperBound - range.lowerBound) / 4
        return stride(from: range.upperBound, through: range.lowerBound, by: -step).map { $0 }
    }
    
    private var yAxisLabelHeight: CGFloat {
        300 / 5 // 5 labels distributed across 300pt height
    }
    
    // MARK: - Dynamic Y-Axis Methods
    /// Updates Y-axis range based on visible viewport using Happy Scale approach
    private func updateVisibleYDomain() {
        guard selectedTimeFrame == .oneYear && !displayChartData.isEmpty else { return }
        
        let screenWidth = UIScreen.main.bounds.width - 32
        let sortedData = displayChartData.sorted { $0.date < $1.date }
        
        guard let firstDate = sortedData.first?.date,
              let lastDate = sortedData.last?.date else { 
            return 
        }
        
        // Calculate what dates are currently visible on screen (not 365-day window)
        let totalWidth = chartWidth
        let pixelsPerDay = totalWidth / CGFloat(Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 365)
        
        // Calculate visible date range based on screen viewport
        let visibleDays = Int(screenWidth / pixelsPerDay)
        let scrolledDays = Int(scrollOffset / pixelsPerDay)
        
        let viewportStart = Calendar.current.date(byAdding: .day, value: scrolledDays, to: firstDate) ?? firstDate
        let viewportEnd = Calendar.current.date(byAdding: .day, value: visibleDays, to: viewportStart) ?? lastDate
        
        print("📱 Screen viewport dates: \(DateFormatter.shortDate.string(from: viewportStart)) to \(DateFormatter.shortDate.string(from: viewportEnd))")
        
        let allHistoricalData = weightLogManager.allEntries
        
        guard !allHistoricalData.isEmpty else { 
            // Fallback to display data if no historical data
            let allWeights = displayChartData.map { $0.weight }
            if let minWeight = allWeights.min(), let maxWeight = allWeights.max() {
                let padding = max((maxWeight - minWeight) * 0.3, 3.0)
                dynamicYRange = (minWeight - padding)...(maxWeight + padding)
            }
            return 
        }
        
        // Update statistics for visible window
        currentWindowData = sortedData.filter { entry in
            entry.date >= viewportStart && entry.date <= viewportEnd
        }
        
        // Calculate Y-axis range from all historical data
        let allHistoricalWeights = allHistoricalData.map { $0.weight }
        guard let minWeight = allHistoricalWeights.min(),
              let maxWeight = allHistoricalWeights.max() else { return }
        
        // Apply padding with iterative boundary checking
        let _ = maxWeight - minWeight
        let targetPadding = max((maxWeight - minWeight) * 0.3, 3.0)
        var calculatedMin = minWeight - targetPadding
        var calculatedMax = maxWeight + targetPadding
        
        // Iterative expansion to prevent data cutoff
        for _ in 0..<5 {
            let testRange = calculatedMin...calculatedMax
            let boundaryHit = allHistoricalWeights.contains { weight in
                weight <= testRange.lowerBound + 1.0 || weight >= testRange.upperBound - 1.0
            }
            
            if !boundaryHit { break }
            
            let expansion = (calculatedMax - calculatedMin) * 0.2
            calculatedMin -= expansion
            calculatedMax += expansion
        }
        
        dynamicYRange = calculatedMin...calculatedMax
    }
    
    /// Throttled Y-axis update to prevent excessive recalculation during scrolling
    private func throttledUpdateYDomain() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
            updateVisibleYDomain()
        }
    }
    
    // MARK: - Chart Layout
    /// Calculate chart width for horizontal scrolling
    private var chartWidth: CGFloat {
        guard selectedTimeFrame != .allTime && !displayChartData.isEmpty else { 
            return UIScreen.main.bounds.width 
        }
        
        let totalDays = Calendar.current.dateComponents([.day], 
            from: displayChartData.first!.date, 
            to: displayChartData.last!.date).day ?? timeframeDays
        let screenWidth = UIScreen.main.bounds.width - 32
        let pointsPerDay = screenWidth / CGFloat(timeframeDays)
        return CGFloat(totalDays) * pointsPerDay
    }
    
    // Full date domain for scrolling
    private var fullDateDomain: ClosedRange<Date> {
        guard !displayChartData.isEmpty else { return Date()...Date() }
        let start = displayChartData.first!.date
        let end = displayChartData.last!.date
        return start...end
    }
    
    private var chartView: some View {
        Chart {
            ForEach(displayChartData, id: \.id) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(Color(red: 144/255, green: 191/255, blue: 255/255))
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.cardinal)
            }
            
            // Add vertical lines for month/year boundaries
            if dateRange.spansMultipleYears || selectedTimeFrame == .oneYear {
                ForEach(dateRange.yearStarts, id: \.self) { monthStart in
                    RuleMark(
                        x: .value("Month", monthStart)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.gray.opacity(0.3))
                }
            }
        }
    }
    
    
    @AxisContentBuilder
    private func chartXAxisView() -> some AxisContent {
        if selectedTimeFrame == .oneYear {
            // Show month labels for 1Y timeline
            AxisMarks(values: .stride(by: .month)) { value in
                AxisTick()
                AxisValueLabel(centered: true) {
                    if let date = value.as(Date.self) {
                        let monthLetter = Calendar.current.monthSymbols[Calendar.current.component(.month, from: date) - 1].prefix(1).uppercased()
                        Text(String(monthLetter))
                    }
                }
            }
        } else if selectedTimeFrame == .threeMonths {
            // Force month labels for 90D timeline - use stride with smaller font
            AxisMarks(values: .stride(by: .month)) { value in
                AxisTick()
                AxisValueLabel(centered: true) {
                    if let date = value.as(Date.self) {
                        let monthAbbr = Calendar.current.monthSymbols[Calendar.current.component(.month, from: date) - 1].prefix(3).uppercased()
                        Text(String(monthAbbr))
                            .font(.system(size: 10, weight: .medium))
                    }
                }
            }
        } else if selectedTimeFrame == .oneMonth {
            // Show 3-letter month labels for 30D timeline
            AxisMarks(values: .stride(by: .month)) { value in
                AxisTick()
                AxisValueLabel(centered: true) {
                    if let date = value.as(Date.self) {
                        let monthAbbr = Calendar.current.monthSymbols[Calendar.current.component(.month, from: date) - 1].prefix(3).uppercased()
                        Text(String(monthAbbr))
                    }
                }
            }
        } else if dateRange.spansMultipleYears {
            // Show year labels when data spans multiple years
            AxisMarks(values: .stride(by: .year)) { value in
                AxisTick()
                AxisValueLabel(format: .dateTime.year(), centered: true)
            }
        } else {
            // Show day labels for 7D timeline
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
            }
        }
    }
    
    private func chartYAxisView() -> some AxisContent {
        // Calculate dynamic stride and label interval based on weight range
        let range = weightRange.max - weightRange.min
        let (stride, labelInterval): (Double, Double) = {
            if range > 6 {
                return (1.0, 2.0) // Grid every 1kg, labels every 2kg
            } else if range > 2 {
                return (0.5, 1.0) // Grid every 0.5kg, labels every 1kg
            } else {
                return (0.25, 0.5) // Grid every 0.25kg, labels every 0.5kg
            }
        }()
        
        return AxisMarks(position: .leading, values: .stride(by: stride)) { value in
            // Only show gridlines and labels within our visible weight range
            if let weight = value.as(Double.self), 
               weight >= weightRange.min && weight <= weightRange.max {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisTick()
                
                // Show labels based on calculated interval
                let weightRounded = (weight * 10).rounded() / 10 // Round to 1 decimal
                let intervalCheck = (weightRounded * 10) / (labelInterval * 10)
                if abs(intervalCheck - intervalCheck.rounded()) < 0.01 {
                    AxisValueLabel {
                        if labelInterval >= 1.0 {
                            Text(String(format: "%.0f kg", weight))
                        } else {
                            Text(String(format: "%.1f kg", weight))
                        }
                    }
                }
            }
        }
    }
    
    private var timeFrameButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeFrame.allCases, id: \.self) { timeFrame in
                    Button(action: {
                        selectedTimeFrame = timeFrame
                        calculateRanges() // Recalculate ranges for new time frame
                    }) {
                        Text(timeFrame.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedTimeFrame == timeFrame ? .white : .blue)
                            .lineLimit(1)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedTimeFrame == timeFrame ? Color.blue : Color.blue.opacity(0.1))
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
    }
    
    private var statisticsSection: some View {
        // Statistics Section - use window data for 1Y timeframe, regular data for others
        let statsData = (selectedTimeFrame == .oneYear && !currentWindowData.isEmpty) ? currentWindowData : chartData
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatCard(title: "Current", value: String(format: "%.1f kg", statsData.last?.weight ?? 0), color: .blue)
                StatCard(title: "Highest", value: String(format: "%.1f kg", statsData.map { $0.weight }.max() ?? 0), color: .red)
                StatCard(title: "Lowest", value: String(format: "%.1f kg", statsData.map { $0.weight }.min() ?? 0), color: .green)
                StatCard(title: "Change", value: calculateWindowChange(for: statsData), color: calculateWindowChangeColor(for: statsData))
            }
        }
        .cardStyle()
    }
    
    // Calculate weight change for current window
    private func calculateWindowChange(for data: [WeightLogEntry]) -> String {
        guard let first = data.first?.weight, let last = data.last?.weight else { return "—" }
        let change = last - first
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", change)) kg"
    }
    
    // Calculate weight change color for current window
    private func calculateWindowChangeColor(for data: [WeightLogEntry]) -> Color {
        guard let first = data.first?.weight, let last = data.last?.weight else { return .secondary }
        let change = last - first
        return change >= 0 ? .red : .green
    }
    
    private var noDataView: some View {
        // No data state
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
    
    // Async data loading function
    private func loadDataAsync() {
        Task {
            // Load data on background thread
            let allEntries = await Task.detached {
                return weightLogManager.allEntries.sorted { $0.date < $1.date }
            }.value
            
            // Update UI on main thread
            await MainActor.run {
                // Update chart cache with loaded data
                chartCache.updateCache(with: allEntries)
                print("WeightChart: Loaded \(allEntries.count) entries")
                print("WeightChart: First entry: \(allEntries.first?.date ?? Date()) - \(allEntries.first?.weight ?? 0)")
                print("WeightChart: Last entry: \(allEntries.last?.date ?? Date()) - \(allEntries.last?.weight ?? 0)")
                calculateRanges()
                isLoading = false
            }
        }
    }
    
    private var weightChangeText: String {
        guard chartData.count >= 2,
              let first = chartData.first?.weight,
              let last = chartData.last?.weight else {
            return "N/A"
        }
        
        let change = last - first
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", change)) kg"
    }
    
    /// Color for weight change indicator
    private var weightChangeColor: Color {
        guard chartData.count >= 2,
              let first = chartData.first?.weight,
              let last = chartData.last?.weight else {
            return .gray
        }
        
        let change = last - first
        return change >= 0 ? .red : .green
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    WeightChartCardView()
        .padding()
}
