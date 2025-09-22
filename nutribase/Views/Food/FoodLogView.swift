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
    
    @ObservedObject private var userProfile = UserProfile.shared
    
    // Pre-calculate values to avoid complex expressions during drag
    private var proteinGoal: Int {
        userProfile.proteinGoalGrams > 0 ? userProfile.proteinGoalGrams : 50
    }
    
    private var caloriesConsumed: Int {
        // Simple calculation to avoid complex function calls during drag
        (proteinConsumed * 4) + (carbsConsumed * 4) + (fatConsumed * 9)
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
    // Keys for UserDefaults storage
    private let visibleMealsKey = "foodLogVisibleMeals"
    private let hiddenMealsKey = "foodLogHiddenMeals"
    
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
        
        let totalProtein = allEntries.reduce(0.0) { total, entry in
            return total + entry.totalProtein
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
        
        // Calculate total calories and NOVA 4 calories
        var totalCalories = 0
        var nova4Calories = 0
        
        for entry in allEntries {
            let entryCalories = entry.totalCalories
            totalCalories += entryCalories
            
            // Check if this is a NOVA 4 food
            if entry.foodItem.novaScore == 4 {
                nova4Calories += entryCalories
            }
        }
        
        // Calculate percentage
        if totalCalories > 0 {
            return (Double(nova4Calories) / Double(totalCalories)) * 100.0
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
        
        // Update steps from activity manager
        // Steps are now handled directly by ActivityManager and HealthKitManager
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background color layer - matching dashboard
            Color(hex: "#F0F1F4")
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
                                .font(.custom("Montserrat-Bold", size: 17))
                                .foregroundColor(.black)
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
                                .font(.custom("Montserrat-Bold", size: 17))
                                .foregroundColor(.black)
                        }
                        
                        Button(action: {
                            // Go to next day
                            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.custom("Montserrat-Bold", size: 17))
                                .foregroundColor(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Left side - empty for balance
                    HStack {
                        Spacer()
                    }
                    
                    // Right side - edit button
                    HStack {
                        Spacer()
                        
                        HStack(spacing: 12) {
                            // Settings button
                            Button(action: {
                                showingMealStorage = true
                            }) {
                                Image(systemName: "gear")
                                    .foregroundColor(.black)
                            }
                            
                            // Edit button
                            Button(action: {
                                withAnimation {
                                    isEditing.toggle()
                                }
                            }) {
                                Text(isEditing ? "Done" : "Edit")
                                    .font(.custom("Montserrat-Bold", size: 17))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.trailing, 8)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 1) // Reduced top padding
                .background(Color(hex: "#F0F1F4"))
                .zIndex(3)
                
                // Weekly overview (hidden completely)
                // WeeklyOverviewView(currentDate: Date(), selectedDate: $selectedDate)
                //     .frame(height: weeklyOverviewHeight)
                //     .opacity(weeklyOverviewHeight > 0 ? 1 : 0)
                //     .zIndex(2)
                
                // Meal cards with scroll-to-reveal functionality
                ScrollView(.vertical, showsIndicators: false) {
                    // Detect scroll position with GeometryReader
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ScrollViewOffsetKey.self,
                            value: proxy.frame(in: .global).minY
                        )
                    }
                    .frame(height: 0)
                    .onAppear {
                        // Initialize scroll offset on appear
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollOffset = 0
                            previousScrollOffset = 0
                        }
                    }
                    
                    VStack(spacing: 16) {
                        
                        // Use indices for ForEach to support drag and drop
                        ForEach(visibleMeals.indices, id: \.self) { index in
                            let mealType = visibleMeals[index]
                            
                            Group {
                                switch mealType {
                                case .caloriesSummary:
                                    CalorieSummaryCard(
                                        consumedCalories: totalCaloriesForDay(),
                                        targetCalories: userProfile.dailyCalorieGoal > 0 ? userProfile.dailyCalorieGoal : 2000
                                    )
                                    .overlay(
                                        isEditing ?
                                        Button(action: {
                                            hideMeal(mealType)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.red)
                                                .background(Circle().fill(Color.white))
                                                .padding(6)
                                        }
                                            .position(x: 20, y: 20)
                                        : nil
                                    )
                                    
                                case .dailyGoals:
                                    DailyGoalsCardWrapper(
                                        proteinConsumed: proteinConsumed,
                                        carbsConsumed: carbsConsumed,
                                        fatConsumed: fatConsumed,
                                        nova4Percentage: nova4Percentage,
                                        nova4Goal: nova4Goal
                                    )
                                    .padding(.top, 4)
                                    .overlay(
                                        isEditing ?
                                        Button(action: {
                                            hideMeal(mealType)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.red)
                                                .background(Circle().fill(Color.white))
                                                .padding(6)
                                        }
                                            .position(x: 20, y: 20)
                                        : nil
                                    )
                                    
                                case .breakfast, .lunch, .dinner, .snacks:
                                    // Find the meal data for this meal type
                                    if let meal = meals.first(where: { $0.name == mealType.rawValue }) {
                                        MealCardView(meal: meal, selectedDate: selectedDate)
                                            .overlay(
                                                isEditing ?
                                                Button(action: {
                                                    hideMeal(mealType)
                                                }) {
                                                    Image(systemName: "minus.circle.fill")
                                                        .font(.title2)
                                                        .foregroundColor(.red)
                                                        .background(Circle().fill(Color.white))
                                                        .padding(6)
                                                }
                                                    .position(x: 20, y: 20)
                                                : nil
                                            )
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
                        
                        // Add extra padding at the bottom to ensure the last card is fully visible
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
            .onAppear {
                // Update metrics when view appears
                updateMetrics()
            }
            .onReceive(NotificationCenter.default.publisher(for: .foodLogUpdated)) { _ in
                // Update metrics when food log changes
                updateMetrics()
            }
            .onPreferenceChange(ScrollViewOffsetKey.self) { offset in
                // Determine scroll direction for future use if needed
                if offset < previousScrollOffset {
                    scrollDirection = .up
                } else if offset > previousScrollOffset {
                    scrollDirection = .down
                }
                
                // Weekly overview functionality disabled
                // Always keep weekly overview hidden
                weeklyOverviewVisible = false
                weeklyOverviewHeight = 0
                
                // Update previous offset for next comparison
                previousScrollOffset = offset
            }
            .onReceive(NotificationCenter.default.publisher(for: .foodLogUpdated)) { _ in
                // This will force the view to refresh when food log changes
                updateMetrics()
                refreshID = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(for: .goalMetricsUpdated)) { _ in
                // This will force the view to refresh when goal metrics order changes
                refreshID = UUID()
            }
            // Use a standard sheet presentation to ensure proper scrolling
            .sheet(isPresented: $showingMealStorage) {
                MealStorageView(visibleMeals: $visibleMeals, hiddenMeals: $hiddenMeals, onDismiss: {
                    showingMealStorage = false
                })
                .onDisappear {
                    // Clean up any duplicates and save changes when dismissed
                    // Use the existing cleanup logic from onChange handler
                    // Remove duplicates between visible and hidden meals
                    let visibleSet = Set(visibleMeals)
                    hiddenMeals = hiddenMeals.filter { !visibleSet.contains($0) }
                    
                    // Save meal visibility preferences
                    saveVisibleMeals()
                    saveHiddenMeals()
                    
                    // Refresh UI
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFoodLog"), object: nil)
                }
            }
            .animation(.spring(), value: showingMealStorage)
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
            .onAppear {
                // Always reset to today's date when view appears
                selectedDate = Date()
                
                // Update metrics when view appears
                updateMetrics()
                // Refresh activity data
                activityManager.refreshActivityData()
                
                // Store current date as last open date
                lastOpenDate = Date().timeIntervalSince1970
            }
            .id(refreshID)
        }
        
        
    }
    
    // Meal card component
    struct MealCardView: View {
        let meal: FoodLogView.Meal
        let selectedDate: Date
        @State private var showingFoodSearch = false
        @State private var showingBarcodeScanner = false
        @State private var scannedBarcode: String? = nil
        @State private var showingFoodEntry = false
        @State private var foundFood: FoodItem? = nil
        @StateObject private var foodLogManager = FoodLogManager.shared
        @StateObject private var typesenseService = TypesenseService.shared
        @State private var showingCopyConfirmation = false
        
        // Barcode search states (matching FoodSearchView)
        @State private var isSearchingBarcode = false
        @State private var barcodeError: String? = nil
        
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
                case .calories:
                    metrics.append("Cal:\(meal.totalCalories)")
                case .fat:
                    metrics.append("F:\(mealFat)g")
                default:
                    continue // Skip non-nutrition metrics like steps, nova4, etc.
                }
            }
            
            return metrics.joined(separator: " ")
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Meal header
                HStack {
                    Text(meal.name)
                        .font(.custom("Montserrat-SemiBold", size: 17))
                        .padding(.vertical, 16)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    Text("\(meal.totalCalories) kcal")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundColor(.secondary)
                        .padding(.trailing)
                }
                
                // Yesterday's meal suggestion (if available and current meal is empty)
                if meal.entries.isEmpty {
                    if let yesterdayMeal = getYesterdayMealEntries() {
                        VStack(alignment: .leading, spacing: 8) {
                            YesterdayMealSuggestion(
                                yesterdayEntries: yesterdayMeal,
                                mealName: meal.name,
                                selectedDate: selectedDate
                            )
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
                
                // Food items (if any)
                if !meal.entries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(meal.entries) { entry in
                            MealFoodItemRow(entry: entry)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                
                // Add food buttons
                HStack(spacing: 16) {
                    Button(action: {
                        showingFoodSearch = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                    }
                    
                    Button(action: {
                        showingBarcodeScanner = true
                    }) {
                        Image(systemName: "barcode.viewfinder")
                            .foregroundColor(.blue)
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
                        NavigationStack {
                            BasicFoodEntryView(
                                food: food,
                                mealType: meal.name,
                                selectedDate: selectedDate,
                                showScanAgainButton: true,
                                initialServingSize: nil,
                                initialServingUnit: nil,
                                initialNumberOfServings: nil,
                                initialSelectedServingSizeOption: nil
                            )
                        }
                    }
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
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#FFFFFF"))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
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
                            .foregroundColor(.orange)
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
                    Text("\(totalCalories) kcal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        // Only allow right swipe
                        if gesture.translation.width > 0 {
                            offset = gesture.translation.width
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingCopyIcon = offset > 50
                            }
                        }
                    }
                    .onEnded { gesture in
                        if gesture.translation.width > 80 {
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
        @State private var offset: CGFloat = 0
        @State private var isSwiping = false
        @State private var showingEditView = false
        @State private var showDeleteButton = false
        
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
                    // Delete the entry
                    withAnimation {
                        foodLogManager.deleteEntry(id: entry.id)
                    }
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                        .frame(width: 90, height: 50)
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
                            
                            // Second row: Brand (if available), amount, NOVA score (if available), NutriScore grade (if available)
                            HStack(spacing: 4) {
                                // Brand name if available
                                if let brandName = entry.foodItem.brandName, !brandName.isEmpty {
                                    Text(brandName)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                    
                                    // Add comma after brand name
                                    Text(",")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                
                                // Amount - use extractWeightFromServingSize for accurate weight
                                Text(calculateDisplayWeight(for: entry))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                
                                // NOVA score if available
                                if entry.foodItem.novaScore > 0 || NovaScoreService.shared.predictNovaScore(for: entry.foodItem) > 0 {
                                    // Add comma before NOVA score
                                    Text(",")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    
                                    let novaScore = entry.foodItem.novaScore > 0 ? entry.foodItem.novaScore : NovaScoreService.shared.predictNovaScore(for: entry.foodItem)
                                    Text("NOVA \(novaScore)")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(novaScoreColor)
                                        .cornerRadius(4)
                                }
                                
                                // NutriScore grade if available
                                if let nutriScoreGrade = entry.foodItem.nutriScoreGrade, !nutriScoreGrade.isEmpty {
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
                                    
                                    Text(nutriScoreGrade.uppercased())
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(nutriScoreColor)
                                        .cornerRadius(4)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Text("\(entry.totalCalories) kcal")
                            .font(.custom("Montserrat-SemiBold", size: 15))
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .offset(x: offset)
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { gesture in
                                // Detect if this is primarily a horizontal swipe
                                let isHorizontalSwipe = abs(gesture.translation.width) > abs(gesture.translation.height)
                                
                                if isHorizontalSwipe {
                                    isSwiping = true
                                    if gesture.translation.width < 0 {
                                        // Only allow dragging to the left (negative values)
                                        offset = gesture.translation.width
                                    }
                                }
                            }
                            .onEnded { gesture in
                                // Only handle horizontal swipes
                                let isHorizontalSwipe = abs(gesture.translation.width) > abs(gesture.translation.height)
                                
                                if isHorizontalSwipe {
                                    withAnimation {
                                        // If dragged more than 90 points to the left, delete
                                        if gesture.translation.width < -90 {
                                            // Provide haptic feedback
                                            HapticManager.shared.mediumFeedback()
                                            // Delete the entry
                                            foodLogManager.deleteEntry(id: entry.id)
                                        } else if gesture.translation.width < -60 {
                                            // If dragged between 60-90 points, show delete button
                                            offset = -90
                                        } else {
                                            // Otherwise, snap back
                                            offset = 0
                                        }
                                    }
                                } else {
                                    // For vertical swipes, just reset offset
                                    withAnimation {
                                        offset = 0
                                    }
                                }
                                
                                // Reset swiping flag after a short delay
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
            .padding(.vertical, 4)
            .sheet(isPresented: $showingEditView) {
                NavigationView {
                    if let retrievedEntry = foodLogManager.entry(withID: entry.id) {
                        FoodEntryEditView(entry: retrievedEntry)
                    }
                }
            }
        }
        
        // Calculate the correct display weight using the actual serving size selected
        private func calculateDisplayWeight(for entry: FoodEntry) -> String {
            print("=== calculateDisplayWeight for \(entry.foodItem.name) ===")
            print("entry.servingSize = \(entry.servingSize)")
            print("entry.servingUnit = \(entry.servingUnit)")
            print("entry.numberOfServings = \(entry.numberOfServings)")
            
            // Use the actual serving size and unit that were selected by the user
            let totalAmount = entry.servingSize * entry.numberOfServings
            let result = formatAmount(totalAmount) + entry.servingUnit
            
            print("✅ Display calculation:")
            print("  - servingSize: \(entry.servingSize)")
            print("  - servingUnit: \(entry.servingUnit)")
            print("  - numberOfServings: \(entry.numberOfServings)")
            print("  - totalAmount: \(totalAmount) (\(entry.servingSize) × \(entry.numberOfServings))")
            print("  - result: \(result)")
            return result
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
