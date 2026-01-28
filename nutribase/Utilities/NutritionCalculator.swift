import Foundation

// Global utility for consistent nutrition calculations across the app
struct NutritionCalculator {
    // Helper to ensure Double values are valid (not NaN, Infinity, or negative)
    private static func validateDouble(_ value: Double, defaultValue: Double = 0.0) -> Double {
        if value.isNaN || value.isInfinite || value < 0 {
            return defaultValue
        }
        return min(value, 99999.0) // Cap at reasonable max
    }
    
    // Helper to ensure Int values are valid (not negative or too large)
    private static func validateInt(_ value: Int, defaultValue: Int = 0) -> Int {
        if value < 0 {
            return defaultValue
        }
        return min(value, 999999) // Cap at reasonable max
    }
    // Calculate calories based on food item, serving size, and number of servings
    static func calculateCalories(
        foodCalories: Int,
        servingSize: Double,
        servingUnit: String,
        numberOfServings: Double,
        isOriginalServingSize: Bool,
        servingDescription: String? = nil,
        servingQuantity: Double? = nil
    ) -> Int {

        
        // Check if we should use original serving size or custom serving size
        if isOriginalServingSize, let originalServingSize = servingDescription, !originalServingSize.isEmpty {
            // Handle non-standard formats like "1bar" or "1 bar (36 g)"
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
                        let valueStr = nsString.substring(with: valueRange)
                        
                        if let servingWeight = Double(valueStr) {
                            // Calculate calories based on the serving weight (assuming foodCalories is per 100g)
                            let caloriesPerGram = Double(foodCalories) / 100.0
                            let rawResult = caloriesPerGram * servingWeight * numberOfServings
                            if rawResult.isNaN || rawResult.isInfinite { return 0 }
                            return validateInt(Int(round(rawResult)))
                        }
                    }
                }
                
                // If no weight found in parentheses, return the base calories (likely per 100g)
                let rawResult = Double(foodCalories) * numberOfServings
                if rawResult.isNaN || rawResult.isInfinite { return 0 }
                return validateInt(Int(round(rawResult)))
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
                    
