//
//  GridEmptySpaceDropDelegate.swift
//  nutribase
//
//  Created on 24/07/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct GridEmptySpaceDropDelegate: DropDelegate {
    @Binding var cards: [DashboardCard]
    let insertionIndex: Int
    
    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.text]).first else {
            return false
        }
        
        item.loadItem(forTypeIdentifier: UTType.text.identifier as String, options: nil) { (data, error) in
            DispatchQueue.main.async {
                guard let data = data as? Data,
                      let idString = String(data: data, encoding: .utf8),
                      let draggedUUID = UUID(uuidString: idString),
                      let draggedCard = cards.first(where: { $0.id == draggedUUID }),
                      let fromIndex = cards.firstIndex(of: draggedCard) else { return }
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    // Remove the card from its current position
                    let movedCard = cards.remove(at: fromIndex)
                    
                    // Calculate the correct insertion index after removal
                    let adjustedInsertionIndex = insertionIndex > fromIndex ? insertionIndex - 1 : insertionIndex
                    let finalInsertionIndex = min(adjustedInsertionIndex, cards.count)
                    
                    // Insert the card at the new position
                    cards.insert(movedCard, at: finalInsertionIndex)
                    
                    // Save the updated card order
                    saveCardOrder()
                }
            }
        }
        
        return true
    }
    
    private func saveCardOrder() {
        let cardTypes = cards.map { $0.cardType }
        if let encodedData = try? JSONEncoder().encode(cardTypes) {
            UserDefaults.standard.set(encodedData, forKey: "dashboardCardOrder")
        }
    }
}
