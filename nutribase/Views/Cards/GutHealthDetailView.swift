//
//  GutHealthDetailView.swift
//  nutribase
//
//  Created by Cascade on 2025-12-26.
//

import SwiftUI

struct GutHealthDetailView: View {
    @ObservedObject var foodLogManager: FoodLogManager
    @ObservedObject private var gutHealthService = GutHealthScoreService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // State for week selection
    @State private var currentWeekOffset: Int = 0
    @State private var scrolledWeekID: Int? = 0
    @State private var animationOpacity: Double = 1.0
    
    // Cache for weekly data
    @State private var weeklyDataCache: [Int: GutHealthScoreService.GutHealthMetrics] = [:]
    
    // State for metric breakdown sheet
    @State private var showingMetricBreakdown = false
    @State private var selectedMetricType: MetricType = .fiber
    
    enum MetricType: String {
        case fiberDiversity = "Fibre & Diversity"
        case upfLoad = "Ultra-Processed Foods"
        case fermentedPrebiotic = "Fermented & Prebiotics"
        case fatQuality = "Fat Quality"
        case consistency = "Consistency"
        // Legacy
        case fiber = "Fiber"
        case sugar = "Sugar"
        case nova4 = "NOVA 4"
        case nutriScore = "Nutri-Score"
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    private var viewBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                viewBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Week selector carousel
                        weekSelectorCarousel
                        
                        // Gut Health Score Gauge Card
                        gutHealthGaugeCard(for: currentWeekOffset)
                            .padding(.horizontal)
                        
                        // Category Breakdown Section
                        Text("Score Breakdown")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        // Individual category cards (4-category diet-based system)
                        VStack(spacing: 12) {
                            let metrics = getCachedMetrics(for: currentWeekOffset)
                            
                            // 1. Fibre Quantity & Diversity (35 pts)
                            CategoryScoreCard(
                                title: "Fibre & Diversity",
                                score: (metrics.fiberDiversityTotal / 35.0) * 100,
                                value: String(format: "%.0f/35", metrics.fiberDiversityTotal),
                                target: "\(metrics.plantDiversityCount) plants • \(String(format: "%.0fg", metrics.fiberGrams)) fibre",
                                color: gutHealthService.fiberDiversityColor,
                                icon: "leaf.fill",
                                insight: getFiberDiversityInsight(metrics),
                                available: true
                            )
                            .onTapGesture {
                                selectedMetricType = .fiberDiversity
                                showingMetricBreakdown = true
                            }
                            
                            // 2. Ultra-Processed Food Load (30 pts)
                            CategoryScoreCard(
                                title: "Ultra-Processed Foods",
                                score: (metrics.upfLoadTotal / 30.0) * 100,
                                value: String(format: "%.0f/30", metrics.upfLoadTotal),
                                target: String(format: "%.0f%% UPF calories", metrics.upfCaloriePercent),
                                color: gutHealthService.upfLoadColor,
                                icon: "exclamationmark.triangle.fill",
                                insight: getUpfLoadInsight(metrics),
                                available: true
                            )
                            .onTapGesture {
                                selectedMetricType = .upfLoad
                                showingMetricBreakdown = true
                            }
                            
                            // 3. Fermented & Prebiotic Foods (20 pts)
                            CategoryScoreCard(
                                title: "Fermented & Prebiotics",
                                score: (metrics.fermentedPrebioticTotal / 20.0) * 100,
                                value: String(format: "%.0f/20", metrics.fermentedPrebioticTotal),
                                target: String(format: "%.1f fermented • %.1f prebiotic", metrics.fermentedServings, metrics.prebioticServings),
                                color: gutHealthService.fermentedPrebioticColor,
                                icon: "sparkles",
                                insight: getFermentedPrebioticInsight(metrics),
                                available: true
                            )
                            .onTapGesture {
                                selectedMetricType = .fermentedPrebiotic
                                showingMetricBreakdown = true
                            }
                            
                            // 4. Fat Quality & Inflammatory Balance (15 pts)
                            CategoryScoreCard(
                                title: "Fat Quality",
                                score: (metrics.fatQualityTotal / 15.0) * 100,
                                value: String(format: "%.0f/15", metrics.fatQualityTotal),
                                target: String(format: "%.1f:1 unsat:sat • %.1f omega-3", metrics.unsatSatRatio, metrics.omega3Servings),
                                color: gutHealthService.fatQualityColor,
                                icon: "drop.fill",
                                insight: getFatQualityInsight(metrics),
                                available: true
                            )
                            .onTapGesture {
                                selectedMetricType = .fatQuality
                                showingMetricBreakdown = true
                            }
                        }
                        .padding(.horizontal)
                        .opacity(animationOpacity)
                        
