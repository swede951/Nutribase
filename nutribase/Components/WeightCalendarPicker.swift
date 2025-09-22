//
//  WeightCalendarPicker.swift
//  nutribase
//
//  Created on 11/09/2025.
//

import SwiftUI

struct WeightCalendarPicker: View {
    @Binding var selectedDate: Date
    let weightEntries: [WeightLogEntry]
    let title: String
    
    @State private var showingCalendar = false
    @State private var currentMonthOffset: Int = 0
    
    // Public initializer
    init(selectedDate: Binding<Date>, weightEntries: [WeightLogEntry], title: String) {
        self._selectedDate = selectedDate
        self.weightEntries = weightEntries
        self.title = title
        
        // Initialize currentMonthOffset to show the selected date's month
        let calendar = Calendar.current
        let monthsDiff = calendar.dateComponents([.month], from: Date(), to: selectedDate.wrappedValue).month ?? 0
        self._currentMonthOffset = State(initialValue: monthsDiff)
    }
    
    private var calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday = 2, Sunday = 1
        return cal
    }()
    
    // Date formatter for display
    private let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date picker button
            Button(action: {
                showingCalendar.toggle()
            }) {
                HStack {
                    Text(title)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(displayFormatter.string(from: selectedDate))
                        .foregroundColor(.blue)
                    
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expandable calendar
            if showingCalendar {
                CalendarGridView(
                    selectedDate: $selectedDate,
                    weightEntries: weightEntries,
                    currentMonthOffset: $currentMonthOffset
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeInOut(duration: 0.2), value: showingCalendar)
            }
        }
    }
}

struct CalendarGridView: View {
    @Binding var selectedDate: Date
    let weightEntries: [WeightLogEntry]
    @Binding var currentMonthOffset: Int
    
    // Public initializer
    init(selectedDate: Binding<Date>, weightEntries: [WeightLogEntry], currentMonthOffset: Binding<Int>) {
        self._selectedDate = selectedDate
        self.weightEntries = weightEntries
        self._currentMonthOffset = currentMonthOffset
    }
    
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
    
    // Current month being displayed
    private var currentMonth: Date {
        calendar.date(byAdding: .month, value: currentMonthOffset, to: Date()) ?? Date()
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Month navigation header
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentMonthOffset -= 1
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(monthFormatter.string(from: currentMonth))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentMonthOffset += 1
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 4)
            
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
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(getDaysInMonth(for: currentMonth), id: \.self) { date in
                    if let date = date {
                        CalendarDayView(
                            date: date,
                            selectedDate: $selectedDate,
                            hasWeightEntry: hasWeightEntry(for: date),
                            isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
                        )
                    } else {
                        // Empty space for dates not in current month
                        Color.clear
                            .frame(height: 36)
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
        
        // Fill remaining slots to complete the grid (6 weeks = 42 slots)
        while days.count < 42 {
            days.append(nil)
        }
        
        return days
    }
    
    private func hasWeightEntry(for date: Date) -> Bool {
        return weightEntries.contains { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }
    }
}

struct CalendarDayView: View {
    let date: Date
    @Binding var selectedDate: Date
    let hasWeightEntry: Bool
    let isCurrentMonth: Bool
    
    // Public initializer
    init(date: Date, selectedDate: Binding<Date>, hasWeightEntry: Bool, isCurrentMonth: Bool) {
        self.date = date
        self._selectedDate = selectedDate
        self.hasWeightEntry = hasWeightEntry
        self.isCurrentMonth = isCurrentMonth
    }
    
    private var calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }()
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    private var isSelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    var body: some View {
        Button(action: {
            selectedDate = date
        }) {
            ZStack {
                // Background circle for selected date
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                }
                
                // Today indicator (border)
                if isToday && !isSelected {
                    Circle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
                
                // Weight entry indicator (small dot)
                if hasWeightEntry {
                    Circle()
                        .fill(isSelected ? Color.white : Color.blue)
                        .frame(width: 6, height: 6)
                        .offset(x: 10, y: -10)
                }
                
                // Date text
                Text(dayFormatter.string(from: date))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(
                        isSelected ? .white :
                        isCurrentMonth ? .primary : .secondary
                    )
            }
        }
        .frame(height: 36)
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedDate = Date()
        
        var body: some View {
            Form {
                WeightCalendarPicker(
                    selectedDate: $selectedDate,
                    weightEntries: [
                        WeightLogEntry(date: Date(), weight: 80.5, movingAverage: 80.5, notes: nil),
                        WeightLogEntry(date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(), weight: 80.3, movingAverage: 80.4, notes: nil),
                        WeightLogEntry(date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(), weight: 80.7, movingAverage: 80.5, notes: nil)
                    ],
                    title: "Start Date"
                )
            }
        }
    }
    
    return PreviewWrapper()
}
