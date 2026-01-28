//
//  FoodSearchView.swift
//  nutribase
//
//  Created on 03/06/2025.
//

import SwiftUI
import Combine
import AVFoundation
import Foundation

// Helper function to calculate calories for the default serving size
func calculateDefaultServingCalories(for food: FoodItem) -> Int {
    // If calories are 0 but we have macro data, calculate from macros
    // Note: When calories are 0, the macros are typically for the serving size, not per 100g
    if food.calories == 0 && (food.protein > 0 || food.carbs > 0 || food.fat > 0) {
        // Calculate calories from macros: Protein=4cal/g, Carbs=4cal/g, Fat=9cal/g
        // These macros are for the serving size, so return directly without scaling
        let calculatedCalories = (food.protein * 4.0) + (food.carbs * 4.0) + (food.fat * 9.0)
        return Int(round(calculatedCalories))
    }
    
    let baseFoodCalories = food.calories
    
    // Check if the food has a serving size specified
    if let originalServingSize = food.servingSize, !originalServingSize.isEmpty {
        // Handle non-standard formats like "1bar" or "1 bar (36 g)"
        if originalServingSize.lowercased().contains("bar") ||
           originalServingSize.lowercased().contains("piece") ||
           originalServingSize.lowercased().contains("pack") ||
           originalServingSize.lowercased().contains("serving") {
            
            // Try to extract weight from parentheses like "1 bar (36 g)"
            let parenthesesPattern = "\\(([0-9]+[.,]?[0-9]*)\\s*([a-zA-Z]+)\\)"
            if let regex = try? NSRegularExpression(pattern: parenthesesPattern, options: []) {
                let nsString = originalServingSize as NSString
                let matches = regex.matches(in: originalServingSize, options: [], range: NSRange(location: 0, length: nsString.length))
                
                if let match = matches.first {
                    let valueRange = match.range(at: 1)
                    let valueStr = nsString.substring(with: valueRange)
                    
                    if let servingWeight = Double(valueStr) {
                        // Calculate calories based on the serving weight (assuming baseFoodCalories is per 100g)
                        let caloriesPerGram = Double(baseFoodCalories) / 100.0
                        return Int(round(caloriesPerGram * servingWeight))
                    }
                }
            }
            
            // If no weight found in parentheses, return the base calories (likely per 100g)
            return baseFoodCalories
        }
        
        // Try to parse standard formats like "100g" or "250ml"
        let pattern = "([0-9]+[.,]?[0-9]*)\\s*([a-zA-Z]+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = originalServingSize as NSString
            let matches = regex.matches(in: originalServingSize, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let match = matches.first {
                let valueRange = match.range(at: 1)
                let unitRange = match.range(at: 2)
                
                let valueStr = nsString.substring(with: valueRange)
                let unitStr = nsString.substring(with: unitRange).lowercased()
                
                if let servingSize = Double(valueStr) {
                    // For grams, calculate based on the serving size
                    if unitStr == "g" {
                        let caloriesPerGram = Double(baseFoodCalories) / 100.0
                        return Int(round(caloriesPerGram * servingSize))
                    }
                    // For ml, assume similar density to water (1ml ≈ 1g for most liquids)
                    else if unitStr == "ml" {
                        let caloriesPerGram = Double(baseFoodCalories) / 100.0
                        return Int(round(caloriesPerGram * servingSize))
                    }
                }
            }
        }
    }
    
    // If no serving size or couldn't parse it, return the base calories
    return baseFoodCalories
}

// Haptic feedback manager for search interactions
class HapticFeedback {
    static let shared = HapticFeedback()
    
    private let hapticQueue = DispatchQueue(label: "com.nutribase.haptics", qos: .userInteractive)
    private var generators: [UIFeedbackGenerator] = []
    
    private init() {
        // Pre-initialize generators on background queue to avoid blocking UI
        hapticQueue.async { [weak self] in
            let softGenerator = UIImpactFeedbackGenerator(style: .soft)
            let lightGenerator = UIImpactFeedbackGenerator(style: .light)
            let selectionGenerator = UISelectionFeedbackGenerator()
            
            softGenerator.prepare()
            lightGenerator.prepare()
            selectionGenerator.prepare()
            
            self?.generators = [softGenerator, lightGenerator, selectionGenerator]
        }
    }
    
    // Ultra light feedback for typing (very subtle)
    func ultraLightFeedback() {
        hapticQueue.async {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred(intensity: 0.3)
        }
    }
    
