//
//  WeightChartCardView.swift
//  nutribase
//
//  Created by Cascade on 2025-07-24.
//

import SwiftUI
import Charts

struct WeightChartCardView: View {
    @ObservedObject private var weightLogManager = WeightLogManager.shared
    @State private var showingDetailView = false
    
    // Get recent weight entries for the chart
    private var recentWeights: [WeightLogEntry] {
        let calendar = Calendar.current
        
        // Get the most recent entry date
        guard let mostRecentDate = weightLogManager.weightEntries.map({ $0.date }).max() else {
            return []
        }
        
        // Calculate date 30 days before the most recent entry
        let thirtyDaysBeforeMostRecent = calendar.date(byAdding: .day, value: -30, to: mostRecentDate) ?? Date()
        
        return weightLogManager.weightEntries
            .filter { $0.date >= thirtyDaysBeforeMostRecent && $0.date <= mostRecentDate }
            .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        Button(action: {
            showingDetailView = true
        }) {
            VStack(alignment: .leading, spacing: 8) {
            // Header with standardized top spacing
            HStack {
                Text("Weight Chart")
                    .font(.custom("Montserrat-Bold", size: 17))
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.bottom, 4)
            
            // Chart content
            if recentWeights.count >= 2 {
                Chart(recentWeights) { entry in
                    // Main line chart
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", entry.weight)
                    )
                    .foregroundStyle(.black)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    // Add X-axis line (horizontal) at the bottom of the chart
                    RuleMark(
                        y: .value("Zero", 0)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .foregroundStyle(.black)
                    
                    // Add Y-axis line (vertical)
                    RuleMark(
                        x: .value("Start", recentWeights.first?.date ?? Date())
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .foregroundStyle(.black)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 40)
            } else if recentWeights.count == 1 {
                // Show a simple preview with just one entry
                let entry = recentWeights[0]
                let previewData = [
                    (date: Calendar.current.date(byAdding: .day, value: -7, to: entry.date) ?? entry.date, weight: entry.weight * 0.98),
                    (date: entry.date, weight: entry.weight)
                ]
                
                Chart(previewData, id: \.date) { dataPoint in
                    // Main line chart
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Weight", dataPoint.weight)
                    )
                    .foregroundStyle(.black)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    // Add X-axis line (horizontal) at the bottom of the chart
                    RuleMark(
                        y: .value("Zero", 0)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .foregroundStyle(.black)
                    
                    // Add Y-axis line (vertical)
                    RuleMark(
                        x: .value("Start", previewData.first?.date ?? Date())
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .foregroundStyle(.black)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 40)
            } else {
                // Placeholder when no data
                VStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("Not enough data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(height: 120)
        }
        .sheet(isPresented: $showingDetailView) {
            WeightChartDetailView()
        }
    }
}

struct WeightChartDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var weightLogManager = WeightLogManager.shared
    
    // Get the last 30 days of data from the most recent weight entry
    private var chartData: [WeightLogEntry] {
        guard let mostRecentEntry = weightLogManager.weightEntries.first else {
            return []
        }
        
        let calendar = Calendar.current
        let endDate = mostRecentEntry.date
        let startDate = calendar.date(byAdding: .day, value: -29, to: endDate) ?? endDate
        
        return weightLogManager.weightEntries
            .filter { $0.date >= startDate && $0.date <= endDate }
            .sorted { $0.date < $1.date }
    }
    
    private var weightRange: (min: Double, max: Double) {
        guard !chartData.isEmpty else { return (0, 100) }
        let weights = chartData.map { $0.weight }
        let minWeight = weights.min() ?? 0
        let maxWeight = weights.max() ?? 100
        let padding = (maxWeight - minWeight) * 0.1 // 10% padding
        return (minWeight - padding, maxWeight + padding)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !chartData.isEmpty {
                        // Chart Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Weight Trend (Last 30 Days)")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Chart(chartData) { entry in
                                LineMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Weight", entry.weight)
                                )
                                .foregroundStyle(.blue)
                                .lineStyle(StrokeStyle(lineWidth: 3))
                                
                                PointMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Weight", entry.weight)
                                )
                                .foregroundStyle(.blue)
                                .symbol(.circle)
                                .symbolSize(30)
                            }
                            .frame(height: 300)
                            .chartYScale(domain: weightRange.min...weightRange.max)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel {
                                        if let weight = value.as(Double.self) {
                                            Text(String(format: "%.1f kg", weight))
                                        }
                                    }
                                }
                            }
                        }
                        .cardStyle()
                        
                        // Statistics Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Statistics")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                                StatCard(title: "Current", value: String(format: "%.1f kg", chartData.last?.weight ?? 0), color: .blue)
                                StatCard(title: "Highest", value: String(format: "%.1f kg", chartData.map { $0.weight }.max() ?? 0), color: .red)
                                StatCard(title: "Lowest", value: String(format: "%.1f kg", chartData.map { $0.weight }.min() ?? 0), color: .green)
                                StatCard(title: "Change", value: weightChangeText, color: weightChangeColor)
                            }
                        }
                        .cardStyle()
                    } else {
                        // No data state
                        VStack(spacing: 16) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No Weight Data")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Start logging your weight to see your progress chart here.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Weight Chart Details")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var weightChangeText: String {
        guard chartData.count >= 2,
              let first = chartData.first?.weight,
              let last = chartData.last?.weight else {
            return "N/A"
        }
        
        let change = last - first
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", change)) kg"
    }
    
    private var weightChangeColor: Color {
        guard chartData.count >= 2,
              let first = chartData.first?.weight,
              let last = chartData.last?.weight else {
            return .gray
        }
        
        let change = last - first
        return change >= 0 ? .red : .green
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    WeightChartCardView()
        .padding()
}
