import SwiftUI

struct WidgetStorageView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var cardOrder: [CardType]
    @Binding var hiddenCards: [CardType]
    
    // Available widgets (not on dashboard)
    private var availableWidgets: [CardType] {
        CardType.allCases.filter { !cardOrder.contains($0) && $0 != .empty }
    }
    
    // Create grid rows similar to dashboard
    private func createGridRows() -> [[CardType]] {
        var rows: [[CardType]] = []
        var currentRow: [CardType] = []
        var currentRowColumns = 0
        
        for cardType in availableWidgets {
            let cardColumns = cardType.size == .twoByOne ? 2 : 1
            
            if currentRowColumns + cardColumns > 2 {
                // Start new row
                if !currentRow.isEmpty {
                    rows.append(currentRow)
                }
                currentRow = [cardType]
                currentRowColumns = cardColumns
            } else {
                currentRow.append(cardType)
                currentRowColumns += cardColumns
            }
            
            // If row is full, start new row
            if currentRowColumns == 2 {
                rows.append(currentRow)
                currentRow = []
                currentRowColumns = 0
            }
        }
        
        // Add remaining cards
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color matching dashboard
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 20) {
                        // All widgets section
                        Text("All Widgets")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        // Grid layout matching dashboard
                        VStack(spacing: 16) {
                            // Wide cards (2x1) - full width
                            ForEach(availableWidgets.filter { $0.size == .twoByOne }, id: \.self) { cardType in
                                widgetPreviewCard(for: cardType)
                            }
                            
                            // Regular cards (1x1) - two columns
                            let regularCards = availableWidgets.filter { $0.size != .twoByOne }
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ], spacing: 16) {
                                ForEach(regularCards, id: \.self) { cardType in
                                    widgetPreviewCard(for: cardType)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        Spacer()
                    }
                    .padding(.vertical)
                }
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
        // Add the card to the dashboard (wide cards are handled by gridCellColumns(2) in the view)
        cardOrder.append(cardType)
        
        // Remove from hidden cards if it was there
        if let index = hiddenCards.firstIndex(of: cardType) {
            hiddenCards.remove(at: index)
        }
        
        // Dismiss the view
        dismiss()
    }
    
    @ViewBuilder
    private func widgetPreviewCard(for cardType: CardType) -> some View {
        ZStack {
            // Actual card preview with placeholder data - full size
            cardPreviewView(for: cardType)
            
            // Green plus button overlay - positioned outside card bounds
            VStack {
                HStack {
                    Button(action: {
                        addWidgetToDashboard(cardType)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.green.opacity(0.9))
                            .background(Circle().fill(Color(.systemBackground)))
                    }
                    Spacer()
                }
                Spacer()
            }
            .offset(x: -10, y: -10)  // Position button outside card bounds
        }
    }
    
    // Returns the actual card view in preview mode
    @ViewBuilder
    private func cardPreviewView(for cardType: CardType) -> some View {
        switch cardType {
        case .currentWeight:
            CurrentWeightCardView(isPreview: true)
        case .weightChart:
            WeightChartCardView(isPreview: true)
        case .calorieTarget:
            CalorieTargetCardView(isPreview: true)
        case .protein:
            ProteinCardView(isPreview: true)
        case .carbs:
            CarbsCardView(isPreview: true)
        case .fat:
            FatCardView(isPreview: true)
        case .activity:
            StepsCardView(isPreview: true)
        case .dailyGoals:
            DailyGoalsCardView(isPreview: true)
        case .novaGroups:
            NovaGroupsCardView(isPreview: true)
        case .nutriScore:
            NutriScoreCardView(isPreview: true)
        case .gutHealth:
            GutHealthCardView(isPreview: true)
        case .empty:
            EmptyView()
        }
    }
}

#Preview {
    WidgetStorageView(
        cardOrder: .constant([.currentWeight, .weightChart, .calorieTarget, .protein]),
        hiddenCards: .constant([.carbs, .fat, .activity]) // .water removed - TEMPORARILY DISABLED
    )
}
