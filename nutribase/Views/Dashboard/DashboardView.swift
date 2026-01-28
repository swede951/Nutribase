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
    // Callback when dashboard is fully loaded
    var onLoaded: (() -> Void)? = nil
    
    // Keys for UserDefaults storage
    private let cardOrderKey = "dashboardCardOrder"
    private let hiddenCardsKey = "dashboardHiddenCards"
    
    // Food log manager for streak calculation
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    
    // User profile for goals - will trigger updates when goals change
    @ObservedObject private var userProfile = UserProfile.shared
    
    // Metric visibility service
    @StateObject private var visibilityService = MetricVisibilityService.shared
    
    // Track if initial load is complete
    @State private var hasLoadedInitialData = false
    
    // Refresh trigger for when goals are updated
    @State private var refreshID = UUID()
    
    // Grid layout configuration
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    // Weight chart size mode from UserDefaults
    @AppStorage("weightChartSizeMode") private var weightChartSizeMode: WeightChartSizeMode = .compact
    
    // Color scheme for adaptive backgrounds
    @Environment(\.colorScheme) private var colorScheme
    
    /// Background color: grey in light mode, black in dark mode (inverted)
    private var scrollBackground: Color {
        colorScheme == .dark ? Color(.systemBackground) : Color(.systemGray6)
    }
    
    // Default card layout - simplified for LazyVGrid
    private let defaultCards: [DashboardCard] = [
        DashboardCard(cardType: .currentWeight),
        DashboardCard(cardType: .weightChart),
        DashboardCard(cardType: .calorieTarget),
        DashboardCard(cardType: .protein),
        DashboardCard(cardType: .novaGroups),
        DashboardCard(cardType: .nutriScore),
        DashboardCard(cardType: .gutHealth),
        DashboardCard(cardType: .carbs),
        DashboardCard(cardType: .fat),
        // DashboardCard(cardType: .water), // TEMPORARILY DISABLED
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
    
    // Cached grid rows to avoid recalculation on every render
    @State private var cachedGridRows: [[DashboardCard]] = []
    @State private var lastCardsHash: Int = 0
    
    // Initialize with saved layout or default layout
    init(onLoaded: (() -> Void)? = nil) {
        self.onLoaded = onLoaded
        
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
    
    // Filter cards based on visibility preferences
    private var visibleCards: [DashboardCard] {
        return cards.filter { card in
            switch card.cardType {
            case .protein:
                return visibilityService.showProtein
            case .calorieTarget:
                return visibilityService.showCalories
            case .carbs:
                return visibilityService.showCarbs
            case .fat:
                return visibilityService.showFat
            case .novaGroups:
                return visibilityService.showNovaScore
            case .nutriScore:
                return visibilityService.showNutriScore
            case .currentWeight, .weightChart, .activity, .dailyGoals, .gutHealth, .empty:
                return true // Always show non-nutrition cards
            }
        }
    }
    
    // Helper function to check if a card should span 2 columns
    private func isWideCard(_ cardType: CardType) -> Bool {
        if cardType == .novaGroups || cardType == .nutriScore || cardType == .dailyGoals || cardType == .gutHealth {
            return true
        }
        if cardType == .weightChart && weightChartSizeMode == .expanded {
            return true
        }
        return false
    }
    
    // Helper function to organize cards into proper Grid rows
    private func createGridRows(from cards: [DashboardCard]) -> [[DashboardCard]] {
        var rows: [[DashboardCard]] = []
        var currentRow: [DashboardCard] = []
        var currentRowColumns = 0
        
        for card in cards {
            let cardColumns = isWideCard(card.cardType) ? 2 : 1
            
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
    
    // Get cached grid rows or recalculate if needed
    private func getGridRows() -> [[DashboardCard]] {
        let currentHash = visibleCards.map { $0.id.hashValue }.reduce(0, ^)
        if currentHash != lastCardsHash || cachedGridRows.isEmpty {
            cachedGridRows = createGridRows(from: visibleCards)
            lastCardsHash = currentHash
        }
        return cachedGridRows
    }
    
    // Invalidate cache when cards change
    private func invalidateGridCache() {
        lastCardsHash = 0
        cachedGridRows = []
    }
    
    var body: some View {
        ZStack {
            // Subtle gradient background with brand color - extended lower
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#35b8ff").opacity(0.85),
                    scrollBackground
                ]),
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.5)
            )
            .ignoresSafeArea()
            .background(scrollBackground)
                
            // Main content with header inside ScrollView
            ScrollView {
                VStack(spacing: 0) {
                    // Custom header with centered title
                    ZStack {
                        // Center - title (positioned absolutely in the center)
                        Text("NUTRIBASE")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundColor(.white)
                            .shadow(color: Color(hex: "#35b8ff").opacity(0.5), radius: 4, x: 0, y: 0)
                            .frame(maxWidth: .infinity)
                        
                        // Left and right elements in an HStack
                        HStack {
                            // Left side - streak
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 16))
                                Text("\(foodLogManager.currentStreak)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                            
                            Spacer()
                        
                            // Right side - edit button
                            HStack(spacing: 12) {
                                // Edit button with icon
                                Button(action: {
                                    HapticManager.shared.lightFeedback()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isEditing.toggle()
                                    }
                                }) {
                                    Image(systemName: isEditing ? "checkmark" : "slider.horizontal.3")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                .withHapticFeedback()
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .padding(.top, 1) // Reduced top padding
                    
                    // Content container
                    ZStack {
                    
                    Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                        ForEach(Array(createGridRows(from: visibleCards).enumerated()), id: \.offset) { rowIndex, row in
                            GridRow {
                                ForEach(row, id: \.id) { card in
                                    if isWideCard(card.cardType) {
                                        // Wide cards span 2 columns
                                        cardView(for: card)
                                            .gridCellColumns(2)
                                            .onLongPressGesture(minimumDuration: 1) {
                                                if !isEditing {
                                                    HapticManager.shared.mediumFeedback()
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        isEditing = true
                                                    }
                                                }
                                            }
                                            .onDrag {
                                                if !isEditing {
                                                    HapticManager.shared.mediumFeedback()
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        isEditing = true
                                                    }
                                                }
                                                return NSItemProvider(object: card.id.uuidString as NSString)
                                            }
                                            .onDrop(of: [.text], delegate: GridCardDropDelegate(card: card, cards: $cards, insertionIndex: getCardIndex(for: card)))
                                    } else {
                                        // Regular 1-column cards
                                        cardView(for: card)
                                            .onLongPressGesture(minimumDuration: 1) {
                                                if !isEditing {
                                                    HapticManager.shared.mediumFeedback()
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        isEditing = true
                                                    }
                                                }
                                            }
                                            .onDrag {
                                                if !isEditing {
                                                    HapticManager.shared.mediumFeedback()
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        isEditing = true
                                                    }
                                                }
                                                return NSItemProvider(object: card.id.uuidString as NSString)
                                            }
                                            .onDrop(of: [.text], delegate: GridCardDropDelegate(card: card, cards: $cards, insertionIndex: getCardIndex(for: card)))
                                    }
                                }
                                
                                // Add empty drop zones to fill the row to 2 columns
                                let currentRowColumns = row.reduce(0) { total, card in
                                    total + (isWideCard(card.cardType) ? 2 : 1)
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
                        Color.clear.frame(height: 100)
                            .gridCellColumns(2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16) // Match vertical spacing between card rows
                }
                }
            }
            .onAppear {
                // Track page view
                AnalyticsService.shared.trackDashboardView()
                
                // Pre-warm caches for faster card rendering
                DailyNutritionCache.shared.prewarmCommonDates()
                
                // Signal that dashboard has loaded after a short delay to ensure all cards are rendered
                if !hasLoadedInitialData {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        hasLoadedInitialData = true
                        onLoaded?()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserProfileDidUpdate"))) { _ in
                // Force refresh dashboard when user profile is updated
                print("📊 Dashboard received UserProfileDidUpdate notification - refreshing cards")
                refreshID = UUID()
                invalidateGridCache()
            }
            .onReceive(NotificationCenter.default.publisher(for: .exitEditMode)) { _ in
                // Exit edit mode when switching tabs
                if isEditing {
                    isEditing = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WeightChartSizeModeChanged"))) { _ in
                // Refresh grid when weight chart size mode changes
                invalidateGridCache()
                refreshID = UUID()
            }
            .id(refreshID) // Force view refresh when refreshID changes
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
            case .gutHealth:
                gutHealthCardView()
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
                                .foregroundColor(Color.red.opacity(0.9))
                                .background(Circle().fill(Color(.systemBackground)))
                        }
                        .opacity(0.7)
                        Spacer()
                    }
                    Spacer()
                }
                .offset(x: -10, y: -10)  // Position button outside card bounds
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
        
        // Remove the card from the array with animation
        _ = withAnimation(.easeInOut(duration: 0.25)) {
            cards.remove(at: cardIndex)
        }
        
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
    
    // Helper function for Gut Health card
    private func gutHealthCardView() -> some View {
        GutHealthCardView()
    }
    
    // Function to return the appropriate card view based on card type
    @ViewBuilder
    private func cardView(for cardType: CardType) -> some View {
        switch cardType {
        case .currentWeight:
            CurrentWeightCardView()
        case .weightChart:
            WeightChartCardView()
        case .calorieTarget:
            CalorieTargetCardView()
        case .protein:
            ProteinCardView()
        case .carbs:
            CarbsCardView()
        case .fat:
            FatCardView()
        // case .water: // TEMPORARILY DISABLED
        //     WaterCardView()
        case .activity:
            StepsCardView()
        case .dailyGoals:
            DailyGoalsCardView()
        case .nutriScore, .novaGroups, .gutHealth, .empty:
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
                                .background(Color(.systemBackground))
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
