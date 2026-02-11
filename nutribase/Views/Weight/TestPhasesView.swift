//
//  TestPhasesView.swift
//  nutribase
//
//  Created on 22/09/2025.
//

import SwiftUI
import Charts

struct TestPhasesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var phaseManager = WeightPhaseManager.shared
    @StateObject private var weightManager = WeightLogManager.shared
    @State private var showingAddPhase = false
    @State private var selectedDate = Date()
    @State private var selectedPhaseForEdit: WeightPhase? = nil
    @State private var showingYearView = false
    @State private var refreshTrigger = UUID()
    
    // Dashboard-matching colors
    private var scrollBackground: Color {
        Color.appBackground
    }
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    var body: some View {
        ZStack {
            // Solid background color
            scrollBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // User phases with calendar at top
                ScrollView {
                    VStack(spacing: 8) {
                        // Phase Carousel
                        PhaseCarouselView(phases: phaseManager.phases.sorted { $0.startDate < $1.startDate }) { phase in
                            selectedPhaseForEdit = phase
                        }
                        .id(refreshTrigger)
                        .padding(.top, 20)
                        .padding(.bottom, 0)
                        
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
                                .foregroundColor(.primary)
                        }
                        Spacer()
                    }
                    
                    // Center - title
                    Text("Phases")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                    
                    // Right side - Add Phase button
                    HStack {
                        Spacer()
                        Button("Add Phase") {
                            showingAddPhase = true
                        }
                        .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 1) // Reduced top padding
                .frame(maxWidth: .infinity)
                .background(scrollBackground)
            }

        .sheet(isPresented: $showingAddPhase) {
            AddPhaseFlowView()
        }
        .sheet(item: $selectedPhaseForEdit) { phase in
            EditPhaseView(phase: phase)
                .onDisappear {
                    // Reset selected phase when edit view dismisses
                    selectedPhaseForEdit = nil
                    // Force refresh by generating new UUID
                    refreshTrigger = UUID()
                }
        }
        .sheet(isPresented: $showingYearView) {
            YearCalendarView(selectedDate: $selectedDate)
        }
    }
    
    func deletePhases(offsets: IndexSet) {
        phaseManager.deletePhase(at: offsets)
    }
}

// Phase carousel component for phases view
struct PhaseCarouselView: View {
    let phases: [WeightPhase]
    let onPhaseTap: (WeightPhase) -> Void
    @ObservedObject private var weightManager = WeightLogManager.shared
    @State private var currentPhaseIndex: Int
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    init(phases: [WeightPhase], onPhaseTap: @escaping (WeightPhase) -> Void) {
        self.phases = phases
        self.onPhaseTap = onPhaseTap
        // Initialize to active phase or last phase
        if let activeIndex = phases.firstIndex(where: { $0.isActive }) {
            _currentPhaseIndex = State(initialValue: activeIndex)
        } else if !phases.isEmpty {
            _currentPhaseIndex = State(initialValue: phases.count - 1)
        } else {
            _currentPhaseIndex = State(initialValue: 0)
        }
    }
    
    // Find the active phase index
    private var activePhaseIndex: Int? {
        phases.firstIndex { $0.isActive }
    }
    
    // Get the current phase based on the visible index
    private var currentPhase: WeightPhase? {
        guard currentPhaseIndex < phases.count else { return nil }
        return phases[currentPhaseIndex]
    }
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        
        if phases.isEmpty {
            // Empty state handled by parent view
            EmptyView()
        } else {
            VStack(spacing: 12) {
                // Phase carousel with snap behavior
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                                PhaseCarouselCard(phase: phase, onTap: { onPhaseTap(phase) })
                                    .frame(width: screenWidth * 0.85)
                                    .id(phase.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, screenWidth * 0.075, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .onScrollTargetVisibilityChange(idType: UUID.self) { visibleIDs in
                        if let centerPhaseID = visibleIDs.first,
                           let phaseIndex = phases.firstIndex(where: { $0.id == centerPhaseID }) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPhaseIndex = phaseIndex
                            }
                        }
                    }
                    .task(id: phases.first?.id) {
                        // Wait for layout to complete, then scroll to active phase
                        try? await Task.sleep(for: .milliseconds(100))
                        // Find active phase directly to avoid State initialization issues
                        if let activeIndex = phases.firstIndex(where: { $0.isActive }) {
                            proxy.scrollTo(phases[activeIndex].id, anchor: .center)
                        } else if !phases.isEmpty {
                            // Fall back to last phase if no active
                            proxy.scrollTo(phases[phases.count - 1].id, anchor: .center)
                        }
                    }
                }
                
                // Phase Calendar underneath that fades in/out
                if let phase = currentPhase {
                    VStack(spacing: 8) {
                        TestPhaseCalendarView(phase: phase)
                        
                        // Weight Progress Chart
                        TestPhaseWeightChartView(phase: phase)
                        
                        // Rate of Change Chart - Commented out for now
                        // TestPhaseRateOfChangeView(phase: phase)
                        
                        // Statistics Section
                        TestPhaseStatisticsView(phase: phase)
                        
                        // Overview Section
                        TestPhaseOverviewView(phase: phase)
                            .padding(.bottom, 16)
                    }
                    .frame(width: UIScreen.main.bounds.width - 32)
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.25), value: phase.id)
                }
            }
        }
    }
}

// Individual phase card for the carousel - using original PhaseCardView styling
struct PhaseCarouselCard: View {
    let phase: WeightPhase
    let onTap: () -> Void
    @ObservedObject private var weightManager = WeightLogManager.shared
    
    @State private var cachedPhaseEntries: [WeightLogEntry] = []
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    // Get weight entries for this phase period
    private var phaseWeightEntries: [WeightLogEntry] {
        // If cache is empty, compute immediately for initial render
        if cachedPhaseEntries.isEmpty {
            return weightManager.weightEntries
                .filter { $0.date >= phase.startDate && $0.date <= phase.effectiveEndDate }
                .sorted { $0.date < $1.date }
        }
        return cachedPhaseEntries
    }
    
    private func recomputeEntries() {
        cachedPhaseEntries = weightManager.weightEntries
            .filter { $0.date >= phase.startDate && $0.date <= phase.effectiveEndDate }
            .sorted { $0.date < $1.date }
    }
    
    // Calculate actual weekly rate for the phase
    private var actualWeeklyRate: Double? {
        // If phase hasn't started yet, return nil
        if Date() < phase.startDate || phaseWeightEntries.count < 2 {
            return nil
        }
        
        // Calculate total change divided by elapsed weeks in phase
        if let firstWeight = phaseWeightEntries.first?.weight,
           let lastWeight = phaseWeightEntries.last?.weight {
            
            // Calculate elapsed days from first entry to last entry
            let daysDifference = Calendar.current.dateComponents([.day], from: phaseWeightEntries.first!.date, to: phaseWeightEntries.last!.date).day ?? 0
            
            // Only calculate weekly rate if we have at least 7 days of data (matches statistics section)
            if daysDifference >= 7 {
                let weeksDifference = Double(daysDifference) / 7.0
                let totalChange = lastWeight - firstWeight
                return totalChange / weeksDifference
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
            // If insufficient data (<7 days), show placeholder (matches statistics section)
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
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Active indicator
                if phase.isActive {
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.primary)
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
                    
                    Text("\(dateFormatter.string(from: phase.startDate)) - \(dateFormatter.string(from: phase.effectiveEndDate))")
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
                
            }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(phase.swiftUIColor.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(phase.swiftUIColor.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .buttonStyle(PlainButtonStyle())
        .onAppear(perform: recomputeEntries)
        .onChange(of: weightManager.allEntries.count) { _, _ in
            recomputeEntries()
        }
        .onChange(of: phase.startDate) { _, _ in
            recomputeEntries()
        }
        .onChange(of: phase.endDate) { _, _ in
            recomputeEntries()
        }
    }
}

// MARK: - Test Phase Calendar View
struct TestPhaseCalendarView: View {
    @Environment(\.colorScheme) private var colorScheme
    let phase: WeightPhase
    @ObservedObject private var weightManager = WeightLogManager.shared
    @State private var isExpanded: Bool = false
    @State private var cachedEntryDaySet: Set<DateComponents> = []
    @State private var cachedMonths: [Date] = []
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    // Cached calendar instance (avoids recreating on every property access)
    private static let mondayFirstCalendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday first
        return cal
    }()
    
    private var calendar: Calendar { Self.mondayFirstCalendar }
    
    private let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                             "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    
    // Use cached set for O(1) lookup
    private var weightEntryDaySet: Set<DateComponents> {
        return cachedEntryDaySet
    }
    
    // Use cached months
    private var phaseMonths: [Date] {
        return cachedMonths
    }
    
    private func recomputeCalendarData() {
        let cal = Self.mondayFirstCalendar
        
        // Compute entry day set
        let entriesInPhase = weightManager.allEntries.filter {
            $0.date >= phase.startDate && $0.date <= phase.effectiveEndDate
        }
        cachedEntryDaySet = Set(
            entriesInPhase.map {
                cal.dateComponents([.year, .month, .day], from: $0.date)
            }
        )
        
        // Compute months
        var months: [Date] = []
        let startDate = phase.startDate
        let endDate = phase.effectiveEndDate
        var currentDate = cal.dateInterval(of: .month, for: startDate)?.start ?? startDate
        while currentDate <= endDate {
            months.append(currentDate)
            guard let nextMonth = cal.date(byAdding: .month, value: 1, to: currentDate) else { break }
            currentDate = nextMonth
        }
        cachedMonths = months
    }
    
    var body: some View {
        let months = phaseMonths
        let rows = (months.count + 2) / 3 // Calculate rows needed for max 3 months per row
        let hasMultipleRows = rows > 1
        
        VStack(alignment: .leading, spacing: 8) {
            // Header outside the card (like Weight Progress)
            HStack {
                Text("Phase Calendar")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.leading, 14)
                
                if hasMultipleRows {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if hasMultipleRows {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }
            }
            
            // Calendar card
            VStack(alignment: .leading, spacing: 4) {
                // Calendar grid - show only first row when collapsed
                ForEach(0..<(isExpanded || !hasMultipleRows ? rows : 1), id: \.self) { row in
                    HStack(alignment: .top, spacing: 8) {
                        // Only render months that exist in this row
                        let startIndex = row * 3
                        let endIndex = min(startIndex + 3, months.count)
                        
                        ForEach(startIndex..<endIndex, id: \.self) { monthIndex in
                            compactMonthView(for: months[monthIndex])
                                .scaleEffect(0.85)
                        }
                        
                        // Add trailing spacer to push content left
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        }
        .onAppear {
            recomputeCalendarData()
        }
        .onChange(of: phase.id) { _, _ in
            recomputeCalendarData()
        }
        .onChange(of: weightManager.allEntries.count) { _, _ in
            recomputeCalendarData()
        }
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
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.primary)
        
        let calendarGrid = VStack(spacing: 2) {
            ForEach(Array(0..<rows), id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(Array(0..<7), id: \.self) { col in
                        dayCell(row: row, col: col, monthDate: monthDate, startingSpaces: startingSpaces, daysInMonth: daysInMonth)
                    }
                }
                .background(
                    phaseRowBackground(row: row, monthDate: monthDate, startingSpaces: startingSpaces, daysInMonth: daysInMonth)
                )
            }
        }
        
        return VStack(alignment: .center, spacing: 8) {
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
                    .frame(width: 14, height: 14)
            )
        } else {
            let dayDate = calendar.date(from: DateComponents(year: year, month: month, day: dayNumber)) ?? Date()
            let components = calendar.dateComponents([.year, .month, .day], from: dayDate)
            
            let isToday = calendar.isDateInToday(dayDate)
            let hasWeightEntry = weightEntryDaySet.contains(components)
            
            let textColor: Color = isToday ? .white : .primary
            
            return AnyView(
                ZStack {
                    // Weight entry indicator (small dot)
                    if hasWeightEntry {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 3, height: 3)
                            .offset(x: 4, y: -4)
                    }
                    
                    Text("\(dayNumber)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(textColor)
                        .frame(width: 14, height: 14)
                }
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
                    let isInPhase = dayDate >= phase.startDate && dayDate <= phase.effectiveEndDate
                    let isToday = calendar.isDateInToday(dayDate)
                    
                    // Get adjacent day info for connected backgrounds
                    let leftInPhase = col > 0 ? isDayInPhase(row: row, col: col - 1, monthDate: monthDate, startingSpaces: startingSpaces, daysInMonth: daysInMonth) : false
                    let rightInPhase = col < 6 ? isDayInPhase(row: row, col: col + 1, monthDate: monthDate, startingSpaces: startingSpaces, daysInMonth: daysInMonth) : false
                    
                    let baseColor = isToday ? Color.blue : (isInPhase ? phase.swiftUIColor.opacity(0.6) : Color.clear)
                    
                    Rectangle()
                        .fill(baseColor)
                        .frame(width: 16, height: 14)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: (leftInPhase && isInPhase) ? 0 : 3,
                                bottomLeadingRadius: (leftInPhase && isInPhase) ? 0 : 3,
                                bottomTrailingRadius: (rightInPhase && isInPhase) ? 0 : 3,
                                topTrailingRadius: (rightInPhase && isInPhase) ? 0 : 3
                            )
                        )
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16, height: 14)
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
        guard let cellDate = calendar.date(from: DateComponents(year: year, month: month, day: dayNumber)) else { return false }
        
        return cellDate >= phase.startDate && cellDate <= phase.effectiveEndDate
    }
}

// MARK: - Test Phase Weight Chart View
struct TestPhaseWeightChartView: View {
    @Environment(\.colorScheme) private var colorScheme
    let phase: WeightPhase
    @ObservedObject private var weightManager = WeightLogManager.shared
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    @State private var cachedPhaseEntries: [WeightLogEntry] = []
    @State private var cachedSmoothedEntries: [WeightLogEntry] = []
    @State private var cachedPredictionEntries: [WeightLogEntry] = []
    @State private var isComputing: Bool = false
    
