//
//  WeightPhase.swift
//  nutribase
//
//  Created on 14/08/2025.
//

import Foundation
import SwiftUI

struct WeightPhase: Identifiable, Codable {
    var id: UUID
    let name: String
    let description: String
    let startDate: Date
    let endDate: Date
    let targetWeeklyRate: Double // kg per week (negative for cutting, positive for bulking)
    let color: PhaseColor
    let notes: String?
    let goalWeight: Double? // Store the original goal weight entered by user
    let isOpenEnded: Bool // Flag to indicate if this phase auto-extends
    
    init(id: UUID = UUID(), name: String, description: String, startDate: Date, endDate: Date, targetWeeklyRate: Double, color: PhaseColor, notes: String? = nil, goalWeight: Double? = nil, isOpenEnded: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.targetWeeklyRate = targetWeeklyRate
        self.color = color
        self.notes = notes
        self.goalWeight = goalWeight
        self.isOpenEnded = isOpenEnded
    }
    
    // Computed property for effective end date that auto-extends for open-ended phases
    // Returns end of day (23:59:59) to include all weight entries on the end date
    var effectiveEndDate: Date {
        let calendar = Calendar.current
        
        let baseEndDate: Date
        if isOpenEnded {
            // For open-ended phases, always extend to end of current month
            let now = Date()
            
            guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
                  let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth),
                  let endOfMonth = calendar.date(byAdding: .day, value: -1, to: startOfNextMonth) else {
                baseEndDate = endDate
                return endOfDayFor(baseEndDate, calendar: calendar)
            }
            baseEndDate = endOfMonth
        } else {
            baseEndDate = endDate
        }
        
        return endOfDayFor(baseEndDate, calendar: calendar)
    }
    
    // Helper to get end of day (23:59:59) for a given date
    private func endOfDayFor(_ date: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(hour: 23, minute: 59, second: 59), to: startOfDay) ?? date
    }
    
    // Check if this phase is currently active
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= effectiveEndDate
    }
    
    // Get the duration of the phase in weeks
    var durationInWeeks: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear], from: startDate, to: effectiveEndDate)
        return max(1, components.weekOfYear ?? 1)
    }
    
    // Get formatted target rate string
    var formattedTargetRate: String {
        let sign = targetWeeklyRate >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", targetWeeklyRate)) kg/week"
    }
    
    // Get the SwiftUI color for this phase
    var swiftUIColor: Color {
        return color.swiftUIColor
    }
}

enum PhaseColor: String, CaseIterable, Codable {
    case blue = "blue"           // Weight/Daily Goals blue
    case purple = "purple"       // Calories purple
    case green = "green"         // Protein green
    case yellow = "yellow"       // Carbs yellow
    case pink = "pink"           // Fat pink
    case orange = "orange"       // Orange accent
    
    var swiftUIColor: Color {
        switch self {
        case .blue: return Color(hex: "#1961AE")     // Ocean Deep
        case .purple: return Color(hex: "#61007D")   // Indigo
        case .green: return Color(hex: "#79C300")    // Yellow Green
        case .yellow: return Color(hex: "#F2CD00")   // Gold
        case .pink: return Color(hex: "#CD001A")     // Flag Red
        case .orange: return Color(hex: "#EF6A00")   // Autumn Leaf
        }
    }
    
    var displayName: String {
        switch self {
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .pink: return "Pink"
        case .orange: return "Orange"
        }
    }
}

// Extension to provide sample phases
extension WeightPhase {
    static let samplePhases: [WeightPhase] = [
        WeightPhase(
            name: "Cutting Phase",
            description: "Focus on fat loss while maintaining muscle mass",
            startDate: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date(),
            targetWeeklyRate: -0.5,
            color: .pink
        ),
        WeightPhase(
            name: "Maintenance Phase",
            description: "Maintain current weight and body composition",
            startDate: Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date(),
            targetWeeklyRate: 0.0,
            color: .blue
        )
    ]
}
