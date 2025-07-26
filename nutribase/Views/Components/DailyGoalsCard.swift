import SwiftUI
import Combine
import HealthKit
import Foundation

// Extension to format integers with commas
extension Int {
    var formattedWithCommas: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        return numberFormatter.string(from: NSNumber(value: self)) ?? String(self)
    }
}

// Available metric types for the Daily Goals card
struct GoalMetric: Identifiable, Equatable {
    let id = UUID()
    let type: MetricType
    var isSelected: Bool
    
    enum MetricType: String, CaseIterable, Hashable {
        case protein = "Protein"
        case steps = "Steps"
        case nova4 = "NOVA 4"
        case calories = "Calories"
        case carbs = "Carbs"
        case fat = "Fat"
        case water = "Water"
        case sleep = "Sleep"
    }
}

struct DailyGoalsCard: View {
    // Protein goal
    var proteinConsumed: Int = 0
    var proteinGoal: Int = 150
    
    // Steps goal
    var stepsGoal: Int = 10000
    
    // Activity manager for step count
    @ObservedObject private var activityManager = ActivityManager.shared
    @ObservedObject private var healthKitManager = HealthKitManager.shared
    
    // NOVA 4 goal (percentage of calories from ultra-processed foods)
    var nova4Percentage: Double = 0
    var nova4Goal: Double = 20 // Target percentage (lower is better)
    
    // Calories goal
    var caloriesConsumed: Int = 0
    var caloriesGoal: Int = 2000
    
    // State for showing the settings sheet
    @State private var showingSettings = false
    
    // Use the shared metrics manager
    @ObservedObject private var metricsManager = GoalMetricsManager.shared
    
    // State for drag operation
    @State private var draggedItem: GoalMetric.MetricType?
    
    // Computed property to get selected metrics
    private var selectedMetrics: [GoalMetric] {
        return metricsManager.selectedMetrics
    }
    
    private var proteinProgress: Double {
        if proteinGoal == 0 { return 0 }
        return Double(proteinConsumed) / Double(proteinGoal)
    }
    
    private var stepsProgress: Double {
        if stepsGoal == 0 { return 0 }
        // Use the steps from ActivityManager if available
        let currentSteps = activityManager.currentActivity.steps > 0 ? 
            activityManager.currentActivity.steps : healthKitManager.todaySteps
        return Double(currentSteps) / Double(stepsGoal)
    }
    
    private var nova4Progress: Double {
        if nova4Goal == 0 { return 0 }
        return nova4Percentage / nova4Goal
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Daily Goals")
                    .font(.custom("Montserrat-Bold", size: 17))
                
                Spacer()
                
                // Settings gear icon
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            HStack(spacing: selectedMetrics.count > 3 ? -5 : 0) {
                Spacer()
                
                // Dynamically show selected metrics (up to 4) with drag-and-drop support
                // Use a simpler approach with local variables to avoid complex expressions
                let metricsToShow = selectedMetrics.prefix(4)
                let useSmallSize = true // Always use small size for consistent appearance
                
                ForEach(metricsToShow) { metric in
                    let isBeingDragged = draggedItem == metric.type
                    let isLastMetric = metric.id == metricsToShow.last?.id
                    let progress = progressForMetric(metric)
                    let metricColor = colorForMetric(metric)
                    let valueText = valueTextForMetric(metric)
                    
                    let goalText = goalTextForMetric(metric)
                    
                    VStack {
                        ZStack {
                            // Background circle
                            Circle()
                                .stroke(lineWidth: 8)
                                .opacity(0.2)
                                .foregroundColor(Color.gray)
                            
                            // Progress circle
                            Circle()
                                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                                .foregroundColor(metricColor)
                                .rotationEffect(Angle(degrees: 270.0))
                                .animation(.linear, value: progress)
                            
                            // Remove button (only in settings view)
                            if showingSettings {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Image(systemName: "minus")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .position(x: useSmallSize ? 55 : 70, y: 10)
                            }
                            
                            // Value and goal text
                            VStack(spacing: 0) {
                                Text(valueText)
                                    .font(.custom("Montserrat-SemiBold", size: useSmallSize ? 14 : 16))
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                                Text(goalText)
                                    .font(.custom("Montserrat-SemiBold", size: useSmallSize ? 10 : 12))
                                    .foregroundColor(.gray)
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: useSmallSize ? 65 : 80, height: useSmallSize ? 65 : 80)
                        
                        Text(metric.type.rawValue)
                            .font(.custom("Montserrat-SemiBold", size: 14))
                            .padding(.top, 4)
                    }
                    .opacity(isBeingDragged ? 0.4 : 1.0)
                    .onDrag {
                        self.draggedItem = metric.type
                        return NSItemProvider(object: metric.type.rawValue as NSString)
                    }
                    .onDrop(of: [.text], isTargeted: nil) { providers in
                        handleDrop(providers: providers, targetMetric: metric)
                        return true
                    }
                    
                    if !isLastMetric {
                        Spacer()
                    }
                }
                
                Spacer()
            }
            .padding(.bottom, 8)
        }
        .onAppear {
            // Refresh step count data when the view appears
            healthKitManager.refreshHealthData()
            activityManager.refreshActivityData()
        }
        .padding(8) // Increased padding around the card for shadow visibility
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.2)) // Increased shadow opacity
                    .offset(y: 3) // Increased shadow offset
                    .blur(radius: 6) // Increased blur radius
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1.0) // More visible border
                    )
            }
        )
        .sheet(isPresented: $showingSettings) {
            MetricsSettingsView(metrics: $metricsManager.metrics)
        }
        .onReceive(NotificationCenter.default.publisher(for: .goalMetricsUpdated)) { _ in
            // Force view to refresh when metrics are updated
        }
    }
}