    // Per-phase chart data cache
    private let chartCache = PhaseDataCache.shared
    
    // Crosshair interaction
    @State private var selectedIndex: Int? = nil
    @State private var lastSelectedIndex: Int? = nil
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    
    // Hash of current weight entries for cache validation
    private var currentEntriesHash: Int {
        weightManager.allEntries.count
    }
    
    // Dynamic chart end date: show full year when data covers it,
    // otherwise cap at latest data + padding so the line fills the chart width.
    // Start interpolation ensures the line connects from the previous year.
    private var chartEndDate: Date {
        let calendar = Calendar.current
        let phaseDays = calendar.dateComponents([.day], from: phase.startDate, to: phase.endDate).day ?? 0
        
        // Only apply dynamic end for phases longer than 3 months
        guard phaseDays > 90 else { return phase.endDate }
        
        // Find latest data point across smoothed and raw entries
        let latestSmoothed = cachedSmoothedEntries.last?.date
        let latestRaw = phaseWeightEntries.last?.date
        let latestData = [latestSmoothed, latestRaw].compactMap { $0 }.max()
        
        guard let latest = latestData else { return phase.endDate }
        
        // If data covers more than 80% of the phase, show the full phase
        let dataDays = calendar.dateComponents([.day], from: phase.startDate, to: latest).day ?? 0
        if Double(dataDays) / Double(phaseDays) > 0.8 { return phase.endDate }
        
        // Add padding: ~15% of data range or 2 weeks, whichever is larger
        let paddingDays = max(Int(Double(dataDays) * 0.15), 14)
        let paddedEnd = calendar.date(byAdding: .day, value: paddingDays, to: latest) ?? phase.endDate
        
        return min(paddedEnd, phase.endDate)
    }
    
    // Get weight entries for this phase
    private var phaseWeightEntries: [WeightLogEntry] {
        // If cache is empty, compute immediately for initial render
        if cachedPhaseEntries.isEmpty {
            return weightManager.allEntries
                .filter { $0.date >= phase.startDate && $0.date <= phase.effectiveEndDate }
                .sorted { $0.date < $1.date }
        }
        return cachedPhaseEntries
    }
    
    private func recomputeEntries() {
        let phaseId = phase.id.uuidString
        let hash = currentEntriesHash
        
        // Check per-phase cache first
        if let cachedPhase = chartCache.getCachedPhaseEntries(for: phaseId, entriesHash: hash),
           let cachedSmoothed = chartCache.getCachedSmoothedEntries(for: phaseId, entriesHash: hash),
           let cachedPredictions = chartCache.getCachedPredictionEntries(for: phaseId, entriesHash: hash) {
            cachedPhaseEntries = cachedPhase
            cachedSmoothedEntries = cachedSmoothed
            cachedPredictionEntries = cachedPredictions
            return
        }
        
        cachedPhaseEntries = weightManager.allEntries
            .filter { $0.date >= phase.startDate && $0.date <= phase.effectiveEndDate }
            .sorted { $0.date < $1.date }
        
        // Recompute smoothing asynchronously
        computeSmoothedDataAsync()
    }
    
    // Interpolate a weight value at an exact date from the smoothed trend
    private static func interpolateWeight(at targetDate: Date, from entries: [WeightLogEntry]) -> Double? {
        guard !entries.isEmpty else { return nil }
        
        // If target is before all entries, use the first entry's value
        if targetDate <= entries.first!.date { return entries.first!.weight }
        // If target is after all entries, use the last entry's value
        if targetDate >= entries.last!.date { return entries.last!.weight }
        
        // Find the two entries that bracket this date
        for i in 0..<(entries.count - 1) {
            let before = entries[i]
            let after = entries[i + 1]
            if before.date <= targetDate && after.date >= targetDate {
                let totalInterval = after.date.timeIntervalSince(before.date)
                guard totalInterval > 0 else { return before.weight }
                let t = targetDate.timeIntervalSince(before.date) / totalInterval
                return before.weight + t * (after.weight - before.weight)
            }
        }
        
        return entries.last!.weight
    }
    
    private func computeSmoothedDataAsync() {
        guard !isComputing else { return }
        isComputing = true
        
        let phaseId = phase.id.uuidString
        let hash = currentEntriesHash
        let phaseStart = phase.startDate
        let phaseEnd = phase.effectiveEndDate
        
        DispatchQueue.global(qos: .userInitiated).async {
            let allEntries = weightManager.allEntries.sorted { $0.date < $1.date }
            
            // Build smoothed trend from ALL data (not just phase data)
            let smoothed = buildHappyScaleSmoothedTrend(
                from: allEntries,
                timeframe: phaseTimeframe
            )
            
            // Trim to phase dates
            var trimmed = smoothed.filter { $0.date >= phaseStart && $0.date <= phaseEnd }
            
            // Interpolate at phase start boundary if the line doesn't begin there
            if let firstDate = trimmed.first?.date, firstDate > phaseStart {
                if let startWeight = Self.interpolateWeight(at: phaseStart, from: smoothed) {
                    let startEntry = WeightLogEntry(
                        id: UUID(),
                        date: phaseStart,
                        weight: startWeight,
                        movingAverage: startWeight
                    )
                    trimmed.insert(startEntry, at: 0)
                }
            }
            
            // Interpolate at phase end boundary ONLY if smoothed data actually covers that date
            // (don't extrapolate far into the future for the current year)
            if let lastDate = trimmed.last?.date, lastDate < phaseEnd,
               let lastSmoothedDate = smoothed.last?.date, phaseEnd <= lastSmoothedDate {
                if let endWeight = Self.interpolateWeight(at: phaseEnd, from: smoothed) {
                    let endEntry = WeightLogEntry(
                        id: UUID(),
                        date: phaseEnd,
                        weight: endWeight,
                        movingAverage: endWeight
                    )
                    trimmed.append(endEntry)
                }
            }
            
            // Calculate predictions
            let predictions = calculatePredictions(from: trimmed)
            
            DispatchQueue.main.async {
                self.cachedSmoothedEntries = trimmed
                self.cachedPredictionEntries = predictions
                self.isComputing = false
                
                // Store in per-phase cache for instant access when switching back
                self.chartCache.setChartCache(
                    for: phaseId,
                    phaseEntries: self.cachedPhaseEntries,
                    smoothed: trimmed,
                    predictions: predictions,
                    entriesHash: hash
                )
            }
        }
    }
    
    private func calculatePredictions(from smoothedEntries: [WeightLogEntry]) -> [WeightLogEntry] {
        guard !smoothedEntries.isEmpty else { return [] }
        
        // Use the most recent entries available, regardless of date
        guard smoothedEntries.count >= 2,
              let firstEntry = smoothedEntries.first,
              let lastEntry = smoothedEntries.last else { return [] }
        
        let daysDiff = Calendar.current.dateComponents([.day], from: firstEntry.date, to: lastEntry.date).day ?? 1
        let weeksDiff = Double(daysDiff) / 7.0
        guard weeksDiff > 0 else { return [] }
        
        let weightChange = lastEntry.weight - firstEntry.weight
        let weeklyRate = weightChange / weeksDiff
        
        var predictions: [WeightLogEntry] = []
        let calendar = Calendar.current
        
        predictions.append(
            WeightLogEntry(
                id: UUID(),
                date: lastEntry.date,
                weight: lastEntry.weight,
                movingAverage: lastEntry.weight,
                weeklyRate: weeklyRate,
                notes: nil
            )
        )
        
        var currentDate = calendar.date(byAdding: .day, value: 1, to: lastEntry.date) ?? lastEntry.date
        
        while currentDate <= phase.effectiveEndDate {
            let daysFromLast = calendar.dateComponents([.day], from: lastEntry.date, to: currentDate).day ?? 0
            let weeksFromLast = Double(daysFromLast) / 7.0
            let predictedWeight = lastEntry.weight + (weeklyRate * weeksFromLast)
            
            predictions.append(
                WeightLogEntry(
                    id: UUID(),
                    date: currentDate,
                    weight: predictedWeight,
                    movingAverage: predictedWeight,
                    weeklyRate: weeklyRate,
                    notes: nil
                )
            )
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return predictions
    }
    
    // Determine appropriate timeframe based on phase duration
    private var phaseTimeframe: TimeFrame {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: phase.startDate, to: phase.endDate).day ?? 0
        
        if days <= 7 {
            return .oneWeek
        } else if days <= 30 {
            return .oneMonth
        } else if days <= 90 {
            return .threeMonths
        } else if days <= 365 {
            return .oneYear
        } else {
            return .allTime
        }
    }
    
