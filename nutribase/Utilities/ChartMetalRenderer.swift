import SwiftUI
import MetalKit
import simd

// MARK: - Metal Chart Renderer
// GPU-accelerated chart rendering for weight trend visualization
// Size impact: ~0.5-1 MB for Metal shaders and compiled pipelines

final class ChartMetalRenderer {
    static let shared = ChartMetalRenderer()
    
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var isInitialized = false
    
    // Pre-compiled vertex data for common chart sizes
    private var cachedVertexBuffers: [String: MTLBuffer] = [:]
    
    private init() {
        initializeMetal()
    }
    
    private func initializeMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("[ChartMetalRenderer] Metal not supported on this device")
            return
        }
        
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        
        // Create shader library
        guard let library = device.makeDefaultLibrary() else {
            print("[ChartMetalRenderer] Failed to create Metal library, using fallback")
            return
        }
        
        // Try to load shaders, fall back gracefully if not found
        let vertexFunction = library.makeFunction(name: "chartVertexShader")
        let fragmentFunction = library.makeFunction(name: "chartFragmentShader")
        
        if vertexFunction != nil && fragmentFunction != nil {
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
                isInitialized = true
                print("[ChartMetalRenderer] Metal pipeline initialized successfully")
            } catch {
                print("[ChartMetalRenderer] Failed to create pipeline state: \(error)")
            }
        }
    }
    
    // MARK: - Chart Data Processing (CPU-optimized fallback)
    
    struct ChartPoint {
        let x: Float
        let y: Float
        let color: SIMD4<Float>
    }
    
    // Pre-calculate chart vertices for performance
    func preCalculateChartVertices(
        dataPoints: [(date: Date, weight: Double)],
        bounds: CGRect,
        minWeight: Double,
        maxWeight: Double
    ) -> [ChartPoint] {
        guard dataPoints.count >= 2 else { return [] }
        
        let width = Float(bounds.width)
        let height = Float(bounds.height)
        let padding: Float = 20
        
        let weightRange = maxWeight - minWeight
        let timeRange = dataPoints.last!.date.timeIntervalSince(dataPoints.first!.date)
        
        var points: [ChartPoint] = []
        
        for (index, dataPoint) in dataPoints.enumerated() {
            let timeOffset = dataPoint.date.timeIntervalSince(dataPoints.first!.date)
            
            let x = padding + Float(timeOffset / timeRange) * (width - 2 * padding)
            let normalizedY = Float((dataPoint.weight - minWeight) / weightRange)
            let y = height - padding - normalizedY * (height - 2 * padding)
            
            // Blue color for weight line
            let color = SIMD4<Float>(0.21, 0.72, 1.0, 1.0)
            
            points.append(ChartPoint(x: x, y: y, color: color))
        }
        
        return points
    }
    
    // Pre-calculate projection line vertices
    func preCalculateProjectionVertices(
        startPoint: (date: Date, weight: Double),
        projectedWeight: Double,
        endDate: Date,
        bounds: CGRect,
        minWeight: Double,
        maxWeight: Double
    ) -> [ChartPoint] {
        let width = Float(bounds.width)
        let height = Float(bounds.height)
        let padding: Float = 20
        
        let weightRange = maxWeight - minWeight
        let timeRange = endDate.timeIntervalSince(startPoint.date)
        
        guard timeRange > 0 else { return [] }
        
        var points: [ChartPoint] = []
        
        // Start point
        let startY = Float((startPoint.weight - minWeight) / weightRange)
        points.append(ChartPoint(
            x: padding,
            y: height - padding - startY * (height - 2 * padding),
            color: SIMD4<Float>(1.0, 0.58, 0.0, 1.0) // Orange for projection
        ))
        
        // End point
        let endY = Float((projectedWeight - minWeight) / weightRange)
        points.append(ChartPoint(
            x: width - padding,
            y: height - padding - endY * (height - 2 * padding),
            color: SIMD4<Float>(1.0, 0.58, 0.0, 1.0)
        ))
        
        return points
    }
    
    // MARK: - Memory Management
    func clearBuffers() {
        cachedVertexBuffers.removeAll()
    }
}

// MARK: - Optimized Chart Path Builder
struct OptimizedChartPath {
    // Pre-calculate smooth curve control points using Catmull-Rom splines
    static func createSmoothPath(
        points: [CGPoint],
        tension: CGFloat = 0.5
    ) -> Path {
        guard points.count >= 2 else { return Path() }
        
        var path = Path()
        path.move(to: points[0])
        
        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }
        
