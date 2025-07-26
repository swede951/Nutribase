import SwiftUI

struct WidgetStorageView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var cardOrder: [CardType]
    @Binding var hiddenCards: [CardType]
    
    // Grid layout configuration
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                // Available Widgets section removed
                
                // All widgets section
                Section {
                    Text("All Widgets")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(CardType.allCases, id: \.self) { cardType in
                            // Show all widgets that are either hidden or special cases like NOVA groups
                            // that can appear multiple times
                            if hiddenCards.contains(cardType) || !cardOrder.contains(cardType) || 
                               (cardType == .novaGroups && cardOrder.filter({ $0 == .novaGroups }).count < 2) ||
                               (cardType == .nutriScore && cardOrder.filter({ $0 == .nutriScore }).count < 2) {
                                widgetPreviewCard(for: cardType)
                                    .onTapGesture {
                                        addWidgetToDashboard(cardType)
                                    }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("Widget Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
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
    
    @ViewBuilder
    private func widgetPreviewCard(for cardType: CardType) -> some View {
        VStack {
            Image(systemName: cardType.systemImage)
                .font(.largeTitle)
                .foregroundColor(cardType.color)
                .frame(width: 60, height: 60)
                .padding()
            
            Text(cardType.rawValue)
                .font(.caption)
                .multilineTextAlignment(.center)
            
            // Add button
            Button(action: {
                addWidgetToDashboard(cardType)
            }) {
                Text("Add")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(height: 180)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}

#Preview {
    WidgetStorageView(
        cardOrder: .constant([.currentWeight, .bmi, .calorieTarget, .protein]),
        hiddenCards: .constant([.carbs, .fat, .water, .activity])
    )
}
