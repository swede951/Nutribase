import Foundation

class NovaScoreService {
    static let shared = NovaScoreService()
    
    private init() {}
    
    // MARK: - Prediction Cache (O(1) lookup for repeated predictions)
    private var predictionCache: [String: Int] = [:] // keyed by food name lowercase
    private let maxCacheSize = 500
    
    // MARK: - Sets for O(1) lookup (converted from arrays)
    
    // Common fruits that should always be NOVA 1
    private let commonFruitsSet: Set<String> = [
        "apple", "banana", "orange", "grape", "strawberry", "blueberry", "raspberry", "blackberry",
        "pear", "peach", "plum", "apricot", "cherry", "kiwi", "mango", "pineapple", "watermelon",
        "melon", "cantaloupe", "honeydew", "lemon", "lime", "grapefruit", "tangerine", "clementine",
        "mandarin", "fig", "date", "papaya", "guava", "lychee", "passion fruit", "pomegranate",
        "avocado", "coconut", "dragonfruit", "persimmon", "nectarine"
    ]
    
    // Common vegetables that should always be NOVA 1
    private let commonVegetablesSet: Set<String> = [
        "carrot", "broccoli", "spinach", "kale", "lettuce", "cabbage", "cauliflower", "cucumber",
        "tomato", "potato", "sweet potato", "yam", "onion", "garlic", "pepper", "bell pepper",
        "eggplant", "zucchini", "squash", "pumpkin", "corn", "pea", "bean", "lentil", "chickpea",
        "asparagus", "celery", "radish", "turnip", "beet", "artichoke", "brussels sprout",
        "mushroom", "leek", "shallot", "scallion", "arugula", "chard", "collard", "okra", "parsnip"
    ]
    
    // Arrays for substring matching (still needed for "contains" checks)
    private let commonFruitsArray = [
        "apple", "banana", "orange", "grape", "strawberry", "blueberry", "raspberry", "blackberry",
        "pear", "peach", "plum", "apricot", "cherry", "kiwi", "mango", "pineapple", "watermelon",
        "melon", "cantaloupe", "honeydew", "lemon", "lime", "grapefruit", "tangerine", "clementine",
        "mandarin", "fig", "date", "papaya", "guava", "lychee", "passion fruit", "pomegranate",
        "avocado", "coconut", "dragonfruit", "persimmon", "nectarine"
    ]
    
    private let commonVegetablesArray = [
        "carrot", "broccoli", "spinach", "kale", "lettuce", "cabbage", "cauliflower", "cucumber",
        "tomato", "potato", "sweet potato", "yam", "onion", "garlic", "pepper", "bell pepper",
        "eggplant", "zucchini", "squash", "pumpkin", "corn", "pea", "bean", "lentil", "chickpea",
        "asparagus", "celery", "radish", "turnip", "beet", "artichoke", "brussels sprout",
        "mushroom", "leek", "shallot", "scallion", "arugula", "chard", "collard", "okra", "parsnip"
    ]
    
    // Keywords associated with different NOVA groups (Sets for O(1) lookup)
    private let novaGroupKeywordsSets: [Int: Set<String>] = [
        // Group 1: Unprocessed or minimally processed foods
        1: [
            // General terms
            "fresh", "raw", "natural", "whole", "frozen", "chilled",
            // Fruits and vegetables
            "fruit", "vegetable", "legume", "nut", "seed",
            // Grains and starches
            "grain", "rice", "basmati", "jasmine", "brown rice", "white rice", "wild rice",
            "pasta", "couscous", "polenta", "quinoa", "oats", "wheat", "barley", "corn", "maize",
            // Meats (animals)
            "meat", "beef", "chicken", "pork", "lamb", "turkey", "duck", "veal", "venison", "rabbit",
            // Meat cuts
            "mince", "minced", "ground", "steak", "chop", "fillet", "breast", "thigh", "leg", "wing",
            "drumstick", "cutlet", "loin", "tenderloin", "sirloin", "ribeye", "rump", "shoulder",
            // Seafood
            "fish", "salmon", "tuna", "cod", "haddock", "mackerel", "trout", "prawns", "shrimp",
            "crab", "lobster", "mussels", "oysters", "squid", "octopus", "sardines", "herring",
            // Other Group 1
            "egg", "eggs", "milk", "water", "tea", "coffee", "spice", "herb", "yoghurt", "plain yogurt"
        ],
        
        // Group 2: Processed culinary ingredients
        2: ["oil", "butter", "lard", "sugar", "salt", "honey", "syrup", "vinegar", "starch", "flour"],
        
        // Group 3: Processed foods
        3: ["bread", "cheese", "canned", "fermented", "preserved", "smoked", "salted", "pickled", "cured", "yogurt", "tofu", "beer", "wine", "cider"],
        
        // Group 4: Ultra-processed foods
        4: ["soda", "candy", "chocolate", "cookie", "cake", "pastry", "cereal", "chip", "snack", "instant", "ready-to-eat", "ready-to-heat", "nugget", "margarine", "spread", "sauce", "dressing", "energy drink", "sports drink", "sweetener", "flavoring", "coloring", "preservative", "additive", "hydrogenated", "hydrolyzed", "modified", "artificial", "fast food", "processed meat", "sausage", "burger", "pizza", "noodle", "packaged"]
    ]
    
