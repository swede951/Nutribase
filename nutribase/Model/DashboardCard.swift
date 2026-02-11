//
//  DashboardCard.swift
//  nutribase
//
//  Created on 23/07/2025.
//

import Foundation
import SwiftUI

struct DashboardCard: Identifiable, Equatable {
    let id = UUID()
    var cardType: CardType
    var size: CardSize
    
    init(cardType: CardType) {
        self.cardType = cardType
        self.size = cardType.size
    }
    
    static func == (lhs: DashboardCard, rhs: DashboardCard) -> Bool {
        return lhs.id == rhs.id
    }
}