                    if let servingSize = Double(valueStr) {
                        // For grams, calculate based on the serving size
                        if unitStr == "g" {
                            let caloriesPerGram = Double(foodCalories) / 100.0
                            let rawResult = caloriesPerGram * servingSize * numberOfServings
                            if rawResult.isNaN || rawResult.isInfinite { return 0 }
                            return validateInt(Int(round(rawResult)))
                        }
                        // For ml, assume similar density to water (1ml ≈ 1g for most liquids)
                        else if unitStr == "ml" {
                            let caloriesPerGram = Double(foodCalories) / 100.0
                            let rawResult = caloriesPerGram * servingSize * numberOfServings
                            if rawResult.isNaN || rawResult.isInfinite { return 0 }
                            return validateInt(Int(round(rawResult)))
                        }
                    }
                }
            }
        }
        
        // If servingDescription is nil, this is a custom serving size (not original)
        // Calculate based on the provided servingSize and servingUnit
        let servingSizeInGrams: Double
        switch servingUnit.lowercased() {
        case "onz", "oz":
            servingSizeInGrams = servingSize * 28.35 // 1 oz = 28.35g

        case "l":
            servingSizeInGrams = servingSize * 1000.0 // 1L = 1000ml

        case "ml":
            servingSizeInGrams = servingSize // 1ml ≈ 1g for most liquids

        case "g":
            servingSizeInGrams = servingSize

        default:
            servingSizeInGrams = servingSize

        }
        
        // Calculate calories based on the serving size in grams
        let caloriesPerGram = Double(foodCalories) / 100.0
        let rawResult = caloriesPerGram * servingSizeInGrams * numberOfServings
        
        // Validate and return
        if rawResult.isNaN || rawResult.isInfinite {
            return 0
        }
        return validateInt(Int(round(rawResult)))
    }
    
    // Calculate macros (protein, carbs, fat) based on food item, serving size, and number of servings
    static func calculateMacro(
        macroValue: Double,
        servingSize: Double,
        servingUnit: String,
        numberOfServings: Double,
        isOriginalServingSize: Bool,
        servingDescription: String? = nil,
        servingQuantity: Double? = nil
    ) -> Double {

        
        // Check if we should use original serving size or custom serving size
        if isOriginalServingSize, let originalServingSize = servingDescription, !originalServingSize.isEmpty {
            // Handle non-standard formats like "1bar" or "1 bar (36 g)"
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
                        let valueStr = nsString.substring(with: valueRange)
                        
                        if let servingWeight = Double(valueStr) {
                            // Calculate macro based on the serving weight (assuming macroValue is per 100g)
                            let macroPerGram = macroValue / 100.0
                            let result = macroPerGram * servingWeight * numberOfServings
                            return validateDouble(result)
                        }
                    }
                }
                
                // If no weight found in parentheses, return the base macro (likely per 100g)
                let result = macroValue * numberOfServings
                return validateDouble(result)
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
                    
                    if let servingSize = Double(valueStr) {
                        // For grams, calculate based on the serving size
                        if unitStr == "g" {
                            let macroPerGram = macroValue / 100.0
                            let result = macroPerGram * servingSize * numberOfServings
                            return validateDouble(result)
                        }
                        // For ml, assume similar density to water (1ml ≈ 1g for most liquids)
                        else if unitStr == "ml" {
                            let macroPerGram = macroValue / 100.0
                            let result = macroPerGram * servingSize * numberOfServings
                            return validateDouble(result)
                        }
                    }
                }
            }
        }
        
        // If servingDescription is nil, this is a custom serving size (not original)
        // Calculate based on the provided servingSize and servingUnit
        let servingSizeInGrams: Double
        switch servingUnit.lowercased() {
        case "onz", "oz":
            servingSizeInGrams = servingSize * 28.35 // 1 oz = 28.35g

        case "l":
            servingSizeInGrams = servingSize * 1000.0 // 1L = 1000ml

        case "ml":
            servingSizeInGrams = servingSize // 1ml ≈ 1g for most liquids

        case "g":
            servingSizeInGrams = servingSize

        default:
            servingSizeInGrams = servingSize

        }
        
        // Calculate macro based on the serving size in grams
        let macroPerGram = macroValue / 100.0
        let result = macroPerGram * servingSizeInGrams * numberOfServings
        
        // Validate and return
        return validateDouble(result)
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
    
    // MARK: - Enhanced Serving Size Handling
    
    // Extract weight from serving size description like "1 bar (35 g)", "40g", or "250ml"
    static func extractWeightFromServingSize(_ servingSize: String) -> (Double, String)? {
        // First try to match parentheses format: "X unit (Y g)" or "X unit (Y ml)"
        let parenthesesPattern = "\\((\\d+(\\.\\d+)?)\\s*(g|ml)\\)"
        
        if let regex = try? NSRegularExpression(pattern: parenthesesPattern, options: []) {
            let range = NSRange(servingSize.startIndex..., in: servingSize)
            if let match = regex.firstMatch(in: servingSize, options: [], range: range) {
                if let weightRange = Range(match.range(at: 1), in: servingSize),
                   let unitRange = Range(match.range(at: 3), in: servingSize) {
                    let weightStr = String(servingSize[weightRange])
                    let unit = String(servingSize[unitRange])
                    if let weight = Double(weightStr) {
                        return (weight, unit)
                    }
                }
            }
        }
        
        // If no parentheses format found, try simple format: "40g" or "250ml"
        let simplePattern = "(\\d+(\\.\\d+)?)\\s*(g|ml)\\b"
        
        if let regex = try? NSRegularExpression(pattern: simplePattern, options: []) {
            let range = NSRange(servingSize.startIndex..., in: servingSize)
            if let match = regex.firstMatch(in: servingSize, options: [], range: range) {
                if let weightRange = Range(match.range(at: 1), in: servingSize),
                   let unitRange = Range(match.range(at: 3), in: servingSize) {
                    let weightStr = String(servingSize[weightRange])
                    let unit = String(servingSize[unitRange])
                    if let weight = Double(weightStr) {
                        return (weight, unit)
                    }
                }
            }
        }
        
        return nil
    }
    
    // Estimate weight in grams for common non-weight units
    static func estimateGramsFromUnit(_ servingDescription: String) -> Double? {
        // Common units and their estimated weights based on OpenFoodFacts data analysis
        let standardUnitWeights: [String: Double] = [
            "bar": 40.0,        // Average granola/protein bar
            "slice": 30.0,      // Average bread slice
            "piece": 25.0,      // Generic piece
            "cookie": 15.0,     // Average cookie
            "unit": 100.0,      // Generic unit
            "each": 100.0,      // Generic each
            "serving": 100.0,   // Generic serving
            "cup": 240.0,       // Standard cup measurement
            "tablespoon": 15.0, // Standard tablespoon
            "teaspoon": 5.0     // Standard teaspoon
        ]
        
        let lowercased = servingDescription.lowercased()
        
        // Try to find a matching unit
        for (unit, weight) in standardUnitWeights {
            if lowercased.contains(unit) {

                return weight
            }
        }
        

        return nil
    }
    
    // Enhanced converter with fallback mechanisms for complex serving descriptions
    static func enhancedConvertToGrams(
        size: Double, 
        unit: String, 
        servingDescription: String? = nil,
        servingQuantity: Double? = nil
    ) -> Double {

        
        // First try direct unit conversion if it's a standard weight/volume unit
        switch unit.lowercased() {
        case "onz", "oz":
            let result = size * 28.35 // 1 oz = 28.35g

            return result
        case "l":
            let result = size * 1000.0 // 1L = 1000ml

            return result
        case "ml", "g":

            return size
        default:
            // For non-standard units, try alternate approaches
            if let servingDescription = servingDescription {
                // Try to extract weight from serving size description (e.g., "1 bar (35 g)")
                if let (weight, _) = extractWeightFromServingSize(servingDescription) {

                    return weight
                }
                
                // Try to estimate weight based on unit type
                if let estimatedWeight = estimateGramsFromUnit(servingDescription) {
                    return estimatedWeight
                }
            }
            
            // If serving quantity is provided and all else fails, use that as grams
            if let quantity = servingQuantity, quantity > 0 {

                return quantity
            }
            
            // Last resort - assume 100g as default reference

            return 100.0
        }
    }
}
