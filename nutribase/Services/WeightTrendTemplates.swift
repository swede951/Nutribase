import Foundation

/// Pre-smoothed weight trend templates for instant chart rendering.
/// Contains pre-computed smoothing curves for common weight patterns.
class WeightTrendTemplates {
    static let shared = WeightTrendTemplates()
    
    // MARK: - Pre-computed Trend Curves
    
    /// Template for a declining weight trend (weight loss)
    struct DeclineTrendTemplate {
        let dayOffsets: [Int]  // Days from start
        let normalizedWeights: [Double]  // 0-1 normalized weights
        let smoothedWeights: [Double]  // Pre-smoothed values
    }
    
    /// Template for a flat/maintenance trend
    struct MaintenanceTrendTemplate {
        let dayOffsets: [Int]
        let normalizedWeights: [Double]
        let smoothedWeights: [Double]
    }
    
    /// Template for an increasing weight trend (weight gain)
    struct IncreaseTrendTemplate {
        let dayOffsets: [Int]
        let normalizedWeights: [Double]
        let smoothedWeights: [Double]
    }
    
    // MARK: - Pre-computed Templates
    
    /// 7-day declining trend templates (0.5lb/week to 2lb/week)
    private let weeklyDeclineTemplates: [Double: [Double]]
    
    /// 30-day declining trend templates
    private let monthlyDeclineTemplates: [Double: [Double]]
    
    /// 90-day declining trend templates
    private let quarterlyDeclineTemplates: [Double: [Double]]
    
    /// Common fluctuation patterns (for adding realistic noise)
    private let dailyFluctuationPatterns: [[Double]]
    
    /// Weekly fluctuation patterns (water weight, etc.)
    private let weeklyFluctuationPatterns: [[Double]]
    
    // MARK: - Smoothing Coefficients Cache
    
    /// Pre-computed smoothing coefficients for different timeframes
    struct SmoothingCoefficients {
        let alpha: Double
        let beta: Double
        let gamma: Double
        let windowSize: Int
    }
    
    private let timeframeCoefficients: [Int: SmoothingCoefficients]
    
    // MARK: - Initialization
    
    private init() {
        // Pre-compute weekly decline templates for common rates
        var weeklyTemplates: [Double: [Double]] = [:]
        for rate in stride(from: 0.25, through: 2.0, by: 0.25) {
            weeklyTemplates[rate] = Self.computeDeclineTemplate(days: 7, weeklyRate: rate)
        }
        self.weeklyDeclineTemplates = weeklyTemplates
        
        // Pre-compute monthly decline templates
        var monthlyTemplates: [Double: [Double]] = [:]
        for rate in stride(from: 0.25, through: 2.0, by: 0.25) {
            monthlyTemplates[rate] = Self.computeDeclineTemplate(days: 30, weeklyRate: rate)
        }
        self.monthlyDeclineTemplates = monthlyTemplates
        
        // Pre-compute quarterly decline templates
        var quarterlyTemplates: [Double: [Double]] = [:]
        for rate in stride(from: 0.25, through: 2.0, by: 0.25) {
            quarterlyTemplates[rate] = Self.computeDeclineTemplate(days: 90, weeklyRate: rate)
        }
        self.quarterlyDeclineTemplates = quarterlyTemplates
        
        // Pre-compute daily fluctuation patterns
        self.dailyFluctuationPatterns = Self.generateFluctuationPatterns(count: 10, length: 7)
        
        // Pre-compute weekly fluctuation patterns
        self.weeklyFluctuationPatterns = Self.generateFluctuationPatterns(count: 5, length: 30)
        
        // Pre-compute timeframe coefficients
        var coefficients: [Int: SmoothingCoefficients] = [:]
        coefficients[7] = SmoothingCoefficients(alpha: 0.7, beta: 0.2, gamma: 0.8, windowSize: 3)
        coefficients[14] = SmoothingCoefficients(alpha: 0.6, beta: 0.18, gamma: 0.7, windowSize: 5)
        coefficients[30] = SmoothingCoefficients(alpha: 0.5, beta: 0.15, gamma: 0.6, windowSize: 7)
        coefficients[60] = SmoothingCoefficients(alpha: 0.4, beta: 0.12, gamma: 0.5, windowSize: 10)
        coefficients[90] = SmoothingCoefficients(alpha: 0.35, beta: 0.1, gamma: 0.45, windowSize: 14)
        coefficients[180] = SmoothingCoefficients(alpha: 0.3, beta: 0.08, gamma: 0.4, windowSize: 21)
        coefficients[365] = SmoothingCoefficients(alpha: 0.25, beta: 0.06, gamma: 0.35, windowSize: 28)
        self.timeframeCoefficients = coefficients
    }
    
    // MARK: - Static Computation Helpers
    
    /// Compute a decline template with pre-applied smoothing
    private static func computeDeclineTemplate(days: Int, weeklyRate: Double) -> [Double] {
        var values: [Double] = []
        let dailyRate = weeklyRate / 7.0
        
        // Generate raw declining values with realistic fluctuations
        var currentValue = 1.0  // Normalized starting weight
        for day in 0..<days {
            // Add daily fluctuation (typically ±0.5-1.5% of body weight)
            let fluctuation = Double.random(in: -0.01...0.015)
            
            // Add weekly pattern (higher at start of week, lower mid-week)
            let weekdayModifier = sin(Double(day % 7) / 7.0 * .pi * 2) * 0.005
            
            let value = currentValue + fluctuation + weekdayModifier
            values.append(max(0, value))
            
            currentValue -= dailyRate / 100.0  // Convert to percentage decline
        }
        
        // Apply pre-smoothing
        return applyTemplateSmoothing(values)
    }
    
