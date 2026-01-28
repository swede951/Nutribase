import Foundation
import Accelerate

/// Calculator for Happy Scale–style Moving Average and Weekly Rate
///
/// **Pipeline Overview:**
/// 1. **Daily Interpolation** → Fill missing days to get a complete daily series
/// 2. **Bidirectional EMA** → Remove lag while keeping smoothness
/// 3. **Savitzky–Golay Filter** → Smooth corners for rounded curves
/// 4. **Weekly Rate** → 7-day difference of smoothed trend, then EMA smoothed
///
/// This matches Happy Scale's approach of creating a smooth, lag-free trend line
/// that responds to weight changes without being overly reactive to daily fluctuations.
final class WeightMovingAverageCalculator {
    
    /// Calculate moving averages with optional custom parameters
    /// - Parameters:
    ///   - entries: Weight log entries to process
    ///   - emaAlpha: EMA smoothing factor (default: 0.3)
    ///   - sgWindow: Savitzky-Golay window size (default: 21, 0 = skip SG)
    ///   - weeklyRateAlpha: Weekly rate EMA smoothing factor (default: 0.25)
    ///   - sgPolyOrder: Polynomial order for Savitzky-Golay (default: 3)
    /// - Returns: Processed entries with moving averages and weekly rates
    static func calculateMovingAverages(for entries: [WeightLogEntry],
                                       emaAlpha: Double = 0.3,
                                       sgWindow: Int = 21,
                                       weeklyRateAlpha: Double = 0.25,
                                       sgPolyOrder: Int = 3) -> [WeightLogEntry] {
        guard !entries.isEmpty else { return [] }
        
        // Sort: we always work oldest → newest
        let sorted = entries.sorted { $0.date < $1.date }
        let calendar = Calendar.current
        
        // STEP 1: DAILY INTERPOLATION
        // Happy Scale works on a daily timeline even if you don't weigh every day.
        // We create a full list of days and linearly interpolate missing weights.
        // This prevents gaps from causing smoothing artifacts.
        let start = calendar.startOfDay(for: sorted.first!.date)
        let end = calendar.startOfDay(for: sorted.last!.date)
        let totalDays = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        let dailyDates = (0...totalDays).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        
        // Build lookup of recorded weights by date
        var recorded: [Date: Double] = [:]
        for e in sorted {
            recorded[calendar.startOfDay(for: e.date)] = e.weight
        }
        
        var dailyWeights: [Double] = []
        for i in 0..<dailyDates.count {
            let day = dailyDates[i]
            if let w = recorded[day] {
                dailyWeights.append(w)
            } else {
                // Linear interpolation between previous and next logged weights
                var prevDate: Date? = nil
                var nextDate: Date? = nil
                var prevWeight: Double? = nil
                var nextWeight: Double? = nil
                
                for j in stride(from: i - 1, through: 0, by: -1) {
                    if let w = recorded[dailyDates[j]] {
                        prevDate = dailyDates[j]
                        prevWeight = w
                        break
                    }
                }
                for j in i + 1..<dailyDates.count {
                    if let w = recorded[dailyDates[j]] {
                        nextDate = dailyDates[j]
                        nextWeight = w
                        break
                    }
                }
                
                if let p = prevDate, let n = nextDate, let pw = prevWeight, let nw = nextWeight {
                    let daysBetween = Double(calendar.dateComponents([.day], from: p, to: n).day ?? 1)
                    let daysFromPrev = Double(calendar.dateComponents([.day], from: p, to: day).day ?? 0)
                    let t = daysFromPrev / daysBetween
                    dailyWeights.append(pw + (nw - pw) * t)
                } else if let pw = prevWeight {
                    dailyWeights.append(pw)
                } else if let nw = nextWeight {
                    dailyWeights.append(nw)
                } else {
                    dailyWeights.append(sorted.first!.weight)
                }
            }
        }
        
        // STEP 2: BIDIRECTIONAL EMA
        // Forward EMA reacts to past → present
        // Backward EMA reacts from future → present
        // Averaging them removes lag while keeping smoothness
        // α varies by timeframe (0.45 for 1W down to 0.12 for >1Y)
        let ema = bidirectionalEMA(data: dailyWeights, alpha: emaAlpha)
        
        // STEP 3: SAVITZKY–GOLAY SMOOTHING (timeframe-aware)
        // Short timeframes (1W): Skip SG entirely - EMA is enough, keep it reactive
        // Medium timeframes (1M, 3M): Light SG with small window to round corners
        // Long timeframes (1Y, >1Y): Full SG with large window for smooth curves
        let smooth: [Double]
        if sgWindow == 0 {
            // Skip SG for maximum reactivity (1W view)
            smooth = ema
        } else {
            // Apply SG with timeframe-specific window and polynomial order
            smooth = savitzkyGolayFilter(data: ema, windowSize: sgWindow, polynomialOrder: sgPolyOrder)
        }
        
        // STEP 4: WEEKLY RATE CALCULATION
        // Weekly change = change in smoothed trend over 7 days
        // This shows the rate of weight change per week
        var weeklyDelta = [Double](repeating: 0.0, count: smooth.count)
        if smooth.count > 7 {
            for i in 7..<smooth.count {
                weeklyDelta[i] = smooth[i] - smooth[i - 7]
            }
        }
        
        // Smooth the weekly rate itself (bidirectional EMA with lower alpha for steadier values)
        // α varies by timeframe (0.35 for 1W down to 0.18 for >1Y) for stable rate display
        let weeklyRate = bidirectionalEMA(data: weeklyDelta, alpha: weeklyRateAlpha)
        
        // Gentle fade only at start to avoid sharp initial values
        // (Not at end - users need accurate current rate)
        let fadedWeekly = edgeFadeStart(data: weeklyRate, fadeLength: 7)
        
        // Clip extreme values to ±5.0 kg/week (prevents unrealistic spikes)
        // Round to 1 decimal place for clean display
        let clipped = fadedWeekly.map { min(max($0, -5.0), 5.0) }
        let weeklySmoothed = clipped.map { ($0 * 10).rounded() / 10 }
        
        // STEP 5: MAP BACK TO ORIGINAL LOGGED DATES
        // We've been working with a complete daily series, but users only logged on certain days.
        // Map the smoothed values back to the dates they actually weighed in.
        var results: [WeightLogEntry] = []
        for entry in sorted {
            let day = calendar.startOfDay(for: entry.date)
            if let i = dailyDates.firstIndex(of: day) {
                let ma = (smooth[i] * 10).rounded() / 10
                var rate: Double? = nil
                if i >= 7 {
                    // weeklySmoothed is already clipped and rounded
                    rate = weeklySmoothed[i]
                }
                results.append(
                    WeightLogEntry(
                        id: entry.id,
                        date: entry.date,
                        weight: entry.weight,
                        movingAverage: ma,
                        weeklyRate: rate,
                        notes: entry.notes
                    )
                )
            }
        }
        return results
    }
    
