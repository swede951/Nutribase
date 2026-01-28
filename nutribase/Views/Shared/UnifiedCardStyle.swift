//
//  UnifiedCardStyle.swift
//  nutribase
//
//  Created by Cascade on 2025-10-24.
//

import SwiftUI

// Unified card modifier that forces identical title positioning for ALL cards
struct UnifiedCardStyle: ViewModifier {
    let title: String
    let showInfoButton: Bool
    let onInfoTap: (() -> Void)?
    @State private var isPressed = false
    
    init(title: String, showInfoButton: Bool = false, onInfoTap: (() -> Void)? = nil) {
        self.title = title
        self.showInfoButton = showInfoButton
        self.onInfoTap = onInfoTap
    }
    
    func body(content: Content) -> some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#FFFFFF"))
                .shadow(
                    color: Color.black.opacity(isPressed ? 0.12 : 0.08), 
                    radius: isPressed ? 12 : 8, 
                    x: 0, 
                    y: isPressed ? 4 : 2
                )
            
            // Content with forced structure
            VStack(alignment: .leading, spacing: 0) {
                // FORCED IDENTICAL TITLE SECTION
                HStack {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    
                    if showInfoButton {
                        Button(action: {
                            onInfoTap?()
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                                .padding(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .frame(height: 24) // FIXED TITLE HEIGHT
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // CONTENT AREA - FLEXIBLE
                content
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: 120)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// Extension for easy application
extension View {
    func unifiedCardStyle(title: String, showInfoButton: Bool = false, onInfoTap: (() -> Void)? = nil) -> some View {
        self.modifier(UnifiedCardStyle(title: title, showInfoButton: showInfoButton, onInfoTap: onInfoTap))
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("Sample Content")
            .font(.title)
            .unifiedCardStyle(title: "Test Card")
        
        VStack {
            Text("82.5 kg")
                .font(.system(size: 30, weight: .bold))
            Text("from last week")
                .font(.caption)
        }
        .unifiedCardStyle(title: "Weight")
    }
    .padding()
}
