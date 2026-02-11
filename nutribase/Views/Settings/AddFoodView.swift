import SwiftUI
import VisionKit
import Vision

enum AddFoodStep: Int, CaseIterable {
    case basicInfo = 0
    case nutrition = 1
    case ingredients = 2
    
    var title: String {
        switch self {
        case .basicInfo: return "Basic Info & Serving"
        case .nutrition: return "Nutrition Facts"
        case .ingredients: return "Ingredients"
        }
    }
    
    var icon: String {
        switch self {
        case .basicInfo: return "info.circle"
        case .nutrition: return "chart.bar"
        case .ingredients: return "list.bullet"
        }
    }
}

struct AddFoodView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) var dismiss
    @StateObject private var typesenseService = TypesenseDirectService.shared
    @StateObject private var aiService = AIFoodAutofillService.shared
    
    var mealType: String = "Other"
    var selectedDate: Date = Date()
    var isPresentedAsSheet: Bool = false  // Set to true when presented as sheet
    
    @State private var foodName = ""
    @State private var brandName = ""
    @State private var barcode = ""
    
    // AI Autofill state
    @State private var isAILoading = false
    @State private var showingAIError = false
    @State private var aiErrorMessage = ""
    
    // Macronutrients
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fiber = ""
    @State private var sugar = ""
    
    // Micronutrients
    @State private var sodium = ""
    @State private var saturatedFat = ""
    @State private var transFat = ""
    @State private var cholesterol = ""
    @State private var potassium = ""
    @State private var calcium = ""
    @State private var iron = ""
    @State private var vitaminC = ""
    @State private var vitaminA = ""
    
    // Serving information
    @State private var servingSize = ""
    @State private var servingUnit = "g"
    @State private var servingsPerContainer = ""
    
    // Additional info
    @State private var ingredients = ""
    
    // Multi-step form state
    @State private var currentStep: AddFoodStep = .basicInfo
    
    // Scanner state
    @State private var isScanningBarcode = false
    @State private var scannedBarcode: String? = nil
    @State private var isScanningText = false
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage? = nil
    @State private var showingNutritionScanner = false
    @State private var nutritionImage: UIImage? = nil
    @State private var showingIngredientsScanner = false
    @State private var ingredientsImage: UIImage? = nil
    
    // Barcode not found state
    @State private var showingBarcodeNotFoundAlert = false
    @State private var notFoundBarcode: String = ""
    @State private var showingAddNewFood = false
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedFood: FoodItem? = nil
    @State private var showingFoodEntry = false
    @State private var isLoading = false
    @State private var showingAISuccessAlert = false
    @State private var aiConfidence = ""
    
    private var progressIndicator: some View {
        HStack {
            ForEach(0..<3) { index in
                Circle()
                    .fill(index <= currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                
                if index < 2 {
                    Rectangle()
                        .fill(index < currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
        VStack(spacing: 0) {
            // Custom navigation bar (only show when presented as sheet)
            if isPresentedAsSheet {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Cancel")
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Text(currentStep.title)
                        .font(.headline)
                    
                    Spacer()
                    
                    // Invisible button for symmetry
                    Button(action: {}) {
                        Text("Cancel")
                            .foregroundColor(.clear)
                    }
                    .disabled(true)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                
                Divider()
            }
            
            // Progress indicator
            progressIndicator
            
            // Step content
            Form {
                switch currentStep {
                case .basicInfo:
                    basicInfoSection()
                case .nutrition:
                    nutritionSection()
                case .ingredients:
                    ingredientsSection()
                }
            }
            .scrollContentBackground(.hidden)
            
            // Navigation buttons
            HStack {
                if currentStep != .basicInfo {
                    Button("Previous") {
                        withAnimation {
                            currentStep = AddFoodStep(rawValue: currentStep.rawValue - 1) ?? .basicInfo
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if currentStep == .ingredients {
                    Button("Submit") {
                        submitFood()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(foodName.isEmpty)
                } else {
                    Button("Next") {
                        withAnimation {
                            currentStep = AddFoodStep(rawValue: currentStep.rawValue + 1) ?? .ingredients
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(currentStep == .basicInfo && foodName.isEmpty)
                }
            }
            .padding()
        }
        }
        .navigationTitle(isPresentedAsSheet ? "" : currentStep.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFoodEntry) {
            if let food = selectedFood {
                BasicFoodEntryView(
                    food: food,
                    mealType: mealType,
                    selectedDate: selectedDate,
                    onFoodAdded: { addedFood in
                        // Add to recent foods when food is added via barcode scanner
                        addToRecentFoodsDirectly(addedFood)
                    },
                    editingEntry: nil,
                    initialServingSize: nil,
                    initialServingUnit: nil,
                    initialNumberOfServings: nil,
                    initialSelectedServingSizeOption: nil
                )
            }
        }
        .sheet(isPresented: $isScanningBarcode) {
            BarcodeScannerView(
                scannedBarcode: $scannedBarcode,
                isPresented: $isScanningBarcode
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: .camera)
        }
        .sheet(isPresented: $showingNutritionScanner) {
            ImagePicker(image: $nutritionImage, sourceType: .camera)
        }
        .sheet(isPresented: $showingIngredientsScanner) {
            ImagePicker(image: $ingredientsImage, sourceType: .camera)
        }
        .sheet(isPresented: $showingAddNewFood) {
            AddFoodView(mealType: mealType, selectedDate: selectedDate, isPresentedAsSheet: true)
                .onAppear {
                    // Pre-populate the barcode if we have one
                    if !notFoundBarcode.isEmpty {
                        // This would need to be passed to the new AddFoodView instance
                    }
                }
        }
        .alert("Barcode Not Found", isPresented: $showingBarcodeNotFoundAlert) {
            Button("Add New Food") {
                showingAddNewFood = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("No food found for barcode \(notFoundBarcode). Would you like to add this as a new food item?")
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Info"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .alert("AI Autofill Complete", isPresented: $showingAISuccessAlert) {
            Button("OK") { }
        } message: {
            Text("Nutrition data has been filled in automatically.\n\nConfidence: \(aiConfidence)\n\nPlease review the values and adjust if needed.")
        }
        .alert("AI Autofill Error", isPresented: $showingAIError) {
            Button("OK") { }
        } message: {
            Text(aiErrorMessage)
        }
        .onChange(of: scannedBarcode) { _, newBarcode in
            if let barcode = newBarcode {
                self.barcode = barcode
                // Don't lookup - just populate the field for new food entry
                scannedBarcode = nil // Reset for next scan
            }
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                recognizeText(from: image)
            }
        }
        .onChange(of: nutritionImage) { _, newImage in
            if let image = newImage {
                recognizeNutritionFacts(from: image)
            }
        }
        .onChange(of: ingredientsImage) { _, newImage in
            if let image = newImage {
                recognizeIngredients(from: image)
            }
        }
    }
    
    private func submitFood() {
        guard !foodName.isEmpty else {
            alertMessage = "Please enter a food name"
            showingAlert = true
            return
        }
        
        // Create comprehensive food document
        var document: [String: Any] = [
            "name": foodName
        ]
        
        if !brandName.isEmpty { document["brand_name"] = brandName }
        if !barcode.isEmpty { document["barcode"] = barcode }
        if !servingSize.isEmpty { document["serving_size"] = Double(servingSize) ?? 0 }
        if !servingUnit.isEmpty { document["serving_unit"] = servingUnit }
        if !servingsPerContainer.isEmpty { document["servings_per_container"] = Double(servingsPerContainer) ?? 0 }
        if !calories.isEmpty { document["calories"] = Double(calories) ?? 0 }
        if !protein.isEmpty { document["protein"] = Double(protein) ?? 0 }
        if !carbs.isEmpty { document["carbs"] = Double(carbs) ?? 0 }
        if !fat.isEmpty { document["fat"] = Double(fat) ?? 0 }
        if !fiber.isEmpty { document["fiber"] = Double(fiber) ?? 0 }
        if !sugar.isEmpty { document["sugar"] = Double(sugar) ?? 0 }
        if !sodium.isEmpty { document["sodium"] = Double(sodium) ?? 0 }
        if !saturatedFat.isEmpty { document["saturated_fat"] = Double(saturatedFat) ?? 0 }
        if !cholesterol.isEmpty { document["cholesterol"] = Double(cholesterol) ?? 0 }
        if !potassium.isEmpty { document["potassium"] = Double(potassium) ?? 0 }
        if !calcium.isEmpty { document["calcium"] = Double(calcium) ?? 0 }
        if !iron.isEmpty { document["iron"] = Double(iron) ?? 0 }
        if !ingredients.isEmpty { document["ingredients_text"] = ingredients }
        
        print("📝 Submitting food with data: \(document)")
        alertMessage = "Food data prepared for submission!\n\nName: \(foodName)\nCalories: \(calories)\nProtein: \(protein)g"
        showingAlert = true
    }
    
    private func lookupFoodByBarcode(_ barcode: String) {
        print("🔍 Looking up barcode: \(barcode)")
        
        // Show loading state
        isLoading = true
        
        typesenseService.searchByBarcode(barcode: barcode) { food, error in
            DispatchQueue.main.async {
                // Hide loading state
                self.isLoading = false
                
                if let food = food {
                    print("✅ Found food: \(food.name)")
                    self.selectedFood = food
                    self.showingFoodEntry = true
                } else {
                    print("❌ No food found for barcode")
                    self.notFoundBarcode = barcode
                    self.showingBarcodeNotFoundAlert = true
                }
            }
        }
    }
    
    private func populateNutritionFields(_ nutrition: [String: String]) {
        if let calories = nutrition["calories"] { self.calories = calories }
        if let protein = nutrition["protein"] { self.protein = protein }
        if let carbs = nutrition["carbs"] { self.carbs = carbs }
        if let fat = nutrition["fat"] { self.fat = fat }
        if let fiber = nutrition["fiber"] { self.fiber = fiber }
        if let sugar = nutrition["sugar"] { self.sugar = sugar }
        if let sodium = nutrition["sodium"] { self.sodium = sodium }
        if let saturatedFat = nutrition["saturated_fat"] { self.saturatedFat = saturatedFat }
        if let cholesterol = nutrition["cholesterol"] { self.cholesterol = cholesterol }
        
        alertMessage = "Nutrition facts scanned successfully!"
        showingAlert = true
    }
    
    // MARK: - AI Autofill
    
    private func performAIAutofill() {
        guard !foodName.isEmpty else {
            aiErrorMessage = "Please enter a food name first"
            showingAIError = true
            return
        }
        
        // Check if user is authenticated (required for AI features)
        guard aiService.hasAPIKey else {
            aiErrorMessage = "Please sign in to use AI autofill."
            showingAIError = true
            return
        }
        
        isAILoading = true
        
        aiService.fetchNutritionData(
            foodName: foodName,
            brandName: brandName.isEmpty ? nil : brandName,
            barcode: barcode.isEmpty ? nil : barcode
        ) { result in
            DispatchQueue.main.async {
                self.isAILoading = false
                
                switch result {
                case .success(let response):
                    self.populateFromAIResponse(response)
                    self.aiConfidence = response.confidence ?? "unknown"
                    self.showingAISuccessAlert = true
                    
                case .failure(let error):
                    print("AI autofill error: \(error.localizedDescription)")
                    self.aiErrorMessage = "Unable to analyze the food description. Please try again or enter the details manually."
                    self.showingAIError = true
                }
            }
        }
    }
    
    private func populateFromAIResponse(_ response: AIFoodNutritionResponse) {
        // Serving information
        if let size = response.servingSize {
            self.servingSize = String(format: "%.1f", size)
        }
        if let unit = response.servingUnit {
            self.servingUnit = unit
        }
        if let servings = response.servingsPerContainer {
            self.servingsPerContainer = String(format: "%.1f", servings)
        }
        
        // Macronutrients
        if let cal = response.calories {
            self.calories = String(format: "%.0f", cal)
        }
        if let prot = response.protein {
            self.protein = String(format: "%.1f", prot)
        }
        if let carb = response.carbs {
            self.carbs = String(format: "%.1f", carb)
        }
        if let f = response.fat {
            self.fat = String(format: "%.1f", f)
        }
        if let fib = response.fiber {
            self.fiber = String(format: "%.1f", fib)
        }
        if let sug = response.sugar {
            self.sugar = String(format: "%.1f", sug)
        }
        
        // Micronutrients
        if let sod = response.sodium {
            self.sodium = String(format: "%.0f", sod)
        }
        if let satFat = response.saturatedFat {
            self.saturatedFat = String(format: "%.1f", satFat)
        }
        if let trans = response.transFat {
            self.transFat = String(format: "%.1f", trans)
        }
        if let chol = response.cholesterol {
            self.cholesterol = String(format: "%.0f", chol)
        }
        if let pot = response.potassium {
            self.potassium = String(format: "%.0f", pot)
        }
        if let calc = response.calcium {
            self.calcium = String(format: "%.0f", calc)
        }
        if let ir = response.iron {
            self.iron = String(format: "%.1f", ir)
        }
        if let vitC = response.vitaminC {
            self.vitaminC = String(format: "%.1f", vitC)
        }
        if let vitA = response.vitaminA {
            self.vitaminA = String(format: "%.0f", vitA)
        }
        
        // Ingredients
        if let ing = response.ingredients, !ing.isEmpty {
            self.ingredients = ing
        }
    }
    
    // Add to recent foods directly (for barcode scanner items)
    private func recognizeText(from image: UIImage) {
        guard let cgImage = image.cgImage else {
            alertMessage = "Failed to process image"
            showingAlert = true
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                DispatchQueue.main.async {
                    self.alertMessage = "Failed to recognize text"
                    self.showingAlert = true
                }
                return
            }
            
            // Extract all recognized text
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            DispatchQueue.main.async {
                if !recognizedStrings.isEmpty {
                    // Try to find the most likely food name (usually the largest/first text)
                    let potentialFoodName = recognizedStrings.first ?? ""
                    
                    // If food name is empty, populate it
                    if self.foodName.isEmpty && !potentialFoodName.isEmpty {
                        self.foodName = potentialFoodName
                    }
                    
                    // Try to find brand name (often appears near food name)
                    if recognizedStrings.count > 1 && self.brandName.isEmpty {
                        self.brandName = recognizedStrings[1]
                    }
                    
                    // Try to find barcode numbers
                    for text in recognizedStrings {
                        // Look for numeric strings that could be barcodes (8-13 digits)
                        let digits = text.filter { $0.isNumber }
                        if digits.count >= 8 && digits.count <= 13 && self.barcode.isEmpty {
                            self.barcode = digits
                            break
                        }
                    }
                    
                    self.alertMessage = "Text recognized! Found: \(recognizedStrings.joined(separator: ", "))"
                    self.showingAlert = true
                } else {
                    self.alertMessage = "No text found in image"
                    self.showingAlert = true
                }
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
        } catch {
            DispatchQueue.main.async {
                self.alertMessage = "Failed to process image: \(error.localizedDescription)"
                self.showingAlert = true
            }
        }
    }
    
    private func recognizeNutritionFacts(from image: UIImage) {
        guard let cgImage = image.cgImage else {
            alertMessage = "Failed to process image"
            showingAlert = true
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                DispatchQueue.main.async {
                    self.alertMessage = "Failed to recognize text"
                    self.showingAlert = true
                }
                return
            }
            
            // Extract all recognized text
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            DispatchQueue.main.async {
                var foundValues: [String] = []
                
                // Parse nutrition facts from recognized text
                for (index, text) in recognizedStrings.enumerated() {
                    let lowercased = text.lowercased()
                    
                    // Look for calories
                    if lowercased.contains("calories") || lowercased.contains("energy") {
                        if let nextText = recognizedStrings[safe: index + 1] {
                            if let value = self.extractNumber(from: nextText) {
                                if self.calories.isEmpty {
                                    self.calories = value
                                    foundValues.append("Calories: \(value)")
                                }
                            }
                        }
                    }
                    
                    // Look for protein
                    if lowercased.contains("protein") {
                        if let value = self.extractNumber(from: text) ?? recognizedStrings[safe: index + 1].flatMap({ self.extractNumber(from: $0) }) {
                            if self.protein.isEmpty {
                                self.protein = value
                                foundValues.append("Protein: \(value)g")
                            }
                        }
                    }
                    
                    // Look for carbs/carbohydrate
                    if lowercased.contains("carb") || lowercased.contains("glucid") {
                        if let value = self.extractNumber(from: text) ?? recognizedStrings[safe: index + 1].flatMap({ self.extractNumber(from: $0) }) {
                            if self.carbs.isEmpty {
                                self.carbs = value
                                foundValues.append("Carbs: \(value)g")
                            }
                        }
                    }
                    
                    // Look for fat
                    if (lowercased.contains("fat") || lowercased.contains("lipid")) && !lowercased.contains("saturated") {
                        if let value = self.extractNumber(from: text) ?? recognizedStrings[safe: index + 1].flatMap({ self.extractNumber(from: $0) }) {
                            if self.fat.isEmpty {
                                self.fat = value
                                foundValues.append("Fat: \(value)g")
                            }
                        }
                    }
                    
                    // Look for fiber
                    if lowercased.contains("fiber") || lowercased.contains("fibre") {
                        if let value = self.extractNumber(from: text) ?? recognizedStrings[safe: index + 1].flatMap({ self.extractNumber(from: $0) }) {
                            if self.fiber.isEmpty {
                                self.fiber = value
                                foundValues.append("Fiber: \(value)g")
                            }
                        }
                    }
                    
                    // Look for sugar
                    if lowercased.contains("sugar") {
                        if let value = self.extractNumber(from: text) ?? recognizedStrings[safe: index + 1].flatMap({ self.extractNumber(from: $0) }) {
                            if self.sugar.isEmpty {
                                self.sugar = value
                                foundValues.append("Sugar: \(value)g")
                            }
                        }
                    }
                    
                    // Look for sodium
                    if lowercased.contains("sodium") {
                        if let value = self.extractNumber(from: text) ?? recognizedStrings[safe: index + 1].flatMap({ self.extractNumber(from: $0) }) {
                            if self.sodium.isEmpty {
                                self.sodium = value
                                foundValues.append("Sodium: \(value)mg")
                            }
                        }
                    }
                    
                    // Look for saturated fat
                    if lowercased.contains("saturated") {
                        if let value = self.extractNumber(from: text) ?? recognizedStrings[safe: index + 1].flatMap({ self.extractNumber(from: $0) }) {
                            if self.saturatedFat.isEmpty {
                                self.saturatedFat = value
                                foundValues.append("Saturated Fat: \(value)g")
                            }
                        }
                    }
                    
                    // Look for cholesterol
                    if lowercased.contains("cholesterol") {
                        if let value = self.extractNumber(from: text) ?? recognizedStrings[safe: index + 1].flatMap({ self.extractNumber(from: $0) }) {
                            if self.cholesterol.isEmpty {
                                self.cholesterol = value
                                foundValues.append("Cholesterol: \(value)mg")
                            }
                        }
                    }
                    
                    // Look for calcium
                    if lowercased.contains("calcium") {
                        if let value = self.extractNumber(from: text) ?? recognizedStrings[safe: index + 1].flatMap({ self.extractNumber(from: $0) }) {
                            if self.calcium.isEmpty {
                                self.calcium = value
                                foundValues.append("Calcium: \(value)mg")
                            }
                        }
                    }
                    
                    // Look for iron
                    if lowercased.contains("iron") || lowercased.contains("fer") {
                        if let value = self.extractNumber(from: text) ?? recognizedStrings[safe: index + 1].flatMap({ self.extractNumber(from: $0) }) {
                            if self.iron.isEmpty {
                                self.iron = value
                                foundValues.append("Iron: \(value)mg")
                            }
                        }
                    }
                }
                
                if !foundValues.isEmpty {
                    self.alertMessage = "Nutrition facts scanned!\n\n" + foundValues.joined(separator: "\n")
                } else {
                    self.alertMessage = "No nutrition values found. Try taking a clearer photo of the nutrition label."
                }
                self.showingAlert = true
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
        } catch {
            DispatchQueue.main.async {
                self.alertMessage = "Failed to process image: \(error.localizedDescription)"
                self.showingAlert = true
            }
        }
    }
    
    private func recognizeIngredients(from image: UIImage) {
        guard let cgImage = image.cgImage else {
            alertMessage = "Failed to process image"
            showingAlert = true
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                DispatchQueue.main.async {
                    self.alertMessage = "Failed to recognize text"
                    self.showingAlert = true
                }
                return
            }
            
            // Extract all recognized text
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            DispatchQueue.main.async {
                if !recognizedStrings.isEmpty {
                    // Look for "Ingredients:" label and get text after it
                    var ingredientsList: [String] = []
                    var foundIngredientsLabel = false
                    
                    for text in recognizedStrings {
                        let lowercased = text.lowercased()
                        
                        // Check if this line contains "ingredients"
                        if lowercased.contains("ingredient") {
                            foundIngredientsLabel = true
                            // If ingredients are on the same line, extract them
                            if let range = lowercased.range(of: "ingredient") {
                                let afterLabel = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                                if !afterLabel.isEmpty && afterLabel != ":" {
                                    ingredientsList.append(afterLabel)
                                }
                            }
                            continue
                        }
                        
                        // If we found the label, collect subsequent lines until we hit another label
                        if foundIngredientsLabel {
                            // Stop if we hit common label keywords
                            if lowercased.contains("nutrition") || 
                               lowercased.contains("allergen") ||
                               lowercased.contains("warning") ||
                               lowercased.contains("storage") ||
                               lowercased.contains("best before") {
                                break
                            }
                            
                            // Add this line to ingredients
                            let cleaned = text.trimmingCharacters(in: .whitespaces)
                            if !cleaned.isEmpty && cleaned.count > 2 {
                                ingredientsList.append(cleaned)
                            }
                        }
                    }
                    
                    if !ingredientsList.isEmpty {
                        // Join all ingredient lines with commas if not already present
                        let joinedIngredients = ingredientsList.joined(separator: ", ")
                        
                        // Clean up multiple commas and spaces
                        let cleaned = joinedIngredients
                            .replacingOccurrences(of: ", ,", with: ",")
                            .replacingOccurrences(of: ",,", with: ",")
                            .replacingOccurrences(of: "  ", with: " ")
                        
                        if self.ingredients.isEmpty {
                            self.ingredients = cleaned
                        } else {
                            // Append to existing ingredients
                            self.ingredients += ", " + cleaned
                        }
                        
                        self.alertMessage = "Ingredients scanned successfully!\n\nFound: \(cleaned)"
                    } else {
                        self.alertMessage = "No ingredients found. Make sure the photo clearly shows the ingredients list."
                    }
                } else {
                    self.alertMessage = "No text found in image"
                }
                self.showingAlert = true
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
        } catch {
            DispatchQueue.main.async {
                self.alertMessage = "Failed to process image: \(error.localizedDescription)"
                self.showingAlert = true
            }
        }
    }
    
    private func extractNumber(from text: String) -> String? {
        // Extract numbers including decimals
        let pattern = "\\d+\\.?\\d*"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            return String(text[range])
        }
        return nil
    }
    
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
    
    @ViewBuilder
    private func basicInfoSection() -> some View {
        Section("Basic Information") {
            HStack {
                TextField("Food Name", text: $foodName)
                    .accessibilityLabel("Food name")
                    .accessibilityHint("Enter the name of the food item")
                
                Button(action: {
                    showingImagePicker = true
                }) {
                    Image(systemName: "camera")
                        .foregroundColor(.blue)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(BorderlessButtonStyle())
                .accessibilityLabel("Scan food name with camera")
                .accessibilityHint("Opens camera to scan food name from package")
            }
            
            TextField("Brand Name", text: $brandName)
                .accessibilityLabel("Brand name")
                .accessibilityHint("Enter the brand or manufacturer name")
            
            HStack {
                TextField("Barcode", text: $barcode)
                    .keyboardType(.numberPad)
                    .accessibilityLabel("Barcode")
                    .accessibilityHint("Enter product barcode or use camera button to scan")
                
                Button(action: {
                    isScanningBarcode = true
                }) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(minWidth: 44, minHeight: 44)
                    } else {
                        Image(systemName: "camera")
                            .foregroundColor(.blue)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isLoading)
                .accessibilityLabel("Scan barcode with camera")
                .accessibilityHint("Opens camera to scan product barcode")
            }
            
            // AI Autofill Button - Temporarily disabled for post-launch development
            // Button(action: {
            //     performAIAutofill()
            // }) {
            //     HStack {
            //         if isAILoading {
            //             ProgressView()
            //                 .scaleEffect(0.8)
            //             Text("Loading...")
            //                 .foregroundColor(.secondary)
            //         } else {
            //             Image(systemName: "sparkles")
            //                 .foregroundColor(.purple)
            //             Text("AI Autofill Nutrition")
            //                 .foregroundColor(.purple)
            //         }
            //         Spacer()
            //         if !isAILoading {
            //             Image(systemName: "chevron.right")
            //                 .font(.caption)
            //                 .foregroundColor(.secondary)
            //         }
            //     }
            // }
            // .disabled(foodName.isEmpty || isAILoading)
            // .accessibilityLabel("AI Autofill")
            // .accessibilityHint("Uses AI to automatically fill in nutrition information based on the food name and brand")
        }
        .listRowBackground(Color.appCardBackground)
        
        Section("Serving Information") {
            TextField("Serving Size", text: $servingSize)
                .keyboardType(.decimalPad)
                .textContentType(.none)
                .autocorrectionDisabled()
                .accessibilityLabel("Serving size")
                .accessibilityHint("Enter the serving size amount")
            
            Picker("Serving Unit", selection: $servingUnit) {
                Text("g").tag("g")
                Text("ml").tag("ml")
                Text("oz").tag("oz")
                Text("cup").tag("cup")
                Text("tbsp").tag("tbsp")
                Text("tsp").tag("tsp")
                Text("piece").tag("piece")
            }
            .pickerStyle(MenuPickerStyle())
            
            TextField("Servings per Container", text: $servingsPerContainer)
                .keyboardType(.decimalPad)
        }
        .listRowBackground(Color.appCardBackground)
    }
    
    @ViewBuilder
    private func nutritionSection() -> some View {
        Section(header:
            HStack {
                Text("Macronutrients")
                Spacer()
                Button(action: {
                    showingNutritionScanner = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                        Text("Scan Label")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        ) {
            TextField("Calories", text: $calories).keyboardType(.numberPad)
            TextField("Protein (g)", text: $protein).keyboardType(.decimalPad)
            TextField("Carbs (g)", text: $carbs).keyboardType(.decimalPad)
            TextField("Fat (g)", text: $fat).keyboardType(.decimalPad)
            TextField("Fiber (g)", text: $fiber).keyboardType(.decimalPad)
            TextField("Sugar (g)", text: $sugar).keyboardType(.decimalPad)
        }
        .listRowBackground(Color.appCardBackground)
        
        Section(header: 
            HStack {
                Text("Micronutrients")
                Spacer()
                Text("Optional")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        ) {
            TextField("Sodium (mg)", text: $sodium)
                .keyboardType(.decimalPad)
                .accessibilityLabel("Sodium in milligrams")
            
            TextField("Saturated Fat (g)", text: $saturatedFat)
                .keyboardType(.decimalPad)
                .accessibilityLabel("Saturated fat in grams")
            
            TextField("Cholesterol (mg)", text: $cholesterol)
                .keyboardType(.decimalPad)
                .accessibilityLabel("Cholesterol in milligrams")
            
            TextField("Calcium (mg)", text: $calcium)
                .keyboardType(.decimalPad)
                .accessibilityLabel("Calcium in milligrams")
            
            TextField("Iron (mg)", text: $iron)
                .keyboardType(.decimalPad)
                .accessibilityLabel("Iron in milligrams")
        }
        .listRowBackground(Color.appCardBackground)
    }
    
    @ViewBuilder
    private func ingredientsSection() -> some View {
        Section(header:
            HStack {
                Text("Ingredients")
                Spacer()
                Button(action: {
                    showingIngredientsScanner = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                        Text("Scan")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
                Spacer().frame(width: 8)
                Text("Required for NOVA Score")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
            }
        ) {
            TextField("Ingredients (comma separated)", text: $ingredients, axis: .vertical)
                .lineLimit(3...6)
                .accessibilityLabel("Ingredients list")
                .accessibilityHint("Enter ingredients separated by commas or use camera to scan")
        }
        .listRowBackground(Color.appCardBackground)
        
        Section("Review") {
            VStack(alignment: .leading, spacing: 4) {
                Text("**\(foodName.isEmpty ? "Food Name" : foodName)**")
                    .font(.headline)
                
                if !calories.isEmpty { 
                    Text("Calories: \(calories)")
                        .font(.subheadline)
                }
                
                if !servingSize.isEmpty { 
                    Text("Serving: \(servingSize)\(servingUnit)")
                        .font(.subheadline)
                }
                
                if !protein.isEmpty || !carbs.isEmpty || !fat.isEmpty {
                    HStack {
                        if !protein.isEmpty { Text("P: \(protein)g") }
                        if !carbs.isEmpty { Text("C: \(carbs)g") }
                        if !fat.isEmpty { Text("F: \(fat)g") }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .listRowBackground(Color.appCardBackground)
    }
}

#Preview {
    AddFoodView()
}

// MARK: - ImagePicker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    var sourceType: UIImagePickerController.SourceType = .camera
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
