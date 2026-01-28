//
//  GlobalCardStructure.swift
//  nutribase
//

import SwiftUI

// MANDATORY STRUCTURE FOR ALL CARDS
struct GlobalCard<Content: View>: View {
    let title: String
    let showInfoButton: Bool
    let onInfoTap: (() -> Void)?
    let onCardTap: (() -> Void)?
    let content: Content
    
    init(title: String, showInfoButton: Bool = false, onInfoTap: (() -> Void)? = nil, onCardTap: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.showInfoButton = showInfoButton
        self.onInfoTap = onInfoTap
        self.onCardTap = onCardTap
        self.content = content()
    }
    
    var body: some View {
        Button(action: { onCardTap?() }) {
            ZStack {
                // BACKGROUND
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                    .overlay(
                        // Debug border to see actual card boundaries
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                
                // CONTENT AREA - POSITIONED BELOW TITLE
                VStack(alignment: .leading, spacing: 0) {
                    // RESERVED SPACE FOR TITLE - EXACTLY 32pt
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 32)
                    
                    // CONTENT SECTION
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // TITLE OVERLAY - ABSOLUTE POSITIONING
                VStack {
                    HStack {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                        if showInfoButton {
                            Button(action: { onInfoTap?() }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .frame(height: 24)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    Spacer()
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 120, maxHeight: 120)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
