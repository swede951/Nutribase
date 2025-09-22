import SwiftUI

struct CardDropDelegate: DropDelegate {
    let item: CardType
    @Binding var items: [CardType]
    let current: Int
    
    // Static properties for drag and drop state management
    static var draggedIndex: Int = 0
    static var isPerformingDrop: Bool = false
    
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
        if CardDropDelegate.isPerformingDrop {
            return
        }
        
        // Set flag to indicate we're performing a drop operation
        CardDropDelegate.isPerformingDrop = true
        
        // Use the stored dragged index
        let sourceIndex = CardDropDelegate.draggedIndex
        
        // Make sure we're not dropping on the same position and indices are valid
        guard sourceIndex != current,
              sourceIndex >= 0, sourceIndex < items.count,
              current >= 0, current < items.count else {
            CardDropDelegate.isPerformingDrop = false
            return
        }
        
        // Create a snapshot of the items array to work with
        let itemsSnapshot = Array(items)
        
        // Capture the current value to avoid race conditions
        let targetIndex = self.current
        
        // Use a dispatch queue with a slight delay to ensure state updates happen on the main thread
        // and are properly sequenced to avoid AttributeGraph errors
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Use a simpler animation to reduce the chance of crashes
            withAnimation(.easeInOut(duration: 0.3)) {
                // Handle the special case for cards that span 2 slots (NOVA Groups and Nutri-Score)
                if self.isWideCard(at: sourceIndex) {
                    // Only move wide cards to even indices (start of row)
                    if targetIndex % 2 == 0 {
                        self.moveWideCard(from: sourceIndex, to: targetIndex)
                    }
                } else if targetIndex < itemsSnapshot.count && (
                          (itemsSnapshot[targetIndex] == .novaGroups && self.findPairedCardIndex(for: targetIndex, type: .novaGroups, in: itemsSnapshot) != -1) ||
                          (itemsSnapshot[targetIndex] == .nutriScore && self.findPairedCardIndex(for: targetIndex, type: .nutriScore, in: itemsSnapshot) != -1)) {
                    // If dropping on a wide card (NOVA Groups or Nutri-Score), find the first card of the pair
                    let firstCardIndex = self.findFirstCardOfPair(at: targetIndex, in: itemsSnapshot)
                    if firstCardIndex != -1 {
                        // Move to the first card of the wide card pair
                        self.reorderCard(from: sourceIndex, to: firstCardIndex)
                    }
                } else {
                    // For regular cards, reorder instead of swapping
                    self.reorderCard(from: sourceIndex, to: targetIndex)
                }
            }
        }
        
        // Update the dragged index to the new position
        CardDropDelegate.draggedIndex = current
        
        // Reset the flag after a short delay to allow the animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            CardDropDelegate.isPerformingDrop = false
        }
    }
    
    // Check if the card at the given index is a wide card (NOVA Groups or Nutri-Score)
    private func isWideCard(at index: Int) -> Bool {
        // Check if this is a wide card (with a second one after or before it)
        return (items[index] == .novaGroups && 
               ((index + 1 < items.count && items[index + 1] == .novaGroups) ||
                (index > 0 && items[index - 1] == .novaGroups))) ||
               (items[index] == .nutriScore && 
               ((index + 1 < items.count && items[index + 1] == .nutriScore) ||
                (index > 0 && items[index - 1] == .nutriScore)))
    }
    
    // Handle moving a wide card (NOVA Groups or Nutri-Score) which spans 2 slots
    private func moveWideCard(from fromIndex: Int, to toIndex: Int) {
        let cardType = items[fromIndex]
        
        // Ensure we're working with the first card of the pair
        let actualFromIndex = (fromIndex > 0 && items[fromIndex - 1] == cardType) ? fromIndex - 1 : fromIndex
        
        // Only allow moving to even indices (start of row) for wide cards
        if toIndex % 2 != 0 {
            CardDropDelegate.isPerformingDrop = false
            return
        }
        
        // Create a copy of the items array
        var newItems = items
        
        // Find the second card index
        let secondCardIndex = actualFromIndex + 1
        
        // Ensure we have valid indices
        guard secondCardIndex < newItems.count,
              actualFromIndex >= 0,
              actualFromIndex < newItems.count,
              newItems[actualFromIndex] == cardType,
              newItems[secondCardIndex] == cardType else {
            print("Invalid indices or card types for wide card move")
            CardDropDelegate.isPerformingDrop = false
            return
        }
        
        // Ensure the target position is valid
        guard toIndex >= 0, toIndex < newItems.count else {
            print("Invalid target position for wide card move")
            CardDropDelegate.isPerformingDrop = false
            return
        }
        
        // First, temporarily replace the wide card with empty slots
        newItems[actualFromIndex] = .empty
        newItems[secondCardIndex] = .empty
        
        // Make sure we have space for the wide card at the target position
        if toIndex + 1 >= newItems.count {
            newItems.append(.empty)
        }
        
        // Create a proper insertion-based reordering
        // First, make sure we have room for the wide card (2 slots)
        // We need to insert empty slots at the target position and shift everything down
        
        // Save all cards from toIndex onwards
        let cardsAfterTarget = Array(newItems[toIndex..<newItems.count])
        
        // Replace the target position and next slot with the wide card
        if toIndex + 1 < newItems.count {
            newItems[toIndex] = cardType
            newItems[toIndex + 1] = cardType
            
            // Now shift all the saved cards down by 2 positions (or 1 if we're replacing an empty slot)
            var insertIndex = toIndex + 2
            for card in cardsAfterTarget {
                // Skip the cards we just replaced
                if insertIndex < newItems.count {
                    newItems[insertIndex] = card
                } else {
                    // If we've reached the end, append
                    newItems.append(card)
                }
                insertIndex += 1
            }
            
            // Trim the array if it grew too large
            if insertIndex < newItems.count {
                newItems.removeSubrange(insertIndex..<newItems.count)
            }
        } else {
            // We're at the end, just add the wide card
            newItems[toIndex] = cardType
            newItems.append(cardType)
        }
        
        // Clean up any consecutive empty slots
        var i = 0
        while i < newItems.count - 1 {
            if newItems[i] == .empty && newItems[i + 1] == .empty {
                newItems.remove(at: i + 1)
            } else {
                i += 1
            }
        }
        
        // Update the items array
        items = newItems
        
        // Explicitly trigger rebalancing to ensure wide cards maintain their two-column width
        // This is especially important for the Nutri-Score card
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("RebalanceDashboard"), object: nil)
        }
    }
    
    // These functions are no longer needed as the logic is now in moveWideCard
    // Keeping them as empty implementations for now in case they're referenced elsewhere
    private func removeNovaCards(from index: Int, in array: inout [CardType]) {
        // Functionality moved to moveWideCard
    }
    
    private func insertNovaCards(at index: Int, in array: inout [CardType]) {
        // Functionality moved to moveWideCard
    }
    
    // Find an empty slot and place a card there
    private func findEmptySlotAndPlace(card: CardType, in array: inout [CardType]) {
        if let emptyIndex = array.firstIndex(of: .empty) {
            array[emptyIndex] = card
        }
    }
    
    // For regular cards, reorder them using iOS-like grid management
    private func reorderCard(from fromIndex: Int, to toIndex: Int) {
        // Validate indices to prevent out-of-bounds errors
        guard fromIndex >= 0, fromIndex < items.count,
              toIndex >= 0, toIndex < items.count else {
            print("Invalid indices for card reordering: from \(fromIndex) to \(toIndex)")
            CardDropDelegate.isPerformingDrop = false
            return
        }
        
        // Create a copy of the items array
        var newItems = self.items
        
        // Get the card being moved
        let movingCard = newItems[fromIndex]
        
        // Check if we're moving to a position occupied by a wide card
        if isWideCard(at: toIndex) {
            // Find the first card of the wide pair
            let firstCardIndex = findFirstCardOfPair(at: toIndex, in: newItems)
            if firstCardIndex != -1 {
                // iOS-like behavior: Move the wide card out of the way first
                // Find the next available position after the card being moved
                let availablePosition = findNextAvailablePosition(after: fromIndex, in: newItems)
                if availablePosition != -1 {
                    // Move the wide card to the available position
                    moveWideCard(from: firstCardIndex, to: availablePosition)
                    
                    // Now place the moving card at the target position
                    newItems[toIndex] = movingCard
                    newItems[fromIndex] = .empty
                    
                    // Update the items array
                    self.items = newItems
                    return
                }
            }
        }
        
        // Standard reordering for regular positions
        // Determine direction of movement
        if fromIndex < toIndex {
            // Moving forward: shift cards backward
            for i in fromIndex..<toIndex {
                guard i + 1 < newItems.count else {
                    print("Index out of bounds in reorderCard: \(i + 1)")
                    CardDropDelegate.isPerformingDrop = false
                    return
                }
                newItems[i] = newItems[i + 1]
            }
        } else {
            // Moving backward: shift cards forward
            for i in (toIndex + 1...fromIndex).reversed() {
                guard i - 1 >= 0 else {
                    print("Index out of bounds in reorderCard: \(i - 1)")
                    CardDropDelegate.isPerformingDrop = false
                    return
                }
                newItems[i] = newItems[i - 1]
            }
        }
        
        // Place the moving card at the target position
        newItems[toIndex] = movingCard
        
        // Update the items array
        self.items = newItems
    }
    
    // Find the next available position after a given index
    private func findNextAvailablePosition(after index: Int, in array: [CardType]) -> Int {
        // Look for empty slots first
        for i in 0..<array.count where array[i] == .empty {
            // For wide cards, need two consecutive empty slots starting at an even index
            if i % 2 == 0 && i + 1 < array.count && array[i + 1] == .empty {
                return i
            }
        }
        
        // If no empty slots, find the end of the array (this would push other cards)
        if array.count >= 2 {
            // Return the last position that can fit a wide card
            let lastEvenIndex = (array.count - 2) - (array.count - 2) % 2
            return lastEvenIndex
        }
        
        return -1 // No suitable position found
    }
    
    // Helper function to find the paired card index for wide cards
    private func findPairedCardIndex(for index: Int, type: CardType, in array: [CardType]) -> Int {
        // Check if the card at the given index is of the specified type
        guard index >= 0, index < array.count, array[index] == type else { return -1 }
        
        // Check adjacent indices for another card of the same type
        if index > 0 && array[index - 1] == type {
            return index - 1
        }
        if index + 1 < array.count && array[index + 1] == type {
            return index + 1
        }
        
        // No paired card found
        return -1
    }
    
    // This duplicate method was removed
    
    // Helper function to find the first card of a wide card pair
    private func findFirstCardOfPair(at index: Int, in array: [CardType]) -> Int {
        // Check if the index is valid
        guard index >= 0, index < array.count else { return -1 }
        
        let cardType = array[index]
        
        // Only NOVA Groups and Nutri-Score are wide cards
        guard cardType == .novaGroups || cardType == .nutriScore else { return -1 }
        
        // If this card has another card of the same type before it, then this is the second card
        if index > 0 && array[index - 1] == cardType {
            return index - 1 // Return the index of the first card
        }
        
        // If this card has another card of the same type after it, then this is the first card
        if index + 1 < array.count && array[index + 1] == cardType {
            return index // This is already the first card
        }
        
        // This is a single card (not part of a pair)
        return -1
    }
}
