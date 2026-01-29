import SwiftUI

/// Fallback drop delegate that catches any drops not handled by card-specific delegates
/// This ensures draggedCardId is always reset when a drag ends
struct DashboardFallbackDropDelegate: DropDelegate {
    @Binding var dragged: CardType?
    @Binding var isDragging: Bool
    
    func performDrop(info: DropInfo) -> Bool {
        dragged = nil
        isDragging = false
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        // Don't clear - still dragging, just left this zone
    }
}
