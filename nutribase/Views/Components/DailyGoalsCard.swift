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
    var goal: Int = 100 // Default goal value
    enum MetricType: String, CaseIterable, Hashable {
        case protein = "Protein"
        case steps = "Steps"
        case activityCalories = "Activity"
        case nova4 = "NOVA 4"
        case calories = "Calories"
        case caloriesRemaining = "Cal Remaining"
        case carbs = "Carbs"
        case fat = "Fat"
        case fibre = "Fibre"
        // case water = "Water" // TEMPORARILY DISABLED
        // case sleep = "Sleep" // TEMPORARILY DISABLED
    }
}

struct DailyGoalsCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    // Preview mode flag
    var isPreview: Bool = false
    
    // Protein goal
    var proteinConsumed: Int = 0
    var proteinGoal: Int = 150
    
    // Date for which to show data
    var selectedDate: Date = Date()
    
    // Activity manager for step count
    @ObservedObject private var activityManager = ActivityManager.shared
    @ObservedObject private var healthKitManager = HealthKitManager.shared
    
    // Metric visibility service
    @StateObject private var visibilityService = MetricVisibilityService.shared
    
    // Dynamic goals from UserDefaults
    @State private var stepsGoal: Int = 10000
    @State private var stepsForSelectedDate: Int = 0
    @State private var activityCaloriesGoal: Int = 500
    @State private var activityCaloriesForSelectedDate: Int = 0
    
    // NOVA 4 goal (percentage of calories from ultra-processed foods)
    var nova4Percentage: Double = 0
    var nova4Goal: Double = 20 // Target percentage (lower is better)
    
    // Calories goal
    var caloriesConsumed: Int = 0
    var caloriesGoal: Int = 2000
    
    // Carbs goal
    var carbsConsumed: Int = 0
    var carbsGoal: Int = 300
    
    // Fat goal
    var fatConsumed: Int = 0
    var fatGoal: Int = 65
    
    // Fibre goal
    var fibreConsumed: Int = 0
    var fibreGoal: Int = 30
    
    // State for showing the settings sheet
    @State private var showingSettings = false
    
    // Use the shared metrics manager
    @ObservedObject private var metricsManager = GoalMetricsManager.shared
    
    // State for drag operation
    @State private var draggedItem: GoalMetric.MetricType?
    
    // Computed property to get selected metrics filtered by visibility preferences
    private var selectedMetrics: [GoalMetric] {
        return metricsManager.selectedMetrics.filter { metric in
            switch metric.type {
            case .protein:
                return visibilityService.showProtein
            case .calories, .caloriesRemaining:
                return visibilityService.showCalories
            case .carbs:
                return visibilityService.showCarbs
            case .fat:
                return visibilityService.showFat
            case .fibre:
                return true // Always show fibre
            case .nova4:
                return visibilityService.showNovaScore
            case .steps, .activityCalories:
                return true // Always show non-nutrition metrics
            // case .sleep:
            //     return true // Always show non-nutrition metrics
            }
        }
    }
    
    private var proteinProgress: Double {
        if proteinGoal == 0 { return 0 }
        return Double(proteinConsumed) / Double(proteinGoal)
    }
    
    private var stepsProgress: Double {
        if stepsGoal == 0 { return 0 }
        // Use steps for the selected date
        let currentSteps = stepsForSelectedDate
        return Double(currentSteps) / Double(stepsGoal)
    }
    
    private var activityCaloriesProgress: Double {
        if activityCaloriesGoal == 0 { return 0 }
        let currentCalories = activityCaloriesForSelectedDate
        return Double(currentCalories) / Double(activityCaloriesGoal)
    }
    
    private var nova4Progress: Double {
        if nova4Goal == 0 { return 0 }
        return nova4Percentage / nova4Goal
    }
    
    var body: some View {
        FixedSizeCard(
            title: "Daily Goals",
            customHeight: 150,
            titleAction: isPreview ? nil : { showingSettings = true },
            titleActionIcon: isPreview ? nil : "gear"
        ) {
            VStack(alignment: .leading, spacing: 8) {
            
            HStack(spacing: 0) {
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
                                .stroke(lineWidth: 6)
                                .foregroundColor(Color.appInsetBackground)
                            
                            // Progress circle
                            Circle()
                                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                                .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
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
                                    .font(.system(size: useSmallSize ? 14 : 16, weight: .bold))
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                                Text(goalText)
                                    .font(.system(size: useSmallSize ? 10 : 12, weight: .medium))
                                    .foregroundColor(.gray)
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: useSmallSize ? 65 : 80, height: useSmallSize ? 65 : 80)
                        
                        Text(metric.type == .caloriesRemaining ? "Calories" : metric.type.rawValue)
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
            .padding(.top, 12)
            .padding(.bottom, 12)
            .padding(.horizontal, 4)
            }
        }
        .onAppear {
            // Refresh step count data when the view appears
            loadGoals()
            fetchStepsForDate()
        }
        .onChange(of: selectedDate) {
            // Fetch steps whenever the date changes
            fetchStepsForDate()
        }
        .sheet(isPresented: $showingSettings) {
            DailyGoalsSettingsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .goalMetricsUpdated)) { _ in
            // Force view to refresh when metrics are updated
        }
        .onReceive(NotificationCenter.default.publisher(for: .metricGoalsUpdated)) { _ in
            loadGoals()
        }
    }
    
    private func loadGoals() {
        stepsGoal = UserDefaults.standard.integer(forKey: "stepsGoal")
        if stepsGoal == 0 { stepsGoal = 10000 }
        
        activityCaloriesGoal = UserDefaults.standard.integer(forKey: "activityCaloriesGoal")
        if activityCaloriesGoal == 0 { activityCaloriesGoal = 500 }
    }
    
    private func fetchStepsForDate() {
        // Use preview data if in preview mode
        if isPreview {
            stepsForSelectedDate = 7850
            activityCaloriesForSelectedDate = 250
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? selectedDate
        
        // If selected date is today, use real-time data
        if calendar.isDateInToday(selectedDate) {
            let currentSteps = activityManager.currentActivity.steps > 0 ? 
                activityManager.currentActivity.steps : healthKitManager.todaySteps
            stepsForSelectedDate = currentSteps
            activityCaloriesForSelectedDate = healthKitManager.todayActiveCalories
            // Also refresh to get latest
            healthKitManager.refreshHealthData()
            activityManager.refreshActivityData()
        } else {
            // For past dates, fetch from HealthKit
            healthKitManager.fetchStepsForDateRange(start: startOfDay, end: endOfDay) { steps, error in
                DispatchQueue.main.async {
                    self.stepsForSelectedDate = steps
                }
            }
            healthKitManager.fetchActiveCaloriesForDateRange(start: startOfDay, end: endOfDay) { calories, error in
                DispatchQueue.main.async {
                    self.activityCaloriesForSelectedDate = calories
                }
            }
        }
    }
}

