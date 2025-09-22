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
                        // Calculate calories based on the serving weight (assuming food.calories is per 100g)
                        let caloriesPerGram = Double(food.calories) / 100.0
                        return Int(round(caloriesPerGram * servingWeight))
                    }
                }
            }
            
            // If no weight found in parentheses, return the base calories (likely per 100g)
            return food.calories
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
                        let caloriesPerGram = Double(food.calories) / 100.0
                        return Int(round(caloriesPerGram * servingSize))
                    }
                    // For ml, assume similar density to water (1ml ≈ 1g for most liquids)
                    else if unitStr == "ml" {
                        let caloriesPerGram = Double(food.calories) / 100.0
                        return Int(round(caloriesPerGram * servingSize))
                    }
                }
            }
        }
    }
    
    // If no serving size or couldn't parse it, return the base calories
    return food.calories
}

// Haptic feedback manager for search interactions
class HapticFeedback {
    static let shared = HapticFeedback()
    
    private init() {}
    
    // Ultra light feedback for typing (very subtle)
    func ultraLightFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.3) // Reduced intensity for an even lighter touch
    }
    
    // Light feedback for typing
    func lightFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // Selection feedback for when an item is selected
    func selectionFeedback() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

struct FoodSearchView: View {
    let mealType: String
    let selectedDate: Date
    @StateObject private var typesenseService = TypesenseDirectService.shared
    @StateObject private var suggestionService = SearchSuggestionService.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    @State private var searchText = ""
    @State private var searchTask: DispatchWorkItem?
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
    
    // Timer for search debouncing
    @State private var searchDebounceTimer: Timer?
    
    // State variables for UI management
    
    // State for search indicators - no longer used with Typesense-only search
    // These are kept for future reintegration of Supabase search
    // @State private var isFuzzySearchActive = false
    // @State private var isSemanticSearchActive = false
    
    // State for search suggestions
    @State private var showSuggestions = false
    
    // Keys for storing data in UserDefaults
    private let recentFoodsKey = "recentlyAddedFoods"
    private let maxRecentFoods = 30
    
    // Get recent foods from UserDefaults
    private var recentFoods: [FoodItem] {
        if let data = UserDefaults.standard.data(forKey: recentFoodsKey),
           let foods = try? JSONDecoder().decode([FoodItem].self, from: data) {
            return foods
        }
        return []
    }
    
    // Computed property for filtered foods
    private var filteredFoods: [FoodItem] {
        if searchText.isEmpty {
            // Show recent foods when no search
            return recentFoods
        } else {
            // Show search results
            return foodItems
        }
    }
    
