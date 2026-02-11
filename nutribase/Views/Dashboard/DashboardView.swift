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
    
    // Card size modes from UserDefaults
    @AppStorage("weightChartSizeMode") private var weightChartSizeMode: WeightChartSizeMode = .compact
    @AppStorage("novaGroupsSizeMode") private var novaGroupsSizeMode: NovaGroupsSizeMode = .wide
    @AppStorage("nutriScoreSizeMode") private var nutriScoreSizeMode: NutriScoreSizeMode = .wide
    
    // Color scheme for adaptive backgrounds
    @Environment(\.colorScheme) private var colorScheme
    
    /// Background color: grey in light mode, black in dark mode (inverted)
    private var scrollBackground: Color {
        Color.appBackground
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
        DashboardCard(cardType: .fibre),
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
    
    // Track which card is being dragged (to hide remove button during drag)
    @State private var draggedCardId: CardType? = nil
    @State private var hoverTarget: CardType? = nil
    @State private var isDragging = false
    
    
    // Initialize with saved layout or default layout
    init(onLoaded: (() -> Void)? = nil) {
        self.onLoaded = onLoaded
        
        // Load saved card order from UserDefaults
        var initialCards = defaultCards
        if let savedCardOrderData = UserDefaults.standard.data(forKey: cardOrderKey),
           let decodedCardOrder = try? JSONDecoder().decode([CardType].self, from: savedCardOrderData) {
            // DEDUPLICATE: Remove any duplicate card types (keep first occurrence)
            var seenTypes = Set<CardType>()
            let uniqueCardTypes = decodedCardOrder.filter { cardType in
                if seenTypes.contains(cardType) {
                    return false
                }
                seenTypes.insert(cardType)
                return true
            }
            
            // Convert to DashboardCards
            initialCards = uniqueCardTypes.map { DashboardCard(cardType: $0) }
            
            // If we removed duplicates, save the cleaned version
            if uniqueCardTypes.count != decodedCardOrder.count {
                if let encodedData = try? JSONEncoder().encode(uniqueCardTypes) {
                    UserDefaults.standard.set(encodedData, forKey: cardOrderKey)
                }
            }
        } else {
            // If no saved layout, use default and save it
            let cardTypes = defaultCards.map { $0.cardType }
            if let encodedData = try? JSONEncoder().encode(cardTypes) {
                UserDefaults.standard.set(encodedData, forKey: cardOrderKey)
            }
        }
        _cards = State(initialValue: initialCards)
        
        // Load saved hidden cards from UserDefaults
        var initialHiddenCards: [CardType] = []
        if let savedHiddenCardsData = UserDefaults.standard.data(forKey: hiddenCardsKey),
           let decodedHiddenCards = try? JSONDecoder().decode([CardType].self, from: savedHiddenCardsData) {
            initialHiddenCards = decodedHiddenCards
        }
        
        // Auto-discover new card types not in cardOrder or hiddenCards (e.g. fibre added after user created their layout)
        let knownCardTypes = Set(initialCards.map { $0.cardType }).union(Set(initialHiddenCards))
        let excludedTypes: Set<CardType> = [.empty] // Types that should never auto-appear
        for cardType in CardType.allCases where !knownCardTypes.contains(cardType) && !excludedTypes.contains(cardType) {
            initialHiddenCards.append(cardType)
        }
        
        _hiddenCards = State(initialValue: initialHiddenCards)
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
            case .fibre:
                return true // Always show fibre card
            case .currentWeight, .weightChart, .activity, .dailyGoals, .gutHealth, .empty:
                return true // Always show non-nutrition cards
            }
        }
    }
    
    // Helper function to check if a card should span 2 columns
    private func isWideCard(_ cardType: CardType) -> Bool {
        if cardType == .dailyGoals || cardType == .gutHealth {
            return true
        }
        if cardType == .novaGroups && novaGroupsSizeMode == .wide {
            return true
        }
        if cardType == .nutriScore && nutriScoreSizeMode == .wide {
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
    
    // Computed grid rows - SwiftUI handles caching via view diffing
    private var gridRows: [[DashboardCard]] {
        createGridRows(from: visibleCards)
    }
    
    // Dashboard header view - shared between normal and edit modes
    private var dashboardHeader: some View {
        dashboardHeaderContent
            .padding(.horizontal)
            .padding(.bottom, 8)
            .padding(.top, 1)
    }
    
    // Editor header with safe area padding (for UICollectionView header)
    private var editorHeader: some View {
        VStack(spacing: 0) {
            // Safe area spacer - reduced to match normal dashboard header position
            Color.clear.frame(height: 0)
            
            dashboardHeaderContent
                .padding(.horizontal)
                .padding(.bottom, 8)
                .padding(.top, -15)
        }
    }
    
    // Shared header content
    private var dashboardHeaderContent: some View {
        ZStack {
            // Center - title
            Text("NUTRIBASE")
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(.white)
                .shadow(color: Color(hex: "#35b8ff").opacity(0.5), radius: 4, x: 0, y: 0)
                .frame(maxWidth: .infinity)
            
            // Left and right elements
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
                    // Edit/Done button
                    Button(action: {
                        HapticManager.shared.lightFeedback()
                        
                        // Capture current card data BEFORE entering edit mode
                        if !isEditing {
                            CapturedCardData.shared.captureCurrentData {
                                // Steps data is now ready - enter edit mode
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    self.isEditing = true
                                }
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isEditing = false
                            }
                            saveCardOrder()
                            saveHiddenCards()
                            // Clear snapshot cache when exiting edit mode
                            CardSnapshotCache.shared.clearCache()
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
            
            if isEditing {
                // Edit mode: UIKit editor with scrollable header
                EmbeddedDashboardEditorView(
                    cardOrder: Binding(
                        get: { cards.map { $0.cardType } },
                        set: { newCardTypes in
                            cards = newCardTypes.map { DashboardCard(cardType: $0) }
                            saveCardOrder()
                        }
                    ),
                    hiddenCards: $hiddenCards,
                    onShowWidgetStorage: {
                        showingWidgetStorage = true
                    },
                    cardViewProvider: { [weightChartSizeMode, novaGroupsSizeMode, nutriScoreSizeMode] cardType in
                        EditorCardViewProvider.cardView(for: cardType, isWeightChartExpanded: weightChartSizeMode == .expanded, isNovaGroupsCompact: novaGroupsSizeMode == .compact, isNutriScoreCompact: nutriScoreSizeMode == .compact)
                    },
                    isWeightChartExpanded: weightChartSizeMode == .expanded,
                    isNovaGroupsCompact: novaGroupsSizeMode == .compact,
                    isNutriScoreCompact: nutriScoreSizeMode == .compact,
                    headerView: AnyView(editorHeader),
                    headerHeight: 118  // 20 (safe area) + 60 (header content)
                )
                .ignoresSafeArea()
            } else {
                // Normal mode: SwiftUI ScrollView
                ScrollView {
                    VStack(spacing: 0) {
                        dashboardHeader
                        
                        // Content container
                        ZStack {
                        
                        Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                            ForEach(Array(gridRows.enumerated()), id: \.offset) { rowIndex, row in
                                GridRow {
                                    ForEach(row, id: \.id) { card in
                                        if isWideCard(card.cardType) {
                                            // Wide cards span 2 columns
                                            cardView(for: card)
                                                .gridCellColumns(2)
                                                .onLongPressGesture(minimumDuration: 1) {
                                                    HapticManager.shared.mediumFeedback()
                                                    CapturedCardData.shared.captureCurrentData {
                                                        withAnimation(.easeInOut(duration: 0.2)) {
                                                            self.isEditing = true
                                                        }
                                                    }
                                                }
                                        } else {
                                            // Regular 1-column cards
                                            cardView(for: card)
                                                .onLongPressGesture(minimumDuration: 1) {
                                                    HapticManager.shared.mediumFeedback()
                                                    CapturedCardData.shared.captureCurrentData {
                                                        withAnimation(.easeInOut(duration: 0.2)) {
                                                            self.isEditing = true
                                                        }
                                                    }
                                                }
                                        }
                                    }
                                    
                                    // Add empty space to fill row to 2 columns
                                    let currentRowColumns = row.reduce(0) { total, card in
                                        total + (isWideCard(card.cardType) ? 2 : 1)
                                    }
                                    if currentRowColumns < 2 {
                                        Rectangle()
                                            .fill(Color.clear)
                                            .frame(maxWidth: .infinity, minHeight: 120)
                                    }
                                }
                            }
                            
                            // Bottom spacing
                            Color.clear.frame(height: 100)
                                .gridCellColumns(2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                    }
                }
                .onAppear {
                    // Track page view
                    AnalyticsService.shared.trackDashboardView()
                    
                    // Pre-warm caches for faster card rendering
                    DailyNutritionCache.shared.prewarmCommonDates()
                    
                    // Signal that dashboard has loaded
                    if !hasLoadedInitialData {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            hasLoadedInitialData = true
                            onLoaded?()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserProfileDidUpdate"))) { _ in
                    refreshID = UUID()
                }
                .onReceive(NotificationCenter.default.publisher(for: .exitEditMode)) { _ in
                    if isEditing {
                        isEditing = false
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WeightChartSizeModeChanged"))) { _ in
                    refreshID = UUID()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NovaGroupsSizeModeChanged"))) { _ in
                    refreshID = UUID()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NutriScoreSizeModeChanged"))) { _ in
                    refreshID = UUID()
                }
                .id(refreshID)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingWidgetStorage) {
            WidgetStorageView(cardOrder: Binding(
                get: { cards.map { $0.cardType } },
                set: { newCardTypes in
                    cards = newCardTypes.map { DashboardCard(cardType: $0) }
                }
            ), hiddenCards: $hiddenCards)
                .onDisappear {
                    saveCardOrder()
                    saveHiddenCards()
                }
        }
        .onChange(of: hiddenCards) { _, _ in
            saveHiddenCards()
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
    
    // Function to save card order to UserDefaults (with deduplication)
    private func saveCardOrder() {
        // Deduplicate before saving
        var seenTypes = Set<CardType>()
        let uniqueCardTypes = cards.map { $0.cardType }.filter { cardType in
            if seenTypes.contains(cardType) {
                return false
            }
            seenTypes.insert(cardType)
            return true
        }
        
        // Update cards array if duplicates were found
        if uniqueCardTypes.count != cards.count {
            cards = uniqueCardTypes.map { DashboardCard(cardType: $0) }
        }
        
        if let encodedData = try? JSONEncoder().encode(uniqueCardTypes) {
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
            
            // Remove button overlay (visible in edit mode, hidden during drag)
            if isEditing && !isDragging {
                VStack {
                    HStack {
                        Button(action: {
                            removeWidget(cardType: card.cardType)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(Color.red.opacity(0.9))
                                .background(Circle().fill(Color.appCardBackground))
                        }
                        .opacity(0.7)
                        Spacer()
                    }
                    Spacer()
                }
                .offset(x: -10, y: -10)  // Position button outside card bounds
                .transaction { $0.animation = nil }  // Don't animate minus button presence
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue, lineWidth: hoverTarget == card.cardType ? 2 : 0)
                .animation(.easeInOut(duration: 0.12), value: hoverTarget)
        )
    }
    
    // Function to save hidden cards to UserDefaults
    private func saveHiddenCards() {
        if let encodedData = try? JSONEncoder().encode(hiddenCards) {
            UserDefaults.standard.set(encodedData, forKey: hiddenCardsKey)
        }
    }
    
    // Function to remove a widget from the dashboard
    private func removeWidget(cardType: CardType) {
        // Find the card to remove
        guard let cardIndex = cards.firstIndex(where: { $0.cardType == cardType }) else { return }
        
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
        case .fibre:
            FibreCardView()
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
                                .background(Color.appCardBackground)
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