// Settings view for selecting which metrics to display
// Helper functions for metric display
extension DailyGoalsCard {
    // Handle drop operation for drag and drop
    private func handleDrop(providers: [NSItemProvider], targetMetric: GoalMetric) {
        if let first = providers.first {
            let _ = first.loadObject(ofClass: NSString.self) { draggedValue, _ in
                if let value = draggedValue as? String,
                   let draggedType = GoalMetric.MetricType(rawValue: value),
                   let draggedIndex = metricsManager.metrics.firstIndex(where: { $0.type == draggedType }),
                   let dropIndex = metricsManager.metrics.firstIndex(where: { $0.type == targetMetric.type }) {
                    
                    // Only reorder if indices are different
                    if draggedIndex != dropIndex {
                        // Move the item in the metrics array
                        let sourceIndexSet = IndexSet(integer: draggedIndex)
                        metricsManager.moveMetric(from: sourceIndexSet, to: dropIndex > draggedIndex ? dropIndex + 1 : dropIndex)
                    }
                }
            }
        }
        self.draggedItem = nil
    }
    
    // Get progress value for a given metric
    func progressForMetric(_ metric: GoalMetric) -> Double {
        switch metric.type {
        case .protein:
            return proteinProgress
        case .steps:
            return stepsProgress
        case .nova4:
            return nova4Progress
        case .calories:
            return caloriesGoal > 0 ? Double(caloriesConsumed) / Double(caloriesGoal) : 0
        case .carbs:
            return 0.5 // Placeholder
        case .fat:
            return 0.3 // Placeholder
        case .water:
            return 0.6 // Placeholder
        case .sleep:
            return 0.8 // Placeholder
        }
    }
    
    // Get color for a given metric
    func colorForMetric(_ metric: GoalMetric) -> Color {
        switch metric.type {
        case .protein:
            return Color(red: 0.2, green: 0.8, blue: 0.2) // Brighter green
        case .steps:
            return Color(red: 0.0, green: 0.5, blue: 1.0) // Bright blue
        case .nova4:
            return Color(red: 1.0, green: 0.6, blue: 0.0) // Bright orange
        case .calories:
            return Color(red: 0.6, green: 0.2, blue: 0.8) // Vibrant purple
        case .carbs:
            return Color(red: 1.0, green: 0.8, blue: 0.0) // Bright yellow
        case .fat:
            return Color(red: 1.0, green: 0.4, blue: 0.6) // Bright pink
        case .water:
            return Color(red: 0.0, green: 0.8, blue: 1.0) // Bright cyan
        case .sleep:
            return Color(red: 0.4, green: 0.2, blue: 0.8) // Bright indigo
        }
    }
    
