import SwiftUI

// ViewModel to hold meal creation state on the heap.
// Using @StateObject ensures this survives parent view re-renders
// and nested sheet lifecycle events that would reset @State properties.
class CreateMealViewModel: ObservableObject {
    @Published var mealName = ""
    @Published var numberOfServings: Double = 1.0
    @Published var selectedFoods: [FoodEntry] = []
    @Published var showingFoodSearch = false
    
    // Stable NumberFormatter instance (avoids TextField reset from recreated formatters)
    let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.allowsFloats = true
        return formatter
    }()
    
    var totalCalories: Int {
        let total = selectedFoods.reduce(0) { $0 + $1.totalCalories }
        guard numberOfServings > 0 else { return total }
        return Int(Double(total) / numberOfServings)
    }
    
    var totalProtein: Double {
        let total = selectedFoods.reduce(into: 0.0) { $0 += $1.totalProtein }
        guard numberOfServings > 0 else { return total }
        return total / numberOfServings
    }
    
    var totalCarbs: Double {
        let total = selectedFoods.reduce(into: 0.0) { $0 += $1.totalCarbs }
        guard numberOfServings > 0 else { return total }
        return total / numberOfServings
    }
    
    var totalFat: Double {
        let total = selectedFoods.reduce(into: 0.0) { $0 += $1.totalFat }
        guard numberOfServings > 0 else { return total }
        return total / numberOfServings
    }
}

