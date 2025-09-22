//
//  WeightCalendarView.swift
//  nutribase
//
//  Created on 14/08/2025.
//

import SwiftUI

struct WeightCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var weightManager = WeightLogManager.shared
    @State private var selectedDate = Date()
    @State private var showingAddWeight = false
    
    // Calendar date formatter
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Single month calendar with swipe navigation
                SingleMonthCalendarView(
                    selectedDate: $selectedDate,
                    weightEntries: weightManager.weightEntries
                )
                .padding()
                
                // Weight entry for selected date
                if let entry = getWeightEntry(for: selectedDate) {
                    VStack(spacing: 16) {
                        Text("Weight Entry for \(dateFormatter.string(from: selectedDate))")
                            .font(.headline)
                            .padding(.top)
                        
                        WeightEntryCardView(entry: entry)
                            .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Weight Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            })
        }
        .sheet(isPresented: $showingAddWeight) {
            AddWeightEntryView(weightManager: weightManager)
        }
    }
    
    // Helper function to get weight entry for a specific date
    private func getWeightEntry(for date: Date) -> WeightLogEntry? {
        let calendar = Calendar.current
        return weightManager.weightEntries.first { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }
    }
}

struct WeightEntryCardView: View {
    let entry: WeightLogEntry
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Weight")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.1f", entry.weight)) kg")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Text("Moving Average")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.1f", entry.movingAverage)) kg")
                    .font(.body)
            }
            
            if let weeklyRate = entry.weeklyRate {
                HStack {
                    Text("Weekly Rate")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: weeklyRate < 0 ? "arrow.down" : "arrow.up")
                            .foregroundColor(weeklyRate < 0 ? .red : .green)
                            .font(.caption)
                        
                        Text("\(String(format: "%.1f", abs(weeklyRate))) kg")
                            .foregroundColor(weeklyRate < 0 ? .red : .green)
                            .font(.body)
                    }
                }
            }
            
            if let notes = entry.notes, !notes.isEmpty {
                HStack {
                    Text("Notes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                Text(notes)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// Single month calendar with horizontal swipe navigation
struct SingleMonthCalendarView: View {
    @Binding var selectedDate: Date
    let weightEntries: [WeightLogEntry]
    
    @State private var currentMonth: Date = Date()
    
    private let calendar = Calendar.current
    
    init(selectedDate: Binding<Date>, weightEntries: [WeightLogEntry]) {
        self._selectedDate = selectedDate
        self.weightEntries = weightEntries
        
        // Initialize current month to the month containing the selected date
        let components = Calendar.current.dateComponents([.year, .month], from: selectedDate.wrappedValue)
        self._currentMonth = State(initialValue: Calendar.current.date(from: components) ?? Date())
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Month navigation header
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(monthFormatter.string(from: currentMonth))
                    .font(.custom("Montserrat-Bold", size: 20))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            
            // Single month view with swipe gesture
            MonthView(
                month: currentMonth,
                selectedDate: $selectedDate,
                weightEntries: weightEntries
            )
            .gesture(
                DragGesture()
                    .onEnded { value in
                        // Swipe left = next month, swipe right = previous month
                        if value.translation.width > 50 {
                            previousMonth()
                        } else if value.translation.width < -50 {
                            nextMonth()
                        }
                    }
            )
            .animation(.easeInOut(duration: 0.3), value: currentMonth)
        }
    }
    
    // MARK: - Navigation Methods
    
    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
    
    // Month formatter
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    

}

// Individual month view for the scrollable calendar
struct MonthView: View {
    let month: Date
    @Binding var selectedDate: Date
    let weightEntries: [WeightLogEntry]
    
    private let calendar = Calendar.current
    
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
    
    var body: some View {
        VStack(spacing: 16) {
            // Month header
            HStack {
                Text(monthFormatter.string(from: month))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)
            
            // Days of week header (only show for first visible month or when month changes)
            HStack(spacing: 0) {
                ForEach(getDaysOfWeek(), id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            
            // Calendar grid for this month
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(getDaysInMonth(for: month), id: \.self) { date in
                    if let date = date {
                        let hasEntry = hasWeightEntry(for: date)
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        let isToday = calendar.isDateInToday(date)
                        let isCurrentMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
                        
                        Button(action: {
                            selectedDate = date
                        }) {
                            ZStack {
                                // Background circle for dates with weight entries
                                if hasEntry && isCurrentMonth {
                                    Circle()
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                }
                                
                                // Today indicator
                                if isToday && !isSelected {
                                    Circle()
                                        .stroke(Color.blue, lineWidth: 1)
                                        .frame(width: 36, height: 36)
                                }
                                
                                // Selected date indicator
                                if isSelected {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 36, height: 36)
                                }
                                
                                Text(dayFormatter.string(from: date))
                                    .font(.body)
                                    .fontWeight(isSelected || isToday ? .semibold : .regular)
                                    .foregroundColor(
                                        isSelected ? .white :
                                        isCurrentMonth ? .primary : .secondary
                                    )
                            }
                        }
                        .frame(height: 44)
                    } else {
                        // Empty space for padding
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Methods
    
    private func getDaysOfWeek() -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        
        var days: [String] = []
        // Start with Monday (weekday 2 in Calendar)
        for i in 2...7 {
            if let date = calendar.date(bySetting: .weekday, value: i, of: Date()) {
                days.append(formatter.string(from: date).uppercased())
            }
        }
        // Add Sunday (weekday 1)
        if let date = calendar.date(bySetting: .weekday, value: 1, of: Date()) {
            days.append(formatter.string(from: date).uppercased())
        }
        return days
    }
    
    private func getDaysInMonth(for month: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else {
            return []
        }
        
        let firstOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        
        // Adjust for Monday start (weekday 2 = Monday in Calendar)
        let adjustedFirstWeekday = firstWeekday == 1 ? 7 : firstWeekday - 1
        let daysFromPreviousMonth = adjustedFirstWeekday - 1
        
        var days: [Date?] = []
        
        // Add days from previous month for padding
        if daysFromPreviousMonth > 0 {
            if let previousMonth = calendar.date(byAdding: .month, value: -1, to: month),
               let previousMonthInterval = calendar.dateInterval(of: .month, for: previousMonth) {
                let daysInPreviousMonth = calendar.range(of: .day, in: .month, for: previousMonth)?.count ?? 0
                let startDay = daysInPreviousMonth - daysFromPreviousMonth + 1
                
                for day in startDay...daysInPreviousMonth {
                    if let date = calendar.date(byAdding: .day, value: day - 1, to: previousMonthInterval.start) {
                        days.append(date)
                    }
                }
            }
        }
        
        // Add days from current month
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 0
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        // Add days from next month to fill the grid (6 rows × 7 days = 42 total)
        let remainingDays = 42 - days.count
        if remainingDays > 0, let nextMonth = calendar.date(byAdding: .month, value: 1, to: month),
           let nextMonthInterval = calendar.dateInterval(of: .month, for: nextMonth) {
            for day in 1...remainingDays {
                if let date = calendar.date(byAdding: .day, value: day - 1, to: nextMonthInterval.start) {
                    days.append(date)
                }
            }
        }
        
        return days
    }
    
    private func hasWeightEntry(for date: Date) -> Bool {
        return weightEntries.contains { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }
    }
}

// Legend view showing dates with weight entries for the current month
struct WeightEntryLegendView: View {
    let weightEntries: [WeightLogEntry]
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    // Get weight entries for the current month
    private var currentMonthEntries: [WeightLogEntry] {
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        
        return weightEntries.filter { entry in
            entry.date >= startOfMonth && entry.date < endOfMonth
        }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        if !currentMonthEntries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text("Dates with weight entries this month:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 4) {
                    ForEach(currentMonthEntries.prefix(12), id: \.id) { entry in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 6, height: 6)
                            Text(dateFormatter.string(from: entry.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if currentMonthEntries.count > 12 {
                    Text("+ \(currentMonthEntries.count - 12) more entries")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
    }
}

#Preview {
    WeightCalendarView()
}
