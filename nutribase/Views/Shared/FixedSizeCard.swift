//
//  FixedSizeCard.swift
//  nutribase
//
//  Created by Cascade on 2025-10-24.
//

import SwiftUI

// ULTRA-SIMPLE FIXED SIZE CARD - FORCES EXACT DIMENSIONS
struct FixedSizeCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let title: String
    let showInfoButton: Bool
    let onInfoTap: (() -> Void)?
    let onCardTap: (() -> Void)?
    let content: Content
    let customHeight: CGFloat?
    let titleAction: (() -> Void)?
    let titleActionIcon: String?
    
    /// Card background: white in light mode, grey in dark mode
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    init(title: String, showInfoButton: Bool = false, onInfoTap: (() -> Void)? = nil, onCardTap: (() -> Void)? = nil, customHeight: CGFloat? = nil, titleAction: (() -> Void)? = nil, titleActionIcon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.showInfoButton = showInfoButton
        self.onInfoTap = onInfoTap
        self.onCardTap = onCardTap
        self.customHeight = customHeight
        self.titleAction = titleAction
        self.titleActionIcon = titleActionIcon
        self.content = content()
    }
    
    var body: some View {
        cardContent
            .frame(maxWidth: .infinity, minHeight: customHeight ?? 150, maxHeight: customHeight ?? 150) // GRID-COMPATIBLE
    }
    
    @ViewBuilder
    private var cardContent: some View {
        let cardView = Rectangle()
            .fill(cardBackground)
            .frame(maxWidth: .infinity, minHeight: customHeight ?? 150, maxHeight: customHeight ?? 150) // GRID-FRIENDLY SIZING
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            .overlay(
                ZStack(alignment: .topLeading) {
                    // CONTENT AREA - Full card space
                    VStack {
                        Spacer(minLength: 28) // Space for title
                        content
                            .padding(.horizontal, 16)
                            .padding(.bottom, 4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // TITLE - Overlaid on top with transparent background
                    HStack {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                        if let titleAction = titleAction, let titleActionIcon = titleActionIcon {
                            Button(action: titleAction) {
                                Image(systemName: titleActionIcon)
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        if showInfoButton {
                            Button(action: { onInfoTap?() }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                }
            )
        
        // Only wrap in Button if there's a tap action - this allows drag gestures to work
        if let onCardTap = onCardTap {
            Button(action: onCardTap) {
                cardView
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            cardView
        }
    }
}

#Preview {
    FixedSizeCard(title: "Test Card") {
        VStack {
            Text("83.1 kg")
                .font(.system(size: 30, weight: .bold))
            Text("from last week")
                .font(.caption)
        }
    }
    .padding()
}
