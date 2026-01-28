import SwiftUI
import UIKit

/// Pre-rendered chart frame assets for faster chart rendering.
/// Caches commonly used chart backgrounds, frames, and decorative elements.
class ChartFrameAssets {
    static let shared = ChartFrameAssets()
    
    // MARK: - Pre-rendered Images
    
    /// Cached chart background images by size
    private var backgroundCache: [String: UIImage] = [:]
    
    /// Cached grid images by configuration
    private var gridCache: [String: UIImage] = [:]
    
    /// Cached shadow images
    private var shadowCache: [String: UIImage] = [:]
    
    /// Cached gradient images
    private var gradientCache: [String: UIImage] = [:]
    
    // MARK: - Pre-computed Colors
    
    /// Commonly used chart colors
    struct ChartColors {
        static let calories = UIColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0)
        static let protein = UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        static let carbs = UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)
        static let fat = UIColor(red: 0.9, green: 0.3, blue: 0.5, alpha: 1.0)
        static let steps = UIColor(red: 0.21, green: 0.72, blue: 1.0, alpha: 1.0)
        static let weight = UIColor(red: 0.37, green: 0.77, blue: 1.0, alpha: 1.0)
        static let gridLine = UIColor.systemGray4
        static let gridBackground = UIColor.systemGray6
    }
    
    // MARK: - Standard Sizes
    
    /// Pre-defined chart sizes
    struct ChartSizes {
        static let dashboardCard = CGSize(width: 160, height: 80)
        static let dashboardCardLarge = CGSize(width: 340, height: 80)
        static let detailWeekly = CGSize(width: 320, height: 180)
        static let detailMonthly = CGSize(width: 320, height: 180)
        static let weightChart = CGSize(width: 340, height: 200)
    }
    
    // MARK: - Initialization
    
    private init() {
        preRenderCommonAssets()
    }
    
    /// Pre-render commonly used assets on app launch
    private func preRenderCommonAssets() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.preRenderGridBackgrounds()
            self?.preRenderShadows()
            self?.preRenderGradients()
        }
    }
    
    // MARK: - Grid Background Rendering
    
    private func preRenderGridBackgrounds() {
        // Dashboard card grid (5 horizontal lines)
        for size in [ChartSizes.dashboardCard, ChartSizes.dashboardCardLarge] {
            let key = gridKey(size: size, lines: 5)
            gridCache[key] = renderGridImage(size: size, horizontalLines: 5)
        }
        
        // Detail view grids
        let detailKey = gridKey(size: ChartSizes.detailWeekly, lines: 5)
        gridCache[detailKey] = renderGridImage(size: ChartSizes.detailWeekly, horizontalLines: 5)
    }
    
    private func renderGridImage(size: CGSize, horizontalLines: Int, verticalDivisions: Int = 0) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Draw horizontal grid lines
            ctx.setStrokeColor(ChartColors.gridLine.cgColor)
            ctx.setLineWidth(0.5)
            
            let spacing = size.height / CGFloat(horizontalLines - 1)
            for i in 0..<horizontalLines {
                let y = CGFloat(i) * spacing
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.strokePath()
            
            // Draw vertical divisions if specified
            if verticalDivisions > 0 {
                let vSpacing = size.width / CGFloat(verticalDivisions)
                for i in 1..<verticalDivisions {
                    let x = CGFloat(i) * vSpacing
                    ctx.move(to: CGPoint(x: x, y: 0))
                    ctx.addLine(to: CGPoint(x: x, y: size.height))
                }
                ctx.strokePath()
            }
        }
    }
    
    private func gridKey(size: CGSize, lines: Int) -> String {
        return "\(Int(size.width))x\(Int(size.height))_\(lines)"
    }
    
    // MARK: - Shadow Rendering
    
    private func preRenderShadows() {
        // Card shadow
        let cardShadowSize = CGSize(width: 180, height: 140)
        shadowCache["card"] = renderShadowImage(size: cardShadowSize, cornerRadius: 16, shadowRadius: 8)
        
        // Wide card shadow
        let wideCardSize = CGSize(width: 360, height: 140)
        shadowCache["wideCard"] = renderShadowImage(size: wideCardSize, cornerRadius: 16, shadowRadius: 8)
    }
    
    private func renderShadowImage(size: CGSize, cornerRadius: CGFloat, shadowRadius: CGFloat) -> UIImage {
        let totalSize = CGSize(width: size.width + shadowRadius * 4, height: size.height + shadowRadius * 4)
        let renderer = UIGraphicsImageRenderer(size: totalSize)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Shadow settings
            ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: shadowRadius, color: UIColor.black.withAlphaComponent(0.08).cgColor)
            
            // Draw rounded rect that will cast shadow
            let rect = CGRect(x: shadowRadius * 2, y: shadowRadius * 2, width: size.width, height: size.height)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            
            UIColor.white.setFill()
            path.fill()
        }
    }
    
    // MARK: - Gradient Rendering
    
    private func preRenderGradients() {
        // Progress bar gradients for each macro type
        let barSize = CGSize(width: 200, height: 8)
        
        gradientCache["calories"] = renderGradientBar(size: barSize, color: ChartColors.calories)
        gradientCache["protein"] = renderGradientBar(size: barSize, color: ChartColors.protein)
        gradientCache["carbs"] = renderGradientBar(size: barSize, color: ChartColors.carbs)
        gradientCache["fat"] = renderGradientBar(size: barSize, color: ChartColors.fat)
        gradientCache["steps"] = renderGradientBar(size: barSize, color: ChartColors.steps)
    }
    
    private func renderGradientBar(size: CGSize, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            let colors = [
                color.withAlphaComponent(0.8).cgColor,
                color.cgColor
            ] as CFArray
            
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: 0),
                options: []
            )
        }
    }
    
    // MARK: - Public Access
    
    /// Get pre-rendered grid image
    func getGridImage(size: CGSize, horizontalLines: Int = 5) -> UIImage? {
        let key = gridKey(size: size, lines: horizontalLines)
        
        if let cached = gridCache[key] {
            return cached
        }
        
        // Render on-demand if not cached
        let image = renderGridImage(size: size, horizontalLines: horizontalLines)
        gridCache[key] = image
        return image
    }
    
    /// Get pre-rendered shadow image
    func getShadowImage(type: String) -> UIImage? {
        return shadowCache[type]
    }
    
    /// Get pre-rendered gradient bar
    func getGradientBar(type: String) -> UIImage? {
        return gradientCache[type]
    }
    
    /// Get chart color for macro type
    func getChartColor(for type: String) -> UIColor {
        switch type.lowercased() {
        case "calories": return ChartColors.calories
        case "protein": return ChartColors.protein
        case "carbs", "carbohydrates": return ChartColors.carbs
        case "fat": return ChartColors.fat
        case "steps": return ChartColors.steps
        case "weight": return ChartColors.weight
        default: return ChartColors.calories
        }
    }
    
    // MARK: - Memory Management
    
    /// Clear cached assets to free memory
    func clearCache() {
        backgroundCache.removeAll()
        gridCache.removeAll()
        shadowCache.removeAll()
        gradientCache.removeAll()
    }
    
    /// Get cache statistics
    func getCacheStats() -> String {
        return """
        📊 ChartFrameAssets Stats:
        - Background images: \(backgroundCache.count)
        - Grid images: \(gridCache.count)
        - Shadow images: \(shadowCache.count)
        - Gradient images: \(gradientCache.count)
        """
    }
}

// MARK: - SwiftUI Image Extensions

extension Image {
    /// Create image from pre-rendered chart grid
    static func chartGrid(size: CGSize, lines: Int = 5) -> Image? {
        guard let uiImage = ChartFrameAssets.shared.getGridImage(size: size, horizontalLines: lines) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
    
    /// Create image from pre-rendered shadow
    static func cardShadow(wide: Bool = false) -> Image? {
        let type = wide ? "wideCard" : "card"
        guard let uiImage = ChartFrameAssets.shared.getShadowImage(type: type) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
}

// MARK: - Pre-rendered Bar Chart Component

struct PrerenderedBarBackground: View {
    let size: CGSize
    let horizontalLines: Int
    
    var body: some View {
        if let gridImage = ChartFrameAssets.shared.getGridImage(size: size, horizontalLines: horizontalLines) {
            Image(uiImage: gridImage)
                .resizable()
                .frame(width: size.width, height: size.height)
        } else {
            // Fallback to runtime rendering
            Canvas { context, canvasSize in
                context.drawHorizontalGrid(in: canvasSize, lineCount: horizontalLines)
            }
            .frame(width: size.width, height: size.height)
        }
    }
}
