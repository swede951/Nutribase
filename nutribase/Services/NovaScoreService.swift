import Foundation

class NovaScoreService {
    static let shared = NovaScoreService()
    
    private init() {}
    
    // Common fruits that should always be NOVA 1
    private let commonFruits = [
        "apple", "banana", "orange", "grape", "strawberry", "blueberry", "raspberry", "blackberry", 
        "pear", "peach", "plum", "apricot", "cherry", "kiwi", "mango", "pineapple", "watermelon", 
        "melon", "cantaloupe", "honeydew", "lemon", "lime", "grapefruit", "tangerine", "clementine", 
        "mandarin", "fig", "date", "papaya", "guava", "lychee", "passion fruit", "pomegranate", 
        "avocado", "coconut", "dragonfruit", "persimmon", "nectarine"
    ]
    
    // Common vegetables that should always be NOVA 1
    private let commonVegetables = [
        "carrot", "broccoli", "spinach", "kale", "lettuce", "cabbage", "cauliflower", "cucumber", 
        "tomato", "potato", "sweet potato", "yam", "onion", "garlic", "pepper", "bell pepper", 
        "eggplant", "zucchini", "squash", "pumpkin", "corn", "pea", "bean", "lentil", "chickpea", 
        "asparagus", "celery", "radish", "turnip", "beet", "artichoke", "brussels sprout", 
        "mushroom", "leek", "shallot", "scallion", "arugula", "chard", "collard", "okra", "parsnip"
    ]
    
    // Keywords associated with different NOVA groups
    private let novaGroupKeywords: [Int: [String]] = [
        // Group 1: Unprocessed or minimally processed foods
        1: ["fresh", "raw", "natural", "whole", "fruit", "vegetable", "legume", "nut", "seed", "grain", "meat", "fish", "egg", "milk", "water", "tea", "coffee", "spice", "herb"],
        
        // Group 2: Processed culinary ingredients
        2: ["oil", "butter", "lard", "sugar", "salt", "honey", "syrup", "vinegar", "starch", "flour"],
        
        // Group 3: Processed foods
        3: ["bread", "cheese", "canned", "fermented", "preserved", "smoked", "salted", "pickled", "cured", "yogurt", "tofu", "beer", "wine", "cider"],
        
        // Group 4: Ultra-processed foods
        4: ["soda", "candy", "chocolate", "cookie", "cake", "pastry", "cereal", "chip", "snack", "instant", "frozen", "ready-to-eat", "ready-to-heat", "nugget", "margarine", "spread", "sauce", "dressing", "energy drink", "sports drink", "sweetener", "flavoring", "coloring", "preservative", "additive", "hydrogenated", "hydrolyzed", "modified", "artificial", "fast food", "processed meat", "sausage", "burger", "pizza", "noodle", "packaged"]
    ]
    
    // Ingredients that indicate ultra-processing (NOVA 4)
    private let ultraProcessedIngredients = [
        "high fructose corn syrup", "corn syrup", "maltodextrin", "dextrose", "invert sugar",
        "glucose-fructose syrup", "hydrogenated", "hydrolyzed", "isolate", "concentrate",
        "texturizer", "emulsifier", "colorant", "artificial", "flavor enhancer", "anti-foaming",
        "bulking agent", "carbonating agent", "firming", "foaming", "gelling agent",
        "glazing agent", "humectant", "tracer gas", "packaging gas", "propellant",
        "sequestrant", "artificial sweetener", "aspartame", "acesulfame", "sucralose",
        "saccharin", "neotame", "cyclamate", "modified starch", "soy protein isolate"
    ]
    
    // Predict NOVA score for a food item
    func predictNovaScore(for foodItem: FoodItem) -> Int {
        // If the food already has a NOVA score, return it
        if foodItem.novaScore > 0 {
            return foodItem.novaScore
        }
        
        let name = foodItem.name.lowercased()
        
        // Direct matching for common fruits and vegetables (always NOVA 1)
        // Check for exact matches first (e.g., "apple" should match "apple" but not "pineapple")
        let words = name.split(separator: " ").map { String($0) }
        for word in words {
            if commonFruits.contains(word) || commonVegetables.contains(word) {
                return 1 // Unprocessed
            }
        }
        
        // Then check for contains (to catch things like "green apple" or "red pepper")
        for fruit in commonFruits {
            if name.contains(fruit) {
                return 1 // Unprocessed
            }
        }
        
        for vegetable in commonVegetables {
            if name.contains(vegetable) {
                return 1 // Unprocessed
            }
        }
        
        // Nutritional heuristics for identifying fresh fruits and vegetables
        // Low calorie, high carb, low fat, low protein is typical of fruits and vegetables
        if foodItem.calories < 100 && foodItem.carbs > 5 && foodItem.fat < 1 && foodItem.protein < 2 {
            return 1 // Likely a fruit or vegetable
        }
        
        var scores = [Int: Int]() // Group: Score
        
        // Check food name against keywords for each NOVA group
        for (group, keywords) in novaGroupKeywords {
            for keyword in keywords {
                if name.contains(keyword) {
                    scores[group, default: 0] += 1
                }
            }
        }
        
        // Check for ultra-processed ingredients in the name
        for ingredient in ultraProcessedIngredients {
            if name.contains(ingredient) {
                scores[4, default: 0] += 2 // Ultra-processed ingredients are strong indicators
            }
        }
        
        // Additional heuristics based on nutritional content
        
        // High calorie density often indicates processing
        let caloriesPerGram = Double(foodItem.calories) / 100.0
        if caloriesPerGram > 4.0 {
            scores[4, default: 0] += 1
        } else if caloriesPerGram > 3.0 {
            scores[3, default: 0] += 1
        }
        
        // Very high protein can indicate protein isolates (ultra-processed)
        if foodItem.protein > 30 {
            scores[4, default: 0] += 1
        }
        
        // Very high fat can indicate processed foods
        if foodItem.fat > 30 {
            scores[3, default: 0] += 1
            scores[4, default: 0] += 1
        }
        
        // If no matches or equal scores, make an educated guess based on macros
        if scores.isEmpty {
            // Default to NOVA 2 (processed ingredients) as a safer middle ground when uncertain
            return 2
        }
        
        // Find the group with the highest score
        let highestScore = scores.max { a, b in a.value < b.value }
        return highestScore?.key ?? 2
    }
    
    // Get color for a NOVA score
    func colorForNovaScore(_ score: Int) -> String {
        switch score {
        case 1: return "green"
        case 2: return "blue"
        case 3: return "orange"
        case 4: return "red"
        default: return "gray"
        }
    }
    
    // Get description for a NOVA score
    func descriptionForNovaScore(_ score: Int) -> String {
        switch score {
        case 1: return "Unprocessed or minimally processed"
        case 2: return "Processed culinary ingredients"
        case 3: return "Processed foods"
        case 4: return "Ultra-processed foods"
        default: return "Unknown processing level"
        }
    }
}
