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
    
    // Optional initial values for cached serving information
    let initialServingSize: Double?
    let initialServingUnit: String?
    let initialNumberOfServings: Double?
    let initialSelectedServingSizeOption: String?
    
    @State private var servingSize: Double = 100.0
    @State private var numberOfServings: Double = 1.0
    @State private var selectedUnit: ServingUnit = .gram
    @State private var showServingSizeOptions: Bool = false
    @State private var selectedServingSizeOption: ServingSizeOption?

    @State private var customServingLabel: String? = nil
    @State private var refreshID = UUID() // Add refreshID to force view refresh
    @State private var isInitialized = false
    @State private var showingBarcodeScanner = false
    @Environment(\.presentationMode) var presentationMode
    
    // Get the NOVA score (actual or predicted)
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
    
    // Get description for the NOVA score
    private var novaScoreDescription: String {
        return NovaScoreService.shared.descriptionForNovaScore(novaScore)
    }
    
    // Check if we have a NOVA score (actual or predicted)
    private var hasNovaScore: Bool {
        return novaScore > 0
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
        return NutritionCalculator.calculateCalories(
            foodCalories: food.calories,
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
            macroValue: food.protein,
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
            macroValue: food.carbs,
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
            macroValue: food.fat,
            servingSize: servingSize,
            servingUnit: servingUnitString,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isUsingOriginalServingSize,
            servingDescription: isUsingOriginalServingSize ? food.servingSize : nil,
            servingQuantity: food.servingsPerPackage
        )
    }
    
    var body: some View {
        List {
            // Food name and brand
            VStack(alignment: .center, spacing: 4) {
                Text(food.name)
                    .font(.custom("Montserrat-Bold", size: 28))
                    .multilineTextAlignment(.center)
                
                if let brandName = food.brandName, !brandName.isEmpty {
                    Text(brandName)
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 0)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            
            // Serving section header
            Section(header: 
                Text("Serving")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                    .padding(.top, 0)
                    .padding(.bottom, -8)
                    .textCase(nil)
            ) {
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
                            
                            Button("25g") {
                                servingSize = 25
                                selectedUnit = .gram
                                selectedServingSizeOption = ServingSizeOption(
                                    label: "25g",
                                    value: 25,
                                    unit: .gram
                                )
                                customServingLabel = "25g"
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
                    TextField("1", value: $numberOfServings, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onChange(of: numberOfServings) { _, _ in
                            refreshID = UUID()
                        refreshID = UUID() // Force view refresh when number of servings changes
                        // Debug removed for performance("Number of servings changed to \(numberOfServings), refreshID updated")
                    }
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .cardStyle()
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            
            // Nutrition section header
            Section(header: 
                Text("Nutrition")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                    .padding(.top, 0)
                    .padding(.bottom, -8)
                    .textCase(nil)
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        // Protein
                        VStack {
                            ZStack {
                                Circle()
                                    .stroke(lineWidth: 6)
                                    .opacity(0.2)
                                    .foregroundColor(Color.gray)
                                
                                Circle()
                                    .trim(from: 0.0, to: 0.75) // Sample progress
                                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.2)) // Green for protein
                                    .rotationEffect(Angle(degrees: 270.0))
                                
                                Text(String(format: "%.0fg", totalProtein(refreshID)))
                                    .font(.custom("Montserrat-SemiBold", size: 14))
                            }
                            .frame(width: 60, height: 60)
                            
                            Text("Protein")
                                .font(.custom("Montserrat-SemiBold", size: 12))
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
                                    .trim(from: 0.0, to: 0.6) // Sample progress
                                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .foregroundColor(Color(red: 0.0, green: 0.5, blue: 1.0)) // Blue for carbs
                                    .rotationEffect(Angle(degrees: 270.0))
                                
                                Text(String(format: "%.0fg", totalCarbs(refreshID)))
                                    .font(.custom("Montserrat-SemiBold", size: 14))
                            }
                            .frame(width: 60, height: 60)
                            
                            Text("Carbs")
                                .font(.custom("Montserrat-SemiBold", size: 12))
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
                                    .trim(from: 0.0, to: 0.45) // Sample progress
                                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0)) // Orange for fat
                                    .rotationEffect(Angle(degrees: 270.0))
                                
                                Text(String(format: "%.0fg", totalFat(refreshID)))
                                    .font(.custom("Montserrat-SemiBold", size: 14))
                            }
                            .frame(width: 60, height: 60)
                            
                            Text("Fat")
                                .font(.custom("Montserrat-SemiBold", size: 12))
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
                                    .trim(from: 0.0, to: 0.8) // Sample progress
                                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .foregroundColor(Color(red: 0.9, green: 0.2, blue: 0.3)) // Red for calories
                                    .rotationEffect(Angle(degrees: 270.0))
                                
                                Text("\(totalCalories(refreshID))")
                                    .font(.custom("Montserrat-SemiBold", size: 14))
                            }
                            .frame(width: 60, height: 60)
                            
                            Text("Calories")
                                .font(.custom("Montserrat-SemiBold", size: 12))
                                .foregroundColor(Color.black)
                        }
                        .frame(maxWidth: .infinity)
                    }
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
                        .foregroundColor(.black)
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
                                    .foregroundColor(.black)
                            }
                            .frame(width: 80, height: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(novaScoreColor)
                            )
                            
                            Text("Nova Score")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                            
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
                                    .foregroundColor(.black)
                            }
                            .frame(width: 80, height: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(nutriScoreColor)
                            )
                            
                            Text("Nutri-Score")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                            
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
                
                // Add & Scan Again button section
                if showScanAgainButton {
                    Section {
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
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .background(Color(hex: "#F0F1F4"))
        .navigationTitle("Add Food")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: Button("Add") {
            addFoodToMeal()
        })
        .sheet(isPresented: $showingBarcodeScanner) {
            BarcodeScannerView(scannedBarcode: .constant(nil), isPresented: $showingBarcodeScanner)
        }
        .onAppear {
            // Set navigation bar background to systemGray6
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemGray6
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            
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
        
        // First priority: Use cached values if available
        if let cachedSize = initialServingSize,
           let cachedUnit = initialServingUnit,
           let cachedServings = initialNumberOfServings,
           let cachedOption = initialSelectedServingSizeOption {
            
            // Using cached values
            servingSize = cachedSize
            numberOfServings = cachedServings
            selectedUnit = cachedUnit == "ml" ? .milliliter : .gram
            
            // Set the selected serving size option
            selectedServingSizeOption = ServingSizeOption(
                label: cachedOption,
                value: cachedSize,
                unit: selectedUnit,
                isOriginal: cachedOption.contains("(original)")
            )
            
            // If it's a custom option, set the custom label
            if !cachedOption.contains("(original)") && !isStandardServingSize(cachedSize, cachedUnit) {
                customServingLabel = cachedOption
            }
            
            refreshID = UUID()
            print("Set servingSize = \(servingSize), numberOfServings = \(numberOfServings), selectedUnit = \(selectedUnit)")
            print("Set selectedServingSizeOption = \(cachedOption)")
            return
        }
        
        // Second priority: Use the original serving size from the database if available
        if let originalServingSize = food.servingSize, !originalServingSize.isEmpty {
            print("=== selectDefaultServingSize ===")
            print("Original serving size from database: '\(originalServingSize)'")
            
            // Try to extract weight from the serving size description
            if let (weight, unit) = NutritionCalculator.extractWeightFromServingSize(originalServingSize) {
                // Use extracted weight and unit
                servingSize = weight
                selectedUnit = unit == "ml" ? .milliliter : .gram
                print("✅ Successfully extracted from '\(originalServingSize)': \(weight)\(unit)")
                print("Set servingSize = \(servingSize), selectedUnit = \(selectedUnit)")
            } else {
                // Fallback: assume it's 1 serving of whatever the description says
                servingSize = 1.0
                selectedUnit = .gram
                print("❌ Could not extract weight from '\(originalServingSize)', using 1.0g as fallback")
                print("Set servingSize = \(servingSize), selectedUnit = \(selectedUnit)")
            }
            
            selectedServingSizeOption = ServingSizeOption(
                label: "\(originalServingSize) (original)", 
                value: servingSize, 
                unit: selectedUnit, 
                isOriginal: true
            )
            customServingLabel = originalServingSize
            refreshID = UUID() // Force view refresh after setting default
            print("Using original serving size: \(servingSize)\(selectedUnit == .gram ? "g" : "ml")")
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
        
        // Debug output before adding to FoodLogManager
        print("=== Adding food to meal ===")
        print("Food: \(food.name)")
        print("ServingSize: \(servingSize)")
        print("ServingUnit: \(unitString)")
        print("NumberOfServings: \(numberOfServings)")
        print("Total weight: \(numberOfServings * servingSize)\(unitString)")
        print("SelectedServingSizeOption: \(selectedServingSizeOption?.label ?? "nil")")
        print("CustomServingLabel: \(customServingLabel ?? "nil")")
        print("IsUsingOriginalServingSize: \(isUsingOriginalServingSize)")
        print("CachedSelectedServingSizeOption: \(selectedServingSizeOption?.label ?? customServingLabel ?? "nil")")
        
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
        
        print("Added \(food.name) to \(mealType) with \(numberOfServings) servings of \(servingSize)\(unitString)")
        print("🎯 Tracked food selection for personalized ranking: \(food.name)")
    }
    
    // Add to recent foods directly (for barcode scanner items)
    private func addToRecentFoodsDirectly(_ food: FoodItem) {
        let recentFoodsKey = "recentlyAddedFoods"
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