    // Light feedback for typing
    func lightFeedback() {
        hapticQueue.async {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
    
    // Selection feedback for when an item is selected
    func selectionFeedback() {
        hapticQueue.async {
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }
}

struct FoodSearchView: View {
    @Environment(\.colorScheme) private var colorScheme
    let mealType: String
    let selectedDate: Date
    var isCreatingMeal: Bool = false
    var onFoodSelectedForMeal: ((FoodEntry) -> Void)? = nil
    
    private var viewBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    @StateObject private var typesenseService = TypesenseDirectService.shared
    @StateObject private var suggestionService = SearchSuggestionService.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    @ObservedObject private var mealsManager = SavedMealsManager.shared
    @State private var searchText = ""
    @State private var searchTask: DispatchWorkItem?
    @FocusState private var isSearchFieldFocused: Bool
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    
    // State for search results
    @State private var foodItems: [FoodItem] = []
    @State private var isLoading = false
    
    // State for barcode scanner sheet
    @State private var showingBarcodeScanner = false
    @State private var isSearchingBarcode = false
    @State private var barcodeError: String? = nil
    @State private var scannedBarcode: String? = nil
    
    // State for food entry navigation
    @State private var selectedFood: FoodItem? = nil
    @State private var showingFoodEntry = false
    
    // State for quick add view
    @State private var showingQuickAddView = false
    @State private var showingAddFoodView = false
    
    // State for meals view
    @State private var showingMealsView = false
    @State private var showingCreateMeal = false
    
    // State for toast notification
    @State private var showToast = false
    @State private var toastMessage = ""
    
    // Timer for search debouncing
    @State private var searchDebounceTimer: Timer?
    
    // Timer for history cache debouncing
    @State private var historyCacheTimer: Timer?
    @State private var initialHistoryLoaded = false
    
    // State variables for UI management
    
    // State for search suggestions
    @State private var showSuggestions = false
    
    // Track if user has submitted a search (Enter or suggestion tap)
    @State private var hasSubmittedSearch = false
    
    // Cached history foods to avoid recalculating on every render
    @State private var cachedHistoryFoods: [FoodItem] = []
    @State private var lastHistorySearchText: String = ""
    
    // Keys for storing data in UserDefaults (user-specific)
    private var recentFoodsKey: String {
        if let authenticatedUser = FirebaseAuthService.shared.currentUser {
            return "recentlyAddedFoods_\(authenticatedUser.id)"
        } else {
            // Fallback to local UUID for offline usage
            if let existingId = UserDefaults.standard.string(forKey: "current_user_id") {
                return "recentlyAddedFoods_\(existingId)"
            } else {
                let newId = UUID().uuidString
                UserDefaults.standard.set(newId, forKey: "current_user_id")
                return "recentlyAddedFoods_\(newId)"
            }
        }
    }
    private let maxRecentFoods = 30
    
    private var recentFoods: [FoodItem] {
        if let data = UserDefaults.standard.data(forKey: recentFoodsKey),
           let foods = try? JSONDecoder().decode([FoodItem].self, from: data) {
            // Apply cached serving info so recent foods use last-used serving sizes
            return FoodServingCacheService.shared.applyCachedServingInfo(to: foods)
        }
        return []
    }
    
    // Computed property for filtered foods
    private var filteredFoods: [FoodItem] {
        if searchText.isEmpty {
            // Show recent foods when no search, but exclude meals
            return recentFoods.filter { !$0.isMeal }
        } else {
            // Show search results, but exclude items that are already in history and meals
            let historyFoodIds = Set(historyFoods.map { generateFoodId(for: $0) })
            return foodItems.filter { food in
                let foodId = generateFoodId(for: food)
                return !historyFoodIds.contains(foodId) && !food.isMeal
            }
        }
    }
    
    // Generate a unique identifier for a food item (same logic as FoodServingCacheService)
    private func generateFoodId(for food: FoodItem) -> String {
        var components: [String] = [food.name.lowercased()]
        
        if let brand = food.brandName, !brand.isEmpty {
            components.append(brand.lowercased())
        }
        
        if let barcode = food.barcode, !barcode.isEmpty {
            components.append(barcode)
        }
        
        return components.joined(separator: "|")
    }
    
    // Use cached history foods (updated via updateHistoryFoodsCache)
    private var historyFoods: [FoodItem] {
        return cachedHistoryFoods
    }
    
    // Update history foods cache - called when search text changes
    // Uses debouncing to prevent multiple refreshes during typing
    private func updateHistoryFoodsCache(debounce: Bool = true) {
        guard !searchText.isEmpty else {
            if !cachedHistoryFoods.isEmpty {
                cachedHistoryFoods = []
            }
            lastHistorySearchText = ""
            initialHistoryLoaded = false
            historyCacheTimer?.invalidate()
            return
        }
        
        // If history hasn't been loaded yet for this search session, load immediately
        if !initialHistoryLoaded {
            performHistoryCacheUpdate()
            initialHistoryLoaded = true
            return
        }
        
        // For subsequent updates, debounce to prevent flickering
        if debounce {
            historyCacheTimer?.invalidate()
            historyCacheTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                performHistoryCacheUpdate()
            }
        } else {
            performHistoryCacheUpdate()
        }
    }
    
    // Perform the actual history cache update
    private func performHistoryCacheUpdate() {
        // Only recalculate if search text has actually changed
        guard searchText != lastHistorySearchText else { return }
        let currentSearchText = searchText
        lastHistorySearchText = currentSearchText
        
        let searchLower = currentSearchText.lowercased()
        
        // Get unique food items by using a dictionary keyed by food identifier
        var uniqueFoodItems: [String: FoodItem] = [:]
        for entry in foodLogManager.entries {
            let food = entry.foodItem
            // Create a unique key using name, brand, and barcode
            let key = "\(food.name.lowercased())|\(food.brandName?.lowercased() ?? "")|\(food.barcode ?? "")"
            uniqueFoodItems[key] = food
        }
        
        let matchingFoods = Array(uniqueFoodItems.values).filter { food in
            // Exclude meals from history
            if food.isMeal {
                return false
            }
            
            // Check if search matches food name
            if food.name.lowercased().contains(searchLower) {
                return true
            }
            
            // Check if search matches brand name
            if let brandName = food.brandName, 
               brandName.lowercased().contains(searchLower) {
                return true
            }
            
            return false
        }.sorted { $0.name < $1.name } // Sort alphabetically
        
        // Apply cached serving information to history foods
        cachedHistoryFoods = matchingFoods.map { food in
            FoodServingCacheService.shared.createFoodItemWithCache(from: food)
        }
    }
    
    // Filter suggestions to exclude items already shown in History
    private var filteredSuggestions: [SearchSuggestionService.SearchSuggestion] {
        let historyNames = Set(historyFoods.map { $0.name.lowercased() })
        return suggestionService.suggestions.filter { suggestion in
            !historyNames.contains(suggestion.text.lowercased())
        }
    }
    
    // Get recently added foods from UserDefaults
    private func getRecentFoods() -> [FoodItem] {
        guard let data = UserDefaults.standard.data(forKey: recentFoodsKey),
              let recentFoods = try? JSONDecoder().decode([FoodItem].self, from: data) else {
            return []
        }
        // Apply cached serving info so recent foods use last-used serving sizes
        return FoodServingCacheService.shared.applyCachedServingInfo(to: recentFoods)
    }
    
    // MARK: - Food Management Methods
    
    // Add to recent foods
    private func addToRecentFoods(_ food: FoodItem) {
        // Load existing recent foods
        var foods = recentFoods
        
        // Remove the food if it already exists (to avoid duplicates)
        // Compare by name, brand, and barcode instead of UUID since same foods can have different UUIDs
        foods.removeAll { existingFood in
            existingFood.name == food.name && 
            existingFood.brandName == food.brandName && 
            existingFood.barcode == food.barcode
        }
        
        // Add the new food at the beginning
        foods.insert(food, at: 0)
        
        // Limit to max number of recent foods
        if foods.count > maxRecentFoods {
            foods = Array(foods.prefix(maxRecentFoods))
        }
        
        // Save the updated list to UserDefaults
        if let encodedData = try? JSONEncoder().encode(foods) {
            UserDefaults.standard.set(encodedData, forKey: recentFoodsKey)
        }
    }
    
    // Perform search with debounce
    private func performSearch() {
        // Cancel any existing search task
        searchTask?.cancel()
        
        // Create a new search task
        let task = DispatchWorkItem {
            // Structs don't need weak self
            
            if self.searchText.isEmpty {
                // Don't search if query is empty
                return
            }
            
            // Show loading state
            DispatchQueue.main.async {
                self.isLoading = true
            }
            
            // Track search event
            self.analyticsService.trackFoodSearchStarted(source: "typesense", queryLength: self.searchText.count)
            
            // Check if the search text looks like a barcode (all digits, 8+ characters)
            let trimmedText = self.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let isBarcode = trimmedText.count >= 8 && trimmedText.allSatisfy { $0.isNumber }
            
            if isBarcode {
                // Use barcode search for numeric inputs that look like barcodes
                self.typesenseService.searchByBarcode(barcode: trimmedText) { food, error in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        
                        if let food = food {
                            self.foodItems = [food] // Show single result
                        } else {
                            self.foodItems = [] // No results
                        }
                    }
                }
            } else {
                // Perform regular search using Typesense
                self.typesenseService.searchFoods(query: self.searchText) { foods, error in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        
                        if let error = error {
                            self.foodItems = [] // Clear results on error
                            print("❌ Typesense search error: \(error.localizedDescription)")
                            return
                        }
                        
                        self.foodItems = foods ?? []
                        print("🔍 Typesense search found \(foods?.count ?? 0) results for '\(self.searchText)'")
                    }
                }
            }
        }
        
        // Save reference to new task
        searchTask = task
        
        // Schedule the task with a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
    }
    
    // Handle scanned barcode
    private func handleScannedBarcode(_ barcode: String) {
        // Show loading state
        isSearchingBarcode = true
        barcodeError = nil
        
        // Search for the barcode using Typesense
        typesenseService.searchByBarcode(barcode: barcode) { food, error in
            DispatchQueue.main.async {
                // Always hide loading state
                isSearchingBarcode = false
                
                if let food = food {
                    // Found the food, show it
                    selectedFood = food
                    showingFoodEntry = true
                } else {
                    // Show error
                    if let error = error {
                        barcodeError = error.localizedDescription
                    } else {
                        barcodeError = "No food found with barcode: \(barcode)"
                    }
                    print("⚠️ Barcode not found in Typesense: \(barcode)")
                }
            }
        }
    }
    