    // Ingredients that indicate ultra-processing (NOVA 4) - Set for O(1) lookup
    private let ultraProcessedIngredientsSet: Set<String> = [
        "high fructose corn syrup", "corn syrup", "maltodextrin", "dextrose", "invert sugar",
        "glucose-fructose syrup", "hydrogenated", "hydrolyzed", "isolate", "concentrate",
        "texturizer", "emulsifier", "colorant", "artificial", "flavor enhancer", "anti-foaming",
        "bulking agent", "carbonating agent", "firming", "foaming", "gelling agent",
        "glazing agent", "humectant", "tracer gas", "packaging gas", "propellant",
        "sequestrant", "artificial sweetener", "aspartame", "acesulfame", "sucralose",
        "saccharin", "neotame", "cyclamate", "modified starch", "soy protein isolate"
    ]
    
    // Array version for substring matching
    private let ultraProcessedIngredientsArray = [
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
        
        // Check cache first for O(1) lookup of previously predicted items
        if let cachedScore = predictionCache[name] {
            return cachedScore
        }
        
        // Compute the prediction
        let predictedScore = computeNovaScore(name: name, foodItem: foodItem)
        
        // Cache the result (with size limit to prevent memory bloat)
        if predictionCache.count >= maxCacheSize {
            predictionCache.removeAll() // Simple eviction - clear when full
        }
        predictionCache[name] = predictedScore
        
        return predictedScore
    }
    
    // Internal computation of NOVA score (separated for caching)
    private func computeNovaScore(name: String, foodItem: FoodItem) -> Int {
        // Direct matching for common fruits and vegetables (always NOVA 1)
        // Check for exact matches first using Sets - O(1) lookup
        let words = name.split(separator: " ").map { String($0) }
        for word in words {
            if commonFruitsSet.contains(word) || commonVegetablesSet.contains(word) {
                return 1 // Unprocessed
            }
        }
        
        // Then check for contains (to catch things like "green apple" or "red pepper")
        // Still need array iteration for substring matching
        for fruit in commonFruitsArray {
            if name.contains(fruit) {
                return 1 // Unprocessed
            }
        }
        
        for vegetable in commonVegetablesArray {
            if name.contains(vegetable) {
                return 1 // Unprocessed
            }
        }
        
        // Nutritional heuristics for identifying minimally processed foods
        // Low calorie, high carb, low fat, low protein is typical of fruits and vegetables
        if foodItem.calories < 100 && foodItem.carbs > 5 && foodItem.fat < 1 && foodItem.protein < 2 {
            return 1 // Likely a fruit or vegetable
        }
        
        // Simple whole foods: high protein, low carb, moderate fat = likely plain meat/fish
        // Plain chicken breast: ~165 cal, 31g protein, 0g carbs, 3.6g fat per 100g
        // Plain beef mince (5%): ~168 cal, 21g protein, 0g carbs, 9g fat per 100g
        if foodItem.protein > 15 && foodItem.carbs < 5 && foodItem.fat < 25 {
            return 1 // Likely plain meat or fish
        }
        
        // High carb, low fat, low protein = likely grains/rice/pasta
        // White rice: ~130 cal, 2.7g protein, 28g carbs, 0.3g fat per 100g
        if foodItem.carbs > 20 && foodItem.protein < 10 && foodItem.fat < 3 {
            return 1 // Likely grain, rice, or pasta
        }
        
        var scores = [Int: Int]() // Group: Score
        
        // Check food name words against keyword Sets - O(1) per word lookup
        for word in words {
            for (group, keywordSet) in novaGroupKeywordsSets {
                if keywordSet.contains(word) {
                    scores[group, default: 0] += 1
                }
            }
        }
        
        // Check for ultra-processed ingredients in the name (substring matching still needed)
        for ingredient in ultraProcessedIngredientsArray {
            if name.contains(ingredient) {
                scores[4, default: 0] += 3 // Ultra-processed ingredients are very strong indicators
            }
        }
        
        // Boost Group 1 score if we found Group 1 keywords (prioritize whole foods)
        if let group1Score = scores[1], group1Score > 0 {
            scores[1] = group1Score + 2 // Give Group 1 extra weight
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
            // For simple nutritional profiles, default to Group 1
            // High protein, low carb, low fat = likely plain meat
            if foodItem.protein > 15 && foodItem.carbs < 5 {
                return 1
            }
            // High carb, low fat = likely grain/rice
            if foodItem.carbs > 20 && foodItem.fat < 3 {
                return 1
            }
            // Otherwise default to NOVA 2 (processed ingredients) as middle ground
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
    
    /// Predict NOVA score based only on food name (for expanded meal items)
    /// Uses optimized NOVAKeywordDictionary for fast O(1) lookups
    func predictNovaScoreByName(_ foodName: String) -> Int {
        let name = foodName.lowercased()
        
        // Check cache first
        if let cachedScore = predictionCache[name] {
            return cachedScore
        }
        
        // Use optimized NOVAKeywordDictionary for fast classification
        let predictedScore = NOVAKeywordDictionary.shared.classifyFood(name: name)
        
        // Cache result
        if predictionCache.count >= maxCacheSize {
            predictionCache.removeAll()
        }
        predictionCache[name] = predictedScore
        
        return predictedScore
    }
    
    /// Predict NOVA score using both name and ingredients (most accurate)
    func predictNovaScoreWithIngredients(_ foodName: String, ingredients: String?) -> Int {
        let name = foodName.lowercased()
        
        // Check cache first
        let cacheKey = name + (ingredients ?? "")
        if let cachedScore = predictionCache[cacheKey] {
            return cachedScore
        }
        
        // Use optimized NOVAKeywordDictionary
        let predictedScore = NOVAKeywordDictionary.shared.classifyFood(name: name, ingredients: ingredients)
        
        // Cache result
        if predictionCache.count >= maxCacheSize {
            predictionCache.removeAll()
        }
        predictionCache[cacheKey] = predictedScore
        
        return predictedScore
    }
}
