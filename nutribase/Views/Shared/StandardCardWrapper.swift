//
//  StandardCardWrapper.swift
//  nutribase
//
//  Created by Cascade on 2025-10-23.
//

import SwiftUI

// Standardized card wrapper that ensures consistent title positioning across ALL cards
struct StandardCardWrapper<Content: View>: View {
    let title: String
    let showInfoButton: Bool
    let onInfoTap: (() -> Void)?
    let content: Content
    
    init(
        title: String,
        showInfoButton: Bool = false,
        onInfoTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showInfoButton = showInfoButton
        self.onInfoTap = onInfoTap
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // STANDARDIZED TITLE SECTION - IDENTICAL FOR ALL CARDS
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
                            .background(
                                Circle()
                                    .fill(Color.secondary.opacity(0.1))
                                    .opacity(0)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(height: 24) // FIXED HEIGHT FOR TITLE SECTION
            .padding(.bottom, 8) // FIXED SPACING AFTER TITLE
            
            // CONTENT SECTION - FLEXIBLE HEIGHT
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    StandardCardWrapper(title: "Test Card") {
        VStack {
            Text("Sample Content")
                .font(.title)
            Text("More content here")
                .font(.caption)
        }
    }
    .cardStyle()
    .frame(width: 180, height: 120)
}
