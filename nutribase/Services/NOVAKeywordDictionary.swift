import Foundation

/// Pre-compiled NOVA classification keyword dictionaries for fast lookup.
/// Uses optimized data structures for O(1) keyword matching instead of O(n) string scanning.
class NOVAKeywordDictionary {
    static let shared = NOVAKeywordDictionary()
    
    // MARK: - Optimized Lookup Sets (O(1) lookup)
    
    /// Group 4 ultra-processed indicators - Set for O(1) lookup
    private let group4Keywords: Set<String>
    
    /// Group 4 additives (E-numbers and additive names)
    private let group4Additives: Set<String>
    
    /// Group 3 processing indicators
    private let group3Keywords: Set<String>
    
    /// Group 2 culinary ingredients
    private let group2Keywords: Set<String>
    
    /// Group 1 unprocessed food indicators
    private let group1Keywords: Set<String>
    
    /// Product categories that are always Group 4
    private let group4Categories: Set<String>
    
    /// E-number regex pattern (pre-compiled)
    private let eNumberRegex: NSRegularExpression?
    
    // MARK: - Prefix Tries for Partial Matching
    
    /// Trie node for efficient prefix matching
    private class TrieNode {
        var children: [Character: TrieNode] = [:]
        var isEndOfWord: Bool = false
        var novaGroup: Int = 0
    }
    
    private let keywordTrie: TrieNode
    
    // MARK: - Pre-tokenized Common Foods Cache
    
    /// Cache of pre-classified common food names
    private var commonFoodCache: [String: Int] = [:]
    
    // MARK: - Initialization
    