// Settings view for selecting which metrics to display
struct DailyGoalsSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var metricsManager = GoalMetricsManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var activityManager = ActivityManager.shared
    @StateObject private var visibilityService = MetricVisibilityService.shared
    
    private var viewBackground: Color {
        Color.appBackground
    }
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    // State for drag operation
    @State private var draggedItem: GoalMetric.MetricType?
    
    // Track which metrics are in the daily goals card (filtered by visibility)
    private var selectedMetrics: [GoalMetric.MetricType] {
        let filtered = metricsManager.metrics.filter { $0.isSelected }
        return filtered.map { $0.type }.filter { metricType in
            switch metricType {
            case .protein:
                return visibilityService.showProtein
            case .calories, .caloriesRemaining:
                return visibilityService.showCalories
            case .carbs:
                return visibilityService.showCarbs
            case .fat:
                return visibilityService.showFat
            case .fibre:
                return true // Always show fibre
            case .nova4:
                return visibilityService.showNovaScore
            case .steps, .activityCalories:
                return true // Always show non-nutrition metrics
            // case .sleep:
            //     return true // Always show non-nutrition metrics
            }
        }
    }
    
    private var availableMetrics: [GoalMetric] {
        return metricsManager.metrics.filter { metric in
            switch metric.type {
            case .protein:
                return visibilityService.showProtein
            case .calories, .caloriesRemaining:
                return visibilityService.showCalories
            case .carbs:
                return visibilityService.showCarbs
            case .fat:
                return visibilityService.showFat
            case .fibre:
                return true // Always show fibre
            case .nova4:
                return visibilityService.showNovaScore
            case .steps, .activityCalories:
                return true // Always show non-nutrition metrics
            // case .sleep:
            //     return true // Always show non-nutrition metrics
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Daily Goals preview section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Daily Goals")
                                .font(.custom("Montserrat-SemiBold", size: 17))
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Preview of selected metrics (up to 4)
                        HStack(spacing: 0) {
                            Spacer()
                            
                            ForEach(selectedMetrics.prefix(4), id: \.self) { metricType in
                                settingsMetricPreview(for: metricType)
                                
                                if metricType != selectedMetrics.prefix(4).last {
                                    Spacer()
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.bottom, 8)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBackground)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                    )
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .onDrop(of: [.text], isTargeted: nil) { providers in
                        // Handle dropping from library to daily goals
                        if let first = providers.first {
                            let _ = first.loadObject(ofClass: NSString.self) { draggedValue, _ in
                                if let value = draggedValue as? String,
                                   let draggedType = GoalMetric.MetricType(rawValue: value),
                                   !selectedMetrics.contains(draggedType) && selectedMetrics.count < 4 {
                                    withAnimation(.spring()) {
                                        metricsManager.addMetricToEndWithoutSaving(metricType: draggedType)
                                    }
                                }
                            }
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
                            // Use filtered metrics based on visibility preferences
                            ForEach(availableMetrics) { metric in
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
                                        handleLibraryDrop(providers: providers, targetType: metricType)
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
                    .background(viewBackground)
                }
            }
            .background(viewBackground)
            .navigationTitle("Daily Goals Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Save metrics before dismissing
                        metricsManager.saveMetrics()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
}

// Card for displaying a metric in the grid
struct MetricCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let metricType: GoalMetric.MetricType
    let isSelected: Bool
    @State private var isDragging = false
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
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
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .offset(x: 20, y: 20)
                }
            }
            
            Text(metricType.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(minWidth: 100, minHeight: 100)
        .background(cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.spring(), value: isDragging)
        .onLongPressGesture(minimumDuration: 0.1) {
            isDragging = true
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
            return "75"
        case .steps:
            return "8,234"
        case .activityCalories:
            return "340"
        case .nova4:
            return "15%"
        case .calories:
            return "1,650"
        case .caloriesRemaining:
            return "450"
        case .carbs:
            return "120g"
        case .fat:
            return "45g"
        case .fibre:
            return "18g"
        // case .water: // TEMPORARILY DISABLED
        //     return "1.2L"
        // case .sleep: // TEMPORARILY DISABLED
        //     return "7.5h"
        }
    }
    
    private var goal: String {
        switch metricType {
        case .protein:
            return "/150g"
        case .steps:
            return "/10,000"
        case .activityCalories:
            return "/500"
        case .nova4:
            return "/20%"
        case .calories:
            return "/2,100"
        case .caloriesRemaining:
            return "remaining"
        case .carbs:
            return "/250g"
        case .fat:
            return "/65g"
        case .fibre:
            return "/30g"
        // case .water: // TEMPORARILY DISABLED
        //     return "/2L"
        // case .sleep: // TEMPORARILY DISABLED
        //     return "/8h"
        }
    }
    
    var body: some View {
        VStack {
            ZStack {
                // Background circle
                Circle()
                    .stroke(lineWidth: 6)
                    .foregroundColor(Color.appInsetBackground)
                
                // Progress circle - using 0.7 as a sample progress value for preview
                Circle()
                    .trim(from: 0.0, to: 0.7)
                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    .foregroundColor(colorForMetricType(metricType))
                    .rotationEffect(Angle(degrees: 270.0))
                
                // Value and goal text
                VStack(spacing: 0) {
                    Text(value)
                        .font(.custom("Montserrat-SemiBold", size: 14))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(goal)
                        .font(.custom("Montserrat-SemiBold", size: 10))
                        .foregroundColor(.gray)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
            .frame(width: 65, height: 65)
            
            Text(metricType.rawValue)
                .font(.custom("Montserrat-SemiBold", size: 14))
                .padding(.top, 4)
        }
        .frame(height: 95)
    }
}

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
        case .activityCalories:
            return activityCaloriesProgress
        case .nova4:
            return nova4Progress
        case .calories:
            return caloriesGoal > 0 ? Double(caloriesConsumed) / Double(caloriesGoal) : 0
        case .caloriesRemaining:
            return caloriesGoal > 0 ? min(Double(caloriesConsumed) / Double(caloriesGoal), 1.0) : 0
        case .carbs:
            return carbsGoal > 0 ? Double(carbsConsumed) / Double(carbsGoal) : 0
        case .fat:
            return fatGoal > 0 ? Double(fatConsumed) / Double(fatGoal) : 0
        case .fibre:
            return fibreGoal > 0 ? Double(fibreConsumed) / Double(fibreGoal) : 0
        // case .water: // TEMPORARILY DISABLED
        //     return 0.6 // Placeholder
        // case .sleep: // TEMPORARILY DISABLED
        //     return 0.8 // Placeholder
        }
    }
    
    // Get color for a given metric
    func colorForMetric(_ metric: GoalMetric) -> Color {
        switch metric.type {
        case .protein:
            return Color(red: 0.2, green: 0.8, blue: 0.2) // Brighter green
        case .steps:
            return Color(red: 0.0, green: 0.5, blue: 1.0) // Bright blue
        case .activityCalories:
            return Color(red: 1.0, green: 0.3, blue: 0.0) // Bright orange-red
        case .nova4:
            return Color(red: 1.0, green: 0.6, blue: 0.0) // Bright orange
        case .calories:
            return Color(red: 0.6, green: 0.2, blue: 0.8) // Vibrant purple
        case .caloriesRemaining:
            return Color(red: 0.6, green: 0.2, blue: 0.8) // Vibrant purple
        case .carbs:
            return Color(red: 1.0, green: 0.8, blue: 0.0) // Bright yellow
        case .fat:
            return Color(red: 1.0, green: 0.4, blue: 0.6) // Bright pink
        case .fibre:
            return Color(red: 0.4, green: 0.8, blue: 0.4) // Light green
        // case .water: // TEMPORARILY DISABLED
        //     return Color(red: 0.0, green: 0.8, blue: 1.0) // Bright cyan
        // case .sleep: // TEMPORARILY DISABLED
        //     return Color(red: 0.4, green: 0.2, blue: 0.8) // Bright indigo
        }
    }
    
    // Get value text for a given metric
    func valueTextForMetric(_ metric: GoalMetric) -> String {
        switch metric.type {
        case .protein:
            return "\(proteinConsumed)"
        case .steps:
            return stepsForSelectedDate.formattedWithCommas
        case .activityCalories:
            return "\(activityCaloriesForSelectedDate)"
        case .nova4:
            return "\(Int(nova4Percentage))%"
        case .calories:
            return "\(caloriesConsumed)"
        case .caloriesRemaining:
            let remaining = caloriesGoal - caloriesConsumed
            return remaining >= 0 ? "\(remaining)" : "-\(abs(remaining))"
        case .carbs:
            return "\(carbsConsumed)g"
        case .fat:
            return "\(fatConsumed)g"
        case .fibre:
            return "\(fibreConsumed)g"
        // case .water: // TEMPORARILY DISABLED
        //     return "1.2L" // Placeholder
        // case .sleep: // TEMPORARILY DISABLED
        //     return "7.5h" // Placeholder
        }
    }
    
    // Get goal text for a given metric
    func goalTextForMetric(_ metric: GoalMetric) -> String {
        switch metric.type {
        case .protein:
            return "/\(proteinGoal)g"
        case .steps:
            return "/\(stepsGoal.formattedWithCommas)"
        case .activityCalories:
            return "/\(activityCaloriesGoal)"
        case .nova4:
            return "/\(Int(nova4Goal))%"
        case .calories:
            return "/\(caloriesGoal)"
        case .caloriesRemaining:
            return "remaining"
        case .carbs:
            return "/\(carbsGoal)g"
        case .fat:
            return "/\(fatGoal)g"
        case .fibre:
            return "/\(fibreGoal)g"
        // case .water: // TEMPORARILY DISABLED
        //     return "/2L"
        // case .sleep: // TEMPORARILY DISABLED
        //     return "/8h"
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
    case .activityCalories:
        return Color(red: 1.0, green: 0.3, blue: 0.0) // Bright orange-red
    case .nova4:
        return Color(red: 1.0, green: 0.6, blue: 0.0) // Bright orange
    case .calories:
        return Color(red: 0.6, green: 0.2, blue: 0.8) // Vibrant purple
    case .caloriesRemaining:
        return Color(red: 0.6, green: 0.2, blue: 0.8) // Vibrant purple (same as calories)
    case .carbs:
        return Color(red: 1.0, green: 0.8, blue: 0.0) // Bright yellow
    case .fat:
        return Color(red: 1.0, green: 0.4, blue: 0.6) // Bright pink
    case .fibre:
        return Color(red: 0.4, green: 0.8, blue: 0.4) // Light green
    // case .water: // TEMPORARILY DISABLED
    //     return Color(red: 0.0, green: 0.8, blue: 1.0) // Bright cyan
    // case .sleep: // TEMPORARILY DISABLED
    //     return Color(red: 0.4, green: 0.2, blue: 0.8) // Bright indigo
    }
}

func iconForMetricType(_ type: GoalMetric.MetricType) -> String {
    switch type {
    case .protein:
        return "figure.strengthtraining.traditional"
    case .steps:
        return "figure.walk"
    case .activityCalories:
        return "bolt.fill"
    case .nova4:
        return "chart.pie"
    case .calories:
        return "flame"
    case .caloriesRemaining:
        return "flame.fill"
    case .carbs:
        return "c.circle"
    case .fat:
        return "f.circle"
    case .fibre:
        return "leaf.fill"
    // case .water: // TEMPORARILY DISABLED
    //     return "drop"
    // case .sleep: // TEMPORARILY DISABLED
    //     return "bed.double"
    }
}

// Extension for DailyGoalsSettingsView helper functions
extension DailyGoalsSettingsView {
    // Helper functions for settings view
    private func calculateProgress(for metric: GoalMetric) -> Double {
        switch metric.type {
        case .nova4:
            return 0.15 // Sample 15%
        case .steps:
            return 0.32 // Sample 32%
        case .activityCalories:
            return 0.68 // Sample 68%
        case .protein:
            return 0.75 // Sample 75%
        case .calories:
            return 0.65 // Sample 65%
        case .caloriesRemaining:
            return 0.65 // Sample 65% (inverted to show calories consumed)
        case .fat:
            return 0.45 // Sample 45%
        case .carbs:
            return 0.55 // Sample 55%
        case .fibre:
            return 0.60 // Sample 60%
        // case .water: // TEMPORARILY DISABLED
        //     return 0.25 // Sample 25%
        // case .sleep: // TEMPORARILY DISABLED
        //     return 0.85 // Sample 85%
        }
    }
    
    private func getMetricColor(for metric: GoalMetric) -> Color {
        switch metric.type {
        case .nova4:
            return Color.orange
        case .steps:
            return Color.blue
        case .activityCalories:
            return Color(red: 1.0, green: 0.3, blue: 0.0)
        case .protein:
            return Color.green
        case .calories:
            return Color.purple
        case .caloriesRemaining:
            return Color.purple
        case .fat:
            return Color.pink
        case .carbs:
            return Color.yellow
        case .fibre:
            return Color(red: 0.4, green: 0.8, blue: 0.4)
        // case .water: // TEMPORARILY DISABLED
        //     return Color.cyan
        // case .sleep: // TEMPORARILY DISABLED
        //     return Color.indigo
        }
    }
    
    private func getMetricValue(for metric: GoalMetric) -> String {
        switch metric.type {
        case .nova4:
            return "15%"
        case .steps:
            return "3,234"
        case .activityCalories:
            return "340"
        case .protein:
            return "75"
        case .calories:
            return "1,650"
        case .caloriesRemaining:
            return "450"
        case .fat:
            return "45"
        case .carbs:
            return "120"
        case .fibre:
            return "18"
        // case .water: // TEMPORARILY DISABLED
        //     return "500"
        // case .sleep: // TEMPORARILY DISABLED
        //     return "7"
        }
    }
    
    private func getMetricGoal(for metric: GoalMetric) -> String {
        switch metric.type {
        case .nova4:
            return "/20%"
        case .steps:
            return "/\(metric.goal)"
        case .activityCalories:
            return "/\(metric.goal)"
        case .protein:
            return "/\(metric.goal)g"
        case .calories:
            return "/\(metric.goal)"
        case .caloriesRemaining:
            return "remaining"
        case .fat:
            return "/\(metric.goal)g"
        case .carbs:
            return "/\(metric.goal)g"
        case .fibre:
            return "/\(metric.goal)g"
        // case .water: // TEMPORARILY DISABLED
        //     return "/\(metric.goal)ml"
        // case .sleep: // TEMPORARILY DISABLED
        //     return "/\(metric.goal)h"
        }
    }
    
    private func handleSettingsDrop(providers: [NSItemProvider], targetType: GoalMetric.MetricType) {
        guard let draggedItem = self.draggedItem else { return }
        
        guard let draggedIndex = metricsManager.metrics.firstIndex(where: { $0.type == draggedItem }),
              let targetIndex = metricsManager.metrics.firstIndex(where: { $0.type == targetType }) else { return }
        
        if draggedIndex != targetIndex {
            withAnimation(.spring()) {
                let draggedMetric = metricsManager.metrics.remove(at: draggedIndex)
                metricsManager.metrics.insert(draggedMetric, at: targetIndex)
                metricsManager.saveMetrics()
            }
        }
        
        self.draggedItem = nil
    }
    
    private func handleLibraryDrop(providers: [NSItemProvider], targetType: GoalMetric.MetricType) {
        // Handle dropping from library to daily goals or reordering within library
        guard let draggedItem = self.draggedItem else { return }
        
        if let draggedIndex = metricsManager.metrics.firstIndex(where: { $0.type == draggedItem }),
           let targetIndex = metricsManager.metrics.firstIndex(where: { $0.type == targetType }) {
            
            if draggedIndex != targetIndex {
                withAnimation(.spring()) {
                    let draggedMetric = metricsManager.metrics.remove(at: draggedIndex)
                    metricsManager.metrics.insert(draggedMetric, at: targetIndex)
                    metricsManager.saveMetrics()
                }
            }
        }
        
        self.draggedItem = nil
    }
    
    // Extracted view builder to fix type-check timeout
    @ViewBuilder
    private func settingsMetricPreview(for metricType: GoalMetric.MetricType) -> some View {
        let isDragging = draggedItem == metricType
        
        if let metric = metricsManager.metrics.first(where: { $0.type == metricType }) {
            let progress = calculateProgress(for: metric)
            let metricColor = getMetricColor(for: metric)
            let valueText = getMetricValue(for: metric)
            let goalText = getMetricGoal(for: metric)
            
            VStack {
                ZStack {
                    Circle()
                        .stroke(lineWidth: 6)
                        .opacity(0.2)
                        .foregroundColor(Color.gray)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                        .foregroundColor(metricColor)
                        .rotationEffect(Angle(degrees: 270.0))
                    
                    VStack(spacing: 0) {
                        Text(valueText)
                            .font(.custom("Montserrat-SemiBold", size: 14))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(goalText)
                            .font(.custom("Montserrat-SemiBold", size: 10))
                            .foregroundColor(.gray)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                }
                .frame(width: 65, height: 65)
                
                Text(metricType == .caloriesRemaining ? "Calories" : metricType.rawValue)
                    .font(.custom("Montserrat-SemiBold", size: 14))
                    .padding(.top, 4)
            }
            .frame(width: 80) // Fixed width to ensure consistent sizing across all metrics
            .opacity(isDragging ? 0.4 : 1.0)
            .overlay(
                Circle()
                    .fill(Color.red)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: -25, y: -25)
            )
            .onDrag {
                self.draggedItem = metricType
                return NSItemProvider(object: metricType.rawValue as NSString)
            }
            .onDrop(of: [.text], isTargeted: nil) { providers in
                handleSettingsDrop(providers: providers, targetType: metricType)
                return true
            }
            .onTapGesture {
                withAnimation(.spring()) {
                    if let index = metricsManager.metrics.firstIndex(where: { $0.type == metricType }) {
                        metricsManager.metrics[index].isSelected = false
                    }
                }
            }
        }
    }
}

// Goals Settings Card Component
struct GoalsSettingsCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var sleepGoalHours: Double = 8.0
    @State private var novaGoalPercentage: Double = 20.0
    @State private var stepsGoal: Int = 10000
    @State private var activityCaloriesGoal: Int = 500
    @State private var waterGoalLiters: Double = 2.5
    @ObservedObject private var userProfile = UserProfile.shared
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Goal Settings")
                .font(.custom("Montserrat-SemiBold", size: 17))
                .padding(.horizontal)
                .padding(.top, 8)
            
            VStack(spacing: 20) {
                // Sleep Goal
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bed.double")
                            .foregroundColor(.indigo)
                            .frame(width: 24)
                        Text("Sleep Goal")
                            .font(.body)
                        Spacer()
                        Text("\(sleepGoalHours, specifier: "%.1f") hours")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $sleepGoalHours, in: 6...10, step: 0.5) {
                        Text("Sleep Goal")
                    }
                    .accentColor(.indigo)
                }
                
                // NOVA Score Goal
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "chart.pie")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        Text("NOVA 4 Limit")
                            .font(.body)
                        Spacer()
                        Text("\(novaGoalPercentage, specifier: "%.0f")%")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $novaGoalPercentage, in: 5...30, step: 5) {
                        Text("NOVA 4 Goal")
                    }
                    .accentColor(.orange)
                    
                    Text("Maximum percentage of calories from ultra-processed foods")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Steps Goal
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "figure.walk")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Steps Goal")
                            .font(.body)
                        Spacer()
                        Text("\(stepsGoal) steps")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(stepsGoal) },
                        set: { stepsGoal = Int($0) }
                    ), in: 5000...20000, step: 1000) {
                        Text("Steps Goal")
                    }
                    .accentColor(.blue)
                }
                
                // Activity Calories Goal
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(Color(red: 1.0, green: 0.3, blue: 0.0))
                            .frame(width: 24)
                        Text("Activity Calories Goal")
                            .font(.body)
                        Spacer()
                        Text("\(activityCaloriesGoal) cal")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(activityCaloriesGoal) },
                        set: { activityCaloriesGoal = Int($0) }
                    ), in: 200...1000, step: 50) {
                        Text("Activity Calories Goal")
                    }
                    .accentColor(Color(red: 1.0, green: 0.3, blue: 0.0))
                }
                
                // Water Goal
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "drop")
                            .foregroundColor(.cyan)
                            .frame(width: 24)
                        Text("Water Goal")
                            .font(.body)
                        Spacer()
                        Text("\(waterGoalLiters, specifier: "%.1f") liters")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $waterGoalLiters, in: 1.5...4.0, step: 0.1) {
                        Text("Water Goal")
                    }
                    .accentColor(.cyan)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .onAppear {
            loadGoals()
        }
        .onChange(of: sleepGoalHours) { saveGoals() }
        .onChange(of: novaGoalPercentage) { saveGoals() }
        .onChange(of: stepsGoal) { saveGoals() }
        .onChange(of: waterGoalLiters) { saveGoals() }
    }
    
    private func loadGoals() {
        // Load from UserDefaults
        sleepGoalHours = UserDefaults.standard.double(forKey: "sleepGoalHours")
        if sleepGoalHours == 0 { sleepGoalHours = 8.0 }
        
        novaGoalPercentage = UserDefaults.standard.double(forKey: "novaGoalPercentage")
        if novaGoalPercentage == 0 { novaGoalPercentage = 20.0 }
        
        stepsGoal = UserDefaults.standard.integer(forKey: "stepsGoal")
        if stepsGoal == 0 { stepsGoal = 10000 }
        
        activityCaloriesGoal = UserDefaults.standard.integer(forKey: "activityCaloriesGoal")
        if activityCaloriesGoal == 0 { activityCaloriesGoal = 500 }
        
        // waterGoalLiters = userProfile.waterGoalLiters // TEMPORARILY DISABLED
    }
    
    private func saveGoals() {
        // Save to UserDefaults
        UserDefaults.standard.set(sleepGoalHours, forKey: "sleepGoalHours")
        UserDefaults.standard.set(novaGoalPercentage, forKey: "novaGoalPercentage")
        UserDefaults.standard.set(stepsGoal, forKey: "stepsGoal")
        UserDefaults.standard.set(activityCaloriesGoal, forKey: "activityCaloriesGoal")
        
        // Update water goal in user profile
        // userProfile.userProfile.waterGoalLiters = waterGoalLiters // TEMPORARILY DISABLED
        
        // Post notification that goals have been updated
        NotificationCenter.default.post(name: .metricGoalsUpdated, object: nil)
    }
}

// Notification extension
extension Notification.Name {
    static let metricGoalsUpdated = Notification.Name("metricGoalsUpdated")
}

#Preview {
    VStack {
        DailyGoalsCard(
            proteinConsumed: 75,
            proteinGoal: 150,
            nova4Percentage: 15,
            nova4Goal: 20
        )
        .padding()
        .background(Color(.systemGray6))
    }
}
