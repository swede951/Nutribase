//
//  CardSnapshotCache.swift
//  nutribase
//
//  Renders SwiftUI card views into cached UIImages for stable editor display
//

import SwiftUI
import UIKit

/// Renders and caches card snapshots for the dashboard editor
/// This eliminates SwiftUI layout instability during drag/drop/scroll
@MainActor
class CardSnapshotCache {
    
    static let shared = CardSnapshotCache()
    
    // Cache: cardType + size variant -> UIImage
    private var cache: [String: UIImage] = [:]
    
    // Container width (set before rendering)
    private var containerWidth: CGFloat = UIScreen.main.bounds.width
    
    private init() {}
    
    // MARK: - Public API
    
    /// Sets the container width for snapshot rendering
    func setContainerWidth(_ width: CGFloat) {
        containerWidth = width
    }
    
    /// Clears the cache (call when exiting edit mode or on theme change)
    func clearCache() {
        cache.removeAll()
    }
    
    /// Pre-renders snapshots for all cards in the given order
    func preRenderSnapshots(
        for cards: [CardType],
        isWeightChartExpanded: Bool,
        isNovaGroupsCompact: Bool = false,
        isNutriScoreCompact: Bool = false,
        colorScheme: ColorScheme,
        cardViewProvider: (CardType) -> AnyView
    ) {
        for card in cards {
            _ = snapshot(
                for: card,
                isWeightChartExpanded: isWeightChartExpanded,
                isNovaGroupsCompact: isNovaGroupsCompact,
                isNutriScoreCompact: isNutriScoreCompact,
                colorScheme: colorScheme,
                cardViewProvider: cardViewProvider
            )
        }
    }
    
    /// Returns a cached snapshot or renders a new one
    func snapshot(
        for cardType: CardType,
        isWeightChartExpanded: Bool,
        isNovaGroupsCompact: Bool = false,
        isNutriScoreCompact: Bool = false,
        colorScheme: ColorScheme,
        cardViewProvider: (CardType) -> AnyView
    ) -> UIImage? {
        let key = cacheKey(for: cardType, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact, colorScheme: colorScheme)
        
        if let cached = cache[key] {
            return cached
        }
        
        // Render new snapshot
        let image = renderSnapshot(
            for: cardType,
            isWeightChartExpanded: isWeightChartExpanded,
            isNovaGroupsCompact: isNovaGroupsCompact,
            isNutriScoreCompact: isNutriScoreCompact,
            colorScheme: colorScheme,
            cardViewProvider: cardViewProvider
        )
        
        if let image = image {
            cache[key] = image
        }
        
        return image
    }
    
    // MARK: - Private
    
    private func cacheKey(for cardType: CardType, isWeightChartExpanded: Bool, isNovaGroupsCompact: Bool = false, isNutriScoreCompact: Bool = false, colorScheme: ColorScheme) -> String {
        var sizeKey = "normal"
        if cardType == .weightChart && isWeightChartExpanded { sizeKey = "expanded" }
        if cardType == .novaGroups && isNovaGroupsCompact { sizeKey = "compact" }
        if cardType == .nutriScore && isNutriScoreCompact { sizeKey = "compact" }
        let schemeKey = colorScheme == .dark ? "dark" : "light"
        return "\(cardType.rawValue)_\(sizeKey)_\(schemeKey)"
    }
    
    private func renderSnapshot(
        for cardType: CardType,
        isWeightChartExpanded: Bool,
        isNovaGroupsCompact: Bool = false,
        isNutriScoreCompact: Bool = false,
        colorScheme: ColorScheme,
        cardViewProvider: (CardType) -> AnyView
    ) -> UIImage? {
        // Calculate exact size from grid engine
        let (colSpan, rowSpan) = DashboardGridEngine.size(of: cardType, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact)
        
        let availableWidth = containerWidth - (DashboardGridEngine.horizontalPadding * 2)
        let cellWidth = (availableWidth - DashboardGridEngine.spacing) / 2
        
        let width: CGFloat = colSpan == 2 ? availableWidth : cellWidth
        let height: CGFloat = CGFloat(rowSpan) * DashboardGridEngine.cellHeight + CGFloat(max(0, rowSpan - 1)) * DashboardGridEngine.spacing
        
        let size = CGSize(width: width, height: height)
        
        // Get the card view
        let cardView = cardViewProvider(cardType)
        
        // Wrap with fixed size and disable animations
        let wrappedView = cardView
            .transaction { $0.animation = nil }
            .frame(width: size.width, height: size.height)
            .clipped()
            .environment(\.colorScheme, colorScheme)
        
        // Render using ImageRenderer (iOS 16+)
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: wrappedView)
            renderer.scale = UIScreen.main.scale
            return renderer.uiImage
        } else {
            // Fallback for iOS 15: use UIHostingController
            return renderWithHostingController(view: AnyView(wrappedView), size: size)
        }
    }
    
    /// Fallback rendering for iOS 15
    private func renderWithHostingController(view: AnyView, size: CGSize) -> UIImage? {
        let hostingController = UIHostingController(rootView: view)
        hostingController.view.bounds = CGRect(origin: .zero, size: size)
        hostingController.view.backgroundColor = .clear
        
        // Force layout
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        // Render to image
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            hostingController.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
    }
}
