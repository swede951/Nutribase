//
//  FoodEntryEditView.swift
//  nutribase
//
//  Created on 03/06/2025.
//

import SwiftUI

public struct FoodEntryEditView: View {
    // Food item to edit
    public let food: FoodItem
    public let mealType: String
    
    // Optional entry ID for editing existing entries
    private let entryId: UUID?
    private let isEditing: Bool
    
    // Serving information
    @State private var servingSize: Double = 100.0
    @State private var numberOfServings: Double = 1.0
    @State private var servingUnit: String = "g"
    @State private var showServingSizeOptions = false
    @State private var selectedServingSizeOption: String? = nil
    @State private var refreshID = UUID() // Force view refresh when serving size changes
    
    // Environment
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDeleteConfirmation = false
    
    private var viewBackground: Color {
        Color.appBackground
    }
    
    // Initialize for creating a new entry
    public init(food: FoodItem, mealType: String) {
        self.food = food
        self.mealType = mealType
        self.entryId = nil
        self.isEditing = false
    }
    
    // Initialize for editing an existing entry
    init(entry: FoodEntry) {
        self.food = entry.foodItem
        self.mealType = entry.mealType
        self.entryId = entry.id
        self.isEditing = true
        self._servingSize = State(initialValue: entry.servingSize)
        self._numberOfServings = State(initialValue: entry.numberOfServings)
        
        let unitLower = entry.servingUnit.lowercased()
        let standardGramSizes: [Double] = [100, 200, 50, 1]
        
        // For non-ml units with standard gram sizes - convert to grams
        if unitLower != "ml" && unitLower != "g" && standardGramSizes.contains(where: { abs($0 - entry.servingSize) < 0.01 }) {
            self._servingUnit = State(initialValue: "g")
            self._selectedServingSizeOption = State(initialValue: "\(Int(entry.servingSize))g")
        } else {
            self._servingUnit = State(initialValue: entry.servingUnit)
            self._selectedServingSizeOption = State(initialValue: FoodEntryEditView.determineSelectedOptionStatic(servingSize: entry.servingSize, servingUnit: entry.servingUnit, foodItem: entry.foodItem))
        }
    }
    
    // Static version of determineSelectedOption for use in init
    private static func determineSelectedOptionStatic(servingSize: Double, servingUnit: String, foodItem: FoodItem) -> String {
        let unitLower = servingUnit.lowercased()
        let standardGramSizes: [Double] = [100, 200, 50, 1]
        
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
        
        // For known weight/volume units, show with unit
        if unitLower == "g" || unitLower == "onz" || unitLower == "oz" || unitLower == "l" {
            let sizeStr = servingSize.truncatingRemainder(dividingBy: 1) == 0 ? 
                "\(Int(servingSize))" : String(format: "%.1f", servingSize)
            return "\(sizeStr)\(servingUnit)"
        }
        
        // For other units (bar, piece, etc.) - show size and unit
        let sizeStr = servingSize.truncatingRemainder(dividingBy: 1) == 0 ? 
            "\(Int(servingSize))" : String(format: "%.1f", servingSize)
        return "\(sizeStr)g"
    }
    
    // Helper function to determine the selected option text
    private func determineSelectedOption(servingSize: Double, servingUnit: String, foodItem: FoodItem) -> String {
        let unitLower = servingUnit.lowercased()
        let standardGramSizes: [Double] = [100, 200, 50, 1]
        
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
        
        // For known weight/volume units, show with unit
        if unitLower == "g" || unitLower == "onz" || unitLower == "oz" || unitLower == "l" {
            let sizeStr = servingSize.truncatingRemainder(dividingBy: 1) == 0 ? 
                "\(Int(servingSize))" : String(format: "%.1f", servingSize)
            return "\(sizeStr)\(servingUnit)"
        }
        
        // For other units (bar, piece, etc.) - show size and unit
        let sizeStr = servingSize.truncatingRemainder(dividingBy: 1) == 0 ? 
            "\(Int(servingSize))" : String(format: "%.1f", servingSize)
        return "\(sizeStr)g"
    }
    
    // Helper function to check if the current serving size and unit match the original serving size
    private func isOriginalServingSize(servingSize: Double, servingUnit: String, originalServingSize: String) -> Bool {
        let originalLower = originalServingSize.lowercased()
        let currentSize = String(format: "%.1f", servingSize).replacingOccurrences(of: ".0", with: "")
        let currentUnit = servingUnit.lowercased()
        
        return originalLower.contains(currentSize) && originalLower.contains(currentUnit)
    }
    
