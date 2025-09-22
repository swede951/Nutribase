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
    
    init(id: UUID = UUID(), name: String, description: String, startDate: Date, endDate: Date, targetWeeklyRate: Double, color: PhaseColor, notes: String? = nil, goalWeight: Double? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.targetWeeklyRate = targetWeeklyRate
        self.color = color
        self.notes = notes
        self.goalWeight = goalWeight
    }
    
    // Check if this phase is currently active
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    // Get the duration of the phase in weeks
    var durationInWeeks: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear], from: startDate, to: endDate)
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
    case red = "red"
    case green = "green"
    case blue = "blue"
    case orange = "orange"
    case purple = "purple"
    case pink = "pink"
    
    var swiftUIColor: Color {
        switch self {
        case .red: return .red
        case .green: return .green
        case .blue: return .blue
        case .orange: return .orange
        case .purple: return .purple
        case .pink: return .pink
        }
    }
    
    var displayName: String {
        return rawValue.capitalized
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
            color: .red
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
