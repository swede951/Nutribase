//
//  DashboardView.swift
//  nutribase
//
//  Created on 03/06/2025.
//

import SwiftUI
import Combine
import UIKit

// CardStyle is now imported from the shared CardStyle.swift file

struct DashboardView: View {
    // Keys for UserDefaults storage
    private let cardOrderKey = "dashboardCardOrder"
    private let hiddenCardsKey = "dashboardHiddenCards"
    
    // Grid layout configuration
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    // Default card layout - simplified for LazyVGrid
    private let defaultCards: [DashboardCard] = [
        DashboardCard(cardType: .currentWeight),
        DashboardCard(cardType: .weightChart),
        DashboardCard(cardType: .bmi),
        DashboardCard(cardType: .calorieTarget),
        DashboardCard(cardType: .protein),
        DashboardCard(cardType: .novaGroups),
        DashboardCard(cardType: .nutriScore),
        DashboardCard(cardType: .carbs),
        DashboardCard(cardType: .fat),
        DashboardCard(cardType: .water),
        DashboardCard(cardType: .activity)
    ]
    
    // State for drag-and-drop reordering
    @State private var cards: [DashboardCard] = []
    
    // State for hidden/removed widgets
    @State private var hiddenCards: [CardType] = []
    
    // State for showing widget storage view
    @State private var showingWidgetStorage = false
    
    // State for edit mode
    @State private var isEditing = false
    
    // Initialize with saved layout or default layout
    init() {
        // Load saved card order from UserDefaults
        var initialCards = defaultCards
        if let savedCardOrderData = UserDefaults.standard.data(forKey: cardOrderKey),
           let decodedCardOrder = try? JSONDecoder().decode([CardType].self, from: savedCardOrderData) {
            // Convert saved CardTypes to DashboardCards
            initialCards = decodedCardOrder.map { DashboardCard(cardType: $0) }
        } else {
            // If no saved layout, use default and save it
            let cardTypes = defaultCards.map { $0.cardType }
            if let encodedData = try? JSONEncoder().encode(cardTypes) {
                UserDefaults.standard.set(encodedData, forKey: cardOrderKey)
            }
        }
        _cards = State(initialValue: initialCards)
        
        // Load saved hidden cards from UserDefaults
        if let savedHiddenCardsData = UserDefaults.standard.data(forKey: hiddenCardsKey),
           let decodedHiddenCards = try? JSONDecoder().decode([CardType].self, from: savedHiddenCardsData) {
            _hiddenCards = State(initialValue: decodedHiddenCards)
        } else {
            // Default empty hidden cards array if nothing is saved
            _hiddenCards = State(initialValue: [])
        }
    }
    
    // Function to reset the dashboard to default layout
    func resetDashboard() {
        // Reset to default cards
        cards = defaultCards
        
        // Save the reset layout
        let cardTypes = cards.map { $0.cardType }
        if let encodedData = try? JSONEncoder().encode(cardTypes) {
            UserDefaults.standard.set(encodedData, forKey: cardOrderKey)
        }
        
        // Clear hidden cards
        hiddenCards = []
        if let encodedData = try? JSONEncoder().encode(hiddenCards) {
            UserDefaults.standard.set(encodedData, forKey: hiddenCardsKey)
        }
    }
    