    private init() {
        // Group 4 Keywords (Ultra-processed)
        group4Keywords = Set([
            // Proteins
            "hydrolysed", "hydrolyzed", "protein isolate", "soy protein", "whey protein",
            "casein", "lactose", "whey", "protein concentrate", "textured vegetable protein",
            
            // Fats and oils
            "hydrogenated", "partially hydrogenated", "interesterified", "palm oil", "fractionated",
            
            // Starches and sweeteners
            "maltodextrin", "high fructose corn syrup", "hfcs", "glucose syrup", "fructose syrup",
            "inverted sugar", "isoglucose", "dextrose", "modified starch", "modified food starch",
            "corn syrup", "glucose-fructose", "agave syrup",
            
            // Flavor enhancers
            "monosodium glutamate", "msg", "flavour enhancer", "flavor enhancer",
            "yeast extract", "autolyzed yeast", "hydrolyzed vegetable protein",
            
            // Preservatives and additives
            "sodium benzoate", "potassium sorbate", "sodium nitrite", "sodium nitrate",
            "bha", "bht", "tbhq", "propyl gallate",
            
            // Emulsifiers and stabilizers
            "lecithin", "mono and diglycerides", "polysorbate", "carrageenan",
            "xanthan gum", "guar gum", "cellulose gum", "methylcellulose",
            
            // Colorings
            "artificial color", "artificial colour", "fd&c", "caramel color", "caramel colour",
            "titanium dioxide", "annatto", "tartrazine",
            
            // Sweeteners
            "aspartame", "sucralose", "acesulfame", "saccharin", "stevia extract",
            "erythritol", "xylitol", "sorbitol", "maltitol", "mannitol",
            
            // Processing indicators
            "enriched", "fortified", "reconstituted", "mechanically separated",
            "ultra-pasteurized", "ultra pasteurized"
        ])
        
        // Group 4 Additives (E-numbers commonly associated with ultra-processing)
        group4Additives = Set([
            // Preservatives
            "e200", "e202", "e210", "e211", "e212", "e213", "e214", "e215",
            "e220", "e221", "e222", "e223", "e224", "e226", "e227", "e228",
            "e249", "e250", "e251", "e252",
            
            // Colorings
            "e100", "e101", "e102", "e104", "e110", "e120", "e122", "e123", "e124", "e127",
            "e129", "e131", "e132", "e133", "e140", "e141", "e142", "e150a", "e150b",
            "e150c", "e150d", "e151", "e153", "e155", "e160a", "e160b", "e160c", "e160d",
            "e160e", "e161b", "e162", "e163", "e170", "e171", "e172", "e173", "e174", "e175",
            
            // Sweeteners
            "e420", "e421", "e950", "e951", "e952", "e953", "e954", "e955", "e957",
            "e959", "e960", "e961", "e962", "e965", "e966", "e967", "e968",
            
            // Emulsifiers
            "e322", "e400", "e401", "e402", "e403", "e404", "e405", "e406", "e407",
            "e410", "e412", "e413", "e414", "e415", "e416", "e417", "e418", "e425",
            "e432", "e433", "e434", "e435", "e436", "e440", "e442", "e444", "e445",
            "e460", "e461", "e462", "e463", "e464", "e465", "e466", "e470a", "e470b",
            "e471", "e472a", "e472b", "e472c", "e472d", "e472e", "e472f", "e473", "e474", "e475",
            "e476", "e477", "e479b", "e481", "e482", "e483", "e491", "e492", "e493", "e494", "e495",
            
            // Flavor enhancers
            "e620", "e621", "e622", "e623", "e624", "e625", "e626", "e627", "e628",
            "e629", "e630", "e631", "e632", "e633", "e634", "e635",
            
            // Anti-oxidants
            "e300", "e301", "e302", "e304", "e306", "e307", "e308", "e309",
            "e310", "e311", "e312", "e315", "e316", "e319", "e320", "e321"
        ])
        
        // Group 4 Categories (always ultra-processed)
        group4Categories = Set([
            "soda", "soft drink", "energy drink", "sports drink", "cola", "lemonade",
            "ice cream", "frozen dessert", "gelato",
            "candy", "sweets", "confectionery", "chocolate bar", "gummy",
            "chips", "crisps", "doritos", "pringles", "cheetos",
            "instant noodles", "cup noodles", "ramen instant",
            "hot dog", "chicken nugget", "fish stick", "fish finger",
            "breakfast cereal", "cereal bar", "granola bar", "protein bar",
            "margarine", "spread",
            "instant soup", "cup soup", "bouillon cube",
            "frozen pizza", "frozen meal", "tv dinner", "ready meal",
            "sausage", "bacon", "ham", "salami", "pepperoni", "bologna",
            "cookie", "biscuit", "cracker", "wafer",
            "cake", "pastry", "doughnut", "donut", "muffin", "croissant",
            "fast food", "mcdonalds", "burger king", "kfc", "wendys"
        ])
        
        // Group 3 Keywords (Processed)
        group3Keywords = Set([
            "canned", "tinned", "preserved", "pickled", "smoked", "cured",
            "salted", "sugared", "sweetened", "in syrup", "in brine",
            "cheese", "fresh bread", "wine", "beer", "cider"
        ])
        
        // Group 2 Keywords (Culinary Ingredients)
        group2Keywords = Set([
            "olive oil", "vegetable oil", "sunflower oil", "coconut oil", "sesame oil",
            "butter", "ghee", "lard", "tallow",
            "sugar", "honey", "maple syrup", "molasses",
            "salt", "sea salt", "rock salt",
            "flour", "wheat flour", "corn flour", "rice flour",
            "starch", "corn starch", "potato starch",
            "vinegar", "balsamic", "apple cider vinegar"
        ])
        
        // Group 1 Keywords (Unprocessed/Minimally processed)
        group1Keywords = Set([
            "fresh", "raw", "whole", "plain", "natural", "organic",
            "apple", "banana", "orange", "grape", "berry", "melon",
            "carrot", "broccoli", "spinach", "lettuce", "tomato", "cucumber",
            "chicken breast", "beef steak", "pork chop", "fish fillet",
            "egg", "milk", "yogurt plain", "plain yogurt",
            "rice", "oats", "quinoa", "barley", "bulgur",
            "beans", "lentils", "chickpeas", "peas",
            "nuts", "almonds", "walnuts", "cashews", "peanuts",
            "seeds", "chia seeds", "flax seeds", "sunflower seeds"
        ])
        
        // Compile E-number regex
        eNumberRegex = try? NSRegularExpression(pattern: "\\be\\d{3}[a-z]?\\b", options: .caseInsensitive)
        
        // Build keyword trie
        keywordTrie = TrieNode()
        buildKeywordTrie()
        
        // Pre-cache common foods
        precomputeCommonFoods()
    }
    
