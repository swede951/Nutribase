import SwiftUI

struct EmptySlotDropDelegate: DropDelegate {
    @Binding var items: [CardType]
    
    func performDrop(info: DropInfo) -> Bool {
        // Add a small delay before resetting the flag to ensure animations complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            CardDropDelegate.isPerformingDrop = false
            
            // Post notifications after the drop is complete and animations have finished
            NotificationCenter.default.post(name: Notification.Name("SaveDashboardLayout"), object: nil)
            NotificationCenter.default.post(name: Notification.Name("RebalanceDashboard"), object: nil)
        }
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Prevent concurrent updates that can cause AG::Graph::value_ref crashes
        if CardDropDelegate.isPerformingDrop { return }
        CardDropDelegate.isPerformingDrop = true
        let sourceIndex = CardDropDelegate.draggedIndex
        guard sourceIndex >= 0, sourceIndex < items.count else {
            print("Invalid source index: \(sourceIndex)")
            CardDropDelegate.isPerformingDrop = false
            return
        }
        
        // Create a snapshot of the items array to work with - use Array() to create a new copy
        let itemsSnapshot = Array(items)
        
        // Get the dragged card
        let draggedCard = itemsSnapshot[sourceIndex]
        
        // Find the first empty slot in the array
        if let emptyIndex = itemsSnapshot.firstIndex(of: .empty) {
            // Create a copy of the items array to avoid mutation issues
            var newItems = itemsSnapshot
            
            // Use a dispatch queue with a slight delay to ensure state updates happen on the main thread
            // and are properly sequenced to avoid AttributeGraph errors
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                // Special handling for wide cards (NOVA Groups and Nutri-Score)
                if draggedCard == .novaGroups || draggedCard == .nutriScore {
                    // Check if this is part of a wide card pair
                    let isPartOfPair = self.isPartOfWidePair(at: sourceIndex, in: itemsSnapshot)
                    
                    if isPartOfPair {
                        // Only allow moving to even indices (start of row) and ensure there's space
                        if emptyIndex % 2 == 0 && emptyIndex + 1 < newItems.count && newItems[emptyIndex + 1] == .empty {
                            // Get the first card index of the pair
                            let firstCardIndex = self.findFirstCardOfWidePair(at: sourceIndex, in: itemsSnapshot)
                            
                            if firstCardIndex != -1 {
                                // Handle the wide card that spans two columns
                                // Remove the two cards from their original position
                                newItems[firstCardIndex] = .empty
                                if firstCardIndex + 1 < newItems.count {
                                    newItems[firstCardIndex + 1] = .empty
                                }
                                
                                // Place them at the empty slot position
                                newItems[emptyIndex] = draggedCard
                                newItems[emptyIndex + 1] = draggedCard
                                
                                // Use a simpler animation to reduce the chance of crashes
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    self.items = newItems
                                }
                            }
                        } else {
                            // Reset the flag since we're not performing the move
                            print("Cannot move wide card to position \(emptyIndex) - needs two adjacent empty slots")
                            CardDropDelegate.isPerformingDrop = false
                        }
                        return
                    }
                }
                
                // For regular cards, use a simpler approach
                // Use a simpler animation to reduce the chance of crashes
                withAnimation(.easeInOut(duration: 0.3)) {
                    // Create a new copy of the items array to avoid mutation issues during animation
                    var safeItems = Array(self.items)
                    
                    // Only proceed if indices are still valid
                    if sourceIndex < safeItems.count && emptyIndex < safeItems.count {
                        // Remove the card from its original position
                        safeItems[sourceIndex] = .empty
                        
                        // Insert the card at the empty slot position
                        safeItems[emptyIndex] = draggedCard
                        
                        // Update the items array all at once
                        self.items = safeItems
                    } else {
                        print("Index out of bounds prevented: source=\(sourceIndex), empty=\(emptyIndex), count=\(safeItems.count)")
                        CardDropDelegate.isPerformingDrop = false
                    }
                }
            }
            
            // Reset the flag after a short delay to allow the animation to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                CardDropDelegate.isPerformingDrop = false
            }
        } else {
            print("No empty slots available")
            CardDropDelegate.isPerformingDrop = false
        }
    }
    
    // Helper function to check if a card is part of a wide card pair
    private func isPartOfWidePair(at index: Int, in array: [CardType]) -> Bool {
        guard index >= 0, index < array.count else { return false }
        
        let cardType = array[index]
        if cardType != .novaGroups && cardType != .nutriScore { return false }
        
        // Check if there's another card of the same type adjacent to this one
        return (index > 0 && array[index - 1] == cardType) || 
               (index + 1 < array.count && array[index + 1] == cardType)
    }
    
    // Helper function to find the first card of a wide card pair
    private func findFirstCardOfWidePair(at index: Int, in array: [CardType]) -> Int {
        guard index >= 0, index < array.count else { return -1 }
        
        let cardType = array[index]
        if cardType != .novaGroups && cardType != .nutriScore { return -1 }
        
        // If this is the second card, return the index of the first card
        if index > 0 && array[index - 1] == cardType {
            return index - 1
        }
        
        // If this is the first card, return this index
        if index + 1 < array.count && array[index + 1] == cardType {
            return index
        }
        
        // This is not part of a pair
        return -1
    }

    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