    // Use cached smoothed entries (computed asynchronously)
    private var smoothedWeightEntries: [WeightLogEntry] {
        return cachedSmoothedEntries
    }
    
    // Use cached prediction entries (computed asynchronously)
    private var predictionEntries: [WeightLogEntry] {
        return cachedPredictionEntries
    }
    
    // MARK: - Happy Scale Smoothing (matches WeightChartDetailView)
    
    private func buildHappyScaleSmoothedTrend(
        from allEntries: [WeightLogEntry],
        timeframe: TimeFrame
    ) -> [WeightLogEntry] {
        guard !allEntries.isEmpty else { return [] }
        
        let sorted = allEntries.sorted { $0.date < $1.date }
        let params = timeframe.smoothingParameters
        
        // STAGE 0: Build daily series with gap filling FROM FULL HISTORY
        let daily = buildDailySeries(from: sorted)
        
        // STAGES 1-3: DES + turning damping + MA polish on FULL series
        let trend = buildTrendFromDaily(
            daily: daily,
            alpha: params.alpha,
            beta: params.beta,
            window: params.windowSize,
            turning: params.turning
        )
        
        // Map to WeightLogEntry
        var result: [WeightLogEntry] = []
        for (index, day) in daily.enumerated() {
            result.append(
                WeightLogEntry(
                    id: UUID(),
                    date: day.date,
                    weight: trend[index],
                    movingAverage: trend[index],
                    weeklyRate: nil,
                    notes: nil
                )
            )
        }
        
        return result
    }
    