    // Struct for barcode error alerts
    struct BarcodeError: Identifiable {
        let id = UUID()
        let message: String
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                viewBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                // Fixed header area with title and search bar
                VStack(spacing: 0) {
                    // Title bar - matches Dashboard style
                    ZStack {
                        // Center title based on full width
                        Text("Food Search")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                        
                        // Right side - cancel button
                        HStack {
                            Spacer()
                            Button("Cancel") {
                                HapticManager.shared.lightFeedback()
                                presentationMode.wrappedValue.dismiss()
                            }
                            .foregroundColor(.primary)
                            .withHapticFeedback()
                        }
                    }
                    .padding()
                    
                    // Search bar - always below the title
                    VStack(spacing: 0) {
                        HStack {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                
                                TextField("Search foods...", text: $searchText, onEditingChanged: { isEditing in
                                    showSuggestions = isEditing && !searchText.isEmpty
                                })
                                .focused($isSearchFieldFocused)
                                .toolbar {
                                    ToolbarItemGroup(placement: .keyboard) {
                                        Spacer()
                                        Button {
                                            isSearchFieldFocused = false
                                        } label: {
                                            Image(systemName: "keyboard.chevron.compact.down")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .onSubmit {
                                    // User pressed Enter - perform the search
                                    if !searchText.isEmpty {
                                        HapticManager.shared.lightFeedback()
                                        hasSubmittedSearch = true
                                        showSuggestions = false
                                        suggestionService.addToRecentSearches(searchText)
                                        performSearch()
                                    }
                                }
                                .onChange(of: searchText) { _, newValue in
                                    // Provide haptic feedback when typing
                                    HapticFeedback.shared.lightFeedback()
                                    
                                    // Don't reset if user just submitted via suggestion tap
                                    // (wait a moment to check if submission happened)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                        // Only reset if search wasn't submitted
                                        if !hasSubmittedSearch {
                                            foodItems = [] // Clear previous search results
                                            
                                            // Show suggestions and fetch them
                                            showSuggestions = !newValue.isEmpty
                                            suggestionService.getSuggestions(for: newValue)
                                        }
                                    }
                                    
                                    // Update history foods cache (only recalculates if search changed)
                                    updateHistoryFoodsCache()
                                }
                                
                                if !searchText.isEmpty {
                                    Button(action: {
                                        HapticManager.shared.lightFeedback()
                                        searchText = ""
                                        showSuggestions = false
                                        hasSubmittedSearch = false
                                        foodItems = []
                                        cachedHistoryFoods = []
                                        lastHistorySearchText = ""
                                        initialHistoryLoaded = false
                                        historyCacheTimer?.invalidate()
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                    .withHapticFeedback()
                                }
                                
                                // Barcode scanner button
                                Button(action: {
                                    HapticManager.shared.lightFeedback()
                                    showingBarcodeScanner = true
                                }) {
                                    Image(systemName: "barcode.viewfinder")
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 4)
                                }
                                .withHapticFeedback()
                            }
                            .padding(8)
                            .background(Color(.systemGray5))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                    
                    // Search, Quick add and Meals buttons - only show when search text is empty
                    if searchText.isEmpty {
                        HStack(spacing: 12) {
                            Button(action: {
                                HapticManager.shared.lightFeedback()
                                showingMealsView = false
                            }) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 16))
                                    Text("Search")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            
                            Button(action: {
                                HapticManager.shared.lightFeedback()
                                showingQuickAddView = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 16))
                                    Text("Quick Add")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            
                            // Hide Meals button when creating a meal to prevent nested meal creation
                            if !isCreatingMeal {
                                Button(action: {
                                    HapticManager.shared.lightFeedback()
                                    showingMealsView.toggle()
                                }) {
                                    HStack {
                                        Image(systemName: "fork.knife")
                                            .font(.system(size: 16))
                                        Text("Meals")
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        
                        // Button padding
                        Spacer().frame(height: 4)
                    }
                    
                    // Extra spacing for layout
                    Spacer().frame(height: 8)
                }
                .buttonStyle(PlainButtonStyle())
                .background(Color(.systemGray6))
                .onChange(of: searchText) { oldValue, newValue in
                    // Provide ultra light haptic feedback when typing
                    HapticFeedback.shared.ultraLightFeedback()
                    // Only search if there's actual text
                    if !newValue.isEmpty {
                        // Debounce search to avoid too many requests
                        searchDebounceTimer?.invalidate()
                        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                            performSearch()
                        }
                    } else {
                        // Clear search results when search is empty
                        foodItems = []
                        showSuggestions = false
                    }
                }
                
                Divider()
                
                // Content area below the fixed header
                if isSearchingBarcode {
                    Spacer()
                    VStack {
                        ProgressView()
                        Text("Searching for barcode...")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    Spacer()
                } else if isLoading && searchText.isEmpty {
                    // Only show full loading screen when there's no search text
                    Spacer()
                    VStack {
                        ProgressView()
                        Text("Loading foods...")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    Spacer()
                } else if let errorMessage = barcodeError {
                    Spacer()
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                            .padding()
                        Text("Error loading foods")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Try Again") {
                            performSearch()
                        }
                        .padding()
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 1) {
                            if searchText.isEmpty {
                                // Show either Meals view or Recently Added Foods
                                if showingMealsView {
                                    // Meals header with Create Meal button
                                    HStack {
                                        Text("Meals")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            HapticManager.shared.lightFeedback()
                                            showingCreateMeal = true
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 14, weight: .semibold))
                                                Text("Create Meal")
                                                    .font(.system(size: 16, weight: .semibold))
                                            }
                                            .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 16)
                                    .padding(.bottom, 12)
                                    
                                    // Saved meals list with swipe-to-delete
                                    ForEach(mealsManager.meals) { meal in
                                        SavedMealCard(
                                            meal: meal,
                                            mealType: mealType,
                                            selectedDate: selectedDate,
                                            onQuickAdd: {
                                                // Show toast notification
                                                toastMessage = "\(meal.name) added to \(mealType)"
                                                showToast = true
                                                
                                                // Hide toast after 2 seconds
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                                    showToast = false
                                                }
                                            }
                                        )
                                        .padding(.bottom, 8)
                                    }
                                    
                                } else if filteredFoods.isEmpty {
                                    // Empty state for recently added foods
                                    Spacer().frame(height: 100)
                                    VStack {
                                        Image(systemName: "clock")
                                            .font(.largeTitle)
                                            .foregroundColor(.gray)
                                            .padding()
                                        Text("No recently added foods")
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    // Recently Added Foods view
                                    Text("Recently Added Foods")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal)
                                        .padding(.top, 8)
                                    
                                    ForEach(filteredFoods) { food in
                                        FoodItemCard(
                                            food: food,
                                            mealType: mealType,
                                            selectedDate: selectedDate,
                                            onQuickAdd: {
                                                // Add to recent foods when quick added
                                                addToRecentFoods(food)
                                                
                                                // Show toast notification
                                                toastMessage = "\(food.name) added to \(mealType)"
                                                showToast = true
                                                
                                                // Hide toast after 2 seconds
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                                    showToast = false
                                                }
                                            },
                                            isCreatingMeal: isCreatingMeal,
                                            onFoodSelectedForMeal: onFoodSelectedForMeal
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            // Provide selection haptic feedback when tapping a food item
                                            HapticFeedback.shared.selectionFeedback()
                                            selectedFood = food
                                            showingFoodEntry = true
                                        }
                                    }
                                }
                            } else {
                                // User is typing or has submitted search
                                
                                // Always show History section if there are matching foods from food log
                                if !historyFoods.isEmpty {
                                    Text("History")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal)
                                        .padding(.top, 8)
                                    
                                    ForEach(historyFoods) { food in
                                        FoodItemCard(
                                            food: food,
                                            mealType: mealType,
                                            selectedDate: selectedDate,
                                            onQuickAdd: {
                                                // Add to recent foods when quick added
                                                addToRecentFoods(food)
                                                
                                                // Show toast notification
                                                toastMessage = "\(food.name) added to \(mealType)"
                                                showToast = true
                                                
                                                // Hide toast after 2 seconds
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                                    showToast = false
                                                }
                                            },
                                            isCreatingMeal: isCreatingMeal,
                                            onFoodSelectedForMeal: onFoodSelectedForMeal
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            // Provide selection haptic feedback when tapping a food item
                                            HapticFeedback.shared.selectionFeedback()
                                            selectedFood = food
                                            showingFoodEntry = true
                                        }
                                    }
                                    
                                    Spacer().frame(height: 8)
                                }
                                
                                // Show Suggested Searches OR Search Results based on submission state
                                if !hasSubmittedSearch {
                                    // User is still typing - show suggested searches inline
                                    if !filteredSuggestions.isEmpty {
                                        Text("Suggested Searches")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal)
                                            .padding(.top, historyFoods.isEmpty ? 8 : 0)
                                        
                                        ForEach(filteredSuggestions) { suggestion in
                                            Button(action: {
                                                HapticManager.shared.lightFeedback()
                                                searchText = suggestion.text
                                                hasSubmittedSearch = true
                                                suggestionService.addToRecentSearches(suggestion.text)
                                                performSearch()
                                            }) {
                                                HStack(spacing: 12) {
                                                    Image(systemName: suggestion.icon)
                                                        .font(.system(size: 16))
                                                        .foregroundColor(.gray)
                                                        .frame(width: 24)
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(suggestion.text)
                                                            .foregroundColor(.primary)
                                                            .lineLimit(1)
                                                        
                                                        if let subtitle = suggestion.subtitle, !subtitle.isEmpty {
                                                            Text(subtitle)
                                                                .font(.caption)
                                                                .foregroundColor(.secondary)
                                                                .lineLimit(1)
                                                        }
                                                    }
                                                    
                                                    Spacer()
                                                }
                                                .padding(.vertical, 12)
                                                .padding(.horizontal, 16)
                                            }
                                        }
                                    } else if historyFoods.isEmpty {
                                        // No history and no suggestions yet
                                        Spacer().frame(height: 60)
                                        VStack {
                                            Image(systemName: "magnifyingglass")
                                                .font(.largeTitle)
                                                .foregroundColor(.gray)
                                                .padding()
                                            Text("Press search to find foods")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                } else {
                                    // User has submitted search - show search results
                                    if isLoading {
                                        Spacer().frame(height: 40)
                                        HStack {
                                            Spacer()
                                            ProgressView()
                                                .padding(.trailing, 8)
                                            Text("Searching...")
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                    } else if !filteredFoods.isEmpty {
                                        Text("Search Results")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal)
                                            .padding(.top, historyFoods.isEmpty ? 8 : 0)
                                        
                                        ForEach(filteredFoods) { food in
                                            FoodItemCard(
                                                food: food,
                                                mealType: mealType,
                                                selectedDate: selectedDate,
                                                onQuickAdd: {
                                                    // Add to recent foods when quick added
                                                    addToRecentFoods(food)
                                                    
                                                    // Show toast notification
                                                    toastMessage = "\(food.name) added to \(mealType)"
                                                    showToast = true
                                                    
                                                    // Hide toast after 2 seconds
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                                        showToast = false
                                                    }
                                                },
                                                isCreatingMeal: isCreatingMeal,
                                                onFoodSelectedForMeal: onFoodSelectedForMeal
                                            )
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                // Provide selection haptic feedback when tapping a food item
                                                HapticFeedback.shared.selectionFeedback()
                                                selectedFood = food
                                                showingFoodEntry = true
                                            }
                                        }
                                    } else if historyFoods.isEmpty {
                                        // No results found
                                        Spacer().frame(height: 60)
                                        VStack {
                                            Image(systemName: "magnifyingglass")
                                                .font(.largeTitle)
                                                .foregroundColor(.gray)
                                                .padding()
                                            Text("No foods match your search")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            .navigationBarHidden(true)
            .background(viewBackground)
            .onAppear {
                // Store current meal type for search ranking
                UserDefaults.standard.set(mealType, forKey: "currentMealType")
                
                // Initialize suggestions
                suggestionService.getSuggestions(for: searchText)
                
                if searchText.isEmpty {
                    // Don't fetch all foods when search is empty
                    // Recent foods will be shown from UserDefaults
                } else {
                    performSearch()
                }
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                BarcodeScannerView(scannedBarcode: $scannedBarcode, isPresented: $showingBarcodeScanner)
            }
            .sheet(isPresented: $showingQuickAddView) {
                QuickAddFoodView(mealType: mealType, isPresented: $showingQuickAddView)
            }
            .sheet(isPresented: $showingAddFoodView) {
                AddFoodView(mealType: mealType, selectedDate: selectedDate)
            }
            .sheet(isPresented: $showingCreateMeal) {
                CreateMealBuilderView(mealType: mealType, selectedDate: selectedDate)
            }
            .navigationDestination(isPresented: $showingFoodEntry) {
                if !isCreatingMeal, let food = selectedFood {
                    // Normal flow - navigate to BasicFoodEntryView
                    BasicFoodEntryView(
                        food: food, 
                        mealType: mealType, 
                        selectedDate: selectedDate, 
                        onFoodAdded: { cachedFood in
                            // Add to recent foods with updated serving information
                            addToRecentFoods(cachedFood)
                            // Dismiss the view after adding the food
                            presentationMode.wrappedValue.dismiss()
                        },
                        showScanAgainButton: false,
                        editingEntry: nil,
                        initialServingSize: food.cachedServingSize,
                        initialServingUnit: food.cachedServingUnit,
                        initialNumberOfServings: food.cachedNumberOfServings,
                        initialSelectedServingSizeOption: food.cachedSelectedServingSizeOption
                    )
                } else {
                    // Fallback empty view if somehow food is nil
                    Text("No food selected")
                        .onAppear {
                            // Go back if no food is selected
                            showingFoodEntry = false
                        }
                }
            }
            .sheet(isPresented: Binding(
                get: { isCreatingMeal && showingFoodEntry },
                set: { if !$0 { showingFoodEntry = false } }
            )) {
                // Meal creation flow - show sheet instead of navigation
                if let food = selectedFood {
                    NavigationView {
                        BasicFoodEntryView(
                            food: food,
                            mealType: mealType,
                            selectedDate: selectedDate,
                            onFoodAdded: { cachedFood in
                                // Create FoodEntry from the cached food with serving info
                                if let onFoodSelectedForMeal = onFoodSelectedForMeal,
                                   let servingSize = cachedFood.cachedServingSize,
                                   let servingUnit = cachedFood.cachedServingUnit,
                                   let numberOfServings = cachedFood.cachedNumberOfServings {
                                    let foodEntry = FoodEntry(
                                        id: UUID(),
                                        foodItem: cachedFood,
                                        mealType: mealType,
                                        servingSize: servingSize,
                                        servingUnit: servingUnit,
                                        numberOfServings: numberOfServings,
                                        dateAdded: selectedDate
                                    )
                                    onFoodSelectedForMeal(foodEntry)
                                }
                                showingFoodEntry = false
                            },
                            showScanAgainButton: false,
                            isCreatingMeal: true,
                            editingEntry: nil,
                            initialServingSize: food.cachedServingSize,
                            initialServingUnit: food.cachedServingUnit,
                            initialNumberOfServings: food.cachedNumberOfServings,
                            initialSelectedServingSizeOption: food.cachedSelectedServingSizeOption
                        )
                    }
                }
            }
            } // Close ZStack
            .onChange(of: scannedBarcode) { oldBarcode, newBarcode in
                if let barcode = newBarcode {
                    handleScannedBarcode(barcode)
                    // Reset the barcode after handling
                    scannedBarcode = nil
                }
            }
            // Alert for barcode errors
            .alert(item: Binding<BarcodeError?>(get: {
                if let error = barcodeError {
                    return BarcodeError(message: error)
                }
                return nil
            }, set: { newValue in
                barcodeError = newValue?.message
            })) { error in
                Alert(
                    title: Text("Barcode Not Found"),
                    message: Text(error.message),
                    primaryButton: .default(Text("Add New Food")) {
                        showingAddFoodView = true
                    },
                    secondaryButton: .cancel(Text("OK"))
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .overlay(
            // Toast notification
            VStack {
                Spacer()
                if showToast {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text(toastMessage)
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#5ec5ff"))
                    .cornerRadius(25)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showToast)
                }
            }
            .padding(.bottom, 100) // Position above tab bar
        )
    }
}

// Food item card component with tap handling
struct TappableFoodItemCard: View {
    let food: FoodItem
    let onTap: (FoodItem) -> Void
    let position: Int?
    let analyticsService: AnalyticsService
    