    // MARK: - Filters
    
    private static func bidirectionalEMA(data: [Double], alpha: Double) -> [Double] {
        guard data.count > 1 else { return data }
        var fwd = [Double](repeating: 0.0, count: data.count)
        var bwd = [Double](repeating: 0.0, count: data.count)
        
        fwd[0] = data[0]
        for i in 1..<data.count {
            fwd[i] = alpha * data[i] + (1 - alpha) * fwd[i - 1]
        }
        bwd[data.count - 1] = data.last!
        for i in stride(from: data.count - 2, through: 0, by: -1) {
            bwd[i] = alpha * data[i] + (1 - alpha) * bwd[i + 1]
        }
        // True centered average
        return zip(fwd, bwd).map { ($0 + $1) / 2.0 }
    }
    
    private static func simpleEMA(data: [Double], alpha: Double) -> [Double] {
        guard !data.isEmpty else { return data }
        var out = [Double](repeating: 0.0, count: data.count)
        out[0] = data[0]
        for i in 1..<data.count {
            out[i] = alpha * data[i] + (1 - alpha) * out[i - 1]
        }
        return out
    }
    
    /// Gentle fade only at start to avoid sharp initial values (preserves current rate at end)
    private static func edgeFadeStart(data: [Double], fadeLength: Int) -> [Double] {
        guard data.count > fadeLength else { return data }
        var out = data
        for i in 0..<fadeLength {
            let weight = Double(i) / Double(fadeLength)
            out[i] *= weight
        }
        return out
    }
    
