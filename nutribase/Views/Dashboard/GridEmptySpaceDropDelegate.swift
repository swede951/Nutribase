//
//  GridEmptySpaceDropDelegate.swift
//  nutribase
//
//  Created on 24/07/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct GridEmptySpaceDropDelegate: DropDelegate {
    let insertionIndex: Int
    @Binding var cards: [DashboardCard]
    @Binding var dragged: CardType?
    @Binding var isDragging: Bool

    func dropEntered(info: DropInfo) {
        guard let dragged = dragged,
              let fromIndex = cards.firstIndex(where: { $0.cardType == dragged })
        else { return }

        // Prevent churn if already at or adjacent to insertion point
        if fromIndex == insertionIndex || fromIndex + 1 == insertionIndex { return }

        // Reorder preview animation only (no saving here)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            cards.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: insertionIndex > fromIndex ? insertionIndex : insertionIndex
            )
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        // End drag with NO animation to prevent minus-button flicker
        withTransaction(Transaction(animation: nil)) {
            dragged = nil
            isDragging = false
        }

        saveCardOrder()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        // Don't clear dragged - still dragging, just left this zone
    }

    private func saveCardOrder() {
        let cardTypes = cards.map { $0.cardType }
        if let encodedData = try? JSONEncoder().encode(cardTypes) {
            UserDefaults.standard.set(encodedData, forKey: "dashboardCardOrder")
        }
    }
}
