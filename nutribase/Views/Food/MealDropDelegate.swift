import SwiftUI

struct MealDropDelegate: DropDelegate {
    let item: MealType
    @Binding var items: [MealType]
    let current: Int
    
    // Static properties for drag and drop state management
    static var draggedIndex: Int = 0
    static var isPerformingDrop: Bool = false
    
    func performDrop(info: DropInfo) -> Bool {
        // Set flag to indicate drop is complete
        MealDropDelegate.isPerformingDrop = false
        
        // Save the meal order to UserDefaults after drop is completed
        DispatchQueue.main.async {
            // This ensures the UI updates first before saving
            NotificationCenter.default.post(name: Notification.Name("SaveFoodLogLayout"), object: nil)
        }
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Prevent concurrent updates that can cause crashes
        if MealDropDelegate.isPerformingDrop {
            return
        }
        
        // Set flag to indicate we're performing a drop operation
        MealDropDelegate.isPerformingDrop = true
        
        // Use the stored dragged index
        let sourceIndex = MealDropDelegate.draggedIndex
        
        // Make sure we're not dropping on the same position and indices are valid
        guard sourceIndex != current,
              sourceIndex >= 0, sourceIndex < items.count,
              current >= 0, current < items.count else {
            MealDropDelegate.isPerformingDrop = false
            return
        }
        
        // Use a simpler animation to reduce the chance of crashes
        withAnimation(.easeInOut(duration: 0.3)) {
            // For meal cards, reorder them (move without swapping)
            reorderMeal(from: sourceIndex, to: current)
        }
        
        // Update the dragged index to the new position
        MealDropDelegate.draggedIndex = current
        
        // Reset the flag after a short delay to allow the animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            MealDropDelegate.isPerformingDrop = false
        }
    }
    
    // For meal cards, reorder them (move without swapping)
    private func reorderMeal(from fromIndex: Int, to toIndex: Int) {
        // Create a copy of the items array
        var newItems = self.items
        
        // Get the meal being moved
        let movingMeal = newItems[fromIndex]
        
        // Determine direction of movement
        if fromIndex < toIndex {
            // Moving forward: shift meals backward
            for i in fromIndex..<toIndex {
                newItems[i] = newItems[i + 1]
            }
        } else {
            // Moving backward: shift meals forward
            for i in (toIndex + 1...fromIndex).reversed() {
                newItems[i] = newItems[i - 1]
            }
        }
        
        // Place the moving meal at the target position
        newItems[toIndex] = movingMeal
        
        // Update the items array
        self.items = newItems
    }
}
