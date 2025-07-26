import Foundation

/// Service for classifying foods into NOVA groups based on ingredients and nutritional data
class NOVAClassificationService {
    
    static let shared = NOVAClassificationService()
    
    private init() {}
    
    // NOVA classification groups
    enum NOVAGroup: Int, Codable {
        case unprocessed = 1    // Unprocessed or minimally processed foods
        case ingredient = 2     // Processed culinary ingredients
        case processed = 3      // Processed foods
        case ultraProcessed = 4 // Ultra-processed foods
        
        var description: String {
            switch self {
            case .unprocessed:
                return "Unprocessed/Minimally Processed"
            case .ingredient:
                return "Processed Culinary Ingredient"
            case .processed:
                return "Processed Food"
            case .ultraProcessed:
                return "Ultra-processed Food"
            }
        }
    }
    
    /// Keywords that indicate ultra-processed foods (NOVA 4)
    private let ultraProcessedKeywords = [
        // Additives
        "flavor", "flavour", "artificial", "color", "colour", "sweetener", "emulsifier", 
        "stabilizer", "stabiliser", "thickener", "texturizer", "texturiser",
        "anti-caking", "anticaking", "bulking agent", "carbonating agent", "carrier",
        "emulsifying salt", "firming agent", "flavour enhancer", "flavor enhancer",
        "foaming agent", "gelling agent", "glazing agent", "humectant", "modified",
        "preservative", "propellant", "raising agent", "sequestrant",
        
        // E-numbers (common additives)
        "e1", "e2", "e3", "e4", "e5", "e6", "e9",
        
        // Common ultra-processed ingredients
        "high fructose corn syrup", "corn syrup", "invert sugar", "maltodextrin",
        "dextrose", "glucose-fructose", "hydrogenated", "hydrolyzed", "isolate",
        "protein isolate", "soy isolate", "whey isolate", "textured protein",
        
        // Specific additives
        "aspartame", "sucralose", "saccharin", "acesulfame", "neotame",
        "polysorbate", "carrageenan", "guar gum", "xanthan gum", "lecithin",
        "mono and diglycerides", "sodium nitrite", "sodium nitrate", "bht", "bha",
        "tbhq", "sodium benzoate", "potassium sorbate"
    ]
    
    /// Keywords that indicate processed foods (NOVA 3)
    private let processedKeywords = [
        "salt", "sugar", "oil", "fat", "butter", "canned", "fermented", "smoked",
        "cured", "pickled", "preserved", "cheese", "bread", "alcohol", "wine", "beer"
    ]
    
    /// Keywords that indicate processed culinary ingredients (NOVA 2)
    private let ingredientKeywords = [
        "oil", "fat", "butter", "lard", "sugar", "salt", "honey", "maple syrup"
    ]
    
    /// Keywords that indicate unprocessed or minimally processed foods (NOVA 1)
    private let unprocessedKeywords = [
        "fresh", "raw", "natural", "whole", "pure", "organic", "dried", "frozen",
        "fruit", "vegetable", "meat", "fish", "egg", "milk", "grain", "seed", "nut",
        "legume", "bean", "herb", "spice"
    ]
    
    /// Predict NOVA group based on ingredients list
    /// - Parameter ingredients: Comma-separated list of ingredients
    /// - Returns: Predicted NOVA group
    func predictNOVAGroup(ingredients: String) -> NOVAGroup {
        let lowercasedIngredients = ingredients.lowercased()
        
        // Check for ultra-processed indicators
        for keyword in ultraProcessedKeywords {
            if lowercasedIngredients.contains(keyword) {
                return .ultraProcessed
            }
        }
        
        // Count indicators for each category
        var processedCount = 0
        var ingredientCount = 0
        var unprocessedCount = 0
        
        for keyword in processedKeywords {
            if lowercasedIngredients.contains(keyword) {
                processedCount += 1
            }
        }
        
        for keyword in ingredientKeywords {
            if lowercasedIngredients.contains(keyword) {
                ingredientCount += 1
            }
        }
        
        for keyword in unprocessedKeywords {
            if lowercasedIngredients.contains(keyword) {
                unprocessedCount += 1
            }
        }
        
        // Determine NOVA group based on counts
        if processedCount > 0 && ingredientCount > 0 {
            return .processed
        } else if ingredientCount > 0 && unprocessedCount == 0 {
            return .ingredient
        } else if unprocessedCount > 0 {
            return .unprocessed
        } else {
            // Default to processed if we can't determine
            return .processed
        }
    }
    
    /// Predict NOVA group based on nutritional data
    /// - Parameters:
    ///   - ingredients: Ingredients list (if available)
    ///   - sodium: Sodium content in mg per 100g
    ///   - sugar: Sugar content in g per 100g
    ///   - saturatedFat: Saturated fat in g per 100g
    ///   - additiveCount: Number of additives (if known)
    /// - Returns: Predicted NOVA group
    func predictNOVAGroup(ingredients: String? = nil, 
                          sodium: Double? = nil,
                          sugar: Double? = nil, 
                          saturatedFat: Double? = nil,
                          additiveCount: Int? = nil) -> NOVAGroup {
        
        var score = 0
        
        // If we have ingredients, use that as primary classifier
        if let ingredients = ingredients, !ingredients.isEmpty {
            return predictNOVAGroup(ingredients: ingredients)
        }
        
        // Otherwise use nutritional data to estimate
        
        // High sodium is common in processed and ultra-processed foods
        if let sodium = sodium {
            if sodium > 500 { // High sodium
                score += 2
            } else if sodium > 300 { // Moderate sodium
                score += 1
            }
        }
        
        // High sugar is common in ultra-processed foods
        if let sugar = sugar {
            if sugar > 20 { // High sugar
                score += 2
            } else if sugar > 10 { // Moderate sugar
                score += 1
            }
        }
        
        // High saturated fat can indicate processing
        if let saturatedFat = saturatedFat {
            if saturatedFat > 5 { // High saturated fat
                score += 1
            }
        }
        
        // Additives are a key indicator of ultra-processing
        if let additiveCount = additiveCount {
            if additiveCount > 5 {
                score += 3
            } else if additiveCount > 0 {
                score += 2
            }
        }
        
        // Determine NOVA group based on score
        if score >= 4 {
            return .ultraProcessed
        } else if score >= 2 {
            return .processed
        } else if score >= 1 {
            return .ingredient
        } else {
            return .unprocessed
        }
    }
    
    /// Extract potential additives from ingredients list
    /// - Parameter ingredients: Ingredients list
    /// - Returns: Count of potential additives
    func countAdditives(in ingredients: String) -> Int {
        let lowercasedIngredients = ingredients.lowercased()
        
        // Count E-numbers (European food additives)
        let eNumberPattern = "e\\d{3}[a-z]?"
        let eNumberRegex = try? NSRegularExpression(pattern: eNumberPattern)
        let eNumberMatches = eNumberRegex?.matches(in: lowercasedIngredients, range: NSRange(lowercasedIngredients.startIndex..., in: lowercasedIngredients))
        let eNumberCount = eNumberMatches?.count ?? 0
        
        // Count common additives
        var additiveCount = 0
        for keyword in ultraProcessedKeywords {
            if lowercasedIngredients.contains(keyword) {
                additiveCount += 1
            }
        }
        
        return eNumberCount + additiveCount
    }
}
