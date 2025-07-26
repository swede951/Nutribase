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
    @State private var servingSize: Double = 100.0
    @State private var numberOfServings: Double = 1.0
    @State private var selectedUnit: ServingUnit = .gram
    @State private var showServingSizeOptions: Bool = false
    @State private var selectedServingSizeOption: ServingSizeOption?
    @State private var customServingSize: Bool = false
    @State private var customServingLabel: String? = nil
    @Environment(\.presentationMode) var presentationMode
    
    // Get the NOVA score (only actual scores from database)
    private var novaScore: Int {
        return food.novaScore
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
    
    // Get description for the NOVA score
    private var novaScoreDescription: String {
        return NovaScoreService.shared.descriptionForNovaScore(novaScore)
    }
    
    // Check if we have an actual NOVA score from the database
    private var hasActualNovaScore: Bool {
        return food.novaScore > 0
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
    
    // Determine if the food is likely a drink
    private var isDrink: Bool {
        let drinkKeywords = ["coffee", "tea", "juice", "water", "milk", "soda", "drink", "beverage", "smoothie", "shake", "espresso", "latte", "cappuccino"]
        return drinkKeywords.contains { food.name.lowercased().contains($0) }
    }
    
    // Check if using original serving size from database
    private var isUsingOriginalServingSize: Bool {
        guard let selectedOption = selectedServingSizeOption else {
            print("BasicFoodEntryView: isUsingOriginalServingSize - No selected option, returning false")
            return false 
        }
        print("BasicFoodEntryView: isUsingOriginalServingSize - Selected option: \(selectedOption.label), isOriginal: \(selectedOption.isOriginal)")
        return selectedOption.isOriginal
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
    
    private var totalCalories: Int {
        return NutritionCalculator.calculateCalories(
            foodCalories: food.calories,
            servingSize: servingSize,
            servingUnit: servingUnitString,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize
        )
    }
    
    private var totalProtein: Double {
        return NutritionCalculator.calculateMacro(
            macroValue: food.protein,
            servingSize: servingSize,
            servingUnit: servingUnitString,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize
        )
    }
    
    private var totalCarbs: Double {
        return NutritionCalculator.calculateMacro(
            macroValue: food.carbs,
            servingSize: servingSize,
            servingUnit: servingUnitString,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize
        )
    }
    
    private var totalFat: Double {
        return NutritionCalculator.calculateMacro(
            macroValue: food.fat,
            servingSize: servingSize,
            servingUnit: servingUnitString,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize
        )
    }
    
    var body: some View {
            List {
            // Food name
            Section {
                Text(food.name)
                    .font(.headline)
            }
            
            // Serving controls
            Section(header: Text("Serving")) {
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
                        customServingSize = false
                        
                        // Convert the serving size when changing units
                        if newUnit == .liter && selectedUnit == .milliliter {
                            servingSize = servingSize / 1000.0
                        } else if newUnit == .milliliter && selectedUnit == .liter {
                            servingSize = servingSize * 1000.0
                        }
                    }
                    
                    // Serving size dropdown
                    VStack(alignment: .leading) {
                        Text("Size:")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        Menu {
                            // Add options based on unit
                            if selectedUnit == .milliliter {
                                Button(action: {
                                    servingSize = 100.0
                                    selectedServingSizeOption = ServingSizeOption(label: "100ml (standard)", value: 100.0, unit: .milliliter)
                                    customServingSize = false
                                }) {
                                    Text("100ml (standard)")
                                }
                                
                                Button(action: {
                                    servingSize = 200.0
                                    selectedServingSizeOption = ServingSizeOption(label: "200ml", value: 200.0, unit: .milliliter)
                                    customServingSize = false
                                }) {
                                    Text("200ml")
                                }
                                
                                Button(action: {
                                    servingSize = 250.0
                                    selectedServingSizeOption = ServingSizeOption(label: "250ml (1 cup)", value: 250.0, unit: .milliliter)
                                    customServingSize = false
                                }) {
                                    Text("250ml (1 cup)")
                                }
                                
                                Button(action: {
                                    servingSize = 330.0
                                    selectedServingSizeOption = ServingSizeOption(label: "330ml (1 can)", value: 330.0, unit: .milliliter)
                                    customServingSize = false
                                }) {
                                    Text("330ml (1 can)")
                                }
                                
                                Button(action: {
                                    servingSize = 500.0
                                    selectedServingSizeOption = ServingSizeOption(label: "500ml", value: 500.0, unit: .milliliter)
                                    customServingSize = false
                                }) {
                                    Text("500ml")
                                }
                            } else if selectedUnit == .liter {
                                Button(action: {
                                    servingSize = 0.5
                                    selectedServingSizeOption = ServingSizeOption(label: "0.5L", value: 0.5, unit: .liter)
                                    customServingSize = false
                                }) {
                                    Text("0.5L")
                                }
                                
                                Button(action: {
                                    servingSize = 1.0
                                    selectedServingSizeOption = ServingSizeOption(label: "1L", value: 1.0, unit: .liter)
                                    customServingSize = false
                                }) {
                                    Text("1L")
                                }
                                
                                Button(action: {
                                    servingSize = 1.5
                                    selectedServingSizeOption = ServingSizeOption(label: "1.5L", value: 1.5, unit: .liter)
                                    customServingSize = false
                                }) {
                                    Text("1.5L")
                                }
                                
                                Button(action: {
                                    servingSize = 2.0
                                    selectedServingSizeOption = ServingSizeOption(label: "2L", value: 2.0, unit: .liter)
                                    customServingSize = false
                                }) {
                                    Text("2L")
                                }
                            }
                            
                            // Add custom option
                            Button(action: {
                                customServingSize = true
                                selectedServingSizeOption = nil
                            }) {
                                Text("Custom...")
                            }
                        } label: {
                            HStack {
                                Text(selectedServingSizeOption?.label ?? "Select serving size")
                                    .foregroundColor(selectedServingSizeOption == nil ? .gray : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        if customServingSize {
                            HStack {
                                Text("Custom size:")
                                Spacer()
                                TextField("Enter value", text: Binding(
                                    get: { String(format: selectedUnit == .liter ? "%.2f" : "%.0f", servingSize) },
                                    set: { if let value = Double($0) { servingSize = value } }
                                ))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                Text(selectedUnit.rawValue)
                            }
                            .padding(.top, 8)
                        }
                    }
                } else {
                    // Standard gram measurement for food
                    VStack(alignment: .leading) {
                        Text("Size:")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        Menu {
                            // Add original serving size if available
                            if let originalServingSize = food.servingSize, !originalServingSize.isEmpty {
                                // Try to extract numeric value from serving size string
                                let pattern = "(\\d+(?:\\.\\d+)?)\\s*([a-zA-Z]+)"
                                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                                    let nsString = originalServingSize as NSString
                                    let matches = regex.matches(in: originalServingSize, options: [], range: NSRange(location: 0, length: nsString.length))
                                    
                                    if let match = matches.first {
                                        let valueRange = match.range(at: 1)
                                        let unitRange = match.range(at: 2)
                                        
                                        if valueRange.location != NSNotFound, unitRange.location != NSNotFound {
                                            let valueStr = nsString.substring(with: valueRange)
                                            let unitStr = nsString.substring(with: unitRange).lowercased()
                                            
                                            if let value = Double(valueStr) {
                                                let unit: ServingUnit = unitStr == "ml" ? .milliliter : 
                                                                        unitStr == "l" ? .liter : .gram
                                                
                                                // Format the value to 2 decimal places if needed
                                                let formattedValue = value.truncatingRemainder(dividingBy: 1) == 0 ? 
                                                    String(format: "%.0f", value) : String(format: "%.2f", value)
                                                let formattedServingSize = "\(formattedValue)\(unitStr) (original)"
                                                
                                                Button(action: {
                                                    servingSize = value
                                                    selectedUnit = unit
                                                    selectedServingSizeOption = ServingSizeOption(label: formattedServingSize, value: value, unit: unit)
                                                    customServingSize = false
                                                }) {
                                                    Text(formattedServingSize)
                                                }
                                                
                                                Divider()
                                            }
                                        }
                                    } else {
                                        // If no match, just display the original serving size as an option
                                        Button(action: {
                                            // Default to 100g if we can't parse
                                            servingSize = 100.0
                                            selectedServingSizeOption = ServingSizeOption(label: "\(originalServingSize) (original)", value: 100.0, unit: .gram)
                                            customServingSize = false
                                        }) {
                                            Text("\(originalServingSize) (original)")
                                        }
                                        
                                        Divider()
                                    }
                                }
                            }
                            
                            // Add common food serving sizes
                            Button(action: {
                                servingSize = 100.0
                                selectedServingSizeOption = ServingSizeOption(label: "100g (standard)", value: 100.0, unit: .gram)
                                customServingSize = false
                            }) {
                                Text("100g (standard)")
                            }
                            
                            Button(action: {
                                servingSize = 50.0
                                selectedServingSizeOption = ServingSizeOption(label: "50g (half serving)", value: 50.0, unit: .gram)
                                customServingSize = false
                            }) {
                                Text("50g (half serving)")
                            }
                            
                            Button(action: {
                                servingSize = 200.0
                                selectedServingSizeOption = ServingSizeOption(label: "200g (double serving)", value: 200.0, unit: .gram)
                                customServingSize = false
                            }) {
                                Text("200g (double serving)")
                            }
                            
                            Button(action: {
                                servingSize = 28.0
                                selectedServingSizeOption = ServingSizeOption(label: "28g (1 oz)", value: 28.0, unit: .gram)
                                customServingSize = false
                            }) {
                                Text("28g (1 oz)")
                            }
                            
                            // Add custom option
                            Button(action: {
                                customServingSize = true
                                selectedServingSizeOption = nil
                            }) {
                                Text("Custom...")
                            }
                        } label: {
                            HStack {
                                Text(selectedServingSizeOption?.label ?? "Select serving size")
                                    .foregroundColor(selectedServingSizeOption == nil ? .gray : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        if customServingSize {
                            HStack {
                                Text("Custom size:")
                                Spacer()
                                TextField("Enter value", text: Binding(
                                    get: { 
                                        servingSize.truncatingRemainder(dividingBy: 1) == 0 ? 
                                            String(format: "%.0f", servingSize) : String(format: "%.2f", servingSize)
                                    },
                                    set: { if let value = Double($0) { servingSize = value } }
                                ))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                Text("g")
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                
                HStack {
                    Text("Number of servings:")
                    Spacer()
                    TextField("1.00", text: Binding(
                        get: { String(format: "%.2f", numberOfServings) },
                        set: { if let value = Double($0), value > 0 { numberOfServings = value } }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        }
                    }
                }
            }
            
            // Nutrition info
            Section(header: Text("Nutrition")) {
                NutritionRow(label: "Calories", value: "\(totalCalories)")
                NutritionRow(label: "Protein", value: String(format: "%.1fg", totalProtein))
                NutritionRow(label: "Carbs", value: String(format: "%.1fg", totalCarbs))
                NutritionRow(label: "Fat", value: String(format: "%.1fg", totalFat))
            }
            
            // NOVA score section - only shown when there's an actual score from the database
            if hasActualNovaScore {
                Section(header: Text("Food Processing")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("NOVA Score")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(novaScore)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(novaScoreColor)
                                .cornerRadius(12)
                        }
                        
                        Text(novaScoreDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Display NOVA score reference information
                        Group {
                            HStack(spacing: 4) {
                                Text("1")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                
                                Text("Unprocessed or minimally processed")
                                    .font(.caption)
                            }
                            
                            HStack(spacing: 4) {
                                Text("2")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                
                                Text("Processed culinary ingredients")
                                    .font(.caption)
                            }
                            
                            HStack(spacing: 4) {
                                Text("3")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                
                                Text("Processed foods")
                                    .font(.caption)
                            }
                            
                            HStack(spacing: 4) {
                                Text("4")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                
                                Text("Ultra-processed foods")
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                // Add Nutri-Score section if available
                if let nutriGrade = food.nutriScoreGrade {
                    Divider()
                        .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Nutri-Score")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text(nutriGrade.uppercased())
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(nutriScoreColor)
                                .cornerRadius(12)
                        }
                        
                        Text(nutriScoreDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Add button
            Section {
                Button(action: {
                    addFoodToMeal()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Add to \(mealType)")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 8)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Add Food")
        .navigationBarItems(trailing: Button("Add") {
            addFoodToMeal()
            presentationMode.wrappedValue.dismiss()
        })
        .onAppear {
            selectDefaultServingSize()
        }
    }
    
    private func selectDefaultServingSize() {
        // First check if we have cached serving information (from recently added foods)
        if let cachedSize = food.cachedServingSize,
           let cachedUnit = food.cachedServingUnit,
           let cachedServings = food.cachedNumberOfServings {
            // Use cached serving information
            servingSize = cachedSize
            numberOfServings = cachedServings
            selectedUnit = cachedUnit == "ml" ? .milliliter : 
                          cachedUnit == "L" ? .liter : .gram
            
            // Create a serving size option that matches the cached selection
            let unitString = cachedUnit
            let formattedSize = cachedSize.truncatingRemainder(dividingBy: 1) == 0 ? 
                String(format: "%.0f", cachedSize) : String(format: "%.1f", cachedSize)
            
            selectedServingSizeOption = ServingSizeOption(
                label: "\(formattedSize)\(unitString)",
                value: cachedSize,
                unit: selectedUnit
            )
            
            return
        }
        
        // Check if the food has a serving size specified
        if let originalServingSize = food.servingSize, !originalServingSize.isEmpty {
            // First, handle common non-standard formats like "1bar" or "1 bar (36 g)"
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
                        let unitRange = match.range(at: 2)
                        
                        let valueStr = nsString.substring(with: valueRange)
                        let unitStr = nsString.substring(with: unitRange).lowercased()
                        
                        if let value = Double(valueStr) {
                            let unit: ServingUnit = unitStr == "ml" ? .milliliter : 
                                                    unitStr == "l" ? .liter : .gram
                            
                            // Set the values using the extracted weight
                            servingSize = value
                            selectedUnit = unit
                            selectedServingSizeOption = ServingSizeOption(label: "\(originalServingSize) (original)", value: value, unit: unit, isOriginal: true)
                            customServingLabel = originalServingSize // Set the custom label to show in the UI
                            print("Selected original non-standard serving size with extracted weight: \(originalServingSize), weight: \(value)\(unitStr), isOriginal: true)")
                            return
                        }
                    }
                }
                
                // If no weight found in parentheses, use default
                servingSize = 1.0 // Default to 1 of whatever the unit is
                selectedUnit = .gram // This won't be used in display since we're using a custom label
                selectedServingSizeOption = ServingSizeOption(label: "\(originalServingSize) (original)", value: 1.0, unit: .gram, isOriginal: true)
                customServingLabel = originalServingSize // Set the custom label to show in the UI
                print("Selected original non-standard serving size: \(originalServingSize), isOriginal: true")
                return
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
                    
                    if let value = Double(valueStr) {
                        let unit: ServingUnit = unitStr == "ml" ? .milliliter : 
                                                unitStr == "l" ? .liter : .gram
                        
                        // Set the values
                        servingSize = value
                        selectedUnit = unit
                        
                        // Format the value to 2 decimal places if needed
                        let formattedValue = value.truncatingRemainder(dividingBy: 1) == 0 ? 
                            String(format: "%.0f", value) : String(format: "%.2f", value)
                        let formattedServingSize = "\(formattedValue)\(unitStr) (original)"
                        
                        selectedServingSizeOption = ServingSizeOption(label: formattedServingSize, value: value, unit: unit, isOriginal: true)
                        // For standard sizes like 100g, we don't need a custom label
                        customServingLabel = nil
                        print("Selected original standard serving size: \(formattedServingSize), isOriginal: true")
                        return
                    }
                }
            }
            
            // If we couldn't parse it with the regex but there is an original serving size,
            // just use it as is
            servingSize = 1.0 // Default to 1 of whatever the unit is
            selectedUnit = .gram // This won't be used in display since we're using a custom label
            selectedServingSizeOption = ServingSizeOption(label: "\(originalServingSize) (original)", value: 1.0, unit: .gram, isOriginal: true)
            customServingLabel = originalServingSize // Set the custom label to show in the UI
            print("Selected original serving size as fallback: \(originalServingSize), isOriginal: true")
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
        
        // Add the food to the FoodLogManager
        FoodLogManager.shared.addEntry(
            foodItem: food,
            mealType: mealType,
            servingSize: servingSize,
            servingUnit: unitString,
            numberOfServings: numberOfServings,
            date: selectedDate
        )
        
        // Create a cached version of the food item that preserves the original serving size
        // but stores the actual serving information used for display purposes
        let cachedFood = FoodItem(
            name: food.name,
            brandName: food.brandName,
            barcode: food.barcode,
            calories: food.calories,
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
            cachedNumberOfServings: numberOfServings
        )
        
        // Call the callback to add this cached food to recently used foods
        onFoodAdded?(cachedFood)
        
        print("Added \(food.name) to \(mealType) with \(numberOfServings) servings of \(servingSize)\(unitString)")
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
