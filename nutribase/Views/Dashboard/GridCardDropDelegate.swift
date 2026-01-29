//
//  GridCardDropDelegate.swift
//  nutribase
//
//  Created on 24/07/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct GridCardDropDelegate: DropDelegate {
    let target: CardType
    @Binding var cards: [DashboardCard]
    @Binding var dragged: CardType?
    @Binding var hoverTarget: CardType?
    @Binding var isDragging: Bool

    func dropEntered(info: DropInfo) {
        // Track hover for highlight
        hoverTarget = target

        guard let dragged = dragged, dragged != target else { return }
        guard
            let fromIndex = cards.firstIndex(where: { $0.cardType == dragged }),
            let toIndex = cards.firstIndex(where: { $0.cardType == target })
        else { return }

        if fromIndex == toIndex { return }

        // Only animate the reorder. Do NOT save here.
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            cards.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        // End drag with NO animation to prevent minus-button flicker
        withTransaction(Transaction(animation: nil)) {
            hoverTarget = nil
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
        if hoverTarget == target { hoverTarget = nil }
    }

    private func saveCardOrder() {
        let cardTypes = cards.map { $0.cardType }
        if let encodedData = try? JSONEncoder().encode(cardTypes) {
            UserDefaults.standard.set(encodedData, forKey: "dashboardCardOrder")
        }
    }
}