                        // Info Section
                        infoSection
                            .padding(.horizontal)
                        
                        // Bottom spacing
                        Color.clear.frame(height: 40)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("Gut Health")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingMetricBreakdown) {
                MetricBreakdownView(
                    metricType: selectedMetricType,
                    weekOffset: currentWeekOffset,
                    foodLogManager: foodLogManager,
                    metrics: getCachedMetrics(for: currentWeekOffset)
                )
            }
            .onAppear {
                // Prefetch AI estimates for foods missing sugar/fiber data
                gutHealthService.prefetchAIEstimates(for: foodLogManager.entries)
            }
        }
    }
    
    // MARK: - Week Selector Carousel
    
    private var weekSelectorCarousel: some View {
        let cardWidth: CGFloat = 170
        
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(-10...0, id: \.self) { offset in
                    weekSelectorCard(for: offset)
                        .frame(width: cardWidth)
                        .id(offset)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrolledWeekID)
        .scrollTargetBehavior(.viewAligned)
        .safeAreaPadding(.horizontal, (UIScreen.main.bounds.width - cardWidth) / 2)
        .defaultScrollAnchor(.trailing)
        .onChange(of: scrolledWeekID) { oldValue, newValue in
            if let newValue = newValue, newValue != currentWeekOffset {
                updateCurrentWeek(to: newValue)
            }
        }
        .onAppear {
            // Pre-cache current week and adjacent weeks
            Task {
                for offset in [-1, 0, 1] {
                    if weeklyDataCache[offset] == nil {
                        let data = gutHealthService.calculateWeeklyMetrics(weekOffset: offset, entries: foodLogManager.entries)
                        weeklyDataCache[offset] = data
                    }
                }
            }
        }
        .frame(height: 50)
    }
    
    private func weekSelectorCard(for offset: Int) -> some View {
        let isSelected = offset == currentWeekOffset
        
        return Text(weekDateRangeString(for: offset))
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "#35b8ff") : cardBackground)
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrolledWeekID = offset
                }
            }
    }
    
    // MARK: - Gut Health Gauge Card
    
    private func gutHealthGaugeCard(for weekOffset: Int) -> some View {
        let metrics = getCachedMetrics(for: weekOffset)
        
        return VStack(spacing: 8) {
            Text("Gut Health Score")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                GutHealthGauge(score: metrics.overallScore, gaugeColors: gutHealthService.gaugeColors)
                    .frame(height: 120)
                    .offset(y: 12)
                
                Text("\(Int(metrics.overallScore))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(gutHealthService.getScoreColor(metrics.overallScore))
                    .offset(y: -16)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, -8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About This Score")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Your Gut Health score is calculated based on four evidence-based dietary factors linked to microbiome health:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoBullet(icon: "leaf.fill", color: gutHealthService.fiberDiversityColor, text: "Fibre & Diversity (35pts): Fibre intake + plant variety")
                InfoBullet(icon: "exclamationmark.triangle.fill", color: gutHealthService.upfLoadColor, text: "UPF Load (30pts): Ultra-processed food consumption")
                InfoBullet(icon: "sparkles", color: gutHealthService.fermentedPrebioticColor, text: "Gut Foods (20pts): Fermented & prebiotic foods")
                InfoBullet(icon: "drop.fill", color: gutHealthService.fatQualityColor, text: "Fat Quality (15pts): Healthy fat balance & omega-3s")
            }
            
            Text("This is for informational purposes only and is not medical advice. Consult a healthcare provider for personalized guidance.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Helper Methods
    
    private func getCachedMetrics(for weekOffset: Int) -> GutHealthScoreService.GutHealthMetrics {
        if let cached = weeklyDataCache[weekOffset] {
            return cached
        }
        let metrics = gutHealthService.calculateWeeklyMetrics(weekOffset: weekOffset, entries: foodLogManager.entries)
        DispatchQueue.main.async {
            weeklyDataCache[weekOffset] = metrics
        }
        return metrics
    }
    
    private func updateCurrentWeek(to offset: Int) {
        withAnimation(.easeOut(duration: 0.15)) {
            animationOpacity = 0.3
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            currentWeekOffset = offset
            
            // Pre-cache adjacent weeks
            Task {
                for adjacentOffset in [offset - 1, offset + 1] {
                    if weeklyDataCache[adjacentOffset] == nil {
                        let data = gutHealthService.calculateWeeklyMetrics(weekOffset: adjacentOffset, entries: foodLogManager.entries)
                        weeklyDataCache[adjacentOffset] = data
                    }
                }
            }
            
            withAnimation(.easeOut(duration: 0.2)) {
                animationOpacity = 1.0
            }
        }
    }
    
    private func weekDateRangeString(for offset: Int) -> String {
        let calendar = Calendar.current
        let today = Date()
        
        guard let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let targetWeekStart = calendar.date(byAdding: .weekOfYear, value: offset, to: currentWeekStart),
              let targetWeekEnd = calendar.date(byAdding: .day, value: 6, to: targetWeekStart) else {
            return "Unknown"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        return "\(formatter.string(from: targetWeekStart)) - \(formatter.string(from: targetWeekEnd))"
    }
    
    private func getNutriScoreGrade(_ average: Double) -> String {
        switch average {
        case 0..<0.2: return "A"
        case 0.2..<0.4: return "B"
        case 0.4..<0.6: return "C"
        case 0.6..<0.8: return "D"
        default: return "E"
        }
    }
    
    // MARK: - New 5-Category Insight Functions
    
    private func getFiberDiversityInsight(_ metrics: GutHealthScoreService.GutHealthMetrics) -> String {
        if metrics.fiberDiversityTotal >= 25 {
            return "Excellent fibre & plant diversity"
        } else if metrics.fiberDiversityTotal >= 18 {
            return "Good variety, aim for 25+ plants/week"
        } else if metrics.fiberDiversityTotal >= 10 {
            return "Try adding more plant foods"
        } else {
            return "Increase fibre and plant variety"
        }
    }
    
    private func getUpfLoadInsight(_ metrics: GutHealthScoreService.GutHealthMetrics) -> String {
        if metrics.upfCaloriePercent < 20 {
            return "Low ultra-processed food intake"
        } else if metrics.upfCaloriePercent < 35 {
            return "Moderate UPF, room for improvement"
        } else if metrics.upfCaloriePercent < 50 {
            return "Consider reducing processed foods"
        } else {
            return "High UPF intake, prioritize whole foods"
        }
    }
    
    private func getFermentedPrebioticInsight(_ metrics: GutHealthScoreService.GutHealthMetrics) -> String {
        if metrics.fermentedPrebioticTotal >= 16 {
            return "Great probiotic & prebiotic intake"
        } else if metrics.fermentedPrebioticTotal >= 10 {
            return "Good gut-friendly food choices"
        } else if metrics.fermentedServings == 0 {
            return "Try adding yogurt, kimchi, or sauerkraut"
        } else {
            return "Add more fermented & prebiotic foods"
        }
    }
    
    private func getFatQualityInsight(_ metrics: GutHealthScoreService.GutHealthMetrics) -> String {
        if metrics.fatQualityTotal >= 12 {
            return "Excellent fat balance"
        } else if metrics.omega3Servings >= 2 {
            return "Good omega-3 intake"
        } else if metrics.unsatSatRatio >= 2.0 {
            return "Good unsaturated fat ratio"
        } else {
            return "Add more fish, nuts, or olive oil"
        }
    }
    
    private func getConsistencyInsight(_ metrics: GutHealthScoreService.GutHealthMetrics) -> String {
        if metrics.daysLogged >= 6 {
            return "Excellent tracking consistency"
        } else if metrics.daysLogged >= 4 {
            return "Good tracking, aim for daily"
        } else {
            return "Log more days for better insights"
        }
    }
    
    private func getInterpretationColor(_ band: String) -> Color {
        switch band {
        case "Thriving": return Color(red: 0.2, green: 0.7, blue: 0.3)      // Green
        case "Supported": return Color(red: 0.6, green: 0.8, blue: 0.3)     // Lime
        case "Needs Attention": return Color(red: 0.95, green: 0.6, blue: 0.2)  // Orange
        case "Under Supported": return Color(red: 0.85, green: 0.2, blue: 0.2)  // Red
        default: return .secondary
        }
    }
    
    private func getNutriScoreInsight(_ average: Double) -> String {
        switch average {
        case 0..<0.2: return "Excellent diet quality"
        case 0.2..<0.4: return "Good diet quality"
        case 0.4..<0.6: return "Moderate diet quality"
        case 0.6..<0.8: return "Could improve diet quality"
        default: return "Diet quality needs attention"
        }
    }
    
    // MARK: - Confidence Indicator Helpers
    
    private func getConfidenceIcon(_ level: String) -> String {
        switch level {
        case "High": return "checkmark.shield.fill"
        case "Medium": return "shield.fill"
        case "Low": return "exclamationmark.shield.fill"
        default: return "questionmark.circle"
        }
    }
    
    private func getConfidenceColor(_ level: String) -> Color {
        switch level {
        case "High": return .green
        case "Medium": return .orange
        case "Low": return .red
        default: return .secondary
        }
    }
}

// MARK: - Category Score Card

struct CategoryScoreCard: View {
    let title: String
    let score: Double
    let value: String
    let target: String
    let color: Color
    let icon: String
    let insight: String
    let available: Bool
    var isEstimated: Bool = false
    var inverted: Bool = false
    var actualValue: Double? = nil
    var targetValue: Double? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingEstimationInfo = false
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if available {
                    HStack(spacing: 4) {
                        Text(value)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                        
                        // Show estimation indicator if value is estimated
                        if isEstimated {
                            Button(action: {
                                showingEstimationInfo = true
                            }) {
                                Text("✨")
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            
            if available {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 12)
                        
                        // Fill
                        let fillPercentage: CGFloat = {
                            if inverted, let actual = actualValue, let target = targetValue, target > 0 {
                                // For inverted metrics, show actual/target ratio (full when at or over target)
                                return CGFloat(min((actual / target) * 100, 100))
                            } else if inverted {
                                // Fallback for inverted metrics without actual/target
                                return CGFloat(100 - score)
                            } else {
                                // For normal metrics, use score directly
                                return CGFloat(score)
                            }
                        }()
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color)
                            .frame(width: max(0, geometry.size.width * (fillPercentage / 100)), height: 12)
                    }
                }
                .frame(height: 12)
                
                // Footer
                HStack {
                    Text(insight)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(target)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // No data state
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.secondary)
                    Text("No data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .alert("Estimated Value", isPresented: $showingEstimationInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This value has been estimated based on similar foods in our database, as the original food entry was missing this nutritional information. While not exact, it provides a reasonable approximation for tracking your overall dietary patterns.")
        }
    }
}

// MARK: - Info Bullet

struct InfoBullet: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 12))
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Gut Health Gauge (reuses NovaScoreGauge pattern)

