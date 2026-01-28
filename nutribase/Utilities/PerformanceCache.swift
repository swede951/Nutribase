import SwiftUI
import UIKit

// MARK: - Performance Cache Manager
// Centralized caching system for expensive computations and rendered assets
// Size impact: ~2-3 MB for cached data structures

final class PerformanceCache {
    static let shared = PerformanceCache()
    
    // MARK: - Cached Gradient Images
    // Pre-rendered gradient images to avoid runtime gradient calculations
    private var gradientImageCache: [String: UIImage] = [:]
    private let gradientCacheLock = NSLock()
    
    // MARK: - Cached Date Formatters
    // Pre-configured formatters are expensive to create
    private(set) lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    private(set) lazy var shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    private(set) lazy var monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private(set) lazy var dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
    
    private(set) lazy var monthShortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()
    
    // MARK: - Cached Number Formatters
    private(set) lazy var weightFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    private(set) lazy var rateFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+"
        return formatter
    }()
    
    // MARK: - Calendar Cache
    private(set) lazy var calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday first
        return cal
    }()
    
    // Cached month grid calculations
    private var monthGridCache: [String: [[Date?]]] = [:]
    private let monthGridLock = NSLock()
    
    // MARK: - Phase Color Palette Cache
    private var phaseColorCache: [String: (light: UIColor, dark: UIColor)] = [:]
    private let colorCacheLock = NSLock()
    
    // Pre-computed color palettes for common phase colors
    private(set) lazy var phaseColorPalettes: [String: [CGFloat: UIColor]] = {
        var palettes: [String: [CGFloat: UIColor]] = [:]
        
        let baseColors = [
            "orange": UIColor.systemOrange,
            "blue": UIColor.systemBlue,
            "green": UIColor.systemGreen,
            "red": UIColor.systemRed,
            "purple": UIColor.systemPurple,
            "teal": UIColor.systemTeal,
            "pink": UIColor.systemPink,
            "yellow": UIColor.systemYellow
        ]
        
        for (name, color) in baseColors {
            var opacityVariants: [CGFloat: UIColor] = [:]
            for opacity in [0.1, 0.15, 0.2, 0.3, 0.5, 0.7, 1.0] as [CGFloat] {
                opacityVariants[opacity] = color.withAlphaComponent(opacity)
            }
            palettes[name] = opacityVariants
        }
        
        return palettes
    }()
    
    private init() {
        // Pre-warm caches on initialization
        preWarmCaches()
    }
    
    // MARK: - Pre-warm Caches
    private func preWarmCaches() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Pre-generate common gradient images
            self?.preGenerateGradients()
            
            // Pre-calculate current month grid
            self?.preCalculateMonthGrids()
        }
    }
    
    // MARK: - Gradient Image Generation
    private func preGenerateGradients() {
        // Weight logbook gradient (light blue)
        _ = getOrCreateGradient(
            key: "weightLogHeader_light",
            colors: [
                UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 0.7),
                UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 0.5),
                UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 0.25),
                UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 0.0)
            ],
            size: CGSize(width: 400, height: 100),
            direction: .vertical
        )
        
        // Phase card gradients for common colors
        let phaseColors: [(String, UIColor)] = [
            ("orange", .systemOrange),
            ("blue", .systemBlue),
            ("green", .systemGreen),
            ("red", .systemRed),
            ("purple", .systemPurple)
        ]
        
        for (name, color) in phaseColors {
            _ = getOrCreateGradient(
                key: "phaseCard_\(name)",
                colors: [
                    color.withAlphaComponent(0.3),
                    color.withAlphaComponent(0.15)
                ],
                size: CGSize(width: 400, height: 200),
                direction: .vertical
            )
        }
    }
    
    // MARK: - Pre-calculate Month Grids
    private func preCalculateMonthGrids() {
        let now = Date()
        
        // Pre-calculate grids for -6 to +6 months
        for offset in -6...6 {
            if let monthDate = calendar.date(byAdding: .month, value: offset, to: now) {
                _ = getMonthGrid(for: monthDate)
            }
        }
    }
    
    // MARK: - Public API: Gradient Images
    enum GradientDirection {
        case vertical
        case horizontal
    }
    
    func getOrCreateGradient(key: String, colors: [UIColor], size: CGSize, direction: GradientDirection) -> UIImage {
        gradientCacheLock.lock()
        defer { gradientCacheLock.unlock() }
        
        if let cached = gradientImageCache[key] {
            return cached
        }
        
        let image = createGradientImage(colors: colors, size: size, direction: direction)
        gradientImageCache[key] = image
        return image
    }
    
    private func createGradientImage(colors: [UIColor], size: CGSize, direction: GradientDirection) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgColors = colors.map { $0.cgColor }
            
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: cgColors as CFArray,
                locations: nil
            ) else { return }
            
            let startPoint: CGPoint
            let endPoint: CGPoint
            
            switch direction {
            case .vertical:
                startPoint = CGPoint(x: size.width / 2, y: 0)
                endPoint = CGPoint(x: size.width / 2, y: size.height)
            case .horizontal:
                startPoint = CGPoint(x: 0, y: size.height / 2)
                endPoint = CGPoint(x: size.width, y: size.height / 2)
            }
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: startPoint,
                end: endPoint,
                options: []
            )
        }
    }
    
    // MARK: - Public API: Month Grid
    func getMonthGrid(for month: Date) -> [[Date?]] {
        let key = monthYearFormatter.string(from: month)
        
        monthGridLock.lock()
        defer { monthGridLock.unlock() }
        
        if let cached = monthGridCache[key] {
            return cached
        }
        
        let grid = calculateMonthGrid(for: month)
        monthGridCache[key] = grid
        return grid
    }
    
    private func calculateMonthGrid(for month: Date) -> [[Date?]] {
        guard let monthRange = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.dateInterval(of: .month, for: month)?.start else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let numberOfEmptySlots = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        var days: [Date?] = Array(repeating: nil, count: numberOfEmptySlots)
        
        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        // Pad to complete weeks (6 rows max)
        while days.count < 42 {
            days.append(nil)
        }
        
        // Convert to 2D array (6 weeks x 7 days)
        var weeks: [[Date?]] = []
        for i in stride(from: 0, to: 42, by: 7) {
            weeks.append(Array(days[i..<min(i+7, days.count)]))
        }
        
        return weeks
    }
    
    // MARK: - Public API: Formatted Strings (Cached)
    func formatWeight(_ weight: Double) -> String {
        return weightFormatter.string(from: NSNumber(value: weight)) ?? String(format: "%.1f", weight)
    }
    
    func formatRate(_ rate: Double) -> String {
        return rateFormatter.string(from: NSNumber(value: rate)) ?? String(format: "%+.1f", rate)
    }
    
    func formatDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }
    
    func formatShortDate(_ date: Date) -> String {
        return shortDateFormatter.string(from: date)
    }
    
    func formatMonthYear(_ date: Date) -> String {
        return monthYearFormatter.string(from: date)
    }
    
    func formatDayOfWeek(_ date: Date) -> String {
        return dayOfWeekFormatter.string(from: date)
    }
    
    // MARK: - Memory Management
    func clearCaches() {
        gradientCacheLock.lock()
        gradientImageCache.removeAll()
        gradientCacheLock.unlock()
        
        monthGridLock.lock()
        monthGridCache.removeAll()
        monthGridLock.unlock()
        
        colorCacheLock.lock()
        phaseColorCache.removeAll()
        colorCacheLock.unlock()
    }
    
    func handleMemoryWarning() {
        // Clear less critical caches
        monthGridLock.lock()
        monthGridCache.removeAll()
        monthGridLock.unlock()
    }
}

