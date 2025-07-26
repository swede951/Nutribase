//
//  GridCardDropDelegate.swift
//  nutribase
//
//  Created on 24/07/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct GridCardDropDelegate: DropDelegate {
    let card: DashboardCard
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
                      let fromIndex = cards.firstIndex(of: draggedCard),
                      let toIndex = cards.firstIndex(of: card) else { return }
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    // Handle the move
                    if fromIndex != toIndex {
                        cards.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                        
                        // Save the updated card order
                        saveCardOrder()
                    }
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