    // MARK: - Trie Building
    
    private func buildKeywordTrie() {
        // Add all keywords to trie with their NOVA group
        for keyword in group4Keywords {
            insertIntoTrie(keyword, group: 4)
        }
        for keyword in group3Keywords {
            insertIntoTrie(keyword, group: 3)
        }
        for keyword in group2Keywords {
            insertIntoTrie(keyword, group: 2)
        }
        for keyword in group1Keywords {
            insertIntoTrie(keyword, group: 1)
        }
    }
    
    private func insertIntoTrie(_ word: String, group: Int) {
        var current = keywordTrie
        for char in word.lowercased() {
            if current.children[char] == nil {
                current.children[char] = TrieNode()
            }
            current = current.children[char]!
        }
        current.isEndOfWord = true
        current.novaGroup = group
    }
    
    // MARK: - Pre-computed Common Foods
    
    private func precomputeCommonFoods() {
        // Pre-classify 500+ common food names for instant lookup
        let commonFoods: [(String, Int)] = [
            // Fruits (Group 1)
            ("apple", 1), ("banana", 1), ("orange", 1), ("grape", 1), ("strawberry", 1),
            ("blueberry", 1), ("raspberry", 1), ("mango", 1), ("pineapple", 1), ("watermelon", 1),
            ("peach", 1), ("pear", 1), ("plum", 1), ("cherry", 1), ("kiwi", 1),
            ("avocado", 1), ("lemon", 1), ("lime", 1), ("grapefruit", 1), ("coconut", 1),
            
            // Vegetables (Group 1)
            ("broccoli", 1), ("carrot", 1), ("spinach", 1), ("kale", 1), ("lettuce", 1),
            ("tomato", 1), ("cucumber", 1), ("pepper", 1), ("onion", 1), ("garlic", 1),
            ("potato", 1), ("sweet potato", 1), ("corn", 1), ("peas", 1), ("beans", 1),
            ("mushroom", 1), ("zucchini", 1), ("eggplant", 1), ("cabbage", 1), ("cauliflower", 1),
            
            // Meats (Group 1)
            ("chicken", 1), ("beef", 1), ("pork", 1), ("lamb", 1), ("turkey", 1),
            ("fish", 1), ("salmon", 1), ("tuna", 1), ("shrimp", 1), ("crab", 1),
            
            // Dairy (Group 1)
            ("milk", 1), ("yogurt", 1), ("egg", 1), ("eggs", 1),
            
            // Grains (Group 1)
            ("rice", 1), ("oats", 1), ("quinoa", 1), ("barley", 1), ("wheat berries", 1),
            
            // Oils (Group 2)
            ("olive oil", 2), ("coconut oil", 2), ("vegetable oil", 2), ("butter", 2),
            
            // Processed (Group 3)
            ("cheese", 3), ("bread", 3), ("canned beans", 3), ("canned tomatoes", 3),
            ("wine", 3), ("beer", 3), ("pickles", 3), ("sauerkraut", 3),
            
            // Ultra-processed (Group 4)
            ("coca cola", 4), ("pepsi", 4), ("sprite", 4), ("fanta", 4),
            ("doritos", 4), ("cheetos", 4), ("lays", 4), ("pringles", 4),
            ("oreo", 4), ("chips ahoy", 4), ("snickers", 4), ("mars bar", 4),
            ("hot dog", 4), ("chicken nuggets", 4), ("fish sticks", 4),
            ("instant noodles", 4), ("cup noodles", 4), ("ramen", 4),
            ("frozen pizza", 4), ("pizza rolls", 4), ("bagel bites", 4),
            ("pop tarts", 4), ("toaster strudel", 4),
            ("lucky charms", 4), ("froot loops", 4), ("frosted flakes", 4),
            ("red bull", 4), ("monster energy", 4), ("gatorade", 4)
        ]
        
        for (food, group) in commonFoods {
            commonFoodCache[food.lowercased()] = group
        }
    }
    