// MARK: - SwiftUI Gradient Image View
struct CachedGradientView: View {
    let gradientKey: String
    let colors: [Color]
    let size: CGSize
    let direction: PerformanceCache.GradientDirection
    
    var body: some View {
        let uiColors = colors.map { UIColor($0) }
        let image = PerformanceCache.shared.getOrCreateGradient(
            key: gradientKey,
            colors: uiColors,
            size: size,
            direction: direction
        )
        
        Image(uiImage: image)
            .resizable()
    }
}

// MARK: - Pre-rendered Row Cell View
struct CachedWeightRowView: View {
    let entry: WeightLogEntry
    let showMovingAverage: Bool
    let showWeeklyRate: Bool
    
    // Use cached formatters
    private let cache = PerformanceCache.shared
    
    var body: some View {
        HStack(alignment: .center) {
            // Date column - use cached formatter
            VStack(alignment: .leading, spacing: 2) {
                Text(cache.formatShortDate(entry.date))
                    .font(.system(size: 18, weight: .medium))
                Text(cache.formatDayOfWeek(entry.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 40, alignment: .leading)
            
            // Recorded weight - use cached formatter
            Text(cache.formatWeight(entry.weight))
                .font(.system(size: 18, weight: .medium))
                .frame(width: 88, alignment: .center)
            
            // Moving average
            if showMovingAverage {
                Text(cache.formatWeight(entry.movingAverage))
                    .font(.system(size: 18, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            // Weekly rate
            if showWeeklyRate {
                weeklyRateView
            }
        }
    }
    
    @ViewBuilder
    private var weeklyRateView: some View {
        if let weeklyRate = entry.weeklyRate, abs(weeklyRate) > 0.05 {
            let isDecreasing = weeklyRate < 0
            let rateColor = isDecreasing ? Color(hex: "#35b8ff") : Color(hex: "#FF9500")
            
            HStack(spacing: 2) {
                Image(systemName: isDecreasing ? "arrow.down" : "arrow.up")
                    .foregroundColor(rateColor)
                    .font(.caption)
                
                Text(cache.formatWeight(abs(weeklyRate)))
                    .foregroundColor(rateColor)
                    .font(.system(size: 18, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(rateColor.opacity(0.1))
            )
            .frame(minWidth: 70, maxWidth: .infinity, alignment: .center)
        } else {
            Text("-")
                .foregroundColor(.secondary)
                .frame(minWidth: 70, maxWidth: .infinity, alignment: .center)
        }
    }
}
