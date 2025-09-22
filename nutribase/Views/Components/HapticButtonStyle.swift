import SwiftUI

struct HapticButtonStyle: ButtonStyle {
    var feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { wasPressed, isPressed in
                if isPressed {
                    let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
                    generator.impactOccurred()
                }
            }
    }
}

extension Button {
    func withHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.buttonStyle(HapticButtonStyle(feedbackStyle: style))
    }
}
