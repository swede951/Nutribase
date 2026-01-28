//
//  FoodLogView.swift
//  nutribase
//
//  Created on 03/06/2025.
//

import SwiftUI
import Combine

// Preference key to track scroll position
struct ScrollViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


// Wrapper to prevent complex calculations during drag operations
struct DailyGoalsCardWrapper: View {
    let proteinConsumed: Int
    let carbsConsumed: Int
    let fatConsumed: Int
    let nova4Percentage: Double
    let nova4Goal: Double
    let caloriesConsumed: Int // Use actual calories from food items
    let selectedDate: Date // Date for which to show data
    
    @ObservedObject private var userProfile = UserProfile.shared
    
    // Pre-calculate values to avoid complex expressions during drag
    private var proteinGoal: Int {
        userProfile.proteinGoalGrams > 0 ? userProfile.proteinGoalGrams : 50
    }
    
    private var caloriesGoal: Int {
        userProfile.dailyCalorieGoal > 0 ? userProfile.dailyCalorieGoal : 2000
    }
    
    private var carbsGoal: Int {
        userProfile.carbGoalGrams > 0 ? userProfile.carbGoalGrams : 300
    }
    
    private var fatGoal: Int {
        userProfile.fatGoalGrams > 0 ? userProfile.fatGoalGrams : 65
    }
    
    var body: some View {
        DailyGoalsCard(
            proteinConsumed: proteinConsumed,
            proteinGoal: proteinGoal,
            selectedDate: selectedDate,
            nova4Percentage: nova4Percentage,
            nova4Goal: nova4Goal,
            caloriesConsumed: caloriesConsumed,
            caloriesGoal: caloriesGoal,
            carbsConsumed: carbsConsumed,
            carbsGoal: carbsGoal,
            fatConsumed: fatConsumed,
            fatGoal: fatGoal
        )
    }
}

// Scroll direction enum
enum ScrollDirection {
    case up, down, none
}