    private func buildDailySeries(from entries: [WeightLogEntry]) -> [(date: Date, weight: Double)] {
        guard let first = entries.first?.date,
              let last = entries.last?.date else { return [] }
        
        var daily: [(date: Date, weight: Double)] = []
        var idx = 0
        let n = entries.count
        let calendar = Calendar.current
        
        var current = calendar.startOfDay(for: first)
        let endDate = calendar.startOfDay(for: last)
        
        while current <= endDate {
            while idx < n && calendar.startOfDay(for: entries[idx].date) < current {
                idx += 1
            }
            
            let w: Double
            if idx < n && calendar.isDate(entries[idx].date, inSameDayAs: current) {
                w = entries[idx].weight
            } else {
                let prevIdx = idx - 1
                let nextIdx = idx
                
                if prevIdx >= 0 && nextIdx < n {
                    let prev = entries[prevIdx]
                    let next = entries[nextIdx]
                    let totalDays = calendar.dateComponents([.day], from: prev.date, to: next.date).day ?? 1
                    let daysFromPrev = calendar.dateComponents([.day], from: prev.date, to: current).day ?? 0
                    let t = max(0.0, min(1.0, Double(daysFromPrev) / Double(totalDays)))
                    w = prev.weight + t * (next.weight - prev.weight)
                } else if prevIdx >= 0 {
                    w = entries[prevIdx].weight
                } else {
                    w = entries[nextIdx].weight
                }
            }
            
            daily.append((date: current, weight: w))
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        
        return daily
    }
    
    private func buildTrendFromDaily(
        daily: [(date: Date, weight: Double)],
        alpha: Double,
        beta: Double,
        window: Int,
        turning: Double
    ) -> [Double] {
        let raw = daily.map { $0.weight }
        let des = desWithStrongTurning(values: raw, alpha: alpha, beta: beta, turning: turning)
        return movingAverage(values: des, window: window)
    }
    
    private func desWithStrongTurning(values: [Double], alpha: Double, beta: Double, turning: Double) -> [Double] {
        let n = values.count
        guard n >= 2 else { return values }
        
        var level = values[0]
        var trend = values[1] - values[0]
        var result = Array(repeating: 0.0, count: n)
        var prevDelta = values[1] - values[0]
        
        for i in 0..<n {
            let x = values[i]
            let delta = i > 0 ? x - values[i - 1] : prevDelta
            
            let isTurning = (i > 1 &&
                           ((delta > 0 && prevDelta < 0) || (delta < 0 && prevDelta > 0)) &&
                           delta != 0 && prevDelta != 0)
            
            var a = alpha
            var b = beta
            
            if isTurning {
                let t = turning * turning
                a = alpha * (1 - 0.85 * t)
                b = beta * (1 - 0.90 * t)
                trend *= (1 - 0.70 * t)
            }
            
            let prevLevel = level
            level = a * x + (1 - a) * (level + trend)
            trend = b * (level - prevLevel) + (1 - b) * trend
            trend = min(1.5, max(-1.5, trend))
            
            result[i] = level + trend
            prevDelta = delta
        }
        
        return result
    }
    
    private func movingAverage(values: [Double], window: Int) -> [Double] {
        guard window > 1, values.count > 1 else { return values }
        
        let w = window % 2 == 0 ? window + 1 : window
        let radius = w / 2
        let n = values.count
        var out = Array(repeating: 0.0, count: n)
        
        for i in 0..<n {
            let start = max(0, i - radius)
            let end = min(n - 1, i + radius)
            let slice = values[start...end]
            out[i] = slice.reduce(0, +) / Double(slice.count)
        }
        
        return out
    }
    
    // Calculate goal weight based on phase target
    private var goalWeight: Double? {
        // Only show goal weight if user explicitly entered one
        return phase.goalWeight
    }
    
    // MARK: - Axis Labels
    
    private func yAxisLabels(height: CGFloat) -> some View {
        GeometryReader { _ in
            let range = yAxisRange.upperBound - yAxisRange.lowerBound
            let labelInterval = yAxisLabelInterval(for: range)
            let labels = generateYAxisLabels(range: range, interval: labelInterval)
            
            ZStack(alignment: .trailing) {
                ForEach(labels, id: \.self) { value in
                    let y = yPosition(for: value, in: CGSize(width: 0, height: height))
                    
                    Text(String(format: "%.1f", value))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                        .position(x: 20, y: y)
                }
            }
        }
    }
    
    // Label intervals (what we show on Y-axis)
    private func yAxisLabelInterval(for range: Double) -> Double {
        if range <= 3.0 {
            return 0.2
        } else if range <= 5.0 {
            return 0.5
        } else if range <= 10.0 {
            return 1.0
        } else {
            return 2.0
        }
    }
    
    // Determine appropriate timeframe string based on phase duration
    private func phaseTimeframeString() -> String {
        let totalDays = Calendar.current.dateComponents([.day], from: phase.startDate, to: phase.endDate).day ?? 1
        
        if totalDays <= 7 {
            return "1W"
        } else if totalDays <= 30 {
            return "1M"
        } else if totalDays <= 90 {
            return "3M"
        } else if totalDays <= 365 {
            return "1Y"
        } else {
            return "All"
        }
    }
    
    private func xAxisLabels(width: CGFloat) -> some View {
        let timeframe = phaseTimeframeString()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = .current
        
        // Set format based on timeframe
        switch timeframe {
        case "1W":
            dateFormatter.dateFormat = "EEE"
        case "1M":
            dateFormatter.dateFormat = "MMM"
        case "3M":
            dateFormatter.dateFormat = "MMM"
        case "1Y":
            dateFormatter.dateFormat = "MMMMM"
        default:
            dateFormatter.dateFormat = "yyyy"
        }
        
        // For 1M, 3M, and 1Y, show month labels positioned in the middle (matches WeightChartCardView)
        if timeframe == "1M" || timeframe == "3M" || timeframe == "1Y" {
            var result: [(Date, String)] = []
            let calendar = Calendar.current
            
            // Get start and end months
            let startComponents = calendar.dateComponents([.year, .month], from: phase.startDate)
            let endComponents = calendar.dateComponents([.year, .month], from: chartEndDate)
            
            if let startDate = calendar.date(from: startComponents),
               let endDate = calendar.date(from: endComponents) {
                
                var currentDate = startDate
                
                // Add label for each month, positioned in the middle of the visible range
                while currentDate <= endDate {
                    // Show label if any part of this month overlaps with the visible chart range
                    if let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: currentDate) {
                        // Check if month overlaps with visible chart range
                        if monthEnd >= phase.startDate && currentDate <= chartEndDate {
                            // Calculate the visible range for this month within the chart
                            let visibleStart = max(currentDate, phase.startDate)
                            let visibleEnd = min(monthEnd, chartEndDate)
                            
                            // Position label at the middle of the visible range
                            let daysBetween = calendar.dateComponents([.day], from: visibleStart, to: visibleEnd).day ?? 0
                            if let midPoint = calendar.date(byAdding: .day, value: daysBetween / 2, to: visibleStart) {
                                result.append((midPoint, dateFormatter.string(from: currentDate)))
                            }
                        }
                    }
                    
                    // Move to next month
                    if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) {
                        currentDate = nextMonth
                    } else {
                        break
                    }
                }
            }
            
            return AnyView(
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        ForEach(result, id: \.0) { (date, label) in
                            // Use geo.size.width directly since padding is applied externally
                            let xPos = xPosition(for: date, in: CGSize(width: geo.size.width, height: 0))
                            Text(label)
                                .font(.system(size: 10))
                                .foregroundColor(.primary)
                                .position(x: xPos, y: 10)
                        }
                    }
                }
                .frame(height: 20)
            )
        } else {
            // For 1W and All, use evenly distributed labels
            let totalDays = Calendar.current.dateComponents([.day], from: phase.startDate, to: chartEndDate).day ?? 1
            let interval = timeframe == "1W" ? 1 : max(totalDays / 4, 1)
            
            var dates: [Date] = []
            var currentDate = phase.startDate
            
            while currentDate <= chartEndDate {
                dates.append(currentDate)
                currentDate = Calendar.current.date(byAdding: .day, value: interval, to: currentDate) ?? chartEndDate
            }
            
            if let lastDate = dates.last, lastDate < chartEndDate {
                dates.append(chartEndDate)
            }
            
            return AnyView(
                HStack {
                    ForEach(dates, id: \.self) { date in
                        Text(dateFormatter.string(from: date))
                            .font(.system(size: 10))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 20)
            )
        }
    }
    
    // MARK: - Canvas Drawing
    
    private func drawPhaseChart(in context: GraphicsContext, size: CGSize) {
        drawGrid(in: context, size: size)
        drawActualTrend(in: context, size: size)
        drawPredictionLine(in: context, size: size)
        if let goal = goalWeight {
            drawGoalLine(in: context, size: size, goal: goal)
        }
    }
    
    private func drawGrid(in context: GraphicsContext, size: CGSize) {
        var gridPath = Path()
        
        // Horizontal gridlines - align with Y-axis labels
        let range = yAxisRange.upperBound - yAxisRange.lowerBound
        let interval = yAxisLabelInterval(for: range)
        let labels = generateYAxisLabels(range: range, interval: interval)
        
        for value in labels {
            let y = yPosition(for: value, in: size)
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: size.width, y: y))
        }
        
        // All horizontal gridlines with Y-axis labels use consistent style
        context.stroke(gridPath, with: .color(Color.gray.opacity(0.4)), lineWidth: 1.0)
        
        // Add intermediate gridlines when labels are every 2kg
        if interval == 2.0 {
            var intermediateGridPath = Path()
            let minRounded = (yAxisRange.lowerBound / 1.0).rounded(.down) * 1.0
            var current = minRounded
            
            while current <= yAxisRange.upperBound {
                let isLabelPosition = labels.contains(where: { abs($0 - current) < 0.01 })
                if !isLabelPosition && current >= yAxisRange.lowerBound {
                    let y = yPosition(for: current, in: size)
                    intermediateGridPath.move(to: CGPoint(x: 0, y: y))
                    intermediateGridPath.addLine(to: CGPoint(x: size.width, y: y))
                }
                current += 1.0
            }
            context.stroke(intermediateGridPath, with: .color(Color.gray.opacity(0.15)), lineWidth: 0.5)
        }
        
        // Add intermediate gridlines when labels are every 1kg
        if interval == 1.0 {
            var intermediateGridPath = Path()
            let minRounded = (yAxisRange.lowerBound / 0.5).rounded(.down) * 0.5
            var current = minRounded
            
            while current <= yAxisRange.upperBound {
                let isLabelPosition = labels.contains(where: { abs($0 - current) < 0.01 })
                if !isLabelPosition && current >= yAxisRange.lowerBound {
                    let y = yPosition(for: current, in: size)
                    intermediateGridPath.move(to: CGPoint(x: 0, y: y))
                    intermediateGridPath.addLine(to: CGPoint(x: size.width, y: y))
                }
                current += 0.5
            }
            context.stroke(intermediateGridPath, with: .color(Color.gray.opacity(0.15)), lineWidth: 0.5)
        }
        
        // Add intermediate gridlines when labels are every 0.2kg (0-3kg range)
        if interval == 0.2 {
            var intermediateGridPath = Path()
            let minRounded = (yAxisRange.lowerBound / 0.1).rounded(.down) * 0.1
            var current = minRounded
            
            while current <= yAxisRange.upperBound {
                let isLabelPosition = labels.contains(where: { abs($0 - current) < 0.01 })
                if !isLabelPosition && current >= yAxisRange.lowerBound {
                    let y = yPosition(for: current, in: size)
                    intermediateGridPath.move(to: CGPoint(x: 0, y: y))
                    intermediateGridPath.addLine(to: CGPoint(x: size.width, y: y))
                }
                current += 0.1
            }
            context.stroke(intermediateGridPath, with: .color(Color.gray.opacity(0.15)), lineWidth: 0.5)
        }
        
        // Add intermediate gridlines when labels are every 0.5kg (3-7kg range)
        if interval == 0.5 {
            var intermediateGridPath = Path()
            let minRounded = (yAxisRange.lowerBound / 0.1).rounded(.down) * 0.1
            var current = minRounded
            
            while current <= yAxisRange.upperBound {
                let isLabelPosition = labels.contains(where: { abs($0 - current) < 0.01 })
                if !isLabelPosition && current >= yAxisRange.lowerBound {
                    let y = yPosition(for: current, in: size)
                    intermediateGridPath.move(to: CGPoint(x: 0, y: y))
                    intermediateGridPath.addLine(to: CGPoint(x: size.width, y: y))
                }
                current += 0.1
            }
            context.stroke(intermediateGridPath, with: .color(Color.gray.opacity(0.15)), lineWidth: 0.5)
        }
        
        // Vertical gridlines based on phase duration
        let timeframe = phaseTimeframeString()
        let calendar = Calendar.current
        
        // Monthly vertical gridlines for 1M, 3M, and 1Y
        if timeframe == "1M" || timeframe == "3M" || timeframe == "1Y" {
            var monthPath = Path()
            
            let startComponents = calendar.dateComponents([.year, .month], from: phase.startDate)
            let endComponents = calendar.dateComponents([.year, .month], from: chartEndDate)
            
            if let startDate = calendar.date(from: startComponents),
               let endDate = calendar.date(from: endComponents) {
                
                var currentDate = startDate
                
                while currentDate <= endDate {
                    if currentDate >= phase.startDate && currentDate <= chartEndDate {
                        let x = xPosition(for: currentDate, in: size)
                        monthPath.move(to: CGPoint(x: x, y: 0))
                        monthPath.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    
                    if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) {
                        currentDate = nextMonth
                    } else {
                        break
                    }
                }
                
                // Draw month markers with consistent style
                context.stroke(monthPath, with: .color(Color.gray.opacity(0.4)), lineWidth: 1.0)
            }
            
            // Weekly sub-lines between monthly gridlines
            var weekPath = Path()
            let weekStart = calendar.startOfDay(for: phase.startDate)
            
            // Find the first Monday on or after phase start
            let weekdayOfStart = calendar.component(.weekday, from: weekStart)
            let daysToMonday = weekdayOfStart == 1 ? 1 : (9 - weekdayOfStart) % 7
            if var currentMonday = calendar.date(byAdding: .day, value: daysToMonday == 0 ? 7 : daysToMonday, to: weekStart) {
                while currentMonday <= chartEndDate {
                    // Skip if this Monday falls on a month boundary (avoid doubling with monthly lines)
                    let dayOfMonth = calendar.component(.day, from: currentMonday)
                    if dayOfMonth != 1 {
                        let x = xPosition(for: currentMonday, in: size)
                        weekPath.move(to: CGPoint(x: x, y: 0))
                        weekPath.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    currentMonday = calendar.date(byAdding: .weekOfYear, value: 1, to: currentMonday) ?? currentMonday
                }
            }
            
            let weekOpacity: Double = (timeframe == "1M") ? 0.25 : 0.15
            context.stroke(weekPath, with: .color(Color.gray.opacity(weekOpacity)), lineWidth: 0.5)
        }
        
        // Daily vertical gridlines for 1W and 1M
        if timeframe == "1W" || timeframe == "1M" {
            var dailyPath = Path()
            
            let startDate = calendar.startOfDay(for: phase.startDate)
            let endDate = calendar.startOfDay(for: chartEndDate)
            
            var currentDate = startDate
            
            while currentDate <= endDate {
                if currentDate >= phase.startDate && currentDate <= chartEndDate {
                    let x = xPosition(for: currentDate, in: size)
                    dailyPath.move(to: CGPoint(x: x, y: 0))
                    dailyPath.addLine(to: CGPoint(x: x, y: size.height))
                }
                
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                    currentDate = nextDay
                } else {
                    break
                }
            }
            
            // Draw daily gridlines
            if timeframe == "1W" {
                context.stroke(dailyPath, with: .color(Color.gray.opacity(0.4)), lineWidth: 1.0)
            } else {
                context.stroke(dailyPath, with: .color(Color.gray.opacity(0.25)), lineWidth: 0.5)
            }
        }
        
        // Yearly vertical gridlines for All time
        if timeframe == "All" {
            let startYear = calendar.component(.year, from: phase.startDate)
            let endYear = calendar.component(.year, from: chartEndDate)
            
            if endYear > startYear {
                var yearPath = Path()
                
                for year in (startYear + 1)...endYear {
                    if let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) {
                        if yearStart >= phase.startDate && yearStart <= chartEndDate {
                            let x = xPosition(for: yearStart, in: size)
                            yearPath.move(to: CGPoint(x: x, y: 0))
                            yearPath.addLine(to: CGPoint(x: x, y: size.height))
                        }
                    }
                }
                
                context.stroke(yearPath, with: .color(Color.gray.opacity(0.4)), lineWidth: 1.0)
            }
        }
    }
    
    private func drawActualTrend(in context: GraphicsContext, size: CGSize) {
        guard smoothedWeightEntries.count >= 2 else { return }
        
        let dates = smoothedWeightEntries.map { $0.date }
        let values = smoothedWeightEntries.map { $0.weight }
        
        // Apply monotone spline (match Weight Chart Details for consistency)
        let (splineDates, splineValues) = monotoneSpline(dates: dates, values: values, samplesPerSegment: 8)
        
        var path = Path()
        if splineDates.count > 0 {
            let firstPoint = CGPoint(
                x: xPosition(for: splineDates[0], in: size),
                y: yPosition(for: splineValues[0], in: size)
            )
            path.move(to: firstPoint)
            
            for i in 1..<splineDates.count {
                let point = CGPoint(
                    x: xPosition(for: splineDates[i], in: size),
                    y: yPosition(for: splineValues[i], in: size)
                )
                path.addLine(to: point)
            }
        }
        
        context.stroke(path, with: .color(Color(hex: "#35b8ff")), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
    }
    
    private func drawPredictionLine(in context: GraphicsContext, size: CGSize) {
        guard predictionEntries.count >= 2 else { return }
        
        var path = Path()
        let firstPoint = CGPoint(
            x: xPosition(for: predictionEntries[0].date, in: size),
            y: yPosition(for: predictionEntries[0].weight, in: size)
        )
        path.move(to: firstPoint)
        
        for i in 1..<predictionEntries.count {
            let point = CGPoint(
                x: xPosition(for: predictionEntries[i].date, in: size),
                y: yPosition(for: predictionEntries[i].weight, in: size)
            )
            path.addLine(to: point)
        }
        
        context.stroke(path, with: .color(phase.swiftUIColor), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [8, 4]))
    }
    
    private func drawGoalLine(in context: GraphicsContext, size: CGSize, goal: Double) {
        let y = yPosition(for: goal, in: size)
        let goalColor = Color(white: 0.4) // Dark grey color
        
        // Draw "Goal" text centered on the line
        let text = Text("Goal")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(goalColor)
        
        let textSize = context.resolve(text).measure(in: size)
        let centerX = size.width / 2
        
        // Draw line segments before and after the text (with small gap)
        let gap: CGFloat = 8
        let leftEnd = centerX - textSize.width / 2 - gap
        let rightStart = centerX + textSize.width / 2 + gap
        
        // Left segment - match prediction line style with rounded caps
        if leftEnd > 0 {
            var leftPath = Path()
            leftPath.move(to: CGPoint(x: 0, y: y))
            leftPath.addLine(to: CGPoint(x: leftEnd, y: y))
            context.stroke(leftPath, with: .color(goalColor), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [8, 4]))
        }
        
        // Right segment - match prediction line style with rounded caps
        if rightStart < size.width {
            var rightPath = Path()
            rightPath.move(to: CGPoint(x: rightStart, y: y))
            rightPath.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(rightPath, with: .color(goalColor), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [8, 4]))
        }
        
        // Draw text centered both horizontally and vertically on the line
        context.draw(text, at: CGPoint(x: centerX, y: y), anchor: .center)
    }
    
    private func xPosition(for date: Date, in size: CGSize) -> CGFloat {
        let total = chartEndDate.timeIntervalSince(phase.startDate)
        guard total > 0 else { return 0 }
        let t = date.timeIntervalSince(phase.startDate) / total
        return CGFloat(t) * size.width
    }
    
    private func yPosition(for weight: Double, in size: CGSize) -> CGFloat {
        let chartHeight = size.height > 0 ? size.height : 160.0
        let range = yAxisRange.upperBound - yAxisRange.lowerBound
        guard range > 0 else { return chartHeight / 2 }
        let normalized = (weight - yAxisRange.lowerBound) / range
        return chartHeight * (1 - CGFloat(normalized))
    }
    
    // Overloaded position functions for crosshair
    private func xPosition(for date: Date, chartWidth: CGFloat) -> CGFloat {
        let total = chartEndDate.timeIntervalSince(phase.startDate)
        guard total > 0 else { return 0 }
        let t = date.timeIntervalSince(phase.startDate) / total
        return CGFloat(t) * chartWidth
    }
    
    private func yPosition(for weight: Double, chartHeight: CGFloat) -> CGFloat {
        let range = yAxisRange.upperBound - yAxisRange.lowerBound
        guard range > 0 else { return chartHeight / 2 }
        let normalized = (weight - yAxisRange.lowerBound) / range
        return chartHeight * (1 - CGFloat(normalized))
    }
    
    // Handle drag gesture for crosshair
    private func handleDrag(at location: CGPoint, in size: CGSize) {
        let chartWidth = size.width - 25
        let xInChart = location.x - 25
        
        guard xInChart >= 0, xInChart <= chartWidth else {
            selectedIndex = nil
            return
        }
        
        // Combine smoothed and prediction entries for searching
        let allEntries = smoothedWeightEntries + predictionEntries
        guard !allEntries.isEmpty else {
            selectedIndex = nil
            return
        }
        
        // Find closest data point
        let total = chartEndDate.timeIntervalSince(phase.startDate)
        guard total > 0 else { return }
        
        let t = Double(xInChart / chartWidth)
        let targetDate = Date(timeInterval: t * total, since: phase.startDate)
        
        var closestIndex = 0
        var minDistance = abs(allEntries[0].date.timeIntervalSince(targetDate))
        
        for (index, entry) in allEntries.enumerated() {
            let distance = abs(entry.date.timeIntervalSince(targetDate))
            if distance < minDistance {
                minDistance = distance
                closestIndex = index
            }
        }
        
        if selectedIndex != closestIndex {
            selectedIndex = closestIndex
            
            // Haptic feedback when changing selection
            if lastSelectedIndex != closestIndex {
                haptic.impactOccurred()
                lastSelectedIndex = closestIndex
            }
        }
    }
    
    // Format date for crosshair label
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
    
    // Build crosshair overlay view
    @ViewBuilder
    private func crosshairOverlay(geoSize: CGSize) -> some View {
        if let idx = selectedIndex,
           let crosshairData = getCrosshairData(for: idx) {
            CrosshairView(
                entry: crosshairData.entry,
                crosshairColor: crosshairData.crosshairColor,
                pointColor: crosshairData.pointColor,
                geoSize: geoSize,
                phase: phase,
                yAxisRange: yAxisRange
            )
        }
    }
    
    // Helper to get crosshair data
    private func getCrosshairData(for idx: Int) -> (entry: WeightLogEntry, crosshairColor: Color, pointColor: Color)? {
        let isInSmoothed = smoothedWeightEntries.indices.contains(idx)
        let isInPrediction = !isInSmoothed && (idx - smoothedWeightEntries.count) < predictionEntries.count
        
        guard isInSmoothed || isInPrediction else { return nil }
        
        if isInSmoothed {
            return (
                entry: smoothedWeightEntries[idx],
                crosshairColor: Color.blue,
                pointColor: Color(hex: "#35b8ff")
            )
        } else {
            let predIdx = idx - smoothedWeightEntries.count
            return (
                entry: predictionEntries[predIdx],
                crosshairColor: phase.swiftUIColor,
                pointColor: phase.swiftUIColor
            )
        }
    }
    
    private func yAxisInterval(for range: Double) -> Double {
        if range <= 3.0 {
            return 0.2
        } else if range <= 7.0 {
            return 0.5
        } else if range <= 10.0 {
            return 1.0
        } else {
            return 2.0
        }
    }
    
    private func generateYAxisLabels(range: Double, interval: Double) -> [Double] {
        var labels: [Double] = []
        let minRounded = (yAxisRange.lowerBound / interval).rounded(.down) * interval
        var current = minRounded
        while current <= yAxisRange.upperBound {
            if current >= yAxisRange.lowerBound {
                labels.append(current)
            }
            current += interval
        }
        return labels
    }
    
    /// STAGE 4: Densified Fritsch-Carlson monotone cubic spline
    private func monotoneSpline(
        dates: [Date],
        values: [Double],
        samplesPerSegment: Int = 8
    ) -> (dates: [Date], values: [Double]) {
        let n = dates.count
        guard n >= 2 else { return (dates, values) }
        
        let firstDate = dates[0]
        let xs = dates.map { $0.timeIntervalSince(firstDate) / 86400.0 }
        let ys = values
        
        var m = Array(repeating: 0.0, count: n)
        for i in 0..<(n-1) {
            m[i] = (ys[i+1] - ys[i]) / (xs[i+1] - xs[i])
        }
        m[n-1] = m[n-2]
        
        var tangents = Array(repeating: 0.0, count: n)
        tangents[0] = m[0]
        for i in 1..<(n-1) {
            let m1 = m[i-1]
            let m2 = m[i]
            if m1 == 0 || m2 == 0 {
                tangents[i] = (m1 + m2) / 2.0
            } else {
                let denom = m1 + m2
                if abs(denom) > 0.0001 {
                    tangents[i] = 2.0 / denom
                } else {
                    tangents[i] = (m1 + m2) / 2.0
                }
            }
        }
        tangents[n-1] = m[n-1]
        
        for i in 0..<(n-1) {
            let m_i = m[i]
            if abs(m_i) < 1e-9 {
                tangents[i] = 0
                tangents[i+1] = 0
            } else {
                let alpha = tangents[i] / m_i
                let beta = tangents[i+1] / m_i
                let h = alpha*alpha + beta*beta
                if h > 9.0 {
                    let tau = 3.0 / sqrt(h)
                    tangents[i] = tau * alpha * m_i
                    tangents[i+1] = tau * beta * m_i
                }
            }
        }
        
        var outX: [Double] = []
        var outY: [Double] = []
        
        for i in 0..<(n-1) {
            let x0 = xs[i]
            let x1 = xs[i+1]
            let y0 = ys[i]
            let y1 = ys[i+1]
            let t0 = tangents[i]
            let t1 = tangents[i+1]
            let dx = x1 - x0
            
            for s in 0..<samplesPerSegment {
                let u = Double(s) / Double(samplesPerSegment)
                let u2 = u * u
                let u3 = u2 * u
                
                let h00 = 2*u3 - 3*u2 + 1
                let h10 = u3 - 2*u2 + u
                let h01 = -2*u3 + 3*u2
                let h11 = u3 - u2
                
                let x_out = x0 + u * dx
                let y_out = h00*y0 + h10*dx*t0 + h01*y1 + h11*dx*t1
                
                outX.append(x_out)
                outY.append(y_out)
            }
        }
        
        outX.append(xs.last!)
        outY.append(ys.last!)
        
        let outDates = outX.map { Date(timeInterval: $0 * 86400.0, since: firstDate) }
        
        return (dates: outDates, values: outY)
    }
    
    // Calculate Y-axis range for the chart (matching WeightChartDetailView approach)
    private var yAxisRange: ClosedRange<Double> {
        // Use rendered data (smoothed + predictions) for range, matching detail view style
        var allWeights = smoothedWeightEntries.map { $0.weight }
        allWeights.append(contentsOf: predictionEntries.map { $0.weight })
        
        // Fall back to raw entries if smoothed data isn't ready yet
        if allWeights.isEmpty {
            allWeights = phaseWeightEntries.map { $0.weight }
        }
        guard !allWeights.isEmpty else { return 0...100 }
        
        var minW = allWeights.min() ?? 0
        var maxW = allWeights.max() ?? 100
        
        // Include goal weight only if it falls within the plotted data range
        if let goal = goalWeight {
            let dataRange = maxW - minW
            let tolerance = max(dataRange * 0.5, 3.0)
            if goal >= minW - tolerance && goal <= maxW + tolerance {
                minW = min(minW, goal)
                maxW = max(maxW, goal)
            }
        }
        
        // Match detail view: 15% padding with 0.5kg minimum
        let range = maxW - minW
        let padding = max(range * 0.15, 0.5)
        
        return (minW - padding)...(maxW + padding)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weight Chart")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primary)
                .padding(.leading, 14)
                .padding(.top, 14)
            
            if !phaseWeightEntries.isEmpty {
                // Canvas-based Weight Chart with axis labels
                VStack(spacing: 0) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Main chart area with left padding for Y-axis
                            Canvas { context, size in
                                drawPhaseChart(in: context, size: size)
                            }
                            .frame(height: 160)
                            .padding(.leading, 25)
                            
                            // Y-axis labels
                            yAxisLabels(height: 160)
                                .frame(width: 25, alignment: .trailing)
                            
                            // Crosshair overlay
                            crosshairOverlay(geoSize: geo.size)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    handleDrag(at: value.location, in: geo.size)
                                }
                                .onEnded { _ in
                                    selectedIndex = nil
                                    lastSelectedIndex = nil
                                }
                        )
                    }
                    .frame(height: 160)
                    
                    // X-axis labels below chart
                    xAxisLabels(width: UIScreen.main.bounds.width - 80)
                        .padding(.leading, 25)
                        .padding(.top, 4)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackground)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                )
                
                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: "#35b8ff"))
                            .frame(width: 8, height: 8)
                        Text("Results")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(phase.swiftUIColor)
                            .frame(width: 8, height: 8)
                        Text("Predicted")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            } else {
                // Empty state for chart
                VStack(spacing: 8) {
                    Text("No weight data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Add weight entries within this phase's date range")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackground)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                )
            }
        }
        .onAppear {
            recomputeEntries()
        }
        .onChange(of: phase.id) { _, _ in
            selectedIndex = nil
            lastSelectedIndex = nil
            recomputeEntries()
        }
        .onChange(of: weightManager.allEntries.count) { _, _ in
            recomputeEntries()
        }
        .onChange(of: phase.startDate) { _, _ in
            recomputeEntries()
        }
        .onChange(of: phase.endDate) { _, _ in
            recomputeEntries()
        }
    }
}

