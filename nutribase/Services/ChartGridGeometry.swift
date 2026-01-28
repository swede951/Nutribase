import SwiftUI

/// Pre-computed chart grid geometry for faster rendering.
/// Stores reusable paths and positions that don't change with data.
class ChartGridGeometry {
    static let shared = ChartGridGeometry()
    
    // MARK: - Pre-computed Grid Configurations
    
    /// Standard grid configuration for bar charts
    struct BarChartGrid {
        let horizontalLineCount: Int
        let horizontalLinePositions: [CGFloat]  // Normalized 0-1 positions
        let barWidth: CGFloat
        let barSpacing: CGFloat
        let cornerRadius: CGFloat
        let targetLinePosition: CGFloat  // Normalized position for target line
    }
    
    /// Standard grid configuration for line charts
    struct LineChartGrid {
        let horizontalLineCount: Int
        let verticalLineCount: Int
        let padding: EdgeInsets
        let lineWidth: CGFloat
        let gridLineWidth: CGFloat
    }
    
    // MARK: - Pre-computed Grids
    
    /// Dashboard card bar chart (7 bars for weekdays)
    let weeklyBarChart: BarChartGrid
    
    /// Monthly bar chart (up to 31 bars)
    let monthlyBarChart: BarChartGrid
    
    /// Weight chart line grid
    let weightLineChart: LineChartGrid
    
    /// Detail view weekly chart
    let detailWeeklyChart: BarChartGrid
    
    // MARK: - Pre-computed Paths
    
    private var cachedHorizontalGridPaths: [String: Path] = [:]
    private var cachedVerticalGridPaths: [String: Path] = [:]
    
    // MARK: - Initialization
    
    private init() {
        // Weekly bar chart (dashboard cards)
        weeklyBarChart = BarChartGrid(
            horizontalLineCount: 5,
            horizontalLinePositions: [0.0, 0.25, 0.5, 0.75, 1.0],
            barWidth: 12,
            barSpacing: 6,
            cornerRadius: 3,
            targetLinePosition: 1.0 / 1.2  // 83.3% for 120% max scale
        )
        
        // Monthly bar chart
        monthlyBarChart = BarChartGrid(
            horizontalLineCount: 5,
            horizontalLinePositions: [0.0, 0.25, 0.5, 0.75, 1.0],
            barWidth: 6,
            barSpacing: 2,
            cornerRadius: 2,
            targetLinePosition: 1.0 / 1.2
        )
        
        // Weight line chart
        weightLineChart = LineChartGrid(
            horizontalLineCount: 5,
            verticalLineCount: 6,
            padding: EdgeInsets(top: 10, leading: 40, bottom: 20, trailing: 10),
            lineWidth: 3,
            gridLineWidth: 0.5
        )
        
        // Detail view weekly chart
        detailWeeklyChart = BarChartGrid(
            horizontalLineCount: 5,
            horizontalLinePositions: [0.0, 0.25, 0.5, 0.75, 1.0],
            barWidth: 30,
            barSpacing: 0,
            cornerRadius: 6,
            targetLinePosition: 1.0 / 1.2
        )
        
        // Pre-compute common paths
        precomputeCommonPaths()
    }
    
    // MARK: - Path Generation
    
    private func precomputeCommonPaths() {
        // Pre-compute horizontal grid paths for common sizes
        for lineCount in [3, 4, 5, 6] {
            let key = "horizontal_\(lineCount)"
            cachedHorizontalGridPaths[key] = createNormalizedHorizontalGridPath(lineCount: lineCount)
        }
        
        // Pre-compute vertical grid paths for weeks and months
        for count in [7, 28, 29, 30, 31] {
            let key = "vertical_\(count)"
            cachedVerticalGridPaths[key] = createNormalizedVerticalGridPath(dividerCount: count)
        }
    }
    
