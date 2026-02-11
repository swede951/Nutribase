import SwiftUI
import UIKit
import Combine

struct QuickAddFoodView: View {
    let mealType: String
    @Binding var isPresented: Bool
    @Environment(\.presentationMode) var presentationMode
    private let foodLogManager = FoodLogManager.shared
    
    // State for input fields
    @State private var foodName: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    
    // State for validation
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Computed property to check if form is valid
    private var isFormValid: Bool {
        !calories.isEmpty && Double(calories) != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Food Details")) {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("0", text: $calories)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                Section(header: Text("Macronutrients (g)")) {
                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("0", text: $protein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Carbohydrates")
                        Spacer()
                        TextField("0", text: $carbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Fat")
                        Spacer()
                        TextField("0", text: $fat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                Section {
                    Button {
                        print("Button tapped")
                        HapticManager.shared.lightFeedback()
                        if isFormValid {
                            addFoodItem()
                        } else {
                            errorMessage = "Please enter calories"
                            showingError = true
                        }
                    } label: {
                        Text("Add to \(mealType)")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding()
                            .background(isFormValid ? Color.blue : Color.gray.opacity(0.6))
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle to avoid form button styling issues
                    .disabled(!isFormValid)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationBarTitle("Quick Add", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    HapticManager.shared.lightFeedback()
                    isPresented = false
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("")
                    }
                }
                .withHapticFeedback()
            )
            .alert(isPresented: $showingError) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    private func addFoodItem() {
        print("addFoodItem called - Form valid: \(isFormValid)")
        guard isFormValid else {
            print("Form validation failed")
            errorMessage = "Please enter calories"
            showingError = true
            return
        }
        print("Creating food item: Quick Add, calories: \(calories)")
        
        // Create a custom food item with cached serving information
        let customFood = FoodItem(
            name: "Quick Add",
            barcode: nil,
            calories: Int(Double(calories) ?? 0),
            protein: Double(protein) ?? 0,
            carbs: Double(carbs) ?? 0,
            fat: Double(fat) ?? 0,
            novaScore: 0, // No NOVA score for quick add
            nutriScoreGrade: nil, // No NutriScore for quick add
            servingSize: "1 serving",
            cachedServingSize: 100.0,
            cachedServingUnit: "g",
            cachedNumberOfServings: 1.0
        )
        
        // Add to food log
        print("Adding to food log: \(customFood.name) to \(mealType)")
        foodLogManager.addEntry(
            foodItem: customFood,
            mealType: mealType,
            servingSize: 100.0,
            servingUnit: "g",
            numberOfServings: 1.0
        )
        print("Successfully added to food log")
        
        // Add to recent foods
        print("Adding to recent foods")
        addToRecentFoods(food: customFood)
        
        // Provide success feedback
        print("Providing haptic feedback")
        HapticManager.shared.successFeedback()
        
        // Dismiss the view
        print("Dismissing view")
        isPresented = false
    }
    
    // Add food to recent foods in UserDefaults
    private func addToRecentFoods(food: FoodItem) {
        let recentFoodsKey = "recentlyAddedFoods"
        let maxRecentFoods = 10
        
        // Get current recent foods
        var recentFoods: [FoodItem] = []
        if let data = UserDefaults.standard.data(forKey: recentFoodsKey),
           let decoded = try? JSONDecoder().decode([FoodItem].self, from: data) {
            recentFoods = decoded
        }
        
        // Remove the food if it already exists (to avoid duplicates)
        recentFoods.removeAll { $0.name == food.name }
        
        // Add the new food at the beginning
        recentFoods.insert(food, at: 0)
        
        // Limit to maximum number of recent foods
        if recentFoods.count > maxRecentFoods {
            recentFoods = Array(recentFoods.prefix(maxRecentFoods))
        }
        
        // Save back to UserDefaults
        if let encoded = try? JSONEncoder().encode(recentFoods) {
            UserDefaults.standard.set(encoded, forKey: recentFoodsKey)
        }
    }
    
    // Helper to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct QuickAddFoodView_Previews: PreviewProvider {
    static var previews: some View {
        QuickAddFoodView(mealType: "Breakfast", isPresented: .constant(true))
    }
}
