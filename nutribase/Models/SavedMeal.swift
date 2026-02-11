import Foundation

struct SavedMeal: Identifiable, Codable {
    let id: UUID
    var name: String
    var foods: [MealFood]
    var numberOfServings: Double
    
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
    
    init(id: UUID = UUID(), name: String, foods: [MealFood], numberOfServings: Double = 1.0) {
        self.id = id
        self.name = name
        self.foods = foods
        self.numberOfServings = numberOfServings
    }
    
    // Backward-compatible decoding: old meals without numberOfServings default to 1.0
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        foods = try container.decode([MealFood].self, forKey: .foods)
        numberOfServings = try container.decodeIfPresent(Double.self, forKey: .numberOfServings) ?? 1.0
    }
    
    // Helper to create from FoodEntry array, dividing by numberOfServings
    // so the stored meal represents a single serving
    static func from(name: String, foodEntries: [FoodEntry], numberOfServings: Double = 1.0) -> SavedMeal {
        let servings = max(numberOfServings, 1.0)
        
        let mealFoods = foodEntries.map { entry in
            // Calculate total weight (servingSize * numberOfServings) for the full recipe
            let totalWeight = entry.servingSize * entry.numberOfServings
            // Divide by meal servings to get per-serving amounts
            let perServingWeight = totalWeight / servings
            let perServingCalories = Int(round(Double(entry.totalCalories) / servings))
            let perServingProtein = entry.totalProtein / servings
            let perServingCarbs = entry.totalCarbs / servings
            let perServingFat = entry.totalFat / servings
            let perServingFiber = (entry.totalFibre ?? 0) / servings
            
            return MealFood(
                id: entry.id,
                foodItemId: entry.foodItem.id,
                foodName: entry.foodItem.name,
                brandName: entry.foodItem.brandName,
                servingSize: perServingWeight,
                servingUnit: entry.servingUnit,
                numberOfServings: 1.0,
                calories: perServingCalories,
                protein: perServingProtein,
                carbs: perServingCarbs,
                fat: perServingFat,
                fiber: perServingFiber,
                novaScore: entry.foodItem.novaScore,
                novaScoreIsEstimated: entry.foodItem.novaScoreIsEstimated,
                nutriScoreGrade: entry.foodItem.nutriScoreGrade,
                nutriScoreIsEstimated: entry.foodItem.nutriScoreIsEstimated
            )
        }
        return SavedMeal(name: name, foods: mealFoods, numberOfServings: servings)
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
    let fiber: Double?
    let novaScore: Int
    let novaScoreIsEstimated: Bool
    let nutriScoreGrade: String?
    let nutriScoreIsEstimated: Bool
    
    init(id: UUID = UUID(), foodItemId: UUID? = nil, foodName: String, brandName: String?, servingSize: Double, servingUnit: String, numberOfServings: Double, calories: Int, protein: Double, carbs: Double, fat: Double, fiber: Double? = nil, novaScore: Int = 0, novaScoreIsEstimated: Bool = false, nutriScoreGrade: String? = nil, nutriScoreIsEstimated: Bool = false) {
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
        self.fiber = fiber
        self.novaScore = novaScore
        self.novaScoreIsEstimated = novaScoreIsEstimated
        self.nutriScoreGrade = nutriScoreGrade
        self.nutriScoreIsEstimated = nutriScoreIsEstimated
    }
}
