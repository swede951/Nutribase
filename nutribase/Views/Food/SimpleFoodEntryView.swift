import SwiftUI

struct SimpleFoodEntryView: View {
    let food: FoodItem
    let mealType: String
    @State private var servingSize: Double = 100.0
    @State private var numberOfServings: Double = 1.0
    @Environment(\.presentationMode) var presentationMode
    
    // Computed properties for nutritional values
    private var totalCalories: Int {
        return Int(Double(food.calories) * numberOfServings * (servingSize / 100.0))
    }
    
    private var totalProtein: Double {
        return food.protein * numberOfServings * (servingSize / 100.0)
    }
    
    private var totalCarbs: Double {
        return food.carbs * numberOfServings * (servingSize / 100.0)
    }
    
    private var totalFat: Double {
        return food.fat * numberOfServings * (servingSize / 100.0)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Food")) {
                Text(food.name)
                    .font(.headline)
            }
            
            Section(header: Text("Amount")) {
                HStack {
                    Text("Serving Size: \(Int(servingSize))g")
                    Spacer()
                }
                Slider(value: $servingSize, in: 10...500, step: 5)
                
                HStack {
                    Text("Number of Servings: \(String(format: "%.1f", numberOfServings))")
                    Spacer()
                }
                Slider(value: $numberOfServings, in: 0.1...10, step: 0.1)
            }
            
            Section(header: Text("Nutrition")) {
                HStack {
                    Text("Calories")
                    Spacer()
                    Text("\(totalCalories)")
                        .fontWeight(.bold)
                }
                
                HStack {
                    Text("Protein")
                    Spacer()
                    Text(String(format: "%.1fg", totalProtein))
                        .fontWeight(.bold)
                }
                
                HStack {
                    Text("Carbs")
                    Spacer()
                    Text(String(format: "%.1fg", totalCarbs))
                        .fontWeight(.bold)
                }
                
                HStack {
                    Text("Fat")
                    Spacer()
                    Text(String(format: "%.1fg", totalFat))
                        .fontWeight(.bold)
                }
            }
            
            Section {
                Button("Add to \(mealType)") {
                    addFoodToMeal()
                    presentationMode.wrappedValue.dismiss()
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
        .navigationTitle("Add Food")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func addFoodToMeal() {
        // In a real app, this would update the data model
        print("Added \(food.name) to \(mealType) with \(numberOfServings) servings of \(servingSize)g")
    }
}
