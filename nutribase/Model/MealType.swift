//
//  MealType.swift
//  nutribase
//
//  Created on 11/07/2025.
//

import Foundation
import SwiftUI

enum MealType: String, CaseIterable, Identifiable, Codable {
    case caloriesSummary = "Calories Summary"
    case dailyGoals = "Daily Goals"
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snacks = "Snacks"
    
    var id: String { self.rawValue }
    
    var systemImage: String {
        switch self {
        case .caloriesSummary:
            return "flame.fill"
        case .dailyGoals:
            return "chart.bar.fill"
        case .breakfast:
            return "sunrise.fill"
        case .lunch:
            return "sun.max.fill"
        case .dinner:
            return "sunset.fill"
        case .snacks:
            return "carrot.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .caloriesSummary:
            return .red
        case .dailyGoals:
            return .indigo
        case .breakfast:
            return .orange
        case .lunch:
            return .blue
        case .dinner:
            return .purple
        case .snacks:
            return .green
        }
    }
}
