//
//  CardStyle.swift
//  nutribase
//
//  Created by Cascade on 2025-07-24.
//

import SwiftUI

// Global card spacing constants
struct CardSpacing {
    static let titleTopPadding: CGFloat = 10
}

// Card styling modifier for consistent card appearance across the app
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.top, CardSpacing.titleTopPadding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#FFFFFF"))
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
    }
}

// Extension to make it easier to apply the card style
extension View {
    func cardStyle() -> some View {
        self.modifier(CardStyle())
    }
}
