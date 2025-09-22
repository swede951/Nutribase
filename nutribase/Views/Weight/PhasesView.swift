//
//  PhasesView.swift
//  nutribase
//
//  Created on 14/08/2025.
//

import SwiftUI
import Charts

struct PhasesView: View {
    @StateObject private var phaseManager = WeightPhaseManager.shared
    @StateObject private var weightManager = WeightLogManager.shared
    @State private var showingAddPhase = false
    @State private var selectedDate = Date()
    @State private var selectedPhaseForDetail: WeightPhase? = nil
    @State private var showingYearView = false
    
    var body: some View {
        ZStack {
            // Background color to match dashboard
            Color(hex: "#F0F1F4")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // User phases with calendar at top
                ScrollView {
                    VStack(spacing: 24) {
                        // Calendar Carousel
                        CalendarCarouselView(selectedDate: $selectedDate, weightEntries: weightManager.weightEntries, phases: phaseManager.phases)
                            .padding(.top, -20)
                            .padding(.bottom, -28)
                        
                        LazyVStack(spacing: 16) {
                            ForEach(phaseManager.phases.sorted { $0.startDate > $1.startDate }) { phase in
                                PhaseCardView(phase: phase) {
                                    selectedPhaseForDetail = phase
                                }
                                .frame(maxWidth: UIScreen.main.bounds.width * 0.9)
                            }
                            .onDelete(perform: deletePhases)
                            
                            if phaseManager.phases.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "calendar.badge.plus")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    
                                    Text("No Phases Yet")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("Add your first weight phase to start tracking your journey")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                    Button("Add Your First Phase") {
                                        showingAddPhase = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .padding(.top, 40)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                // Custom header to match Logbook styling
                ZStack {
                    // Left side - Calendar button
                    HStack {
                        Button(action: {
                            showingYearView = true
                        }) {
                            Image(systemName: "calendar")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                    
                    // Center - title
                    Text("Phases")
                        .font(.custom("Montserrat-Bold", size: 17))
                        .foregroundColor(.primary)
                    
                    // Right side - Add Phase button
                    HStack {
                        Spacer()
                        Button("Add Phase") {
                            showingAddPhase = true
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 1) // Reduced top padding
                .background(Color(hex: "#F0F1F4"))
            }

        .sheet(isPresented: $showingAddPhase) {
            AddPhaseView()
        }
        .sheet(item: $selectedPhaseForDetail) { phase in
            PhaseDetailView(phase: phase)
        }
        .sheet(isPresented: $showingYearView) {
            YearCalendarView(selectedDate: $selectedDate)
        }
    }
    
    func deletePhases(offsets: IndexSet) {
        phaseManager.deletePhase(at: offsets)
    }
}

// Calendar carousel component for phases view
struct CalendarCarouselView: View {
    @Binding var selectedDate: Date
    let weightEntries: [WeightLogEntry]
    let phases: [WeightPhase]
    
    @State private var currentMonthOffset: Int = 0
    
    private var calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday = 2, Sunday = 1
        return cal
    }()
    
    // Month formatter
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    // Day formatter
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    init(selectedDate: Binding<Date>, weightEntries: [WeightLogEntry], phases: [WeightPhase]) {
        self._selectedDate = selectedDate
        self.weightEntries = weightEntries
        self.phases = phases
    }
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        
        // Month carousel with snap behavior
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    // Generate month cards: past 12 months to future 12 months
                    ForEach(-12...12, id: \.self) { offset in
                        monthCalendarCard(for: offset)
                            .frame(width: screenWidth * 0.85, height: 400)
                            .fixedSize()
                            .id(offset)
                    }
                }
                .padding(.horizontal, screenWidth * 0.075)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .defaultScrollAnchor(.center)
            .onScrollTargetVisibilityChange(idType: Int.self) { visibleIDs in
                if let centerID = visibleIDs.first {
                    currentMonthOffset = centerID
                }
            }
            .frame(height: 420)
        }
    }
    
    // Create a month calendar card for a specific month offset
    private func monthCalendarCard(for offset: Int) -> some View {
        let currentMonth = calendar.date(byAdding: .month, value: offset, to: Date()) ?? Date()
        
        return VStack(spacing: 16) {
            // Month header
            HStack {
                Text(monthFormatter.string(from: currentMonth))
                    .font(.custom("Montserrat-SemiBold", size: 17))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Days of week header
            HStack(spacing: 0) {
                ForEach(getDaysOfWeek(), id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid with joined phase backgrounds (fixed height)
            VStack(spacing: 0) {
                // Ensure exactly 6 rows for consistent height
                ForEach(0..<6, id: \.self) { weekIndex in
                    let weekRows = getWeekRows(for: currentMonth)
                    let weekDates = weekIndex < weekRows.count ? weekRows[weekIndex] : Array(repeating: nil, count: 7)
                    ZStack {
                        // Phase background strips for the week
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { dayIndex in
                                let date = weekDates[dayIndex]
                                let phase = date != nil ? getPhase(for: date!) : nil
                                let prevPhase = dayIndex > 0 && weekDates[dayIndex - 1] != nil ? getPhase(for: weekDates[dayIndex - 1]!) : nil
                                let nextPhase = dayIndex < 6 && weekDates[dayIndex + 1] != nil ? getPhase(for: weekDates[dayIndex + 1]!) : nil
                                
                                let shouldJoinLeft = phase != nil && prevPhase != nil && phase!.id == prevPhase!.id
                                let shouldJoinRight = phase != nil && nextPhase != nil && phase!.id == nextPhase!.id
                                
                                ZStack {
                                    if let phase = phase {
                                        // Create joined background based on adjacent phases
                                        if shouldJoinLeft && shouldJoinRight {
                                            // Middle of a group - rectangle with no rounding
                                            Rectangle()
                                                .fill(phase.swiftUIColor.opacity(0.2))
                                                .frame(height: 32)
                                        } else if shouldJoinLeft {
                                            // End of a group - rounded on right only
                                            UnevenRoundedRectangle(cornerRadii: .init(
                                                topLeading: 0, bottomLeading: 0,
                                                bottomTrailing: 16, topTrailing: 16
                                             ))
                                             .fill(phase.swiftUIColor.opacity(0.2))
                                             .frame(height: 32)
                                        } else if shouldJoinRight {
                                            // Start of a group - rounded on left only
                                            UnevenRoundedRectangle(cornerRadii: .init(
                                                topLeading: 16, bottomLeading: 16,
                                                bottomTrailing: 0, topTrailing: 0
                                            ))
                                            .fill(phase.swiftUIColor.opacity(0.2))
                                            .frame(height: 32)
                                        } else {
                                            // Single date - fully rounded
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(phase.swiftUIColor.opacity(0.2))
                                                .frame(width: 28, height: 32)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        
                        // Date buttons overlay
                        HStack(spacing: 8) {
                            ForEach(0..<7, id: \.self) { dayIndex in
                                if let date = weekDates[dayIndex] {
                                    let hasEntry = hasWeightEntry(for: date)
                                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                                    let isToday = calendar.isDateInToday(date)
                                    let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
                                    
                                    Button(action: {
                                        selectedDate = date
                                    }) {
                                        ZStack {
                                            // Weight entry indicator (small dot)
                                            if hasEntry {
                                                Circle()
                                                    .fill(Color.blue)
                                                    .frame(width: 6, height: 6)
                                                    .offset(x: 8, y: -8)
                                            }
                                            
                                            // Today indicator
                                            if isToday {
                                                Circle()
                                                    .stroke(Color.blue, lineWidth: 2)
                                                    .frame(width: 32, height: 32)
                                            }
                                            
                                            // Selected date indicator
                                            if isSelected {
                                                Circle()
                                                    .fill(Color.blue)
                                                    .frame(width: 32, height: 32)
                                            }
                                            
                                            Text(dayFormatter.string(from: date))
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(isSelected ? .white : (isCurrentMonth ? .primary : .secondary))
                                        }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else {
                                    // Empty space for dates not in current month
                                    Color.clear
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                        }
                        .frame(height: 40)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Helper Methods
    private func getDaysOfWeek() -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        var symbols = formatter.shortWeekdaySymbols!
        // Rearrange to start with Monday (move Sunday from index 0 to end)
        let sunday = symbols.removeFirst()
        symbols.append(sunday)
        return symbols
    }
    
    private func getDaysInMonth(for month: Date) -> [Date?] {
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
        
        // Fill remaining slots to complete the current week only
        let totalSlots = ((days.count + 6) / 7) * 7  // Round up to nearest week
        while days.count < totalSlots {
            days.append(nil)
        }
        
        return days
    }
    
    private func hasWeightEntry(for date: Date) -> Bool {
        return weightEntries.contains { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }
    }
    
    private func getPhase(for date: Date) -> WeightPhase? {
        return phases.first { phase in
            date >= phase.startDate && date <= phase.endDate
        }
    }
    
    private func getPhaseBackgroundColor(for date: Date) -> Color {
        guard let phase = getPhase(for: date) else {
            return Color.clear
        }
        return phase.swiftUIColor.opacity(0.3)
    }
    
    private func getWeekRows(for month: Date) -> [[Date?]] {
        let days = getDaysInMonth(for: month)
        var weeks: [[Date?]] = []
        
        for i in stride(from: 0, to: days.count, by: 7) {
            let weekEnd = min(i + 7, days.count)
            let week = Array(days[i..<weekEnd])
            
            // Pad week to 7 days if needed
            var paddedWeek = week
            while paddedWeek.count < 7 {
                paddedWeek.append(nil)
            }
            
            weeks.append(paddedWeek)
        }
        
        return weeks
    }
}

struct PhaseCardView: View {
    let phase: WeightPhase
    let onTap: () -> Void
    @StateObject private var weightManager = WeightLogManager.shared
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    // Get weight entries for this phase period
    private var phaseWeightEntries: [WeightLogEntry] {
        weightManager.allEntries.filter { entry in
            entry.date >= phase.startDate && entry.date <= phase.endDate
        }.sorted { $0.date < $1.date }
    }
    
    // Calculate actual weekly rate for the phase
    private var actualWeeklyRate: Double? {
        // If phase hasn't started yet, return nil
        if Date() < phase.startDate || phaseWeightEntries.count < 2 {
            return nil
        }
        
        // Calculate average change per week
        if let firstDate = phaseWeightEntries.first?.date,
           let lastDate = phaseWeightEntries.last?.date,
           let firstWeight = phaseWeightEntries.first?.weight,
           let lastWeight = phaseWeightEntries.last?.weight {
            
            let totalDays = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
            let totalWeeks = Double(totalDays) / 7.0
            
            if totalWeeks > 0 {
                let totalChange = lastWeight - firstWeight
                return totalChange / totalWeeks
            }
        }
        
        return nil
    }
    
    // Format the weekly rate for display
    private var formattedWeeklyRate: String {
        if let rate = actualWeeklyRate {
            let sign = rate >= 0 ? "+" : ""
            return "\(sign)\(String(format: "%.2f", rate)) kg/week"
        } else {
            // If phase hasn't started or has no data, show target rate or 0
            return phase.formattedTargetRate
        }
    }
    
    // Determine color for weekly rate
    private var weeklyRateColor: Color {
        if let rate = actualWeeklyRate {
            return rate < 0 ? .green : rate > 0 ? .red : .blue
        } else {
            return phase.targetWeeklyRate < 0 ? .green : phase.targetWeeklyRate > 0 ? .red : .blue
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(phase.name)
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Active indicator
                if phase.isActive {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(phase.swiftUIColor)
                            .frame(width: 12, height: 12)
                        
                        Text("Active")
                            .font(.caption)
                            .foregroundColor(phase.swiftUIColor)
                    }
                }
            }
            
            // Phase details
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                
                // Date range
                HStack {
                    Text("Duration:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(dateFormatter.string(from: phase.startDate)) - \(dateFormatter.string(from: phase.endDate))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                // Target rate
                HStack {
                    Text("Weekly rate:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formattedWeeklyRate)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(weeklyRateColor)
                }
                
                // Duration in weeks
                HStack {
                    Text("Length:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(phase.durationInWeeks) weeks")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                // Notes if available
                if let notes = phase.notes, !notes.isEmpty {
                    HStack {
                        Text("Notes:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(phase.swiftUIColor.opacity(0.15))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Phase Detail View
struct PhaseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var phaseManager = WeightPhaseManager.shared
    @StateObject private var weightManager = WeightLogManager.shared
    let phase: WeightPhase
    
    @State private var showingDeleteAlert = false
    @State private var showingEditView = false
    @State private var refreshChart = false
    
    // Get weight entries for this phase period
    private var phaseWeightEntries: [WeightLogEntry] {
        // Get the current phase from the manager to ensure we have the latest data
        guard let currentPhase = phaseManager.phases.first(where: { $0.id == phase.id }) else {
            return weightManager.allEntries.filter { entry in
                entry.date >= phase.startDate && entry.date <= phase.endDate
            }.sorted { $0.date < $1.date }
        }
        
        return weightManager.allEntries.filter { entry in
            entry.date >= currentPhase.startDate && entry.date <= currentPhase.endDate
        }.sorted { $0.date < $1.date }
    }
    
    // Calculate phase statistics
    private var phaseStats: (highest: Double?, lowest: Double?, averageChange: Double?, totalChange: Double?) {
        guard !phaseWeightEntries.isEmpty else {
            return (nil, nil, nil, nil)
        }
        
        let weights = phaseWeightEntries.map { $0.weight }
        let highest = weights.max()
        let lowest = weights.min()
        
        // Calculate average change per week
        let averageChange: Double?
        if phaseWeightEntries.count > 1,
           let firstDate = phaseWeightEntries.first?.date,
           let lastDate = phaseWeightEntries.last?.date,
           let firstWeight = phaseWeightEntries.first?.weight,
           let lastWeight = phaseWeightEntries.last?.weight {
            
            let totalDays = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
            let totalWeeks = Double(totalDays) / 7.0
            
            if totalWeeks > 0 {
                let totalChange = lastWeight - firstWeight
                averageChange = totalChange / totalWeeks
            } else {
                averageChange = nil
            }
        } else {
            averageChange = nil
        }
        
        let totalChange: Double?
        if let firstWeight = phaseWeightEntries.first?.weight,
           let lastWeight = phaseWeightEntries.last?.weight {
            totalChange = lastWeight - firstWeight
        } else {
            totalChange = nil
        }
        
        return (highest, lowest, averageChange, totalChange)
    }
    
    // Calculate goal weight based on phase target
    private var goalWeight: Double? {
        // Get the current phase from the manager to ensure we have the latest data
        guard let currentPhase = phaseManager.phases.first(where: { $0.id == phase.id }) else { return nil }
        
        // Use stored goal weight if available, otherwise calculate from weekly rate
        if let storedGoalWeight = currentPhase.goalWeight {
            return storedGoalWeight
        }
        
        guard let firstEntry = phaseWeightEntries.first else { return nil }
        let startWeight = firstEntry.weight
        let phaseDurationWeeks = Double(currentPhase.durationInWeeks)
        let totalTargetChange = currentPhase.targetWeeklyRate * phaseDurationWeeks
        return startWeight + totalTargetChange
    }
    
    // Calculate Y-axis range for the chart (including goal weight)
    private var yAxisRange: ClosedRange<Double> {
        guard !phaseWeightEntries.isEmpty else { return 0...100 }
        
        let weights = phaseWeightEntries.map { $0.weight }
        var minWeight = weights.min() ?? 0
        var maxWeight = weights.max() ?? 100
        
        // Include goal weight in range calculation
        if let goal = goalWeight {
            minWeight = min(minWeight, goal)
            maxWeight = max(maxWeight, goal)
        }
        
        // Add padding above and below
        let range = maxWeight - minWeight
        let padding = max(range * 0.1, 1.0) // At least 1kg padding
        
        return (minWeight - padding)...(maxWeight + padding)
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color to match dashboard
                Color(hex: "#F0F1F4")
                    .ignoresSafeArea()
                
                ScrollView {
                VStack(spacing: 24) {
                    // Header with phase name and status
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Text(phaseManager.phases.first(where: { $0.id == phase.id })?.name ?? phase.name)
                                    .font(.custom("Montserrat-Bold", size: 24))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                
                                // Phase color indicator after the title
                                Circle()
                                    .fill(phaseManager.phases.first(where: { $0.id == phase.id })?.swiftUIColor ?? phase.swiftUIColor)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                                    .shadow(color: (phaseManager.phases.first(where: { $0.id == phase.id })?.swiftUIColor ?? phase.swiftUIColor).opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            
                            if phase.isActive {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("Currently Active")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.1))
                                )
                            }
                        }
                    }
                    .padding(.top)
                    
                    // Duration Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Duration")
                            .font(.title2)
                            .fontWeight(.semibold)
                        .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Start Date:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(dateFormatter.string(from: phaseManager.phases.first(where: { $0.id == phase.id })?.startDate ?? phase.startDate))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                Text("End Date:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(dateFormatter.string(from: phaseManager.phases.first(where: { $0.id == phase.id })?.endDate ?? phase.endDate))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                Text("Total Length:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                let currentPhase = phaseManager.phases.first(where: { $0.id == phase.id }) ?? phase
                                let totalWeeks = Calendar.current.dateComponents([.weekOfYear], from: currentPhase.startDate, to: currentPhase.endDate).weekOfYear ?? 0
                                Text("\(totalWeeks) weeks")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Weight Chart Section
                    if !phaseWeightEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Weight Progress")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            // Weight Chart
                            Chart {
                                ForEach(phaseWeightEntries, id: \.id) { entry in
                                    LineMark(
                                        x: .value("Date", entry.date),
                                        y: .value("Weight", entry.weight)
                                    )
                                    .foregroundStyle(.blue)
                                    .lineStyle(StrokeStyle(lineWidth: 3))
                                    .interpolationMethod(.catmullRom)
                                }
                                
                                // Goal weight line (horizontal dashed line)
                                if let goal = goalWeight {
                                    RuleMark(
                                        y: .value("Goal Weight", goal)
                                    )
                                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                                    .foregroundStyle((phaseManager.phases.first(where: { $0.id == phase.id })?.swiftUIColor ?? phase.swiftUIColor).opacity(0.7))
                                    .annotation(position: .overlay, alignment: .center) {
                                        Text("Goal Weight")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(phaseManager.phases.first(where: { $0.id == phase.id })?.swiftUIColor ?? phase.swiftUIColor)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color(.systemBackground))
                                            )
                                    }
                                }
                            }
                            .frame(height: 200)
                            .chartYScale(domain: yAxisRange)
                            .chartXScale(domain: (phaseManager.phases.first(where: { $0.id == phase.id })?.startDate ?? phase.startDate)...(phaseManager.phases.first(where: { $0.id == phase.id })?.endDate ?? phase.endDate))
                            .id(refreshChart)
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading, values: .stride(by: 1.0)) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel()
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                            )
                            .padding(.horizontal)
                        }
                        
                        // Weight Statistics
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Statistics")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                // Highest Weight
                                if let highest = phaseStats.highest {
                                    StatCard(
                                        title: "Highest Weight",
                                        value: String(format: "%.1f kg", highest),
                                        color: .red
                                    )
                                }
                                
                                // Lowest Weight
                                if let lowest = phaseStats.lowest {
                                    StatCard(
                                        title: "Lowest Weight",
                                        value: String(format: "%.1f kg", lowest),
                                        color: .green
                                    )
                                }
                                
                                // Weekly Rate (always show, default to 0.0 if no data)
                                let averageChange = phaseStats.averageChange ?? 0.0
                                let changeText = averageChange >= 0 ? "+" + String(format: "%.2f kg/week", averageChange) : String(format: "%.2f kg/week", averageChange)
                                let changeColor: Color = averageChange >= 0 ? .red : .green
                                StatCard(
                                    title: "Weekly Rate",
                                    value: changeText,
                                    color: changeColor
                                )
                                
                                // Total Change
                                if let totalChange = phaseStats.totalChange {
                                    let changeText = totalChange >= 0 ? "+" + String(format: "%.1f kg", totalChange) : String(format: "%.1f kg", totalChange)
                                    let changeColor: Color = totalChange >= 0 ? .red : .green
                                    StatCard(
                                        title: "Total Change",
                                        value: changeText,
                                        color: changeColor
                                    )
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    // Phase Details Cards
                    VStack(spacing: 16) {
                        
                        
                        // Progress Card (if active)
                        if phase.isActive {
                            DetailCard(title: "Progress", icon: "chart.line.uptrend.xyaxis") {
                                VStack(alignment: .leading, spacing: 8) {
                                    let daysElapsed = Calendar.current.dateComponents([.day], from: phase.startDate, to: Date()).day ?? 0
                                    let totalDays = Calendar.current.dateComponents([.day], from: phase.startDate, to: phase.endDate).day ?? 1
                                    let progress = min(Double(daysElapsed) / Double(totalDays), 1.0)
                                    
                                    HStack {
                                        Text("Days Completed:")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(daysElapsed) / \(totalDays)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    
                                    ProgressView(value: progress)
                                        .progressViewStyle(LinearProgressViewStyle(tint: phase.swiftUIColor))
                                    
                                    HStack {
                                        Text("Progress:")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(String(format: "%.1f%%", progress * 100))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(phase.swiftUIColor)
                                    }
                                }
                            }
                        }
                        
                        // Notes Card (if available)
                        if let notes = phase.notes, !notes.isEmpty {
                            DetailCard(title: "Notes", icon: "note.text") {
                                Text(notes)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
            }
            }
            .navigationTitle("Phase Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditView = true
                    }
                    .foregroundColor(.blue)
                }
            }
            .sheet(isPresented: $showingEditView) {
                EditPhaseView(phase: phase)
            }
            .onReceive(phaseManager.$phases) { _ in
                refreshChart.toggle()
            }
        }
    }
    
    private func deletePhase() {
        phaseManager.deletePhase(phase)
        dismiss()
    }
    
    private var phaseTypeDescription: String {
        if phase.targetWeeklyRate < 0 {
            return "This is a cutting phase focused on fat loss. Maintain a caloric deficit while preserving muscle mass through resistance training."
        } else if phase.targetWeeklyRate > 0 {
            return "This is a bulking phase focused on muscle gain. Maintain a caloric surplus with adequate protein intake for optimal muscle growth."
        } else {
            return "This is a maintenance phase focused on maintaining current weight and body composition while building strength and habits."
        }
    }
}

// MARK: - Detail Card Component
struct DetailCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text(title)
                    .font(.custom("Montserrat-SemiBold", size: 16))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

struct PhasesView_Previews: PreviewProvider {
    static var previews: some View {
        PhasesView()
    }
}
