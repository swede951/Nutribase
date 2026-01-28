import SwiftUI

/// Bundled chart animation assets and pre-computed animation curves.
/// Provides smooth, consistent animations across all chart views.
class ChartAnimationAssets {
    static let shared = ChartAnimationAssets()
    
    // MARK: - Pre-computed Animation Curves
    
    /// Pre-computed easing curve values (100 steps from 0 to 1)
    struct AnimationCurve {
        let name: String
        let values: [Double]  // 100 pre-computed values
        
        /// Get interpolated value for any progress (0-1)
        func value(at progress: Double) -> Double {
            let clamped = max(0, min(progress, 1))
            let index = Int(clamped * 99)
            return values[min(index, 99)]
        }
    }
    
    /// Standard easing curves
    let easeIn: AnimationCurve
    let easeOut: AnimationCurve
    let easeInOut: AnimationCurve
    let spring: AnimationCurve
    let bounce: AnimationCurve
    
    /// Chart-specific animation curves
    let barGrow: AnimationCurve      // For bar chart animations
    let lineReveal: AnimationCurve   // For line chart drawing
    let fadeIn: AnimationCurve       // For opacity animations
    let scaleUp: AnimationCurve      // For scale animations
    
    // MARK: - Pre-computed Keyframe Sequences
    
    /// Keyframe data for complex animations
    struct KeyframeSequence {
        let keyframes: [(time: Double, value: Double)]
        let duration: TimeInterval
        
        /// Get interpolated value at a specific time
        func value(at time: Double) -> Double {
            guard !keyframes.isEmpty else { return 0 }
            
            let normalizedTime = time / duration
            
            // Find surrounding keyframes
            var prevKeyframe = keyframes[0]
            var nextKeyframe = keyframes.last!
            
            for keyframe in keyframes {
                if keyframe.time <= normalizedTime {
                    prevKeyframe = keyframe
                } else {
                    nextKeyframe = keyframe
                    break
                }
            }
            
            // Interpolate between keyframes
            let timeDiff = nextKeyframe.time - prevKeyframe.time
            if timeDiff <= 0 {
                return prevKeyframe.value
            }
            
            let progress = (normalizedTime - prevKeyframe.time) / timeDiff
            return prevKeyframe.value + (nextKeyframe.value - prevKeyframe.value) * progress
        }
    }
    
    /// Pre-computed keyframe sequences for common animations
    let barAppearSequence: KeyframeSequence
    let chartLoadSequence: KeyframeSequence
    let valueCountUpSequence: KeyframeSequence
    let pulseSequence: KeyframeSequence
    
    // MARK: - Staggered Animation Helpers
    
    /// Pre-computed stagger delays for 7-day charts
    let weeklyStaggerDelays: [TimeInterval]
    
    /// Pre-computed stagger delays for 31-day charts
    let monthlyStaggerDelays: [TimeInterval]
    
    // MARK: - Animation Durations
    
    /// Standard animation durations
    struct Durations {
        static let instant: TimeInterval = 0.1
        static let fast: TimeInterval = 0.2
        static let normal: TimeInterval = 0.3
        static let slow: TimeInterval = 0.5
        static let verySlow: TimeInterval = 0.8
        
        // Chart-specific durations
        static let barGrow: TimeInterval = 0.4
        static let lineReveal: TimeInterval = 0.6
        static let chartLoad: TimeInterval = 0.5
        static let tooltipAppear: TimeInterval = 0.15
        static let cardTransition: TimeInterval = 0.25
    }
    
    // MARK: - Initialization
    
    private init() {
        // Pre-compute standard easing curves
        easeIn = Self.computeEaseInCurve()
        easeOut = Self.computeEaseOutCurve()
        easeInOut = Self.computeEaseInOutCurve()
        spring = Self.computeSpringCurve()
        bounce = Self.computeBounceCurve()
        
        // Pre-compute chart-specific curves
        barGrow = Self.computeBarGrowCurve()
        lineReveal = Self.computeLineRevealCurve()
        fadeIn = Self.computeFadeInCurve()
        scaleUp = Self.computeScaleUpCurve()
        
        // Pre-compute keyframe sequences
        barAppearSequence = Self.computeBarAppearSequence()
        chartLoadSequence = Self.computeChartLoadSequence()
        valueCountUpSequence = Self.computeValueCountUpSequence()
        pulseSequence = Self.computePulseSequence()
        
        // Pre-compute stagger delays
        weeklyStaggerDelays = (0..<7).map { Double($0) * 0.05 }
        monthlyStaggerDelays = (0..<31).map { Double($0) * 0.02 }
    }
    