    /// Native Savitzky–Golay polynomial smoothing
    private static func savitzkyGolayFilter(data: [Double], windowSize: Int, polynomialOrder: Int) -> [Double] {
        guard data.count >= windowSize else { return data }
        precondition(windowSize % 2 == 1, "Window size must be odd")
        let half = windowSize / 2
        
        // Design matrix
        let x = (-(half)...half).map { Double($0) }
        var A = [[Double]]()
        for xi in x {
            A.append((0...polynomialOrder).map { pow(xi, Double($0)) })
        }
        
        // Compute pseudoinverse of A
        let AT = transpose(A)
        let ATA = multiply(AT, A)
        let ATAInv = invertMatrix(ATA)
        let ATAInvAT = multiply(ATAInv, AT)
        
        // First row = smoothing coefficients
        let coeffs = ATAInvAT[0]
        let norm = coeffs.reduce(0, +)
        let normalized = coeffs.map { $0 / norm }
        
        var out = [Double](repeating: 0.0, count: data.count)
        for i in 0..<data.count {
            var sum = 0.0
            for j in 0..<windowSize {
                var idx = i - half + j
                if idx < 0 { idx = 0 }
                if idx >= data.count { idx = data.count - 1 }
                sum += normalized[j] * data[idx]
            }
            out[i] = sum
        }
        return out
    }
    
    // MARK: - Matrix utilities
    
    private static func transpose(_ m: [[Double]]) -> [[Double]] {
        guard let cols = m.first?.count else { return [] }
        var result = [[Double]](repeating: [Double](repeating: 0.0, count: m.count), count: cols)
        for i in 0..<m.count {
            for j in 0..<cols {
                result[j][i] = m[i][j]
            }
        }
        return result
    }
    
    private static func multiply(_ A: [[Double]], _ B: [[Double]]) -> [[Double]] {
        var result = [[Double]](repeating: [Double](repeating: 0.0, count: B[0].count), count: A.count)
        for i in 0..<A.count {
            for j in 0..<B[0].count {
                for k in 0..<B.count {
                    result[i][j] += A[i][k] * B[k][j]
                }
            }
        }
        return result
    }
    
    // Note: Using legacy CLAPACK interface. To use new LAPACK, compile with -DACCELERATE_NEW_LAPACK
    @available(iOS, deprecated: 16.4, message: "Using legacy CLAPACK - consider migrating to new LAPACK interface")
    private static func invertMatrix(_ matrix: [[Double]]) -> [[Double]] {
        let inMatrix = matrix.flatMap { $0 }
        let n = Int32(sqrt(Double(inMatrix.count)))
        var pivots = [Int32](repeating: 0, count: Int(n))
        var workspace = [Double](repeating: 0.0, count: Int(n))
        var error: Int32 = 0
        
        var lwork = n
        var result = inMatrix
        
        // Create separate copies for each parameter to avoid overlapping access
        var n1 = n
        var n2 = n
        var n3 = n
        var n4 = n
        var n5 = n
        var _ = n
        
        // Silence deprecation warnings for legacy LAPACK functions
        withUnsafeMutablePointer(to: &n1) { n1Ptr in
            withUnsafeMutablePointer(to: &n2) { n2Ptr in
                withUnsafeMutablePointer(to: &n3) { n3Ptr in
                    withUnsafeMutablePointer(to: &n4) { n4Ptr in
                        withUnsafeMutablePointer(to: &n5) { n5Ptr in
                            withUnsafeMutablePointer(to: &lwork) { lworkPtr in
                                withUnsafeMutablePointer(to: &error) { errorPtr in
                                    result.withUnsafeMutableBufferPointer { resultPtr in
                                        pivots.withUnsafeMutableBufferPointer { pivotsPtr in
                                            workspace.withUnsafeMutableBufferPointer { workspacePtr in
                                                dgetrf_(n1Ptr, n2Ptr, resultPtr.baseAddress, n3Ptr, pivotsPtr.baseAddress, errorPtr)
                                                dgetri_(n4Ptr, resultPtr.baseAddress, n5Ptr, pivotsPtr.baseAddress, workspacePtr.baseAddress, lworkPtr, errorPtr)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        var output: [[Double]] = []
        for i in 0..<Int(n) {
            let start = i * Int(n)
            let end = start + Int(n)
            output.append(Array(result[start..<end]))
        }
        return output
    }
}

