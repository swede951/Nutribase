//
//  NovaClassification.swift
//  nutribase
//
//  Created on 03/06/2025.
//

import Foundation
import SwiftUI

enum NovaClassification: Int, CaseIterable, Identifiable {
    case group1 = 1
    case group2 = 2
    case group3 = 3
    case group4 = 4
    
    var id: Int { self.rawValue }
    
    var description: String {
        switch self {
        case .group1:
            return "Unprocessed or minimally processed foods"
        case .group2:
            return "Processed culinary ingredients"
        case .group3:
            return "Processed foods"
        case .group4:
            return "Ultra-processed foods"
        }
    }
    
    var color: Color {
        switch self {
        case .group1:
            return .green
        case .group2:
            return .blue
        case .group3:
            return .orange
        case .group4:
            return .red
        }
    }
    
    var examples: String {
        switch self {
        case .group1:
            return "Fresh fruits, vegetables, grains, legumes, meat, eggs, milk"
        case .group2:
            return "Salt, sugar, oils, butter, vinegar"
        case .group3:
            return "Canned vegetables, cheese, freshly made bread"
        case .group4:
            return "Soft drinks, packaged snacks, breakfast cereals, reconstituted meat products"
        }
    }
}
