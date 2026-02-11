import SwiftUI

struct EditMealView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var mealsManager = SavedMealsManager.shared
    
    let meal: SavedMeal
    @State private var editedMeal: SavedMeal
    @State private var numberOfServings: Double = 1.0
    @State private var showingFoodSearch = false
    @State private var selectedFoodsForAdding: [FoodEntry] = []
    
    init(meal: SavedMeal) {
        self.meal = meal
        _editedMeal = State(initialValue: meal)
        _numberOfServings = State(initialValue: meal.numberOfServings)
    }
    
    // NumberFormatter for servings input
    private var decimalFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.allowsFloats = true
        return formatter
    }
    
    var totalCalories: Int {
        let total = editedMeal.foods.reduce(0) { $0 + $1.calories }
        return Int(Double(total) / numberOfServings)
    }
    
    var totalProtein: Double {
        let total = editedMeal.foods.reduce(0.0) { $0 + $1.protein }
        return total / numberOfServings
    }
    
    var totalCarbs: Double {
        let total = editedMeal.foods.reduce(0.0) { $0 + $1.carbs }
        return total / numberOfServings
    }
    
    var totalFat: Double {
        let total = editedMeal.foods.reduce(0.0) { $0 + $1.fat }
        return total / numberOfServings
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    servingSection
                    nutritionSection
                    mealItemsSection
                }
                .padding(.vertical)
            }
            .background(Color.appBackground)
            .navigationTitle("Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMeal()
                    }
                    .foregroundColor(.primary)
                    .disabled(editedMeal.foods.isEmpty)
                }
            }
            .sheet(isPresented: $showingFoodSearch) {
                MealFoodPickerView(
                    selectedFoods: $selectedFoodsForAdding,
                    mealType: "Breakfast",
                    selectedDate: Date()
                )
            }
            .onChange(of: selectedFoodsForAdding) { oldValue, newValue in
                // When new foods are selected, convert them to MealFood and add to meal
                let newFoods = newValue.filter { newEntry in
                    !oldValue.contains(where: { $0.id == newEntry.id })
                }
                
                for foodEntry in newFoods {
                    let totalWeight = foodEntry.servingSize * foodEntry.numberOfServings
                    
                    // Check if this food already exists in the meal
                    // Match by foodItemId if available, otherwise fall back to name matching
                    if let existingIndex = editedMeal.foods.firstIndex(where: { existing in
                        let sameUnit = existing.servingUnit == foodEntry.servingUnit
                        
                        // If foodItemId exists, use it for matching
                        if let existingFoodId = existing.foodItemId {
                            return existingFoodId == foodEntry.foodItem.id && sameUnit
                        }
                        
                        // Fall back to name matching for backward compatibility
                        return existing.foodName.lowercased() == foodEntry.foodItem.name.lowercased() && sameUnit
                    }) {
                        // Combine with existing entry by adding weights
                        let existing = editedMeal.foods[existingIndex]
                        let combinedWeight = existing.servingSize + totalWeight
                        let combinedCalories = existing.calories + foodEntry.totalCalories
                        let combinedProtein = existing.protein + foodEntry.totalProtein
                        let combinedCarbs = existing.carbs + foodEntry.totalCarbs
                        let combinedFat = existing.fat + foodEntry.totalFat
                        
                        let updatedMealFood = MealFood(
                            id: existing.id,
                            foodItemId: existing.foodItemId,
                            foodName: existing.foodName,
                            brandName: existing.brandName,
                            servingSize: combinedWeight,
                            servingUnit: existing.servingUnit,
                            numberOfServings: 1.0,
                            calories: combinedCalories,
                            protein: combinedProtein,
                            carbs: combinedCarbs,
                            fat: combinedFat,
                            novaScore: existing.novaScore,
                            novaScoreIsEstimated: existing.novaScoreIsEstimated,
                            nutriScoreGrade: existing.nutriScoreGrade,
                            nutriScoreIsEstimated: existing.nutriScoreIsEstimated
                        )
                        editedMeal.foods[existingIndex] = updatedMealFood
                    } else {
                        // Add as new entry
                        let newMealFood = MealFood(
                            id: UUID(),
                            foodItemId: foodEntry.foodItem.id,
                            foodName: foodEntry.foodItem.name,
                            brandName: foodEntry.foodItem.brandName,
                            servingSize: totalWeight,
                            servingUnit: foodEntry.servingUnit,
                            numberOfServings: 1.0,
                            calories: foodEntry.totalCalories,
                            protein: foodEntry.totalProtein,
                            carbs: foodEntry.totalCarbs,
                            fat: foodEntry.totalFat,
                            novaScore: foodEntry.foodItem.novaScore,
                            novaScoreIsEstimated: foodEntry.foodItem.novaScoreIsEstimated,
                            nutriScoreGrade: foodEntry.foodItem.nutriScoreGrade,
                            nutriScoreIsEstimated: foodEntry.foodItem.nutriScoreIsEstimated
                        )
                        editedMeal.foods.append(newMealFood)
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var servingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
                        Text("Serving")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.horizontal)
                        
                        HStack {
                            Text("Number of servings:")
                                .font(.system(size: 17))
                            Spacer()
                            TextField("1.00", value: $numberOfServings, formatter: decimalFormatter)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.appInsetBackground)
                                .cornerRadius(8)
                                .toolbar {
                                    ToolbarItemGroup(placement: .keyboard) {
                                        Spacer()
                                        Button {
                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        } label: {
                                            Image(systemName: "keyboard.chevron.compact.down")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                        }
                        .padding()
                        .background(Color.appCardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
        }
    }
    
    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
                        Text("Nutrition")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.horizontal)
                        
                        // Calories circle
                        HStack {
                            Text("Calories")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                                    .frame(width: 65, height: 65)
                                
                                Circle()
                                    .trim(from: 0, to: 1.0)
                                    .stroke(
                                        Color(red: 0.6, green: 0.2, blue: 0.8),
                                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                    )
                                    .frame(width: 65, height: 65)
                                    .rotationEffect(.degrees(-90))
                                
                                Text("\(totalCalories)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appCardBackground)
                        )
                        .padding(.horizontal)
                        
                        // Macros
                        HStack(spacing: 16) {
                            MacroCircle(value: totalProtein, label: "Protein", color: .green)
                            MacroCircle(value: totalCarbs, label: "Carbs", color: .orange)
                            MacroCircle(value: totalFat, label: "Fats", color: .pink)
                        }
                        .padding()
                        .background(Color.appCardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
        }
    }
    
    private var mealItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Meal Items")
                                .font(.system(size: 17, weight: .semibold))
                            
                            Spacer()
                            
                            Text("\(editedMeal.foods.count) item\(editedMeal.foods.count == 1 ? "" : "s")")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            ForEach(Array(editedMeal.foods.enumerated()), id: \.element.id) { index, mealFood in
                                EditableMealFoodCard(
                                    mealFood: mealFood,
                                    onUpdate: { updatedFood in
                                        editedMeal.foods[index] = updatedFood
                                    },
                                    onDelete: {
                                        editedMeal.foods.remove(at: index)
                                    }
                                )
                            }
                        }
                        
                        // Add more foods button
                        Button(action: {
                            showingFoodSearch = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add More Foods")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appInsetBackground)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
        }
    }
    
    // MARK: - Actions
    
    private func saveMeal() {
        let oldServings = editedMeal.numberOfServings
        let newServings = max(numberOfServings, 1.0)
        
        // If servings changed, rescale food amounts so stored data = 1 serving
        if oldServings != newServings {
            let scale = oldServings / newServings
            editedMeal.foods = editedMeal.foods.map { food in
                MealFood(
                    id: food.id,
                    foodItemId: food.foodItemId,
                    foodName: food.foodName,
                    brandName: food.brandName,
                    servingSize: food.servingSize * scale,
                    servingUnit: food.servingUnit,
                    numberOfServings: food.numberOfServings,
                    calories: Int(round(Double(food.calories) * scale)),
                    protein: food.protein * scale,
                    carbs: food.carbs * scale,
                    fat: food.fat * scale,
                    fiber: (food.fiber ?? 0) * scale,
                    novaScore: food.novaScore,
                    novaScoreIsEstimated: food.novaScoreIsEstimated,
                    nutriScoreGrade: food.nutriScoreGrade,
                    nutriScoreIsEstimated: food.nutriScoreIsEstimated
                )
            }
        }
        
        editedMeal.numberOfServings = newServings
        // Update the meal in the manager
        if let index = mealsManager.meals.firstIndex(where: { $0.id == meal.id }) {
            mealsManager.meals[index] = editedMeal
            mealsManager.persistMeals()
        }
        dismiss()
    }
}