    // Get value text for a given metric (just the current value, not the goal)
    func valueTextForMetric(_ metric: GoalMetric) -> String {
        switch metric.type {
        case .protein:
            return "\(proteinConsumed)"
        case .steps:
            // Use the steps from ActivityManager if available
            let currentSteps = activityManager.currentActivity.steps > 0 ? 
                activityManager.currentActivity.steps : healthKitManager.todaySteps
            return "\(currentSteps.formattedWithCommas)"
        case .nova4:
            return "\(Int(nova4Percentage))%"
        case .calories:
            let remaining = caloriesGoal - caloriesConsumed
            return "\(remaining > 0 ? remaining : 0)"
        case .carbs:
            return "0"
        case .fat:
            return "0"
        case .water:
            return "0"
        case .sleep:
            return "0"
        }
    }
    
    // Get goal text for a given metric
    func goalTextForMetric(_ metric: GoalMetric) -> String {
        switch metric.type {
        case .protein:
            return "/\(proteinGoal)g"
        case .steps:
            return "/\(stepsGoal.formattedWithCommas)"
        case .nova4:
            return "/\(Int(nova4Goal))%"
        case .calories:
            return "/\(caloriesGoal)"
        case .carbs:
            return "/250g" // Placeholder
        case .fat:
            return "/65g" // Placeholder
        case .water:
            return "/2L" // Placeholder
        case .sleep:
            return "/8h" // Placeholder
        }
    }
}

struct MetricsSettingsView: View {
    @Binding var metrics: [GoalMetric]
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var metricsManager = GoalMetricsManager.shared
    
    // State for drag operation
    @State private var draggedItem: GoalMetric.MetricType?
    
    // Helper method to handle metric card drop
    private func handleMetricCardDrop(providers: [NSItemProvider], targetType: GoalMetric.MetricType) {
        if let first = providers.first {
            let _ = first.loadObject(ofClass: NSString.self) { draggedValue, _ in
                if let value = draggedValue as? String,
                   let draggedType = GoalMetric.MetricType(rawValue: value),
                   let draggedIndex = metricsManager.metrics.firstIndex(where: { $0.type == draggedType }),
                   let dropIndex = metricsManager.metrics.firstIndex(where: { $0.type == targetType }) {
                    
                    // Only reorder if indices are different
                    if draggedIndex != dropIndex {
                        // Move the item in the metrics array
                        let sourceIndexSet = IndexSet(integer: draggedIndex)
                        metricsManager.moveMetric(from: sourceIndexSet, to: dropIndex > draggedIndex ? dropIndex + 1 : dropIndex)
                    }
                }
            }
        }
        self.draggedItem = nil
    }
    
    // Track which metrics are in the daily goals card
    private var selectedMetrics: [GoalMetric.MetricType] {
        // We need to preserve the original order from the metrics array
        // rather than creating a new filtered array that loses the order
        return metricsManager.metrics.filter { $0.isSelected }.map { $0.type }
    }
    