    // MARK: - Curve Computation
    
    private static func computeEaseInCurve() -> AnimationCurve {
        let values = (0..<100).map { i in
            let t = Double(i) / 99.0
            return t * t * t  // Cubic ease-in
        }
        return AnimationCurve(name: "easeIn", values: values)
    }
    
    private static func computeEaseOutCurve() -> AnimationCurve {
        let values = (0..<100).map { i in
            let t = Double(i) / 99.0
            let tMinus1 = t - 1
            return tMinus1 * tMinus1 * tMinus1 + 1  // Cubic ease-out
        }
        return AnimationCurve(name: "easeOut", values: values)
    }
    
    private static func computeEaseInOutCurve() -> AnimationCurve {
        let values = (0..<100).map { i in
            let t = Double(i) / 99.0
            if t < 0.5 {
                return 4 * t * t * t
            } else {
                let f = 2 * t - 2
                return 0.5 * f * f * f + 1
            }
        }
        return AnimationCurve(name: "easeInOut", values: values)
    }
    
    private static func computeSpringCurve() -> AnimationCurve {
        let values = (0..<100).map { i in
            let t = Double(i) / 99.0
            let damping = 0.8
            let omega = 10.0
            return 1 - exp(-damping * omega * t) * cos(omega * sqrt(1 - damping * damping) * t)
        }
        return AnimationCurve(name: "spring", values: values)
    }
    
    private static func computeBounceCurve() -> AnimationCurve {
        let values = (0..<100).map { i in
            let t = Double(i) / 99.0
            if t < 0.36364 {
                return 7.5625 * t * t
            } else if t < 0.72727 {
                let adjusted = t - 0.54545
                return 7.5625 * adjusted * adjusted + 0.75
            } else if t < 0.90909 {
                let adjusted = t - 0.81818
                return 7.5625 * adjusted * adjusted + 0.9375
            } else {
                let adjusted = t - 0.95454
                return 7.5625 * adjusted * adjusted + 0.984375
            }
        }
        return AnimationCurve(name: "bounce", values: values)
    }
    
    private static func computeBarGrowCurve() -> AnimationCurve {
        // Slightly overshoot then settle
        let values = (0..<100).map { i in
            let t = Double(i) / 99.0
            let overshoot = 1.1
            if t < 0.7 {
                // Grow phase with overshoot
                let progress = t / 0.7
                return (1 + (overshoot - 1) * sin(progress * .pi / 2)) * progress
            } else {
                // Settle phase
                let settleProgress = (t - 0.7) / 0.3
                return overshoot - (overshoot - 1) * settleProgress
            }
        }
        return AnimationCurve(name: "barGrow", values: values)
    }
    
    private static func computeLineRevealCurve() -> AnimationCurve {
        // Smooth reveal for line drawing
        let values = (0..<100).map { i in
            let t = Double(i) / 99.0
            // Ease out quart
            let tMinus1 = t - 1
            return 1 - tMinus1 * tMinus1 * tMinus1 * tMinus1
        }
        return AnimationCurve(name: "lineReveal", values: values)
    }
    
    private static func computeFadeInCurve() -> AnimationCurve {
        // Quick fade-in with slight ease
        let values = (0..<100).map { i in
            let t = Double(i) / 99.0
            return t * (2 - t)  // Ease-out quad
        }
        return AnimationCurve(name: "fadeIn", values: values)
    }
    
    private static func computeScaleUpCurve() -> AnimationCurve {
        // Pop-in effect
        let values = (0..<100).map { i in
            let t = Double(i) / 99.0
            let overshoot = 0.1
            if t < 0.8 {
                let progress = t / 0.8
                return (1 + overshoot) * (1 - pow(1 - progress, 3))
            } else {
                let settleProgress = (t - 0.8) / 0.2
                return (1 + overshoot) - overshoot * settleProgress
            }
        }
        return AnimationCurve(name: "scaleUp", values: values)
    }
    
    // MARK: - Keyframe Sequence Computation
    
    private static func computeBarAppearSequence() -> KeyframeSequence {
        return KeyframeSequence(
            keyframes: [
                (time: 0.0, value: 0.0),
                (time: 0.3, value: 0.6),
                (time: 0.5, value: 0.9),
                (time: 0.7, value: 1.05),
                (time: 1.0, value: 1.0)
            ],
            duration: 0.4
        )
    }
    
