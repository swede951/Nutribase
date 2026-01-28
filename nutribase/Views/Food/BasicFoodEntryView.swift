import SwiftUI
import Combine

enum ServingUnit: String, CaseIterable {
    case gram = "g"
    case milliliter = "ml"
    case liter = "L"
    case ounce = "onz"
    
    var conversionFactor: Double {
        switch self {
        case .gram: return 1.0
        case .milliliter: return 1.0 // Assuming 1ml = 1g for simplicity
        case .liter: return 1000.0 // 1L = 1000ml
        case .ounce: return 28.35 // 1oz = 28.35g
        }
    }
}

// Serving Size Option model
struct ServingSizeOption: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let value: Double
    let unit: ServingUnit
    let isOriginal: Bool
    
    init(label: String, value: Double, unit: ServingUnit, isOriginal: Bool = false) {
        self.label = label
        self.value = value
        self.unit = unit
        self.isOriginal = isOriginal
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ServingSizeOption, rhs: ServingSizeOption) -> Bool {
        return lhs.id == rhs.id
    }
}

struct BasicFoodEntryView: View {
    let food: FoodItem
    let mealType: String
    let selectedDate: Date
    var onFoodAdded: ((FoodItem) -> Void)? = nil
    var showScanAgainButton: Bool = false
    var isCreatingMeal: Bool = false  // Flag to indicate if we're building a meal
    
    // Optional entry for editing existing entries
    let editingEntry: FoodEntry?
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var visibilityService = MetricVisibilityService.shared
    
    private var viewBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    // Optional initial values for cached serving information
    let initialServingSize: Double?
    let initialServingUnit: String?
    let initialNumberOfServings: Double?
    let initialSelectedServingSizeOption: String?
    
    @State private var servingSize: Double = 100.0
    @State private var numberOfServings: Double = 1.0
    @State private var servingsText: String = "1" // String representation for better TextField behavior
    @State private var selectedUnit: ServingUnit = .gram
    @State private var showServingSizeOptions: Bool = false
    @State private var selectedServingSizeOption: ServingSizeOption?

    @State private var customServingLabel: String? = nil
    @State private var refreshID = UUID() // Add refreshID to force view refresh
    @State private var isInitialized = false
    @State private var showingBarcodeScanner = false
    @State private var showAdditionalInfo = false // State for dropdown
    @State private var refreshedFood: FoodItem? = nil // Store refreshed food data for editing
    @State private var showingFlagSheet = false // State for food flag sheet
    @State private var showingEstimationInfo = false // State for estimation info popup
    @FocusState private var isServingsFieldFocused: Bool // Track focus for select-all behavior
    
    // Computed property to determine if we're editing
    private var isEditing: Bool {
        return editingEntry != nil
    }
    
    // Use refreshed food data if available, otherwise use original
    private var currentFood: FoodItem {
        return refreshedFood ?? food
    }
    
