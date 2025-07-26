import Foundation

// Global utility for consistent nutrition calculations across the app
struct NutritionCalculator {
    // Calculate calories based on food item, serving size, and number of servings
    static func calculateCalories(
        foodCalories: Int,
        servingSize: Double,
        servingUnit: String,
        numberOfServings: Double,
        isOriginalServingSize: Bool
    ) -> Int {
        print("NutritionCalculator: calculating calories with foodCalories=\(foodCalories), servingSize=\(servingSize), servingUnit=\(servingUnit), numberOfServings=\(numberOfServings), isOriginalServingSize=\(isOriginalServingSize)")
        
        if isOriginalServingSize {
            // Use database values directly for original serving size without any conversion
            let result = Int(Double(foodCalories) * numberOfServings)
            print("NutritionCalculator: using original serving size, result=\(result)")
            return result
        } else {
            // Scale values for different serving sizes
            let servingSizeInGrams = convertToGrams(size: servingSize, unit: servingUnit)
            let result = Int(Double(foodCalories) * numberOfServings * (servingSizeInGrams / 100.0))
            print("NutritionCalculator: using scaled serving size, servingSizeInGrams=\(servingSizeInGrams), result=\(result)")
            return result
        }
    }
    
    // Calculate macros (protein, carbs, fat) based on food item, serving size, and number of servings
    static func calculateMacro(
        macroValue: Double,
        servingSize: Double,
        servingUnit: String,
        numberOfServings: Double,
        isOriginalServingSize: Bool
    ) -> Double {
        if isOriginalServingSize {
            // Use database values directly for original serving size without any conversion
            return macroValue * numberOfServings
        } else {
            // Scale values for different serving sizes
            let servingSizeInGrams = convertToGrams(size: servingSize, unit: servingUnit)
            return macroValue * numberOfServings * (servingSizeInGrams / 100.0)
        }
    }
    
    // Convert serving size to grams for calculations
    static func convertToGrams(size: Double, unit: String) -> Double {
        switch unit.lowercased() {
        case "onz", "oz":
            return size * 28.35 // 1 oz = 28.35g
        case "l":
            return size * 1000.0 // 1L = 1000ml
        case "ml", "g":
            return size
        default:
            return size
        }
    }
}
