//
//  EmbeddedYearCalendarView.swift
//  nutribase
//
//  Compact year calendar view for embedding in PhasesView with phase backgrounds
//

import SwiftUI
import Charts

struct EmbeddedYearCalendarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedDate: Date
    
    @StateObject private var weightManager = WeightLogManager.shared
    @ObservedObject private var phaseManager = WeightPhaseManager.shared
    @State private var currentYear = Calendar.current.component(.year, from: Date())
    
    // Explicit state variables that get updated when year changes
    @State private var displayedWeightEntries: [WeightLogEntry] = []
    @State private var displayedPhases: [WeightPhase] = []
    @State private var viewRefreshID = UUID()
    
    // Dashboard-matching card background
    private var cardBackground: Color {
        Color.appCardBackground
    }
    private let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                             "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday first
        return cal
    }
    
    private func updateDataForYear() {
        let cal = Calendar.current
        let yearStart = cal.date(from: DateComponents(year: currentYear, month: 1, day: 1)) ?? Date()
        let yearEnd = cal.date(from: DateComponents(year: currentYear, month: 12, day: 31)) ?? Date()
        
        // Filter weight entries for this year
        displayedWeightEntries = weightManager.weightEntries.filter { entry in
            entry.date >= yearStart && entry.date <= yearEnd
        }.sorted { $0.date < $1.date }
        
        // Filter phases for this year
        displayedPhases = phaseManager.phases.filter { phase in
            phase.startDate <= yearEnd && phase.effectiveEndDate >= yearStart
        }.sorted { $0.startDate < $1.startDate }
        
        // Force view refresh
        viewRefreshID = UUID()
        
        print("📊 [YearCalendar] Updated for \(currentYear): \(displayedWeightEntries.count) entries, \(displayedPhases.count) phases")
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Year header with navigation
            HStack {
                Button(action: {
                    currentYear -= 1
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(String(currentYear))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    currentYear += 1
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            
            // Months grid - 4 rows x 3 columns
            VStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { col in
                            let monthIndex = row * 3 + col
                            if monthIndex < 12 {
                                monthView(for: monthIndex)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            
            // Phase Legend
            if !displayedPhases.isEmpty {
                Divider()
                    .padding(.top, 8)
                
                phaseLegend
            }
            
            // Weight Chart with Phase Backgrounds
            Divider()
                .padding(.top, 8)
            
            yearWeightChart
        }
        .id(viewRefreshID)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .onAppear {
            updateDataForYear()
        }
        .onChange(of: currentYear) { oldValue, newValue in
            updateDataForYear()
        }
    }
    
    // MARK: - Year Weight Chart with Phase Backgrounds
    
    private var yearWeightChart: some View {
        let cal = Calendar.current
        let yearStart = cal.date(from: DateComponents(year: currentYear, month: 1, day: 1)) ?? Date()
        let yearEnd = cal.date(from: DateComponents(year: currentYear, month: 12, day: 31)) ?? Date()
        
        // Calculate weight range from displayedWeightEntries
        let weights = displayedWeightEntries.map { $0.weight }
        let minWeight = (weights.min() ?? 60) - 2
        let maxWeight = (weights.max() ?? 80) + 2
        
        return VStack(alignment: .leading, spacing: 8) {
            Text("Weight Chart")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            if displayedWeightEntries.isEmpty {
                Text("No weight entries in \(String(currentYear))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    // Phase background rectangles
                    ForEach(displayedPhases) { phase in
                        let phaseStart = max(phase.startDate, yearStart)
                        let phaseEnd = min(phase.effectiveEndDate, yearEnd)
                        
                        RectangleMark(
                            xStart: .value("Start", phaseStart),
                            xEnd: .value("End", phaseEnd),
                            yStart: .value("Min", minWeight),
                            yEnd: .value("Max", maxWeight)
                        )
                        .foregroundStyle(phase.swiftUIColor.opacity(0.5))
                    }
                    
                    // Weight line
                    ForEach(displayedWeightEntries, id: \.id) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(Color.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    
                    // Weight points
                    ForEach(displayedWeightEntries, id: \.id) { entry in
                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(Color.blue)
                        .symbolSize(20)
                    }
                }
                .chartXScale(domain: yearStart...yearEnd)
                .chartYScale(domain: minWeight...maxWeight)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 2)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let weight = value.as(Double.self) {
                                Text("\(Int(weight))")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 150)
                .id("chart-\(currentYear)")
            }
        }
        .id("year-\(currentYear)")
    }
    
    private func monthView(for monthIndex: Int) -> some View {
        let monthDate = calendar.date(from: DateComponents(year: currentYear, month: monthIndex + 1, day: 1)) ?? Date()
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: monthDate)
        let startingSpaces = (firstWeekday == 1) ? 6 : firstWeekday - 2
        let totalCells = startingSpaces + daysInMonth
        let rows = (totalCells + 6) / 7
        
        return VStack(spacing: 2) {
            // Month name
            Text(monthNames[monthIndex])
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Calendar grid
            VStack(spacing: 0) {
                ForEach(Array(0..<rows), id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(Array(0..<7), id: \.self) { col in
                            dayCell(row: row, col: col, monthIndex: monthIndex, startingSpaces: startingSpaces, daysInMonth: daysInMonth)
                        }
                    }
                    .background(
                        phaseRowBackground(row: row, monthIndex: monthIndex, startingSpaces: startingSpaces, daysInMonth: daysInMonth)
                    )
                }
            }
            .frame(height: CGFloat(rows) * 12)
        }
    }
    
    private func dayCell(row: Int, col: Int, monthIndex: Int, startingSpaces: Int, daysInMonth: Int) -> some View {
        let cellIndex = row * 7 + col
        let dayNumber = cellIndex - startingSpaces + 1
        
        if cellIndex < startingSpaces || dayNumber > daysInMonth {
            return AnyView(
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 12, height: 12)
            )
        } else {
            let dayDate = calendar.date(from: DateComponents(year: currentYear, month: monthIndex + 1, day: dayNumber)) ?? Date()
            let isSelected = calendar.isDate(dayDate, inSameDayAs: selectedDate)
            let isToday = calendar.isDateInToday(dayDate)
            
            let textColor: Color = isSelected ? .white : (isToday ? .red : .primary)
            
            return AnyView(
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                    }
                    
                    Text("\(dayNumber)")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(textColor)
                }
                .frame(width: 12, height: 12)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedDate = dayDate
                }
            )
        }
    }
    
    private func phaseRowBackground(row: Int, monthIndex: Int, startingSpaces: Int, daysInMonth: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(0..<7), id: \.self) { col in
                let cellIndex = row * 7 + col
                let dayNumber = cellIndex - startingSpaces + 1
                
                if cellIndex >= startingSpaces && dayNumber <= daysInMonth {
                    let dayDate = calendar.date(from: DateComponents(year: currentYear, month: monthIndex + 1, day: dayNumber)) ?? Date()
                    let phaseForDate = getPhase(for: dayDate)
                    let isToday = calendar.isDateInToday(dayDate)
                    
                    // Get adjacent phase info for connected backgrounds
                    let leftPhase = col > 0 ? getPhaseForCell(row: row, col: col - 1, monthIndex: monthIndex, startingSpaces: startingSpaces, daysInMonth: daysInMonth) : nil
                    let rightPhase = col < 6 ? getPhaseForCell(row: row, col: col + 1, monthIndex: monthIndex, startingSpaces: startingSpaces, daysInMonth: daysInMonth) : nil
                    
                    let baseColor = isToday ? Color.red.opacity(0.15) : (phaseForDate?.color.swiftUIColor.opacity(0.5) ?? Color.clear)
                    
                    // Create connected background shape
                    let leftConnected = phaseForDate?.id == leftPhase?.id && phaseForDate != nil
                    let rightConnected = phaseForDate?.id == rightPhase?.id && phaseForDate != nil
                    
                    Rectangle()
                        .fill(baseColor)
                        .frame(width: 12, height: 12)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: leftConnected ? 0 : 2,
                                bottomLeadingRadius: leftConnected ? 0 : 2,
                                bottomTrailingRadius: rightConnected ? 0 : 2,
                                topTrailingRadius: rightConnected ? 0 : 2
                            )
                        )
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 12, height: 12)
                }
            }
        }
    }
    
    private func getPhase(for date: Date) -> WeightPhase? {
        return phaseManager.phases.first { phase in
            date >= phase.startDate && date <= phase.effectiveEndDate
        }
    }
    
    private func getPhaseForCell(row: Int, col: Int, monthIndex: Int, startingSpaces: Int, daysInMonth: Int) -> WeightPhase? {
        let cellIndex = row * 7 + col
        let dayNumber = cellIndex - startingSpaces + 1
        
        guard cellIndex >= startingSpaces && dayNumber <= daysInMonth else { return nil }
        guard let cellDate = calendar.date(from: DateComponents(year: currentYear, month: monthIndex + 1, day: dayNumber)) else { return nil }
        
        return getPhase(for: cellDate)
    }
    
    // Phase legend showing active phases for the year
    private var phaseLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phases")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            if displayedPhases.isEmpty {
                Text("No phases in \(String(currentYear))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(displayedPhases) { phase in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(phase.swiftUIColor)
                                .frame(width: 10, height: 10)
                            
                            Text(phase.name)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    EmbeddedYearCalendarView(
        selectedDate: .constant(Date())
    )
    .padding()
    .background(Color(.systemGray6))
}
