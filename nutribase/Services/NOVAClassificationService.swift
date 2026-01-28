import Foundation

/// Service for classifying foods into NOVA groups based on Open Food Facts methodology
/// Reference: https://world.openfoodfacts.org/nova
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
    
    /// Product categories that indicate Group 4 (Ultra-processed)
    private let group4Categories = [
        "soda", "soft drink", "energy drink", "sports drink",
        "ice cream", "frozen dessert",
        "chocolate", "candy", "confection", "sweet",
        "snack", "chip", "crisp",
        "ready meal", "frozen meal", "instant",
        "sausage", "hot dog", "processed meat",
        "baby formula", "infant formula"
    ]
    
    /// Keywords that indicate ultra-processed foods (NOVA 4) - Based on Open Food Facts
    private let ultraProcessedKeywords = [
        // Specific additive classes (Group 4 only)
        "colour stabilizer", "colour stabiliser", "color stabilizer", "color stabiliser",
        "flavour enhancer", "flavor enhancer",
        "carbonating agent", "firming agent", "bulking agent", "anti-bulking agent",
        "de-foaming agent", "defoaming agent", "anti-caking agent", "anticaking agent",
        "glazing agent", "emulsifier", "sequestrant", "humectant",
        
        // Cosmetic additives
        "artificial color", "artificial colour", "artificial flavor", "artificial flavour",
        "color", "colour", "sweetener", "non-sugar sweetener",
        
        // Processed ingredients extracted from foods
        "casein", "lactose", "whey", "whey protein", "whey powder",
        "gluten", "isolated protein", "protein isolate",
        
        // Further processed food constituents
        "hydrogenated oil", "hydrogenated fat", "interesterified",
        "hydrolysed protein", "hydrolyzed protein", "hydrolysed", "hydrolyzed",
        "soy protein isolate", "soya protein isolate",
        "maltodextrin", "invert sugar", "high fructose corn syrup", "high-fructose corn syrup",
        "corn syrup", "glucose-fructose syrup", "glucose syrup",
        
        // Specific additives
        "aspartame", "sucralose", "saccharin", "acesulfame", "neotame",
        "polysorbate", "carrageenan", "mono and diglycerides", "monoglycerides", "diglycerides",
        "sodium nitrite", "sodium nitrate", "bht", "bha", "tbhq",
        "sodium benzoate", "potassium sorbate", "modified starch"
    ]
    
    /// Ingredients that indicate processed foods (NOVA 3) when combined with Group 1
    private let group3Indicators = [
        "preservative", "canned", "bottled", "fermented", "smoked",
        "cured", "pickled", "in syrup", "salted", "sweetened"
    ]
    
    /// Keywords that indicate processed culinary ingredients (NOVA 2) - standalone products
    private let group2Keywords = [
        // These should be the PRIMARY ingredient, not just present
        "vegetable oil", "olive oil", "sunflower oil", "canola oil", "coconut oil",
        "butter", "lard", "ghee",
        "table salt", "sea salt", "kosher salt",
        "white sugar", "brown sugar", "cane sugar", "granulated sugar",
        "honey", "maple syrup", "agave syrup",
        "vinegar", "balsamic vinegar", "wine vinegar"
    ]
    
    /// Keywords that indicate unprocessed or minimally processed foods (NOVA 1)
    private let unprocessedKeywords = [
        "fresh", "raw", "natural", "whole", "pure", "organic", "dried", "frozen",
        "fruit", "vegetable", "meat", "fish", "egg", "milk", "grain", "seed", "nut",
        "legume", "bean", "herb", "spice"
    ]
    
    /// Predict NOVA group based on ingredients list using hierarchical classification
    /// Following Open Food Facts methodology: https://world.openfoodfacts.org/nova
    /// - Parameters:
    ///   - ingredients: Comma-separated list of ingredients
    ///   - productName: Optional product name for category detection
    /// - Returns: Predicted NOVA group
    func predictNOVAGroup(ingredients: String, productName: String? = nil) -> NOVAGroup {
        let lowercasedIngredients = ingredients.lowercased()
        let lowercasedName = productName?.lowercased() ?? ""
        
        // STEP 1: Check for Group 4 (Ultra-processed) indicators
        // These are definitive - if found, it's Group 4
        
        // Check product category
        for category in group4Categories {
            if lowercasedName.contains(category) {
                return .ultraProcessed
            }
        }
        
        // Check for Group 4 specific ingredients/additives
        for keyword in ultraProcessedKeywords {
            if lowercasedIngredients.contains(keyword) {
                return .ultraProcessed
            }
        }
        
        // Check for E-numbers (European food additives)
        if containsENumbers(lowercasedIngredients) {
            return .ultraProcessed
        }
        
        // STEP 2: Check for Group 2 (Processed culinary ingredients)
        // These are typically single-ingredient products like oil, salt, sugar
        let ingredientList = ingredients.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        
        // If very few ingredients and matches Group 2 keywords, it's likely Group 2
        if ingredientList.count <= 2 {
            for keyword in group2Keywords {
                if lowercasedIngredients.contains(keyword) || lowercasedName.contains(keyword) {
                    return .ingredient
                }
            }
        }
        
        // STEP 3: Check for Group 3 (Processed foods)
        // These have Group 1 foods + Group 2 ingredients + processing methods
        var hasGroup3Indicator = false
        for indicator in group3Indicators {
            if lowercasedIngredients.contains(indicator) || lowercasedName.contains(indicator) {
                hasGroup3Indicator = true
                break
            }
        }
        
        // If has processing indicators and some basic ingredients, it's Group 3
        if hasGroup3Indicator {
            return .processed
        }
        
        // Check if it has salt/sugar/oil added (common in Group 3)
        let hasAddedSalt = lowercasedIngredients.contains("salt") && !lowercasedIngredients.starts(with: "salt")
        let hasAddedSugar = lowercasedIngredients.contains("sugar") && !lowercasedIngredients.starts(with: "sugar")
        let hasAddedOil = lowercasedIngredients.contains("oil") && !lowercasedIngredients.starts(with: "oil")
        
        if (hasAddedSalt || hasAddedSugar || hasAddedOil) && ingredientList.count >= 2 {
            return .processed
        }
        
        // STEP 4: Default to Group 1 (Unprocessed/Minimally processed)
        // If none of the above criteria are met, it's likely unprocessed
        return .unprocessed
    }
    
    /// Check if ingredients contain E-numbers (European food additive codes)
    private func containsENumbers(_ text: String) -> Bool {
        let eNumberPattern = "\\be\\d{3}[a-z]?\\b"
        let regex = try? NSRegularExpression(pattern: eNumberPattern, options: .caseInsensitive)
        let matches = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return (matches?.count ?? 0) > 0
    }
    
    /// Predict NOVA group with optional parameters
    /// NOTE: NOVA classification should be based on ingredients, not nutritional values
    /// - Parameters:
    ///   - ingredients: Ingredients list (required for accurate classification)
    ///   - productName: Product name for category detection
    /// - Returns: Predicted NOVA group, or .unprocessed if no ingredients provided
    func predictNOVAGroup(ingredients: String? = nil, productName: String? = nil) -> NOVAGroup {
        // If we have ingredients, use hierarchical classification
        if let ingredients = ingredients, !ingredients.isEmpty {
            return predictNOVAGroup(ingredients: ingredients, productName: productName)
        }
        
        // Without ingredients, we can only check product name for category
        if let productName = productName {
            let lowercasedName = productName.lowercased()
            for category in group4Categories {
                if lowercasedName.contains(category) {
                    return .ultraProcessed
                }
            }
        }
        
        // Default to unprocessed if we don't have enough information
        // Note: This is a limitation - NOVA requires ingredients for accurate classification
        return .unprocessed
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
