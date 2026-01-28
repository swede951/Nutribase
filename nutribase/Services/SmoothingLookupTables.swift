import Foundation

/// Pre-computed lookup tables for weight smoothing algorithms.
/// Eliminates expensive runtime calculations by pre-computing common smoothing parameters.
class SmoothingLookupTables {
    static let shared = SmoothingLookupTables()
    
    // MARK: - Pre-computed DES Parameters
    
    /// Double Exponential Smoothing parameters for different data densities
    struct DESParameters {
        let alpha: Double  // Level smoothing factor
        let beta: Double   // Trend smoothing factor
        let turningDamping: Double  // Damping factor for trend reversals
    }
    
    /// Pre-computed DES parameters indexed by days of data
    private let desParameterLookup: [Int: DESParameters]
    
    /// Moving average window sizes for different timeframes
    private let maWindowSizes: [Int: Int]
    
    // MARK: - Pre-computed Gaussian Weights
    
    /// Gaussian kernel weights for different window sizes
    private var gaussianWeights: [Int: [Double]] = [:]
    
    /// Exponential decay weights for smoothing
    private var exponentialWeights: [Int: [Double]] = [:]
    
    // MARK: - Pre-computed Interpolation Tables
    
    /// Catmull-Rom spline coefficients (4-point interpolation)
    struct SplineCoefficients {
        let a: Double
        let b: Double
        let c: Double
        let d: Double
    }
    
    /// Pre-computed Catmull-Rom coefficients for 100 t-values (0.00 to 0.99)
    private let catmullRomCoefficients: [[SplineCoefficients]]
    
    // MARK: - Initialization
    
    private init() {
        // Pre-compute DES parameters for 1-365 days of data
        var desParams: [Int: DESParameters] = [:]
        
        // Short term (1-7 days): More responsive
        for days in 1...7 {
            desParams[days] = DESParameters(alpha: 0.8, beta: 0.3, turningDamping: 0.7)
        }
        
        // Medium term (8-30 days): Balanced
        for days in 8...30 {
            let alphaDecay = 0.8 - (Double(days - 7) / 23.0) * 0.3  // 0.8 -> 0.5
            let betaDecay = 0.3 - (Double(days - 7) / 23.0) * 0.15  // 0.3 -> 0.15
            desParams[days] = DESParameters(alpha: alphaDecay, beta: betaDecay, turningDamping: 0.6)
        }
        
        // Long term (31-90 days): Smoother
        for days in 31...90 {
            let alphaDecay = 0.5 - (Double(days - 30) / 60.0) * 0.2  // 0.5 -> 0.3
            let betaDecay = 0.15 - (Double(days - 30) / 60.0) * 0.05  // 0.15 -> 0.1
            desParams[days] = DESParameters(alpha: alphaDecay, beta: betaDecay, turningDamping: 0.5)
        }
        
        // Very long term (91-365 days): Very smooth
        for days in 91...365 {
            let alphaDecay = 0.3 - (Double(days - 90) / 275.0) * 0.1  // 0.3 -> 0.2
            desParams[days] = DESParameters(alpha: alphaDecay, beta: 0.08, turningDamping: 0.4)
        }
        
        // Beyond 365 days
        for days in 366...1000 {
            desParams[days] = DESParameters(alpha: 0.2, beta: 0.05, turningDamping: 0.3)
        }
        
        self.desParameterLookup = desParams
        
        // Pre-compute MA window sizes
        var maWindows: [Int: Int] = [:]
        maWindows[7] = 3      // 1 week: 3-day MA
        maWindows[30] = 5     // 1 month: 5-day MA
        maWindows[90] = 7     // 3 months: 7-day MA
        maWindows[365] = 14   // 1 year: 14-day MA
        maWindows[1000] = 21  // All time: 21-day MA
        self.maWindowSizes = maWindows
        
        // Pre-compute Gaussian weights for common window sizes
        for windowSize in [3, 5, 7, 9, 11, 14, 21] {
            gaussianWeights[windowSize] = Self.computeGaussianWeights(windowSize: windowSize)
        }
        
        // Pre-compute exponential weights
        for windowSize in [3, 5, 7, 10, 14, 21, 30] {
            exponentialWeights[windowSize] = Self.computeExponentialWeights(windowSize: windowSize)
        }
        
        // Pre-compute Catmull-Rom coefficients for 100 t-values
        var splineCoeffs: [[SplineCoefficients]] = []
        for tIndex in 0..<100 {
            let t = Double(tIndex) / 100.0
            let t2 = t * t
            let t3 = t2 * t
            
            // Catmull-Rom basis functions
            let coeffs = SplineCoefficients(
                a: -0.5 * t3 + t2 - 0.5 * t,
                b: 1.5 * t3 - 2.5 * t2 + 1.0,
                c: -1.5 * t3 + 2.0 * t2 + 0.5 * t,
                d: 0.5 * t3 - 0.5 * t2
            )
            splineCoeffs.append([coeffs])
        }
        self.catmullRomCoefficients = splineCoeffs
    }
    
    // MARK: - Static Computation Helpers
    