    // Get recently added foods from UserDefaults
    private func getRecentFoods() -> [FoodItem] {
        guard let data = UserDefaults.standard.data(forKey: recentFoodsKey),
              let recentFoods = try? JSONDecoder().decode([FoodItem].self, from: data) else {
            return []
        }
        return recentFoods
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
            
            // Perform search using Typesense
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
                            .foregroundColor(.blue)
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
                                .onChange(of: searchText) { _, newValue in
                                    // Provide haptic feedback when typing
                                    HapticFeedback.shared.lightFeedback()
                                    showSuggestions = !newValue.isEmpty
                                    suggestionService.getSuggestions(for: newValue)
                                    performSearch()
                                }
                                
                                if !searchText.isEmpty {
                                    Button(action: {
                                        HapticManager.shared.lightFeedback()
                                        searchText = ""
                                        showSuggestions = false
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
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 4)
                                }
                                .withHapticFeedback()
                            }
                            .padding(8)
                            .background(Color(.systemGray5))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        // Search suggestions
                        if showSuggestions && !suggestionService.suggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(suggestionService.suggestions, id: \.self) { suggestion in
                                    Button(action: {
                                        HapticManager.shared.lightFeedback()
                                        searchText = suggestion
                                        showSuggestions = false
                                        suggestionService.addToRecentSearches(suggestion)
                                        performSearch()
                                    }) {
                                        HStack {
                                            Image(systemName: "magnifyingglass")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                            Text(suggestion)
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                    }
                                    .background(Color(.systemGray6))
                                    
                                    if suggestion != suggestionService.suggestions.last {
                                        Divider()
                                            .padding(.leading, 40)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
                            )
                            .padding(.horizontal)
                            .transition(.opacity)
                            .zIndex(1)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // Quick add button - only show when search text is empty
                    if searchText.isEmpty {
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
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                        }
                        
                        // Quick Add button padding
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
                } else if isLoading {
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
                } else if filteredFoods.isEmpty {
                    Spacer()
                    VStack {
                        Image(systemName: searchText.isEmpty ? "clock" : "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                            .padding()
                        Text(searchText.isEmpty ? "No recently added foods" : "No foods match your search")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 1) {
                            if searchText.isEmpty {
                                Text("Recently Added Foods")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                
                                ForEach(filteredFoods) { food in
                                    FoodItemCard(food: food)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            // Provide selection haptic feedback when tapping a food item
                                            HapticFeedback.shared.selectionFeedback()
                                            selectedFood = food
                                            showingFoodEntry = true
                                        }
                                }
                            } else {
                                Text("Search Results")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                
                                ForEach(filteredFoods) { food in
                                    FoodItemCard(food: food)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            // Provide selection haptic feedback when tapping a food item
                                            HapticFeedback.shared.selectionFeedback()
                                            selectedFood = food
                                            showingFoodEntry = true
                                        }
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemGray6))
            .onAppear {
                // Store current meal type for search ranking
                UserDefaults.standard.set(mealType, forKey: "currentMealType")
                
                // Initialize suggestions
                suggestionService.getSuggestions(for: searchText)
                
                if searchText.isEmpty {
                    // Don't fetch all foods when search is empty
                    // Recent foods will be shown from UserDefaults
                } else {
                    // Use Typesense search instead of Supabase
                    performSearch()
                }
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                BarcodeScannerView(scannedBarcode: $scannedBarcode, isPresented: $showingBarcodeScanner)
            }
            .sheet(isPresented: $showingQuickAddView) {
                QuickAddFoodView(mealType: mealType, isPresented: $showingQuickAddView)
            }
            .navigationDestination(isPresented: $showingFoodEntry) {
                if let food = selectedFood {
                    BasicFoodEntryView(
                        food: food, 
                        mealType: mealType, 
                        selectedDate: selectedDate, 
                        onFoodAdded: addToRecentFoods,
                        showScanAgainButton: scannedBarcode != nil,
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
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// Food item card component with tap handling
struct TappableFoodItemCard: View {
    let food: FoodItem
    let onTap: (FoodItem) -> Void
    let position: Int?
    let analyticsService: AnalyticsService
    
    var body: some View {
        FoodItemCard(food: food)
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
    let food: FoodItem
    
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
    
    // Get color based on NOVA score
    private var novaScoreColor: Color {
        switch food.novaScore {
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
                    
                    // NOVA score if available
                    if food.novaScore > 0 || NovaScoreService.shared.predictNovaScore(for: food) > 0 {
                        // Add comma before NOVA score
                        Text(",")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            
                        let displayNovaScore = food.novaScore > 0 ? food.novaScore : NovaScoreService.shared.predictNovaScore(for: food)
                        Text("NOVA \(displayNovaScore)")
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
                            
                        Text(nutriGrade.uppercased())
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
            
            // Calories
            VStack(alignment: .trailing) {
                Text("\(displayCalories()) kcal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 8)
        .frame(height: 72) // Maintain consistent height similar to rows
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
            // Show original serving size
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
    public let nutriScoreGrade: String?
    public let servingSize: String?
    public let servingsPerPackage: Double?
    public let servingType: String?
    
    // Cached serving information for recently added foods
    public let cachedServingSize: Double?
    public let cachedServingUnit: String?
    public let cachedNumberOfServings: Double?
    public let cachedSelectedServingSizeOption: String?
    
    public init(name: String, brandName: String? = nil, barcode: String? = nil, calories: Int, protein: Double, carbs: Double, fat: Double, novaScore: Int = 0, nutriScoreGrade: String? = nil, servingSize: String? = nil, servingsPerPackage: Double? = nil, servingType: String? = nil, cachedServingSize: Double? = nil, cachedServingUnit: String? = nil, cachedNumberOfServings: Double? = nil, cachedSelectedServingSizeOption: String? = nil) {
        self.id = UUID()
        self.name = name
        self.brandName = brandName
        self.barcode = barcode
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.novaScore = novaScore
        self.nutriScoreGrade = nutriScoreGrade
        self.servingSize = servingSize
        self.servingsPerPackage = servingsPerPackage
        self.servingType = servingType
        self.cachedServingSize = cachedServingSize
        self.cachedServingUnit = cachedServingUnit
        self.cachedNumberOfServings = cachedNumberOfServings
        self.cachedSelectedServingSizeOption = cachedSelectedServingSizeOption
    }
    
    // Codable implementation
    enum CodingKeys: String, CodingKey {
        case id, name, brandName, barcode, calories, protein, carbs, fat, novaScore, nutriScoreGrade, servingSize, servingsPerPackage, servingType, cachedServingSize, cachedServingUnit, cachedNumberOfServings, cachedSelectedServingSizeOption
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
        nutriScoreGrade = try container.decodeIfPresent(String.self, forKey: .nutriScoreGrade)
        servingSize = try container.decodeIfPresent(String.self, forKey: .servingSize)
        servingsPerPackage = try container.decodeIfPresent(Double.self, forKey: .servingsPerPackage)
        servingType = try container.decodeIfPresent(String.self, forKey: .servingType)
        cachedServingSize = try container.decodeIfPresent(Double.self, forKey: .cachedServingSize)
        cachedServingUnit = try container.decodeIfPresent(String.self, forKey: .cachedServingUnit)
        cachedNumberOfServings = try container.decodeIfPresent(Double.self, forKey: .cachedNumberOfServings)
        cachedSelectedServingSizeOption = try container.decodeIfPresent(String.self, forKey: .cachedSelectedServingSizeOption)
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
        try container.encodeIfPresent(nutriScoreGrade, forKey: .nutriScoreGrade)
        try container.encodeIfPresent(servingSize, forKey: .servingSize)
        try container.encodeIfPresent(servingsPerPackage, forKey: .servingsPerPackage)
        try container.encodeIfPresent(servingType, forKey: .servingType)
        try container.encodeIfPresent(cachedServingSize, forKey: .cachedServingSize)
        try container.encodeIfPresent(cachedServingUnit, forKey: .cachedServingUnit)
        try container.encodeIfPresent(cachedNumberOfServings, forKey: .cachedNumberOfServings)
        try container.encodeIfPresent(cachedSelectedServingSizeOption, forKey: .cachedSelectedServingSizeOption)
    }
}

// Food item row component
struct FoodItemRow: View {
    let food: FoodItem
    
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
    
    // Get color based on NOVA score
    private var novaScoreColor: Color {
        switch food.novaScore {
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
                    
                    // NOVA score if available
                    if food.novaScore > 0 || NovaScoreService.shared.predictNovaScore(for: food) > 0 {
                        // Add comma before NOVA score
                        Text(",")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            
                        let displayNovaScore = food.novaScore > 0 ? food.novaScore : NovaScoreService.shared.predictNovaScore(for: food)
                        Text("NOVA \(displayNovaScore)")
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
                            
                        Text(nutriGrade.uppercased())
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
            
            Text("\(calculateDefaultServingCalories(for: food)) kcal")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
    let title: String
    let value: String
    let description: String
    let color: Color
    
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
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}
