import Foundation

/// Match the app's timeframes
enum WeightChartTimeFrame {
    case oneWeek
    case oneMonth
    case threeMonths
    case oneYear
    case greaterThanOneYear
    
    /// Convert from the app's TimeFrame enum
    static func from(_ timeFrame: TimeFrame) -> WeightChartTimeFrame {
        switch timeFrame {
        case .oneWeek:
            return .oneWeek
        case .oneMonth:
            return .oneMonth
        case .threeMonths:
            return .threeMonths
        case .oneYear:
            return .oneYear
        case .allTime:
            return .greaterThanOneYear
        }
    }
}

/// What the chart actually needs
struct WeightChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let recorded: Double
    let trend: Double
}

/// Builds chart-ready data using different smoothing depending on timeframe
/// This implements Happy Scale-style adaptive smoothing:
/// - Short timeframes (1W, 1M): Less smoothing, show more detail
/// - Medium timeframes (3M): Moderate smoothing
/// - Long timeframes (1Y, >1Y): Heavy smoothing, weekly aggregation
final class WeightChartDataBuilder {
    
    /// Main entry point – call this from your view
    /// - Parameters:
    ///   - entries: Raw weight log entries from the user
    ///   - timeframe: Selected timeframe (determines smoothing level)
    /// - Returns: Chart-ready data points with trend values
    static func buildChartData(from entries: [WeightLogEntry],
                               timeframe: WeightChartTimeFrame) -> [WeightChartPoint] {
        guard !entries.isEmpty else { return [] }
        
        // 1) Pick smoothing parameters for this timeframe
        let params = params(for: timeframe)
        
        // 2) Optionally aggregate to weekly for long ranges (reduces noise)
        let sourceEntries: [WeightLogEntry]
        if params.useWeeklySource {
            sourceEntries = weeklyAverage(from: entries)
        } else {
            sourceEntries = entries
        }
        
        // 3) Run the Happy Scale-style moving average calculator with timeframe-specific parameters
        //    (daily interpolation + bidirectional EMA + timeframe-aware Savitzky-Golay)
        let smoothedEntries = WeightMovingAverageCalculator
            .calculateMovingAverages(for: sourceEntries,
                                    emaAlpha: params.emaAlpha,
                                    sgWindow: params.sgWindow,
                                    weeklyRateAlpha: params.weeklyRateAlpha,
                                    sgPolyOrder: params.sgPolyOrder)
        
        // 4) Downsample for the chart if needed (skip points for performance)
        let stepped = stride(from: 0, to: smoothedEntries.count, by: params.sampleStep).map { idx -> WeightChartPoint in
            let e = smoothedEntries[idx]
            return WeightChartPoint(
                date: e.date,
                recorded: e.weight,
                trend: e.movingAverage
            )
        }
        
        return stepped
    }
    
    // MARK: - Timeframe Parameters
    
    /// Configuration for chart smoothing based on timeframe
    private struct ChartParams {
        let emaAlpha: Double          // EMA smoothing factor
        let sgWindow: Int             // Savitzky-Golay window size (days, 0 = skip SG)
        let sgPolyOrder: Int          // Polynomial order for Savitzky-Golay
        let weeklyRateAlpha: Double   // Weekly rate EMA smoothing factor
        let sampleStep: Int           // How many points to skip when charting (1 = show all)
        let useWeeklySource: Bool     // Aggregate to weekly before smoothing?
    }
    
    /// Returns optimal smoothing parameters for each timeframe
    /// Shorter timeframes = less smoothing, more detail
    /// Longer timeframes = more smoothing, clearer trends
    private static func params(for timeframe: WeightChartTimeFrame) -> ChartParams {
        switch timeframe {
        case .oneWeek:
            // Bidirectional EMA only, no SG - snappy and responsive
            return ChartParams(emaAlpha: 0.85, sgWindow: 0, sgPolyOrder: 2, weeklyRateAlpha: 0.75, sampleStep: 1, useWeeklySource: false)
            
        case .oneMonth:
            // Bidirectional EMA only, no SG - shows short-term changes
            return ChartParams(emaAlpha: 0.70, sgWindow: 0, sgPolyOrder: 2, weeklyRateAlpha: 0.60, sampleStep: 1, useWeeklySource: false)
            
        case .threeMonths:
            // Bidirectional EMA only, no SG - balanced responsiveness
            return ChartParams(emaAlpha: 0.55, sgWindow: 0, sgPolyOrder: 3, weeklyRateAlpha: 0.45, sampleStep: 2, useWeeklySource: false)
            
        case .oneYear:
            // Long-term view - full EMA + SG smoothing with weekly data
            return ChartParams(emaAlpha: 0.22, sgWindow: 21, sgPolyOrder: 3, weeklyRateAlpha: 0.20, sampleStep: 1, useWeeklySource: true)
            
        case .greaterThanOneYear:
            // Ultra-smooth macro trend - full EMA + SG for decade view
            return ChartParams(emaAlpha: 0.12, sgWindow: 31, sgPolyOrder: 3, weeklyRateAlpha: 0.18, sampleStep: 1, useWeeklySource: true)
        }
    }
    
    // MARK: - Weekly Aggregation
    
    /// Turn daily entries into one-per-week entries (used for 1Y and >1Y)
    /// Groups by week and averages all weights in that week
    /// This reduces noise and makes long-term trends clearer
    private static func weeklyAverage(from entries: [WeightLogEntry]) -> [WeightLogEntry] {
        let calendar = Calendar.current
        
        // Group entries by the start of their week
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.dateInterval(of: .weekOfYear, for: entry.date)!.start
        }
        
        // For each week, create a single entry with the average weight
        return grouped.keys.sorted().compactMap { weekStart in
            guard let group = grouped[weekStart], !group.isEmpty else { return nil }
            
            // Average the moving averages
            let avg = group.map { $0.movingAverage }.reduce(0, +) / Double(group.count)
            
            return WeightLogEntry(
                id: UUID(),
                date: weekStart,
                weight: avg,
                movingAverage: avg,
                weeklyRate: nil,
                notes: nil
            )
        }
    }
}