    // Helper function to organize cards into proper Grid rows
    private func createGridRows(from cards: [DashboardCard]) -> [[DashboardCard]] {
        var rows: [[DashboardCard]] = []
        var currentRow: [DashboardCard] = []
        var currentRowColumns = 0
        
        for card in cards {
            let cardColumns = (card.cardType == .novaGroups || card.cardType == .nutriScore) ? 2 : 1
            
            // If adding this card would exceed 2 columns, start a new row
            if currentRowColumns + cardColumns > 2 {
                if !currentRow.isEmpty {
                    rows.append(currentRow)
                    currentRow = []
                    currentRowColumns = 0
                }
            }
            
            currentRow.append(card)
            currentRowColumns += cardColumns
            
            // If we've filled exactly 2 columns, start a new row
            if currentRowColumns == 2 {
                rows.append(currentRow)
                currentRow = []
                currentRowColumns = 0
            }
        }
        
        // Add any remaining cards in the current row
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    // Helper function to get card index in the flat cards array
    private func getCardIndex(for card: DashboardCard) -> Int {
        return cards.firstIndex(where: { $0.id == card.id }) ?? 0
    }
    
    // Helper function to get insertion index for empty space in a row
    private func getInsertionIndexForRow(_ rowIndex: Int, row: [DashboardCard]) -> Int {
        // Find the index after the last card in this row
        if let lastCard = row.last {
            return getCardIndex(for: lastCard) + 1
        }
        return cards.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header with centered title
            ZStack {
                // Center - title (positioned absolutely in the center)
                Text("NUTRIBASE")
                    .font(.custom("Montserrat ExtraBold", size: 22))
                    .foregroundColor(Color(hex: "#e6a698"))
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        // Check available fonts
                        let montserratFonts = UIFont.familyNames.filter { $0.contains("Montserrat") }
                        print("Available Montserrat fonts:")
                        for family in montserratFonts {
                            let names = UIFont.fontNames(forFamilyName: family)
                            print("Family: \(family)")
                            for name in names {
                                print("  - \(name)")
                            }
                        }
                        
                        // Also check if our specific fonts exist
                        let testFont1 = UIFont(name: "Montserrat ExtraBold", size: 20)
                        let testFont2 = UIFont(name: "Montserrat-ExtraBold", size: 20)
                        let testFont3 = UIFont(name: "MontserratExtraBold", size: 20)
                        print("Font test results:")
                        print("Montserrat ExtraBold: \(testFont1 != nil ? "Found" : "Not found")")
                        print("Montserrat-ExtraBold: \(testFont2 != nil ? "Found" : "Not found")")
                        print("MontserratExtraBold: \(testFont3 != nil ? "Found" : "Not found")")
                    }
                
                // Left and right elements in an HStack
                HStack {
                    // Left side - flame icon
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("0")
                            .foregroundColor(.orange)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                
                    // Right side - edit button and reset button
                    HStack(spacing: 12) {
                        // Reset button to restore NOVA Groups card
                        Button(action: {
                            HapticManager.shared.lightFeedback()
                            resetDashboard()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.primary)
                        }
                        .withHapticFeedback()
                        
                        // Edit button
                        Button(action: {
                            HapticManager.shared.lightFeedback()
                            withAnimation {
                                isEditing.toggle()
                            }
                        }) {
                            Text(isEditing ? "Done" : "Edit")
                                .foregroundColor(.primary)
                        }
                        .withHapticFeedback()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .padding(.top, 1) // Reduced top padding
            .background(Color(hex: "#f7f3ee"))
            
            // Main content
            ScrollView {
                // Apply background color to the entire ScrollView
                ZStack {
                    // Background color layer - using custom warm beige background
                    Color(hex: "#f7f3ee")
                        .ignoresSafeArea()
                    
                    Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                        let cardRows = createGridRows(from: cards)
                        ForEach(Array(cardRows.enumerated()), id: \.offset) { rowIndex, row in
                            GridRow {
                                ForEach(row, id: \.id) { card in
                                    if card.cardType == .novaGroups || card.cardType == .nutriScore {
                                        // Wide cards span 2 columns
                                        cardView(for: card)
                                            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                                            .cardStyle() // Apply consistent card styling
                                            .gridCellColumns(2)
                                            .onDrag {
                                                return NSItemProvider(object: card.id.uuidString as NSString)
                                            }
                                            .onDrop(of: [.text], delegate: GridCardDropDelegate(card: card, cards: $cards, insertionIndex: getCardIndex(for: card)))
                                    } else {
                                        // Regular 1-column cards
                                        cardView(for: card)
                                            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                                            .cardStyle() // Apply consistent card styling
                                            .onDrag {
                                                return NSItemProvider(object: card.id.uuidString as NSString)
                                            }
                                            .onDrop(of: [.text], delegate: GridCardDropDelegate(card: card, cards: $cards, insertionIndex: getCardIndex(for: card)))
                                    }
                                }
                                
                                // Add empty drop zones to fill the row to 2 columns
                                let currentRowColumns = row.reduce(0) { total, card in
                                    total + (card.cardType == .novaGroups || card.cardType == .nutriScore ? 2 : 1)
                                }
                                if currentRowColumns < 2 {
                                    // Add nearly invisible drop zone with card styling
                                    Rectangle()
                                        .fill(Color.black.opacity(0.001))
                                        .frame(maxWidth: .infinity, minHeight: 120)
                                        .onDrop(of: [.text], delegate: GridEmptySpaceDropDelegate(cards: $cards, insertionIndex: getInsertionIndexForRow(rowIndex, row: row)))
                                }
                            }
                        }
                        
                        // Add Widget button appears in edit mode
                        if isEditing {
                            Button(action: {
                                showingWidgetStorage = true
                            }) {
                                VStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.blue)
                                    Text("Add Widget")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                        .foregroundColor(.blue.opacity(0.5))
                                )
                            }
                            .gridCellColumns(2)
                        }
                        
                        // Add bottom spacing to ensure content doesn't blend with tab bar
                        Color.clear.frame(height: 20)
                            .gridCellColumns(2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16) // Match vertical spacing between card rows
                }
            }
            .animation(.default, value: cards)
        }
        .navigationBarHidden(true) // Hide the default navigation bar since we have a custom header
        .sheet(isPresented: $showingWidgetStorage) {
            WidgetStorageView(cardOrder: Binding(
                get: { cards.map { $0.cardType } },
                set: { newCardTypes in
                    cards = newCardTypes.map { DashboardCard(cardType: $0) }
                }
            ), hiddenCards: $hiddenCards)
                .onDisappear {
                    // Save changes when widget storage view is dismissed
                    saveCardOrder()
                    saveHiddenCards()
                }
        }
    }
    
