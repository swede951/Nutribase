//
//  EditorPreviewCards.swift
//  nutribase
//
//  Editor preview cards that use REAL data captured when entering edit mode.
//  These cards render correctly with ImageRenderer (no Swift Charts, no SF Symbols that fail).
//

import SwiftUI

// MARK: - Editor Weight Card Preview

/// Snapshot-compatible version of CurrentWeightCardView
/// Uses "+" or "-" text instead of SF Symbol arrows
/// Uses real data from CapturedCardData
struct EditorCurrentWeightPreview: View {
    @ObservedObject private var capturedData = CapturedCardData.shared
    
    var body: some View {
        FixedSizeCard(title: "Weight") {
            VStack(alignment: .leading, spacing: 8) {
                if capturedData.hasWeightData {
                    Text("\(String(format: "%.1f", capturedData.currentWeight)) \(capturedData.weightUnit)")
                        .font(.system(size: 28, weight: .bold))
                    
                    if capturedData.weeklyWeightRate != 0 {
                        HStack(spacing: 4) {
                            // Use Unicode arrows (snapshot-compatible, SF Symbols fail in ImageRenderer)
                            Text(capturedData.weeklyWeightRate < 0 ? "↓" : "↑")
                                .foregroundColor(Color(hex: "#5ec5ff"))
                                .font(.caption)
                            
                            Text("\(String(format: "%.1f", abs(capturedData.weeklyWeightRate))) \(capturedData.weightUnit)")
                                .foregroundColor(Color(hex: "#5ec5ff"))
                                .font(.caption)
                            
                            Text("Weekly Rate")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.accessibleSecondary)
                        }
                    }
                } else {
                    Text("No data")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("Log your first weight")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accessibleSecondary)
                }
            }
        }
    }
}

// MARK: - Editor Weight Chart Preview

