//
//  DashboardEditorRepresentable.swift
//  nutribase
//
//  UIViewControllerRepresentable wrapper for DashboardEditorViewController
//

import SwiftUI
import UIKit

/// Embedded version for inline use in dashboard (no navigation bar)
struct EmbeddedDashboardEditorView: UIViewControllerRepresentable {
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Binding to card order
    @Binding var cardOrder: [CardType]
    
    // Binding to hidden cards
    @Binding var hiddenCards: [CardType]
    
    // Show widget storage
    var onShowWidgetStorage: () -> Void
    
    // Card view provider
    var cardViewProvider: (CardType) -> AnyView
    
    // Card size states
    var isWeightChartExpanded: Bool
    var isNovaGroupsCompact: Bool = false
    var isNutriScoreCompact: Bool = false
    
    // Header view (scrolls with content)
    var headerView: AnyView?
    var headerHeight: CGFloat = 60
    
    // Footer view (scrolls with content at bottom)
    var footerView: AnyView?
    var footerHeight: CGFloat = 60
    
    func makeUIViewController(context: Context) -> DashboardEditorViewController {
        let editorVC = DashboardEditorViewController()
        editorVC.isEmbedded = true
        editorVC.hiddenCards = hiddenCards
        editorVC.isWeightChartExpanded = isWeightChartExpanded
        editorVC.isNovaGroupsCompact = isNovaGroupsCompact
        editorVC.isNutriScoreCompact = isNutriScoreCompact
        editorVC.cardViewProvider = cardViewProvider
        editorVC.colorScheme = colorScheme
        editorVC.headerView = headerView
        editorVC.headerHeight = headerHeight
        editorVC.footerView = footerView
        editorVC.footerHeight = footerHeight
        
        // Pre-render snapshots for all cards (stable editor rendering)
        let containerWidth = UIScreen.main.bounds.width
        CardSnapshotCache.shared.setContainerWidth(containerWidth)
        CardSnapshotCache.shared.preRenderSnapshots(
            for: cardOrder,
            isWeightChartExpanded: isWeightChartExpanded,
            isNovaGroupsCompact: isNovaGroupsCompact,
            isNutriScoreCompact: isNutriScoreCompact,
            colorScheme: colorScheme,
            cardViewProvider: cardViewProvider
        )
        
        // Set snapshot provider
        editorVC.snapshotProvider = { [cardViewProvider, isWeightChartExpanded, isNovaGroupsCompact, isNutriScoreCompact, colorScheme] cardType in
            CardSnapshotCache.shared.snapshot(
                for: cardType,
                isWeightChartExpanded: isWeightChartExpanded,
                isNovaGroupsCompact: isNovaGroupsCompact,
                isNutriScoreCompact: isNutriScoreCompact,
                colorScheme: colorScheme,
                cardViewProvider: cardViewProvider
            )
        }
        
        // Initialize placements from card order
        editorVC.initializePlacementsIfNeeded(from: cardOrder)
        
        editorVC.onCardOrderChanged = { newOrder in
            // Synchronous update - async dispatch caused race condition where
            // updateUIViewController would reset to old order before async completed
            cardOrder = newOrder
        }
        
        editorVC.onCardRemoved = { removedCard in
            // Synchronous update to avoid race conditions
            if !hiddenCards.contains(removedCard) {
                hiddenCards.append(removedCard)
            }
        }
        
        editorVC.onAddWidget = {
            onShowWidgetStorage()
        }
        
        context.coordinator.editorVC = editorVC
        
        return editorVC
    }
    
