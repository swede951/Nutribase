//
//  SearchIndicatorView.swift
//  nutribase
//
//  Created on 16/07/2025.
//

import SwiftUI

struct SearchIndicatorView: View {
    let isSemanticSearchActive: Bool
    let isFuzzySearchActive: Bool
    let searchText: String
    
    var body: some View {
        Group {
            if isSemanticSearchActive && !searchText.isEmpty {
                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(.purple)
                    Text("Showing meaning-based results for '\(searchText)'")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
                .transition(.opacity)
                .animation(.easeInOut, value: isSemanticSearchActive)
            } else if isFuzzySearchActive && !searchText.isEmpty {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.blue)
                    Text("Showing similar matches for '\(searchText)'")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
                .transition(.opacity)
                .animation(.easeInOut, value: isFuzzySearchActive)
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 20) {
        SearchIndicatorView(isSemanticSearchActive: true, isFuzzySearchActive: false, searchText: "apple")
        SearchIndicatorView(isSemanticSearchActive: false, isFuzzySearchActive: true, searchText: "banana")
        SearchIndicatorView(isSemanticSearchActive: false, isFuzzySearchActive: false, searchText: "orange")
    }
    .padding()
}