    // Reset the dashboard to the default layout
    private func resetToDefaultLayout() {
        // Clear saved card order and hidden cards from UserDefaults
        UserDefaults.standard.removeObject(forKey: cardOrderKey)
        UserDefaults.standard.removeObject(forKey: hiddenCardsKey)
        
        // Set cards back to default
        cards = defaultCards
        hiddenCards = []
        
        // Save the reset layout
        saveCardOrder()
        saveHiddenCards()
    }
    
    // Function to save card order to UserDefaults
    private func saveCardOrder() {
        let cardTypes = cards.map { $0.cardType }
        if let encodedData = try? JSONEncoder().encode(cardTypes) {
            UserDefaults.standard.set(encodedData, forKey: cardOrderKey)
        }
    }
    
    // Function to render a card view based on DashboardCard
    @ViewBuilder
    private func cardView(for card: DashboardCard) -> some View {
        ZStack {
            // Main card content
            switch card.cardType {
            case .novaGroups:
                novaGroupsCardView()
            case .nutriScore:
                nutriScoreCardView()
            default:
                regularCardView(for: card.cardType)
            }
            
            // Remove button overlay (only visible in edit mode)
            if isEditing {
                VStack {
                    HStack {
                        Button(action: {
                            removeWidget(cardId: card.id)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        .padding(8)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }
    
    // Function to save hidden cards to UserDefaults
    private func saveHiddenCards() {
        if let encodedData = try? JSONEncoder().encode(hiddenCards) {
            UserDefaults.standard.set(encodedData, forKey: hiddenCardsKey)
        }
    }
    
    // Function to remove a widget from the dashboard
    private func removeWidget(cardId: UUID) {
        // Find the card to remove
        guard let cardIndex = cards.firstIndex(where: { $0.id == cardId }) else { return }
        let cardType = cards[cardIndex].cardType
        
        // Add to hidden cards if not already there
        if !hiddenCards.contains(cardType) {
            hiddenCards.append(cardType)
            saveHiddenCards()
        }
        
        // Remove the card from the array
        cards.remove(at: cardIndex)
        
        // Save the updated card order
        saveCardOrder()
    }
    
    // Helper function for regular cards
    @ViewBuilder
    private func regularCardView(for cardType: CardType) -> some View {
        self.cardView(for: cardType)
    }
    
    // Helper function for the NOVA groups card with delete button and drag-drop support
    @ViewBuilder
    private func novaGroupsCardView() -> some View {
        NovaGroupsCardView()
    }
    
    // Helper function for Nutri-Score card
    private func nutriScoreCardView() -> some View {
        NutriScoreCardView()
    }
    
    // Function to return the appropriate card view based on card type
    @ViewBuilder
    private func cardView(for cardType: CardType) -> some View {
        switch cardType {
        case .currentWeight:
            CurrentWeightCardView()
        case .weightChart:
            WeightChartCardView()
        case .bmi:
            BMICardView()
        case .calorieTarget:
            CalorieTargetCardView()
        case .protein:
            ProteinCardView()
        case .carbs:
            CarbsCardView()
        case .fat:
            FatCardView()
        case .water:
            WaterCardView()
        case .activity:
            StepsCardView()
        case .nutriScore, .novaGroups, .empty:
            // These are handled by the main cardView(for: DashboardCard) function
            EmptyView()
        }
    }
    
    // Empty slot view for removed cards
    @ViewBuilder
    private func emptySlotView() -> some View {
        Color.clear
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 120)
            .fixedSize(horizontal: false, vertical: false)
            .background(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            .padding(8)
            .overlay(
                Group {
                    if isEditing {
                        Button(action: {
                            // Handle adding a new widget
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            )
    }
}

// Struct for the card view with delete button overlay
struct DashboardCardView<Content: View>: View {
    let content: Content
    let isEditing: Bool
    let onDelete: () -> Void
    
    init(isEditing: Bool, onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isEditing = isEditing
        self.onDelete = onDelete
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            content
            
            if isEditing {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        .padding(8)
                    }
                    Spacer()
                }
            }
        }
    }
    

}

#Preview {
    DashboardView()
}