// Editable meal food card
struct EditableMealFoodCard: View {
    let mealFood: MealFood
    let onUpdate: (MealFood) -> Void
    let onDelete: () -> Void
    
    @State private var showingEditSheet = false
    
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
        Button(action: {
            showingEditSheet = true
        }) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mealFood.foodName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    // Serving size and badges
                    HStack(spacing: 6) {
                        Text("\(String(format: "%.0f", mealFood.servingSize))\(mealFood.servingUnit)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        // NOVA Score badge
                        if mealFood.novaScore > 0 {
                            Text("\(mealFood.novaScoreIsEstimated ? "✨ " : "")NOVA \(mealFood.novaScore)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(novaScoreColor)
                                .cornerRadius(4)
                        }
                        
                        // Nutri-Score badge
                        if let nutriScore = mealFood.nutriScoreGrade, !nutriScore.isEmpty {
                            Text("\(mealFood.nutriScoreIsEstimated ? "✨ " : "")\(nutriScore.uppercased())")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(nutriScoreColor)
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Text("\(mealFood.calories) kcal")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding()
            .background(Color.appCardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            .padding(.horizontal)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditMealFoodView(mealFood: mealFood, onSave: onUpdate)
        }
    }
}

// Edit individual food in meal
struct EditMealFoodView: View {
    @Environment(\.dismiss) private var dismiss
    
    let mealFood: MealFood
    let onSave: (MealFood) -> Void
    
    @State private var servingSize: Double
    @State private var numberOfServings: Double
    @State private var selectedServingSizeOption: String
    
    // Generate serving size options based on the unit
    private var servingSizeOptions: [String] {
        let unit = mealFood.servingUnit
        
        // Common serving sizes
        if unit.lowercased().contains("g") {
            return ["100g", "50g", "200g", "250g", "500g"]
        } else if unit.lowercased().contains("ml") {
            return ["100ml", "200ml", "250ml", "330ml", "500ml"]
        } else if unit.lowercased() == "serving" {
            return ["1 serving", "0.5 serving", "2 servings"]
        } else {
            // For other units, create options based on current value
            let baseValue = mealFood.servingSize
            return [
                "\(Int(baseValue * 0.5)) \(unit)",
                "\(Int(baseValue)) \(unit)",
                "\(Int(baseValue * 1.5)) \(unit)",
                "\(Int(baseValue * 2)) \(unit)"
            ]
        }
    }
    
    init(mealFood: MealFood, onSave: @escaping (MealFood) -> Void) {
        self.mealFood = mealFood
        self.onSave = onSave
        _servingSize = State(initialValue: mealFood.servingSize)
        _numberOfServings = State(initialValue: mealFood.numberOfServings)
        _selectedServingSizeOption = State(initialValue: "\(Int(mealFood.servingSize)) \(mealFood.servingUnit)")
    }
    
    var calculatedCalories: Int {
        let baseCalories = Double(mealFood.calories) / mealFood.numberOfServings / (mealFood.servingSize / 100.0)
        return Int(baseCalories * (servingSize / 100.0) * numberOfServings)
    }
    
    var calculatedProtein: Double {
        let baseProtein = mealFood.protein / mealFood.numberOfServings / (mealFood.servingSize / 100.0)
        return baseProtein * (servingSize / 100.0) * numberOfServings
    }
    
    var calculatedCarbs: Double {
        let baseCarbs = mealFood.carbs / mealFood.numberOfServings / (mealFood.servingSize / 100.0)
        return baseCarbs * (servingSize / 100.0) * numberOfServings
    }
    
    var calculatedFat: Double {
        let baseFat = mealFood.fat / mealFood.numberOfServings / (mealFood.servingSize / 100.0)
        return baseFat * (servingSize / 100.0) * numberOfServings
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Serving size
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Serving Size")
                            .font(.system(size: 17, weight: .semibold))
                        
                        Menu {
                            ForEach(servingSizeOptions, id: \.self) { option in
                                Button(action: {
                                    selectedServingSizeOption = option
                                    updateServingSize(from: option)
                                }) {
                                    HStack {
                                        Text(option)
                                        if option == selectedServingSizeOption {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedServingSizeOption)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.appInsetBackground)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.appCardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Number of servings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of Servings")
                            .font(.system(size: 17, weight: .semibold))
                        
                        TextField("Servings", value: $numberOfServings, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding()
                    .background(Color.appCardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Nutrition preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nutrition")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("Calories")
                                Spacer()
                                Text("\(calculatedCalories) kcal")
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text("Protein")
                                Spacer()
                                Text("\(String(format: "%.1f", calculatedProtein))g")
                            }
                            
                            HStack {
                                Text("Carbs")
                                Spacer()
                                Text("\(String(format: "%.1f", calculatedCarbs))g")
                            }
                            
                            HStack {
                                Text("Fat")
                                Spacer()
                                Text("\(String(format: "%.1f", calculatedFat))g")
                            }
                        }
                        .padding()
                        .background(Color.appCardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.appBackground)
            .navigationTitle(mealFood.foodName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
    
    private func updateServingSize(from option: String) {
        // Parse the serving size from the option string
        // Format examples: "100g", "1 serving", "200ml"
        let components = option.components(separatedBy: " ")
        if let firstComponent = components.first,
           let value = Double(firstComponent.filter { $0.isNumber || $0 == "." }) {
            servingSize = value
        }
    }
    
    private func saveChanges() {
        let updatedFood = MealFood(
            id: mealFood.id,
            foodItemId: mealFood.foodItemId,
            foodName: mealFood.foodName,
            brandName: mealFood.brandName,
            servingSize: servingSize,
            servingUnit: mealFood.servingUnit,
            numberOfServings: numberOfServings,
            calories: calculatedCalories,
            protein: calculatedProtein,
            carbs: calculatedCarbs,
            fat: calculatedFat,
            novaScore: mealFood.novaScore,
            novaScoreIsEstimated: mealFood.novaScoreIsEstimated,
            nutriScoreGrade: mealFood.nutriScoreGrade,
            nutriScoreIsEstimated: mealFood.nutriScoreIsEstimated
        )
        onSave(updatedFood)
        dismiss()
    }
}

// Macro circle component
struct MacroCircle: View {
    let value: Double
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 65, height: 65)
                
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 65, height: 65)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(value))g")
                    .font(.custom("Montserrat-SemiBold", size: 14))
            }
            
            Text(label)
                .font(.custom("Montserrat-SemiBold", size: 14))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
}
