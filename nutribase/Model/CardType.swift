//
//  CardType.swift
//  nutribase
//
//  Created on 03/06/2025.
//

import Foundation
import SwiftUI

enum CardSize {
    case oneByOne
    case twoByOne
}

enum CardType: String, CaseIterable, Identifiable, Codable {
    case currentWeight = "Current Weight"
    case weightChart = "Weight Chart"
    case calorieTarget = "Calorie Target"
    case protein = "Protein"
    case carbs = "Carbs"
    case fat = "Fat"
    case fibre = "Fibre"
    // case water = "Water" // TEMPORARILY DISABLED
    case activity = "Activity"
    case dailyGoals = "Daily Goals"
    case novaGroups = "NOVA Groups"
    case nutriScore = "Nutri-Score"
    case gutHealth = "Gut Health"
    case empty = "Empty Slot"
    

    
    var id: String { self.rawValue }
    
    var systemImage: String {
        switch self {
        case .currentWeight:
            return "scalemass.fill"
        case .weightChart:
            return "chart.line.uptrend.xyaxis"
        case .calorieTarget:
            return "flame.fill"
        case .protein:
            return "chart.bar.fill"
        case .carbs:
            return "leaf.fill"
        case .fat:
            return "drop.fill"
        case .fibre:
            return "bolt.fill"
        // case .water: // TEMPORARILY DISABLED
        //     return "drop.fill"
        case .activity:
            return "figure.walk"
        case .dailyGoals:
            return "target"
        case .novaGroups:
            return "circle.grid.2x2.fill"
        case .nutriScore:
            return "a.circle.fill"
        case .gutHealth:
            return "leaf.arrow.triangle.circlepath"
        case .empty:
            return "plus"
        }
    }
    
    var color: Color {
        switch self {
        case .currentWeight, .weightChart:
            return .blue
        case .calorieTarget:
            return Color(red: 0.6, green: 0.2, blue: 0.8) // Vibrant purple to match daily goals
        case .protein:
            return Color(red: 0.2, green: 0.8, blue: 0.2) // Bright green to match daily goals
        case .carbs:
            return Color(red: 1.0, green: 0.8, blue: 0.0) // Bright yellow to match daily goals
        case .fat:
            return Color(red: 1.0, green: 0.4, blue: 0.6) // Bright pink to match daily goals
        case .fibre:
            return Color(red: 0.4, green: 0.7, blue: 0.4) // Earthy green for fibre
        // case .water: // TEMPORARILY DISABLED
        //     return .blue
        case .activity:
            return .pink
        case .dailyGoals:
            return Color(red: 0.0, green: 0.5, blue: 1.0) // Bright blue
        case .novaGroups:
            return .indigo
        case .nutriScore:
            return .green
        case .gutHealth:
            return Color(red: 0.2, green: 0.7, blue: 0.5) // Teal green for gut health
        case .empty:
            return .gray
        }
    }
    
    var size: CardSize {
        switch self {
        case .dailyGoals, .novaGroups, .nutriScore, .gutHealth:
            return .twoByOne
        default:
            return .oneByOne
        }
    }
}
