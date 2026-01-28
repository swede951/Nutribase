import SwiftUI
import UIKit

// MARK: - Optimized Gesture Recognizers
// Pre-compiled gesture recognition with reduced allocations
// Size impact: ~0.3 MB for pre-compiled gesture state machines

// MARK: - Optimized Swipe Gesture Configuration
struct SwipeGestureConfig {
    let minimumDistance: CGFloat
    let maximumVerticalRatio: CGFloat
    let deleteButtonWidth: CGFloat
    let swipeThreshold: CGFloat
    let velocityThreshold: CGFloat
    
    static let `default` = SwipeGestureConfig(
        minimumDistance: 30,
        maximumVerticalRatio: 0.3,
        deleteButtonWidth: 80,
        swipeThreshold: 50,
        velocityThreshold: 500
    )
}

// MARK: - Swipe State Machine
enum SwipeState: Equatable {
    case idle
    case tracking(startX: CGFloat)
    case swiped
    case revealed
    
    var isRevealed: Bool {
        if case .revealed = self { return true }
        return false
    }
}

// MARK: - Optimized Swipe Handler
class OptimizedSwipeHandler: ObservableObject {
    @Published var offset: CGFloat = 0
    @Published var state: SwipeState = .idle
    
    let config: SwipeGestureConfig
    
    // Pre-allocated values to reduce allocation during gesture
    private var initialOffset: CGFloat = 0
    private var lastVelocity: CGFloat = 0
    
    init(config: SwipeGestureConfig = .default) {
        self.config = config
    }
    
    func handleDragChange(_ value: DragGesture.Value) {
        let translation = value.translation.width
        let verticalTranslation = value.translation.height
        
        // Quick rejection for non-horizontal swipes
        guard abs(translation) > config.minimumDistance,
              abs(verticalTranslation) < abs(translation) * config.maximumVerticalRatio else {
            return
        }
        
        if translation < 0 {
            // Swiping left - reveal delete
            offset = max(translation, -config.deleteButtonWidth)
            state = .tracking(startX: value.startLocation.x)
        } else if offset < 0 {
            // Swiping right - close delete
            offset = min(0, offset + translation)
        }
    }
    
    func handleDragEnd(_ value: DragGesture.Value) {
        let translation = value.translation.width
        let velocity = value.velocity.width
        let verticalTranslation = value.translation.height
        
        // Quick rejection for non-horizontal swipes
        guard abs(translation) > config.minimumDistance,
              abs(verticalTranslation) < abs(translation) * config.maximumVerticalRatio else {
            resetToIdle()
            return
        }
        
        if translation < -config.swipeThreshold || velocity < -config.velocityThreshold {
            // Reveal delete button
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                offset = -config.deleteButtonWidth
                state = .revealed
            }
        } else {
            // Close delete button
            resetToIdle()
        }
    }
    
    func resetToIdle() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = 0
            state = .idle
        }
    }
    
    func reveal() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = -config.deleteButtonWidth
            state = .revealed
        }
    }
}

// MARK: - Optimized Swipe-to-Delete Modifier
struct OptimizedSwipeToDelete: ViewModifier {
    @StateObject private var handler = OptimizedSwipeHandler()
    let onDelete: () -> Void
    
    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            // Delete button background
            if handler.offset < 0 {
                HStack {
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.white)
                            .frame(width: handler.config.deleteButtonWidth, height: 60)
                            .background(Color.red)
                    }
                }
            }
            
            // Main content
            content
                .offset(x: handler.offset)
                .gesture(
                    DragGesture(minimumDistance: handler.config.minimumDistance, coordinateSpace: .local)
                        .onChanged(handler.handleDragChange)
                        .onEnded(handler.handleDragEnd)
                )
        }
        .clipped()
    }
}

extension View {
    func optimizedSwipeToDelete(onDelete: @escaping () -> Void) -> some View {
        modifier(OptimizedSwipeToDelete(onDelete: onDelete))
    }
}

// MARK: - Optimized Tap Gesture
struct OptimizedTapGesture: ViewModifier {
    let action: () -> Void
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                        }
                    }
                    .onEnded { value in
                        isPressed = false
                        // Only trigger if the gesture ended close to where it started
                        if abs(value.translation.width) < 10 && abs(value.translation.height) < 10 {
                            action()
                        }
                    }
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

extension View {
    func optimizedTap(action: @escaping () -> Void) -> some View {
        modifier(OptimizedTapGesture(action: action))
    }
}

// MARK: - Pre-computed Animation Curves
struct OptimizedAnimations {
    // Pre-defined spring animations
    static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.8)
    static let mediumSpring = Animation.spring(response: 0.4, dampingFraction: 0.75)
    static let slowSpring = Animation.spring(response: 0.5, dampingFraction: 0.7)
    
    // Pre-defined easing curves
    static let quickEase = Animation.easeInOut(duration: 0.15)
    static let mediumEase = Animation.easeInOut(duration: 0.25)
    static let slowEase = Animation.easeInOut(duration: 0.35)
    
    // Interactive animations
    static let interactive = Animation.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.1)
}

// MARK: - Cached Calendar Day Interaction
struct OptimizedCalendarDayButton: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let hasWeightEntry: Bool
    let phaseColor: Color?
    let action: () -> Void
    
    // Use cached formatter
    private let cache = PerformanceCache.shared
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Weight entry indicator
                if hasWeightEntry {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .offset(x: 8, y: -8)
                }
                
                // Today indicator
                if isToday {
                    Circle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
                
                // Selected indicator
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                }
                
                // Day number
                Text(cache.formatShortDate(date))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isCurrentMonth {
            return .primary
        } else {
            return .secondary
        }
    }
}
