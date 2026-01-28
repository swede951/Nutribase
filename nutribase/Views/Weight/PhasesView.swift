//
//  PhasesView.swift
//  nutribase
//
//  Created on 14/08/2025.
//

import SwiftUI
import Charts

struct PhasesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var phaseManager = WeightPhaseManager.shared
    @StateObject private var weightManager = WeightLogManager.shared
    @State private var showingAddPhase = false
    @State private var selectedDate = Date()
    @State private var selectedPhaseForDetail: WeightPhase? = nil
    @State private var showingYearView = false
    
    private var viewBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    var body: some View {
        ZStack {
            // Background color to match dashboard
            viewBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // User phases with calendar at top
                ScrollView {
                    VStack(spacing: 24) {
                        // Calendar Carousel
                        CalendarCarouselView(selectedDate: $selectedDate, weightEntries: weightManager.weightEntries, phases: phaseManager.phases)
                            .padding(.top, -20)
                            .padding(.bottom, -28)
                        
                        // Year Overview with Weight Chart
                        EmbeddedYearCalendarView(
                            selectedDate: $selectedDate
                        )
                        .padding(.horizontal, UIScreen.main.bounds.width * 0.075)
                        
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
                .frame(maxWidth: .infinity)
                .background(viewBackground)
            }

        .sheet(isPresented: $showingAddPhase) {
            AddPhaseFlowView()
        }
        .sheet(item: $selectedPhaseForDetail) { phase in
            EditPhaseView(phase: phase)
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
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedDate: Date
    let weightEntries: [WeightLogEntry]
    let phases: [WeightPhase]
    
    // Performance: Use cached formatters and calendar
    private let performanceCache = PerformanceCache.shared
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    @State private var currentMonthOffset: Int = 0
    
    // Find the month offset for the current active phase
    private var activePhaseMonthOffset: Int {
        guard let activePhase = phases.first(where: { $0.isActive }) else {
            return 0 // Default to current month if no active phase
        }
        
        let currentDate = Date()
        let phaseStartDate = activePhase.startDate
        
        // Calculate month difference between current date and phase start
        let components = performanceCache.calendar.dateComponents([.month], from: phaseStartDate, to: currentDate)
        return components.month ?? 0
    }
    
    // Performance: Use cached calendar
    private var calendar: Calendar {
        performanceCache.calendar
    }
    
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
            .onAppear {
                // Scroll to active phase month immediately without animation
                let targetOffset = activePhaseMonthOffset
                proxy.scrollTo(targetOffset, anchor: .center)
                currentMonthOffset = targetOffset
            }
        }
    }
    
    // Create a month calendar card for a specific month offset
    private func monthCalendarCard(for offset: Int) -> some View {
        let currentMonth = calendar.date(byAdding: .month, value: offset, to: Date()) ?? Date()
        
        return VStack(spacing: 16) {
            // Month header - use cached formatter
            HStack {
                Text(performanceCache.formatMonthYear(currentMonth))
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
                                            
                                            // Performance: Use cached formatter
                                            Text(performanceCache.formatShortDate(date))
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
                .fill(cardBackground)
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
        let calendar = Calendar.current
        return phases.first { phase in
            let dateStart = calendar.startOfDay(for: date)
            let phaseStart = calendar.startOfDay(for: phase.startDate)
            let phaseEnd = calendar.startOfDay(for: phase.endDate)
            return dateStart >= phaseStart && dateStart <= phaseEnd
        }
    }
    
    private func getPhaseBackgroundColor(for date: Date) -> Color {
        guard let phase = getPhase(for: date) else {
            return Color.clear
        }
        return phase.swiftUIColor.opacity(0.3)
    }
    
    private func getWeekRows(for month: Date) -> [[Date?]] {
        // Performance: Use cached month grid
        return performanceCache.getMonthGrid(for: month)
    }
}

struct PhaseCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let phase: WeightPhase
    let onTap: () -> Void
    @StateObject private var weightManager = WeightLogManager.shared
    
    // Performance: Use cached formatters
    private let performanceCache = PerformanceCache.shared
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
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
            
            // Only calculate weekly rate if we have at least 7 days of data
            if totalDays >= 7 {
                let totalWeeks = Double(totalDays) / 7.0
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
            // If phase hasn't started or has insufficient data (< 7 days), show placeholder
            return "-- kg/week"
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
                
                // Date range - use cached formatter
                HStack {
                    Text("Duration:")
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(performanceCache.formatDate(phase.startDate)) - \(performanceCache.formatDate(phase.endDate))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                // Target rate
                HStack {
                    Text("Weekly rate:")
                        .font(.caption)
                        .foregroundColor(.primary)
                    
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
                        .foregroundColor(.primary)
                    
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
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
            
            // Phase Calendar Card
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                
                Text("Phase Calendar")
                    .font(.caption)
                    .foregroundColor(.primary)
                
                PhaseCalendarView(phase: phase)
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


// MARK: - Detail Card Component
struct DetailCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let icon: String
    let content: Content
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
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
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Phase Calendar View
struct PhaseCalendarView: View {
    @Environment(\.colorScheme) private var colorScheme
    let phase: WeightPhase
    @StateObject private var weightManager = WeightLogManager.shared
    
    // Performance: Use cached formatters and calendar
    private let performanceCache = PerformanceCache.shared
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    // Performance: Use cached calendar
    private var calendar: Calendar {
        performanceCache.calendar
    }
    
    private let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                             "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    
    // Get all months covered by this phase
    private var phaseMonths: [Date] {
        var months: [Date] = []
        let startDate = phase.startDate
        let endDate = phase.endDate
        
        var currentDate = calendar.dateInterval(of: .month, for: startDate)?.start ?? startDate
        
        while currentDate <= endDate {
            months.append(currentDate)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) else { break }
            currentDate = nextMonth
        }
        
        return months
    }
    
    var body: some View {
        let months = phaseMonths
        let rows = (months.count + 2) / 3 // Calculate rows needed for max 3 months per row
        
        VStack(spacing: 12) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { col in
                        let monthIndex = row * 3 + col
                        if monthIndex < months.count {
                            compactMonthView(for: months[monthIndex])
                                .frame(maxWidth: .infinity)
                        } else {
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
        )
    }
    
    private func compactMonthView(for monthDate: Date) -> some View {
        let monthIndex = calendar.component(.month, from: monthDate) - 1
        let _ = calendar.component(.year, from: monthDate)
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: monthDate)
        let startingSpaces = (firstWeekday == 1) ? 6 : firstWeekday - 2 // Monday = 0, Sunday = 6
        let totalCells = startingSpaces + daysInMonth
        let rows = (totalCells + 6) / 7 // Calculate number of rows needed
        
        let monthTitle = Text(monthNames[monthIndex])
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.primary)
            .frame(height: 16, alignment: .bottom)
        
        let calendarGrid = VStack(spacing: 2) {
            ForEach(Array(0..<rows), id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(Array(0..<7), id: \.self) { col in
                        dayCell(row: row, col: col, monthDate: monthDate, startingSpaces: startingSpaces, daysInMonth: daysInMonth)
                    }
                }
                .background(
                    phaseRowBackground(row: row, monthDate: monthDate, startingSpaces: startingSpaces, daysInMonth: daysInMonth)
                )
            }
        }
        .frame(height: CGFloat(rows * 12)) // Adjust height based on number of rows
        
        return VStack(spacing: 3) {
            monthTitle
            calendarGrid
        }
    }
    
    private func dayCell(row: Int, col: Int, monthDate: Date, startingSpaces: Int, daysInMonth: Int) -> some View {
        let cellIndex = row * 7 + col
        let dayNumber = cellIndex - startingSpaces + 1
        let year = calendar.component(.year, from: monthDate)
        let month = calendar.component(.month, from: monthDate)
        
        if cellIndex < startingSpaces || dayNumber > daysInMonth {
            return AnyView(
                Text("")
                    .frame(width: 12, height: 10)
            )
        } else {
            let dayDate = calendar.date(from: DateComponents(year: year, month: month, day: dayNumber)) ?? Date()
            let isToday = calendar.isDateInToday(dayDate)
            let hasWeightEntry = weightManager.allEntries.contains { entry in
                calendar.isDate(entry.date, inSameDayAs: dayDate)
            }
            
            let textColor: Color = isToday ? .white : .primary
            
            return AnyView(
                ZStack {
                    // Weight entry indicator (tiny dot)
                    if hasWeightEntry {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 2, height: 2)
                            .offset(x: 3, y: -3)
                    }
                    
                    Text("\(dayNumber)")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(textColor)
                }
                .frame(width: 12, height: 10)
            )
        }
    }
    
    private func phaseRowBackground(row: Int, monthDate: Date, startingSpaces: Int, daysInMonth: Int) -> some View {
        let year = calendar.component(.year, from: monthDate)
        let month = calendar.component(.month, from: monthDate)
        
        return HStack(spacing: 0) {
            ForEach(Array(0..<7), id: \.self) { col in
                let cellIndex = row * 7 + col
                let dayNumber = cellIndex - startingSpaces + 1
                
                if cellIndex >= startingSpaces && dayNumber <= daysInMonth {
                    let dayDate = calendar.date(from: DateComponents(year: year, month: month, day: dayNumber)) ?? Date()
                    
                    // Compare using date components to avoid timezone issues
                    let phaseStartComponents = calendar.dateComponents([.year, .month, .day], from: phase.startDate)
                    let phaseEndComponents = calendar.dateComponents([.year, .month, .day], from: phase.endDate)
                    
                    let dayValue = year * 10000 + month * 100 + dayNumber
                    let startValue = (phaseStartComponents.year ?? 0) * 10000 + (phaseStartComponents.month ?? 0) * 100 + (phaseStartComponents.day ?? 0)
                    let endValue = (phaseEndComponents.year ?? 0) * 10000 + (phaseEndComponents.month ?? 0) * 100 + (phaseEndComponents.day ?? 0)
                    
                    let isInPhase = dayValue >= startValue && dayValue <= endValue
                    let isToday = calendar.isDateInToday(dayDate)
                    
                    // Get adjacent day info for connected backgrounds
                    let leftInPhase = col > 0 ? isDayInPhase(row: row, col: col - 1, monthDate: monthDate, startingSpaces: startingSpaces, daysInMonth: daysInMonth) : false
                    let rightInPhase = col < 6 ? isDayInPhase(row: row, col: col + 1, monthDate: monthDate, startingSpaces: startingSpaces, daysInMonth: daysInMonth) : false
                    
                    let baseColor = isToday ? Color.blue : (isInPhase ? phase.swiftUIColor.opacity(0.3) : Color.clear)
                    
                    Rectangle()
                        .fill(baseColor)
                        .frame(width: 14.5, height: 10)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: (leftInPhase && isInPhase) ? 0 : 2,
                                bottomLeadingRadius: (leftInPhase && isInPhase) ? 0 : 2,
                                bottomTrailingRadius: (rightInPhase && isInPhase) ? 0 : 2,
                                topTrailingRadius: (rightInPhase && isInPhase) ? 0 : 2
                            )
                        )
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 14.5, height: 10)
                }
            }
        }
    }
    
    private func isDayInPhase(row: Int, col: Int, monthDate: Date, startingSpaces: Int, daysInMonth: Int) -> Bool {
        let cellIndex = row * 7 + col
        let dayNumber = cellIndex - startingSpaces + 1
        let year = calendar.component(.year, from: monthDate)
        let month = calendar.component(.month, from: monthDate)
        
        guard cellIndex >= startingSpaces && dayNumber <= daysInMonth else { return false }
        
        // Compare using date components to avoid timezone issues
        let phaseStartComponents = calendar.dateComponents([.year, .month, .day], from: phase.startDate)
        let phaseEndComponents = calendar.dateComponents([.year, .month, .day], from: phase.endDate)
        
        let dayValue = year * 10000 + month * 100 + dayNumber
        let startValue = (phaseStartComponents.year ?? 0) * 10000 + (phaseStartComponents.month ?? 0) * 100 + (phaseStartComponents.day ?? 0)
        let endValue = (phaseEndComponents.year ?? 0) * 10000 + (phaseEndComponents.month ?? 0) * 100 + (phaseEndComponents.day ?? 0)
        
        return dayValue >= startValue && dayValue <= endValue
    }
}

struct PhasesView_Previews: PreviewProvider {
    static var previews: some View {
        PhasesView()
    }
}