    // Initialize selected metrics from binding
    private func initializeSelectedMetrics() {
        // No need to initialize here, it's a computed property
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Preview of the Daily Goals card with current selection
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Daily Goals")
                            .font(.headline)
                        
                        Spacer()
                        
                        Image(systemName: "gear")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    HStack(spacing: selectedMetrics.count > 3 ? 5 : 12) {
                        Spacer()
                        
                        // Show selected metrics (up to 4)
                        ForEach(selectedMetrics.prefix(4), id: \.self) { metricType in
                            VStack(spacing: 4) {
                                ZStack {
                                    MetricPreviewCard(metricType: metricType)
                                        .frame(width: selectedMetrics.count > 3 ? 60 : 70, height: selectedMetrics.count > 3 ? 60 : 70)
                                    
                                    // Remove button overlay
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Image(systemName: "minus")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                        .offset(x: 25, y: -25)
                                }
                                .onDrag {
                                    self.draggedItem = metricType
                                    return NSItemProvider(object: metricType.rawValue as NSString)
                                }
                                .onDrop(of: [.text], isTargeted: nil) { providers in
                                    // Handle reordering within the Daily Goals card
                                    guard let draggedItem = self.draggedItem,
                                          selectedMetrics.contains(draggedItem) else { return false }
                                    
                                    // Find the indices of both metrics in the full metrics array
                                    guard let draggedIndex = metricsManager.metrics.firstIndex(where: { $0.type == draggedItem }),
                                          let targetIndex = metricsManager.metrics.firstIndex(where: { $0.type == metricType }) else { return false }
                                    
                                    // Only reorder if indices are different and both are selected
                                    if draggedIndex != targetIndex && 
                                       metricsManager.metrics[draggedIndex].isSelected && 
                                       metricsManager.metrics[targetIndex].isSelected {
                                        
                                        // Use insertion-based reordering (similar to dashboard cards)
                                        // This approach makes items shift to make room rather than swapping
                                        DispatchQueue.main.async {
                                            withAnimation(.spring()) {
                                                let sourceIndexSet = IndexSet(integer: draggedIndex)
                                                metricsManager.moveMetric(from: sourceIndexSet, to: targetIndex > draggedIndex ? targetIndex : targetIndex)
                                                metricsManager.saveMetrics() // Ensure changes are saved
                                                
                                                // Post notification to update any views that depend on this data
                                                NotificationCenter.default.post(name: .goalMetricsUpdated, object: nil)
                                            }
                                        }
                                    }
                                    
                                    self.draggedItem = nil
                                    return true
                                }
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        if let index = metricsManager.metrics.firstIndex(where: { $0.type == metricType }) {
                                            metricsManager.metrics[index].isSelected = false
                                        }
                                    }
                                }
                                
                                Text(metricType.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 5)
                            
                            if metricType != selectedMetrics.prefix(4).last {
                                Spacer()
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical)
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding()
                .onDrop(of: ["public.text"], isTargeted: nil) { providers in
                    // Break up complex expressions into simpler steps
                    guard let draggedItem = self.draggedItem else { return false }
                    let alreadySelected = selectedMetrics.contains(draggedItem)
                    let hasRoom = selectedMetrics.count < 4
                    
                    // If the item is already selected, we're just reordering within the preview
                    // This is now handled by the individual metric's onDrop handler
                    if alreadySelected {
                        return false
                    }
                    
                    // If the item is not selected and there's room, add it to the end without saving
                    if !alreadySelected && hasRoom {
                        withAnimation(.spring()) {
                            metricsManager.addMetricToEndWithoutSaving(metricType: draggedItem)
                        }
                        self.draggedItem = nil
                        return true
                    }
                    return false
                }
                
                Text("Metrics Library (up to 4)")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.top)
                
                // Available metrics to drag from
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 15) {
                        // Use a simpler approach to avoid complex expressions
                        ForEach(metricsManager.metrics) { metric in
                            let metricType = metric.type
                            let isSelected = selectedMetrics.contains(metricType)
                            let isDragging = draggedItem == metricType
                            
                            MetricCard(metricType: metricType, isSelected: isSelected)
                                .opacity(isSelected ? 0.6 : 1.0)
                                .opacity(isDragging ? 0.4 : 1.0)
                                .onDrag {
                                    self.draggedItem = metricType
                                    return NSItemProvider(object: metricType.rawValue as NSString)
                                }
                                .onDrop(of: [.text], isTargeted: nil) { providers in
                                    // Use a helper method to handle the drop
                                    handleMetricCardDrop(providers: providers, targetType: metricType)
                                    return true
                                }
                                .overlay(isSelected ? Text("In Use")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                                    .offset(y: 20) : nil)
                                .onTapGesture {
                                    if !selectedMetrics.contains(metricType) && selectedMetrics.count < 4 {
                                        withAnimation(.spring()) {
                                            metricsManager.addMetricToEndWithoutSaving(metricType: metricType)
                                        }
                                    }
                                }
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Daily Goals Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Save metrics before dismissing
                        metricsManager.saveMetrics()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                // No need to initialize here, it's a computed property
            }
        }
    }
}