struct CreateMealBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateMealViewModel()
    
    let mealType: String
    let selectedDate: Date
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Meal name input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Meal Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            TextField("Enter meal name", text: $viewModel.mealName)
                                .font(.system(size: 17))
                                .padding()
                                .background(Color.appCardBackground)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Number of servings input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Number of Servings")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            HStack {
                                TextField("1.00", value: $viewModel.numberOfServings, formatter: viewModel.decimalFormatter)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 17))
                                    .padding()
                                    .background(Color.appCardBackground)
                                    .cornerRadius(10)
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
                        }
                        .padding(.horizontal)
                        
                        // Nutrition card (only show if there are foods)
                        if !viewModel.selectedFoods.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Nutrition per Serving")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                // All macros in one row
                                HStack(spacing: 12) {
                                    MacroCircleSmall(
                                        value: Double(viewModel.totalCalories),
                                        label: "Calories",
                                        color: LinearGradient(
                                            gradient: Gradient(colors: [CardType.calorieTarget.color, CardType.calorieTarget.color]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        unit: ""
                                    )
                                    MacroCircleSmall(
                                        value: viewModel.totalProtein,
                                        label: "Protein",
                                        color: LinearGradient(
                                            gradient: Gradient(colors: [CardType.protein.color, CardType.protein.color]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        unit: "g"
                                    )
                                    MacroCircleSmall(
                                        value: viewModel.totalCarbs,
                                        label: "Carbs",
                                        color: LinearGradient(
                                            gradient: Gradient(colors: [CardType.carbs.color, CardType.carbs.color]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        unit: "g"
                                    )
                                    MacroCircleSmall(
                                        value: viewModel.totalFat,
                                        label: "Fats",
                                        color: LinearGradient(
                                            gradient: Gradient(colors: [CardType.fat.color, CardType.fat.color]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        unit: "g"
                                    )
                                }
                                .padding()
                                .background(Color.appCardBackground)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Foods section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Foods: \(viewModel.selectedFoods.count)")
                                    .font(.system(size: 17, weight: .semibold))
                                
                                Spacer()
                                
                                Text("\(viewModel.totalCalories) kcal")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            if viewModel.selectedFoods.isEmpty {
                                // Empty state
                                Button(action: {
                                    viewModel.showingFoodSearch = true
                                }) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "fork.knife.circle")
                                            .font(.system(size: 50))
                                            .foregroundColor(.gray.opacity(0.5))
                                        
                                        Text("Add Foods")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.blue)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                }
                            } else {
                                // List of foods
                                VStack(spacing: 8) {
                                    ForEach(viewModel.selectedFoods) { foodEntry in
                                        MealFoodCard(foodEntry: foodEntry, onDelete: {
                                            if let index = viewModel.selectedFoods.firstIndex(where: { $0.id == foodEntry.id }) {
                                                viewModel.selectedFoods.remove(at: index)
                                            }
                                        })
                                    }
                                }
                                
                                // Add more foods button
                                Button(action: {
                                    viewModel.showingFoodSearch = true
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
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Create Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveMeal() }
                        .foregroundColor(.primary)
                        .disabled(viewModel.mealName.isEmpty || viewModel.selectedFoods.isEmpty)
                }
            }
            .sheet(isPresented: $viewModel.showingFoodSearch) {
                MealFoodPickerView(selectedFoods: $viewModel.selectedFoods, mealType: mealType, selectedDate: selectedDate)
            }
        }
    }
    
    private func saveMeal() {
        let meal = SavedMeal.from(name: viewModel.mealName, foodEntries: viewModel.selectedFoods, numberOfServings: viewModel.numberOfServings)
        SavedMealsManager.shared.saveMeal(meal)
        dismiss()
    }
}

// Food card component matching food log layout
struct MealFoodCard: View {
    let foodEntry: FoodEntry
    let onDelete: () -> Void
    
    private var novaScoreColor: Color {
        let novaScore = foodEntry.foodItem.novaScore
        switch novaScore {
        case 1: return Color(hex: "#3f993f")
        case 2: return Color(hex: "#b7ce0d")
        case 3: return Color(hex: "#f28e16")
        case 4: return Color(hex: "#e4032f")
        default: return .gray
        }
    }
    
    private var nutriScoreColor: Color {
        guard let grade = foodEntry.foodItem.nutriScoreGrade?.lowercased() else { return .gray }
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
        HStack(alignment: .top, spacing: 12) {
            // Food info
            VStack(alignment: .leading, spacing: 4) {
                // Food name
                Text(foodEntry.foodItem.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                // Quantity and badges (no brand)
                HStack(spacing: 6) {
                    // Serving quantity - show total (servingSize × numberOfServings)
                    let totalServingSize = foodEntry.servingSize * foodEntry.numberOfServings
                    Text("\(String(format: "%.0f", totalServingSize))\(foodEntry.servingUnit)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    // NOVA Score badge
                    if foodEntry.foodItem.novaScore > 0 {
                        Text("\(foodEntry.foodItem.novaScoreIsEstimated ? "✨ " : "")NOVA \(foodEntry.foodItem.novaScore)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(novaScoreColor)
                            .cornerRadius(4)
                    }
                    
                    // Nutri-Score badge
                    if let nutriScore = foodEntry.foodItem.nutriScoreGrade, !nutriScore.isEmpty {
                        Text("\(foodEntry.foodItem.nutriScoreIsEstimated ? "✨ " : "")\(nutriScore.uppercased())")
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
            
            // Calories and delete button
            HStack(spacing: 12) {
                Text("\(foodEntry.totalCalories) kcal")
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
}

struct MealFoodPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFoods: [FoodEntry]
    let mealType: String
    let selectedDate: Date
    
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        // Don't wrap in NavigationView - FoodSearchView already has one
        FoodSearchView(
            mealType: mealType,
            selectedDate: selectedDate,
            isCreatingMeal: true,
            onFoodSelectedForMeal: { foodEntry in
                // Check if this food already exists in the meal
                if let existingIndex = selectedFoods.firstIndex(where: { 
                    $0.foodItem.id == foodEntry.foodItem.id && 
                    $0.servingUnit == foodEntry.servingUnit 
                }) {
                    // Combine with existing entry by adding weights
                    let existing = selectedFoods[existingIndex]
                    let combinedServingSize = existing.servingSize + foodEntry.servingSize
                    
                    // Create new entry with combined serving size
                    let combinedEntry = FoodEntry(
                        id: existing.id,
                        foodItem: existing.foodItem,
                        mealType: existing.mealType,
                        servingSize: combinedServingSize,
                        servingUnit: existing.servingUnit,
                        numberOfServings: combinedServingSize,
                        dateAdded: existing.dateAdded
                    )
                    selectedFoods[existingIndex] = combinedEntry
                    
                    toastMessage = "\(foodEntry.foodItem.name) weight combined"
                } else {
                    // Add as new entry
                    selectedFoods.append(foodEntry)
                    toastMessage = "\(foodEntry.foodItem.name) added"
                }
                
                // Show toast confirmation
                showToast = true
                
                // Hide toast after 1.5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showToast = false
                }
            }
        )
        .overlay(
            // Toast notification
            VStack {
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
                    .background(Color(hex: "#35b8ff"))
                    .cornerRadius(25)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showToast)
                }
                Spacer()
            }
            .padding(.top, 60)
        )
    }
}

// Self-contained button that owns its own sheet state.
// Isolating the sheet here prevents the massive FoodSearchView body
// from being re-evaluated when the sheet opens/closes.
struct CreateMealButton: View {
    let mealType: String
    let selectedDate: Date
    @State private var showingCreateMeal = false
    
    var body: some View {
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
        .sheet(isPresented: $showingCreateMeal) {
            CreateMealBuilderView(mealType: mealType, selectedDate: selectedDate)
        }
    }
}

// Small macro circle component for meal builder
struct MacroCircleSmall: View {
    let value: Double
    let label: String
    let color: LinearGradient
    let unit: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 5)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(value))\(unit)")
                    .font(.system(size: 14, weight: .semibold))
            }
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}