    func updateUIViewController(_ uiViewController: DashboardEditorViewController, context: Context) {
        // Update color scheme
        uiViewController.colorScheme = colorScheme
        
        // Update size flags BEFORE cardOrder so placements use correct size
        uiViewController.isWeightChartExpanded = isWeightChartExpanded
        uiViewController.isNovaGroupsCompact = isNovaGroupsCompact
        uiViewController.isNutriScoreCompact = isNutriScoreCompact
        
        // Update hiddenCards BEFORE cardOrder so placements are built correctly
        uiViewController.hiddenCards = hiddenCards
        
        // Update card order if it changed externally (e.g., from widget storage)
        if uiViewController.cardOrder != cardOrder {
            // Re-render snapshot for any new cards
            for card in cardOrder where !uiViewController.cardOrder.contains(card) {
                _ = CardSnapshotCache.shared.snapshot(
                    for: card,
                    isWeightChartExpanded: isWeightChartExpanded,
                    isNovaGroupsCompact: isNovaGroupsCompact,
                    isNutriScoreCompact: isNutriScoreCompact,
                    colorScheme: colorScheme,
                    cardViewProvider: cardViewProvider
                )
            }
            uiViewController.setCardOrderAndReload(cardOrder, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var editorVC: DashboardEditorViewController?
    }
}

/// Modal version with navigation bar (for fullScreenCover use)
struct DashboardEditorView: UIViewControllerRepresentable {
    
    // Binding to card order
    @Binding var cardOrder: [CardType]
    
    // Binding to hidden cards
    @Binding var hiddenCards: [CardType]
    
    // Dismiss action
    var onDismiss: () -> Void
    
    // Show widget storage
    var onShowWidgetStorage: () -> Void
    
    // Card view provider
    var cardViewProvider: (CardType) -> AnyView
    
    // Card size states
    var isWeightChartExpanded: Bool
    var isNovaGroupsCompact: Bool = false
    var isNutriScoreCompact: Bool = false
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let editorVC = DashboardEditorViewController()
        editorVC.hiddenCards = hiddenCards
        editorVC.isWeightChartExpanded = isWeightChartExpanded
        editorVC.isNovaGroupsCompact = isNovaGroupsCompact
        editorVC.isNutriScoreCompact = isNutriScoreCompact
        editorVC.cardViewProvider = cardViewProvider
        
        // Initialize placements from card order
        editorVC.initializePlacementsIfNeeded(from: cardOrder)
        
        editorVC.onCardOrderChanged = { newOrder in
            // Synchronous update - async dispatch caused race condition where
            // updateUIViewController would reset to old order before async completed
            cardOrder = newOrder
        }
        
        editorVC.onCardRemoved = { removedCard in
            // Synchronous update to avoid race conditions
            if !hiddenCards.contains(removedCard) {
                hiddenCards.append(removedCard)
            }
        }
        
        editorVC.onDismiss = {
            onDismiss()
        }
        
        editorVC.onAddWidget = {
            onShowWidgetStorage()
        }
        
        context.coordinator.editorVC = editorVC
        
        let navController = UINavigationController(rootViewController: editorVC)
        navController.navigationBar.prefersLargeTitles = false
        
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        guard let editorVC = context.coordinator.editorVC else { return }
        
        // Update size flags BEFORE cardOrder so placements use correct size
        editorVC.isWeightChartExpanded = isWeightChartExpanded
        editorVC.isNovaGroupsCompact = isNovaGroupsCompact
        editorVC.isNutriScoreCompact = isNutriScoreCompact
        
        // Update card order if it changed externally (e.g., from widget storage)
        if editorVC.cardOrder != cardOrder {
            editorVC.setCardOrderAndReload(cardOrder, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var editorVC: DashboardEditorViewController?
    }
}

// MARK: - Preview Card Views

/// Simplified card views for the editor (no interactions, just visual)
/// Note: Height/frame wrapping is handled in the cell provider, not here
struct EditorCardViewProvider {
    
    /// Returns snapshot-compatible preview views for the editor
    /// These views don't use Swift Charts or SF Symbols that fail in ImageRenderer
    static func cardView(for cardType: CardType, isWeightChartExpanded: Bool = false, isNovaGroupsCompact: Bool = false, isNutriScoreCompact: Bool = false) -> AnyView {
        // Use EditorPreviewCardProvider for snapshot-compatible previews
        return EditorPreviewCardProvider.previewView(for: cardType, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact)
        
        // ORIGINAL CODE (commented out for reference):
        // switch cardType {
        // case .currentWeight:
        //     return AnyView(CurrentWeightCardView())
        // case .weightChart:
        //     return AnyView(WeightChartCardView())
        // case .calorieTarget:
        //     return AnyView(CalorieTargetCardView())
        // case .protein:
        //     return AnyView(ProteinCardView())
        // case .carbs:
        //     return AnyView(CarbsCardView())
        // case .fat:
        //     return AnyView(FatCardView())
        // case .activity:
        //     return AnyView(StepsCardView())
        // case .dailyGoals:
        //     return AnyView(DailyGoalsCardView())
        // case .novaGroups:
        //     return AnyView(NovaGroupsCardView())
        // case .nutriScore:
        //     return AnyView(NutriScoreCardView())
        // case .gutHealth:
        //     return AnyView(GutHealthCardView())
        // case .empty:
        //     return AnyView(EmptyView())
        // }
    }
}