    // NumberFormatter for 2 decimal places
    private var decimalFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.allowsFloats = true
        return formatter
    }
    
    // Format servings number nicely (remove trailing zeros)
    private func formatServingsNumber(_ value: Double) -> String {
        if value == floor(value) {
            return String(Int(value))
        } else {
            // Format with up to 2 decimal places, removing trailing zeros
            let formatted = String(format: "%.2f", value)
            return formatted.replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
        }
    }
    
    // Get the NOVA score (actual or predicted)
    private var novaScore: Int {
        if food.novaScore > 0 {
            return food.novaScore
        } else {
            return NovaScoreService.shared.predictNovaScore(for: food)
        }
    }
    
    // Calculate proportional fill for macronutrient circles
    private func proteinProportion(_ refreshID: UUID) -> Double {
        let proteinCalories = totalProtein(refreshID) * 4
        let totalCals = Double(totalCalories(refreshID))
        return totalCals > 0 ? min(proteinCalories / totalCals, 1.0) : 0.0
    }
    
    private func carbsProportion(_ refreshID: UUID) -> Double {
        let carbsCalories = totalCarbs(refreshID) * 4
        let totalCals = Double(totalCalories(refreshID))
        return totalCals > 0 ? min(carbsCalories / totalCals, 1.0) : 0.0
    }
    
    private func fatProportion(_ refreshID: UUID) -> Double {
        let fatCalories = totalFat(refreshID) * 9
        let totalCals = Double(totalCalories(refreshID))
        return totalCals > 0 ? min(fatCalories / totalCals, 1.0) : 0.0
    }
    
    // Helper functions for segmented calories circle
    private func proteinCaloriesEnd(_ refreshID: UUID) -> Double {
        return proteinProportion(refreshID)
    }
    
    private func carbsCaloriesEnd(_ refreshID: UUID) -> Double {
        return proteinProportion(refreshID) + carbsProportion(refreshID)
    }
    
    private func fatCaloriesEnd(_ refreshID: UUID) -> Double {
        return proteinProportion(refreshID) + carbsProportion(refreshID) + fatProportion(refreshID)
    }

    // Get color for the NOVA score
    private var novaScoreColor: Color {
        switch novaScore {
        case 1: return Color(hex: "#3f993f")  // Unprocessed - darker green
        case 2: return Color(hex: "#b7ce0d")  // Processed culinary ingredients - lime green
        case 3: return Color(hex: "#f28e16")  // Processed foods - orange
        case 4: return Color(hex: "#e4032f")  // Ultra-processed foods - bright red
        default: return .gray
        }
    }
    
    // Get description for the NOVA score
    private var novaScoreDescription: String {
        return NovaScoreService.shared.descriptionForNovaScore(novaScore)
    }
    
    // Check if we have a NOVA score (actual or predicted)
    private var hasNovaScore: Bool {
        return novaScore > 0
    }
    
    // Check if NOVA score is estimated (not from original data)
    private var isNovaScoreEstimated: Bool {
        return food.novaScoreIsEstimated || food.novaScore == 0
    }
    
    // Check if Nutri-Score is estimated
    private var isNutriScoreEstimated: Bool {
        return food.nutriScoreIsEstimated
    }
    
    // Get the Nutri-Score grade
    private var nutriScoreGrade: String {
        return food.nutriScoreGrade?.uppercased() ?? "?"
    }
    
    // Get color for the Nutri-Score grade
    private var nutriScoreColor: Color {
        switch food.nutriScoreGrade?.lowercased() {
        case "a": return Color(hex: "#22e83d")  // Match NOVA Group 1 color
        case "b": return Color(hex: "#8eff00")  // Match NOVA Group 2 color
        case "c": return Color(hex: "#f4df70")  // Custom yellow color
        case "d": return Color(hex: "#ffb300")  // Match NOVA Group 3 color
        case "e": return Color(hex: "#ff5722")  // Match NOVA Group 4 color
        default: return .gray
        }
    }
    
    // Get description for the Nutri-Score grade
    private var nutriScoreDescription: String {
        switch food.nutriScoreGrade?.lowercased() {
        case "a": return "Excellent nutritional quality"
        case "b": return "Good nutritional quality"
        case "c": return "Average nutritional quality"
        case "d": return "Poor nutritional quality"
        case "e": return "Very poor nutritional quality"
        default: return "Unknown nutritional quality"
        }
    }
    
    // Determine if the food is likely a drink
    private var isDrink: Bool {
        let drinkKeywords = ["coffee", "tea", "juice", "water", "milk", "soda", "drink", "beverage", "smoothie", "shake", "espresso", "latte", "cappuccino"]
        return drinkKeywords.contains { food.name.lowercased().contains($0) }
    }
    
    // Check if this food is a meal (using the isMeal flag on FoodItem)
    private var isMeal: Bool {
        return food.isMeal
    }
    
    // Get the component foods if this is a meal
    private var mealFoods: [MealFood] {
        // Find the saved meal by name
        if let savedMeal = SavedMealsManager.shared.meals.first(where: { $0.name == food.name }) {
            return savedMeal.foods
        }
        return []
    }
    
    // Check if using original serving size from database
    private var isUsingOriginalServingSize: Bool {
        // Check if the selected option contains "(original)"
        return selectedServingSizeOption?.label.contains("(original)") == true
    }
    
    // Convert serving size to unit string for the calculator
    private var servingUnitString: String {
        switch selectedUnit {
        case .ounce: return "onz"
        case .gram: return "g"
        case .milliliter: return "ml"
        case .liter: return "L"
        }
    }
    
    private func totalCalories(_ refreshID: UUID) -> Int {
        // If calories are 0 but we have macro data, calculate from macros
        let baseFoodCalories: Int
        if currentFood.calories == 0 && (currentFood.protein > 0 || currentFood.carbs > 0 || currentFood.fat > 0) {
            // Calculate calories from macros: Protein=4cal/g, Carbs=4cal/g, Fat=9cal/g
            let calculatedCalories = (currentFood.protein * 4.0) + (currentFood.carbs * 4.0) + (currentFood.fat * 9.0)
            baseFoodCalories = Int(round(calculatedCalories))
        } else {
            baseFoodCalories = currentFood.calories
        }
        
        return NutritionCalculator.calculateCalories(
            foodCalories: baseFoodCalories,
            servingSize: servingSize,
            servingUnit: servingUnitString,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize,
            servingDescription: isUsingOriginalServingSize ? food.servingSize : nil,
            servingQuantity: food.servingsPerPackage
        )
    }
    
    private func totalProtein(_ refreshID: UUID) -> Double {
        return NutritionCalculator.calculateMacro(
            macroValue: currentFood.protein,
            servingSize: servingSize,
            servingUnit: servingUnitString,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize,
            servingDescription: isUsingOriginalServingSize ? food.servingSize : nil,
            servingQuantity: food.servingsPerPackage
        )
    }
    
    private func totalCarbs(_ refreshID: UUID) -> Double {
        return NutritionCalculator.calculateMacro(
            macroValue: currentFood.carbs,
            servingSize: servingSize,
            servingUnit: servingUnitString,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize,
            servingDescription: isUsingOriginalServingSize ? food.servingSize : nil,
            servingQuantity: food.servingsPerPackage
        )
    }
    
    private func totalFat(_ refreshID: UUID) -> Double {
        return NutritionCalculator.calculateMacro(
            macroValue: currentFood.fat,
            servingSize: servingSize,
            servingUnit: servingUnitString,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize,
            servingDescription: isUsingOriginalServingSize ? food.servingSize : nil,
            servingQuantity: food.servingsPerPackage
        )
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // Food name and brand
                VStack(alignment: .center, spacing: 4) {
                    Text(currentFood.name)
                        .font(.custom("Montserrat-Bold", size: 28))
                        .multilineTextAlignment(.center)
                    
                    if let brandName = currentFood.brandName, !brandName.isEmpty {
                        Text(brandName)
                            .font(.custom("Montserrat-SemiBold", size: 18))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            
                // Serving section header
                HStack {
                    Text("Serving")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, -8)
                .padding(.top, 4)
                
                // Serving card
                VStack(alignment: .leading, spacing: 12) {
                
                if isDrink {
                    // Unit picker for drinks
                    Picker("Unit", selection: $selectedUnit) {
                        ForEach(ServingUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedUnit) { _, newUnit in
                        // Reset serving size option when unit changes
                        selectedServingSizeOption = nil

                        
                        // Convert the serving size when changing units
                        let conversionFactor = newUnit.conversionFactor / selectedUnit.conversionFactor
                        servingSize *= conversionFactor
                        
                        // Update the selected unit
                        selectedUnit = newUnit
                        
                        // Force refresh
                        refreshID = UUID()
                    }
                    
                    // Size dropdown for drinks
                    HStack {
                        Text("Size:")
                            .font(.headline)
                        
                        Spacer()
                        
                        Menu {
                            // Add original serving size as first option if available
                            if let originalServingSize = food.servingSize, !originalServingSize.isEmpty {
                                Button("\(originalServingSize) (original)") {
                                    // Parse the original serving size with better unit detection
                                    let components = originalServingSize.lowercased().components(separatedBy: CharacterSet.decimalDigits.inverted)
                                    if let firstNumber = components.compactMap({ Double($0) }).first {
                                        servingSize = firstNumber
                                        
                                        // Detect unit from the original serving size string
                                        if originalServingSize.lowercased().contains("ml") || originalServingSize.lowercased().contains("milliliter") {
                                            selectedUnit = .milliliter
                                        } else if originalServingSize.lowercased().contains("l") && !originalServingSize.lowercased().contains("ml") {
                                            selectedUnit = .liter
                                        } else if originalServingSize.lowercased().contains("oz") || originalServingSize.lowercased().contains("ounce") {
                                            selectedUnit = .ounce
                                        } else {
                                            selectedUnit = .gram
                                        }
                                        
                                        selectedServingSizeOption = ServingSizeOption(
                                            label: "\(originalServingSize) (original)",
                                            value: firstNumber,
                                            unit: selectedUnit,
                                            isOriginal: true
                                        )
                                        customServingLabel = "\(originalServingSize) (original)"
                                        refreshID = UUID()
                                    }
                                }
                            }
                            
                            // Common drink serving sizes
                            Button("100ml") {
                                servingSize = 100
                                selectedUnit = .milliliter
                                selectedServingSizeOption = ServingSizeOption(
                                    label: "100ml",
                                    value: 100,
                                    unit: .milliliter
                                )
                                customServingLabel = "100ml"
                                refreshID = UUID()
                            }
                            
                            Button("250ml") {
                                servingSize = 250
                                selectedUnit = .milliliter
                                selectedServingSizeOption = ServingSizeOption(
                                    label: "250ml",
                                    value: 250,
                                    unit: .milliliter
                                )
                                customServingLabel = "250ml"
                                refreshID = UUID()
                            }
                            
                            Button("500ml") {
                                servingSize = 500
                                selectedUnit = .milliliter
                                selectedServingSizeOption = ServingSizeOption(
                                    label: "500ml",
                                    value: 500,
                                    unit: .milliliter
                                )
                                customServingLabel = "500ml"
                                refreshID = UUID()
                            }
                            
                            if selectedUnit == .milliliter || selectedUnit == .liter {
                                Button("1 cup (240ml)") {
                                    servingSize = 240
                                    selectedUnit = .milliliter
                                    selectedServingSizeOption = ServingSizeOption(
                                        label: "1 cup (240ml)",
                                        value: 240,
                                        unit: .milliliter
                                    )
                                    customServingLabel = "1 cup (240ml)"
                                    refreshID = UUID()
                                }
                                
                                Button("1 glass (200ml)") {
                                    servingSize = 200
                                    selectedUnit = .milliliter
                                    selectedServingSizeOption = ServingSizeOption(
                                        label: "1 glass (200ml)",
                                        value: 200,
                                        unit: .milliliter
                                    )
                                    customServingLabel = "1 glass (200ml)"
                                    refreshID = UUID()
                                }
                            }
                        } label: {
                            HStack {
                                Text(customServingLabel ?? selectedServingSizeOption?.label ?? "Select serving size")
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                } else {
                    // Serving size dropdown for solid foods
                    HStack {
                        Text("Size:")
                        
                        Spacer()
                        
                        Menu {
                            // Add original serving size as first option if available
                            if let originalServingSize = food.servingSize, !originalServingSize.isEmpty {
                                Button("\(originalServingSize) (original)") {
                                    // Parse the original serving size with better unit detection
                                    let components = originalServingSize.lowercased().components(separatedBy: CharacterSet.decimalDigits.inverted)
                                    if let firstNumber = components.compactMap({ Double($0) }).first {
                                        servingSize = firstNumber
                                        
                                        // Detect unit from the original serving size string
                                        if originalServingSize.lowercased().contains("ml") || originalServingSize.lowercased().contains("milliliter") {
                                            selectedUnit = .milliliter
                                        } else if originalServingSize.lowercased().contains("l") && !originalServingSize.lowercased().contains("ml") {
                                            selectedUnit = .liter
                                        } else if originalServingSize.lowercased().contains("oz") || originalServingSize.lowercased().contains("ounce") {
                                            selectedUnit = .ounce
                                        } else {
                                            selectedUnit = .gram
                                        }
                                        
                                        selectedServingSizeOption = ServingSizeOption(
                                            label: "\(originalServingSize) (original)",
                                            value: firstNumber,
                                            unit: selectedUnit,
                                            isOriginal: true
                                        )
                                        customServingLabel = "\(originalServingSize) (original)"
                                        refreshID = UUID()
                                    }
                                }
                            }
                            
                            // Common serving sizes
                            Button("100g") {
                                servingSize = 100
                                selectedUnit = .gram
                                selectedServingSizeOption = ServingSizeOption(
                                    label: "100g",
                                    value: 100,
                                    unit: .gram
                                )
                                customServingLabel = "100g"
                                refreshID = UUID()
                            }
                            
                            Button("50g") {
                                servingSize = 50
                                selectedUnit = .gram
                                selectedServingSizeOption = ServingSizeOption(
                                    label: "50g",
                                    value: 50,
                                    unit: .gram
                                )
                                customServingLabel = "50g"
                                refreshID = UUID()
                            }
                            
                            Button("1g") {
                                servingSize = 1
                                selectedUnit = .gram
                                selectedServingSizeOption = ServingSizeOption(
                                    label: "1g",
                                    value: 1,
                                    unit: .gram
                                )
                                customServingLabel = "1g"
                                refreshID = UUID()
                            }
                            
                            Button("1 oz (28.35g)") {
                                servingSize = 28.35
                                selectedUnit = .gram
                                selectedServingSizeOption = ServingSizeOption(
                                    label: "1 oz (28.35g)",
                                    value: 28.35,
                                    unit: .gram
                                )
                                customServingLabel = "1 oz (28.35g)"
                                refreshID = UUID()
                            }
                            
                            Button("1 cup") {
                                servingSize = 240
                                selectedUnit = .gram
                                selectedServingSizeOption = ServingSizeOption(
                                    label: "1 cup",
                                    value: 240,
                                    unit: .gram
                                )
                                customServingLabel = "1 cup"
                                refreshID = UUID()
                            }
                            
                            Button("1 tablespoon (15g)") {
                                servingSize = 15
                                selectedUnit = .gram
                                selectedServingSizeOption = ServingSizeOption(
                                    label: "1 tablespoon (15g)",
                                    value: 15,
                                    unit: .gram
                                )
                                customServingLabel = "1 tablespoon (15g)"
                                refreshID = UUID()
                            }
                        } label: {
                            HStack {
                                Text(customServingLabel ?? selectedServingSizeOption?.label ?? "Select serving size")
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Divider()
                
                HStack {
                    Text("Number of servings:")
                    Spacer()
                    TextField("1", text: $servingsText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .focused($isServingsFieldFocused)
                        .onChange(of: servingsText) { _, newValue in
                            // Parse the string and update numberOfServings
                            // Allow empty string during editing
                            if newValue.isEmpty {
                                return
                            }
                            // Clean the input: allow digits and one decimal point
                            let cleaned = newValue.filter { $0.isNumber || $0 == "." }
                            if cleaned != newValue {
                                servingsText = cleaned
                            }
                            // Parse to Double
                            if let value = Double(cleaned), value > 0 {
                                numberOfServings = value
                                refreshID = UUID()
                            }
                        }
                        .onChange(of: isServingsFieldFocused) { _, isFocused in
                            if isFocused {
                                // Select all text when field is focused
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    // This triggers select all behavior via UIKit
                                    UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                                }
                            } else {
                                // When losing focus, ensure we have a valid value
                                if servingsText.isEmpty || Double(servingsText) == nil || Double(servingsText) == 0 {
                                    numberOfServings = 1.0
                                    servingsText = "1"
                                } else if let value = Double(servingsText) {
                                    numberOfServings = value
                                    // Format nicely (remove trailing zeros)
                                    servingsText = formatServingsNumber(value)
                                }
                                refreshID = UUID()
                            }
                        }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button {
                                isServingsFieldFocused = false
                            } label: {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackground)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                )
            
                // Nutrition section header
                HStack {
                    Text("Nutrition")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, -8)
                .padding(.top, 4)
                
                // Calories Card (conditionally shown)
                if visibilityService.showCalories {
                    HStack {
                        Text("Calories")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        ZStack {
                            // Background circle
                            Circle()
                                .stroke(lineWidth: 6)
                                .opacity(0.2)
                                .foregroundColor(Color.gray)
                            
                            // Protein segment (green) - only if protein visible
                            if visibilityService.showProtein {
                                Circle()
                                    .trim(from: 0.0, to: proteinCaloriesEnd(refreshID))
                                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .foregroundColor(Color.green)
                                    .rotationEffect(Angle(degrees: 270.0))
                            }
                            
                            // Carbs segment (orange) - only if carbs visible
                            if visibilityService.showCarbs {
                                Circle()
                                    .trim(from: proteinCaloriesEnd(refreshID), to: carbsCaloriesEnd(refreshID))
                                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .foregroundColor(Color.orange)
                                    .rotationEffect(Angle(degrees: 270.0))
                            }
                            
                            // Fats segment (pink) - only if fat visible
                            if visibilityService.showFat {
                                Circle()
                                    .trim(from: carbsCaloriesEnd(refreshID), to: fatCaloriesEnd(refreshID))
                                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .foregroundColor(Color.pink)
                                    .rotationEffect(Angle(degrees: 270.0))
                            }
                            
                            Text("\(totalCalories(refreshID))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 65, height: 65)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBackground)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
                
                // Macros Card (conditionally shown based on visibility)
                if visibilityService.anyMacroVisible {
                    HStack(spacing: 16) {
                        // Protein
                        if visibilityService.showProtein {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .stroke(lineWidth: 6)
                                        .opacity(0.2)
                                        .foregroundColor(Color.gray)
                                    
                                    Circle()
                                        .trim(from: 0.0, to: proteinProportion(refreshID))
                                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                        .foregroundColor(Color.green) // Green for protein
                                        .rotationEffect(Angle(degrees: 270.0))
                                    
                                    Text(String(format: "%.0fg", totalProtein(refreshID)))
                                        .font(.custom("Montserrat-SemiBold", size: 14))
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 65, height: 65)
                                
                                Text("Protein")
                                    .font(.custom("Montserrat-SemiBold", size: 14))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        // Carbs
                        if visibilityService.showCarbs {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .stroke(lineWidth: 6)
                                        .opacity(0.2)
                                        .foregroundColor(Color.gray)
                                    
                                    Circle()
                                        .trim(from: 0.0, to: carbsProportion(refreshID))
                                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                        .foregroundColor(Color.orange) // Orange for carbs
                                        .rotationEffect(Angle(degrees: 270.0))
                                    
                                    Text(String(format: "%.0fg", totalCarbs(refreshID)))
                                        .font(.custom("Montserrat-SemiBold", size: 14))
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 65, height: 65)
                                
                                Text("Carbs")
                                    .font(.custom("Montserrat-SemiBold", size: 14))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        // Fats
                        if visibilityService.showFat {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .stroke(lineWidth: 6)
                                        .opacity(0.2)
                                        .foregroundColor(Color.gray)
                                    
                                    Circle()
                                        .trim(from: 0.0, to: fatProportion(refreshID))
                                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                        .foregroundColor(Color.pink) // Pink for fats
                                        .rotationEffect(Angle(degrees: 270.0))
                                    
                                    Text(String(format: "%.0fg", totalFat(refreshID)))
                                        .font(.custom("Montserrat-SemiBold", size: 14))
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 65, height: 65)
                                
                                Text("Fats")
                                    .font(.custom("Montserrat-SemiBold", size: 14))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBackground)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                    )
                }
                
                // Additional Information Card (expandable inline)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAdditionalInfo.toggle()
                    }
                }) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack {
                            Text("Additional Information")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: showAdditionalInfo ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(showAdditionalInfo ? 180 : 0))
                                .animation(.easeInOut(duration: 0.3), value: showAdditionalInfo)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    
                    // Expandable content
                    if showAdditionalInfo {
                        let _ = print("🔍 BasicFoodEntryView - Additional Info Values:")
                        let _ = print("   fiber: \(food.fiber ?? -1)")
                        let _ = print("   sugar: \(food.sugar ?? -1)")
                        let _ = print("   sodium: \(food.sodium ?? -1)")
                        let _ = print("   saturatedFat: \(food.saturatedFat ?? -1)")
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Fiber
                            if let fiber = food.fiber, fiber > 0 {
                                HStack {
                                    Text("Fiber")
                                        .font(.system(size: 16, weight: .medium))
                                    Spacer()
                                    Text("\(String(format: "%.1f", fiber))g")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                        
                        // Sugar
                        if let sugar = food.sugar, sugar > 0 {
                            HStack {
                                Text("Sugar")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Text("\(String(format: "%.1f", sugar))g")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Sodium
                        if let sodium = food.sodium, sodium > 0 {
                            HStack {
                                Text("Sodium")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Text("\(String(format: "%.0f", sodium))mg")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Saturated Fat
                        if let saturatedFat = food.saturatedFat, saturatedFat > 0 {
                            HStack {
                                Text("Saturated Fat")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Text("\(String(format: "%.1f", saturatedFat))g")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Show a message if no additional info is available
                        if (food.fiber ?? 0) <= 0 && (food.sugar ?? 0) <= 0 && (food.sodium ?? 0) <= 0 && (food.saturatedFat ?? 0) <= 0 {
                            Text("No additional nutritional information available")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .italic()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .slide))
                    }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackground)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                )
                .buttonStyle(PlainButtonStyle())
            
                // Food Items section (shown only for meals)
                if isMeal && !mealFoods.isEmpty {
                    HStack {
                        Text("Food Items")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, -8)
                    .padding(.top, 4)
                    
                    VStack(spacing: 8) {
                        ForEach(mealFoods) { mealFood in
                            MealFoodItemRow(mealFood: mealFood)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBackground)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                    )
                }
            
                // Food Score section (conditionally shown, hidden for meals)
                if hasNovaScore && visibilityService.anyFoodScoreVisible && !isMeal {
                    HStack {
                        Text("Food Score")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, -8)
                    .padding(.top, 4)
                    
                    HStack(alignment: .top, spacing: 12) {
                        // NOVA Score Card
                        if visibilityService.showNovaScore {
                            ZStack(alignment: .topTrailing) {
                                VStack(spacing: 12) {
                                    // Score display with rounded rectangle background
                                    VStack {
                                        Text("\(novaScore)")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.primary)
                                    }
                                    .frame(width: 80, height: 80)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(novaScoreColor)
                                    )
                                    
                                    Text("Nova Score")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text(novaScoreDescription)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(nil)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(cardBackground)
                                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                                )
                                
                                // Estimation indicator
                                if isNovaScoreEstimated {
                                    Button(action: {
                                        showingEstimationInfo = true
                                    }) {
                                        Text("✨")
                                            .font(.system(size: 16))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(8)
                                }
                            }
                        }
                        
                        // Nutri-Score Card
                        if visibilityService.showNutriScore {
                            ZStack(alignment: .topTrailing) {
                                VStack(spacing: 12) {
                                    // Score display with rounded rectangle background
                                    VStack {
                                        Text(nutriScoreGrade)
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.primary)
                                    }
                                    .frame(width: 80, height: 80)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(nutriScoreColor)
                                    )
                                    
                                    Text("Nutri-Score")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text(nutriScoreDescription)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(nil)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(cardBackground)
                                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                                )
                                
                                // Estimation indicator
                                if isNutriScoreEstimated {
                                    Button(action: {
                                        showingEstimationInfo = true
                                    }) {
                                        Text("✨")
                                            .font(.system(size: 16))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .alert("Estimated Value", isPresented: $showingEstimationInfo) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("This value has been estimated based on similar foods in our database, as the original food entry was missing this information. While not exact, it provides a reasonable approximation for tracking your dietary patterns.")
                    }
                }
                
                // Add & Scan Again button
                if showScanAgainButton {
                    Button(action: {
                        addFoodToMeal()
                        showingBarcodeScanner = true
                    }) {
                        HStack {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundColor(.white)
                            Text("Add & Scan Again")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(viewBackground)
        .navigationTitle(isEditing ? "Edit Food" : "Add Food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Flag/Report button
                    Menu {
                        Button(action: { showingFlagSheet = true }) {
                            Label("Report Issue", systemImage: "flag")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.primary)
                    }
                    
                    // Add/Save button
                    Button(isEditing ? "Save" : "Add") {
                        if isEditing {
                            updateFoodEntry()
                        } else {
                            addFoodToMeal()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingBarcodeScanner) {
            BarcodeScannerView(scannedBarcode: .constant(nil), isPresented: $showingBarcodeScanner)
        }
        .sheet(isPresented: $showingFlagSheet) {
            FoodFlagSheet(food: currentFood)
        }
        .onAppear {
            // Debug food item data
            print("🍎 DEBUG Food Item Data:")
            print("  Name: \(food.name)")
            print("  Calories: \(food.calories)")
            print("  Protein: \(food.protein)")
            print("  Carbs: \(food.carbs)")
            print("  Fat: \(food.fat)")
            
            // If editing and food has a barcode, refresh the food data from Typesense
            if isEditing, let barcode = food.barcode, !barcode.isEmpty {
                print("🔄 Refreshing food data for editing: \(food.name) with barcode: \(barcode)")
                TypesenseDirectService.shared.searchByBarcode(barcode: barcode) { refreshedFood, error in
                    DispatchQueue.main.async {
                        if let refreshedFood = refreshedFood {
                            print("✅ Successfully refreshed food data:")
                            print("  Carbs: \(food.carbs) -> \(refreshedFood.carbs)")
                            self.refreshedFood = refreshedFood
                        } else {
                            print("❌ Failed to refresh food data: \(error?.localizedDescription ?? "Unknown error")")
                        }
                    }
                }
            }
            
            // Set navigation bar background to systemGray6
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemGray6
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            
            
            // Initialize default serving size if not already initialized
            if !isInitialized {
                selectDefaultServingSize()
                isInitialized = true
            }
        }
    }
    
    private func selectDefaultServingSize() {
        // Removed debug logging for performance
        
        // First priority: If editing, use entry values
        if let entry = editingEntry {
            servingSize = entry.servingSize
            numberOfServings = entry.numberOfServings
            servingsText = formatServingsNumber(entry.numberOfServings)
            selectedUnit = entry.servingUnit == "ml" ? .milliliter : .gram
            
            // Set the selected serving size option based on entry
            selectedServingSizeOption = ServingSizeOption(
                label: determineSelectedOption(servingSize: entry.servingSize, servingUnit: entry.servingUnit, foodItem: food),
                value: entry.servingSize,
                unit: entry.servingUnit == "ml" ? .milliliter : .gram,
                isOriginal: false
            )
            return
        }
        
        // Second priority: Use cached values if available (be lenient - only require size, unit, and servings)
        if let cachedSize = initialServingSize,
           let cachedUnit = initialServingUnit,
           let cachedServings = initialNumberOfServings {
            
            // Using cached values
            servingSize = cachedSize
            numberOfServings = cachedServings
            servingsText = formatServingsNumber(cachedServings)
            selectedUnit = cachedUnit == "ml" ? .milliliter : .gram
            
            // Always regenerate the label to ensure proper formatting (fixes "100.0 serving" -> "100g")
            let optionLabel = determineSelectedOption(servingSize: cachedSize, servingUnit: cachedUnit, foodItem: food)
            
            // Set the selected serving size option
            selectedServingSizeOption = ServingSizeOption(
                label: optionLabel,
                value: cachedSize,
                unit: selectedUnit,
                isOriginal: optionLabel.contains("(original)")
            )
            
            // If it's a custom option, set the custom label
            if !optionLabel.contains("(original)") && !isStandardServingSize(cachedSize, cachedUnit) {
                customServingLabel = optionLabel
            }
            
            refreshID = UUID()
            return
        }
        
        // Second priority: Use the original serving size from the database if available
        if let originalServingSize = food.servingSize, !originalServingSize.isEmpty {
            
            // Try to extract weight from the serving size description
            if let (weight, unit) = NutritionCalculator.extractWeightFromServingSize(originalServingSize) {
                // Use extracted weight and unit
                servingSize = weight
                selectedUnit = unit == "ml" ? .milliliter : .gram
            } else {
                // Fallback: assume it's 1 serving of whatever the description says
                servingSize = 1.0
                selectedUnit = .gram
            }
            
            selectedServingSizeOption = ServingSizeOption(
                label: "\(originalServingSize) (original)", 
                value: servingSize, 
                unit: selectedUnit, 
                isOriginal: true
            )
            customServingLabel = originalServingSize
            refreshID = UUID() // Force view refresh after setting default
            return
        }

        
        // If no original serving size or couldn't parse it, select the default option based on food type
        if isDrink {
            // For drinks, default to 250ml (1 cup)
            servingSize = 250.0
            selectedUnit = .milliliter
            selectedServingSizeOption = ServingSizeOption(label: "250ml (1 cup)", value: 250.0, unit: .milliliter)
            customServingLabel = nil
        } else {
            // For solid foods, default to 100g (standard)
            servingSize = 100.0
            selectedUnit = .gram
            selectedServingSizeOption = ServingSizeOption(label: "100g (standard)", value: 100.0, unit: .gram)
            customServingLabel = nil
        }
        
        // Sync servingsText with numberOfServings
        servingsText = formatServingsNumber(numberOfServings)
        refreshID = UUID() // Force view refresh after setting default
    }
    
    private func addFoodToMeal() {
        // Determine the unit string based on what was actually selected
        let unitString: String
        if let selectedOption = selectedServingSizeOption {
            // If a specific serving size option was selected, extract the unit from the label
            let label = selectedOption.label
            if label.contains("onz") || label.contains("oz") {
                unitString = "onz"
            } else if label.contains("bar") {
                unitString = "bar"
            } else if label.contains("piece") {
                unitString = "piece"
            } else if label.contains("serving") {
                unitString = "serving"
            } else if label.contains("ml") {
                unitString = "ml"
            } else if label.contains("L") {
                unitString = "L"
            } else {
                unitString = "g"
            }
        } else if let customLabel = customServingLabel {
            // If using a custom serving label, preserve the original unit
            if customLabel.contains("onz") || customLabel.contains("oz") {
                unitString = "onz"
            } else if customLabel.contains("bar") {
                unitString = "bar"
            } else if customLabel.contains("piece") {
                unitString = "piece"
            } else if customLabel.contains("serving") {
                unitString = "serving"
            } else {
                unitString = selectedUnit.rawValue
            }
        } else {
            // Default to the selected unit
            unitString = selectedUnit.rawValue
        }
        
        // Calculate calories from macros if food has 0 calories but has macro data
        let effectiveCalories: Int
        if food.calories == 0 && (food.protein > 0 || food.carbs > 0 || food.fat > 0) {
            let calculatedCalories = (food.protein * 4.0) + (food.carbs * 4.0) + (food.fat * 9.0)
            effectiveCalories = Int(round(calculatedCalories))
        } else {
            effectiveCalories = food.calories
        }
        
        // Create food item with corrected calories for the food log
        let foodForLog = FoodItem(
            name: food.name,
            brandName: food.brandName,
            barcode: food.barcode,
            calories: effectiveCalories,
            protein: food.protein,
            carbs: food.carbs,
            fat: food.fat,
            novaScore: food.novaScore,
            nutriScoreGrade: food.nutriScoreGrade,
            servingSize: food.servingSize,
            servingsPerPackage: food.servingsPerPackage,
            servingType: food.servingType
        )
        
        // Add the food to the FoodLogManager (skip if creating a meal)
        if !isCreatingMeal {
            FoodLogManager.shared.addEntry(
                foodItem: foodForLog,
                mealType: mealType,
                servingSize: servingSize,
                servingUnit: unitString,
                numberOfServings: numberOfServings,
                date: selectedDate,
                selectedServingSizeOption: selectedServingSizeOption?.label ?? customServingLabel
            )
        }
        
        // Create a cached version of the food item that preserves the original serving size
        // but stores the actual serving information used for display purposes
        let cachedFood = FoodItem(
            name: food.name,
            brandName: food.brandName,
            barcode: food.barcode,
            calories: effectiveCalories, // Use calculated calories if original was 0
            protein: food.protein,
            carbs: food.carbs,
            fat: food.fat,
            novaScore: food.novaScore,
            nutriScoreGrade: food.nutriScoreGrade,
            servingSize: food.servingSize, // Preserve original serving size
            servingsPerPackage: food.servingsPerPackage,
            servingType: food.servingType,
            cachedServingSize: servingSize,
            cachedServingUnit: unitString,
            cachedNumberOfServings: numberOfServings,
            cachedSelectedServingSizeOption: selectedServingSizeOption?.label ?? customServingLabel
        )
        
        // Call the callback to add this cached food to recently used foods
        onFoodAdded?(cachedFood)
        
        // If this food was added via barcode scanner, also add to recent foods
        if showScanAgainButton {
            // Add to recent foods list for barcode scanner items
            addToRecentFoodsDirectly(cachedFood)
        }
        
        // Track this food selection for personalized ranking
        TypesenseDirectService.shared.trackFoodSelection(food)
        
        
        // Dismiss the view after adding the food
        presentationMode.wrappedValue.dismiss()
    }
    
    // Add to recent foods directly (for barcode scanner items)
    private func addToRecentFoodsDirectly(_ food: FoodItem) {
        // Use user-specific key (same logic as FoodSearchView)
        let recentFoodsKey: String
        if let authenticatedUser = FirebaseAuthService.shared.currentUser {
            recentFoodsKey = "recentlyAddedFoods_\(authenticatedUser.id)"
        } else {
            // Fallback to local UUID for offline usage
            if let existingId = UserDefaults.standard.string(forKey: "current_user_id") {
                recentFoodsKey = "recentlyAddedFoods_\(existingId)"
            } else {
                let newId = UUID().uuidString
                UserDefaults.standard.set(newId, forKey: "current_user_id")
                recentFoodsKey = "recentlyAddedFoods_\(newId)"
            }
        }
        
        let maxRecentFoods = 30
        
        // Load existing recent foods
        var foods: [FoodItem] = []
        if let data = UserDefaults.standard.data(forKey: recentFoodsKey),
           let recentFoods = try? JSONDecoder().decode([FoodItem].self, from: data) {
            foods = recentFoods
        }
        
        // Remove the food if it already exists (to avoid duplicates)
        foods.removeAll { $0.name == food.name && $0.brandName == food.brandName }
        
        // Add the new food at the beginning
        foods.insert(food, at: 0)
        
        // Limit to max number of recent foods
        if foods.count > maxRecentFoods {
            foods = Array(foods.prefix(maxRecentFoods))
        }
        
        // Save the updated list to UserDefaults
        if let data = try? JSONEncoder().encode(foods) {
            UserDefaults.standard.set(data, forKey: recentFoodsKey)
        }
    }
    
    // Helper function to check if a serving size is a standard option
    private func isStandardServingSize(_ size: Double, _ unit: String) -> Bool {
        let standardSizes = [50.0, 100.0, 150.0, 200.0, 250.0, 300.0, 400.0, 500.0]
        return standardSizes.contains(size) && (unit == "g" || unit == "ml")
    }
    
    // Update existing food entry
    private func updateFoodEntry() {
        guard let entry = editingEntry else { return }
        
        // Determine the unit string based on what was actually selected
        let unitString: String
        if let selectedOption = selectedServingSizeOption {
            let label = selectedOption.label
            if label.contains("onz") || label.contains("oz") {
                unitString = "onz"
            } else if label.contains("bar") {
                unitString = "bar"
            } else if label.contains("piece") {
                unitString = "piece"
            } else if label.contains("serving") {
                unitString = "serving"
            } else if label.contains("ml") {
                unitString = "ml"
            } else if label.contains("L") {
                unitString = "L"
            } else {
                unitString = "g"
            }
        } else {
            unitString = selectedUnit == .milliliter ? "ml" : "g"
        }
        
        // Update in FoodLogManager (note: this only updates serving info, not the food item itself)
        FoodLogManager.shared.updateEntry(
            id: entry.id,
            servingSize: servingSize,
            servingUnit: unitString,
            numberOfServings: numberOfServings
        )
        
        // Dismiss the view
        presentationMode.wrappedValue.dismiss()
    }
    
    // Helper function to determine selected option from entry values
    private func determineSelectedOption(servingSize: Double, servingUnit: String, foodItem: FoodItem) -> String {
        let unitLower = servingUnit.lowercased()
        let standardGramSizes: [Double] = [1, 50, 100, 150, 200, 250, 300, 400, 500]
        
        // For ml units - handle liquid measurements
        if unitLower == "ml" {
            if abs(servingSize - 240) < 0.01 { return "1 cup" }
            if abs(servingSize - 15) < 0.01 { return "1 tbsp" }
            let sizeStr = servingSize.truncatingRemainder(dividingBy: 1) == 0 ? 
                "\(Int(servingSize))" : String(format: "%.1f", servingSize)
            return "\(sizeStr)ml"
        }
        
        // For non-ml units with standard gram sizes - always show as grams
        if unitLower != "ml" && standardGramSizes.contains(where: { abs($0 - servingSize) < 0.01 }) {
            return "\(Int(servingSize))g"
        }
        
        // For known weight units, show with unit
        if unitLower == "g" || unitLower == "onz" || unitLower == "oz" || unitLower == "l" {
            let sizeStr = servingSize.truncatingRemainder(dividingBy: 1) == 0 ? 
                "\(Int(servingSize))" : String(format: "%.1f", servingSize)
            return "\(sizeStr)\(servingUnit)"
        }
        
        // For other units - default to showing as grams
        let sizeStr = servingSize.truncatingRemainder(dividingBy: 1) == 0 ? 
            "\(Int(servingSize))" : String(format: "%.1f", servingSize)
        return "\(sizeStr)g"
    }
}

struct NutritionRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

// Component for displaying individual meal food items
struct MealFoodItemRow: View {
    let mealFood: MealFood
    
    private var novaScoreColor: Color {
        switch mealFood.novaScore {
        case 1: return Color(hex: "#3f993f")
        case 2: return Color(hex: "#b7ce0d")
        case 3: return Color(hex: "#f28e16")
        case 4: return Color(hex: "#e4032f")
        default: return .gray
        }
    }
    
    private var nutriScoreColor: Color {
        guard let grade = mealFood.nutriScoreGrade?.lowercased() else { return .gray }
        switch grade {
        case "a": return Color(hex: "#22e83d")
        case "b": return Color(hex: "#85bb2f")
        case "c": return Color(hex: "#f2c51d")
        case "d": return Color(hex: "#ee8a22")
        case "e": return Color(hex: "#e4032f")
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(mealFood.foodName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    // Weight
                    Text("\(String(format: "%.0f", mealFood.servingSize))\(mealFood.servingUnit)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    // NOVA Score badge
                    if mealFood.novaScore > 0 {
                        HStack(spacing: 2) {
                            if mealFood.novaScoreIsEstimated {
                                Text("✨")
                                    .font(.system(size: 9))
                            }
                            Text("NOVA \(mealFood.novaScore)")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(novaScoreColor)
                        .cornerRadius(4)
                    }
                    
                    // Nutri-Score badge
                    if let nutriScore = mealFood.nutriScoreGrade, !nutriScore.isEmpty {
                        HStack(spacing: 2) {
                            if mealFood.nutriScoreIsEstimated {
                                Text("✨")
                                    .font(.system(size: 9))
                            }
                            Text(nutriScore.uppercased())
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(nutriScoreColor)
                        .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            Text("\(mealFood.calories) kcal")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
        
        Divider()
    }
}