    private static func computeChartLoadSequence() -> KeyframeSequence {
        return KeyframeSequence(
            keyframes: [
                (time: 0.0, value: 0.0),
                (time: 0.2, value: 0.3),
                (time: 0.4, value: 0.6),
                (time: 0.6, value: 0.85),
                (time: 0.8, value: 0.95),
                (time: 1.0, value: 1.0)
            ],
            duration: 0.5
        )
    }
    
    private static func computeValueCountUpSequence() -> KeyframeSequence {
        return KeyframeSequence(
            keyframes: [
                (time: 0.0, value: 0.0),
                (time: 0.3, value: 0.5),
                (time: 0.6, value: 0.8),
                (time: 0.8, value: 0.95),
                (time: 1.0, value: 1.0)
            ],
            duration: 0.6
        )
    }
    
    private static func computePulseSequence() -> KeyframeSequence {
        return KeyframeSequence(
            keyframes: [
                (time: 0.0, value: 1.0),
                (time: 0.25, value: 1.15),
                (time: 0.5, value: 1.0),
                (time: 0.75, value: 1.1),
                (time: 1.0, value: 1.0)
            ],
            duration: 0.8
        )
    }
    
    // MARK: - Public Methods
    
    /// Get stagger delay for bar at index
    func staggerDelay(forBarIndex index: Int, total: Int) -> TimeInterval {
        if total <= 7 {
            return weeklyStaggerDelays[min(index, 6)]
        } else {
            return monthlyStaggerDelays[min(index, 30)]
        }
    }
    
    /// Get animation value for bar growth at progress
    func barGrowthValue(at progress: Double) -> Double {
        return barGrow.value(at: progress)
    }
    
    /// Get animation value for line reveal at progress
    func lineRevealValue(at progress: Double) -> Double {
        return lineReveal.value(at: progress)
    }
    
    /// Get SwiftUI Animation for chart transitions
    func chartTransitionAnimation() -> Animation {
        return .easeInOut(duration: Durations.cardTransition)
    }
    
    /// Get SwiftUI Animation for bar appearance
    func barAppearAnimation(delay: TimeInterval = 0) -> Animation {
        return .spring(response: 0.4, dampingFraction: 0.7).delay(delay)
    }
    
    /// Get SwiftUI Animation for value changes
    func valueChangeAnimation() -> Animation {
        return .easeOut(duration: Durations.fast)
    }
    
    // MARK: - Cache Stats
    
    func getCacheStats() -> String {
        return """
        📊 ChartAnimationAssets Stats:
        - Standard curves: 5
        - Chart-specific curves: 4
        - Keyframe sequences: 4
        - Weekly stagger delays: \(weeklyStaggerDelays.count)
        - Monthly stagger delays: \(monthlyStaggerDelays.count)
        """
    }
}

// MARK: - SwiftUI Animation Extensions

extension Animation {
    /// Pre-configured bar chart animation
    static var barChart: Animation {
        ChartAnimationAssets.shared.barAppearAnimation()
    }
    
    /// Pre-configured chart transition
    static var chartTransition: Animation {
        ChartAnimationAssets.shared.chartTransitionAnimation()
    }
    
    /// Pre-configured value change animation
    static var valueChange: Animation {
        ChartAnimationAssets.shared.valueChangeAnimation()
    }
}

// MARK: - Animated Value View

/// View that animates a numeric value with pre-computed easing
struct AnimatedValueView: View {
    let value: Double
    let format: String
    let duration: TimeInterval
    
    @State private var displayValue: Double = 0
    @State private var animationProgress: Double = 0
    
    private let animationAssets = ChartAnimationAssets.shared
    
    init(value: Double, format: String = "%.0f", duration: TimeInterval = 0.6) {
        self.value = value
        self.format = format
        self.duration = duration
    }
    
    var body: some View {
        Text(String(format: format, displayValue))
            .onAppear {
                animateValue()
            }
            .onChange(of: value) { _, newValue in
                animateValue()
            }
    }
    
    private func animateValue() {
        let startValue = displayValue
        let targetValue = value
        let startTime = Date()
        
        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / duration, 1.0)
            
            let easedProgress = animationAssets.easeOut.value(at: progress)
            displayValue = startValue + (targetValue - startValue) * easedProgress
            
            if progress >= 1.0 {
                timer.invalidate()
                displayValue = targetValue
            }
        }
    }
}