struct GutHealthGauge: View {
    let score: Double
    let gaugeColors: [Color]
    
    private var needleRotation: Double {
        return 150.0 + (score / 100.0) * 240.0
    }
    
    var body: some View {
        GeometryReader { geometry in
            let centerY = geometry.size.height * 0.6
            let center = CGPoint(x: geometry.size.width / 2, y: centerY)
            let radius = min(geometry.size.width / 2, geometry.size.height * 0.8) - 10
            let innerRadius = radius * 0.70
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
                    let needleLength = radius * 0.80
                    let needleWidth: CGFloat = 6
                    
                    let angle = Angle(degrees: needleRotation).radians
                    let tipX = center.x + cos(angle) * needleLength
                    let tipY = center.y + sin(angle) * needleLength
                    
                    let leftAngle = angle + .pi / 2
                    let rightAngle = angle - .pi / 2
                    let baseLeftX = center.x + cos(leftAngle) * (needleWidth * 0.6)
                    let baseLeftY = center.y + sin(leftAngle) * (needleWidth * 0.6)
                    let baseRightX = center.x + cos(rightAngle) * (needleWidth * 0.6)
                    let baseRightY = center.y + sin(rightAngle) * (needleWidth * 0.6)
                    
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: baseLeftX, y: baseLeftY))
                    path.addLine(to: CGPoint(x: baseRightX, y: baseRightY))
                    path.closeSubpath()
                }
                .fill(Color(.label))
                
                // Center dot
                Circle()
                    .fill(Color(.label))
                    .frame(width: 12, height: 12)
                    .position(center)
                
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 6, height: 6)
                    .position(center)
                
                // Scale labels
                let labelRadius = radius + 12
                let startLabelAngle = Angle(degrees: 150).radians
                let endLabelAngle = Angle(degrees: 30).radians
                
                Text("0")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .position(
                        x: center.x + cos(startLabelAngle) * labelRadius,
                        y: center.y + sin(startLabelAngle) * labelRadius
                    )
                
                Text("100")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .position(
                        x: center.x + cos(endLabelAngle) * labelRadius,
                        y: center.y + sin(endLabelAngle) * labelRadius
                    )
            }
        }
    }
}

