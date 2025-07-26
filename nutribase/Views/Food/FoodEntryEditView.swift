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
    
    // Environment
    @Environment(\.presentationMode) var presentationMode
    @State private var showDeleteConfirmation = false
    
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
        self._servingUnit = State(initialValue: entry.servingUnit)
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
    
    // Check if using original serving size from database
    private var isUsingOriginalServingSize: Bool {
        guard let selectedOption = selectedServingSizeOption else { return false }
        print("FoodEntryEditView: isUsingOriginalServingSize - Selected option: \(selectedOption), contains '(original)': \(selectedOption.contains("(original)"))")
        return selectedOption.contains("(original)")
    }
    
    // Computed properties for nutritional values based on quantity
    private var totalCalories: Int {
        return NutritionCalculator.calculateCalories(
            foodCalories: food.calories,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize
        )
    }
    
    private var totalProtein: Double {
        return NutritionCalculator.calculateMacro(
            macroValue: food.protein,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize
        )
    }
    
    private var totalCarbs: Double {
        return NutritionCalculator.calculateMacro(
            macroValue: food.carbs,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize
        )
    }
    
    private var totalFat: Double {
        return NutritionCalculator.calculateMacro(
            macroValue: food.fat,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize
        )
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
        case 1: return .green
        case 2: return .blue
        case 3: return .orange
        case 4: return .red
        default: return .gray
        }
    }
    
    // Check if the score is predicted or actual
    private var isScorePredicted: Bool {
        return food.novaScore == 0
    }
    
    // Get the Nutri-Score grade
    private var nutriScoreGrade: String {
        return food.nutriScoreGrade?.uppercased() ?? "?"
    }
    
    // Get color for the Nutri-Score grade
    private var nutriScoreColor: Color {
        switch food.nutriScoreGrade?.lowercased() {
        case "a": return .green
        case "b": return .blue
        case "c": return .yellow
        case "d": return .orange
        case "e": return .red
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
        // Debug: Print the Nutri-Score grade
        let _ = print("Nutri-Score Grade in FoodEntryEditView: \(food.nutriScoreGrade ?? "nil")")
        
        Form {
            // Food title
            Text(food.name)
                .font(.title)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            
            // Serving section
            Section(header: Text("SERVING").font(.caption).foregroundColor(.secondary)) {
                // Serving size
                HStack {
                    Text("Size: \(Int(servingSize))\(servingUnit)")
                    Spacer()
                    Menu {
                        // Add original serving size as first option if available
                        if let originalServingSize = food.servingSize, !originalServingSize.isEmpty {
                            Button("\(originalServingSize) (original)") {
                                // Parse the original serving size with better unit detection
                                let cleanedSize = originalServingSize
                                    .replacingOccurrences(of: "onz", with: "")
                                    .replacingOccurrences(of: "oz", with: "")
                                    .replacingOccurrences(of: "g", with: "")
                                    .replacingOccurrences(of: "ml", with: "")
                                    .replacingOccurrences(of: "L", with: "")
                                    .replacingOccurrences(of: "bar", with: "")
                                    .replacingOccurrences(of: "piece", with: "")
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                if let parsedSize = Double(cleanedSize) {
                                    servingSize = parsedSize
                                    
                                    // Determine unit from original serving size
                                    if originalServingSize.contains("onz") || originalServingSize.contains("oz") {
                                        servingUnit = "onz"
                                    } else if originalServingSize.contains("ml") {
                                        servingUnit = "ml"
                                    } else if originalServingSize.contains("L") {
                                        servingUnit = "L"
                                    } else if originalServingSize.contains("bar") {
                                        servingUnit = "bar"
                                    } else if originalServingSize.contains("piece") {
                                        servingUnit = "piece"
                                    } else {
                                        servingUnit = "g"
                                    }
                                    
                                    selectedServingSizeOption = "\(originalServingSize) (original)"
                                }
                            }
                        }
                        
                        Button("100g") {
                            servingSize = 100
                            servingUnit = "g"
                            selectedServingSizeOption = "100g"
                        }
                        Button("200g") {
                            servingSize = 200
                            servingUnit = "g"
                            selectedServingSizeOption = "200g"
                        }
                        Button("50g") {
                            servingSize = 50
                            servingUnit = "g"
                            selectedServingSizeOption = "50g"
                        }
                        Button("1 cup") {
                            servingSize = 240
                            servingUnit = "ml"
                            selectedServingSizeOption = "1 cup"
                        }
                        Button("1 tbsp") {
                            servingSize = 15
                            servingUnit = "ml"
                            selectedServingSizeOption = "1 tbsp"
                        }
                    } label: {
                        HStack {
                            Text("Select serving size")
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                                .padding(.leading, 12)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                                .padding(.trailing, 12)
                        }
                        .frame(maxWidth: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
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
                            // Ensure value is greater than 0
                            if newValue <= 0 {
                                numberOfServings = 0.1
                            }
                            // No auto-save here - will only save when Save button is pressed
                        }
                }
            }
            
            // Nutrition section
            Section(header: Text("NUTRITION").font(.caption).foregroundColor(.secondary)) {
                // Calories
                HStack {
                    Text("Calories")
                    Spacer()
                    Text("\(totalCalories)")
                        .fontWeight(.medium)
                }
                
                // Protein
                HStack {
                    Text("Protein")
                    Spacer()
                    Text(String(format: "%.1fg", totalProtein))
                        .fontWeight(.medium)
                }
                
                // Carbs
                HStack {
                    Text("Carbs")
                    Spacer()
                    Text(String(format: "%.1fg", totalCarbs))
                        .fontWeight(.medium)
                }
                
                // Fat
                HStack {
                    Text("Fat")
                    Spacer()
                    Text(String(format: "%.1fg", totalFat))
                        .fontWeight(.medium)
                }
            }
            
            // Food processing section
            Section(header: Text("FOOD PROCESSING").font(.caption).foregroundColor(.secondary)) {
                // NOVA Score
                HStack {
                    Text("NOVA Score")
                    Spacer()
                    Text("\(novaScore)")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(novaScoreColor)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                
                // NOVA Classification
                VStack(alignment: .leading, spacing: 8) {
                    Text("NOVA Classification:")
                        .font(.subheadline)
                    
                    HStack {
                        Circle()
                            .fill(novaScoreColor)
                            .frame(width: 20, height: 20)
                            .overlay(Text("\(novaScore)").font(.caption).foregroundColor(.white))
                        
                        Text(NovaScoreService.shared.descriptionForNovaScore(novaScore))
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
                
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
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Save") {
                        saveChanges()
                        presentationMode.wrappedValue.dismiss()
                    }
                } else {
                    Button("Add") {
                        addEntry()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
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
        // Add new entry
        FoodLogManager.shared.addEntry(
            foodItem: food,
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