    /// Apply smoothing to a template
    private static func applyTemplateSmoothing(_ values: [Double]) -> [Double] {
        guard values.count > 2 else { return values }
        
        let alpha = 0.4
        var smoothed: [Double] = []
        var level = values[0]
        var trend = values[1] - values[0]
        
        smoothed.append(level)
        
        for i in 1..<values.count {
            let prevLevel = level
            level = alpha * values[i] + (1 - alpha) * (level + trend)
            trend = 0.1 * (level - prevLevel) + 0.9 * trend
            smoothed.append(level)
        }
        
        return smoothed
    }
    
    /// Generate random fluctuation patterns
    private static func generateFluctuationPatterns(count: Int, length: Int) -> [[Double]] {
        var patterns: [[Double]] = []
        
        for seed in 0..<count {
            var pattern: [Double] = []
            var rng = SeededRandomGenerator(seed: UInt64(seed * 12345))
            
            for day in 0..<length {
                // Base fluctuation: typically ±0.5-1.5% of body weight
                let baseFluctuation = rng.nextDouble() * 0.02 - 0.01
                
                // Weekly pattern (water retention on weekends)
                let weekdayModifier: Double
                switch day % 7 {
                case 0, 6:  // Weekend - typically higher
                    weekdayModifier = rng.nextDouble() * 0.008
                case 1:  // Monday - often highest
                    weekdayModifier = rng.nextDouble() * 0.01
                case 3, 4:  // Mid-week - typically lowest
                    weekdayModifier = -rng.nextDouble() * 0.005
                default:
                    weekdayModifier = 0
                }
                
                pattern.append(baseFluctuation + weekdayModifier)
            }
            
            patterns.append(pattern)
        }
        
        return patterns
    }
    
    // MARK: - Public Access Methods
    
    /// Get pre-computed decline template for a weekly rate
    func getDeclineTemplate(days: Int, weeklyRate: Double) -> [Double]? {
        let roundedRate = (weeklyRate * 4).rounded() / 4.0  // Round to nearest 0.25
        
        switch days {
        case 1...7:
            return weeklyDeclineTemplates[roundedRate]
        case 8...30:
            return monthlyDeclineTemplates[roundedRate]
        case 31...90:
            return quarterlyDeclineTemplates[roundedRate]
        default:
            return quarterlyDeclineTemplates[roundedRate]
        }
    }
    
    /// Get smoothing coefficients for a timeframe
    func getSmoothingCoefficients(days: Int) -> SmoothingCoefficients {
        // Find the closest pre-computed timeframe
        let sortedKeys = timeframeCoefficients.keys.sorted()
        
        for key in sortedKeys {
            if days <= key {
                return timeframeCoefficients[key]!
            }
        }
        
        return timeframeCoefficients[365]!
    }
    
    /// Get a random fluctuation pattern
    func getFluctuationPattern(index: Int, days: Int) -> [Double] {
        if days <= 7 {
            let safeIndex = index % dailyFluctuationPatterns.count
            return dailyFluctuationPatterns[safeIndex]
        } else {
            let safeIndex = index % weeklyFluctuationPatterns.count
            return weeklyFluctuationPatterns[safeIndex]
        }
    }
    
    /// Apply pre-computed template to actual weight data
    func applyTemplateSmoothing(to weights: [Double], startWeight: Double, endWeight: Double, days: Int) -> [Double] {
        guard !weights.isEmpty else { return weights }
        
        // Calculate effective weekly rate
        let totalDays = max(days, 1)
        let totalChange = startWeight - endWeight
        let weeklyRate = (totalChange / Double(totalDays)) * 7.0
        
        // Get template if available
        if let template = getDeclineTemplate(days: totalDays, weeklyRate: abs(weeklyRate)) {
            // Scale template to actual weight range
            let range = startWeight - endWeight
            return template.map { normalizedValue in
                endWeight + normalizedValue * range
            }
        }
        
        // Fallback to runtime smoothing with pre-computed coefficients
        let coeffs = getSmoothingCoefficients(days: totalDays)
        return applyRuntimeSmoothing(weights, coefficients: coeffs)
    }
    
    /// Apply runtime smoothing with pre-computed coefficients
    private func applyRuntimeSmoothing(_ values: [Double], coefficients: SmoothingCoefficients) -> [Double] {
        guard values.count > 2 else { return values }
        
        var smoothed: [Double] = []
        var level = values[0]
        var trend = values.count > 1 ? values[1] - values[0] : 0
        
        smoothed.append(level)
        
        for i in 1..<values.count {
            let prevLevel = level
            level = coefficients.alpha * values[i] + (1 - coefficients.alpha) * (level + trend)
            trend = coefficients.beta * (level - prevLevel) + (1 - coefficients.beta) * trend
            smoothed.append(level)
        }
        
        return smoothed
    }
    
    // MARK: - Cache Stats
    
    func getCacheStats() -> String {
        return """
        📊 WeightTrendTemplates Stats:
        - Weekly decline templates: \(weeklyDeclineTemplates.count)
        - Monthly decline templates: \(monthlyDeclineTemplates.count)
        - Quarterly decline templates: \(quarterlyDeclineTemplates.count)
        - Daily fluctuation patterns: \(dailyFluctuationPatterns.count)
        - Weekly fluctuation patterns: \(weeklyFluctuationPatterns.count)
        - Timeframe coefficients: \(timeframeCoefficients.count)
        """
    }
}

// MARK: - Seeded Random Generator

/// Deterministic random number generator for reproducible patterns
struct SeededRandomGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    
    mutating func nextDouble() -> Double {
        return Double(next() & 0x7FFFFFFFFFFFFFFF) / Double(Int64.max)
    }
}
