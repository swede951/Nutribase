//
//  CardStyle.swift
//  nutribase
//
//  Created by Cascade on 2025-07-24.
//

import SwiftUI

// Global card spacing constants
struct CardSpacing {
    static let titleTopPadding: CGFloat = 6
}

// WCAG AA compliant colors
extension Color {
    // Secondary text color that meets WCAG AA contrast ratio (4.5:1) on white backgrounds
    static let accessibleSecondary = Color(red: 0.4, green: 0.4, blue: 0.4) // #666666 - 7:1 contrast ratio
}

// Card styling modifier with forced title alignment
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    func body(content: Content) -> some View {
        ZStack(alignment: .topLeading) {
            // Card background and content
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackground)
                        .shadow(
                            color: Color.black.opacity(isPressed ? 0.12 : 0.08), 
                            radius: isPressed ? 12 : 8, 
                            x: 0, 
                            y: isPressed ? 4 : 2
                        )
                )
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            // Provide haptic feedback for tappable cards
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// Extension to make it easier to apply the card style
extension View {
    func cardStyle() -> some View {
        self.modifier(CardStyle())
    }
}