// Statistics view for current phase
struct TestPhaseStatisticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let phase: WeightPhase
    @ObservedObject private var weightManager = WeightLogManager.shared
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    @State private var cachedPhaseEntries: [WeightLogEntry] = []
    
    // Get weight entries for this phase
    private var phaseWeightEntries: [WeightLogEntry] {
        // If cache is empty, compute immediately for initial render
        if cachedPhaseEntries.isEmpty {
            return weightManager.weightEntries
                .filter { $0.date >= phase.startDate && $0.date <= phase.effectiveEndDate }
                .sorted { $0.date < $1.date }
        }
        return cachedPhaseEntries
    }
    
    private func recomputeEntries() {
        cachedPhaseEntries = weightManager.weightEntries
            .filter { $0.date >= phase.startDate && $0.date <= phase.effectiveEndDate }
            .sorted { $0.date < $1.date }
    }
    
    // Calculate phase statistics
    private var phaseStats: (highest: Double?, lowest: Double?, averageChange: Double?, totalChange: Double?) {
        guard !phaseWeightEntries.isEmpty else {
            return (nil, nil, nil, nil)
        }
        
        let weights = phaseWeightEntries.map { $0.weight }
        let highest = weights.max()
        let lowest = weights.min()
        
        var averageChange: Double? = nil
        var totalChange: Double? = nil
        
        if phaseWeightEntries.count >= 2 {
            let firstWeight = phaseWeightEntries.first!.weight
            let lastWeight = phaseWeightEntries.last!.weight
            totalChange = lastWeight - firstWeight
            
            // Calculate weekly rate - only if we have at least 7 days of data
            let daysDifference = Calendar.current.dateComponents([.day], from: phaseWeightEntries.first!.date, to: phaseWeightEntries.last!.date).day ?? 0
            if daysDifference >= 7 {
                let weeksDifference = Double(daysDifference) / 7.0
                averageChange = totalChange! / weeksDifference
            }
        }
        
        return (highest, lowest, averageChange, totalChange)
    }
    
    var body: some View {
        let stats = phaseStats
        let highest = stats.highest
        let lowest = stats.lowest
        let totalChange = stats.totalChange
        
        return VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primary)
                .padding(.leading, 14)
                .padding(.top, 14)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Highest Weight
                StatCard(
                    title: "Highest Weight",
                    value: highest != nil ? String(format: "%.1f kg", highest!) : "-- kg",
                    color: .red
                )
                
                // Lowest Weight
                StatCard(
                    title: "Lowest Weight",
                    value: lowest != nil ? String(format: "%.1f kg", lowest!) : "-- kg",
                    color: .green
                )
                
                // Weekly Rate - only shows value when at least 7 days of data exists
                StatCard(
                    title: "Weekly Rate",
                    value: {
                        if let rate = stats.averageChange {
                            return rate >= 0 ? "+" + String(format: "%.2f kg/week", rate) : String(format: "%.2f kg/week", rate)
                        } else {
                            return "-- kg/week"
                        }
                    }(),
                    color: (stats.averageChange ?? 0) >= 0 ? .red : .green
                )
                
                // Total Change
                let totalText = totalChange != nil ? (totalChange! >= 0 ? "+" + String(format: "%.1f kg", totalChange!) : String(format: "%.1f kg", totalChange!)) : "-- kg"
                let totalColor: Color = (totalChange ?? 0) >= 0 ? .red : .green
                StatCard(
                    title: "Total Change",
                    value: totalText,
                    color: totalColor
                )
            }
        }
        .onAppear(perform: recomputeEntries)
        .onChange(of: phase.id) { _, _ in
            recomputeEntries()
        }
        .onChange(of: weightManager.weightEntries.count) { _, _ in
            recomputeEntries()
        }
        .onChange(of: phase.startDate) { _, _ in
            recomputeEntries()
        }
        .onChange(of: phase.endDate) { _, _ in
            recomputeEntries()
        }
    }
}