    // Helper function to check if this is one of our standard serving sizes
    private func isStandardServingSize(servingSize: Double, servingUnit: String) -> Bool {
        // Check against our standard options
        if (servingSize == 100 && servingUnit == "g") ||
           (servingSize == 200 && servingUnit == "g") ||
           (servingSize == 50 && servingUnit == "g") ||
           (servingSize == 240 && servingUnit == "ml") ||
           (servingSize == 15 && servingUnit == "ml") {
            return true
        }
        return false
    }
    
    // Helper function to format a custom serving size label
    private func formatCustomServingSize(servingSize: Double, servingUnit: String) -> String {
        // Format without decimal if it's a whole number
        let sizeStr = servingSize.truncatingRemainder(dividingBy: 1) == 0 ? 
            "\(Int(servingSize))" : String(format: "%.1f", servingSize)
            
        if servingUnit == "g" || servingUnit == "ml" || servingUnit == "onz" || servingUnit == "oz" || servingUnit == "L" {
            return "\(sizeStr)\(servingUnit)"
        } else {
            return "\(sizeStr) \(servingUnit)"
        }
    }
    
    // Helper function to check if this serving size matches the original
    private func checkIfMatchesOriginalServingSize(servingSize: Double, servingUnit: String) -> Bool {
        guard let originalServingSize = food.servingSize, !originalServingSize.isEmpty else { 
            return false 
        }
        return isOriginalServingSize(servingSize: servingSize, servingUnit: servingUnit, originalServingSize: originalServingSize)
    }
    
    // Convert serving size to grams for calculations
    private var servingSizeInGrams: Double {
        switch servingUnit {
        case "onz", "oz":
            return servingSize * 28.35 // 1 oz = 28.35g
        case "L":
            return servingSize * 1000.0 // 1L = 1000ml
        case "ml", "g":
            return servingSize
        default:
            return servingSize
        }
    }
    
    // Check if we're using the original serving size from database
    private var isUsingOriginalServingSize: Bool {
        // Check if the selected option contains "(original)" OR if using "serving" unit type
        // "serving" unit means the user selected the original serving size format
        let unitLower = servingUnit.lowercased()
        if unitLower == "serving" || unitLower == "servings" || unitLower == "meal" {
            return true
        }
        return selectedServingSizeOption?.contains("(original)") == true
    }
    
    // Functions to calculate nutrition values that explicitly depend on refreshID
    private func calculateCalories(_ refreshID: UUID) -> Int {
        print("FoodEntryEditView: calculateCalories - servingSize=\(servingSize), servingUnit=\(servingUnit), isOriginal=\(isUsingOriginalServingSize), selectedOption=\(selectedServingSizeOption ?? "nil"), refreshID=\(refreshID)")
        let result = NutritionCalculator.calculateCalories(
            foodCalories: food.calories,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize,
            servingDescription: isUsingOriginalServingSize ? food.servingSize : nil,
            servingQuantity: food.servingsPerPackage
        )
        // Validate result to prevent crashes (Int can't be NaN/Infinity)
        return result < 0 ? 0 : min(result, 999999)
    }
    
    private func calculateProtein(_ refreshID: UUID) -> Double {
        let result = NutritionCalculator.calculateMacro(
            macroValue: food.protein,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize,
            servingDescription: isUsingOriginalServingSize ? food.servingSize : nil,
            servingQuantity: food.servingsPerPackage
        )
        // Validate result to prevent crashes
        return (result.isNaN || result.isInfinite || result < 0) ? 0 : min(result, 99999)
    }
    
    private func calculateCarbs(_ refreshID: UUID) -> Double {
        let result = NutritionCalculator.calculateMacro(
            macroValue: food.carbs,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize,
            servingDescription: isUsingOriginalServingSize ? food.servingSize : nil,
            servingQuantity: food.servingsPerPackage
        )
        // Validate result to prevent crashes
        return (result.isNaN || result.isInfinite || result < 0) ? 0 : min(result, 99999)
    }
    
    private func calculateFat(_ refreshID: UUID) -> Double {
        let result = NutritionCalculator.calculateMacro(
            macroValue: food.fat,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize,
            servingDescription: isUsingOriginalServingSize ? food.servingSize : nil,
            servingQuantity: food.servingsPerPackage
        )
        // Validate result to prevent crashes
        return (result.isNaN || result.isInfinite || result < 0) ? 0 : min(result, 99999)
    }
    
