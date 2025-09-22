//
//  YearCalendarView.swift
//  nutribase
//
//  Created on 24/08/2025.
//

import SwiftUI

// Simple SwiftUI Calendar implementation
public struct YearCalendarView: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    @StateObject private var phaseManager = WeightPhaseManager.shared
    
    public init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
    }
    
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                             "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday first
        return cal
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Year header
                HStack {
                    Text(String(currentYear))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.leading, 20)
                    
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                // Months grid - 4 rows x 3 columns
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(0..<4, id: \.self) { row in
                            HStack(spacing: 15) {
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
                    .padding(.horizontal, 15)
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
    }
    
    private func monthView(for monthIndex: Int) -> some View {
        let monthDate = calendar.date(from: DateComponents(year: currentYear, month: monthIndex + 1, day: 1)) ?? Date()
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: monthDate)
        let startingSpaces = (firstWeekday == 1) ? 6 : firstWeekday - 2 // Monday = 0, Sunday = 6
        let totalCells = startingSpaces + daysInMonth
        let rows = (totalCells + 6) / 7 // Calculate number of rows needed
        
        let monthTitle = Text(monthNames[monthIndex])
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.primary)
            .frame(height: 20, alignment: .bottom)
        
        let calendarGrid = VStack(spacing: 2) {
            ForEach(Array(0..<rows), id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(Array(0..<7), id: \.self) { col in
                        dayCell(row: row, col: col, monthIndex: monthIndex, startingSpaces: startingSpaces, daysInMonth: daysInMonth)
                    }
                }
                .background(
                    phaseRowBackground(row: row, monthIndex: monthIndex, startingSpaces: startingSpaces, daysInMonth: daysInMonth)
                )
            }
        }
        .frame(height: 100)
        
        return VStack(spacing: 4) {
            monthTitle
            calendarGrid
        }
    }
    
    private func dayCell(row: Int, col: Int, monthIndex: Int, startingSpaces: Int, daysInMonth: Int) -> some View {
        let cellIndex = row * 7 + col
        let dayNumber = cellIndex - startingSpaces + 1
        
        if cellIndex < startingSpaces || dayNumber > daysInMonth {
            return AnyView(
                Text("")
                    .frame(width: 14, height: 14)
            )
        } else {
            let dayDate = calendar.date(from: DateComponents(year: currentYear, month: monthIndex + 1, day: dayNumber)) ?? Date()
            let isSelected = calendar.isDate(dayDate, inSameDayAs: selectedDate)
            let isToday = calendar.isDateInToday(dayDate)
            let phaseForDate = phaseManager.phase(for: dayDate)
            
            let textColor: Color = isSelected ? .white : (isToday ? .red : .primary)
            let backgroundColor: Color = isSelected ? .red : (isToday ? .red.opacity(0.1) : (phaseForDate?.color.swiftUIColor.opacity(0.3) ?? .clear))
            
            return AnyView(
                Text("\(dayNumber)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(textColor)
                    .frame(width: 14, height: 14)
                    .background(Color.clear)
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
                    let phaseForDate = phaseManager.phase(for: dayDate)
                    let isToday = calendar.isDateInToday(dayDate)
                    
                    // Get adjacent phase info for connected backgrounds
                    let leftPhase = col > 0 ? getPhaseForCell(row: row, col: col - 1, monthIndex: monthIndex, startingSpaces: startingSpaces, daysInMonth: daysInMonth) : nil
                    let rightPhase = col < 6 ? getPhaseForCell(row: row, col: col + 1, monthIndex: monthIndex, startingSpaces: startingSpaces, daysInMonth: daysInMonth) : nil
                    
                    let baseColor = isToday ? Color.red.opacity(0.1) : (phaseForDate?.color.swiftUIColor.opacity(0.3) ?? Color.clear)
                    
                    // Create connected background shape
                    let leftConnected = phaseForDate?.id == leftPhase?.id && phaseForDate != nil
                    let rightConnected = phaseForDate?.id == rightPhase?.id && phaseForDate != nil
                    
                    Rectangle()
                        .fill(baseColor)
                        .frame(width: 16, height: 14)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: leftConnected ? 0 : 3,
                                bottomLeadingRadius: leftConnected ? 0 : 3,
                                bottomTrailingRadius: rightConnected ? 0 : 3,
                                topTrailingRadius: rightConnected ? 0 : 3
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
    
    private func getPhaseForCell(row: Int, col: Int, monthIndex: Int, startingSpaces: Int, daysInMonth: Int) -> WeightPhase? {
        let cellIndex = row * 7 + col
        let dayNumber = cellIndex - startingSpaces + 1
        
        guard cellIndex >= startingSpaces && dayNumber <= daysInMonth else { return nil }
        guard let cellDate = calendar.date(from: DateComponents(year: currentYear, month: monthIndex + 1, day: dayNumber)) else { return nil }
        
        return phaseManager.phase(for: cellDate)
    }
}