    var body: some View {
        FoodItemCard(
            food: food,
            mealType: "Unknown",
            selectedDate: Date(),
            onQuickAdd: nil
        )
        .contentShape(Rectangle())
            .highPriorityGesture(TapGesture().onEnded { _ in
                // Track food search result tap
                if let position = position {
                    analyticsService.trackFoodSearchResultTapped(position: position, source: "typesense")
                }
                
                // Use high priority gesture to ensure it takes precedence over scroll gestures
                onTap(food)
            })
    }
}

// Food item card component
struct FoodItemCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let food: FoodItem
    let mealType: String
    let selectedDate: Date
    let onQuickAdd: (() -> Void)?
    var isCreatingMeal: Bool = false
    var onFoodSelectedForMeal: ((FoodEntry) -> Void)? = nil
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    @State private var showingFoodEntry = false
    
    // Format serving size to display nicely with 2 decimal places when needed
    private func formatServingSize(_ servingSize: String?) -> String {
        guard let servingSize = servingSize, !servingSize.isEmpty else {
            return "100g"
        }
        
        // Use regex to extract numeric values and units
        let pattern = "(\\d+(?:\\.\\d+)?)\\s*([a-zA-Z]+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = servingSize as NSString
            let matches = regex.matches(in: servingSize, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let match = matches.first {
                let valueRange = match.range(at: 1)
                let unitRange = match.range(at: 2)
                
                if valueRange.location != NSNotFound, unitRange.location != NSNotFound {
                    let valueStr = nsString.substring(with: valueRange)
                    let unitStr = nsString.substring(with: unitRange)
                    
                    if let value = Double(valueStr) {
                        // Format to 2 decimal places if needed, otherwise show as integer
                        let formattedValue = value.truncatingRemainder(dividingBy: 1) == 0 ? 
                            String(format: "%.0f", value) : String(format: "%.2f", value)
                        return "\(formattedValue)\(unitStr)"
                    }
                }
            }
        }
        
        // If we couldn't parse it, return the original string
        return servingSize
    }
    
