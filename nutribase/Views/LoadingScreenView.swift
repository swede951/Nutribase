//
//  LoadingScreenView.swift
//  nutribase
//
//  Created by Cascade on 2025-11-10.
//

import SwiftUI

struct LoadingScreenView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background color
            Color(hex: "#35b8ff")
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // App icon
                Image("app-logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 180)
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
    }
}

#Preview {
    LoadingScreenView()
}