// MARK: - Metric Breakdown View (Debug)

struct MetricBreakdownView: View {
    let metricType: GutHealthDetailView.MetricType
    let weekOffset: Int
    @ObservedObject var foodLogManager: FoodLogManager
    let metrics: GutHealthScoreService.GutHealthMetrics
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    private var weekEntries: [FoodEntry] {
        let calendar = Calendar.current
        let today = Date()
        
        guard let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let targetWeekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart),
              let targetWeekEnd = calendar.date(byAdding: .day, value: 7, to: targetWeekStart) else {
            return []
        }
        
        return foodLogManager.entries.filter { entry in
            entry.dateAdded >= targetWeekStart && entry.dateAdded < targetWeekEnd
        }
    }
    
    private var foodBreakdown: [(entry: FoodEntry, value: Double, isEstimated: Bool)] {
        let allEntries = weekEntries.map { entry in
            let (value, isEstimated) = calculateMetricValue(for: entry)
            return (entry: entry, value: value, isEstimated: isEstimated)
        }
        .sorted { $0.value > $1.value } // Sort by value descending
        
        // For fermentedPrebiotic and fatQuality, only show foods that contribute
        switch metricType {
        case .fermentedPrebiotic, .fatQuality:
            return allEntries.filter { $0.value > 0 }
        default:
            return allEntries
        }
    }
    
    private var totalValue: Double {
        foodBreakdown.reduce(0) { $0 + $1.value }
    }
    
    private var uniqueDaysCount: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(weekEntries.map { calendar.startOfDay(for: $0.dateAdded) })
        return uniqueDays.count
    }
    
    private var dailyAverage: Double {
        uniqueDaysCount > 0 ? totalValue / Double(uniqueDaysCount) : 0
    }
    
    var body: some View {
        NavigationView {
            List {
                // Summary section
                Section {
                    if metricType == .fermentedPrebiotic {
                        // Show fermented and prebiotic counts from metrics
                        HStack {
                            Text("Fermented servings")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(String(format: "%.1f", metrics.fermentedServings))
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                        }
                        HStack {
                            Text("Prebiotic servings")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(String(format: "%.1f", metrics.prebioticServings))
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        HStack {
                            Text("Score")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(Int(metrics.fermentedPrebioticTotal))/20")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    } else if metricType == .fatQuality {
                        // Show fat quality details from metrics
                        HStack {
                            Text("Unsat:Sat ratio")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(String(format: "%.1f:1", metrics.unsatSatRatio))
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        HStack {
                            Text("Omega-3 servings")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(String(format: "%.1f", metrics.omega3Servings))
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        HStack {
                            Text("Score")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(Int(metrics.fatQualityTotal))/15")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    } else {
                        HStack {
                            Text("Total (\(metricType.rawValue))")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(formatValue(totalValue))
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        
                        HStack {
                            Text("Days with entries")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(uniqueDaysCount)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Daily average")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(formatValue(dailyAverage))
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Text("Summary")
                }
                
                // Food breakdown section
                Section {
                    if foodBreakdown.isEmpty {
                        if metricType == .fermentedPrebiotic {
                            Text("No fermented or prebiotic foods detected this week.\n\nLook for: yogurt, kefir, kimchi, sauerkraut, miso, tempeh, kombucha, onion, garlic, banana, oats, legumes")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        } else if metricType == .fatQuality {
                            Text("No omega-3 rich foods detected this week.\n\nLook for: salmon, mackerel, sardines, walnuts, flaxseed, chia seeds")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        } else {
                            Text("No food entries for this week")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(foodBreakdown, id: \.entry.id) { item in
                            FoodMetricRow(
                                entry: item.entry,
                                value: item.value,
                                isEstimated: item.isEstimated,
                                metricType: metricType,
                                formatValue: formatValue
                            )
                        }
                    }
                } header: {
                    Text("Food Breakdown (sorted by \(metricType.rawValue))")
                }
            }
            .navigationTitle("\(metricType.rawValue) Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func calculateMetricValue(for entry: FoodEntry) -> (Double, Bool) {
        let unitLower = entry.servingUnit.lowercased()
        let isOriginalServing = unitLower == "serving" || unitLower == "servings" || unitLower == "meal"
        
        switch metricType {
        case .fiber, .fiberDiversity:
            let fiberPer100g = entry.foodItem.fiber ?? GutHealthScoreService.shared.estimateFiberForDebug(for: entry.foodItem)
            let isEstimated = entry.foodItem.fiber == nil || entry.foodItem.fiber == 0
            let scaledValue = NutritionCalculator.calculateMacro(
                macroValue: fiberPer100g,
                servingSize: entry.servingSize,
                servingUnit: entry.servingUnit,
                numberOfServings: entry.numberOfServings,
                isOriginalServingSize: isOriginalServing,
                servingDescription: entry.foodItem.servingSize,
                servingQuantity: entry.foodItem.servingsPerPackage
            )
            return (scaledValue, isEstimated)
            
        case .sugar:
            let sugarPer100g = entry.foodItem.sugar ?? GutHealthScoreService.shared.estimateSugarForDebug(for: entry.foodItem)
            let isEstimated = entry.foodItem.sugar == nil || entry.foodItem.sugar == 0
            let scaledValue = NutritionCalculator.calculateMacro(
                macroValue: sugarPer100g,
                servingSize: entry.servingSize,
                servingUnit: entry.servingUnit,
                numberOfServings: entry.numberOfServings,
                isOriginalServingSize: isOriginalServing,
                servingDescription: entry.foodItem.servingSize,
                servingQuantity: entry.foodItem.servingsPerPackage
            )
            return (scaledValue, isEstimated)
            
        case .nova4, .upfLoad:
            let novaScore = entry.foodItem.novaScore > 0 ?
                entry.foodItem.novaScore :
                NovaScoreService.shared.predictNovaScore(for: entry.foodItem)
            let calories = Double(entry.totalCalories)
            // Return calories if NOVA 4, 0 otherwise
            return (novaScore == 4 ? calories : 0, entry.foodItem.novaScore == 0)
            
        case .nutriScore:
            if let grade = entry.foodItem.nutriScoreGrade, !grade.isEmpty {
                let numericScore = nutriScoreGradeToNumeric(grade)
                return (numericScore, entry.foodItem.nutriScoreIsEstimated)
            }
            return (0, true)
            
        case .fermentedPrebiotic:
            // Check if food matches fermented or prebiotic keywords
            let isFermented = GutHealthScoreService.shared.isFermentedFood(entry.foodItem.name)
            let isPrebiotic = GutHealthScoreService.shared.isPrebioticFood(entry.foodItem.name)
            // Return servings count if it matches either category
            if isFermented || isPrebiotic {
                return (entry.numberOfServings, false)
            }
            return (0, false)
            
        case .fatQuality:
            // Check if food is omega-3 rich
            let isOmega3 = GutHealthScoreService.shared.isOmega3Food(entry.foodItem.name)
            if isOmega3 {
                return (entry.numberOfServings, false)
            }
            // Also show fat ratio contribution
            let totalFat = entry.foodItem.fat
            let saturatedFat = entry.foodItem.saturatedFat ?? 0
            if totalFat > 0 && saturatedFat > 0 {
                let unsatFat = max(0, totalFat - saturatedFat)
                let ratio = unsatFat / saturatedFat
                return (ratio, false)
            }
            return (0, false)
            
        case .consistency:
            // Not used in 4-category system
            return (0, false)
        }
    }
    
    private func nutriScoreGradeToNumeric(_ grade: String) -> Double {
        switch grade.lowercased() {
        case "a": return 0.0
        case "b": return 0.25
        case "c": return 0.5
        case "d": return 0.75
        case "e": return 1.0
        default: return 0.5
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        switch metricType {
        case .fiber, .sugar, .fiberDiversity:
            return String(format: "%.1fg", value)
        case .nova4, .upfLoad:
            return String(format: "%.0f kcal", value)
        case .nutriScore:
            return String(format: "%.2f", value)
        case .fermentedPrebiotic:
            return value > 0 ? String(format: "%.0f serving(s)", value) : "0"
        case .fatQuality:
            return value > 0 ? String(format: "%.1f:1", value) : "0"
        case .consistency:
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Food Metric Row

struct FoodMetricRow: View {
    let entry: FoodEntry
    let value: Double
    let isEstimated: Bool
    let metricType: GutHealthDetailView.MetricType
    let formatValue: (Double) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.foodItem.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if isEstimated {
                    Text("✨")
                        .font(.caption)
                }
                
                Spacer()
                
                Text(formatValue(value))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(value > 0 ? .blue : .secondary)
            }
            
            HStack(spacing: 8) {
                // Serving info
                let totalServing = entry.servingSize * entry.numberOfServings
                Text("\(String(format: "%.0f", totalServing))\(entry.servingUnit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Date
                Text(formatDate(entry.dateAdded))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Raw value info for debugging
                if metricType == .sugar || metricType == .fiber {
                    let rawValue = metricType == .sugar ? entry.foodItem.sugar : entry.foodItem.fiber
                    if let raw = rawValue {
                        Text("(\(String(format: "%.1f", raw))g/100g)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    } else {
                        Text("(estimated)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                if metricType == .nova4 {
                    let novaScore = entry.foodItem.novaScore > 0 ?
                        entry.foodItem.novaScore :
                        NovaScoreService.shared.predictNovaScore(for: entry.foodItem)
                    Text("NOVA \(novaScore)")
                        .font(.caption2)
                        .foregroundColor(novaScore == 4 ? .red : .gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    GutHealthDetailView(foodLogManager: FoodLogManager.shared)
}