// Overview view for current phase weekly data
// Shared cache for all phases
class PhaseDataCache: ObservableObject {
    static let shared = PhaseDataCache()
    
    // In-memory cache for current session
    @Published private var cache: [String: [(week: Int, weekStart: Date, avgWeight: Double?, weightChange: Double?, avgKcals: Double?, avgSteps: Double?)]] = [:]
    @Published private var loadingStates: [String: Bool] = [:]
    @Published private var stepsCache: [String: Double?] = [:]
    
    // Per-phase chart data cache (smoothed entries + predictions)
    private var chartSmoothedCache: [String: [WeightLogEntry]] = [:]
    private var chartPredictionCache: [String: [WeightLogEntry]] = [:]
    private var chartPhaseEntriesCache: [String: [WeightLogEntry]] = [:]
    private var chartEntriesHash: [String: Int] = [:]
    
    // Persistent storage for finalized weekly data
    private let persistentCacheKey = "phase_weekly_data_persistent_cache"
    
    // Structure for storing weekly data persistently
    struct PersistentWeekData: Codable {
        let avgKcals: Double?
        let avgSteps: Double?
        let savedDate: Date
    }
    
    // MARK: - Chart Data Cache Methods
    
    func getCachedSmoothedEntries(for phaseId: String, entriesHash: Int) -> [WeightLogEntry]? {
        guard chartEntriesHash[phaseId] == entriesHash else { return nil }
        return chartSmoothedCache[phaseId]
    }
    
    func getCachedPredictionEntries(for phaseId: String, entriesHash: Int) -> [WeightLogEntry]? {
        guard chartEntriesHash[phaseId] == entriesHash else { return nil }
        return chartPredictionCache[phaseId]
    }
    
    func getCachedPhaseEntries(for phaseId: String, entriesHash: Int) -> [WeightLogEntry]? {
        guard chartEntriesHash[phaseId] == entriesHash else { return nil }
        return chartPhaseEntriesCache[phaseId]
    }
    
    func setChartCache(for phaseId: String, phaseEntries: [WeightLogEntry], smoothed: [WeightLogEntry], predictions: [WeightLogEntry], entriesHash: Int) {
        chartPhaseEntriesCache[phaseId] = phaseEntries
        chartSmoothedCache[phaseId] = smoothed
        chartPredictionCache[phaseId] = predictions
        chartEntriesHash[phaseId] = entriesHash
    }
    
    // MARK: - Weekly Data Cache Methods
    
    func getCachedData(for phaseId: String) -> [(week: Int, weekStart: Date, avgWeight: Double?, weightChange: Double?, avgKcals: Double?, avgSteps: Double?)] {
        return cache[phaseId] ?? []
    }
    
    func setCachedData(for phaseId: String, data: [(week: Int, weekStart: Date, avgWeight: Double?, weightChange: Double?, avgKcals: Double?, avgSteps: Double?)]) {
        cache[phaseId] = data
    }
    
    func isLoading(for phaseId: String) -> Bool {
        return loadingStates[phaseId] ?? false
    }
    
    func setLoading(for phaseId: String, loading: Bool) {
        loadingStates[phaseId] = loading
    }
    
    func getCachedSteps(for phaseId: String) -> Double? {
        return stepsCache[phaseId] ?? nil
    }
    
    func setCachedSteps(for phaseId: String, steps: Double?) {
        stepsCache[phaseId] = steps
    }
    
    // MARK: - Persistent Cache Methods
    
    /// Get persistent cache for a specific phase and week
    func getPersistentWeekData(phaseId: String, weekStart: Date) -> PersistentWeekData? {
        guard let data = UserDefaults.standard.data(forKey: persistentCacheKey),
              let allCache = try? JSONDecoder().decode([String: [String: PersistentWeekData]].self, from: data),
              let phaseCache = allCache[phaseId] else {
            return nil
        }
        
        let weekKey = weekStartKey(weekStart)
        return phaseCache[weekKey]
    }
    
    /// Save persistent cache for a specific phase and week
    func savePersistentWeekData(phaseId: String, weekStart: Date, avgKcals: Double?, avgSteps: Double?) {
        var allCache: [String: [String: PersistentWeekData]] = [:]
        
        if let data = UserDefaults.standard.data(forKey: persistentCacheKey),
           let existing = try? JSONDecoder().decode([String: [String: PersistentWeekData]].self, from: data) {
            allCache = existing
        }
        
        if allCache[phaseId] == nil {
            allCache[phaseId] = [:]
        }
        
        let weekKey = weekStartKey(weekStart)
        allCache[phaseId]?[weekKey] = PersistentWeekData(
            avgKcals: avgKcals,
            avgSteps: avgSteps,
            savedDate: Date()
        )
        
        if let encoded = try? JSONEncoder().encode(allCache) {
            UserDefaults.standard.set(encoded, forKey: persistentCacheKey)
        }
    }
    