    // Get the NOVA score (either actual or predicted)
    private var novaScore: Int {
        if food.novaScore > 0 {
            return food.novaScore
        } else {
            return NovaScoreService.shared.predictNovaScore(for: food)
        }
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
    
    // Check if the score is predicted or actual
    private var isScorePredicted: Bool {
        return food.novaScore == 0
    }
    
    // Check if we have a NOVA score (actual or predicted)
    private var hasNovaScore: Bool {
        return novaScore > 0
    }
    
    // Get description for the NOVA score
    private var novaScoreDescription: String {
        return NovaScoreService.shared.descriptionForNovaScore(novaScore)
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
    
    public var body: some View {
        Form {
            // Food title
            Text(food.name)
                .font(.custom("Montserrat-Bold", size: 24))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            
            // Serving section
            Section(header: Text("SERVING").font(.caption).foregroundColor(.secondary)) {
                // Serving size dropdown
                HStack {
                    Text("Size:")
                    Spacer()
                    Menu {
                        // Add original serving size as first option if available
                        if let originalServingSize = food.servingSize, !originalServingSize.isEmpty {
                            Button("\(originalServingSize) (original)") {
                                // Try to extract gram value from parentheses first (e.g., "1 serving (100 g)" -> 100)
                                var parsedSize: Double? = nil
                                var detectedUnit = "g"
                                
                                // Check for value in parentheses like "(100 g)" or "(100g)" or "(240 ml)"
                                if let parenRange = originalServingSize.range(of: "\\(\\s*([0-9.]+)\\s*(g|ml|oz|onz)?\\s*\\)", options: .regularExpression) {
                                    let parenContent = String(originalServingSize[parenRange])
                                    let numbers = parenContent.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                                    if let numValue = Double(numbers), numValue > 0 {
                                        parsedSize = numValue
                                        if parenContent.contains("ml") {
                                            detectedUnit = "ml"
                                        } else if parenContent.contains("oz") || parenContent.contains("onz") {
                                            detectedUnit = "onz"
                                        } else {
                                            detectedUnit = "g"
                                        }
                                    }
                                }
                                
                                // Fallback: parse leading number if no parentheses value found
                                if parsedSize == nil {
                                    let cleanedSize = originalServingSize
                                        .replacingOccurrences(of: "onz", with: "")
                                        .replacingOccurrences(of: "oz", with: "")
                                        .replacingOccurrences(of: "g", with: "")
                                        .replacingOccurrences(of: "ml", with: "")
                                        .replacingOccurrences(of: "L", with: "")
                                        .replacingOccurrences(of: "bar", with: "")
                                        .replacingOccurrences(of: "piece", with: "")
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                    
                                    // Extract first number from the string
                                    let numbers = cleanedSize.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).first { !$0.isEmpty }
                                    if let numStr = numbers, let numValue = Double(numStr) {
                                        parsedSize = numValue
                                    }
                                    
                                    // Determine unit from original serving size
                                    if originalServingSize.contains("onz") || originalServingSize.contains("oz") {
                                        detectedUnit = "onz"
                                    } else if originalServingSize.contains("ml") {
                                        detectedUnit = "ml"
                                    } else if originalServingSize.contains("L") {
                                        detectedUnit = "L"
                                    } else if originalServingSize.contains("bar") {
                                        detectedUnit = "bar"
                                    } else if originalServingSize.contains("piece") {
                                        detectedUnit = "piece"
                                    }
                                }
                                
                                if let size = parsedSize {
                                    servingSize = size
                                    servingUnit = detectedUnit
                                    selectedServingSizeOption = "\(originalServingSize) (original)"
                                    refreshID = UUID() // Force view refresh
                                    print("Selected original: servingSize=\(servingSize), servingUnit=\(servingUnit), isOriginal=\(isUsingOriginalServingSize)")
                                }
                            }
                        }
                        
                        Button("100g") {
                            servingSize = 100
                            servingUnit = "g"
                            selectedServingSizeOption = "100g"
                            refreshID = UUID() // Force view refresh
                            print("Selected 100g: servingSize=\(servingSize), servingUnit=\(servingUnit), isOriginal=\(isUsingOriginalServingSize)")
                        }
                        Button("200g") {
                            servingSize = 200
                            servingUnit = "g"
                            selectedServingSizeOption = "200g"
                            refreshID = UUID() // Force view refresh
                            print("Selected 200g: servingSize=\(servingSize), servingUnit=\(servingUnit), isOriginal=\(isUsingOriginalServingSize)")
                        }
                        Button("50g") {
                            servingSize = 50
                            servingUnit = "g"
                            selectedServingSizeOption = "50g"
                            refreshID = UUID() // Force view refresh
                            print("Selected 50g: servingSize=\(servingSize), servingUnit=\(servingUnit), isOriginal=\(isUsingOriginalServingSize)")
                        }
                        Button("1 cup") {
                            servingSize = 240
                            servingUnit = "ml"
                            selectedServingSizeOption = "1 cup"
                            refreshID = UUID() // Force view refresh
                            print("Selected 1 cup: servingSize=\(servingSize), servingUnit=\(servingUnit), isOriginal=\(isUsingOriginalServingSize)")
                        }
                        Button("1 tbsp") {
                            servingSize = 15
                            servingUnit = "ml"
                            selectedServingSizeOption = "1 tbsp"
                            refreshID = UUID() // Force view refresh
                            print("Selected 1 tbsp: servingSize=\(servingSize), servingUnit=\(servingUnit), isOriginal=\(isUsingOriginalServingSize)")
                        }
                        
                        // Add custom option for non-standard serving sizes
                        if !isStandardServingSize(servingSize: servingSize, servingUnit: servingUnit) && 
                           !checkIfMatchesOriginalServingSize(servingSize: servingSize, servingUnit: servingUnit) {
                            let customLabel = formatCustomServingSize(servingSize: servingSize, servingUnit: servingUnit)
                            Button(customLabel) {
                                // Keep the current serving size and unit
                                selectedServingSizeOption = customLabel
                                refreshID = UUID() // Force view refresh
                                print("Selected custom: \(customLabel), servingSize=\(servingSize), servingUnit=\(servingUnit)")
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedServingSizeOption ?? "Select serving size")
                                .foregroundColor(selectedServingSizeOption != nil ? .primary : .secondary)
                                .padding(.vertical, 8)
                                .padding(.leading, 12)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                                .padding(.trailing, 12)
                        }
                        .frame(maxWidth: 200)
                        .background(Color.appInsetBackground)
                        .cornerRadius(8)
                    }
                    .onChange(of: selectedServingSizeOption) { oldValue, newValue in
                        print("Serving size option changed from \(oldValue ?? "nil") to \(newValue ?? "nil")")
                        // Force view update
                        refreshID = UUID()
                    }
                }
                
                // Number of servings
                HStack {
                    Text("Number of servings:")
                    Spacer()
                    TextField("", value: $numberOfServings, formatter: createDecimalFormatter())
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .onChange(of: numberOfServings) { oldValue, newValue in
                            // Ensure value is greater than 0 and not too large
                            if newValue <= 0 {
                                numberOfServings = 0.1
                            } else if newValue > 9999 {
                                numberOfServings = 9999
                            }
                            // Force refresh of nutrition values
                            refreshID = UUID()
                            print("numberOfServings changed to \(newValue), refreshing nutrition values")
                            // No auto-save here - will only save when Save button is pressed
                        }
                }
            }
            
            // Nutrition section header
            Section(header: 
                Text("Nutrition")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                    .padding(.top, 0)
                    .padding(.bottom, -8)
                    .textCase(nil)
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    NutritionCirclesView(
                        calories: calculateCalories(refreshID),
                        protein: calculateProtein(refreshID),
                        carbs: calculateCarbs(refreshID),
                        fat: calculateFat(refreshID)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .cardStyle()
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            
            // Food Score section header
            if hasNovaScore {
                Section(header: 
                    Text("Food Score")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                        .padding(.top, 0)
                        .padding(.bottom, -8)
                        .textCase(nil)
                ) {
                    HStack(spacing: 12) {
                        // NOVA Score Card
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
                                .lineLimit(2)
                                .frame(height: 32)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .cardStyle()
                        
                        // Nutri-Score Card
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
                                .lineLimit(2)
                                .frame(height: 32)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .cardStyle()
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                
                // Nutri-Score Grade
                if let _ = food.nutriScoreGrade {
                    Divider()
                        .padding(.vertical, 4)
                    
                    HStack {
                        Text("Nutri-Score")
                        Spacer()
                        Text(nutriScoreGrade)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(nutriScoreColor)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                    
                    // Nutri-Score Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nutritional Quality:")
                            .font(.subheadline)
                        
                        HStack {
                            Circle()
                                .fill(nutriScoreColor)
                                .frame(width: 20, height: 20)
                                .overlay(Text(nutriScoreGrade).font(.caption).foregroundColor(.white))
                            
                            Text(nutriScoreDescription)
                                .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Only show delete button when editing
            if isEditing {
                Section {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Delete Entry")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .alert("Delete Food Entry", isPresented: $showDeleteConfirmation) {
                        Button("Cancel", role: .cancel) { }
                        Button("Delete", role: .destructive) {
                            deleteEntry()
                            presentationMode.wrappedValue.dismiss()
                        }
                    } message: {
                        Text("Are you sure you want to delete this food entry?")
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Edit Food")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.primary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Save") {
                        saveChanges()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.primary)
                } else {
                    Button("Add") {
                        addEntry()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(viewBackground)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            // Set initial selected serving size option if not already set (for new entries)
            if selectedServingSizeOption == nil {
                selectedServingSizeOption = determineSelectedOption(servingSize: servingSize, servingUnit: servingUnit, foodItem: food)
            }
        }
    }
    
    private func saveChanges() {
        if isEditing, let id = entryId {
            // Update existing entry
            FoodLogManager.shared.updateEntry(
                id: id,
                servingSize: servingSize,
                servingUnit: servingUnit,
                numberOfServings: numberOfServings
            )
            print("Updated \(food.name) in \(mealType) with \(numberOfServings) servings of \(servingSize)\(servingUnit)")
        } else {
            addEntry()
        }
    }
    
    private func addEntry() {
        // Calculate calories from macros if food has 0 calories but has macro data
        let effectiveCalories: Int
        if food.calories == 0 && (food.protein > 0 || food.carbs > 0 || food.fat > 0) {
            let calculatedCalories = (food.protein * 4.0) + (food.carbs * 4.0) + (food.fat * 9.0)
            effectiveCalories = Int(round(calculatedCalories))
        } else {
            effectiveCalories = food.calories
        }
        
        // Create food item with corrected calories
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
        
        // Add new entry
        FoodLogManager.shared.addEntry(
            foodItem: foodForLog,
            mealType: mealType,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings
        )
        print("Added \(food.name) to \(mealType) with \(numberOfServings) servings of \(servingSize)\(servingUnit)")
    }
    
    private func deleteEntry() {
        if let id = entryId {
            FoodLogManager.shared.deleteEntry(id: id)
            print("Deleted \(food.name) from \(mealType)")
        }
    }
    
    // Create a properly configured decimal formatter for the number of servings
    private func createDecimalFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2 // Allow up to 2 decimal places
        formatter.minimum = 0.1 // Only minimum limit, no maximum
        formatter.allowsFloats = true
        return formatter
    }
}

// Macronutrient display component
struct MacronutrientView: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(color)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// Nutrition circles display - extracted for performance
struct NutritionCirclesView: View {
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    
    var body: some View {
        HStack {
            // Protein
            VStack {
                ZStack {
                    Circle()
                        .stroke(lineWidth: 6)
                        .opacity(0.2)
                        .foregroundColor(Color.gray)
                    
                    Circle()
                        .trim(from: 0.0, to: 0.75)
                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.2))
                        .rotationEffect(Angle(degrees: 270.0))
                    
                    Text(formatMacro(protein))
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(width: 60, height: 60)
                
                Text("Protein")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.black)
            }
            .frame(maxWidth: .infinity)
            
            // Carbs
            VStack {
                ZStack {
                    Circle()
                        .stroke(lineWidth: 6)
                        .opacity(0.2)
                        .foregroundColor(Color.black)
                    
                    Circle()
                        .trim(from: 0.0, to: 0.6)
                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .foregroundColor(Color(red: 0.0, green: 0.5, blue: 1.0))
                        .rotationEffect(Angle(degrees: 270.0))
                    
                    Text(formatMacro(carbs))
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(width: 60, height: 60)
                
                Text("Carbs")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.black)
            }
            .frame(maxWidth: .infinity)
            
            // Fat
            VStack {
                ZStack {
                    Circle()
                        .stroke(lineWidth: 6)
                        .opacity(0.2)
                        .foregroundColor(Color.gray)
                    
                    Circle()
                        .trim(from: 0.0, to: 0.45)
                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0))
                        .rotationEffect(Angle(degrees: 270.0))
                    
                    Text(formatMacro(fat))
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(width: 60, height: 60)
                
                Text("Fat")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.black)
            }
            .frame(maxWidth: .infinity)
            
            // Calories
            VStack {
                ZStack {
                    Circle()
                        .stroke(lineWidth: 6)
                        .opacity(0.2)
                        .foregroundColor(Color.gray)
                    
                    Circle()
                        .trim(from: 0.0, to: 0.8)
                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .foregroundColor(Color(red: 1.0, green: 0.3, blue: 0.3))
                        .rotationEffect(Angle(degrees: 270.0))
                    
                    Text("\(calories)")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(width: 60, height: 60)
                
                Text("Calories")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.black)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func formatMacro(_ value: Double) -> String {
        if value.isNaN || value.isInfinite {
            return "0g"
        }
        return String(format: "%.0fg", value)
    }
}