// Card for displaying a metric in the grid
struct MetricCard: View {
    let metricType: GoalMetric.MetricType
    let isSelected: Bool
    @State private var isDragging = false
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(colorForMetricType(metricType).opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: iconForMetricType(metricType))
                    .font(.system(size: 24))
                    .foregroundColor(colorForMetricType(metricType))
                
                // Drag handle indicator
                if !isSelected {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.gray.opacity(0.7))
                        .clipShape(Circle())
                        .offset(x: 20, y: 20)
                        .opacity(0.7)
                }
            }
            
            Text(metricType.rawValue)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.vertical, 8)
        .frame(minWidth: 100, minHeight: 100)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.spring(), value: isDragging)
        .onLongPressGesture(minimumDuration: 0.1) {
            // This helps provide visual feedback when starting a drag
            withAnimation {
                isDragging = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        isDragging = false
                    }
                }
            }
        }
    }
}

// Smaller preview card for the Daily Goals section
struct MetricPreviewCard: View {
    let metricType: GoalMetric.MetricType
    
    // Placeholder values for the preview
    private var value: String {
        switch metricType {
        case .protein:
            return "0"
        case .steps:
            return "0"
        case .nova4:
            return "0%"
        case .calories:
            return "0"
        case .carbs:
            return "0"
        case .fat:
            return "0"
        case .water:
            return "0"
        case .sleep:
            return "0"
        }
    }
    
    private var goal: String {
        switch metricType {
        case .protein:
            return "/150g"
        case .steps:
            return "/10,000"
        case .nova4:
            return "/20%"
        case .calories:
            return "/2100"
        case .carbs:
            return "/250g"
        case .fat:
            return "/65g"
        case .water:
            return "/2L"
        case .sleep:
            return "/8h"
        }
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(lineWidth: 8)
                .opacity(0.2)
                .foregroundColor(Color.gray)
            
            // Progress circle - using 0.7 as a sample progress value for preview
            Circle()
                .trim(from: 0.0, to: 0.7)
                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .foregroundColor(colorForMetricType(metricType))
                .rotationEffect(Angle(degrees: 270.0))
            
            // Value and goal text
            VStack(spacing: 0) {
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(goal)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
    }
}

// Helper functions for metric display
func colorForMetricType(_ type: GoalMetric.MetricType) -> Color {
    switch type {
    case .protein:
        return Color(red: 0.2, green: 0.8, blue: 0.2) // Brighter green
    case .steps:
        return Color(red: 0.0, green: 0.5, blue: 1.0) // Bright blue
    case .nova4:
        return Color(red: 1.0, green: 0.6, blue: 0.0) // Bright orange
    case .calories:
        return Color(red: 0.6, green: 0.2, blue: 0.8) // Vibrant purple
    case .carbs:
        return Color(red: 1.0, green: 0.8, blue: 0.0) // Bright yellow
    case .fat:
        return Color(red: 1.0, green: 0.4, blue: 0.6) // Bright pink
    case .water:
        return Color(red: 0.0, green: 0.8, blue: 1.0) // Bright cyan
    case .sleep:
        return Color(red: 0.4, green: 0.2, blue: 0.8) // Bright indigo
    }
}

func iconForMetricType(_ type: GoalMetric.MetricType) -> String {
    switch type {
    case .protein:
        return "figure.strengthtraining.traditional"
    case .steps:
        return "figure.walk"
    case .nova4:
        return "chart.pie"
    case .calories:
        return "flame"
    case .carbs:
        return "c.circle"
    case .fat:
        return "f.circle"
    case .water:
        return "drop"
    case .sleep:
        return "bed.double"
    }
}

#Preview {
    VStack {
        DailyGoalsCard(
            proteinConsumed: 75,
            proteinGoal: 150,
            stepsGoal: 10000,
            nova4Percentage: 15,
            nova4Goal: 20
        )
        .padding()
        .background(Color(.systemGray6))
    }
}
