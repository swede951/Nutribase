import SwiftUI

struct WidgetStorageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Binding var cardOrder: [CardType]
    @Binding var hiddenCards: [CardType]
    
    /// Background color matching dashboard (grey in light mode, black in dark mode)
    private var scrollBackground: Color {
        Color.appBackground
    }
    
    // Grid layout configuration - spacing matches DashboardGridEngine.spacing (16pt)
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    // Separate hidden cards into 1x1 and full-width
    private var hiddenOneByOneCards: [CardType] {
        hiddenCards.filter { $0.size == .oneByOne && $0 != .empty }
    }
    
    private var hiddenFullWidthCards: [CardType] {
        hiddenCards.filter { $0.size == .twoByOne && $0 != .empty }
    }
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    if hiddenCards.isEmpty || (hiddenOneByOneCards.isEmpty && hiddenFullWidthCards.isEmpty) {
                        // All widgets are on the dashboard
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.green)
                            Text("All widgets added")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("All available widgets are on your dashboard")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 60)
                    } else {
                        // 1x1 cards in a 2-column grid
                        if !hiddenOneByOneCards.isEmpty {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(hiddenOneByOneCards, id: \.self) { cardType in
                                    galleryCardWrapper(for: cardType)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Full-width cards stacked vertically
                        if !hiddenFullWidthCards.isEmpty {
                            VStack(spacing: 16) {
                                ForEach(hiddenFullWidthCards, id: \.self) { cardType in
                                    galleryCardWrapper(for: cardType)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .background(scrollBackground.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("Widget Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(scrollBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
    
    private func addWidgetToDashboard(_ cardType: CardType) {
        // Handle special cases for cards that span two columns
        if cardType == .novaGroups || cardType == .nutriScore {
            cardOrder.append(cardType)
            cardOrder.append(cardType) // Add twice for the two-column span
        } else {
            cardOrder.append(cardType)
        }
        
        // Remove from hidden cards if it was there
        if let index = hiddenCards.firstIndex(of: cardType) {
            hiddenCards.remove(at: index)
        }
        
        // Dismiss the view
        dismiss()
    }
    
    /// Wraps an editor preview card with a green + button overlay
    @ViewBuilder
    private func galleryCardWrapper(for cardType: CardType) -> some View {
        ZStack(alignment: .topLeading) {
            // Use the same editor preview cards as the edit dashboard
            EditorPreviewCardProvider.previewView(for: cardType)
                .allowsHitTesting(false) // Prevent interaction with card internals
            
            // Green + button in top-left (same position as red - button in edit mode)
            Button(action: {
                addWidgetToDashboard(cardType)
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                    .background(
                        Circle()
                            .fill(Color.appCardBackground)
                            .frame(width: 20, height: 20)
                    )
            }
            .offset(x: -6, y: -6)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            addWidgetToDashboard(cardType)
        }
    }
}

#Preview {
    WidgetStorageView(
        cardOrder: .constant([.currentWeight, .weightChart, .calorieTarget, .protein]),
        hiddenCards: .constant([.carbs, .fat, .novaGroups, .activity])
    )
}
