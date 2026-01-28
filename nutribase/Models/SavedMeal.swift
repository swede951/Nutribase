import Foundation

struct SavedMeal: Identifiable, Codable {
    let id: UUID
    var name: String
    var foods: [MealFood]
    
    var totalCalories: Int {
        foods.reduce(0) { $0 + $1.calories }
    }
    
    var totalProtein: Double {
        foods.reduce(0.0) { $0 + $1.protein }
    }
    
    var totalCarbs: Double {
        foods.reduce(0.0) { $0 + $1.carbs }
    }
    
    var totalFat: Double {
        foods.reduce(0.0) { $0 + $1.fat }
    }
    
    init(id: UUID = UUID(), name: String, foods: [MealFood]) {
        self.id = id
        self.name = name
        self.foods = foods
    }
    
    // Helper to create from FoodEntry array
    static func from(name: String, foodEntries: [FoodEntry]) -> SavedMeal {
        let mealFoods = foodEntries.map { entry in
            // Calculate total weight (servingSize * numberOfServings) for display
            // Nutrition values are already calculated for the total amount
            let totalWeight = entry.servingSize * entry.numberOfServings
            
            return MealFood(
                id: entry.id,
                foodItemId: entry.foodItem.id,
                foodName: entry.foodItem.name,
                brandName: entry.foodItem.brandName,
                servingSize: totalWeight,  // Store total weight, not base serving
                servingUnit: entry.servingUnit,
                numberOfServings: 1.0,  // Set to 1 since we're storing total weight
                calories: entry.totalCalories,
                protein: entry.totalProtein,
                carbs: entry.totalCarbs,
                fat: entry.totalFat,
                novaScore: entry.foodItem.novaScore,
                novaScoreIsEstimated: entry.foodItem.novaScoreIsEstimated,
                nutriScoreGrade: entry.foodItem.nutriScoreGrade,
                nutriScoreIsEstimated: entry.foodItem.nutriScoreIsEstimated
            )
        }
        return SavedMeal(name: name, foods: mealFoods)
    }
}

struct MealFood: Identifiable, Codable {
    let id: UUID
    let foodItemId: UUID?
    let foodName: String
    let brandName: String?
    let servingSize: Double
    let servingUnit: String
    let numberOfServings: Double
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let novaScore: Int
    let novaScoreIsEstimated: Bool
    let nutriScoreGrade: String?
    let nutriScoreIsEstimated: Bool
    
    init(id: UUID = UUID(), foodItemId: UUID? = nil, foodName: String, brandName: String?, servingSize: Double, servingUnit: String, numberOfServings: Double, calories: Int, protein: Double, carbs: Double, fat: Double, novaScore: Int = 0, novaScoreIsEstimated: Bool = false, nutriScoreGrade: String? = nil, nutriScoreIsEstimated: Bool = false) {
        self.id = id
        self.foodItemId = foodItemId
        self.foodName = foodName
        self.brandName = brandName
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.numberOfServings = numberOfServings
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.novaScore = novaScore
        self.novaScoreIsEstimated = novaScoreIsEstimated
        self.nutriScoreGrade = nutriScoreGrade
        self.nutriScoreIsEstimated = nutriScoreIsEstimated
    }
}