    /// Create normalized horizontal grid path (0-1 coordinate space)
    private func createNormalizedHorizontalGridPath(lineCount: Int) -> Path {
        var path = Path()
        let spacing = 1.0 / CGFloat(lineCount - 1)
        
        for i in 0..<lineCount {
            let y = CGFloat(i) * spacing
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: 1, y: y))
        }
        
        return path
    }
    
    /// Create normalized vertical grid path
    private func createNormalizedVerticalGridPath(dividerCount: Int) -> Path {
        var path = Path()
        let spacing = 1.0 / CGFloat(dividerCount)
        
        for i in 1..<dividerCount {
            let x = CGFloat(i) * spacing
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: 1))
        }
        
        return path
    }
    
    // MARK: - Scaled Path Access
    
    /// Get horizontal grid path scaled to actual size
    func horizontalGridPath(lineCount: Int, size: CGSize) -> Path {
        let key = "horizontal_\(lineCount)"
        guard let normalizedPath = cachedHorizontalGridPaths[key] else {
            return createNormalizedHorizontalGridPath(lineCount: lineCount)
                .applying(CGAffineTransform(scaleX: size.width, y: size.height))
        }
        
        return normalizedPath.applying(CGAffineTransform(scaleX: size.width, y: size.height))
    }
    
    /// Get vertical grid path scaled to actual size
    func verticalGridPath(dividerCount: Int, size: CGSize) -> Path {
        let key = "vertical_\(dividerCount)"
        guard let normalizedPath = cachedVerticalGridPaths[key] else {
            return createNormalizedVerticalGridPath(dividerCount: dividerCount)
                .applying(CGAffineTransform(scaleX: size.width, y: size.height))
        }
        
        return normalizedPath.applying(CGAffineTransform(scaleX: size.width, y: size.height))
    }
    
    // MARK: - Y-Axis Helpers
    
    /// Pre-computed nice Y-axis intervals
    static let niceIntervals: [Double] = [0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000]
    
    /// Get a nice interval for Y-axis given range
    func niceYAxisInterval(for range: Double, targetTicks: Int = 5) -> Double {
        let roughInterval = range / Double(targetTicks - 1)
        
        // Find the nearest nice interval
        for interval in Self.niceIntervals {
            if interval >= roughInterval {
                return interval
            }
        }
        
        return Self.niceIntervals.last ?? 1000
    }
    
    /// Calculate Y-axis tick values
    func yAxisTicks(min: Double, max: Double, targetTicks: Int = 5) -> [Double] {
        let range = max - min
        guard range > 0 else { return [min] }
        
        let interval = niceYAxisInterval(for: range, targetTicks: targetTicks)
        let firstTick = (min / interval).rounded(.down) * interval
        
        var ticks: [Double] = []
        var current = firstTick
        
        while current <= max + interval * 0.1 {
            if current >= min - interval * 0.1 {
                ticks.append(current)
            }
            current += interval
        }
        
        return ticks
    }
    
    // MARK: - Bar Position Calculations
    
    /// Calculate bar positions for weekly chart
    func weeklyBarPositions(chartWidth: CGFloat, barCount: Int = 7) -> [CGFloat] {
        let totalBarWidth = weeklyBarChart.barWidth * CGFloat(barCount)
        let totalSpacing = weeklyBarChart.barSpacing * CGFloat(barCount - 1)
        let totalContentWidth = totalBarWidth + totalSpacing
        let startX = (chartWidth - totalContentWidth) / 2
        
        return (0..<barCount).map { i in
            startX + CGFloat(i) * (weeklyBarChart.barWidth + weeklyBarChart.barSpacing) + weeklyBarChart.barWidth / 2
        }
    }
    
    /// Calculate bar positions for monthly chart
    func monthlyBarPositions(chartWidth: CGFloat, dayCount: Int) -> [CGFloat] {
        let availableWidth = chartWidth - 20  // Padding
        let barWidth = min(monthlyBarChart.barWidth, availableWidth / CGFloat(dayCount) - 1)
        let totalWidth = barWidth * CGFloat(dayCount)
        let startX = (chartWidth - totalWidth) / 2
        
        return (0..<dayCount).map { i in
            startX + CGFloat(i) * barWidth + barWidth / 2
        }
    }
    
    // MARK: - Target Line Position
    
    /// Calculate target line Y position (for 120% max scale)
    func targetLineY(chartHeight: CGFloat, maxRatio: CGFloat = 1.2) -> CGFloat {
        return chartHeight * (1.0 - 1.0 / maxRatio)
    }
}

// MARK: - Canvas Drawing Extensions

extension GraphicsContext {
    /// Draw pre-computed horizontal grid
    func drawHorizontalGrid(in size: CGSize, lineCount: Int = 5, color: Color = .gray.opacity(0.3)) {
        let path = ChartGridGeometry.shared.horizontalGridPath(lineCount: lineCount, size: size)
        stroke(path, with: .color(color), lineWidth: 0.5)
    }
    
    /// Draw pre-computed vertical grid for days
    func drawVerticalGrid(in size: CGSize, dividerCount: Int, color: Color = .gray.opacity(0.3)) {
        let path = ChartGridGeometry.shared.verticalGridPath(dividerCount: dividerCount, size: size)
        stroke(path, with: .color(color), lineWidth: 0.5)
    }
    
    /// Draw target line at standard position
    func drawTargetLine(in size: CGSize, color: Color = .black, lineWidth: CGFloat = 2) {
        let y = ChartGridGeometry.shared.targetLineY(chartHeight: size.height)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
        stroke(path, with: .color(color), lineWidth: lineWidth)
    }
}