    private static func computeGaussianWeights(windowSize: Int) -> [Double] {
        let sigma = Double(windowSize) / 4.0
        let center = Double(windowSize - 1) / 2.0
        
        var weights: [Double] = []
        var sum = 0.0
        
        for i in 0..<windowSize {
            let x = Double(i) - center
            let weight = exp(-(x * x) / (2 * sigma * sigma))
            weights.append(weight)
            sum += weight
        }
        
        // Normalize weights to sum to 1
        return weights.map { $0 / sum }
    }
    
    private static func computeExponentialWeights(windowSize: Int) -> [Double] {
        let decay = 2.0 / Double(windowSize + 1)
        
        var weights: [Double] = []
        var sum = 0.0
        
        for i in 0..<windowSize {
            let weight = pow(1 - decay, Double(windowSize - 1 - i))
            weights.append(weight)
            sum += weight
        }
        
        // Normalize
        return weights.map { $0 / sum }
    }
    
    // MARK: - Public Access Methods
    
    /// Get DES parameters for a given number of data days
    func getDESParameters(forDays days: Int) -> DESParameters {
        let clampedDays = max(1, min(days, 1000))
        return desParameterLookup[clampedDays] ?? DESParameters(alpha: 0.3, beta: 0.1, turningDamping: 0.5)
    }
    
    /// Get moving average window size for timeframe
    func getMAWindowSize(forDays days: Int) -> Int {
        if days <= 7 { return maWindowSizes[7]! }
        if days <= 30 { return maWindowSizes[30]! }
        if days <= 90 { return maWindowSizes[90]! }
        if days <= 365 { return maWindowSizes[365]! }
        return maWindowSizes[1000]!
    }
    
    /// Get pre-computed Gaussian weights for a window size
    func getGaussianWeights(windowSize: Int) -> [Double] {
        if let weights = gaussianWeights[windowSize] {
            return weights
        }
        // Compute on-demand if not pre-cached
        let weights = Self.computeGaussianWeights(windowSize: windowSize)
        gaussianWeights[windowSize] = weights
        return weights
    }
    
    /// Get pre-computed exponential weights
    func getExponentialWeights(windowSize: Int) -> [Double] {
        if let weights = exponentialWeights[windowSize] {
            return weights
        }
        let weights = Self.computeExponentialWeights(windowSize: windowSize)
        exponentialWeights[windowSize] = weights
        return weights
    }
    
    /// Get Catmull-Rom coefficients for interpolation
    func getCatmullRomCoefficients(t: Double) -> SplineCoefficients {
        let tClamped = max(0, min(t, 0.99))
        let index = Int(tClamped * 100)
        return catmullRomCoefficients[index][0]
    }
    
    /// Apply Catmull-Rom interpolation using pre-computed coefficients
    func catmullRomInterpolate(p0: Double, p1: Double, p2: Double, p3: Double, t: Double) -> Double {
        let coeffs = getCatmullRomCoefficients(t: t)
        return coeffs.a * p0 + coeffs.b * p1 + coeffs.c * p2 + coeffs.d * p3
    }
    
    // MARK: - Fast Smoothing Methods
    
    /// Apply weighted moving average using pre-computed Gaussian weights
    func gaussianSmooth(_ values: [Double], windowSize: Int) -> [Double] {
        guard values.count > 1 else { return values }
        
        let weights = getGaussianWeights(windowSize: windowSize)
        let halfWindow = windowSize / 2
        var result: [Double] = []
        result.reserveCapacity(values.count)
        
        for i in 0..<values.count {
            var sum = 0.0
            var weightSum = 0.0
            
            for (j, weight) in weights.enumerated() {
                let index = i - halfWindow + j
                if index >= 0 && index < values.count {
                    sum += values[index] * weight
                    weightSum += weight
                }
            }
            
            result.append(weightSum > 0 ? sum / weightSum : values[i])
        }
        
        return result
    }
    
    /// Apply exponential smoothing using pre-computed weights
    func exponentialSmooth(_ values: [Double], windowSize: Int) -> [Double] {
        guard values.count > 1 else { return values }
        
        let weights = getExponentialWeights(windowSize: windowSize)
        var result: [Double] = []
        result.reserveCapacity(values.count)
        
        for i in 0..<values.count {
            var sum = 0.0
            var weightSum = 0.0
            
            let startIndex = max(0, i - windowSize + 1)
            for j in startIndex...i {
                let weightIndex = j - startIndex
                if weightIndex < weights.count {
                    sum += values[j] * weights[weightIndex]
                    weightSum += weights[weightIndex]
                }
            }
            
            result.append(weightSum > 0 ? sum / weightSum : values[i])
        }
        
        return result
    }
    
    /// Fast Double Exponential Smoothing with pre-computed parameters
    func doubleExponentialSmooth(_ values: [Double], days: Int) -> [Double] {
        guard values.count > 1 else { return values }
        
        let params = getDESParameters(forDays: days)
        var result: [Double] = []
        result.reserveCapacity(values.count)
        
        var level = values[0]
        var trend = values.count > 1 ? values[1] - values[0] : 0
        
        result.append(level)
        
        for i in 1..<values.count {
            let prevLevel = level
            level = params.alpha * values[i] + (1 - params.alpha) * (level + trend)
            
            let newTrend = params.beta * (level - prevLevel) + (1 - params.beta) * trend
            
            // Apply turning damping if trend direction changed
            if trend * newTrend < 0 {
                trend = newTrend * params.turningDamping
            } else {
                trend = newTrend
            }
            
            result.append(level)
        }
        
        return result
    }
}
