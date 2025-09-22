import SwiftUI
import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // Light feedback for UI interactions like button taps
    func lightFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // Medium feedback for more significant actions
    func mediumFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // Success feedback for completed actions
    func successFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // Error feedback for failed actions
    func errorFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}

// SwiftUI View extension to easily add haptic feedback to any view
extension View {
    func withHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.onTapGesture {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        }
    }
}