    /// Check if a week is "finalized" (more than 8 weeks old, data won't change)
    func isWeekFinalized(weekStart: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart),
              let eightWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -8, to: now) else {
            return false
        }
        return weekEnd < eightWeeksAgo
    }
    
    private func weekStartKey(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
    
    func clearCache(for phaseId: String) {
        cache.removeValue(forKey: phaseId)
        loadingStates.removeValue(forKey: phaseId)
        stepsCache.removeValue(forKey: phaseId)
        chartSmoothedCache.removeValue(forKey: phaseId)
        chartPredictionCache.removeValue(forKey: phaseId)
        chartPhaseEntriesCache.removeValue(forKey: phaseId)
        chartEntriesHash.removeValue(forKey: phaseId)
        
        // Also clear persistent cache for this phase
        if let data = UserDefaults.standard.data(forKey: persistentCacheKey),
           var allCache = try? JSONDecoder().decode([String: [String: PersistentWeekData]].self, from: data) {
            allCache.removeValue(forKey: phaseId)
            if let encoded = try? JSONEncoder().encode(allCache) {
                UserDefaults.standard.set(encoded, forKey: persistentCacheKey)
            }
        }
        
        print("🗑️ Cleared cache for phase: \(phaseId)")
    }
    
    func clearAllCache() {
        cache.removeAll()
        loadingStates.removeAll()
        stepsCache.removeAll()
        chartSmoothedCache.removeAll()
        chartPredictionCache.removeAll()
        chartPhaseEntriesCache.removeAll()
        chartEntriesHash.removeAll()
        UserDefaults.standard.removeObject(forKey: persistentCacheKey)
        print("🗑️ Cleared all phase cache data")
    }
    
    private init() {
        // Listen for cache clearing notifications
        NotificationCenter.default.addObserver(
            forName: Notification.Name("clearPhaseCache"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let phaseId = notification.userInfo?["phaseId"] as? String {
                self?.clearCache(for: phaseId)
            }
        }
        
        // Listen for clear all cache notifications
        NotificationCenter.default.addObserver(
            forName: Notification.Name("clearAllPhaseCache"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearAllCache()
        }
    }
}

struct TestPhaseOverviewView: View {
    @Environment(\.colorScheme) private var colorScheme
    let phase: WeightPhase
    @ObservedObject private var weightManager = WeightLogManager.shared
    @ObservedObject private var healthKitManager = HealthKitManager.shared
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    @ObservedObject private var cache = PhaseDataCache.shared
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    // Get weight entries for this phase
    private var phaseWeightEntries: [WeightLogEntry] {
        return weightManager.weightEntries.filter { entry in
            entry.date >= phase.startDate && entry.date <= phase.effectiveEndDate
        }.sorted { $0.date < $1.date }
    }
    
    // Get cached data for this specific phase
    private var cachedWeeklyData: [(week: Int, weekStart: Date, avgWeight: Double?, weightChange: Double?, avgKcals: Double?, avgSteps: Double?)] {
        return cache.getCachedData(for: phase.id.uuidString)
    }
    
    private var isCalculatingData: Bool {
        return cache.isLoading(for: phase.id.uuidString)
    }
    
    private var currentWeekSteps: Double? {
        return cache.getCachedSteps(for: phase.id.uuidString)
    }
    
    // Build weeks incrementally using simple addition instead of ranges
    private var weeklyData: [(week: Int, weekStart: Date, avgWeight: Double?, weightChange: Double?, avgKcals: Double?, avgSteps: Double?)] {
        return cachedWeeklyData
    }
    
    // Calculate weekly data asynchronously
    private func calculateWeeklyDataAsync() {
        let phaseId = phase.id.uuidString
        guard !cache.isLoading(for: phaseId) else { return }
        cache.setLoading(for: phaseId, loading: true)
        
        Task {
            let data = await calculateWeeklyDataInBackground()
            await MainActor.run {
                self.cache.setCachedData(for: phaseId, data: data)
                self.cache.setLoading(for: phaseId, loading: false)
            }
        }
    }
    
    // Background calculation of weekly data
    private func calculateWeeklyDataInBackground() async -> [(week: Int, weekStart: Date, avgWeight: Double?, weightChange: Double?, avgKcals: Double?, avgSteps: Double?)] {
        let calendar = Calendar.current
        let now = Date()
        let phaseEnd = min(phase.endDate, now)
        
        // Calculate total days and weeks based on phase boundaries
        let totalDays = calendar.dateComponents([.day], from: phase.startDate, to: phaseEnd).day ?? 0
        guard totalDays >= 0 else { return [] }
        
        let maxWeeks = min(totalDays / 7 + 1, 20) // Reduced from 52 to 20 weeks for better performance
        guard maxWeeks > 0 else { return [] }
        
        // Get weight entries for this phase (filtered properly)
        let phaseEntries = weightManager.weightEntries.filter { entry in
            entry.date >= phase.startDate && entry.date <= phase.effectiveEndDate
        }.sorted { $0.date < $1.date }
        
        // Build week data incrementally starting from phase start
        var results: [(week: Int, weekStart: Date, avgWeight: Double?, weightChange: Double?, avgKcals: Double?, avgSteps: Double?)] = []
        var previousWeekWeight: Double? = nil
        
        var weekIndex = 0
        while weekIndex < maxWeeks {
            // Calculate week start date by adding days to phase start
            guard let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: phase.startDate) else {
                weekIndex += 1
                continue
            }
            
            // Stop if we've gone past the phase end
            if weekStart > phaseEnd {
                break
            }
            
            // Calculate week end
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            
            // Get weight entries for this week (using phase entries)
            let weekEntries = phaseEntries.filter { entry in
                entry.date >= weekStart && entry.date < weekEnd
            }
            
            // Calculate average weight for this week
            var avgWeight: Double? = nil
            if !weekEntries.isEmpty {
                avgWeight = weekEntries.map { $0.weight }.reduce(0, +) / Double(weekEntries.count)
            }
            
            // Calculate weight change from previous week
            var weightChange: Double? = nil
            if let currentWeight = avgWeight, let prevWeight = previousWeekWeight {
                weightChange = currentWeight - prevWeight
            }
            
            // Update previous week weight for next iteration
            if avgWeight != nil {
                previousWeekWeight = avgWeight
            }
            
            // Smart caching: Use persistent cache for finalized weeks (>8 weeks old)
            let isFinalized = cache.isWeekFinalized(weekStart: weekStart)
            var avgKcals: Double? = nil
            var avgSteps: Double? = nil
            
            if isFinalized, let persistentData = cache.getPersistentWeekData(phaseId: phase.id.uuidString, weekStart: weekStart) {
                // Use cached values for finalized weeks
                avgKcals = persistentData.avgKcals
                avgSteps = persistentData.avgSteps
            } else {
                // Calculate for recent weeks or uncached finalized weeks
                avgKcals = await calculateAverageKcalsForWeekAsync(weekStart: weekStart, weekEnd: weekEnd)
                avgSteps = await calculateAverageStepsForWeekAsync(weekStart: weekStart, weekEnd: weekEnd)
                
                // Save to persistent cache if finalized
                if isFinalized {
                    cache.savePersistentWeekData(phaseId: phase.id.uuidString, weekStart: weekStart, avgKcals: avgKcals, avgSteps: avgSteps)
                }
            }
            
            results.append((
                week: weekIndex,
                weekStart: weekStart,
                avgWeight: avgWeight,
                weightChange: weightChange,
                avgKcals: avgKcals,
                avgSteps: avgSteps
            ))
            
            weekIndex += 1
        }
        
        return results
    }
    
    // Calculate average kcals for a specific week (async version)
    private func calculateAverageKcalsForWeekAsync(weekStart: Date, weekEnd: Date) async -> Double? {
        let calendar = Calendar.current
        var totalKcals = 0
        var daysWithData = 0
        
        // Iterate through each day in the week
        var currentDate = weekStart
        while currentDate < weekEnd {
            // Only include calories from completed days
            if let dayKcals = FoodLogView.getCaloriesForCompletedDay(date: currentDate) {
                totalKcals += dayKcals
                daysWithData += 1
            }
            
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDay
        }
        
        // Return average only if we have data for at least one completed day
        return daysWithData > 0 ? Double(totalKcals) / Double(daysWithData) : nil
    }
    
    // Calculate average steps for a specific week (async version)
    private func calculateAverageStepsForWeekAsync(weekStart: Date, weekEnd: Date) async -> Double? {
        guard healthKitManager.isAuthorized else { return nil }
        
        return await withCheckedContinuation { continuation in
            healthKitManager.fetchStepsForDateRange(start: weekStart, end: weekEnd) { steps, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error fetching steps: \(error)")
                        continuation.resume(returning: nil)
                    } else if steps > 0 {
                        // Calculate average steps per day for the week
                        let calendar = Calendar.current
                        let now = Date()
                        // Use the earlier of weekEnd or now to avoid dividing by future days
                        let effectiveEnd = min(weekEnd, now)
                        let days = calendar.dateComponents([.day], from: weekStart, to: effectiveEnd).day ?? 1
                        // Ensure we have at least 1 day to avoid division by zero
                        let divisor = max(days, 1)
                        let avgSteps = Double(steps) / Double(divisor)
                        continuation.resume(returning: avgSteps)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    // Format week date for display
    private func formatWeekDate(_ weekStart: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: weekStart)
    }
    
    // Format steps with thousand separators
    private func formatStepsWithCommas(_ steps: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: steps)) ?? String(format: "%.0f", steps)
    }
    
    // Calculate current week's average steps
    private func fetchCurrentWeekSteps() {
        let phaseId = phase.id.uuidString
        let calendar = Calendar.current
        let now = Date()
        
        // Get start of current week (Monday)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let endOfWeek = min(now, calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? now)
        
        // Calculate how many days have passed in the current week
        let daysInCurrentWeek = calendar.dateComponents([.day], from: startOfWeek, to: endOfWeek).day ?? 1
        
        healthKitManager.fetchStepsForDateRange(start: startOfWeek, end: endOfWeek) { totalSteps, error in
            DispatchQueue.main.async {
                if error == nil && daysInCurrentWeek > 0 {
                    // Calculate daily average for the current week
                    let avgSteps = Double(totalSteps) / Double(daysInCurrentWeek)
                    self.cache.setCachedSteps(for: phaseId, steps: avgSteps)
                }
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primary)
                .padding(.leading, 14)
                .padding(.top, 14)
            
            if !weeklyData.isEmpty || isCalculatingData || !phaseWeightEntries.isEmpty {
                VStack(spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        Text("Week")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                        
                        Text("Weight")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                        
                        Text("Change")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                        
                        Text("Kcals")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                        
                        Text("Steps")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.appCardBackground)
                    .clipShape(
                        .rect(
                            topLeadingRadius: 12,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 12
                        )
                    )
                    
                    Divider()
                    
                    // Data rows for each week
                    if isCalculatingData && weeklyData.isEmpty {
                        // Loading state
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading weekly data...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ForEach(weeklyData.indices, id: \.self) { index in
                            let weekData = weeklyData[index]
                            
                            VStack(spacing: 0) {
                                HStack(spacing: 0) {
                                    Text(formatWeekDate(weekData.weekStart))
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity)
                                    
                                    if let weight = weekData.avgWeight {
                                        Text(String(format: "%.1f kg", weight))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity)
                                    } else {
                                        Text("-")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                    }
                                    
                                    if let change = weekData.weightChange {
                                        let changeText = change >= 0 ? "+" + String(format: "%.1f", change) : String(format: "%.1f", change)
                                        Text(changeText)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(phase.swiftUIColor)
                                            .frame(maxWidth: .infinity)
                                    } else {
                                        Text("-")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                    }
                                    
                                    if let kcals = weekData.avgKcals {
                                        Text(String(format: "%.0f", kcals))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity)
                                    } else if isCalculatingData {
                                        Text("...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                    } else {
                                        Text("-")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                    }
                                    
                                    if let steps = weekData.avgSteps {
                                        Text(formatStepsWithCommas(steps))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity)
                                    } else if isCalculatingData {
                                        Text("...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                    } else {
                                        Text("-")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                
                                if index < weeklyData.count - 1 {
                                    Divider()
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackground)
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
                )
            } else {
                // No data available
                VStack(spacing: 8) {
                    Text("No weekly data available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Add weight entries to see weekly overview")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackground)
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
                )
            }
        }
        .onAppear {
            // Track page view
            AnalyticsService.shared.trackPhasesView()
            
            // Only calculate if not already cached
            if cachedWeeklyData.isEmpty && !isCalculatingData {
                fetchCurrentWeekSteps()
                calculateWeeklyDataAsync()
            }
        }
        .onChange(of: phase.id) { _, _ in
            // Recalculate when swiping to a different phase
            if cachedWeeklyData.isEmpty && !isCalculatingData {
                fetchCurrentWeekSteps()
                calculateWeeklyDataAsync()
            }
        }
        .onChange(of: phase.startDate) { _, _ in
            // Recalculate when phase dates change
            fetchCurrentWeekSteps()
            calculateWeeklyDataAsync()
        }
        .onChange(of: phase.endDate) { _, _ in
            // Recalculate when phase dates change
            fetchCurrentWeekSteps()
            calculateWeeklyDataAsync()
        }
        .onChange(of: weightManager.weightEntries.count) { _, _ in
            // Recalculate when weight data is added or deleted
            fetchCurrentWeekSteps()
            calculateWeeklyDataAsync()
        }
    }
}

// Rate of Change Chart View for Phase
struct TestPhaseRateOfChangeView: View {
    @Environment(\.colorScheme) private var colorScheme
    let phase: WeightPhase
    @ObservedObject private var weightManager = WeightLogManager.shared
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    // Get weight entries for this phase
    private var phaseWeightEntries: [WeightLogEntry] {
        return weightManager.weightEntries.filter { entry in
            entry.date >= phase.startDate && entry.date <= phase.effectiveEndDate
        }.sorted { $0.date < $1.date }
    }
    
    // Determine appropriate timeframe based on phase duration
    private var phaseTimeframe: TimeFrame {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: phase.startDate, to: phase.endDate).day ?? 0
        
        if days <= 7 {
            return .oneWeek
        } else if days <= 30 {
            return .oneMonth
        } else if days <= 90 {
            return .threeMonths
        } else if days <= 365 {
            return .oneYear
        } else {
            return .allTime
        }
    }
    
    // Get smoothed trend data using Happy Scale algorithm
    private var smoothedWeightEntries: [WeightLogEntry] {
        guard phaseWeightEntries.count > 1 else { return phaseWeightEntries }
        
        // Get all weight entries to enable proper gap-filling
        let allEntries = weightManager.allEntries.sorted { $0.date < $1.date }
        
        // Apply Happy Scale smoothing to full history
        let smoothed = buildHappyScaleSmoothedTrend(
            from: allEntries,
            timeframe: phaseTimeframe
        )
        
        // Trim to phase dates
        return smoothed.filter { $0.date >= phase.startDate && $0.date <= phase.endDate }
    }
    
    // MARK: - Happy Scale Smoothing (matches WeightChartDetailView)
    
    private func buildHappyScaleSmoothedTrend(
        from allEntries: [WeightLogEntry],
        timeframe: TimeFrame
    ) -> [WeightLogEntry] {
        guard !allEntries.isEmpty else { return [] }
        
        let sorted = allEntries.sorted { $0.date < $1.date }
        let params = timeframe.smoothingParameters
        
        // STAGE 0: Build daily series with gap filling FROM FULL HISTORY
        let daily = buildDailySeries(from: sorted)
        
        // STAGES 1-3: DES + turning damping + MA polish on FULL series
        let trend = buildTrendFromDaily(
            daily: daily,
            alpha: params.alpha,
            beta: params.beta,
            window: params.windowSize,
            turning: params.turning
        )
        
        // Map to WeightLogEntry
        var result: [WeightLogEntry] = []
        for (index, day) in daily.enumerated() {
            result.append(
                WeightLogEntry(
                    id: UUID(),
                    date: day.date,
                    weight: trend[index],
                    movingAverage: trend[index],
                    weeklyRate: nil,
                    notes: nil
                )
            )
        }
        
        return result
    }
    
    private func buildDailySeries(from entries: [WeightLogEntry]) -> [(date: Date, weight: Double)] {
        guard let first = entries.first?.date,
              let last = entries.last?.date else { return [] }
        
        var daily: [(date: Date, weight: Double)] = []
        var idx = 0
        let n = entries.count
        let calendar = Calendar.current
        
        var current = calendar.startOfDay(for: first)
        let endDate = calendar.startOfDay(for: last)
        
        while current <= endDate {
            while idx < n && calendar.startOfDay(for: entries[idx].date) < current {
                idx += 1
            }
            
            let w: Double
            if idx < n && calendar.isDate(entries[idx].date, inSameDayAs: current) {
                w = entries[idx].weight
            } else {
                let prevIdx = idx - 1
                let nextIdx = idx
                
                if prevIdx >= 0 && nextIdx < n {
                    let prev = entries[prevIdx]
                    let next = entries[nextIdx]
                    let totalDays = calendar.dateComponents([.day], from: prev.date, to: next.date).day ?? 1
                    let daysFromPrev = calendar.dateComponents([.day], from: prev.date, to: current).day ?? 0
                    let t = max(0.0, min(1.0, Double(daysFromPrev) / Double(totalDays)))
                    w = prev.weight + t * (next.weight - prev.weight)
                } else if prevIdx >= 0 {
                    w = entries[prevIdx].weight
                } else {
                    w = entries[nextIdx].weight
                }
            }
            
            daily.append((date: current, weight: w))
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        
        return daily
    }
    
    private func buildTrendFromDaily(
        daily: [(date: Date, weight: Double)],
        alpha: Double,
        beta: Double,
        window: Int,
        turning: Double
    ) -> [Double] {
        let raw = daily.map { $0.weight }
        let des = desWithStrongTurning(values: raw, alpha: alpha, beta: beta, turning: turning)
        return movingAverage(values: des, window: window)
    }
    
    private func desWithStrongTurning(values: [Double], alpha: Double, beta: Double, turning: Double) -> [Double] {
        let n = values.count
        guard n >= 2 else { return values }
        
        var level = values[0]
        var trend = values[1] - values[0]
        var result = Array(repeating: 0.0, count: n)
        var prevDelta = values[1] - values[0]
        
        for i in 0..<n {
            let x = values[i]
            let delta = i > 0 ? x - values[i - 1] : prevDelta
            
            let isTurning = (i > 1 &&
                           ((delta > 0 && prevDelta < 0) || (delta < 0 && prevDelta > 0)) &&
                           delta != 0 && prevDelta != 0)
            
            var a = alpha
            var b = beta
            
            if isTurning {
                let t = turning * turning
                a = alpha * (1 - 0.85 * t)
                b = beta * (1 - 0.90 * t)
                trend *= (1 - 0.70 * t)
            }
            
            let prevLevel = level
            level = a * x + (1 - a) * (level + trend)
            trend = b * (level - prevLevel) + (1 - b) * trend
            trend = min(1.5, max(-1.5, trend))
            
            result[i] = level + trend
            prevDelta = delta
        }
        
        return result
    }
    
    private func movingAverage(values: [Double], window: Int) -> [Double] {
        guard window > 1, values.count > 1 else { return values }
        
        let w = window % 2 == 0 ? window + 1 : window
        let radius = w / 2
        let n = values.count
        var out = Array(repeating: 0.0, count: n)
        
        for i in 0..<n {
            let start = max(0, i - radius)
            let end = min(n - 1, i + radius)
            let slice = values[start...end]
            out[i] = slice.reduce(0, +) / Double(slice.count)
        }
        
        return out
    }
    
    // Calculate weekly weight changes from the smoothed trend line
    private var weeklyRateData: [(weekStart: Date, averageRate: Double)] {
        guard smoothedWeightEntries.count > 1 else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let phaseEnd = min(phase.endDate, now)
        
        // Calculate total weeks in phase
        let totalDays = calendar.dateComponents([.day], from: phase.startDate, to: phaseEnd).day ?? 0
        guard totalDays >= 0 else { return [] }
        
        let maxWeeks = min(totalDays / 7 + 1, 20)
        guard maxWeeks > 0 else { return [] }
        
        var results: [(Date, Double)] = []
        
        var weekIndex = 0
        while weekIndex < maxWeeks {
            // Calculate week start date
            guard let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: phase.startDate) else {
                weekIndex += 1
                continue
            }
            
            // Stop if we've gone past the phase end
            if weekStart > phaseEnd {
                break
            }
            
            // Calculate week end
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            
            // Find the smoothed weight at the start and end of this week
            let weekStartWeight = interpolateWeight(at: weekStart, from: smoothedWeightEntries)
            let weekEndWeight = interpolateWeight(at: weekEnd, from: smoothedWeightEntries)
            
            // Calculate the rate of change for this week
            if let startWeight = weekStartWeight, let endWeight = weekEndWeight {
                let weightChange = endWeight - startWeight
                // Round to 1 decimal place
                let roundedChange = round(weightChange * 10) / 10
                results.append((weekStart, roundedChange))
            }
            
            weekIndex += 1
        }
        
        return results
    }
    
    // Interpolate weight at a specific date from smoothed data
    private func interpolateWeight(at date: Date, from entries: [WeightLogEntry]) -> Double? {
        guard !entries.isEmpty else { return nil }
        
        // If date is before first entry, return first entry weight
        if date <= entries.first!.date {
            return entries.first!.weight
        }
        
        // If date is after last entry, return last entry weight
        if date >= entries.last!.date {
            return entries.last!.weight
        }
        
        // Find the two entries that bracket this date
        for i in 0..<(entries.count - 1) {
            let current = entries[i]
            let next = entries[i + 1]
            
            if date >= current.date && date <= next.date {
                // Linear interpolation between the two points
                let totalInterval = next.date.timeIntervalSince(current.date)
                let dateInterval = date.timeIntervalSince(current.date)
                let ratio = totalInterval > 0 ? dateInterval / totalInterval : 0
                
                return current.weight + (next.weight - current.weight) * ratio
            }
        }
        
        return nil
    }
    
    // Calculate Y-axis range for rate of change - always include 0
    private var rateOfChangeYRange: ClosedRange<Double> {
        guard !weeklyRateData.isEmpty else { return -1...1 }
        
        let rates = weeklyRateData.map { $0.averageRate }
        guard let minRate = rates.min(), let maxRate = rates.max() else {
            return -1...1
        }
        
        // Always include 0 in the range
        let actualMin = min(minRate, 0)
        let actualMax = max(maxRate, 0)
        
        // Add padding to the range
        let range = actualMax - actualMin
        let padding = max(range * 0.2, 0.2) // At least 0.2 kg/week padding
        
        return (actualMin - padding)...(actualMax + padding)
    }
    
    var body: some View {
        if !weeklyRateData.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Weekly Rate")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.leading, 14)
                    .padding(.top, 14)
                
                // Bar Chart - One bar per week
                Chart(weeklyRateData, id: \.weekStart) { weekData in
                    BarMark(
                        x: .value("Week", weekData.weekStart, unit: .weekOfYear),
                        y: .value("Weekly Rate", weekData.averageRate)
                    )
                    .foregroundStyle(phase.swiftUIColor.opacity(0.7))
                    .cornerRadius(4)
                }
                .frame(height: 180)
                .chartYScale(domain: rateOfChangeYRange)
                .chartXScale(domain: phase.startDate...phase.endDate)
                .chartYAxis {
                    // Faded gridlines at 0.1 kg intervals
                    AxisMarks(position: .leading, values: .stride(by: 0.1)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.2))
                    }
                    // Main axis marks with labels at automatic intervals
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let rate = value.as(Double.self) {
                                let sign = rate > 0 ? "+" : ""
                                Text("\(sign)\(String(format: "%.1f", rate))")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackground)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                )
            }
        }
    }
}