/// Snapshot-compatible version of WeightChartCardView
/// Uses Canvas for drawing instead of Swift Charts
/// Supports both compact (1×1) and expanded (2×3) modes
/// Uses real data from CapturedCardData
struct EditorWeightChartPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var capturedData = CapturedCardData.shared
    
    /// Whether to show expanded (2×3) mode or compact (1×1) mode
    var isExpanded: Bool = false
    
    // Use captured weight chart points, with fallback to placeholder
    private var chartWeights: [(date: Date, weight: Double)] {
        if capturedData.weightChartPoints.isEmpty {
            // Fallback placeholder when no data
            let calendar = Calendar.current
            let today = Date()
            return [
                (calendar.date(byAdding: .day, value: -7, to: today)!, 0),
                (today, 0)
            ]
        }
        return capturedData.weightChartPoints
    }
    
    private var yAxisRange: ClosedRange<Double> {
        let weights = chartWeights.map { $0.weight }
        let minW = weights.min() ?? 0
        let maxW = weights.max() ?? 100
        let range = maxW - minW
        let padding = max(range * 0.15, 0.5)  // Match CanvasChart padding
        return (minW - padding)...(maxW + padding)
    }
    
    /// Determine Y-axis interval based on range - matching CanvasChart
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
    
    /// Generate Y-axis label values - matching CanvasChart
    private func generateYAxisLabels() -> [Double] {
        let range = yAxisRange.upperBound - yAxisRange.lowerBound
        let interval = yAxisInterval(for: range)
        var labels: [Double] = []
        
        let minRounded = (yAxisRange.lowerBound / interval).rounded(.down) * interval
        var current = minRounded
        while current <= yAxisRange.upperBound {
            if current >= yAxisRange.lowerBound {
                labels.append(current)
            }
            current += interval
        }
        
        return labels
    }
    
    // Height for expanded mode: 482 (same as original WeightChartCardView)
    private var customHeight: CGFloat? {
        isExpanded ? 482 : nil
    }
    
    // Chart height based on mode
    private var chartHeight: CGFloat {
        isExpanded ? 380 : 80
    }
    
    var body: some View {
        FixedSizeCard(title: "Weight Chart", customHeight: customHeight) {
            VStack(alignment: .leading, spacing: isExpanded ? 4 : 8) {
                // Chart with Y-axis labels - matching CanvasChart layout
                GeometryReader { geo in
                    let size = geo.size
                    
                    ZStack(alignment: .leading) {
                        // Main chart (line + grid) - offset to make room for Y-axis labels
                        Canvas { context, canvasSize in
                            drawChart(in: context, size: canvasSize)
                        }
                        .frame(height: size.height)
                        .padding(.leading, 40) // Space for Y-axis labels
                        
                        // Y-axis labels
                        yAxisLabelsView(height: size.height)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .frame(height: chartHeight)
                
                if isExpanded {
                    // X-axis labels for expanded mode
                    expandedXAxisLabels
                        .frame(height: 16)
                    
                    // Timeframe buttons for expanded mode
                    expandedTimeFrameButtons
                        .frame(height: 36)
                }
            }
        }
    }
    
    // MARK: - Y-axis Labels
    
    private func yAxisLabelsView(height: CGFloat) -> some View {
        let labels = generateYAxisLabels()
        
        return ZStack(alignment: .trailing) {
            ForEach(labels, id: \.self) { value in
                let y = yPositionForLabel(for: value, in: height)
                
                Text(String(format: "%.1f", value))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
                    .position(x: 30, y: y)
            }
        }
    }
    
    private func yPositionForLabel(for weight: Double, in height: CGFloat) -> CGFloat {
        let range = yAxisRange.upperBound - yAxisRange.lowerBound
        guard range > 0 else { return height / 2 }
        let normalized = (weight - yAxisRange.lowerBound) / range
        return height - (CGFloat(normalized) * height)
    }
    
    // MARK: - Expanded Mode UI
    
    /// Generate axis labels based on actual data range - matching WeightChartCardView
    private func generateAxisLabels() -> [(Date, String)] {
        guard chartWeights.count >= 2,
              let firstDate = chartWeights.first?.date,
              let lastDate = chartWeights.last?.date else { return [] }
        
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
        
        let formatter = DateFormatter()
        formatter.locale = .current
        
        var result: [(Date, String)] = []
        
        if days > 365 {
            // Year labels for All time view
            formatter.dateFormat = "yyyy"
            let startYear = calendar.component(.year, from: firstDate)
            let endYear = calendar.component(.year, from: lastDate)
            
            for year in startYear...endYear {
                if let yearDate = calendar.date(from: DateComponents(year: year, month: 7, day: 1)) {
                    if yearDate >= firstDate && yearDate <= lastDate {
                        result.append((yearDate, "\(year)"))
                    }
                }
            }
        } else if days > 30 {
            // Month labels
            formatter.dateFormat = "MMM"
            let startComponents = calendar.dateComponents([.year, .month], from: firstDate)
            let endComponents = calendar.dateComponents([.year, .month], from: lastDate)
            
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
            // Week/short view - day labels
            formatter.dateFormat = "EEE"
            let count = min(5, chartWeights.count)
            let step = max(1, chartWeights.count / count)
            for i in stride(from: 0, to: chartWeights.count, by: step) {
                let date = chartWeights[i].date
                result.append((date, formatter.string(from: date)))
            }
        }
        
        return result
    }
    
    private var expandedXAxisLabels: some View {
        let labels = generateAxisLabels()
        guard let firstDate = chartWeights.first?.date,
              let lastDate = chartWeights.last?.date else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(labels, id: \.0) { (date, label) in
                        let total = lastDate.timeIntervalSince(firstDate)
                        let t = total > 0 ? date.timeIntervalSince(firstDate) / total : 0
                        // Account for 40pt Y-axis label space
                        let chartWidth = geo.size.width - 40
                        let xPos = CGFloat(t) * chartWidth
                        Text(label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.primary)
                            .position(x: xPos + 40, y: 8) // +40 for Y-axis label offset
                    }
                }
            }
        )
    }
    
    private var expandedTimeFrameButtons: some View {
        HStack(spacing: 8) {
            ForEach(["1W", "1M", "3M", "1Y", "All"], id: \.self) { label in
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(label == "All" ? .white : .blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(label == "All" ? Color.blue : Color.blue.opacity(0.1))
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func drawChart(in context: GraphicsContext, size: CGSize) {
        guard chartWeights.count >= 2 else { return }
        
        // Draw gridlines
        drawGrid(in: context, size: size)
        
        // Draw the weight line
        drawLine(in: context, size: size)
    }
    
    private func drawGrid(in context: GraphicsContext, size: CGSize) {
        guard !chartWeights.isEmpty,
              let firstDate = chartWeights.first?.date,
              let lastDate = chartWeights.last?.date else { return }
        
        let range = yAxisRange.upperBound - yAxisRange.lowerBound
        let interval = yAxisInterval(for: range)
        let labels = generateYAxisLabels()
        
        // Horizontal gridlines - aligned with Y-axis labels
        var gridPath = Path()
        for value in labels {
            let y = yPosition(for: value, in: size)
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(gridPath, with: .color(Color.gray.opacity(0.4)), lineWidth: 1.0)
        
        // Add intermediate gridlines when labels are every 2kg
        if interval == 2.0 {
            var intermediateGridPath = Path()
            let minRounded = (yAxisRange.lowerBound / 1.0).rounded(.down) * 1.0
            var current = minRounded
            
            while current <= yAxisRange.upperBound {
                let isLabelPosition = labels.contains(where: { abs($0 - current) < 0.01 })
                if !isLabelPosition && current >= yAxisRange.lowerBound {
                    let y = yPosition(for: current, in: size)
                    intermediateGridPath.move(to: CGPoint(x: 0, y: y))
                    intermediateGridPath.addLine(to: CGPoint(x: size.width, y: y))
                }
                current += 1.0
            }
            context.stroke(intermediateGridPath, with: .color(Color.gray.opacity(0.15)), lineWidth: 0.5)
        }
        
        // Vertical year markers for All time view
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
        
        if days > 365 {
            // Year markers
            let startYear = calendar.component(.year, from: firstDate)
            let endYear = calendar.component(.year, from: lastDate)
            
            if endYear > startYear {
                var yearPath = Path()
                
                for year in (startYear + 1)...endYear {
                    if let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) {
                        if yearStart >= firstDate && yearStart <= lastDate {
                            let x = xPosition(for: yearStart, in: size, firstDate: firstDate, lastDate: lastDate)
                            yearPath.move(to: CGPoint(x: x, y: 0))
                            yearPath.addLine(to: CGPoint(x: x, y: size.height))
                        }
                    }
                }
                context.stroke(yearPath, with: .color(Color.gray.opacity(0.4)), lineWidth: 1.0)
                
                // Monthly sub-markers (lighter)
                var monthSubPath = Path()
                let startComponents = calendar.dateComponents([.year, .month], from: firstDate)
                
                if let iterStart = calendar.date(from: startComponents) {
                    var currentDate = iterStart
                    
                    while currentDate <= lastDate {
                        let month = calendar.component(.month, from: currentDate)
                        if month != 1 && currentDate >= firstDate {
                            let x = xPosition(for: currentDate, in: size, firstDate: firstDate, lastDate: lastDate)
                            monthSubPath.move(to: CGPoint(x: x, y: 0))
                            monthSubPath.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        
                        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) else { break }
                        currentDate = nextMonth
                    }
                    context.stroke(monthSubPath, with: .color(Color.gray.opacity(0.15)), lineWidth: 0.5)
                }
            }
        } else if days > 30 {
            // Month markers for 1M-1Y views
            var monthPath = Path()
            let startComponents = calendar.dateComponents([.year, .month], from: firstDate)
            let endComponents = calendar.dateComponents([.year, .month], from: lastDate)
            
            if let startDate = calendar.date(from: startComponents),
               let endDate = calendar.date(from: endComponents) {
                var currentDate = startDate
                
                while currentDate <= endDate {
                    if currentDate >= firstDate && currentDate <= lastDate {
                        let x = xPosition(for: currentDate, in: size, firstDate: firstDate, lastDate: lastDate)
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
                
                // Weekly sub-gridlines (lighter) between month markers
                var weekPath = Path()
                var weekDate = calendar.date(byAdding: .weekOfYear, value: 1, to: firstDate) ?? firstDate
                while weekDate < lastDate {
                    // Skip if this week start coincides with a month start (within 1 day)
                    let dayOfMonth = calendar.component(.day, from: weekDate)
                    if dayOfMonth != 1 {
                        let x = xPosition(for: weekDate, in: size, firstDate: firstDate, lastDate: lastDate)
                        weekPath.move(to: CGPoint(x: x, y: 0))
                        weekPath.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: weekDate) else { break }
                    weekDate = next
                }
                context.stroke(weekPath, with: .color(Color.gray.opacity(0.15)), lineWidth: 0.5)
            }
        }
    }
    
    private func drawLine(in context: GraphicsContext, size: CGSize) {
        guard let firstDate = chartWeights.first?.date,
              let lastDate = chartWeights.last?.date else { return }
        
        var path = Path()
        
        for (index, entry) in chartWeights.enumerated() {
            let x = xPosition(for: entry.date, in: size, firstDate: firstDate, lastDate: lastDate)
            let y = yPosition(for: entry.weight, in: size)
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        context.stroke(
            path,
            with: .color(.blue),
            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        )
    }
    
    private func xPosition(for date: Date, in size: CGSize, firstDate: Date, lastDate: Date) -> CGFloat {
        let total = lastDate.timeIntervalSince(firstDate)
        guard total > 0 else { return 0 }
        let t = date.timeIntervalSince(firstDate) / total
        return CGFloat(t) * size.width
    }
    
    private func yPosition(for weight: Double, in size: CGSize) -> CGFloat {
        let range = yAxisRange.upperBound - yAxisRange.lowerBound
        guard range > 0 else { return size.height / 2 }
        let normalized = (weight - yAxisRange.lowerBound) / range
        return size.height - (CGFloat(normalized) * size.height)
    }
}

// MARK: - Editor Calorie Preview

/// Snapshot-compatible version of CalorieTargetCardView
/// Uses real captured data
struct EditorCaloriePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var capturedData = CapturedCardData.shared
    
    var body: some View {
        FixedSizeCard(title: "Calories") {
            VStack(alignment: .center, spacing: 8) {
                Spacer()
                
                let barHeight: CGFloat = 40
                let maxRatio: CGFloat = 1.2
                let targetLineOffset = barHeight * (1.0 - 1.0 / maxRatio)
                
                ZStack(alignment: .top) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(capturedData.weeklyCalorieData.enumerated()), id: \.offset) { _, dayData in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.appInsetBackground)
                                    .frame(width: 12, height: barHeight)
                                    .overlay(
                                        VStack(spacing: 0) {
                                            Spacer(minLength: 0)
                                            let progress = capturedData.calorieTarget > 0 ? CGFloat(dayData.1) / CGFloat(capturedData.calorieTarget) / maxRatio : 0
                                            if progress > 0 {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(Color(red: 0.6, green: 0.2, blue: 0.8))
                                                    .frame(width: 12, height: min(barHeight * progress, barHeight))
                                            }
                                        }
                                    )
                                
                                Text(dayData.day)
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
                
                Text("\(capturedData.caloriesConsumed) / \(capturedData.calorieTarget)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - Editor Protein Preview

/// Snapshot-compatible version of ProteinCardView - uses real captured data
struct EditorProteinPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var capturedData = CapturedCardData.shared
    
    var body: some View {
        FixedSizeCard(title: "Protein") {
            VStack(alignment: .center, spacing: 8) {
                Spacer()
                
                let barHeight: CGFloat = 40
                let maxRatio: CGFloat = 1.2
                let targetLineOffset = barHeight * (1.0 - 1.0 / maxRatio)
                
                ZStack(alignment: .top) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(capturedData.weeklyProteinData.enumerated()), id: \.offset) { _, dayData in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.appInsetBackground)
                                    .frame(width: 12, height: barHeight)
                                    .overlay(
                                        VStack(spacing: 0) {
                                            Spacer(minLength: 0)
                                            let progress = capturedData.proteinTarget > 0 ? CGFloat(dayData.1) / CGFloat(capturedData.proteinTarget) / maxRatio : 0
                                            if progress > 0 {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(CardType.protein.color)
                                                    .frame(width: 12, height: min(barHeight * progress, barHeight))
                                            }
                                        }
                                    )
                                
                                Text(dayData.day)
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
                
                Text("\(capturedData.proteinConsumed)g / \(capturedData.proteinTarget)g")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - Editor Carbs Preview

/// Snapshot-compatible version of CarbsCardView - uses real captured data
struct EditorCarbsPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var capturedData = CapturedCardData.shared
    
    var body: some View {
        FixedSizeCard(title: "Carbs") {
            VStack(alignment: .center, spacing: 8) {
                Spacer()
                
                let barHeight: CGFloat = 40
                let maxRatio: CGFloat = 1.2
                let targetLineOffset = barHeight * (1.0 - 1.0 / maxRatio)
                
                ZStack(alignment: .top) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(capturedData.weeklyCarbsData.enumerated()), id: \.offset) { _, dayData in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.appInsetBackground)
                                    .frame(width: 12, height: barHeight)
                                    .overlay(
                                        VStack(spacing: 0) {
                                            Spacer(minLength: 0)
                                            let progress = capturedData.carbsTarget > 0 ? CGFloat(dayData.1) / CGFloat(capturedData.carbsTarget) / maxRatio : 0
                                            if progress > 0 {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(CardType.carbs.color)
                                                    .frame(width: 12, height: min(barHeight * progress, barHeight))
                                            }
                                        }
                                    )
                                
                                Text(dayData.day)
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
                
                Text("\(capturedData.carbsConsumed)g / \(capturedData.carbsTarget)g")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - Editor Fat Preview

/// Snapshot-compatible version of FatCardView - uses real captured data
struct EditorFatPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var capturedData = CapturedCardData.shared
    
    var body: some View {
        FixedSizeCard(title: "Fat") {
            VStack(alignment: .center, spacing: 8) {
                Spacer()
                
                let barHeight: CGFloat = 40
                let maxRatio: CGFloat = 1.2
                let targetLineOffset = barHeight * (1.0 - 1.0 / maxRatio)
                
                ZStack(alignment: .top) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(capturedData.weeklyFatData.enumerated()), id: \.offset) { _, dayData in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.appInsetBackground)
                                    .frame(width: 12, height: barHeight)
                                    .overlay(
                                        VStack(spacing: 0) {
                                            Spacer(minLength: 0)
                                            let progress = capturedData.fatTarget > 0 ? CGFloat(dayData.1) / CGFloat(capturedData.fatTarget) / maxRatio : 0
                                            if progress > 0 {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(CardType.fat.color)
                                                    .frame(width: 12, height: min(barHeight * progress, barHeight))
                                            }
                                        }
                                    )
                                
                                Text(dayData.day)
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
                
                Text("\(capturedData.fatConsumed)g / \(capturedData.fatTarget)g")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - Editor Fibre Preview

/// Snapshot-compatible version of FibreCardView - uses real captured data
struct EditorFibrePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var capturedData = CapturedCardData.shared
    
    var body: some View {
        FixedSizeCard(title: "Fibre") {
            VStack(alignment: .center, spacing: 8) {
                Spacer()
                
                let barHeight: CGFloat = 40
                let maxRatio: CGFloat = 1.2
                let targetLineOffset = barHeight * (1.0 - 1.0 / maxRatio)
                
                ZStack(alignment: .top) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(capturedData.weeklyFibreData.enumerated()), id: \.offset) { _, dayData in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.appInsetBackground)
                                    .frame(width: 12, height: barHeight)
                                    .overlay(
                                        VStack(spacing: 0) {
                                            Spacer(minLength: 0)
                                            let progress = capturedData.fibreTarget > 0 ? CGFloat(dayData.1) / CGFloat(capturedData.fibreTarget) / maxRatio : 0
                                            if progress > 0 {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(CardType.fibre.color)
                                                    .frame(width: 12, height: min(barHeight * progress, barHeight))
                                            }
                                        }
                                    )
                                
                                Text(dayData.day)
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
                
                Text("\(capturedData.fibreConsumed)g / \(capturedData.fibreTarget)g")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - Editor Steps Preview

/// Snapshot-compatible version of StepsCardView - uses real captured data
struct EditorStepsPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var capturedData = CapturedCardData.shared
    
    var body: some View {
        FixedSizeCard(title: "Steps") {
            VStack(alignment: .center, spacing: 8) {
                Spacer()
                
                let barHeight: CGFloat = 40
                let maxRatio: CGFloat = 1.2
                let targetLineOffset = barHeight * (1.0 - 1.0 / maxRatio)
                
                ZStack(alignment: .top) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(capturedData.weeklyStepsData.enumerated()), id: \.offset) { _, dayData in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.appInsetBackground)
                                    .frame(width: 12, height: barHeight)
                                    .overlay(
                                        VStack(spacing: 0) {
                                            Spacer(minLength: 0)
                                            let progress = capturedData.stepsTarget > 0 ? CGFloat(dayData.1) / CGFloat(capturedData.stepsTarget) / maxRatio : 0
                                            if progress > 0 {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(Color(hex: "#35b8ff"))
                                                    .frame(width: 12, height: min(barHeight * progress, barHeight))
                                            }
                                        }
                                    )
                                
                                Text(dayData.day)
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
                
                Text("\(formatSteps(capturedData.stepsCount)) / \(formatSteps(capturedData.stepsTarget))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 12)
            }
        }
    }
    
    private func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }
}

// MARK: - Editor NOVA Groups Preview

/// Snapshot-compatible version of NovaGroupsCardView - uses real captured data
/// Exactly matches the layout of NovaGroupsCardView
struct EditorNovaGroupsPreview: View {
    @ObservedObject private var capturedData = CapturedCardData.shared
    var isCompact: Bool = false
    
    // NOVA group colors - exactly matching NovaGroupsCardView
    private let novaColors: [Int: Color] = [
        1: Color(hex: "#3f993f"),      // Unprocessed - darker green
        2: Color(hex: "#b7ce0d"),      // Processed culinary ingredients - lime green
        3: Color(hex: "#f28e16"),      // Processed foods - orange
        4: Color(hex: "#d4455a")       // Ultra-processed foods - desaturated red
    ]
    
    // Calculate percentage for a NOVA group from captured distribution
    private func percentage(for group: Int) -> Double {
        return (capturedData.novaDistribution[group] ?? 0) * 100.0
    }
    
    var body: some View {
        FixedSizeCard(title: "NOVA Groups", showInfoButton: false) {
            if isCompact {
                // Compact mode: chart only
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(capturedData.weeklyNovaData.enumerated()), id: \.offset) { _, dayData in
                        EditorNovaWeekdayBar(day: dayData.day, distribution: dayData.distribution, novaColors: novaColors)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 50)
            } else {
                // Wide mode: percentages + chart
                HStack(alignment: .center, spacing: 12) {
                    // Weekly average percentages stacked vertically on the left
                    VStack(spacing: 3) {
                        percentageView(value: percentage(for: 1), label: "Unprocessed", color: novaColors[1] ?? .gray)
                        percentageView(value: percentage(for: 2), label: "Ingredients", color: novaColors[2] ?? .gray)
                        percentageView(value: percentage(for: 3), label: "Processed", color: novaColors[3] ?? .gray)
                        percentageView(value: percentage(for: 4), label: "Ultra", color: novaColors[4] ?? .gray)
                    }
                    .frame(minWidth: 100) // Minimum width but flexible
                    
                    // Weekday bars on the right - more compact spacing
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(capturedData.weeklyNovaData.enumerated()), id: \.offset) { _, dayData in
                            EditorNovaWeekdayBar(day: dayData.day, distribution: dayData.distribution, novaColors: novaColors)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 50) // Use available space flexibly with increased height
                }
            }
        }
    }
    
    // Helper function to create a percentage view with inactive state handling - exactly matching NovaGroupsCardView
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
    }
}

/// Weekday bar for NOVA preview - exactly matching WeekdayBar from NovaGroupsCardView
struct EditorNovaWeekdayBar: View {
    let day: String
    let distribution: [Int: Double]
    let novaColors: [Int: Color]
    
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
                            if !distribution.isEmpty && distribution.values.reduce(0, +) > 0 {
                                // Create a ZStack to apply clipping to the entire stack
                                ZStack(alignment: .bottom) {
                                    // Create a single stacked bar with all NOVA groups
                                    VStack(spacing: 0) {
                                        ForEach(1...4, id: \.self) { group in
                                            if let percentage = distribution[group], percentage > 0 {
                                                Rectangle()
                                                    .fill(novaColors[group] ?? .gray)
                                                    .frame(width: 12, height: geometry.size.height * percentage)
                                            }
                                        }
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 3))
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

// MARK: - Editor NutriScore Preview

/// Snapshot-compatible version of NutriScoreCardView - uses real captured data
/// Exactly matches the layout of NutriScoreCardView
struct EditorNutriScorePreview: View {
    @ObservedObject private var capturedData = CapturedCardData.shared
    var isCompact: Bool = false
    
    // Calculate percentage for a grade from captured distribution
    private func percentage(for grade: String) -> Double {
        return (capturedData.nutriScoreDistribution[grade] ?? 0) * 100.0
    }
    
    var body: some View {
        FixedSizeCard(title: "Nutri-Score", showInfoButton: false) {
            if isCompact {
                // Compact mode: chart only
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(capturedData.weeklyNutriScoreData.enumerated()), id: \.offset) { _, dayData in
                        EditorNutriScoreWeekdayBar(day: dayData.day, distribution: dayData.distribution)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 50)
            } else {
                // Wide mode: percentages + chart
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Left side: Grade percentages centered at 25% from left
                        VStack(spacing: 3) {
                            gradePercentageRow(grade: "A", percentage: percentage(for: "A"), color: .green)
                            gradePercentageRow(grade: "B", percentage: percentage(for: "B"), color: .blue)
                            gradePercentageRow(grade: "C", percentage: percentage(for: "C"), color: .yellow)
                            gradePercentageRow(grade: "D", percentage: percentage(for: "D"), color: .orange)
                            gradePercentageRow(grade: "E", percentage: percentage(for: "E"), color: .red)
                        }
                        .frame(width: geometry.size.width * 0.5, alignment: .center)
                        
                        // Right side: Weekday bars centered at 75% from left
                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(Array(capturedData.weeklyNutriScoreData.enumerated()), id: \.offset) { _, dayData in
                                EditorNutriScoreWeekdayBar(day: dayData.day, distribution: dayData.distribution)
                            }
                        }
                        .frame(width: geometry.size.width * 0.5, alignment: .center)
                    }
                }
                .frame(height: 80)
            }
        }
    }
    
    // Helper function to create individual grade percentage rows - exactly matching NutriScoreCardView
    private func gradePercentageRow(grade: String, percentage: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(grade)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 12, alignment: .leading)
            
            Text("\(Int(percentage))%")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

/// Weekday bar for Nutri-Score preview - exactly matching NutriScoreStackedDayBar
struct EditorNutriScoreWeekdayBar: View {
    let day: String
    let distribution: [String: Double]
    
    private let nutriScoreColors: [String: Color] = [
        "A": Color(hex: "#22e83d"),      // Grade A - bright green
        "B": Color(hex: "#8eff00"),      // Grade B - lime green  
        "C": Color(hex: "#f4df70"),      // Grade C - yellow
        "D": Color(hex: "#ffb300"),      // Grade D - orange
        "E": Color(hex: "#ff5722")       // Grade E - red
    ]
    
    private var totalValue: Double {
        distribution.values.reduce(0, +)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Stacked bar
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.appInsetBackground)
                    .frame(width: 12, height: 48)
                
                // Stacked segments (bottom to top: A, B, C, D, E)
                if totalValue > 0 {
                    VStack(spacing: 0) {
                        ForEach(["A", "B", "C", "D", "E"], id: \.self) { grade in
                            let value = distribution[grade] ?? 0
                            if value > 0 {
                                let heightPercentage = CGFloat(value) / CGFloat(totalValue)
                                Rectangle()
                                    .fill(nutriScoreColors[grade] ?? .gray)
                                    .frame(height: 48 * heightPercentage)
                            }
                        }
                    }
                    .frame(width: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            
            Text(day)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Editor Gut Health Preview

/// Snapshot-compatible version of GutHealthCardView - uses real captured data
/// Exactly matches the layout of GutHealthCardView
struct EditorGutHealthPreview: View {
    @ObservedObject private var capturedData = CapturedCardData.shared
    
    // Gauge colors - exactly matching GutHealthScoreService
    private let gaugeColors: [Color] = [
        Color(red: 0.85, green: 0.2, blue: 0.2),   // Red (0-20)
        Color(red: 0.95, green: 0.5, blue: 0.2),   // Orange (20-40)
        Color(red: 0.95, green: 0.8, blue: 0.2),   // Yellow (40-60)
        Color(red: 0.6, green: 0.8, blue: 0.3),    // Lime (60-80)
        Color(red: 0.2, green: 0.7, blue: 0.3)     // Green (80-100)
    ]
    
    // Get score color - matching GutHealthScoreService.getScoreColor
    private func getScoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return gaugeColors[4]
        case 60..<80: return gaugeColors[3]
        case 40..<60: return gaugeColors[2]
        case 20..<40: return gaugeColors[1]
        default: return gaugeColors[0]
        }
    }
    
    var body: some View {
        FixedSizeCard(title: "Gut Health", showInfoButton: false) {
            HStack(spacing: 16) {
                // Mini gauge on the left
                ZStack {
                    // Simplified arc gauge - exactly matching MiniGutHealthGauge
                    EditorMiniGutHealthGauge(score: capturedData.gutHealthScore, gaugeColors: gaugeColors)
                        .frame(width: 80, height: 60)
                        .offset(y: -13)
                    
                    // Score number
                    Text("\(Int(capturedData.gutHealthScore))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(getScoreColor(capturedData.gutHealthScore))
                        .offset(y: 22)
                }
                .frame(width: 90, height: 70)
                
                // Category bars on the right - 4 pillars - exactly matching GutHealthCardView
                VStack(alignment: .leading, spacing: 4) {
                    EditorCategoryMiniBar(label: "Fiber", value: capturedData.fiberScore, color: .green)
                    EditorCategoryMiniBar(label: "UPF", value: capturedData.upfScore, color: .red)
                    EditorCategoryMiniBar(label: "Fermented", value: capturedData.fermentedScore, color: .purple)
                    EditorCategoryMiniBar(label: "Fat", value: capturedData.fatQualityScore, color: .orange)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 4)
        }
    }
}

/// Snapshot-compatible mini gauge for gut health - exactly matching MiniGutHealthGauge
struct EditorMiniGutHealthGauge: View {
    let score: Double
    let gaugeColors: [Color]
    
    private var needleRotation: Double {
        return 150.0 + (score / 100.0) * 240.0
    }
    
    var body: some View {
        GeometryReader { geometry in
            let centerY = geometry.size.height * 0.75
            let center = CGPoint(x: geometry.size.width / 2, y: centerY)
            let radius = min(geometry.size.width / 2, geometry.size.height) - 5
            let innerRadius = radius * 0.65
            let segmentAngle = 240.0 / 5.0
            
            ZStack {
                // Colored arc segments
                ForEach(0..<5, id: \.self) { index in
                    Path { path in
                        let startAngle = Angle(degrees: 150.0 + Double(index) * segmentAngle)
                        let endAngle = Angle(degrees: 150.0 + Double(index + 1) * segmentAngle - 2)
                        
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
                    let needleLength = radius * 0.75
                    let angle = Angle(degrees: needleRotation).radians
                    let tipX = center.x + cos(angle) * needleLength
                    let tipY = center.y + sin(angle) * needleLength
                    
                    let leftAngle = angle + .pi / 2
                    let rightAngle = angle - .pi / 2
                    let baseLeftX = center.x + cos(leftAngle) * 2
                    let baseLeftY = center.y + sin(leftAngle) * 2
                    let baseRightX = center.x + cos(rightAngle) * 2
                    let baseRightY = center.y + sin(rightAngle) * 2
                    
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: baseLeftX, y: baseLeftY))
                    path.addLine(to: CGPoint(x: baseRightX, y: baseRightY))
                    path.closeSubpath()
                }
                .fill(Color(.label))
                
                // Center dot
                Circle()
                    .fill(Color(.label))
                    .frame(width: 6, height: 6)
                    .position(center)
            }
        }
    }
}

/// Snapshot-compatible category bar - exactly matching CategoryMiniBar
struct EditorCategoryMiniBar: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 65, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.appInsetBackground)
                        .frame(height: 8)
                    
                    // Fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(0, geometry.size.width * min(value / 100.0, 1.0)), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Editor Daily Goals Preview

/// Snapshot-compatible version of DailyGoalsCardView
struct EditorDailyGoalsPreview: View {
    var body: some View {
        DailyGoalsCardView(isPreview: true)
    }
}

// MARK: - Editor Card View Provider

/// Provides snapshot-compatible preview views for the dashboard editor
struct EditorPreviewCardProvider {
    
    /// Returns a snapshot-compatible preview view for the given card type
    static func previewView(for cardType: CardType, isWeightChartExpanded: Bool = false, isNovaGroupsCompact: Bool = false, isNutriScoreCompact: Bool = false) -> AnyView {
        switch cardType {
        case .currentWeight:
            return AnyView(EditorCurrentWeightPreview())
        case .weightChart:
            return AnyView(EditorWeightChartPreview(isExpanded: isWeightChartExpanded))
        case .calorieTarget:
            return AnyView(EditorCaloriePreview())
        case .protein:
            return AnyView(EditorProteinPreview())
        case .carbs:
            return AnyView(EditorCarbsPreview())
        case .fat:
            return AnyView(EditorFatPreview())
        case .fibre:
            return AnyView(EditorFibrePreview())
        case .activity:
            return AnyView(EditorStepsPreview())
        case .dailyGoals:
            return AnyView(EditorDailyGoalsPreview())
        case .novaGroups:
            return AnyView(EditorNovaGroupsPreview(isCompact: isNovaGroupsCompact))
        case .nutriScore:
            return AnyView(EditorNutriScorePreview(isCompact: isNutriScoreCompact))
        case .gutHealth:
            return AnyView(EditorGutHealthPreview())
        case .empty:
            return AnyView(EmptyView())
        }
    }
}
