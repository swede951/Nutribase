import SwiftUI
import Combine

/// Lazy card rendering system for dashboard optimization.
/// Only renders cards that are visible in the viewport, deferring off-screen cards.
class LazyCardRenderer: ObservableObject {
    static let shared = LazyCardRenderer()
    
    // MARK: - Visibility Tracking
    
    /// Set of currently visible card IDs
    @Published private(set) var visibleCards: Set<String> = []
    
    /// Cards that have been rendered at least once (warm cache)
    private var renderedCards: Set<String> = []
    
    /// Debounce timer for visibility updates
    private var visibilityDebounceTimer: Timer?
    
    /// Pending visibility updates
    private var pendingVisibilityUpdates: [(String, Bool)] = []
    
    // MARK: - Configuration
    
    /// How far off-screen to pre-render (in points)
    let preRenderMargin: CGFloat = 100
    
    /// Debounce interval for visibility changes
    let debounceInterval: TimeInterval = 0.1
    
    /// Maximum cards to render simultaneously during initial load
    let maxInitialRenderBatch: Int = 6
    
    // MARK: - Rendering State
    
    /// Cards currently being rendered
    private var renderingCards: Set<String> = []
    
    /// Render priority queue (higher priority = render first)
    private var renderPriorityQueue: [(cardId: String, priority: Int)] = []
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Visibility Management
    
    /// Report that a card is now visible
    func cardBecameVisible(_ cardId: String) {
        pendingVisibilityUpdates.append((cardId, true))
        scheduleVisibilityUpdate()
    }
    
    /// Report that a card is no longer visible
    func cardBecameInvisible(_ cardId: String) {
        pendingVisibilityUpdates.append((cardId, false))
        scheduleVisibilityUpdate()
    }
    
    /// Schedule debounced visibility update
    private func scheduleVisibilityUpdate() {
        visibilityDebounceTimer?.invalidate()
        visibilityDebounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.processVisibilityUpdates()
        }
    }
    
    /// Process all pending visibility updates
    private func processVisibilityUpdates() {
        for (cardId, isVisible) in pendingVisibilityUpdates {
            if isVisible {
                visibleCards.insert(cardId)
                renderedCards.insert(cardId)
            } else {
                visibleCards.remove(cardId)
            }
        }
        pendingVisibilityUpdates.removeAll()
    }
    
    /// Check if a card should be rendered
    func shouldRenderCard(_ cardId: String) -> Bool {
        // Always render if visible
        if visibleCards.contains(cardId) {
            return true
        }
        
        // Render if it was previously rendered (warm cache)
        if renderedCards.contains(cardId) {
            return true
        }
        
        // Otherwise, defer rendering
        return false
    }
    
    /// Check if a card is in the warm cache
    func isCardWarmed(_ cardId: String) -> Bool {
        return renderedCards.contains(cardId)
    }
    
    /// Mark a card as rendered
    func markCardRendered(_ cardId: String) {
        renderedCards.insert(cardId)
    }
    
    // MARK: - Priority Rendering
    
    /// Add card to priority render queue
    func queueForRendering(_ cardId: String, priority: Int = 0) {
        renderPriorityQueue.append((cardId, priority))
        renderPriorityQueue.sort { $0.priority > $1.priority }
    }
    
    /// Get next card to render
    func nextCardToRender() -> String? {
        guard !renderPriorityQueue.isEmpty else { return nil }
        return renderPriorityQueue.removeFirst().cardId
    }
    
    // MARK: - Reset
    
    /// Reset all visibility state
    func reset() {
        visibleCards.removeAll()
        renderedCards.removeAll()
        renderingCards.removeAll()
        renderPriorityQueue.removeAll()
        pendingVisibilityUpdates.removeAll()
        visibilityDebounceTimer?.invalidate()
    }
}

// MARK: - Lazy Card View Modifier

/// View modifier that enables lazy rendering for dashboard cards
struct LazyCardModifier: ViewModifier {
    let cardId: String
    @ObservedObject private var renderer = LazyCardRenderer.shared
    @State private var hasAppeared = false
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .opacity(shouldRender ? 1 : 0)
                .overlay(
                    Group {
                        if !shouldRender {
                            // Placeholder while not rendered
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appInsetBackground)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.8)
                                )
                        }
                    }
                )
                .onAppear {
                    hasAppeared = true
                    renderer.cardBecameVisible(cardId)
                }
                .onDisappear {
                    renderer.cardBecameInvisible(cardId)
                }
        }
    }
    
    private var shouldRender: Bool {
        return hasAppeared || renderer.shouldRenderCard(cardId)
    }
}

extension View {
    /// Apply lazy rendering optimization to a dashboard card
    func lazyCard(id: String) -> some View {
        self.modifier(LazyCardModifier(cardId: id))
    }
}

// MARK: - Visibility Detection View

/// View that reports visibility changes
struct VisibilityTracker: View {
    let cardId: String
    let onVisibilityChange: (Bool) -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: VisibilityPreferenceKey.self, value: geometry.frame(in: .global))
                .onPreferenceChange(VisibilityPreferenceKey.self) { frame in
                    let screenHeight = UIScreen.main.bounds.height
                    let isNowVisible = frame.minY < screenHeight && frame.maxY > 0
                    
                    if isNowVisible != isVisible {
                        isVisible = isNowVisible
                        onVisibilityChange(isNowVisible)
                    }
                }
        }
        .frame(height: 0)
    }
}

struct VisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Deferred Content View

/// View that defers its content rendering until visible
struct DeferredView<Content: View>: View {
    let cardId: String
    let content: () -> Content
    
    @State private var shouldRender = false
    @ObservedObject private var renderer = LazyCardRenderer.shared
    
    init(cardId: String, @ViewBuilder content: @escaping () -> Content) {
        self.cardId = cardId
        self.content = content
    }
    
    var body: some View {
        Group {
            if shouldRender || renderer.isCardWarmed(cardId) {
                content()
                    .onAppear {
                        renderer.markCardRendered(cardId)
                    }
            } else {
                // Lightweight placeholder
                placeholderView
                    .onAppear {
                        // Delay rendering slightly to prioritize visible cards
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            shouldRender = true
                        }
                    }
            }
        }
    }
    
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.appInsetBackground)
            .frame(height: 120)
    }
}