// Safe array subscript extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct TestPhasesView_Previews: PreviewProvider {
    static var previews: some View {
        TestPhasesView()
    }
}

// MARK: - Crosshair View
private struct CrosshairView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: WeightLogEntry
    let crosshairColor: Color
    let pointColor: Color
    let geoSize: CGSize
    let phase: WeightPhase
    let yAxisRange: ClosedRange<Double>
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    private var chartWidth: CGFloat { geoSize.width - 25 }
    
    private var xPos: CGFloat {
        let total = phase.endDate.timeIntervalSince(phase.startDate)
        guard total > 0 else { return 0 }
        let t = entry.date.timeIntervalSince(phase.startDate) / total
        return CGFloat(t) * chartWidth
    }
    
    private var yPos: CGFloat {
        let chartHeight: CGFloat = 160
        let range = yAxisRange.upperBound - yAxisRange.lowerBound
        guard range > 0 else { return chartHeight / 2 }
        let normalized = (entry.weight - yAxisRange.lowerBound) / range
        return chartHeight * (1 - CGFloat(normalized))
    }
    
    var body: some View {
        ZStack {
            // Vertical crosshair line
            Path { path in
                path.move(to: CGPoint(x: xPos + 25, y: 0))
                path.addLine(to: CGPoint(x: xPos + 25, y: 160))
            }
            .stroke(crosshairColor.opacity(0.5), lineWidth: 1)
            
            // Horizontal crosshair line
            Path { path in
                path.move(to: CGPoint(x: 25, y: yPos))
                path.addLine(to: CGPoint(x: geoSize.width, y: yPos))
            }
            .stroke(crosshairColor.opacity(0.5), lineWidth: 1)
            
            // Data point circle
            Circle()
                .fill(pointColor)
                .frame(width: 8, height: 8)
                .position(x: xPos + 25, y: yPos)
            
            // Value label
            VStack(spacing: 2) {
                Text(String(format: "%.1f kg", entry.weight))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Text(formatDate(entry.date))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(cardBackground)
                    .shadow(color: .black.opacity(0.1), radius: 2)
            )
            .position(x: xPos + 25, y: max(30, min(130, yPos - 30)))
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}