        // Use pre-calculated Catmull-Rom spline for smooth curves
        for i in 0..<(points.count - 1) {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i < points.count - 2 ? points[i + 2] : p2
            
            // Calculate control points
            let d1 = sqrt(pow(p1.x - p0.x, 2) + pow(p1.y - p0.y, 2))
            let d2 = sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
            let d3 = sqrt(pow(p3.x - p2.x, 2) + pow(p3.y - p2.y, 2))
            
            let b1 = d1 == 0 ? p1 : CGPoint(
                x: p1.x + (p2.x - p0.x) * tension * d2 / (d1 + d2) / 3,
                y: p1.y + (p2.y - p0.y) * tension * d2 / (d1 + d2) / 3
            )
            
            let b2 = d3 == 0 ? p2 : CGPoint(
                x: p2.x - (p3.x - p1.x) * tension * d2 / (d2 + d3) / 3,
                y: p2.y - (p3.y - p1.y) * tension * d2 / (d2 + d3) / 3
            )
            
            path.addCurve(to: p2, control1: b1, control2: b2)
        }
        
        return path
    }
    
    // Optimized line path for dashed lines (goal, projection)
    static func createDashedLinePath(
        from start: CGPoint,
        to end: CGPoint,
        dashLength: CGFloat = 8,
        gapLength: CGFloat = 4
    ) -> Path {
        var path = Path()
        
        let totalLength = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2))
        let direction = CGPoint(
            x: (end.x - start.x) / totalLength,
            y: (end.y - start.y) / totalLength
        )
        
        var currentLength: CGFloat = 0
        var isDrawing = true
        
        while currentLength < totalLength {
            let segmentLength = isDrawing ? dashLength : gapLength
            let nextLength = min(currentLength + segmentLength, totalLength)
            
            if isDrawing {
                let startPoint = CGPoint(
                    x: start.x + direction.x * currentLength,
                    y: start.y + direction.y * currentLength
                )
                let endPoint = CGPoint(
                    x: start.x + direction.x * nextLength,
                    y: start.y + direction.y * nextLength
                )
                
                path.move(to: startPoint)
                path.addLine(to: endPoint)
            }
            
            currentLength = nextLength
            isDrawing.toggle()
        }
        
        return path
    }
}

// MARK: - Cached Chart View
struct CachedChartView: View {
    let dataPoints: [(date: Date, weight: Double)]
    let projectedWeight: Double?
    let goalWeight: Double?
    let minWeight: Double
    let maxWeight: Double
    
    @State private var chartSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let bounds = CGRect(origin: .zero, size: size)
                let padding: CGFloat = 20
                
                guard dataPoints.count >= 2 else { return }
                
                let weightRange = maxWeight - minWeight
                let timeRange = dataPoints.last!.date.timeIntervalSince(dataPoints.first!.date)
                
                guard weightRange > 0 && timeRange > 0 else { return }
                
                // Convert data points to CGPoints
                let points: [CGPoint] = dataPoints.map { dataPoint in
                    let timeOffset = dataPoint.date.timeIntervalSince(dataPoints.first!.date)
                    let x = padding + CGFloat(timeOffset / timeRange) * (size.width - 2 * padding)
                    let normalizedY = CGFloat((dataPoint.weight - minWeight) / weightRange)
                    let y = size.height - padding - normalizedY * (size.height - 2 * padding)
                    return CGPoint(x: x, y: y)
                }
                
                // Draw goal line if present
                if let goal = goalWeight {
                    let goalY = size.height - padding - CGFloat((goal - minWeight) / weightRange) * (size.height - 2 * padding)
                    let goalPath = OptimizedChartPath.createDashedLinePath(
                        from: CGPoint(x: padding, y: goalY),
                        to: CGPoint(x: size.width - padding, y: goalY)
                    )
                    context.stroke(goalPath, with: .color(.gray), lineWidth: 1.5)
                }
                
                // Draw projection line if present
                if let projected = projectedWeight, let lastPoint = points.last {
                    let projectedY = size.height - padding - CGFloat((projected - minWeight) / weightRange) * (size.height - 2 * padding)
                    let projectionPath = OptimizedChartPath.createDashedLinePath(
                        from: lastPoint,
                        to: CGPoint(x: size.width - padding, y: projectedY),
                        dashLength: 6,
                        gapLength: 3
                    )
                    context.stroke(projectionPath, with: .color(.orange), lineWidth: 2)
                }
                
                // Draw main weight line
                let mainPath = OptimizedChartPath.createSmoothPath(points: points)
                context.stroke(mainPath, with: .color(Color(hex: "#35b8ff")), lineWidth: 2.5)
                
                // Draw data points
                for point in points {
                    let circle = Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
                    context.fill(circle, with: .color(Color(hex: "#35b8ff")))
                }
            }
            .onAppear {
                chartSize = geometry.size
            }
        }
    }
}