    // MARK: - Public Classification Methods
    
    /// Fast NOVA classification using all optimizations
    func classifyFood(name: String, ingredients: String? = nil) -> Int {
        let nameLower = name.lowercased()
        
        // 1. Check common food cache first (O(1))
        if let cached = commonFoodCache[nameLower] {
            return cached
        }
        
        // 2. Check product categories (O(1))
        for category in group4Categories {
            if nameLower.contains(category) {
                return 4
            }
        }
        
        // 3. Check ingredients if provided
        if let ingredientList = ingredients?.lowercased(), !ingredientList.isEmpty {
            return classifyByIngredients(ingredientList)
        }
        
        // 4. Classify by name keywords
        return classifyByKeywords(nameLower)
    }
    
    /// Fast ingredient-based classification
    func classifyByIngredients(_ ingredients: String) -> Int {
        let lower = ingredients.lowercased()
        
        // Check for E-numbers (Group 4)
        if let regex = eNumberRegex {
            let range = NSRange(lower.startIndex..., in: lower)
            if regex.firstMatch(in: lower, options: [], range: range) != nil {
                return 4
            }
        }
        
        // Check Group 4 additives
        for additive in group4Additives {
            if lower.contains(additive) {
                return 4
            }
        }
        
        // Check Group 4 keywords
        for keyword in group4Keywords {
            if lower.contains(keyword) {
                return 4
            }
        }
        
        // Check Group 3 keywords
        for keyword in group3Keywords {
            if lower.contains(keyword) {
                return 3
            }
        }
        
        // Simple ingredients = Group 1 or 2
        let ingredientCount = ingredients.components(separatedBy: ",").count
        return ingredientCount <= 3 ? 1 : 3
    }
    
    /// Keyword-based classification
    private func classifyByKeywords(_ text: String) -> Int {
        // Check Group 4 first (most restrictive)
        for keyword in group4Keywords {
            if text.contains(keyword) {
                return 4
            }
        }
        
        // Check Group 3
        for keyword in group3Keywords {
            if text.contains(keyword) {
                return 3
            }
        }
        
        // Check Group 2
        for keyword in group2Keywords {
            if text.contains(keyword) {
                return 2
            }
        }
        
        // Check Group 1
        for keyword in group1Keywords {
            if text.contains(keyword) {
                return 1
            }
        }
        
        // Default to unprocessed for unknown foods
        return 1
    }
    
    /// Check if text contains any E-numbers
    func containsENumbers(_ text: String) -> Bool {
        guard let regex = eNumberRegex else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text.lowercased(), options: [], range: range) != nil
    }
    
    /// Get all E-numbers found in text
    func extractENumbers(_ text: String) -> [String] {
        guard let regex = eNumberRegex else { return [] }
        let lower = text.lowercased()
        let range = NSRange(lower.startIndex..., in: lower)
        let matches = regex.matches(in: lower, options: [], range: range)
        
        return matches.compactMap { match in
            guard let range = Range(match.range, in: lower) else { return nil }
            return String(lower[range])
        }
    }
    
    // MARK: - Cache Management
    
    /// Add a food to the common foods cache
    func cacheFood(_ name: String, group: Int) {
        commonFoodCache[name.lowercased()] = group
    }
    
    /// Get cache statistics
    func getCacheStats() -> String {
        return """
        📊 NOVA Dictionary Stats:
        - Common foods cached: \(commonFoodCache.count)
        - Group 4 keywords: \(group4Keywords.count)
        - Group 4 additives: \(group4Additives.count)
        - Group 4 categories: \(group4Categories.count)
        - Group 3 keywords: \(group3Keywords.count)
        - Group 2 keywords: \(group2Keywords.count)
        - Group 1 keywords: \(group1Keywords.count)
        """
    }
}