struct FoodLogView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var visibilityService = MetricVisibilityService.shared
    
    private var viewBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    // Date formatter for the header
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d/M/yyyy"
        return formatter
    }
    
    // Helper function to check if a date is today
    private func isToday(date: Date) -> Bool {
        return Calendar.current.isDateInToday(date)
    }
    
    // Helper function to check if a date is yesterday
    private func isYesterday(date: Date) -> Bool {
        return Calendar.current.isDateInYesterday(date)
    }
    
    // Helper function to check if a date is tomorrow
    private func isTomorrow(date: Date) -> Bool {
        return Calendar.current.isDateInTomorrow(date)
    }
    
    // Helper function to get the appropriate date display text
    private func getDateDisplayText(for date: Date) -> String {
        if isToday(date: date) {
            return "Today"
        } else if isYesterday(date: date) {
            return "Yesterday"
        } else if isTomorrow(date: date) {
            return "Tomorrow"
        } else {
            return dateFormatter.string(from: date)
        }
    }
    // Keys for UserDefaults storage (user-specific)
    private var visibleMealsKey: String {
        if let userId = FirebaseAuthService.shared.currentUser?.id {
            return "foodLogVisibleMeals_\(userId)"
        } else if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
            return "foodLogVisibleMeals_\(localUserId)"
        }
        return "foodLogVisibleMeals_default"
    }
    
    private var hiddenMealsKey: String {
        if let userId = FirebaseAuthService.shared.currentUser?.id {
            return "foodLogHiddenMeals_\(userId)"
        } else if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
            return "foodLogHiddenMeals_\(localUserId)"
        }
        return "foodLogHiddenMeals_default"
    }
    
    // Weekly overview state
    @State private var weeklyOverviewHeight: CGFloat = 0
    @State private var weeklyOverviewVisible: Bool = false
    @State private var dragOffset: CGFloat = 0
    private let weeklyOverviewFullHeight: CGFloat = 100
    
    // Initialize with the current date
    @State private var selectedDate = Date() {
        didSet {
            // Update metrics whenever the date changes
            updateMetrics()
            // Load completion status for the new date
            loadDayCompletionStatus()
        }
    }
    
    // Store the last app open date to check if we need to reset to today
    @AppStorage("lastFoodLogOpenDate") private var lastOpenDate: Double = Date().timeIntervalSince1970
    
    // Observe the food log manager
    @StateObject private var foodLogManager = FoodLogManager.shared
    
    // Observe the activity manager for steps data
    @ObservedObject private var activityManager = ActivityManager.shared
    
    // Observe the user profile for nutrition goals
    @ObservedObject private var userProfile = UserProfile.shared
    
    // Observe the metrics manager for goal metrics order
    @ObservedObject private var metricsManager = GoalMetricsManager.shared
    
    // Refresh trigger
    @State private var refreshID = UUID()
    
    // Health metrics
    @State private var proteinConsumed: Int = 0
    @State private var carbsConsumed: Int = 0
    @State private var fatConsumed: Int = 0
    // Steps are now handled directly by ActivityManager and HealthKitManager
    @State private var stepsGoal: Int = 10000
    @State private var stepsForSelectedDate: Int = 0
    @State private var activityCaloriesForSelectedDate: Int = 0
    @State private var nova4Percentage: Double = 0
    @State private var nova4Goal: Double = 20
    
    // State for meal card customization
    @State private var visibleMeals: [MealType] = []
    @State private var hiddenMeals: [MealType] = []
    @State private var showingMealStorage = false
    
    // State for scroll detection
    @State private var scrollOffset: CGFloat = 0
    @State private var previousScrollOffset: CGFloat = 0
    @State private var scrollDirection: ScrollDirection = .none
    @State private var scrollDragActive: Bool = false
    @State private var isEditing = false
    
    // Sticky header state
    @State private var showStickyMetrics = false
    @State private var showStickyCaloriesRemaining = false
    @State private var dailyGoalsVisible = true
    
    // Day completion tracking
    @State private var isDayCompleted = false
    
    // Track if view has appeared to avoid redundant work
    @State private var hasAppearedOnce = false
    
    // Detail view state
    @State private var showingCaloriesDetailView = false
    
    // Meal data structure
    struct Meal: Identifiable {
        let id = UUID()
        let name: String
        var entries: [FoodEntry] = []
        
        var totalCalories: Int {
            entries.reduce(0) { $0 + $1.totalCalories }
        }
    }
    
    // Default meal order with Calories Summary and Daily Goals first
    private let defaultMealOrder: [MealType] = [
        .caloriesSummary,
        .dailyGoals,
        .breakfast,
        .lunch,
        .dinner,
        .snacks
    ]
    
    // Initialize with saved meal visibility or default (all visible)
    init() {
        // Load saved visible meals from UserDefaults
        if let savedVisibleMealsData = UserDefaults.standard.data(forKey: visibleMealsKey),
           let decodedVisibleMeals = try? JSONDecoder().decode([MealType].self, from: savedVisibleMealsData) {
            _visibleMeals = State(initialValue: decodedVisibleMeals)
        } else {
            // Default all meals visible if nothing is saved
            _visibleMeals = State(initialValue: defaultMealOrder)
        }
        
        // Load saved hidden meals from UserDefaults
        if let savedHiddenMealsData = UserDefaults.standard.data(forKey: hiddenMealsKey),
           let decodedHiddenMeals = try? JSONDecoder().decode([MealType].self, from: savedHiddenMealsData) {
            _hiddenMeals = State(initialValue: decodedHiddenMeals)
        } else {
            // Default empty hidden meals array if nothing is saved
            _hiddenMeals = State(initialValue: [])
        }
    }
    
    // Computed meals based on selected date (only visible meal type cards)
    private var meals: [Meal] {
        // Filter to only include actual meal types (breakfast, lunch, dinner, snacks)
        // and exclude summary cards (calories, daily goals)
        visibleMeals.filter { mealType in
            return mealType == .breakfast || mealType == .lunch ||
            mealType == .dinner || mealType == .snacks
        }.map { mealType in
            let entries = foodLogManager.entries(for: selectedDate, mealType: mealType.rawValue)
            return Meal(name: mealType.rawValue, entries: entries)
        }
    }
    
    // Save visible meals to UserDefaults
    private func saveVisibleMeals() {
        if let encodedData = try? JSONEncoder().encode(visibleMeals) {
            UserDefaults.standard.set(encodedData, forKey: visibleMealsKey)
        }
    }
    
    // Save hidden meals to UserDefaults
    private func saveHiddenMeals() {
        if let encodedData = try? JSONEncoder().encode(hiddenMeals) {
            UserDefaults.standard.set(encodedData, forKey: hiddenMealsKey)
        }
    }
    
    // Calculate total calories consumed for the day
    private func totalCaloriesForDay() -> Int {
        return meals.reduce(0) { $0 + $1.totalCalories }
    }
    
    // Helper functions for day completion tracking
    private func completedDaysKey() -> String {
        return "completedFoodLogDays"
    }
    
    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func loadDayCompletionStatus() {
        let key = completedDaysKey()
        let completedDays = UserDefaults.standard.stringArray(forKey: key) ?? []
        let currentDateKey = dateKey(for: selectedDate)
        isDayCompleted = completedDays.contains(currentDateKey)
    }
    
    private func saveDayCompletionStatus() {
        let key = completedDaysKey()
        var completedDays = UserDefaults.standard.stringArray(forKey: key) ?? []
        let currentDateKey = dateKey(for: selectedDate)
        
        if isDayCompleted {
            if !completedDays.contains(currentDateKey) {
                completedDays.append(currentDateKey)
            }
        } else {
            completedDays.removeAll { $0 == currentDateKey }
        }
        
        UserDefaults.standard.set(completedDays, forKey: key)
        
        // Clear phase cache to force recalculation with new completion data
        NotificationCenter.default.post(name: Notification.Name("clearAllPhaseCache"), object: nil)
    }
    
    // Check if a specific date is marked as completed
    func isDayCompleted(for date: Date) -> Bool {
        let key = completedDaysKey()
        let completedDays = UserDefaults.standard.stringArray(forKey: key) ?? []
        let dateKey = dateKey(for: date)
        return completedDays.contains(dateKey)
    }
    
    // Static function to get completed days for phase analytics
    static func getCompletedDays() -> [String] {
        return UserDefaults.standard.stringArray(forKey: "completedFoodLogDays") ?? []
    }
    
    // Static function to check if a date is completed (for external use)
    static func isDayCompleted(for date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: date)
        let completedDays = getCompletedDays()
        return completedDays.contains(dateKey)
    }
    
    // Get calories for a specific date only if the day is marked as completed
    static func getCaloriesForCompletedDay(date: Date) -> Int? {
        guard isDayCompleted(for: date) else { return nil }
        
        // Get entries for the date
        let foodLogManager = FoodLogManager.shared
        let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snacks"]
        
        var totalCalories = 0
        for mealType in mealTypes {
            let entries = foodLogManager.entries(for: date, mealType: mealType)
            totalCalories += entries.reduce(0) { $0 + $1.totalCalories }
        }
        
        return totalCalories
    }
    
    // Hide a meal card
    private func hideMeal(_ mealType: MealType) {
        // Only hide if there's more than one visible meal
        guard visibleMeals.count > 1 else { return }
        
        // Remove from visible meals
        if let index = visibleMeals.firstIndex(of: mealType) {
            visibleMeals.remove(at: index)
        }
        
        // Add to hidden meals if not already there
        if !hiddenMeals.contains(mealType) {
            hiddenMeals.append(mealType)
        }
        
        // Save changes
        saveVisibleMeals()
        saveHiddenMeals()
    }
    
    // Calculate total protein consumed for the day
    private func calculateProteinForDay() -> Int {
        // Get entries specifically for the selected date
        let allEntries = meals.flatMap { $0.entries }
        
        // If no entries for the day, return 0
        if allEntries.isEmpty {
            return 0
        }
        
        // Expand meals into individual food items for accurate calculation
        let expandedItems = foodLogManager.expandedFoodItems(for: allEntries)
        let totalProtein = expandedItems.reduce(0.0) { total, item in
            return total + item.protein
        }
        return Int(totalProtein)
    }
    
    // Calculate NOVA 4 percentage for the day
    private func calculateNova4Percentage() -> Double {
        // Get entries specifically for the selected date
        let allEntries = meals.flatMap { $0.entries }
        
        // If no entries for the day, return 0
        if allEntries.isEmpty {
            return 0
        }
        
        // Expand meals into individual food items for accurate NOVA scoring
        let expandedItems = foodLogManager.expandedFoodItems(for: allEntries)
        
        // Calculate total calories and NOVA 4 calories
        var totalCalories = 0.0
        var nova4Calories = 0.0
        
        for item in expandedItems {
            totalCalories += Double(item.calories)
            
            // Get the actual or predicted NOVA score
            let novaScore: Int
            if item.novaScore > 0 {
                novaScore = item.novaScore
            } else {
                // Use predicted score by name if actual score is missing
                novaScore = NovaScoreService.shared.predictNovaScoreByName(item.name)
            }
            
            // Check if this is a NOVA 4 food (actual or predicted)
            if novaScore == 4 {
                nova4Calories += Double(item.calories)
            }
        }
        
        // Calculate percentage
        if totalCalories > 0 {
            return (nova4Calories / totalCalories) * 100.0
        } else {
            return 0
        }
    }
    
    // Reset to today's date if needed
    private func resetToTodayIfNeeded() {
        let calendar = Calendar.current
        let lastDate = Date(timeIntervalSince1970: lastOpenDate)
        
        // If the last open date is not today, reset to today
        if !calendar.isDateInToday(lastDate) {
            selectedDate = Date()
        }
    }
    
    // Update all metrics
    private func updateMetrics() {
        // Reset all values first
        proteinConsumed = 0
        carbsConsumed = 0
        fatConsumed = 0
        nova4Percentage = 0
        
        // Load NOVA 4 goal from UserDefaults (use "nova4Limit" key from settings)
        let savedGoal = UserDefaults.standard.integer(forKey: "nova4Limit")
        nova4Goal = savedGoal > 0 ? Double(savedGoal) : 20.0
        
        // Only calculate if there are meals with entries
        if !meals.flatMap({ $0.entries }).isEmpty {
            // Update protein
            proteinConsumed = calculateProteinForDay()
            
            // Update carbs and fat using FoodLogManager
            carbsConsumed = foodLogManager.totalCarbsForDay(date: selectedDate)
            fatConsumed = foodLogManager.totalFatForDay(date: selectedDate)
            
            // Update NOVA 4 percentage
            nova4Percentage = calculateNova4Percentage()
        }
        
        // Update steps and activity calories for selected date
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            // For today, use current activity values
            stepsForSelectedDate = activityManager.currentActivity.steps
            activityCaloriesForSelectedDate = HealthKitManager.shared.todayActiveCalories
        } else {
            // For other dates, fetch from HealthKit
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? selectedDate
            
            // Fetch steps for selected date
            HealthKitManager.shared.fetchStepsForDateRange(start: startOfDay, end: endOfDay) { steps, error in
                DispatchQueue.main.async {
                    self.stepsForSelectedDate = steps
                }
            }
            
            // Fetch activity calories for selected date
            HealthKitManager.shared.fetchActiveCaloriesForDateRange(start: startOfDay, end: endOfDay) { calories, error in
                DispatchQueue.main.async {
                    self.activityCaloriesForSelectedDate = calories
                }
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background color layer - matching dashboard
            viewBackground
                .ignoresSafeArea()
            VStack(spacing: 0) {
                // Custom header with date navigation
                ZStack {
                    // Center - date with navigation
                    HStack(spacing: 8) {
                        Button(action: {
                            // Go to previous day
                            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        // Date picker
                        Menu {
                            DatePicker(
                                "Select a date",
                                selection: $selectedDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                        } label: {
                            Text(getDateDisplayText(for: selectedDate))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: {
                            // Go to next day
                            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Left side - empty space (completion moved to bottom card)
                    HStack {
                        Spacer()
                    }
                    .padding(.leading, 8)
                    
                    // Right side - edit button
                    HStack {
                        Spacer()
                        
                        // Edit button
                        Button(action: {
                            withAnimation {
                                isEditing.toggle()
                            }
                        }) {
                            Image(systemName: isEditing ? "checkmark" : "slider.horizontal.3")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .padding(.trailing, 8)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .padding(.top, 1) // Reduced top padding
                .frame(maxWidth: .infinity)
                .background(viewBackground)
                
                // Sticky Calories Remaining bar - appears when scrolled past Calories Remaining card (only if it's first and calories visible)
                if showStickyCaloriesRemaining && !isEditing && visibleMeals.first == .caloriesSummary && visibilityService.showCalories {
                    let goal = userProfile.dailyCalorieGoal > 0 ? userProfile.dailyCalorieGoal : 2000
                    let consumed = totalCaloriesForDay()
                    let activityCalories = activityCaloriesForSelectedDate
                    let includeActivity = UserDefaults.standard.bool(forKey: "includeActivityCaloriesInGoal")
                    let adjustedGoal = includeActivity ? goal + activityCalories : goal
                    let remaining = max(adjustedGoal - consumed, 0)
                    let progress = min(CGFloat(consumed) / CGFloat(adjustedGoal), 1.0)
                    let progressColor: Color = {
                        if progress > 1.0 {
                            return .red
                        } else if progress > 0.9 {
                            return .orange
                        } else {
                            return .blue
                        }
                    }()
                    
                    HStack(spacing: 0) {
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text("\(goal)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Goal")
                                .font(.custom("Montserrat-SemiBold", size: 12))
                                .foregroundColor(.gray)
                                .offset(y: 18)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text("-")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text(" ")
                                .font(.custom("Montserrat-SemiBold", size: 12))
                                .foregroundColor(.clear)
                                .offset(y: 18)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text("\(consumed)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Consumed")
                                .font(.custom("Montserrat-SemiBold", size: 12))
                                .foregroundColor(.gray)
                                .offset(y: 18)
                        }
                        
                        Spacer()
                        
                        // Show activity calories if enabled
                        if includeActivity {
                            VStack(spacing: 4) {
                                Text("+")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text(" ")
                                    .font(.custom("Montserrat-SemiBold", size: 12))
                                    .foregroundColor(.clear)
                                    .offset(y: 18)
                            }
                            
                            Spacer()
                            
                            VStack(spacing: 4) {
                                Text("\(activityCalories)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Activity")
                                    .font(.custom("Montserrat-SemiBold", size: 12))
                                    .foregroundColor(.gray)
                                    .offset(y: 18)
                            }
                            
                            Spacer()
                        }
                        
                        VStack(spacing: 4) {
                            Text("=")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text(" ")
                                .font(.custom("Montserrat-SemiBold", size: 12))
                                .foregroundColor(.clear)
                                .offset(y: 18)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .stroke(progressColor.opacity(0.2), lineWidth: 4)
                                    .frame(width: 50, height: 50)
                                Circle()
                                    .trim(from: 0, to: 1 - progress)
                                    .stroke(progressColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .frame(width: 50, height: 50)
                                    .rotationEffect(.degrees(-90))
                                
                                Text("\(remaining)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            
                            Text("Remaining")
                                .font(.custom("Montserrat-SemiBold", size: 12))
                                .foregroundColor(.gray)
                                .fixedSize()
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Sticky metrics bar - appears when scrolled past Daily Goals (only if it's first)
                if showStickyMetrics && !isEditing && visibleMeals.first == .dailyGoals {
                    HStack(spacing: 20) {
                        // Dynamically show metrics based on user's Daily Goals selection
                        ForEach(metricsManager.selectedMetrics.prefix(4)) { metric in
                            stickyMetricView(for: metric.type)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(Color(.systemGray6))
            .zIndex(3)
                
                // Weekly overview (hidden completely)
                // WeeklyOverviewView(currentDate: Date(), selectedDate: $selectedDate)
                //     .frame(height: weeklyOverviewHeight)
                //     .opacity(weeklyOverviewHeight > 0 ? 1 : 0)
                //     .zIndex(2)
                
                // Meal cards with scroll-to-reveal functionality
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        // Add spacer to account for overlaying header
                        Color.clear
                            .frame(height:18) // Approximate header height
                        // Use indices for ForEach to support drag and drop
                        ForEach(visibleMeals.indices, id: \.self) { index in
                            let mealType = visibleMeals[index]
                            
                            Group {
                                switch mealType {
                                case .caloriesSummary:
                                    // Only show Calories Remaining card if calories are visible
                                    if visibilityService.showCalories {
                                        CalorieSummaryCard(
                                        consumedCalories: totalCaloriesForDay(),
                                        targetCalories: userProfile.dailyCalorieGoal > 0 ? userProfile.dailyCalorieGoal : 2000,
                                        activityCalories: activityCaloriesForSelectedDate,
                                        onCardTap: { showingCaloriesDetailView = true }
                                    )
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear
                                                .onChange(of: geo.frame(in: .global).maxY) { oldValue, newValue in
                                                    let threshold: CGFloat = 100
                                                    let shouldShowSticky = newValue < threshold
                                                    
                                                    if showStickyCaloriesRemaining != shouldShowSticky {
                                                        withAnimation(.easeInOut(duration: 0.2)) {
                                                            showStickyCaloriesRemaining = shouldShowSticky
                                                        }
                                                    }
                                                }
                                        }
                                    )
                                    .overlay(
                                        isEditing ?
                                        VStack {
                                            HStack {
                                                Button(action: {
                                                    hideMeal(mealType)
                                                }) {
                                                    Image(systemName: "minus.circle.fill")
                                                        .font(.title2)
                                                        .foregroundColor(Color.red.opacity(0.9))
                                                        .background(Circle().fill(cardBackground))
                                                }
                                                .opacity(0.7)
                                                Spacer()
                                            }
                                            Spacer()
                                        }
                                        .offset(x: -10, y: -10)
                                        : nil
                                    )
                                    .onLongPressGesture(minimumDuration: 1) {
                                        if !isEditing {
                                            HapticManager.shared.mediumFeedback()
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                isEditing = true
                                            }
                                        }
                                    }
                                    }
                                    
                                case .dailyGoals:
                                    DailyGoalsCardWrapper(
                                        proteinConsumed: proteinConsumed,
                                        carbsConsumed: carbsConsumed,
                                        fatConsumed: fatConsumed,
                                        nova4Percentage: nova4Percentage,
                                        nova4Goal: nova4Goal,
                                        caloriesConsumed: totalCaloriesForDay(),
                                        selectedDate: selectedDate
                                    )
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear
                                                .onChange(of: geo.frame(in: .global).maxY) { oldValue, newValue in
                                                    // Show sticky when card is mostly scrolled off (bottom edge above 100pt)
                                                    // This triggers earlier, when card is still partially visible
                                                    let threshold: CGFloat = 100
                                                    let shouldShowSticky = newValue < threshold
                                                    
                                                    if showStickyMetrics != shouldShowSticky {
                                                        withAnimation(.easeInOut(duration: 0.2)) {
                                                            showStickyMetrics = shouldShowSticky
                                                        }
                                                        print("📊 Card bottom Y: \(newValue), Threshold: \(threshold), Sticky: \(shouldShowSticky)")
                                                    }
                                                }
                                        }
                                    )
                                    .overlay(
                                        isEditing ?
                                        VStack {
                                            HStack {
                                                Button(action: {
                                                    hideMeal(mealType)
                                                }) {
                                                    Image(systemName: "minus.circle.fill")
                                                        .font(.title2)
                                                        .foregroundColor(Color.red.opacity(0.7))
                                                        .background(Circle().fill(cardBackground))
                                                }
                                                .opacity(0.7)
                                                Spacer()
                                            }
                                            Spacer()
                                        }
                                        .offset(x: -10, y: -10)
                                        : nil
                                    )
                                    .onLongPressGesture(minimumDuration: 1) {
                                        if !isEditing {
                                            HapticManager.shared.mediumFeedback()
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                isEditing = true
                                            }
                                        }
                                    }
                                    
                                case .breakfast, .lunch, .dinner, .snacks:
                                    // Find the meal data for this meal type
                                    if let meal = meals.first(where: { $0.name == mealType.rawValue }) {
                                        MealCardView(meal: meal, selectedDate: selectedDate)
                                            .overlay(
                                                isEditing ?
                                                VStack {
                                                    HStack {
                                                        Button(action: {
                                                            hideMeal(mealType)
                                                        }) {
                                                            Image(systemName: "minus.circle.fill")
                                                                .font(.title2)
                                                                .foregroundColor(Color.red.opacity(0.7))
                                                                .background(Circle().fill(cardBackground))
                                                        }
                                                        .opacity(0.7)
                                                        Spacer()
                                                    }
                                                    Spacer()
                                                }
                                                .offset(x: -10, y: -10)
                                                : nil
                                            )
                                            .onLongPressGesture(minimumDuration: 1) {
                                                if !isEditing {
                                                    HapticManager.shared.mediumFeedback()
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        isEditing = true
                                                    }
                                                }
                                            }
                                    }
                                }
                            }
                            .onDrag {
                                // Only enable drag when in edit mode
                                guard isEditing else { return NSItemProvider() }
                                MealDropDelegate.draggedIndex = index
                                return NSItemProvider(object: mealType.rawValue as NSString)
                            }
                            .onDrop(of: [.text], delegate: MealDropDelegate(item: mealType, items: $visibleMeals, current: index))
                        }
                        
                        // Add Section button appears in edit mode
                        if isEditing {
                            Button(action: {
                                showingMealStorage = true
                            }) {
                                VStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.blue)
                                    Text("Add Section")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                        .foregroundColor(.blue.opacity(0.5))
                                )
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .padding(.top, 16)
                        }
                        
                        // Day completion card at the bottom
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isDayCompleted.toggle()
                                saveDayCompletionStatus()
                            }
                        }) {
                            HStack(spacing: 16) {
                                // Text content
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(isDayCompleted ? "Day Completed" : "Mark Day as Complete")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text(isDayCompleted ? "Great job logging your food today!" : "Tap to confirm")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                                
                                // Checkmark circle
                                ZStack {
                                    Circle()
                                        .stroke(isDayCompleted ? Color.green : Color.gray.opacity(0.3), lineWidth: 3)
                                        .frame(width: 50, height: 50)
                                    
                                    if isDayCompleted {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.white)
                                    } else {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.gray.opacity(0.3))
                                    }
                                }
                            }
                            .padding(16)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(cardBackground)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                        )
                        .accessibilityLabel(isDayCompleted ? "Day marked as complete" : "Mark day as complete")
                        .accessibilityHint("Toggle to mark this day's food logging as complete for accurate phase analytics")
                        .padding(.top, 8)
                        
                        // Add extra padding at the bottom to ensure the card is fully visible
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                // Make sure the ScrollView takes all available space
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Add horizontal swipe gesture for date navigation
                .gesture(
                    DragGesture(minimumDistance: 50)
                        .onEnded { gesture in
                            // Only respond to horizontal swipes (more horizontal than vertical)
                            if abs(gesture.translation.width) > abs(gesture.translation.height) {
                                // Left swipe (negative translation) - go to next day
                                if gesture.translation.width < 0 {
                                    withAnimation {
                                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                                    }
                                }
                                // Right swipe (positive translation) - go to previous day
                                else {
                                    withAnimation {
                                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                                    }
                                }
                            }
                        }
                )
            }
            .navigationBarHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: .foodLogUpdated)) { _ in
                // Update metrics when food log changes
                updateMetrics()
            }
            .onReceive(NotificationCenter.default.publisher(for: .goalMetricsUpdated)) { _ in
                // This will force the view to refresh when goal metrics order changes
                refreshID = UUID()
            }
            // Use a standard sheet presentation to ensure proper scrolling
            .sheet(isPresented: $showingMealStorage) {
                MealStorageView(visibleMeals: $visibleMeals, hiddenMeals: $hiddenMeals, onDismiss: {})
                    .onDisappear {
                        // Save changes when view is dismissed
                        saveVisibleMeals()
                        saveHiddenMeals()
                    }
            }
            .sheet(isPresented: $showingCaloriesDetailView) {
                CaloriesDetailView(foodLogManager: foodLogManager, userProfile: userProfile)
            }
            // Animation removed - was potentially interfering with sheet presentation
            .ignoresSafeArea(edges: .bottom)
            .onChange(of: showingMealStorage) { oldValue, isShowing in
                if !isShowing {
                    // Debug print to verify card visibility state
                    print("Sheet dismissed - Visible meals: \(visibleMeals.map { $0.rawValue })")
                    print("Sheet dismissed - Hidden meals: \(hiddenMeals.map { $0.rawValue })")
                    
                    // Ensure Daily Goals card is properly handled
                    if hiddenMeals.contains(.dailyGoals) && visibleMeals.contains(.dailyGoals) {
                        // Remove duplicate if it exists in both arrays
                        if let index = hiddenMeals.firstIndex(of: .dailyGoals) {
                            hiddenMeals.remove(at: index)
                        }
                    }
                    
                    // Save meal visibility preferences when the sheet is dismissed
                    saveVisibleMeals()
                    saveHiddenMeals()
                    
                    // Force UI refresh
                    refreshID = UUID()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .nutritionGoalsUpdated)) { _ in
                // Refresh view when nutrition goals are updated
                refreshID = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SaveFoodLogLayout"))) { _ in
                // Save meal order when cards are reordered via drag and drop
                saveVisibleMeals()
                saveHiddenMeals()
            }
            .onReceive(NotificationCenter.default.publisher(for: .exitEditMode)) { _ in
                // Exit edit mode when switching tabs
                if isEditing {
                    isEditing = false
                }
            }
            .onChange(of: selectedDate) { oldValue, newValue in
                // Reset sticky metrics when date changes
                showStickyMetrics = false
                showStickyCaloriesRemaining = false
            }
            .onAppear {
                // Only do full initialization on first appear
                if !hasAppearedOnce {
                    hasAppearedOnce = true
                    // Track page view
                    AnalyticsService.shared.trackFoodLogView()
                    // Load completion status
                    loadDayCompletionStatus()
                }
                
                // Always reset to today's date when view appears
                selectedDate = Date()
                
                // Lightweight updates on every appear
                updateMetrics()
                
                // Store current date as last open date
                lastOpenDate = Date().timeIntervalSince1970
            }
            .id(refreshID)
    }
    
    // Helper function to create sticky metric view for each type
    @ViewBuilder
    private func stickyMetricView(for metricType: GoalMetric.MetricType) -> some View {
        switch metricType {
        case .nova4:
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: min(CGFloat(nova4Percentage) / CGFloat(nova4Goal > 0 ? nova4Goal : 20), 1.0))
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(Int(nova4Percentage))%")
                            .font(.system(size: 12, weight: .bold))
                        Text("/\(Int(nova4Goal))%")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Text("NOVA 4")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            
        case .protein:
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: min(CGFloat(proteinConsumed) / CGFloat(userProfile.proteinGoalGrams > 0 ? userProfile.proteinGoalGrams : 50), 1.0))
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(proteinConsumed)")
                            .font(.system(size: 12, weight: .bold))
                        Text("/\(userProfile.proteinGoalGrams > 0 ? userProfile.proteinGoalGrams : 50)g")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Text("Protein")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            
        case .calories:
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.purple.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: min(CGFloat(totalCaloriesForDay()) / CGFloat(userProfile.dailyCalorieGoal > 0 ? userProfile.dailyCalorieGoal : 2000), 1.0))
                        .stroke(Color.purple, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(totalCaloriesForDay())")
                            .font(.system(size: 12, weight: .bold))
                        Text("/\(userProfile.dailyCalorieGoal > 0 ? userProfile.dailyCalorieGoal : 2000)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Text("Calories")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            
        case .caloriesRemaining:
            VStack(spacing: 4) {
                let goal = userProfile.dailyCalorieGoal > 0 ? userProfile.dailyCalorieGoal : 2000
                let consumed = totalCaloriesForDay()
                let remaining = max(goal - consumed, 0)
                let progress = min(CGFloat(consumed) / CGFloat(goal), 1.0)
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: 1 - progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(remaining)")
                            .font(.system(size: 12, weight: .bold))
                        Text("/\(goal)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Text("Calories")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            
        case .carbs:
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: min(CGFloat(carbsConsumed) / CGFloat(userProfile.carbGoalGrams > 0 ? userProfile.carbGoalGrams : 300), 1.0))
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(carbsConsumed)")
                            .font(.system(size: 12, weight: .bold))
                        Text("/\(userProfile.carbGoalGrams > 0 ? userProfile.carbGoalGrams : 300)g")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Text("Carbs")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            
        case .fat:
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.pink.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: min(CGFloat(fatConsumed) / CGFloat(userProfile.fatGoalGrams > 0 ? userProfile.fatGoalGrams : 65), 1.0))
                        .stroke(Color.pink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(fatConsumed)")
                            .font(.system(size: 12, weight: .bold))
                        Text("/\(userProfile.fatGoalGrams > 0 ? userProfile.fatGoalGrams : 65)g")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Text("Fat")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            
        case .steps:
            VStack(spacing: 4) {
                let stepsGoal = UserDefaults.standard.integer(forKey: "stepsGoal") > 0 ? UserDefaults.standard.integer(forKey: "stepsGoal") : 10000
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: min(CGFloat(stepsForSelectedDate) / CGFloat(stepsGoal), 1.0))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(stepsForSelectedDate)")
                            .font(.system(size: 12, weight: .bold))
                        Text("/\(stepsGoal)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Text("Steps")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            
        case .activityCalories:
            VStack(spacing: 4) {
                let activityCaloriesGoal = UserDefaults.standard.integer(forKey: "activityCaloriesGoal") > 0 ? UserDefaults.standard.integer(forKey: "activityCaloriesGoal") : 500
                let activityCalories = activityCaloriesForSelectedDate
                ZStack {
                    Circle()
                        .stroke(Color(red: 1.0, green: 0.3, blue: 0.0).opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: min(CGFloat(activityCalories) / CGFloat(activityCaloriesGoal), 1.0))
                        .stroke(Color(red: 1.0, green: 0.3, blue: 0.0), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(activityCalories)")
                            .font(.system(size: 12, weight: .bold))
                        Text("/\(activityCaloriesGoal)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Text("Activity")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }
    
    // Meal card component
    struct MealCardView: View {
        @Environment(\.colorScheme) private var colorScheme
        @StateObject private var visibilityService = MetricVisibilityService.shared
        let meal: FoodLogView.Meal
        let selectedDate: Date
        @State private var showingFoodSearch = false
        @State private var showingBarcodeScanner = false
        @State private var scannedBarcode: String? = nil
        @State private var showingFoodEntry = false
        @State private var foundFood: FoodItem? = nil
        @StateObject private var foodLogManager = FoodLogManager.shared
        @StateObject private var typesenseService = TypesenseDirectService.shared
        @State private var showingCopyConfirmation = false
        
        private var cardBackground: Color {
            colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
        }
        
        // Barcode search states (matching FoodSearchView)
        @State private var isSearchingBarcode = false
        @State private var barcodeError: String? = nil
        @State private var showingAddFoodView = false
        
        // Collapse state
        @State private var isExpanded = true
        
        // Observe the metrics manager to get selected daily goal metrics
        @ObservedObject private var metricsManager = GoalMetricsManager.shared
        
        // Calculate nutrition totals for this meal
        private var mealProtein: Int {
            Int(meal.entries.reduce(0.0) { $0 + $1.totalProtein })
        }
        
        private var mealCarbs: Int {
            Int(meal.entries.reduce(0.0) { $0 + $1.totalCarbs })
        }
        
        private var mealFat: Int {
            Int(meal.entries.reduce(0.0) { $0 + $1.totalFat })
        }
        
        // Get nutrition metrics text based on selected daily goals
        private var nutritionMetricsText: String {
            guard !meal.entries.isEmpty else { return "" }
            
            var metrics: [String] = []
            
            // Check which metrics are selected in daily goals and add them
            for metric in metricsManager.selectedMetrics {
                switch metric.type {
                case .protein:
                    metrics.append("P:\(mealProtein)g")
                case .carbs:
                    metrics.append("C:\(mealCarbs)g")
                case .fat:
                    metrics.append("F:\(mealFat)g")
                default:
                    continue // Skip non-nutrition metrics like calories, steps, nova4, etc.
                }
            }
            
            return metrics.joined(separator: " ")
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Meal header - tappable to expand/collapse
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text(meal.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.vertical, 16)
                            .padding(.horizontal)
                        
                        Spacer()
                        
                        if visibilityService.showCalories {
                            Text("\(meal.totalCalories) kcal")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Chevron indicator
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.trailing)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Collapsible content - only show when expanded
                if isExpanded {
                    // Yesterday's meal suggestion (if available and current meal is empty)
                    if meal.entries.isEmpty {
                        if let yesterdayMeal = getYesterdayMealEntries() {
                            VStack(alignment: .leading, spacing: 4) {
                                YesterdayMealSuggestion(
                                    yesterdayEntries: yesterdayMeal,
                                    mealName: meal.name,
                                    selectedDate: selectedDate
                                )
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 2)
                        }
                    }
                    
                    // Food items (if any)
                    if !meal.entries.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(meal.entries) { entry in
                                MealFoodItemRow(entry: entry)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 2)
                    }
                }
                
                // Add food buttons - ALWAYS VISIBLE (outside collapsed section)
                HStack(spacing: 16) {
                    Button(action: {
                        showingFoodSearch = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.secondary)
                            .font(.system(size: 18))
                    }
                    
                    Button(action: {
                        showingBarcodeScanner = true
                    }) {
                        Image(systemName: "barcode.viewfinder")
                            .foregroundColor(.secondary)
                            .font(.system(size: 18))
                    }
                    
                    Spacer()
                    
                    // Nutrition metrics display (only when meal has entries)
                    if !meal.entries.isEmpty && !nutritionMetricsText.isEmpty {
                        Text(nutritionMetricsText)
                            .font(.custom("Montserrat-Medium", size: 12))
                            .foregroundColor(.secondary)
                            .padding(.trailing, 4)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.clear)
                )
                .gesture(
                    DragGesture()
                        .onEnded { gesture in
                            // Right swipe to copy yesterday's meal
                            if gesture.translation.width > 100 && abs(gesture.translation.height) < 50 {
                                copyYesterdaysMeal()
                            }
                        }
                )
                
                // Sheets remain outside the conditional - always available
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
            .sheet(isPresented: $showingFoodSearch) {
                    NavigationStack {
                        FoodSearchView(mealType: meal.name, selectedDate: selectedDate)
                    }
                }
                .sheet(isPresented: $showingBarcodeScanner) {
                    BarcodeScannerView(scannedBarcode: $scannedBarcode, isPresented: $showingBarcodeScanner)
                        .onDisappear {
                            if let barcode = scannedBarcode {
                                handleScannedBarcode(barcode)
                            }
                        }
                }
                .sheet(isPresented: $showingFoodEntry) {
                    if isSearchingBarcode {
                        // Loading state
                        NavigationStack {
                            VStack {
                                Spacer()
                                VStack {
                                    ProgressView()
                                    Text("Searching for barcode...")
                                        .foregroundColor(.secondary)
                                        .padding()
                                }
                                Spacer()
                            }
                            .navigationTitle("Loading")
                            .navigationBarTitleDisplayMode(.inline)
                        }
                    } else if let errorMessage = barcodeError {
                        // Error state
                        NavigationStack {
                            VStack {
                                Spacer()
                                VStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 50))
                                        .foregroundColor(.orange)
                                        .padding()
                                    Text("Barcode Not Found")
                                        .font(.headline)
                                        .padding()
                                    Text(errorMessage)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding()
                                    
                                    Button(action: {
                                        // Close current sheet and open AddFoodView
                                        showingFoodEntry = false
                                        barcodeError = nil
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            showingAddFoodView = true
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Add New Food")
                                        }
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(.blue)
                                        .cornerRadius(12)
                                    }
                                    .padding()
                                }
                                Spacer()
                            }
                            .navigationTitle("Error")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        showingFoodEntry = false
                                        barcodeError = nil
                                    }
                                }
                            }
                        }
                    } else if let food = foundFood {
                        // Show BasicFoodEntryView for found food
                        NavigationStack {
                            BasicFoodEntryView(
                                food: food,
                                mealType: meal.name,
                                selectedDate: selectedDate,
                                onFoodAdded: { _ in
                                    // Dismiss the sheet after adding the food
                                    self.foundFood = nil
                                    self.showingFoodEntry = false
                                },
                                showScanAgainButton: true,
                                editingEntry: nil,
                                initialServingSize: food.cachedServingSize,
                                initialServingUnit: food.cachedServingUnit,
                                initialNumberOfServings: food.cachedNumberOfServings,
                                initialSelectedServingSizeOption: food.cachedSelectedServingSizeOption
                            )
                        }
                    }
                }
                .sheet(isPresented: $showingAddFoodView) {
                    AddFoodView(mealType: meal.name, selectedDate: selectedDate)
                }
                .alert("Copy Yesterday's \(meal.name)?", isPresented: $showingCopyConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Copy") {
                        performCopyYesterdaysMeal()
                    }
                } message: {
                    Text("This will add all foods from yesterday's \(meal.name.lowercased()) to today.")
                }
        }
        
        // MARK: - Barcode Handling
        private func handleScannedBarcode(_ barcode: String) {
            print("📱 Scanned barcode in meal card: \(barcode)")
            
            // Show loading state
            isSearchingBarcode = true
            barcodeError = nil
            showingFoodEntry = true  // Show sheet immediately for loading state
            
            // Search for the barcode using Typesense service
            typesenseService.searchByBarcode(barcode: barcode) { food, error in
                DispatchQueue.main.async {
                    // Always hide loading state
                    isSearchingBarcode = false
                    
                    if let food = food {
                        // Store the found food and keep showing BasicFoodEntryView
                        self.foundFood = food
                        print("✅ Found food from barcode: \(food.name)")
                    } else {
                        // Show error
                        if let error = error {
                            barcodeError = error.localizedDescription
                        } else {
                            barcodeError = "No food found with barcode: \(barcode)"
                        }
                        print("❌ Food not found for barcode: \(barcode)")
                    }
                }
            }
            
            // Reset scanned barcode
            scannedBarcode = nil
        }
        
        // Struct for barcode error alerts
        struct BarcodeError: Identifiable {
            let id = UUID()
            let message: String
        }
        
        // MARK: - Copy Yesterday's Meal Functions
        private func copyYesterdaysMeal() {
            showingCopyConfirmation = true
        }
        
        private func getYesterdayMealEntries() -> [FoodEntry]? {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            let yesterdayEntries = foodLogManager.entries(for: yesterday, mealType: meal.name)
            return yesterdayEntries.isEmpty ? nil : yesterdayEntries
        }
        
        private func performCopyYesterdaysMeal() {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            let yesterdayEntries = foodLogManager.entries(for: yesterday, mealType: meal.name)
            
            guard !yesterdayEntries.isEmpty else {
                return
            }
            
            // Copy each entry from yesterday to today
            for entry in yesterdayEntries {
                let newEntry = FoodEntry(
                    id: UUID(),
                    foodItem: entry.foodItem,
                    mealType: entry.mealType,
                    servingSize: entry.servingSize,
                    servingUnit: entry.servingUnit,
                    numberOfServings: entry.numberOfServings,
                    dateAdded: selectedDate
                )
                
                foodLogManager.addEntry(
                    foodItem: newEntry.foodItem,
                    mealType: newEntry.mealType,
                    servingSize: newEntry.servingSize,
                    servingUnit: newEntry.servingUnit,
                    numberOfServings: newEntry.numberOfServings,
                    date: newEntry.dateAdded
                )
            }
            
            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
    
    // Yesterday's meal suggestion component
    struct YesterdayMealSuggestion: View {
        let yesterdayEntries: [FoodEntry]
        let mealName: String
        let selectedDate: Date
        @StateObject private var foodLogManager = FoodLogManager.shared
        @State private var offset: CGFloat = 0
        @State private var showingCopyIcon = false
        @State private var isPulsing = false
        
        private var totalCalories: Int {
            yesterdayEntries.reduce(0) { $0 + $1.totalCalories }
        }
        
        private var foodSummary: String {
            let foodNames = yesterdayEntries.prefix(3).map { $0.foodItem.name }
            let summary = foodNames.joined(separator: ", ")
            return yesterdayEntries.count > 3 ? "\(summary) + \(yesterdayEntries.count - 3) more" : summary
        }
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(Color(hex: "#5ec5ff"))
                            .font(.caption)
                        Text("Yesterday's \(mealName.lowercased())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(foodSummary)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if showingCopyIcon {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    HStack(spacing: 4) {
                        Text("\(totalCalories) kcal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Swipe hint
                        HStack(spacing: -2) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: "#5ec5ff").opacity(1))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: "#5ec5ff").opacity(1))
                        }
                        .opacity(isPulsing ? 0.4 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .onAppear {
                isPulsing = true
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#5ec5ff").opacity(0.3), lineWidth: 1)
                    )
            )
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onChanged { gesture in
                        let translation = gesture.translation.width
                        let verticalTranslation = gesture.translation.height
                        
                        // Only allow right swipe when clearly horizontal
                        if translation > 0 && abs(verticalTranslation) < abs(translation) * 0.3 {
                            offset = translation
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingCopyIcon = offset > 50
                            }
                        }
                    }
                    .onEnded { gesture in
                        let verticalTranslation = gesture.translation.height
                        
                        if gesture.translation.width > 80 && abs(verticalTranslation) < abs(gesture.translation.width) * 0.3 {
                            // Start animation to slide off screen
                            withAnimation(.easeInOut(duration: 0.15)) {
                                offset = UIScreen.main.bounds.width
                            }
                            
                            // Copy the meal as soon as card edge leaves screen
                            // Card takes up most of screen width with padding, so roughly 90% of screen width
                            // When card has moved its own width, the trailing edge is off screen
                            let screenWidth = UIScreen.main.bounds.width
                            let cardWidth = screenWidth * 0.9
                            let timeToEdgeOffScreen = 0.15 * (cardWidth / screenWidth) // ~0.135 seconds
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + timeToEdgeOffScreen) {
                                copyYesterdaysMeal()
                            }
                        } else {
                            // Snap back to original position
                            withAnimation(.spring()) {
                                offset = 0
                                showingCopyIcon = false
                            }
                        }
                    }
            )
        }
        
        private func copyYesterdaysMeal() {
            // Copy each entry from yesterday to today
            for entry in yesterdayEntries {
                let newEntry = FoodEntry(
                    id: UUID(),
                    foodItem: entry.foodItem,
                    mealType: entry.mealType,
                    servingSize: entry.servingSize,
                    servingUnit: entry.servingUnit,
                    numberOfServings: entry.numberOfServings,
                    dateAdded: selectedDate
                )
                
                foodLogManager.addEntry(
                    foodItem: newEntry.foodItem,
                    mealType: newEntry.mealType,
                    servingSize: newEntry.servingSize,
                    servingUnit: newEntry.servingUnit,
                    numberOfServings: newEntry.numberOfServings,
                    date: newEntry.dateAdded
                )
            }
            
            // Reset animation state after copying
            withAnimation(.spring()) {
                offset = 0
                showingCopyIcon = false
            }
            
            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
    
    // Meal-specific food item row (to avoid name conflict with FoodSearchView)
    struct MealFoodItemRow: View {
        let entry: FoodEntry
        @StateObject private var foodLogManager = FoodLogManager.shared
        @StateObject private var visibilityService = MetricVisibilityService.shared
        @State private var offset: CGFloat = 0
        @State private var isSwiping = false
        @State private var showingEditView = false
        @State private var showDeleteButton = false
        
        // Check if this entry is a meal (using the isMeal flag on FoodItem)
        private var isMeal: Bool {
            return entry.foodItem.isMeal
        }
        
        // Get color based on NOVA score
        private var novaScoreColor: Color {
            let novaScore = entry.foodItem.novaScore > 0 ? entry.foodItem.novaScore : NovaScoreService.shared.predictNovaScore(for: entry.foodItem)
            switch novaScore {
            case 1: return Color(hex: "#3f993f")  // Unprocessed - darker green
            case 2: return Color(hex: "#b7ce0d")  // Processed culinary ingredients - lime green
            case 3: return Color(hex: "#f28e16")  // Processed foods - orange
            case 4: return Color(hex: "#e4032f")  // Ultra-processed foods - bright red
            default: return .gray
            }
        }
        
        // Helper function to format amount with appropriate decimal places
        private func formatAmount(_ value: Double) -> String {
            // If it's a whole number, show no decimal places
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", value)
            }
            // If it has 1 decimal place (like 0.5), show 1 decimal place
            else if (value * 10).truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.1f", value)
            }
            // Otherwise show 2 decimal places (like 0.25)
            else {
                return String(format: "%.2f", value)
            }
        }
        
        var body: some View {
            ZStack(alignment: .trailing) {
                // Delete button (revealed on swipe)
                Button(action: {
                    // Provide haptic feedback
                    HapticManager.shared.mediumFeedback()
                    // Delete the entry immediately
                    withAnimation {
                        foodLogManager.deleteEntry(id: entry.id)
                    }
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                        .frame(width: 60, height: 50)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .opacity(offset < -60 ? 1 : 0)
                
                // Food item content
                Button(action: {
                    if !isSwiping {
                        showingEditView = true
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            // First row: Food name
                            Text(entry.foodItem.name)
                                .font(.custom("Montserrat-SemiBold", size: 15))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            // Second row: amount, NOVA score (if available), NutriScore grade (if available)
                            // Hide all metadata for Quick Add foods since they don't have real serving/ingredient data
                            if entry.foodItem.name != "Quick Add" {
                                HStack(spacing: 4) {
                                    // For meals: show servings instead of weight, hide NOVA/NutriScore
                                    if isMeal {
                                        Text("\(formatAmount(entry.numberOfServings)) serving\(entry.numberOfServings == 1 ? "" : "s")")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    } else {
                                        // Amount - use extractWeightFromServingSize for accurate weight
                                        Text(calculateDisplayWeight(for: entry))
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        
                                        // NOVA score if available and visible
                                        if visibilityService.showNovaScore && (entry.foodItem.novaScore > 0 || NovaScoreService.shared.predictNovaScore(for: entry.foodItem) > 0) {
                                            // Add comma before NOVA score
                                            Text(",")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                            
                                            let novaScore = entry.foodItem.novaScore > 0 ? entry.foodItem.novaScore : NovaScoreService.shared.predictNovaScore(for: entry.foodItem)
                                            let isNovaEstimated = entry.foodItem.novaScoreIsEstimated
                                            Text("\(isNovaEstimated ? "✨ " : "")NOVA \(novaScore)")
                                                .font(.caption2)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(novaScoreColor)
                                                .cornerRadius(4)
                                        }
                                        
                                        // NutriScore grade if available and visible
                                        if visibilityService.showNutriScore, let nutriScoreGrade = entry.foodItem.nutriScoreGrade, !nutriScoreGrade.isEmpty {
                                            // Add comma before NutriScore grade
                                            Text(",")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                            let nutriScoreColor: Color = {
                                                switch nutriScoreGrade.uppercased() {
                                                case "A": return Color(hex: "#22e83d")  // Match NOVA Group 1 color
                                                case "B": return Color(hex: "#8eff00")  // Match NOVA Group 2 color
                                                case "C": return Color(hex: "#f4df70")  // Custom yellow color
                                                case "D": return Color(hex: "#ffb300")  // Match NOVA Group 3 color
                                                case "E": return Color(hex: "#ff5722")  // Match NOVA Group 4 color
                                                default: return .gray
                                                }
                                            }()
                                            
                                            Text("\(entry.foodItem.nutriScoreIsEstimated ? "✨ " : "")\(nutriScoreGrade.uppercased())")
                                                .font(.caption2)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(nutriScoreColor)
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Only show calories if visibility is enabled
                        if visibilityService.showCalories {
                            Text("\(entry.totalCalories) kcal")
                                .font(.custom("Montserrat-SemiBold", size: 15))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .cornerRadius(8)
                    .offset(x: offset)
                    .gesture(
                        DragGesture(minimumDistance: 30, coordinateSpace: .local)
                            .onChanged { gesture in
                                let translation = gesture.translation.width
                                let verticalTranslation = gesture.translation.height
                                
                                // Only handle clearly horizontal swipes (horizontal > 3x vertical)
                                if abs(translation) > 30 && abs(verticalTranslation) < abs(translation) * 0.3 {
                                    isSwiping = true
                                    if translation < 0 {
                                        offset = translation
                                    }
                                }
                            }
                            .onEnded { gesture in
                                let translation = gesture.translation.width
                                let verticalTranslation = gesture.translation.height
                                
                                // Only handle clearly horizontal swipes
                                if abs(translation) > 30 && abs(verticalTranslation) < abs(translation) * 0.3 {
                                    withAnimation {
                                        if translation < -60 {
                                            HapticManager.shared.lightFeedback()
                                            offset = -90
                                        } else {
                                            offset = 0
                                        }
                                    }
                                } else {
                                    withAnimation {
                                        offset = 0
                                    }
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isSwiping = false
                                }
                            }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .sheet(isPresented: $showingEditView) {
                NavigationView {
                    if let retrievedEntry = foodLogManager.entry(withID: entry.id) {
                        BasicFoodEntryView(
                            food: retrievedEntry.foodItem,
                            mealType: retrievedEntry.mealType,
                            selectedDate: retrievedEntry.dateAdded,
                            onFoodAdded: nil,
                            showScanAgainButton: false,
                            editingEntry: retrievedEntry,
                            initialServingSize: nil,
                            initialServingUnit: nil,
                            initialNumberOfServings: nil,
                            initialSelectedServingSizeOption: nil
                        )
                    }
                }
            }
        }
        
        // Calculate the correct display weight using the actual serving size selected
        private func calculateDisplayWeight(for entry: FoodEntry) -> String {
            let unitLower = entry.servingUnit.lowercased()
            
            // For "serving", "servings", or "meal" units, check if servingSize represents grams
            if unitLower == "meal" || unitLower == "serving" || unitLower == "servings" {
                // If servingSize is a typical gram value (>=1), calculate total grams
                if entry.servingSize >= 1 {
                    let totalGrams = entry.servingSize * entry.numberOfServings
                    return formatAmount(totalGrams) + "g"
                }
                // Otherwise show servings count
                let servingCount = Int(entry.numberOfServings)
                return servingCount == 1 ? "1 serving" : "\(servingCount) servings"
            }
            
            // Use the actual serving size and unit that were selected by the user
            let totalAmount = entry.servingSize * entry.numberOfServings
            return formatAmount(totalAmount) + entry.servingUnit
        }
    }
    
    // Wrapper view that opens FoodSearchView with barcode scanner automatically triggered
    struct BarcodeScannerFoodSearchView: View {
        let mealType: String
        let selectedDate: Date
        
        var body: some View {
            FoodSearchView(mealType: mealType, selectedDate: selectedDate)
        }
    }
    
}

#Preview {
    FoodLogView()
}
