//
//  GutHealthCardView.swift
//  nutribase
//
//  Created by Cascade on 2025-12-26.
//

import SwiftUI

struct GutHealthCardView: View {
    var isPreview: Bool = false
    
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    @ObservedObject private var gutHealthService = GutHealthScoreService.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingDetailView = false
    @State private var showingInfo = false
    @State private var currentMetrics: GutHealthScoreService.GutHealthMetrics?
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    // Preview data
    private var previewScore: Double { 68 }
    
    private var displayMetrics: GutHealthScoreService.GutHealthMetrics {
        if isPreview {
            return GutHealthScoreService.GutHealthMetrics(
                fiberFrequencyPoints: 10.0,
                fiberFrequencyScore: 15.0,      // 18 pts max
                plantDiversityCount: 18,
                herbSpiceCount: 3,
                plantDiversityScore: 7.2,       // 12 pts max
                fiberGrams: 22,
                fiberGramsScore: 4.4,           // 5 pts max (when data quality sufficient)
                fiberDataQuality: 0.75,
                fiberDiversityTotal: 26.6,      // 35 pts max
                upfCaloriePercent: 18,
                upfLoadTotal: 30.0,             // 30 pts max (low UPF)
                fermentedServings: 3,
                fermentedScore: 7.5,
                prebioticServings: 4,
                prebioticScore: 8.0,
                fermentedPrebioticTotal: 15.5,  // 20 pts max
                unsatSatRatio: 1.8,
                fatRatioScore: 6.5,
                omega3Servings: 1,
                omega3Score: 3.5,
                fatQualityTotal: 10.0,          // 15 pts max
                overallScore: 82,               // Thriving
                interpretationBand: "Thriving",
                confidenceLevel: "High",
                confidencePercent: 85.0,
                daysLogged: 5,
                dataCompleteness: 0.8
            )
        }
        return currentMetrics ?? gutHealthService.calculateWeeklyMetrics(weekOffset: 0, entries: foodLogManager.entries)
    }
    
    var body: some View {
        FixedSizeCard(title: "Gut Health", showInfoButton: true, onInfoTap: {
            showingInfo = true
        }, onCardTap: {
            showingDetailView = true
        }) {
            HStack(spacing: 16) {
                // Mini gauge on the left
                ZStack {
                    // Simplified arc gauge
                    MiniGutHealthGauge(score: displayMetrics.overallScore, gaugeColors: gutHealthService.gaugeColors)
                        .frame(width: 80, height: 60)
                        .offset(y: -13)
                    
                    // Score number
                    Text("\(Int(displayMetrics.overallScore))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(gutHealthService.getScoreColor(displayMetrics.overallScore))
                        .offset(y: 22)
                }
                .frame(width: 90, height: 70)
                
                // Category bars on the right - 4 pillars
                VStack(alignment: .leading, spacing: 4) {
                    CategoryMiniBar(
                        label: "Fiber",
                        value: (displayMetrics.fiberDiversityTotal / 35.0) * 100,
                        color: .green,
                        available: true
                    )
                    CategoryMiniBar(
                        label: "UPF",
                        value: (displayMetrics.upfLoadTotal / 30.0) * 100,
                        color: .red,
                        available: true
                    )
                    CategoryMiniBar(
                        label: "Fermented",
                        value: (displayMetrics.fermentedPrebioticTotal / 20.0) * 100,
                        color: .purple,
                        available: true
                    )
                    CategoryMiniBar(
                        label: "Fat",
                        value: (displayMetrics.fatQualityTotal / 15.0) * 100,
                        color: .orange,
                        available: true
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            if !isPreview {
                refreshMetrics()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .foodLogUpdated)) { _ in
            if !isPreview {
                refreshMetrics()
            }
        }
        .sheet(isPresented: $showingDetailView) {
            GutHealthDetailView(foodLogManager: foodLogManager)
        }
        .alert("Gut Health Score", isPresented: $showingInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your Gut Health score is based on fiber intake, ultra-processed food consumption, sugar levels, and overall diet quality. Higher scores indicate a more gut-friendly diet.\n\nThis is for informational purposes only and is not medical advice.")
        }
    }
    
    private func refreshMetrics() {
        currentMetrics = gutHealthService.calculateWeeklyMetrics(weekOffset: 0, entries: foodLogManager.entries)
    }
}

// Mini gauge for the card view
struct MiniGutHealthGauge: View {
    let score: Double
    let gaugeColors: [Color]
    
    private var needleRotation: Double {
        return 150.0 + (score / 100.0) * 240.0
    }
    
    var body: some View {
        GeometryReader { geometry in
            let centerY = geometry.size.height * 0.75
            let center = CGPoint(x: geometry.size.width / 2, y: centerY)
            let radius = min(geometry.size.width / 2, geometry.size.height) - 5
            let innerRadius = radius * 0.65
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
                    let needleLength = radius * 0.75
                    let angle = Angle(degrees: needleRotation).radians
                    let tipX = center.x + cos(angle) * needleLength
                    let tipY = center.y + sin(angle) * needleLength
                    
                    let leftAngle = angle + .pi / 2
                    let rightAngle = angle - .pi / 2
                    let baseLeftX = center.x + cos(leftAngle) * 2
                    let baseLeftY = center.y + sin(leftAngle) * 2
                    let baseRightX = center.x + cos(rightAngle) * 2
                    let baseRightY = center.y + sin(rightAngle) * 2
                    
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: baseLeftX, y: baseLeftY))
                    path.addLine(to: CGPoint(x: baseRightX, y: baseRightY))
                    path.closeSubpath()
                }
                .fill(Color(.label))
                
                // Center dot
                Circle()
                    .fill(Color(.label))
                    .frame(width: 6, height: 6)
                    .position(center)
            }
        }
    }
}

// Mini category bar for the card
struct CategoryMiniBar: View {
    let label: String
    let value: Double
    let color: Color
    let available: Bool
    var inverted: Bool = false
    var actualValue: Double? = nil
    var targetValue: Double? = nil
    
    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 65, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    // Fill
                    if available {
                        let fillPercentage: CGFloat = {
                            if inverted, let actual = actualValue, let target = targetValue, target > 0 {
                                // For inverted metrics, show actual/target ratio (full when at or over target)
                                // Processing: 21% / 20% = 105% → capped at 100% (full bar)
                                // Sugar: 17g / 25g = 68% → 68% filled
                                return CGFloat(min((actual / target) * 100, 100))
                            } else {
                                // For normal metrics, use score directly
                                return CGFloat(value)
                            }
                        }()
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(width: max(0, geometry.size.width * (fillPercentage / 100)), height: 8)
                    }
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    GutHealthCardView(isPreview: true)
        .frame(width: 350, height: 150)
        .padding()
}
