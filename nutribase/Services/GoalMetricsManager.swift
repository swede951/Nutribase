import Foundation
import Combine

// Manager for handling goal metrics ordering and persistence
class GoalMetricsManager: ObservableObject {
    static let shared = GoalMetricsManager()
    
    // Key for UserDefaults storage
    private let metricsOrderKey = "goalMetricsOrder"
    private let selectedMetricsKey = "selectedGoalMetrics"
    
    // Published properties for metrics
    @Published var metrics: [GoalMetric] = []
    
    // Initialize with default or saved metrics
    private init() {
        loadMetrics()
    }
    
    // Load metrics from UserDefaults
    private func loadMetrics() {
        // Default metrics with realistic goal values
        let defaultMetrics = [
            GoalMetric(type: .protein, isSelected: true, goal: 176),
            GoalMetric(type: .steps, isSelected: true, goal: 10000),
            GoalMetric(type: .activityCalories, isSelected: false, goal: 500),
            GoalMetric(type: .nova4, isSelected: true, goal: 20),
            GoalMetric(type: .calories, isSelected: false, goal: 2100),
            GoalMetric(type: .caloriesRemaining, isSelected: false, goal: 2100),
            GoalMetric(type: .carbs, isSelected: false, goal: 250),
            GoalMetric(type: .fat, isSelected: false, goal: 70)
            // GoalMetric(type: .water, isSelected: false, goal: 2000), // TEMPORARILY DISABLED
            // GoalMetric(type: .sleep, isSelected: false, goal: 8) // TEMPORARILY DISABLED
        ]
        
        // Try to load saved metrics order
        if let savedData = UserDefaults.standard.data(forKey: metricsOrderKey),
           let savedTypes = try? JSONDecoder().decode([String].self, from: savedData) {
            
            // Convert saved types to metrics
            var loadedMetrics: [GoalMetric] = []
            
            // First add metrics in the saved order
            for typeString in savedTypes {
                if let type = GoalMetric.MetricType(rawValue: typeString),
                   let defaultMetric = defaultMetrics.first(where: { $0.type == type }) {
                    loadedMetrics.append(defaultMetric)
                }
            }
            
            // Add any remaining default metrics that weren't in the saved order
            for metric in defaultMetrics {
                if !loadedMetrics.contains(where: { $0.type == metric.type }) {
                    loadedMetrics.append(metric)
                }
            }
            
            metrics = loadedMetrics
        } else {
            // Use default metrics if no saved order
            metrics = defaultMetrics
        }
        
        // Load selected state
        if let savedSelectionData = UserDefaults.standard.data(forKey: selectedMetricsKey),
           let savedSelection = try? JSONDecoder().decode([String: Bool].self, from: savedSelectionData) {
            
            // Update selection state for each metric
            for i in 0..<metrics.count {
                if let isSelected = savedSelection[metrics[i].type.rawValue] {
                    metrics[i].isSelected = isSelected
                }
            }
        }
    }
    
    // Save metrics order to UserDefaults
    func saveMetrics() {
        // Save the order of metric types
        let metricTypes = metrics.map { $0.type.rawValue }
        if let encodedOrder = try? JSONEncoder().encode(metricTypes) {
            UserDefaults.standard.set(encodedOrder, forKey: metricsOrderKey)
        }
        
        // Save the selection state
        var selectionDict: [String: Bool] = [:]
        for metric in metrics {
            selectionDict[metric.type.rawValue] = metric.isSelected
        }
        
        if let encodedSelection = try? JSONEncoder().encode(selectionDict) {
            UserDefaults.standard.set(encodedSelection, forKey: selectedMetricsKey)
        }
        
        // Post notification for views to update
        NotificationCenter.default.post(name: .goalMetricsUpdated, object: nil)
    }
    
    // Move a metric from one position to another
    func moveMetric(from source: IndexSet, to destination: Int) {
        metrics.move(fromOffsets: source, toOffset: destination)
        saveMetrics()
    }
    
    // Toggle selection state for a metric
    func toggleSelection(for metricType: GoalMetric.MetricType) {
        if let index = metrics.firstIndex(where: { $0.type == metricType }) {
            metrics[index].isSelected.toggle()
            saveMetrics()
        }
    }
    
    // Add a metric to the end of the selected metrics without saving
    func addMetricToEndWithoutSaving(metricType: GoalMetric.MetricType) {
        // First, make sure the metric exists and is not already selected
        guard let index = metrics.firstIndex(where: { $0.type == metricType }),
              !metrics[index].isSelected else {
            return
        }
        
        // Mark it as selected
        metrics[index].isSelected = true
        
        // Move it to the end of the selected metrics
        // First, remove it from its current position
        let metric = metrics.remove(at: index)
        
        // Then insert it after the last selected metric
        let lastSelectedIndex = metrics.lastIndex(where: { $0.isSelected }) ?? -1
        metrics.insert(metric, at: lastSelectedIndex + 1)
        
        // Note: This method doesn't save changes automatically
        // The caller is responsible for calling saveMetrics() when appropriate
    }
    
    // Add a metric to the end of the selected metrics and save changes
    func addMetricToEnd(metricType: GoalMetric.MetricType) {
        addMetricToEndWithoutSaving(metricType: metricType)
        saveMetrics()
    }
    
    // Get selected metrics in order
    var selectedMetrics: [GoalMetric] {
        return metrics.filter { $0.isSelected }
    }
}

// Notification name extension
extension Notification.Name {
    static let goalMetricsUpdated = Notification.Name("goalMetricsUpdated")
}