    // Get color based on NOVA score (use predicted score if original is 0)
    private var novaScoreColor: Color {
        let displayScore = food.novaScore > 0 ? food.novaScore : NovaScoreService.shared.predictNovaScore(for: food)
        switch displayScore {
        case 1: return Color(hex: "#3f993f")  // Unprocessed - darker green
        case 2: return Color(hex: "#b7ce0d")  // Processed culinary ingredients - lime green
        case 3: return Color(hex: "#f28e16")  // Processed foods - orange
        case 4: return Color(hex: "#e4032f")  // Ultra-processed foods - bright red
        default: return .gray
        }
    }
    
    // Get color based on Nutri-Score grade
    private var nutriScoreColor: Color {
        switch food.nutriScoreGrade {
        case "a": return Color(hex: "#22e83d")  // Match NOVA Group 1 color
        case "b": return Color(hex: "#8eff00")  // Match NOVA Group 2 color
        case "c": return Color(hex: "#f4df70")  // Custom yellow color
        case "d": return Color(hex: "#ffb300")  // Match NOVA Group 3 color
        case "e": return Color(hex: "#ff5722")  // Match NOVA Group 4 color
        default: return .gray
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    // Brand name if available
                    if let brandName = food.brandName, !brandName.isEmpty {
                        Text(brandName)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    // Amount (default to 100g if no serving size specified)
                    if let brandName = food.brandName, !brandName.isEmpty {
                        // Add comma after brand name
                        Text(",")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    // Show cached serving info if available, otherwise default serving size
                    Text(displayServingSize())
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    // NOVA score if available (don't show for meals - only individual food items)
                    if !food.isMeal && (food.novaScore > 0 || NovaScoreService.shared.predictNovaScore(for: food) > 0) {
                        // Add comma before NOVA score
                        Text(",")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            
                        let displayNovaScore = food.novaScore > 0 ? food.novaScore : NovaScoreService.shared.predictNovaScore(for: food)
                        let isEstimated = food.novaScoreIsEstimated || food.novaScore == 0
                        Text("\(isEstimated ? "✨ " : "")NOVA \(displayNovaScore)")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(novaScoreColor)
                            .cornerRadius(4)
                    }
                    
                    // NutriScore grade if available
                    if let nutriGrade = food.nutriScoreGrade, !nutriGrade.isEmpty {
                        // Add comma before NutriScore grade
                        Text(",")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        Text("\(food.nutriScoreIsEstimated ? "✨ " : "")\(nutriGrade.uppercased())")
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
            
            // Calories and Quick Add Button
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(displayCalories()) kcal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Button(action: {
                    // Quick add - always add directly without opening entry view
                    // User can tap on the food item itself to edit servings
                    quickAddFood()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .withHapticFeedback()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 8)
        .frame(height: 72) // Maintain consistent height similar to rows
        .sheet(isPresented: $showingFoodEntry) {
            if isCreatingMeal {
                // Show BasicFoodEntryView for meal creation
                BasicFoodEntryView(
                    food: food,
                    mealType: mealType,
                    selectedDate: selectedDate,
                    onFoodAdded: { cachedFood in
                        // Create FoodEntry from the cached food with serving info
                        if let onFoodSelectedForMeal = onFoodSelectedForMeal,
                           let servingSize = cachedFood.cachedServingSize,
                           let servingUnit = cachedFood.cachedServingUnit,
                           let numberOfServings = cachedFood.cachedNumberOfServings {
                            let foodEntry = FoodEntry(
                                id: UUID(),
                                foodItem: cachedFood,
                                mealType: mealType,
                                servingSize: servingSize,
                                servingUnit: servingUnit,
                                numberOfServings: numberOfServings,
                                dateAdded: selectedDate
                            )
                            onFoodSelectedForMeal(foodEntry)
                        }
                        showingFoodEntry = false
                    },
                    showScanAgainButton: false,
                    isCreatingMeal: true,
                    editingEntry: nil,
                    initialServingSize: food.cachedServingSize,
                    initialServingUnit: food.cachedServingUnit,
                    initialNumberOfServings: food.cachedNumberOfServings,
                    initialSelectedServingSizeOption: food.cachedSelectedServingSizeOption
                )
            }
        }
    }
    
    // Display serving size - either cached or original
    private func displayServingSize() -> String {
        print("🔍 displayServingSize for \(food.name):")
        print("   - cachedServingSize: \(food.cachedServingSize ?? 0)")
        print("   - cachedServingUnit: \(food.cachedServingUnit ?? "nil")")
        print("   - cachedNumberOfServings: \(food.cachedNumberOfServings ?? 0)")
        print("   - cachedSelectedServingSizeOption: \(food.cachedSelectedServingSizeOption ?? "nil")")
        
        if let cachedSize = food.cachedServingSize,
           let cachedUnit = food.cachedServingUnit,
           let cachedServings = food.cachedNumberOfServings {
            // Show the total consumed amount (serving size × number of servings)
            let totalSize = cachedSize * cachedServings
            let formattedSize = totalSize.truncatingRemainder(dividingBy: 1) == 0 ? 
                String(format: "%.0f", totalSize) : String(format: "%.1f", totalSize)
            let result = "\(formattedSize)\(cachedUnit)"
            print("   - using cached total: \(result)")
            return result
        } else if let cachedSize = food.cachedServingSize,
                  let cachedUnit = food.cachedServingUnit,
                  let cachedServings = food.cachedNumberOfServings {
            // Fallback: Show total consumed amount (serving size × number of servings)
            let totalSize = cachedSize * cachedServings
            let formattedSize = totalSize.truncatingRemainder(dividingBy: 1) == 0 ? 
                String(format: "%.0f", totalSize) : String(format: "%.1f", totalSize)
            let result = "\(formattedSize)\(cachedUnit)"
            print("   - using cached fallback: \(result)")
            return result
        } else {
            // Try to extract grams from serving size string (e.g., "1 serving (180 g)" -> "180g")
            if let servingSize = food.servingSize, !servingSize.isEmpty {
                // Look for pattern like "(180 g)" or "(180g)"
                let pattern = "\\((\\d+(?:\\.\\d+)?)\\s*g\\)"
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let nsString = servingSize as NSString
                    if let match = regex.firstMatch(in: servingSize, options: [], range: NSRange(location: 0, length: nsString.length)) {
                        let valueRange = match.range(at: 1)
                        if valueRange.location != NSNotFound {
                            let valueStr = nsString.substring(with: valueRange)
                            if let value = Double(valueStr) {
                                let formattedValue = value.truncatingRemainder(dividingBy: 1) == 0 ? 
                                    String(format: "%.0f", value) : String(format: "%.1f", value)
                                let result = "\(formattedValue)g"
                                print("   - extracted grams from parentheses: \(result)")
                                return result
                            }
                        }
                    }
                }
            }
            
            // Show original serving size formatted
            let result = formatServingSize(food.servingSize)
            print("   - using original: \(result)")
            return result
        }
    }
    
    // Display calories using the centralized NutritionCalculator
    private func displayCalories() -> Int {
        // Extract serving size and unit from the food item
        var servingSize: Double = 100.0 // Default to 100g
        var servingUnit: String = "g"  // Default to grams
        var numberOfServings: Double = 1.0
        var isOriginalServingSize: Bool = false
        
        if let cachedSize = food.cachedServingSize,
           let cachedUnit = food.cachedServingUnit,
           let cachedServings = food.cachedNumberOfServings {
            // Use cached values
            servingSize = cachedSize
            servingUnit = cachedUnit
            numberOfServings = cachedServings
            
            // Check if this matches the original serving size
            if let originalServingSize = food.servingSize, !originalServingSize.isEmpty {
                let originalLower = originalServingSize.lowercased()
                let currentSize = String(format: "%.1f", servingSize).replacingOccurrences(of: ".0", with: "")
                let currentUnit = servingUnit.lowercased()
                
                isOriginalServingSize = originalLower.contains(currentSize) && originalLower.contains(currentUnit)
            }
        } else if let originalServingSize = food.servingSize, !originalServingSize.isEmpty {
            // If no cached values, try to extract from original serving size using the same logic as BasicFoodEntryView
            isOriginalServingSize = true
            
            // Use the same extraction logic as NutritionCalculator.extractWeightFromServingSize
            if let (weight, unit) = NutritionCalculator.extractWeightFromServingSize(originalServingSize) {
                servingSize = weight
                servingUnit = unit
            } else {
                // Fallback: assume it's 1 serving of whatever the description says
                servingSize = 1.0
                servingUnit = "g"
            }
        }
        
        // Use the NutritionCalculator to calculate calories
        return NutritionCalculator.calculateCalories(
            foodCalories: food.calories,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isOriginalServingSize,
            servingDescription: food.servingSize,
            servingQuantity: food.servingsPerPackage
        )
    }
    
    // Quick add functionality
    private func quickAddFood() {
        // Extract serving information from the display
        var servingSize: Double = 100.0
        var servingUnit: String = "g"
        var numberOfServings: Double = 1.0
        
        // Use cached values if available, otherwise extract from original serving size
        if let cachedSize = food.cachedServingSize,
           let cachedUnit = food.cachedServingUnit,
           let cachedServings = food.cachedNumberOfServings {
            servingSize = cachedSize
            servingUnit = cachedUnit
            numberOfServings = cachedServings
        } else if let originalServingSize = food.servingSize, !originalServingSize.isEmpty {
            // Extract from original serving size using NutritionCalculator
            if let (weight, unit) = NutritionCalculator.extractWeightFromServingSize(originalServingSize) {
                servingSize = weight
                servingUnit = unit
                numberOfServings = 1.0
            }
        }
        
        // Create food item with predicted NOVA score if original is 0
        var foodItemToAdd = food
        if food.novaScore == 0 {
            let predictedNova = NovaScoreService.shared.predictNovaScore(for: food)
            if predictedNova > 0 {
                // Create a new FoodItem with the predicted NOVA score
                foodItemToAdd = FoodItem(
                    name: food.name,
                    brandName: food.brandName,
                    barcode: food.barcode,
                    calories: food.calories,
                    protein: food.protein,
                    carbs: food.carbs,
                    fat: food.fat,
                    novaScore: predictedNova,
                    novaScoreIsEstimated: true,
                    nutriScoreGrade: food.nutriScoreGrade,
                    nutriScoreIsEstimated: food.nutriScoreIsEstimated,
                    servingSize: food.servingSize,
                    servingsPerPackage: food.servingsPerPackage,
                    servingType: food.servingType,
                    fiber: food.fiber,
                    sugar: food.sugar,
                    sodium: food.sodium,
                    saturatedFat: food.saturatedFat,
                    ingredients: food.ingredients,
                    cachedServingSize: food.cachedServingSize,
                    cachedServingUnit: food.cachedServingUnit,
                    cachedNumberOfServings: food.cachedNumberOfServings,
                    cachedSelectedServingSizeOption: food.cachedSelectedServingSizeOption,
                    countries: food.countries,
                    purchasePlaces: food.purchasePlaces,
                    origins: food.origins
                )
            }
        }
        
        // Check if we're creating a meal or adding to food log
        if isCreatingMeal, let onFoodSelectedForMeal = onFoodSelectedForMeal {
            // Creating a meal - pass the food entry to the meal builder
            let foodEntry = FoodEntry(
                id: UUID(),
                foodItem: foodItemToAdd,
                mealType: mealType,
                servingSize: servingSize,
                servingUnit: servingUnit,
                numberOfServings: numberOfServings,
                dateAdded: selectedDate
            )
            onFoodSelectedForMeal(foodEntry)
        } else {
            // Normal flow - add to food log
            foodLogManager.addEntry(
                foodItem: foodItemToAdd,
                mealType: mealType,
                servingSize: servingSize,
                servingUnit: servingUnit,
                numberOfServings: numberOfServings,
                date: selectedDate
            )
        }
        
        // Provide haptic feedback
        HapticManager.shared.successFeedback()
        
        // Call the completion handler if provided (but not when creating a meal - toast is handled by MealFoodPickerView)
        if !isCreatingMeal {
            onQuickAdd?()
        }
        
        print("🍽️ Quick added \(food.name) to \(mealType): \(numberOfServings) × \(servingSize)\(servingUnit)")
    }
}

// Food item model
public struct FoodItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let name: String
    public let brandName: String?
    public let barcode: String?
    public let calories: Int
    public let protein: Double
    public let carbs: Double
    public let fat: Double
    public let novaScore: Int
    public let novaScoreIsEstimated: Bool
    public let nutriScoreGrade: String?
    public let nutriScoreIsEstimated: Bool
    public let servingSize: String?
    public let servingsPerPackage: Double?
    public let servingType: String?
    
    // Additional nutritional information
    public let fiber: Double?
    public let sugar: Double?
    public let sodium: Double?
    public let saturatedFat: Double?
    
    // Ingredients list for diversity tracking
    public let ingredients: String?
    
    // Cached serving information for recently added foods
    public let cachedServingSize: Double?
    public let cachedServingUnit: String?
    public let cachedNumberOfServings: Double?
    public let cachedSelectedServingSizeOption: String?
    
    // Region information for location-based search
    public let countries: [String]?
    public let purchasePlaces: String?
    public let origins: String?
    
    // Flag to identify if this is a saved meal (not a regular food item)
    public let isMeal: Bool
    
    public init(name: String, brandName: String? = nil, barcode: String? = nil, calories: Int, protein: Double, carbs: Double, fat: Double, novaScore: Int = 0, novaScoreIsEstimated: Bool = false, nutriScoreGrade: String? = nil, nutriScoreIsEstimated: Bool = false, servingSize: String? = nil, servingsPerPackage: Double? = nil, servingType: String? = nil, fiber: Double? = nil, sugar: Double? = nil, sodium: Double? = nil, saturatedFat: Double? = nil, ingredients: String? = nil, cachedServingSize: Double? = nil, cachedServingUnit: String? = nil, cachedNumberOfServings: Double? = nil, cachedSelectedServingSizeOption: String? = nil, countries: [String]? = nil, purchasePlaces: String? = nil, origins: String? = nil, isMeal: Bool = false) {
        self.id = UUID()
        self.name = name
        self.brandName = brandName
        self.barcode = barcode
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.novaScore = novaScore
        self.novaScoreIsEstimated = novaScoreIsEstimated
        self.nutriScoreGrade = nutriScoreGrade
        self.nutriScoreIsEstimated = nutriScoreIsEstimated
        self.servingSize = servingSize
        self.servingsPerPackage = servingsPerPackage
        self.servingType = servingType
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
        self.saturatedFat = saturatedFat
        self.ingredients = ingredients
        self.cachedServingSize = cachedServingSize
        self.cachedServingUnit = cachedServingUnit
        self.cachedNumberOfServings = cachedNumberOfServings
        self.cachedSelectedServingSizeOption = cachedSelectedServingSizeOption
        self.countries = countries
        self.purchasePlaces = purchasePlaces
        self.origins = origins
        self.isMeal = isMeal
    }
    
    // Codable implementation
    enum CodingKeys: String, CodingKey {
        case id, name, brandName, barcode, calories, protein, carbs, fat, novaScore, novaScoreIsEstimated, nutriScoreGrade, nutriScoreIsEstimated, servingSize, servingsPerPackage, servingType, fiber, sugar, sodium, saturatedFat, ingredients, cachedServingSize, cachedServingUnit, cachedNumberOfServings, cachedSelectedServingSizeOption, countries, purchasePlaces, origins, isMeal
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        brandName = try container.decodeIfPresent(String.self, forKey: .brandName)
        barcode = try container.decodeIfPresent(String.self, forKey: .barcode)
        calories = try container.decode(Int.self, forKey: .calories)
        protein = try container.decode(Double.self, forKey: .protein)
        carbs = try container.decode(Double.self, forKey: .carbs)
        fat = try container.decode(Double.self, forKey: .fat)
        novaScore = try container.decodeIfPresent(Int.self, forKey: .novaScore) ?? 0
        novaScoreIsEstimated = try container.decodeIfPresent(Bool.self, forKey: .novaScoreIsEstimated) ?? false
        nutriScoreGrade = try container.decodeIfPresent(String.self, forKey: .nutriScoreGrade)
        nutriScoreIsEstimated = try container.decodeIfPresent(Bool.self, forKey: .nutriScoreIsEstimated) ?? false
        servingSize = try container.decodeIfPresent(String.self, forKey: .servingSize)
        servingsPerPackage = try container.decodeIfPresent(Double.self, forKey: .servingsPerPackage)
        servingType = try container.decodeIfPresent(String.self, forKey: .servingType)
        fiber = try container.decodeIfPresent(Double.self, forKey: .fiber)
        sugar = try container.decodeIfPresent(Double.self, forKey: .sugar)
        sodium = try container.decodeIfPresent(Double.self, forKey: .sodium)
        saturatedFat = try container.decodeIfPresent(Double.self, forKey: .saturatedFat)
        ingredients = try container.decodeIfPresent(String.self, forKey: .ingredients)
        cachedServingSize = try container.decodeIfPresent(Double.self, forKey: .cachedServingSize)
        cachedServingUnit = try container.decodeIfPresent(String.self, forKey: .cachedServingUnit)
        cachedNumberOfServings = try container.decodeIfPresent(Double.self, forKey: .cachedNumberOfServings)
        cachedSelectedServingSizeOption = try container.decodeIfPresent(String.self, forKey: .cachedSelectedServingSizeOption)
        countries = try container.decodeIfPresent([String].self, forKey: .countries)
        purchasePlaces = try container.decodeIfPresent(String.self, forKey: .purchasePlaces)
        origins = try container.decodeIfPresent(String.self, forKey: .origins)
        isMeal = try container.decodeIfPresent(Bool.self, forKey: .isMeal) ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(brandName, forKey: .brandName)
        try container.encodeIfPresent(barcode, forKey: .barcode)
        try container.encode(calories, forKey: .calories)
        try container.encode(protein, forKey: .protein)
        try container.encode(carbs, forKey: .carbs)
        try container.encode(fat, forKey: .fat)
        try container.encode(novaScore, forKey: .novaScore)
        try container.encode(novaScoreIsEstimated, forKey: .novaScoreIsEstimated)
        try container.encodeIfPresent(nutriScoreGrade, forKey: .nutriScoreGrade)
        try container.encode(nutriScoreIsEstimated, forKey: .nutriScoreIsEstimated)
        try container.encodeIfPresent(servingSize, forKey: .servingSize)
        try container.encodeIfPresent(servingsPerPackage, forKey: .servingsPerPackage)
        try container.encodeIfPresent(servingType, forKey: .servingType)
        try container.encodeIfPresent(fiber, forKey: .fiber)
        try container.encodeIfPresent(sugar, forKey: .sugar)
        try container.encodeIfPresent(sodium, forKey: .sodium)
        try container.encodeIfPresent(saturatedFat, forKey: .saturatedFat)
        try container.encodeIfPresent(ingredients, forKey: .ingredients)
        try container.encodeIfPresent(cachedServingSize, forKey: .cachedServingSize)
        try container.encodeIfPresent(cachedServingUnit, forKey: .cachedServingUnit)
        try container.encodeIfPresent(cachedNumberOfServings, forKey: .cachedNumberOfServings)
        try container.encodeIfPresent(cachedSelectedServingSizeOption, forKey: .cachedSelectedServingSizeOption)
        try container.encodeIfPresent(countries, forKey: .countries)
        try container.encodeIfPresent(purchasePlaces, forKey: .purchasePlaces)
        try container.encodeIfPresent(origins, forKey: .origins)
        try container.encode(isMeal, forKey: .isMeal)
    }
}

// Food item row component
struct FoodItemRow: View {
    let food: FoodItem
    @StateObject private var visibilityService = MetricVisibilityService.shared
    
    // Format serving size to display nicely with 2 decimal places when needed
    private func formatServingSize(_ servingSize: String?) -> String {
        guard let servingSize = servingSize, !servingSize.isEmpty else {
            return "100g"
        }
        
        // Use regex to extract numeric values and units
        let pattern = "(\\d+(?:\\.\\d+)?)\\s*([a-zA-Z]+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = servingSize as NSString
            let matches = regex.matches(in: servingSize, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let match = matches.first {
                let valueRange = match.range(at: 1)
                let unitRange = match.range(at: 2)
                
                if valueRange.location != NSNotFound, unitRange.location != NSNotFound {
                    let valueStr = nsString.substring(with: valueRange)
                    let unitStr = nsString.substring(with: unitRange)
                    
                    if let value = Double(valueStr) {
                        // Format to 2 decimal places if needed, otherwise show as integer
                        let formattedValue = value.truncatingRemainder(dividingBy: 1) == 0 ? 
                            String(format: "%.0f", value) : String(format: "%.2f", value)
                        return "\(formattedValue)\(unitStr)"
                    }
                }
            }
        }
        
        // If we couldn't parse it, return the original string
        return servingSize
    }
    
    // Get color based on NOVA score (use predicted score if original is 0)
    private var novaScoreColor: Color {
        let displayScore = food.novaScore > 0 ? food.novaScore : NovaScoreService.shared.predictNovaScore(for: food)
        switch displayScore {
        case 1: return Color(hex: "#3f993f")  // Unprocessed - darker green
        case 2: return Color(hex: "#b7ce0d")  // Processed culinary ingredients - lime green
        case 3: return Color(hex: "#f28e16")  // Processed foods - orange
        case 4: return Color(hex: "#e4032f")  // Ultra-processed foods - bright red
        default: return .gray
        }
    }
    
    // Get color based on Nutri-Score grade
    private var nutriScoreColor: Color {
        switch food.nutriScoreGrade {
        case "a": return Color(hex: "#22e83d")  // Match NOVA Group 1 color
        case "b": return Color(hex: "#8eff00")  // Match NOVA Group 2 color
        case "c": return Color(hex: "#f4df70")  // Custom yellow color
        case "d": return Color(hex: "#ffb300")  // Match NOVA Group 3 color
        case "e": return Color(hex: "#ff5722")  // Match NOVA Group 4 color
        default: return .gray
        }
    }
    
    // Get description based on NOVA score
    private var novaScoreDescription: String {
        switch food.novaScore {
        case 1: return "Unprocessed"
        case 2: return "Processed ingredients"
        case 3: return "Processed"
        case 4: return "Ultra-processed"
        default: return "Unknown"
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    // Brand name if available
                    if let brandName = food.brandName, !brandName.isEmpty {
                        Text(brandName)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    // Amount (default to 100g if no serving size specified)
                    if let brandName = food.brandName, !brandName.isEmpty {
                        // Add comma after brand name
                        Text(",")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    // Show default amount or serving size with formatted numbers
                    Text(formatServingSize(food.servingSize))
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    // NOVA score if available and visible
                    if visibilityService.showNovaScore && (food.novaScore > 0 || NovaScoreService.shared.predictNovaScore(for: food) > 0) {
                        // Add comma before NOVA score
                        Text(",")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            
                        let displayNovaScore = food.novaScore > 0 ? food.novaScore : NovaScoreService.shared.predictNovaScore(for: food)
                        let isEstimated = food.novaScoreIsEstimated || food.novaScore == 0
                        Text("\(isEstimated ? "✨ " : "")NOVA \(displayNovaScore)")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(novaScoreColor)
                            .cornerRadius(4)
                    }
                    
                    // NutriScore grade if available and visible
                    if visibilityService.showNutriScore, let nutriGrade = food.nutriScoreGrade, !nutriGrade.isEmpty {
                        // Add comma before NutriScore grade
                        Text(",")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            
                        Text("\(food.nutriScoreIsEstimated ? "✨ " : "")\(nutriGrade.uppercased())")
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
            
            // Only show calories if visibility is enabled
            if visibilityService.showCalories {
                Text("\(calculateDefaultServingCalories(for: food)) kcal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// Food detail view for showing more information
struct FoodDetailView: View {
    let food: FoodItem
    @State private var showingNutritionInfo = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Basic food info
                VStack(alignment: .leading, spacing: 8) {
                    Text(food.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let brand = food.brandName {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Nutrition summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nutrition Summary")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        NutrientCircle(value: food.calories, label: "Calories", unit: "kcal")
                        NutrientCircle(value: Int(food.protein), label: "Protein", unit: "g")
                        NutrientCircle(value: Int(food.carbs), label: "Carbs", unit: "g")
                        NutrientCircle(value: Int(food.fat), label: "Fat", unit: "g")
                    }
                }
                
                // Food quality indicators
                HStack(spacing: 16) {
                    if food.novaScore > 0 {
                        FoodQualityIndicator(
                            title: "NOVA Score",
                            value: "\(food.novaScore)",
                            description: getNovaDescription(score: food.novaScore),
                            color: getNovaColor(score: food.novaScore)
                        )
                    }
                    
                    if let nutriGrade = food.nutriScoreGrade {
                        FoodQualityIndicator(
                            title: "Nutri-Score",
                            value: nutriGrade.uppercased(),
                            description: getNutriScoreDescription(grade: nutriGrade),
                            color: getNutriScoreColor(grade: nutriGrade)
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // Helper functions for NOVA score
    private func getNovaColor(score: Int) -> Color {
        switch score {
        case 1: return .green
        case 2: return .blue
        case 3: return .orange
        case 4: return .red
        default: return .gray
        }
    }
    
    private func getNovaDescription(score: Int) -> String {
        switch score {
        case 1: return "Unprocessed or minimally processed foods"
        case 2: return "Processed culinary ingredients"
        case 3: return "Processed foods"
        case 4: return "Ultra-processed foods"
        default: return "Unknown"
        }
    }
    
    // Helper functions for Nutri-Score
    private func getNutriScoreColor(grade: String) -> Color {
        switch grade.lowercased() {
        case "a": return .green
        case "b": return .blue
        case "c": return .yellow
        case "d": return .orange
        case "e": return .red
        default: return .gray
        }
    }
    
    private func getNutriScoreDescription(grade: String) -> String {
        switch grade.lowercased() {
        case "a": return "Excellent nutritional quality"
        case "b": return "Good nutritional quality"
        case "c": return "Average nutritional quality"
        case "d": return "Poor nutritional quality"
        case "e": return "Very poor nutritional quality"
        default: return "Unknown"
        }
    }
}

#Preview {
    NavigationView {
        FoodSearchView(mealType: "Breakfast", selectedDate: Date())
    }
}

// Helper component for displaying nutrient values in circles
struct NutrientCircle: View {
    let value: Int
    let label: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                VStack(spacing: 0) {
                    Text("\(value)")
                        .font(.system(size: 18, weight: .bold))
                    
                    Text(unit)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// Component for displaying food quality indicators like NOVA score and Nutri-Score
struct FoodQualityIndicator: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let description: String
    let color: Color
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(value)
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color.opacity(0.2))
                    )
                    .foregroundColor(color)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}

// Saved Meal Card Component
struct SavedMealCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let meal: SavedMeal
    let mealType: String
    let selectedDate: Date
    let onQuickAdd: () -> Void
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    @ObservedObject private var mealsManager = SavedMealsManager.shared
    @State private var showingEditMeal = false
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button (revealed on swipe)
            Button(action: {
                // Provide haptic feedback
                HapticManager.shared.mediumFeedback()
                // Delete the meal immediately
                withAnimation {
                    mealsManager.deleteMeal(meal)
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                    Text("Delete")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(width: 90)
                .frame(maxHeight: .infinity)
                .background(Color.red)
                .cornerRadius(12)
            }
            .opacity(offset < -60 ? 1 : 0)
            .padding(.horizontal, 8)
            
            // Meal card content
            Button(action: {
                if !isSwiping {
                    showingEditMeal = true
                }
            }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    // Meal info
                    VStack(alignment: .leading, spacing: 4) {
                        // Meal name
                        Text(meal.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        // Food count
                        Text("\(meal.foods.count) item\(meal.foods.count == 1 ? "" : "s")")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Calories and quick add button
                    HStack(spacing: 12) {
                        Text("\(meal.totalCalories) kcal")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Button(action: {
                            quickAddMeal()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                
                // Macros row
                HStack(spacing: 16) {
                    MacroLabel(value: meal.totalProtein, label: "Protein", color: .green)
                    MacroLabel(value: meal.totalCarbs, label: "Carbs", color: .orange)
                    MacroLabel(value: meal.totalFat, label: "Fats", color: .pink)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
            .padding(.horizontal, 8)
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onChanged { gesture in
                        let translation = gesture.translation.width
                        let verticalTranslation = gesture.translation.height
                        
                        // Only allow left swipe when clearly horizontal
                        if translation < 0 && abs(verticalTranslation) < abs(translation) * 0.3 {
                            isSwiping = true
                            withAnimation(.interactiveSpring()) {
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
        .sheet(isPresented: $showingEditMeal) {
            EditMealView(meal: meal)
        }
    }
    
    private func quickAddMeal() {
        // Add each food from the meal as individual entries
        for mealFood in meal.foods {
            // MealFood stores total nutrition values for the total amount
            // To reconstruct a proper FoodItem (which stores per-100g), calculate per-100g values
            let per100gCalories = mealFood.servingSize > 0 ? Int(Double(mealFood.calories) / (mealFood.servingSize * mealFood.numberOfServings) * 100.0) : mealFood.calories
            let per100gProtein = mealFood.servingSize > 0 ? mealFood.protein / (mealFood.servingSize * mealFood.numberOfServings) * 100.0 : mealFood.protein
            let per100gCarbs = mealFood.servingSize > 0 ? mealFood.carbs / (mealFood.servingSize * mealFood.numberOfServings) * 100.0 : mealFood.carbs
            let per100gFat = mealFood.servingSize > 0 ? mealFood.fat / (mealFood.servingSize * mealFood.numberOfServings) * 100.0 : mealFood.fat
            
            let foodItem = FoodItem(
                name: mealFood.foodName,
                brandName: mealFood.brandName,
                barcode: nil,
                calories: per100gCalories,
                protein: per100gProtein,
                carbs: per100gCarbs,
                fat: per100gFat,
                novaScore: mealFood.novaScore,
                novaScoreIsEstimated: mealFood.novaScoreIsEstimated,
                nutriScoreGrade: mealFood.nutriScoreGrade,
                nutriScoreIsEstimated: mealFood.nutriScoreIsEstimated,
                servingSize: "\(Int(mealFood.servingSize))\(mealFood.servingUnit)",
                servingsPerPackage: nil,
                isMeal: false
            )
            
            // Add each food with its stored serving info from the meal
            foodLogManager.addEntry(
                foodItem: foodItem,
                mealType: mealType,
                servingSize: mealFood.servingSize,
                servingUnit: mealFood.servingUnit,
                numberOfServings: mealFood.numberOfServings,
                date: selectedDate
            )
        }
        
        // Provide haptic feedback
        HapticManager.shared.successFeedback()
        
        // Call completion handler
        onQuickAdd()
    }
}

// Simple macro label component for meal cards
struct MacroLabel: View {
    let value: Double
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text("\(Int(value))g")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}
