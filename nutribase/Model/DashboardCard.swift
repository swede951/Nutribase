//
//  DashboardCard.swift
//  nutribase
//
//  Created on 23/07/2025.
//

import Foundation
import SwiftUI

struct DashboardCard: Identifiable, Equatable {
    var cardType: CardType
    var size: CardSize
    
    // Use cardType as stable identity (no duplicate card types on dashboard)
    var id: CardType { cardType }
    
    init(cardType: CardType) {
        self.cardType = cardType
        self.size = cardType.size
    }
    
    static func == (lhs: DashboardCard, rhs: DashboardCard) -> Bool {
        return lhs.cardType == rhs.cardType
    }
}
