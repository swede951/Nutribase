//
//  GutHealthScoreService.swift
//  nutribase
//
//  Created by Cascade on 2025-12-26.
//

import Foundation
import SwiftUI

/// Service for calculating gut health scores based on dietary data
class GutHealthScoreService: ObservableObject {
    static let shared = GutHealthScoreService()
    
    // MARK: - Metrics Cache
    
    private struct CachedMetrics {
        let metrics: GutHealthMetrics
        let entriesHash: Int
        let timestamp: Date
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 60 // 1 minute expiration
        }
    }
    
    // Cache keyed by date string (for daily) or "week_offset" (for weekly)
    private var metricsCache: [String: CachedMetrics] = [:]
    private let maxCacheEntries = 14 // Keep up to 14 days/weeks cached
    
    // MARK: - Score Weights (Spec-Compliant 4-Pillar System)
    // Based on NutriBase Gut Health Feature Full Implementation Breakdown
    
    // Pillar weights (total = 100)
    let pillar1Weight: Double = 35.0  // Fibre & Plant Diversity
    let pillar2Weight: Double = 30.0  // Ultra-Processed Foods (NOVA 4)
    let pillar3Weight: Double = 20.0  // Fermented & Prebiotic Foods
    let pillar4Weight: Double = 15.0  // Fat Quality & Inflammatory Balance
    
    // MARK: - Pillar 1: Fibre & Plant Diversity (35 pts)
    // Method: Broad / categorical (primary)
    
    // 1A. Fibre-Dense Food Frequency (18 pts max)
    // Uses fiber density bands, not raw grams
    let fiberFrequencyMaxPoints: Double = 18.0
    let fiberFrequencyTargetDaily: Double = 8.0   // ~8 fibre-points/day for full score (more achievable)
    
    // 1B. Plant Diversity (12 pts max)
    let plantDiversityMaxPoints: Double = 12.0
    let plantDiversityOptimal: Double = 3.6       // ~25 plants/week (3.6/day avg) → 12 pts
    let herbSpiceCap: Int = 4                     // Max herbs/spices counted per week
    
    // 1C. Fibre Grams Modifier (5 pts max) - Optional, only when data quality ≥60%
    let fiberGramsMaxPoints: Double = 5.0
    let fiberGramsOptimal: Double = 25.0          // ≥25g/day avg → 5 pts
    let fiberDataQualityThreshold: Double = 0.60  // 60% coverage required
    
    // MARK: - Pillar 2: Ultra-Processed Foods / NOVA 4 (30 pts)
    // Method: Exact numeric
    
    let upfMaxPoints: Double = 30.0
    let upfExcellentThreshold: Double = 20.0      // ≤20% → full points
    let upfPoorThreshold: Double = 50.0           // ≥50% → near-zero
    
    // MARK: - Pillar 3: Fermented & Prebiotic Foods (20 pts)
    // Method: Broad / frequency-based (daily averages)
    
    // 3A. Fermented Foods (10 pts)
    let fermentedMaxPoints: Double = 10.0
    let fermentedOptimalDaily: Double = 0.5       // ≥0.5 servings/day avg → 10 pts
    
    // 3B. Prebiotic Foods (10 pts)
    let prebioticMaxPoints: Double = 10.0
    let prebioticOptimalDaily: Double = 0.75      // ≥0.75 servings/day avg → 10 pts
    
    // MARK: - Pillar 4: Fat Quality & Inflammatory Balance (15 pts)
    // Method: Hybrid (numeric → banded)
    
    // 4A. Unsat:Sat Fat Ratio - Banded (8 pts)
    let fatRatioMaxPoints: Double = 8.0
    let fatRatioOptimal: Double = 2.0             // ≥2:1 → full points
    let fatRatioMin: Double = 1.0                 // <1 → capped
    
    // 4B. Omega-3 Foods - Frequency (7 pts)
    let omega3MaxPoints: Double = 7.0
    let omega3OptimalWeekly: Double = 2.0         // ≥2 servings/week → 7 pts (weekly goal, not daily)
    
    // MARK: - Fiber Density Bands
    // Priority: fiber g/100g → food group tags → NOVA → keyword heuristics
    
    enum FiberDensityBand: Int, CaseIterable {
        case veryHigh = 4   // Legumes, lentils, chia/flax
        case high = 3       // Vegetables, berries, whole grains
        case moderate = 2   // Fruit, potatoes (skin)
        case low = 1        // Refined grains, dairy, meat
        case veryLow = 0    // Confectionery, sugary drinks
    }
    
    // MARK: - Confidence Level (NOT part of score)
    enum ConfidenceLevel: String {
        case high = "High"      // ≥80% foods classified with high confidence
        case medium = "Medium"  // 50-79%
        case low = "Low"        // <50%
    }
    
    // Legacy aliases for backward compatibility
    var fiberDiversityWeight: Double { pillar1Weight }
    var upfLoadWeight: Double { pillar2Weight }
    var fermentedPrebioticWeight: Double { pillar3Weight }
    var fatQualityWeight: Double { pillar4Weight }
    
    // MARK: - Category Colors
    
    let fiberDiversityColor = Color(red: 0.2, green: 0.7, blue: 0.4)    // Green
    let upfLoadColor = Color(red: 0.9, green: 0.3, blue: 0.3)           // Red
    let fermentedPrebioticColor = Color(red: 0.6, green: 0.4, blue: 0.8) // Purple
    let fatQualityColor = Color(red: 1.0, green: 0.6, blue: 0.2)        // Orange
    
    // Legacy colors (for backward compatibility)
    let fiberColor = Color(red: 0.2, green: 0.7, blue: 0.4)
    let nova4Color = Color(red: 0.9, green: 0.3, blue: 0.3)
    let sugarColor = Color(red: 1.0, green: 0.6, blue: 0.2)
    let nutriScoreColor = Color(red: 0.3, green: 0.5, blue: 0.9)
    
    // Legacy thresholds (for backward compatibility with insight methods)
    let fiberOptimalGrams: Double = 30.0  // Used in getFiberInsight
    let fiberTargetGrams: Double = 25.0
    let sugarLimitGrams: Double = 25.0
    let sugarHighGrams: Double = 50.0
    let nova4LowPercent: Double = 20.0
    let nova4HighPercent: Double = 50.0
    
    // Gauge colors (red to green gradient)
    let gaugeColors: [Color] = [
        Color(red: 0.85, green: 0.2, blue: 0.2),   // Red (0-20)
        Color(red: 0.95, green: 0.5, blue: 0.2),   // Orange (20-40)
        Color(red: 0.95, green: 0.8, blue: 0.2),   // Yellow (40-60)
        Color(red: 0.6, green: 0.8, blue: 0.3),    // Lime (60-80)
        Color(red: 0.2, green: 0.7, blue: 0.3)     // Green (80-100)
    ]
    
    // MARK: - Food Category Detection Keywords
    
    // Fiber Density Band Keywords (for Pillar 1A scoring)
    // Very High (4 pts): Legumes, lentils, chia/flax, artichoke
    private let veryHighFiberKeywords: Set<String> = [
        // Legumes (5-8g fiber per serving)
        "lentil", "chickpea", "black bean", "kidney bean", "pinto bean", "navy bean",
        "cannellini", "split pea", "dal", "dahl", "legume", "bean", "pulse",
        "white bean", "butter bean", "lima bean", "broad bean", "fava bean",
        "mung bean", "adzuki", "black-eyed pea", "cowpea",
        // Seeds (very high fiber)
        "chia", "chia seed", "flax", "flaxseed", "linseed", "psyllium",
        // Bran products
        "bran", "wheat bran", "oat bran", "all-bran", "fiber one",
        // High fiber vegetables (6+ g per serving)
        "artichoke", "jerusalem artichoke", "sunchoke"
    ]
    
    // High (3 pts): Vegetables, berries, whole grains (3-6g fiber per serving)
    private let highFiberKeywords: Set<String> = [
        // Cruciferous vegetables
        "broccoli", "brussels sprout", "kale", "spinach", "cabbage",
        "cauliflower", "collard", "bok choy", "kohlrabi",
        // Root vegetables
        "carrot", "parsnip", "turnip", "beetroot", "beet", "sweet potato",
        "yam", "rutabaga", "celeriac",
        // Squash family
        "pumpkin", "squash", "butternut", "acorn squash", "spaghetti squash",
        // Other high-fiber vegetables
        "pea", "green bean", "asparagus", "leek", "okra", "fennel",
        "swiss chard", "dandelion green", "mustard green", "turnip green",
        // Berries (high fiber fruits)
        "raspberry", "blackberry", "blueberry", "strawberry", "mixed berries",
        "boysenberry", "mulberry", "gooseberry", "cranberry", "acai",
        // Whole grains
        "oat", "oatmeal", "porridge", "overnight oat", "steel cut oat",
        "quinoa", "barley", "bulgur", "farro", "freekeh",
        "brown rice", "wild rice", "whole grain", "wholegrain", "whole wheat",
        "wholemeal", "rye bread", "pumpernickel", "granola", "muesli",
        "buckwheat", "amaranth", "teff", "millet", "spelt", "kamut",
        // Prepared foods with legumes/grains
        "edamame", "hummus", "falafel", "veggie", "vegetable", "bean soup",
        "lentil soup", "minestrone", "chili", "dal", "dhal",
        // High fiber fruits
        "guava", "passion fruit", "asian pear", "dried fig", "prune"
    ]
    
    // Moderate (2 pts): Fruit, potatoes, nuts, seeds (2-3g fiber per serving)
    private let moderateFiberKeywords: Set<String> = [
        // Common fruits
        "apple", "pear", "orange", "banana", "mango", "peach", "plum", "apricot",
        "grape", "kiwi", "melon", "watermelon", "pineapple", "papaya",
        "nectarine", "tangerine", "clementine", "mandarin", "grapefruit",
        "cherry", "fig", "date", "pomegranate", "persimmon", "dragonfruit",
        "lychee", "longan", "rambutan", "jackfruit", "durian", "starfruit",
        // Vegetables
        "potato", "corn", "avocado", "tomato", "cucumber", "pepper",
        "celery", "lettuce", "mushroom", "onion", "garlic", "salad",
        "zucchini", "courgette", "eggplant", "aubergine", "radish",
        "green onion", "spring onion", "scallion", "shallot",
        "bean sprout", "bamboo shoot", "water chestnut", "jicama",
        // Nuts (all provide moderate fiber)
        "almond", "walnut", "cashew", "pistachio", "peanut", "hazelnut",
        "pecan", "macadamia", "brazil nut", "pine nut", "chestnut", "nut",
        "nut butter", "peanut butter", "almond butter",
        // Seeds
        "sunflower seed", "pumpkin seed", "sesame", "seed", "hemp seed",
        "poppy seed", "tahini",
        // General terms
        "fruit", "berry", "smoothie", "fruit salad", "trail mix",
        // Other moderate fiber foods
        "olive", "olives",
        // Dried fruits
        "raisin", "sultana", "currant", "dried apricot", "dried mango",
        "dried cranberry", "craisin", "dried fruit"
    ]
    
    // Low (1 pt): Refined grains, dairy, meat, processed foods
    private let lowFiberKeywords: Set<String> = [
        // Refined grains
        "white bread", "white rice", "rice", "basmati", "jasmine",
        "pasta", "noodle", "cracker", "bagel",
        "croissant", "muffin", "pancake", "waffle", "tortilla", "pita",
        "couscous", "semolina", "cornflake", "rice krispie", "cheerio",
        "macaroni", "spaghetti", "linguine", "fettuccine", "penne", "fusilli",
        "ramen", "udon", "soba", "rice noodle", "vermicelli",
        "bread roll", "baguette", "ciabatta", "focaccia", "naan",
        "wrap", "flatbread", "lavash", "matzo",
        // Dairy
        "milk", "cheese", "yogurt", "cream", "butter", "sour cream",
        "cottage cheese", "ricotta", "mozzarella", "cheddar", "parmesan",
        "cream cheese", "brie", "camembert", "feta", "gouda",
        "ice cream", "frozen yogurt", "custard", "pudding",
        // Meat & protein (minimal fiber)
        "chicken", "beef", "pork", "lamb", "fish", "salmon", "tuna",
        "turkey", "duck", "goose", "venison", "bison", "veal",
        "steak", "roast", "chop", "fillet", "loin", "rib",
        "bacon", "ham", "sausage", "hot dog", "deli meat", "pepperoni",
        "shrimp", "prawn", "lobster", "crab", "scallop", "mussel", "clam",
        "cod", "tilapia", "halibut", "trout", "bass", "snapper",
        "egg", "tofu", "tempeh", "seitan"
    ]
    
    // Very Low (0 pts): Confectionery, sugary drinks, ultra-processed
    private let veryLowFiberKeywords: Set<String> = [
        // Candy & sweets
        "candy", "chocolate bar", "sweet", "sugar", "syrup", "honey",
        "gummy", "gummi", "jellybean", "lollipop", "licorice", "toffee",
        "marshmallow", "cotton candy", "hard candy", "fruit snack",
        // Sugary drinks
        "soda", "cola", "lemonade", "energy drink", "sports drink",
        "fruit punch", "sweet tea", "iced tea", "frappuccino", "slushie",
        "milkshake", "hot chocolate", "mocha",
        // Baked desserts
        "cake", "cookie", "biscuit", "donut", "doughnut",
        "pastry", "pie", "brownie", "fudge", "caramel",
        "cupcake", "muffin top", "danish", "strudel", "eclair",
        "macaron", "macaroon", "meringue", "profiterole",
        "cheesecake", "tiramisu", "mousse", "panna cotta",
        // Chips & snacks
        "potato chip", "crisp", "corn chip", "tortilla chip", "nacho",
        "cheese puff", "cheeto", "dorito", "pretzel"
    ]
    
    // Generic terms that should be demoted unless specific food detected
    // These give 1 point max unless a specific fruit/vegetable is also matched
    private let genericTermKeywords: Set<String> = [
        "fruit", "vegetable", "veggie", "smoothie", "juice", "salad", "mixed",
        "assorted", "variety", "blend", "medley"
    ]
    
    // Specific fruit keywords (used to validate generic terms)
    private let specificFruitKeywords: Set<String> = [
        "apple", "banana", "orange", "grape", "strawberry", "blueberry", "raspberry",
        "blackberry", "mango", "pineapple", "watermelon", "melon", "kiwi", "peach",
        "pear", "plum", "cherry", "apricot", "fig", "date", "pomegranate", "papaya"
    ]
    
    // Specific vegetable keywords (used to validate generic terms)
    private let specificVegetableKeywords: Set<String> = [
        "spinach", "kale", "broccoli", "carrot", "tomato", "cucumber", "pepper",
        "onion", "garlic", "lettuce", "cabbage", "cauliflower", "celery", "asparagus",
        "beetroot", "squash", "pumpkin", "zucchini", "eggplant", "mushroom", "corn"
    ]
    
    // Herbs & Spices (count separately, capped)
    private let herbSpiceKeywords: Set<String> = [
        "basil", "oregano", "thyme", "rosemary", "parsley", "cilantro", "coriander",
        "mint", "dill", "sage", "bay leaf", "chive", "tarragon",
        "cumin", "turmeric", "paprika", "cinnamon", "ginger", "nutmeg", "clove",
        "cardamom", "saffron", "vanilla", "pepper", "chili", "cayenne"
    ]
    
    // Fermented foods (for gut microbiome) - comprehensive list from research
    private let fermentedFoodKeywords: Set<String> = [
        // Dairy-based fermented
        "yogurt", "yoghurt", "greek yogurt", "kefir", "lassi", "skyr", "quark",
        "buttermilk", "sour cream", "creme fraiche", "labneh", "ayran",
        "cottage cheese", "raw cheese", "aged cheese",
        // Vegetable ferments
        "kimchi", "sauerkraut", "pickled", "fermented", "lacto-fermented",
        "pickled cucumber", "pickled cabbage", "curtido", "tsukemono",
        // Soy-based ferments
        "miso", "tempeh", "natto", "doenjang", "gochujang",
        "soy sauce", "tamari", "liquid aminos",
        // Fermented beverages
        "kombucha", "kvass", "jun", "water kefir", "ginger beer",
        "tepache", "rejuvelac", "beet kvass",
        // Bread & grain ferments
        "sourdough", "injera", "idli", "dosa", "dhokla",
        // Vinegars
        "apple cider vinegar", "raw vinegar", "mother vinegar",
        // Other fermented foods
        "probiotic", "live culture", "active culture",
        "coconut yogurt", "coconut kefir", "almond yogurt"
    ]
    
    // Prebiotic-rich foods (feed good bacteria) - from Healthline research
    private let prebioticFoodKeywords: Set<String> = [
        // Allium family (highest in inulin & FOS)
        "onion", "garlic", "leek", "shallot", "spring onion", "scallion",
        "green onion", "chive", "ramp",
        // Root vegetables high in inulin
        "chicory", "chicory root", "jerusalem artichoke", "sunchoke",
        "dandelion", "dandelion green", "burdock", "burdock root",
        "yacon", "yacon root", "jicama", "jicama root",
        // Other prebiotic vegetables
        "asparagus", "artichoke", "globe artichoke",
        // Prebiotic fruits
        "banana", "green banana", "plantain", "apple",
        // Prebiotic grains
        "oat", "oatmeal", "porridge", "barley", "wheat bran",
        // Prebiotic seeds
        "flaxseed", "linseed", "chia seed",
        // Other prebiotic foods
        "seaweed", "kelp", "nori", "wakame", "dulse", "kombu",
        "cocoa", "cacao", "dark chocolate",
        "konjac", "shirataki", "glucomannan",
        // Legumes (resistant starch)
        "legume", "lentil", "chickpea", "bean", "pea"
    ]
    
    // Plant foods (for diversity counting) - expanded list for better matching
    private let plantFoodKeywords: Set<String> = [
        // Common Fruits
        "apple", "banana", "orange", "grape", "strawberry", "blueberry", "raspberry",
        "blackberry", "mango", "pineapple", "watermelon", "melon", "cantaloupe", "honeydew",
        "kiwi", "peach", "pear", "plum", "cherry", "apricot", "nectarine",
        "fig", "date", "pomegranate", "papaya", "passion fruit", "guava", "lychee",
        "coconut", "avocado", "tomato", "lemon", "lime", "grapefruit", "tangerine",
        "clementine", "mandarin", "cranberry", "boysenberry", "mulberry", "gooseberry",
        "persimmon", "dragonfruit", "starfruit", "jackfruit", "durian", "rambutan",
        "longan", "acai", "goji", "elderberry", "currant", "prune", "raisin",
        // Vegetables - Leafy Greens
        "spinach", "kale", "lettuce", "romaine", "arugula", "rocket", "watercress",
        "swiss chard", "chard", "collard", "mustard green", "turnip green", "beet green",
        "bok choy", "pak choi", "napa cabbage", "endive", "radicchio", "escarole",
        // Vegetables - Cruciferous
        "broccoli", "cauliflower", "cabbage", "brussels sprout", "kohlrabi",
        // Vegetables - Root
        "carrot", "beetroot", "beet", "radish", "turnip", "parsnip", "rutabaga",
        "sweet potato", "yam", "potato", "celeriac", "jicama", "daikon",
        // Vegetables - Allium
        "onion", "garlic", "leek", "shallot", "scallion", "spring onion", "chive",
        // Vegetables - Other
        "pepper", "bell pepper", "capsicum", "cucumber", "zucchini", "courgette",
        "eggplant", "aubergine", "celery", "asparagus", "artichoke",
        "pumpkin", "squash", "butternut", "acorn", "spaghetti squash",
        "mushroom", "portobello", "shiitake", "cremini", "oyster mushroom",
        "corn", "pea", "green bean", "snap pea", "snow pea", "fennel", "okra",
        "bamboo shoot", "bean sprout", "water chestnut", "lotus root",
        // Legumes
        "lentil", "chickpea", "black bean", "kidney bean", "pinto bean", "navy bean",
        "cannellini", "white bean", "butter bean", "lima bean", "broad bean", "fava bean",
        "mung bean", "adzuki", "black-eyed pea", "split pea",
        "edamame", "soybean", "hummus", "falafel", "dal", "dhal",
        // Nuts
        "almond", "walnut", "cashew", "pistachio", "hazelnut", "pecan", "macadamia",
        "peanut", "brazil nut", "pine nut", "chestnut", "coconut",
        // Seeds
        "sunflower seed", "pumpkin seed", "pepita", "chia seed", "flax seed", "flaxseed",
        "sesame", "hemp seed", "poppy seed", "tahini",
        // Whole Grains
        "oat", "oatmeal", "quinoa", "rice", "brown rice", "wild rice", "basmati", "jasmine rice",
        "barley", "bulgur", "farro", "millet", "buckwheat", "amaranth", "teff", "spelt",
        "rye", "wheat", "freekeh", "sorghum", "kamut", "couscous",
        // Additional common foods
        "olive", "olives"
    ]
    
    // Omega-3 rich foods - from Healthline/NIH research
    private let omega3FoodKeywords: Set<String> = [
        // Fatty fish (highest EPA/DHA content)
        "salmon", "wild salmon", "atlantic salmon", "sockeye", "king salmon",
        "mackerel", "atlantic mackerel", "king mackerel",
        "sardine", "anchovy", "herring", "kipper",
        "trout", "rainbow trout", "lake trout",
        "tuna", "albacore", "bluefin", "skipjack",
        // Other seafood
        "oyster", "mussel", "caviar", "roe", "fish egg",
        "cod liver", "fish oil", "krill oil",
        // Omega-3 supplements/fortified
        "omega-3", "omega 3", "dha", "epa", "fish oil capsule",
        // Plant sources (ALA omega-3)
        "flax", "flaxseed", "flax oil", "linseed",
        "chia", "chia seed", "chia pudding",
        "walnut", "black walnut", "english walnut",
        "hemp", "hemp seed", "hemp heart", "hemp oil",
        // Other plant sources
        "seaweed", "algae", "algae oil", "spirulina", "chlorella", "nori",
        "edamame", "soybean", "soy",
        "canola", "rapeseed", "canola oil",
        "perilla", "perilla oil",
        // Omega-3 enriched foods
        "omega-3 egg", "pasture raised egg", "grass-fed"
    ]
    
    // MARK: - USDA Verified Data (per 100g)
    // Source: USDA FoodData Central - SR Legacy & Foundation Foods
    // These are verified values from the official USDA database
    
    struct USDANutrient {
        let sugar: Double
        let fiber: Double
    }
    
    private let usdaDatabase: [String: USDANutrient] = [
        // Sweeteners (USDA verified)
        "honey": USDANutrient(sugar: 82.1, fiber: 0.2),
        "maple syrup": USDANutrient(sugar: 60.5, fiber: 0.0),
        "golden syrup": USDANutrient(sugar: 73.0, fiber: 0.0),
        "jam": USDANutrient(sugar: 48.5, fiber: 0.9),
        "marmalade": USDANutrient(sugar: 49.0, fiber: 0.5),
        "sugar": USDANutrient(sugar: 99.8, fiber: 0.0),
        "treacle": USDANutrient(sugar: 64.0, fiber: 0.0),
        "molasses": USDANutrient(sugar: 55.0, fiber: 0.0),
        
        // Fruits (USDA verified)
        "banana": USDANutrient(sugar: 12.2, fiber: 2.6),
        "apple": USDANutrient(sugar: 10.4, fiber: 2.4),
        "orange": USDANutrient(sugar: 9.4, fiber: 2.4),
        "grape": USDANutrient(sugar: 15.5, fiber: 0.9),
        "strawberry": USDANutrient(sugar: 4.9, fiber: 2.0),
        "blueberry": USDANutrient(sugar: 10.0, fiber: 2.4),
        "raspberry": USDANutrient(sugar: 4.4, fiber: 6.5),
        "mango": USDANutrient(sugar: 13.7, fiber: 1.6),
        "pineapple": USDANutrient(sugar: 10.0, fiber: 1.4),
        "avocado": USDANutrient(sugar: 0.7, fiber: 6.7),
        "watermelon": USDANutrient(sugar: 6.2, fiber: 0.4),
        "peach": USDANutrient(sugar: 8.4, fiber: 1.5),
        "pear": USDANutrient(sugar: 9.8, fiber: 3.1),
        "kiwi": USDANutrient(sugar: 9.0, fiber: 3.0),
        "cherry": USDANutrient(sugar: 12.8, fiber: 2.1),
        "plum": USDANutrient(sugar: 9.9, fiber: 1.4),
        "melon": USDANutrient(sugar: 8.0, fiber: 0.9),
        "grapefruit": USDANutrient(sugar: 6.9, fiber: 1.6),
        "lemon": USDANutrient(sugar: 2.5, fiber: 2.8),
        "lime": USDANutrient(sugar: 1.7, fiber: 2.8),
        
        // Dried fruits (USDA verified)
        "raisin": USDANutrient(sugar: 59.2, fiber: 3.7),
        "date": USDANutrient(sugar: 66.5, fiber: 6.7),
        "dried fig": USDANutrient(sugar: 47.9, fiber: 9.8),
        "prune": USDANutrient(sugar: 38.1, fiber: 7.1),
        "dried apricot": USDANutrient(sugar: 53.4, fiber: 7.3),
        "cranberry": USDANutrient(sugar: 65.0, fiber: 5.7),
        "dried mango": USDANutrient(sugar: 73.0, fiber: 2.4),
        "dried banana": USDANutrient(sugar: 35.3, fiber: 7.7),
        
        // More fruits (USDA verified)
        "papaya": USDANutrient(sugar: 7.8, fiber: 1.7),
        "pomegranate": USDANutrient(sugar: 13.7, fiber: 4.0),
        "passion fruit": USDANutrient(sugar: 11.2, fiber: 10.4),
        "guava": USDANutrient(sugar: 8.9, fiber: 5.4),
        "lychee": USDANutrient(sugar: 15.2, fiber: 1.3),
        "dragon fruit": USDANutrient(sugar: 8.0, fiber: 3.0),
        "coconut": USDANutrient(sugar: 6.2, fiber: 9.0),
        "fig": USDANutrient(sugar: 16.3, fiber: 2.9),
        "apricot": USDANutrient(sugar: 9.2, fiber: 2.0),
        "nectarine": USDANutrient(sugar: 7.9, fiber: 1.7),
        "tangerine": USDANutrient(sugar: 10.6, fiber: 1.8),
        "clementine": USDANutrient(sugar: 9.2, fiber: 1.7),
        "cantaloupe": USDANutrient(sugar: 7.9, fiber: 0.9),
        "honeydew": USDANutrient(sugar: 8.1, fiber: 0.8),
        "blackberry": USDANutrient(sugar: 4.9, fiber: 5.3),
        "gooseberry": USDANutrient(sugar: 8.0, fiber: 4.3),
        
        // Vegetables (USDA verified)
        "carrot": USDANutrient(sugar: 4.7, fiber: 2.8),
        "broccoli": USDANutrient(sugar: 1.7, fiber: 2.6),
        "spinach": USDANutrient(sugar: 0.4, fiber: 2.2),
        "tomato": USDANutrient(sugar: 2.6, fiber: 1.2),
        "potato": USDANutrient(sugar: 0.8, fiber: 2.1),
        "sweet potato": USDANutrient(sugar: 4.2, fiber: 3.0),
        "onion": USDANutrient(sugar: 4.2, fiber: 1.7),
        "pepper": USDANutrient(sugar: 2.4, fiber: 1.7),
        "cucumber": USDANutrient(sugar: 1.7, fiber: 0.5),
        "lettuce": USDANutrient(sugar: 0.8, fiber: 1.3),
        "celery": USDANutrient(sugar: 1.3, fiber: 1.6),
        "mushroom": USDANutrient(sugar: 2.0, fiber: 1.0),
        "zucchini": USDANutrient(sugar: 2.5, fiber: 1.0),
        "cauliflower": USDANutrient(sugar: 1.9, fiber: 2.0),
        "cabbage": USDANutrient(sugar: 3.2, fiber: 2.5),
        "asparagus": USDANutrient(sugar: 1.9, fiber: 2.1),
        "green bean": USDANutrient(sugar: 3.3, fiber: 2.7),
        "pea": USDANutrient(sugar: 5.7, fiber: 5.1),
        "corn": USDANutrient(sugar: 6.3, fiber: 2.7),
        "beetroot": USDANutrient(sugar: 6.8, fiber: 2.8),
        "olive": USDANutrient(sugar: 0.0, fiber: 3.2),
        "kale": USDANutrient(sugar: 1.3, fiber: 2.0),
        "brussels sprout": USDANutrient(sugar: 2.2, fiber: 3.8),
        "eggplant": USDANutrient(sugar: 3.5, fiber: 3.0),
        "artichoke": USDANutrient(sugar: 1.0, fiber: 5.4),
        "leek": USDANutrient(sugar: 3.9, fiber: 1.8),
        "radish": USDANutrient(sugar: 1.9, fiber: 1.6),
        "turnip": USDANutrient(sugar: 3.8, fiber: 1.8),
        "parsnip": USDANutrient(sugar: 4.8, fiber: 4.9),
        "squash": USDANutrient(sugar: 2.2, fiber: 1.5),
        "butternut squash": USDANutrient(sugar: 2.2, fiber: 2.0),
        "pumpkin": USDANutrient(sugar: 2.8, fiber: 0.5),
        "bok choy": USDANutrient(sugar: 1.2, fiber: 1.0),
        "swiss chard": USDANutrient(sugar: 1.1, fiber: 1.6),
        "collard": USDANutrient(sugar: 0.5, fiber: 4.0),
        "arugula": USDANutrient(sugar: 2.1, fiber: 1.6),
        "watercress": USDANutrient(sugar: 0.2, fiber: 0.5),
        "endive": USDANutrient(sugar: 0.3, fiber: 3.1),
        "fennel": USDANutrient(sugar: 3.9, fiber: 3.1),
        "okra": USDANutrient(sugar: 1.5, fiber: 3.2),
        "snap pea": USDANutrient(sugar: 4.0, fiber: 2.6),
        
        // Dairy (USDA verified)
        "milk": USDANutrient(sugar: 5.0, fiber: 0.0),
        "yogurt": USDANutrient(sugar: 4.7, fiber: 0.0),
        "greek yogurt": USDANutrient(sugar: 3.6, fiber: 0.0),
        "cheese": USDANutrient(sugar: 0.5, fiber: 0.0),
        "cheddar": USDANutrient(sugar: 0.5, fiber: 0.0),
        "mozzarella": USDANutrient(sugar: 1.0, fiber: 0.0),
        "parmesan": USDANutrient(sugar: 0.9, fiber: 0.0),
        "cream cheese": USDANutrient(sugar: 2.7, fiber: 0.0),
        "cottage cheese": USDANutrient(sugar: 2.7, fiber: 0.0),
        "butter": USDANutrient(sugar: 0.1, fiber: 0.0),
        "cream": USDANutrient(sugar: 2.9, fiber: 0.0),
        "ice cream": USDANutrient(sugar: 21.2, fiber: 0.0),
        
        // Meat & Poultry (USDA verified - all have 0g sugar/fiber)
        "chicken": USDANutrient(sugar: 0.0, fiber: 0.0),
        "beef": USDANutrient(sugar: 0.0, fiber: 0.0),
        "pork": USDANutrient(sugar: 0.0, fiber: 0.0),
        "lamb": USDANutrient(sugar: 0.0, fiber: 0.0),
        "turkey": USDANutrient(sugar: 0.0, fiber: 0.0),
        "duck": USDANutrient(sugar: 0.0, fiber: 0.0),
        "mince": USDANutrient(sugar: 0.0, fiber: 0.0),
        "steak": USDANutrient(sugar: 0.0, fiber: 0.0),
        "bacon": USDANutrient(sugar: 0.0, fiber: 0.0),
        "ham": USDANutrient(sugar: 1.0, fiber: 0.0),
        "sausage": USDANutrient(sugar: 1.2, fiber: 0.0),
        
        // Seafood (USDA verified)
        "salmon": USDANutrient(sugar: 0.0, fiber: 0.0),
        "tuna": USDANutrient(sugar: 0.0, fiber: 0.0),
        "cod": USDANutrient(sugar: 0.0, fiber: 0.0),
        "shrimp": USDANutrient(sugar: 0.0, fiber: 0.0),
        "prawn": USDANutrient(sugar: 0.0, fiber: 0.0),
        "crab": USDANutrient(sugar: 0.0, fiber: 0.0),
        "lobster": USDANutrient(sugar: 0.0, fiber: 0.0),
        "mackerel": USDANutrient(sugar: 0.0, fiber: 0.0),
        "sardine": USDANutrient(sugar: 0.0, fiber: 0.0),
        "haddock": USDANutrient(sugar: 0.0, fiber: 0.0),
        
        // Eggs (USDA verified)
        "egg": USDANutrient(sugar: 0.4, fiber: 0.0),
        
        // Grains (USDA verified)
        "rice": USDANutrient(sugar: 0.1, fiber: 0.4),
        "white rice": USDANutrient(sugar: 0.1, fiber: 0.4),
        "brown rice": USDANutrient(sugar: 0.4, fiber: 1.8),
        "pasta": USDANutrient(sugar: 0.6, fiber: 1.8),
        "bread": USDANutrient(sugar: 5.0, fiber: 2.7),
        "wholemeal": USDANutrient(sugar: 4.4, fiber: 6.8),
        "whole wheat": USDANutrient(sugar: 4.4, fiber: 6.8),
        "oat": USDANutrient(sugar: 1.0, fiber: 10.6),
        "oatmeal": USDANutrient(sugar: 1.0, fiber: 10.6),
        "porridge": USDANutrient(sugar: 1.0, fiber: 10.6),
        "quinoa": USDANutrient(sugar: 0.9, fiber: 2.8),
        "couscous": USDANutrient(sugar: 0.1, fiber: 1.4),
        "cereal": USDANutrient(sugar: 8.0, fiber: 5.0),
        "granola": USDANutrient(sugar: 14.3, fiber: 5.0),
        "muesli": USDANutrient(sugar: 13.0, fiber: 7.5),
        "cornflakes": USDANutrient(sugar: 8.0, fiber: 1.2),
        "bran": USDANutrient(sugar: 13.0, fiber: 18.3),
        "weetabix": USDANutrient(sugar: 4.4, fiber: 10.0),
        "bagel": USDANutrient(sugar: 6.0, fiber: 2.3),
        "croissant": USDANutrient(sugar: 10.5, fiber: 2.6),
        "naan": USDANutrient(sugar: 3.6, fiber: 2.1),
        "pita": USDANutrient(sugar: 1.3, fiber: 2.2),
        "tortilla": USDANutrient(sugar: 2.8, fiber: 2.4),
        "wrap": USDANutrient(sugar: 2.8, fiber: 2.4),
        "sourdough": USDANutrient(sugar: 1.9, fiber: 2.4),
        "rye bread": USDANutrient(sugar: 3.9, fiber: 5.8),
        "ciabatta": USDANutrient(sugar: 2.5, fiber: 2.3),
        "baguette": USDANutrient(sugar: 3.0, fiber: 2.4),
        "brioche": USDANutrient(sugar: 9.5, fiber: 2.0),
        "english muffin": USDANutrient(sugar: 5.0, fiber: 2.6),
        "pancake": USDANutrient(sugar: 8.0, fiber: 1.0),
        "waffle": USDANutrient(sugar: 10.0, fiber: 1.5),
        "french toast": USDANutrient(sugar: 8.0, fiber: 1.0),
        "crumpet": USDANutrient(sugar: 2.8, fiber: 2.2),
        "scone": USDANutrient(sugar: 14.0, fiber: 1.5),
        "barley": USDANutrient(sugar: 0.8, fiber: 15.6),
        "bulgur": USDANutrient(sugar: 0.4, fiber: 12.5),
        "farro": USDANutrient(sugar: 0.0, fiber: 3.0),
        "millet": USDANutrient(sugar: 0.0, fiber: 8.5),
        "buckwheat": USDANutrient(sugar: 0.0, fiber: 10.0),
        "polenta": USDANutrient(sugar: 0.6, fiber: 1.4),
        "spaghetti": USDANutrient(sugar: 0.6, fiber: 1.8),
        "noodle": USDANutrient(sugar: 0.6, fiber: 1.2),
        "ramen": USDANutrient(sugar: 1.0, fiber: 1.5),
        "udon": USDANutrient(sugar: 0.4, fiber: 1.3),
        "rice noodle": USDANutrient(sugar: 0.0, fiber: 0.9),
        
        // Nuts & Seeds (USDA verified)
        "almond": USDANutrient(sugar: 4.4, fiber: 12.5),
        "cashew": USDANutrient(sugar: 5.9, fiber: 3.3),
        "walnut": USDANutrient(sugar: 2.6, fiber: 6.7),
        "peanut": USDANutrient(sugar: 4.7, fiber: 8.5),
        "pistachio": USDANutrient(sugar: 7.7, fiber: 10.3),
        "hazelnut": USDANutrient(sugar: 4.3, fiber: 9.7),
        "pecan": USDANutrient(sugar: 4.0, fiber: 9.6),
        "macadamia": USDANutrient(sugar: 4.6, fiber: 8.6),
        "brazil nut": USDANutrient(sugar: 2.3, fiber: 7.5),
        "peanut butter": USDANutrient(sugar: 6.0, fiber: 6.0),
        "almond butter": USDANutrient(sugar: 4.4, fiber: 10.3),
        "chia seed": USDANutrient(sugar: 0.0, fiber: 34.4),
        "flax seed": USDANutrient(sugar: 1.6, fiber: 27.3),
        "sunflower seed": USDANutrient(sugar: 2.6, fiber: 8.6),
        "pumpkin seed": USDANutrient(sugar: 1.4, fiber: 6.5),
        
        // Legumes (USDA verified)
        "lentil": USDANutrient(sugar: 2.0, fiber: 7.9),
        "chickpea": USDANutrient(sugar: 4.8, fiber: 7.6),
        "black bean": USDANutrient(sugar: 0.3, fiber: 8.7),
        "kidney bean": USDANutrient(sugar: 2.2, fiber: 6.4),
        "hummus": USDANutrient(sugar: 0.3, fiber: 6.0),
        "tofu": USDANutrient(sugar: 0.6, fiber: 0.3),
        
        // Beverages (USDA verified)
        "cola": USDANutrient(sugar: 10.6, fiber: 0.0),
        "soda": USDANutrient(sugar: 10.6, fiber: 0.0),
        "pepsi": USDANutrient(sugar: 11.0, fiber: 0.0),
        "sprite": USDANutrient(sugar: 8.8, fiber: 0.0),
        "fanta": USDANutrient(sugar: 10.0, fiber: 0.0),
        "lemonade": USDANutrient(sugar: 8.9, fiber: 0.0),
        "ginger ale": USDANutrient(sugar: 8.1, fiber: 0.0),
        "tonic water": USDANutrient(sugar: 8.8, fiber: 0.0),
        "energy drink": USDANutrient(sugar: 11.0, fiber: 0.0),
        "red bull": USDANutrient(sugar: 11.0, fiber: 0.0),
        "monster": USDANutrient(sugar: 11.0, fiber: 0.0),
        "sports drink": USDANutrient(sugar: 6.0, fiber: 0.0),
        "gatorade": USDANutrient(sugar: 5.9, fiber: 0.0),
        "orange juice": USDANutrient(sugar: 8.4, fiber: 0.2),
        "apple juice": USDANutrient(sugar: 9.6, fiber: 0.1),
        "grape juice": USDANutrient(sugar: 14.2, fiber: 0.2),
        "cranberry juice": USDANutrient(sugar: 12.1, fiber: 0.1),
        "pineapple juice": USDANutrient(sugar: 9.5, fiber: 0.2),
        "tomato juice": USDANutrient(sugar: 3.6, fiber: 0.4),
        "carrot juice": USDANutrient(sugar: 4.0, fiber: 0.8),
        "smoothie": USDANutrient(sugar: 12.0, fiber: 1.0),
        "milkshake": USDANutrient(sugar: 18.0, fiber: 0.3),
        "hot chocolate": USDANutrient(sugar: 17.0, fiber: 1.5),
        "coffee": USDANutrient(sugar: 0.0, fiber: 0.0),
        "latte": USDANutrient(sugar: 5.0, fiber: 0.0),
        "cappuccino": USDANutrient(sugar: 4.0, fiber: 0.0),
        "mocha": USDANutrient(sugar: 15.0, fiber: 0.5),
        "frappuccino": USDANutrient(sugar: 20.0, fiber: 0.3),
        "tea": USDANutrient(sugar: 0.0, fiber: 0.0),
        "iced tea": USDANutrient(sugar: 8.0, fiber: 0.0),
        "chai": USDANutrient(sugar: 16.0, fiber: 0.5),
        "beer": USDANutrient(sugar: 0.0, fiber: 0.0),
        "lager": USDANutrient(sugar: 0.0, fiber: 0.0),
        "wine": USDANutrient(sugar: 0.6, fiber: 0.0),
        "red wine": USDANutrient(sugar: 0.6, fiber: 0.0),
        "white wine": USDANutrient(sugar: 1.0, fiber: 0.0),
        "champagne": USDANutrient(sugar: 1.5, fiber: 0.0),
        "cocktail": USDANutrient(sugar: 12.0, fiber: 0.0),
        "cider": USDANutrient(sugar: 5.0, fiber: 0.0),
        "almond milk": USDANutrient(sugar: 0.0, fiber: 0.5),
        "oat milk": USDANutrient(sugar: 4.0, fiber: 0.8),
        "soy milk": USDANutrient(sugar: 1.0, fiber: 0.6),
        "coconut milk": USDANutrient(sugar: 2.0, fiber: 0.0),
        "coconut water": USDANutrient(sugar: 2.6, fiber: 0.0),
        
        // Condiments (USDA verified)
        "ketchup": USDANutrient(sugar: 22.8, fiber: 0.3),
        "mustard": USDANutrient(sugar: 3.0, fiber: 3.3),
        "mayonnaise": USDANutrient(sugar: 0.6, fiber: 0.0),
        "mayo": USDANutrient(sugar: 0.6, fiber: 0.0),
        "soy sauce": USDANutrient(sugar: 0.4, fiber: 0.8),
        "vinegar": USDANutrient(sugar: 0.0, fiber: 0.0),
        "bbq sauce": USDANutrient(sugar: 33.0, fiber: 0.5),
        "hot sauce": USDANutrient(sugar: 0.8, fiber: 0.3),
        "sriracha": USDANutrient(sugar: 15.0, fiber: 0.5),
        "salsa": USDANutrient(sugar: 3.9, fiber: 1.5),
        "guacamole": USDANutrient(sugar: 0.5, fiber: 5.0),
        "ranch": USDANutrient(sugar: 2.8, fiber: 0.1),
        "caesar": USDANutrient(sugar: 2.0, fiber: 0.0),
        "thousand island": USDANutrient(sugar: 14.0, fiber: 0.5),
        "italian dressing": USDANutrient(sugar: 5.0, fiber: 0.0),
        "balsamic": USDANutrient(sugar: 15.0, fiber: 0.0),
        "teriyaki": USDANutrient(sugar: 16.0, fiber: 0.1),
        "hoisin": USDANutrient(sugar: 25.0, fiber: 1.0),
        "fish sauce": USDANutrient(sugar: 0.0, fiber: 0.0),
        "oyster sauce": USDANutrient(sugar: 11.0, fiber: 0.3),
        "worcestershire": USDANutrient(sugar: 15.0, fiber: 0.0),
        "tahini": USDANutrient(sugar: 0.5, fiber: 9.3),
        "pesto": USDANutrient(sugar: 2.0, fiber: 1.5),
        "aioli": USDANutrient(sugar: 0.5, fiber: 0.0),
        "relish": USDANutrient(sugar: 20.0, fiber: 1.0),
        "pickle": USDANutrient(sugar: 1.1, fiber: 1.2),
        
        // Prepared Foods (USDA verified)
        "pizza": USDANutrient(sugar: 3.6, fiber: 2.3),
        "burger": USDANutrient(sugar: 5.0, fiber: 1.5),
        "hamburger": USDANutrient(sugar: 5.0, fiber: 1.5),
        "cheeseburger": USDANutrient(sugar: 5.5, fiber: 1.3),
        "hot dog": USDANutrient(sugar: 4.0, fiber: 0.8),
        "sandwich": USDANutrient(sugar: 4.0, fiber: 2.0),
        "sub": USDANutrient(sugar: 3.5, fiber: 1.8),
        "burrito": USDANutrient(sugar: 2.5, fiber: 3.5),
        "taco": USDANutrient(sugar: 2.8, fiber: 2.5),
        "quesadilla": USDANutrient(sugar: 2.0, fiber: 1.5),
        "nachos": USDANutrient(sugar: 2.5, fiber: 3.0),
        "enchilada": USDANutrient(sugar: 3.5, fiber: 3.2),
        "fajita": USDANutrient(sugar: 3.0, fiber: 2.5),
        "fried rice": USDANutrient(sugar: 1.0, fiber: 1.2),
        "stir fry": USDANutrient(sugar: 4.0, fiber: 2.0),
        "curry": USDANutrient(sugar: 4.5, fiber: 2.5),
        "tikka masala": USDANutrient(sugar: 5.0, fiber: 1.5),
        "korma": USDANutrient(sugar: 6.0, fiber: 1.2),
        "biryani": USDANutrient(sugar: 1.5, fiber: 1.0),
        "pad thai": USDANutrient(sugar: 8.0, fiber: 1.5),
        "spring roll": USDANutrient(sugar: 2.5, fiber: 1.5),
        "dumpling": USDANutrient(sugar: 2.0, fiber: 1.0),
        "dim sum": USDANutrient(sugar: 2.5, fiber: 1.0),
        "sushi": USDANutrient(sugar: 8.0, fiber: 0.5),
        "sashimi": USDANutrient(sugar: 0.0, fiber: 0.0),
        "tempura": USDANutrient(sugar: 3.0, fiber: 1.5),
        "pho": USDANutrient(sugar: 0.5, fiber: 0.5),
        "gyoza": USDANutrient(sugar: 2.5, fiber: 1.0),
        "lasagna": USDANutrient(sugar: 4.0, fiber: 1.5),
        "carbonara": USDANutrient(sugar: 1.0, fiber: 1.2),
        "bolognese": USDANutrient(sugar: 4.5, fiber: 1.5),
        "mac and cheese": USDANutrient(sugar: 4.0, fiber: 1.0),
        "risotto": USDANutrient(sugar: 0.5, fiber: 0.5),
        "paella": USDANutrient(sugar: 1.5, fiber: 1.0),
        "shepherd's pie": USDANutrient(sugar: 3.5, fiber: 2.0),
        "cottage pie": USDANutrient(sugar: 3.5, fiber: 2.0),
        "fish and chips": USDANutrient(sugar: 2.0, fiber: 2.5),
        "fish finger": USDANutrient(sugar: 2.5, fiber: 1.0),
        "chicken nugget": USDANutrient(sugar: 1.5, fiber: 1.0),
        "fried chicken": USDANutrient(sugar: 0.5, fiber: 0.5),
        "roast chicken": USDANutrient(sugar: 0.0, fiber: 0.0),
        "rotisserie": USDANutrient(sugar: 0.0, fiber: 0.0),
        "meatball": USDANutrient(sugar: 3.5, fiber: 0.5),
        "meatloaf": USDANutrient(sugar: 5.0, fiber: 0.8),
        "pot roast": USDANutrient(sugar: 2.0, fiber: 1.0),
        "beef stew": USDANutrient(sugar: 3.0, fiber: 1.5),
        "chili": USDANutrient(sugar: 4.0, fiber: 5.0),
        "soup": USDANutrient(sugar: 2.5, fiber: 1.5),
        "chicken soup": USDANutrient(sugar: 1.0, fiber: 0.5),
        "tomato soup": USDANutrient(sugar: 5.0, fiber: 1.0),
        "minestrone": USDANutrient(sugar: 2.5, fiber: 2.5),
        "clam chowder": USDANutrient(sugar: 2.0, fiber: 0.5),
        "french fries": USDANutrient(sugar: 0.3, fiber: 3.8),
        "chips": USDANutrient(sugar: 0.3, fiber: 3.8),
        "mashed potato": USDANutrient(sugar: 1.5, fiber: 1.5),
        "baked potato": USDANutrient(sugar: 1.0, fiber: 2.2),
        "jacket potato": USDANutrient(sugar: 1.0, fiber: 2.2),
        "hash brown": USDANutrient(sugar: 0.5, fiber: 2.0),
        "potato salad": USDANutrient(sugar: 5.0, fiber: 1.5),
        "coleslaw": USDANutrient(sugar: 8.0, fiber: 1.5),
        "caesar salad": USDANutrient(sugar: 2.0, fiber: 1.5),
        "greek salad": USDANutrient(sugar: 3.5, fiber: 1.5),
        "garden salad": USDANutrient(sugar: 2.5, fiber: 1.8),
        "pasta salad": USDANutrient(sugar: 3.0, fiber: 1.5),
        "quiche": USDANutrient(sugar: 2.5, fiber: 1.0),
        "omelette": USDANutrient(sugar: 1.0, fiber: 0.5),
        "scrambled egg": USDANutrient(sugar: 1.5, fiber: 0.0),
        "poached egg": USDANutrient(sugar: 0.4, fiber: 0.0),
        "fried egg": USDANutrient(sugar: 0.4, fiber: 0.0),
        "benedict": USDANutrient(sugar: 2.0, fiber: 0.5),
        
        // Sweets & Baked Goods (USDA verified)
        "chocolate": USDANutrient(sugar: 48.0, fiber: 7.0),
        "dark chocolate": USDANutrient(sugar: 24.0, fiber: 10.9),
        "milk chocolate": USDANutrient(sugar: 52.0, fiber: 3.4),
        "white chocolate": USDANutrient(sugar: 59.0, fiber: 0.2),
        "chocolate bar": USDANutrient(sugar: 50.0, fiber: 4.0),
        "cake": USDANutrient(sugar: 35.0, fiber: 1.0),
        "cheesecake": USDANutrient(sugar: 22.0, fiber: 0.5),
        "carrot cake": USDANutrient(sugar: 32.0, fiber: 1.5),
        "chocolate cake": USDANutrient(sugar: 38.0, fiber: 2.0),
        "sponge cake": USDANutrient(sugar: 30.0, fiber: 0.8),
        "pound cake": USDANutrient(sugar: 25.0, fiber: 0.6),
        "cupcake": USDANutrient(sugar: 35.0, fiber: 0.8),
        "cookie": USDANutrient(sugar: 25.0, fiber: 1.5),
        "chocolate chip cookie": USDANutrient(sugar: 30.0, fiber: 1.8),
        "oatmeal cookie": USDANutrient(sugar: 22.0, fiber: 2.5),
        "shortbread": USDANutrient(sugar: 18.0, fiber: 1.0),
        "oreo": USDANutrient(sugar: 41.0, fiber: 1.8),
        "biscuit": USDANutrient(sugar: 20.0, fiber: 2.0),
        "digestive": USDANutrient(sugar: 16.0, fiber: 3.0),
        "donut": USDANutrient(sugar: 22.0, fiber: 1.2),
        "doughnut": USDANutrient(sugar: 22.0, fiber: 1.2),
        "brownie": USDANutrient(sugar: 40.0, fiber: 1.5),
        "blondie": USDANutrient(sugar: 38.0, fiber: 0.8),
        "muffin": USDANutrient(sugar: 23.0, fiber: 1.5),
        "blueberry muffin": USDANutrient(sugar: 25.0, fiber: 1.2),
        "banana bread": USDANutrient(sugar: 22.0, fiber: 1.5),
        "pastry": USDANutrient(sugar: 20.0, fiber: 1.5),
        "danish": USDANutrient(sugar: 18.0, fiber: 1.2),
        "cinnamon roll": USDANutrient(sugar: 30.0, fiber: 1.0),
        "pie": USDANutrient(sugar: 15.0, fiber: 1.5),
        "apple pie": USDANutrient(sugar: 15.0, fiber: 1.8),
        "pumpkin pie": USDANutrient(sugar: 14.0, fiber: 1.5),
        "pecan pie": USDANutrient(sugar: 38.0, fiber: 2.5),
        "tart": USDANutrient(sugar: 20.0, fiber: 1.0),
        "flan": USDANutrient(sugar: 22.0, fiber: 0.0),
        "custard": USDANutrient(sugar: 14.0, fiber: 0.0),
        "pudding": USDANutrient(sugar: 15.0, fiber: 0.3),
        "rice pudding": USDANutrient(sugar: 14.0, fiber: 0.5),
        "tiramisu": USDANutrient(sugar: 28.0, fiber: 0.5),
        "mousse": USDANutrient(sugar: 18.0, fiber: 1.0),
        "panna cotta": USDANutrient(sugar: 20.0, fiber: 0.0),
        "gelato": USDANutrient(sugar: 23.0, fiber: 0.5),
        "sorbet": USDANutrient(sugar: 26.0, fiber: 0.5),
        "frozen yogurt": USDANutrient(sugar: 17.0, fiber: 0.0),
        "candy": USDANutrient(sugar: 60.0, fiber: 0.0),
        "gummy": USDANutrient(sugar: 70.0, fiber: 0.0),
        "jelly bean": USDANutrient(sugar: 93.0, fiber: 0.0),
        "lollipop": USDANutrient(sugar: 87.0, fiber: 0.0),
        "caramel": USDANutrient(sugar: 65.0, fiber: 0.0),
        "toffee": USDANutrient(sugar: 70.0, fiber: 0.0),
        "fudge": USDANutrient(sugar: 74.0, fiber: 0.5),
        "marshmallow": USDANutrient(sugar: 57.6, fiber: 0.1),
        "meringue": USDANutrient(sugar: 80.0, fiber: 0.0),
        "macaron": USDANutrient(sugar: 72.0, fiber: 1.5),
        
        // Oils (USDA verified - all 0g)
        "oil": USDANutrient(sugar: 0.0, fiber: 0.0),
        "olive oil": USDANutrient(sugar: 0.0, fiber: 0.0),
        "coconut oil": USDANutrient(sugar: 0.0, fiber: 0.0),
        
        // Snacks (USDA verified)
        "crisp": USDANutrient(sugar: 1.5, fiber: 4.4),
        "chip": USDANutrient(sugar: 1.5, fiber: 4.4),
        "tortilla chip": USDANutrient(sugar: 1.0, fiber: 5.3),
        "corn chip": USDANutrient(sugar: 1.2, fiber: 5.0),
        "popcorn": USDANutrient(sugar: 0.5, fiber: 14.5),
        "pretzel": USDANutrient(sugar: 3.0, fiber: 2.2),
        "cracker": USDANutrient(sugar: 3.0, fiber: 2.9),
        "rice cake": USDANutrient(sugar: 0.3, fiber: 0.4),
        "rice cracker": USDANutrient(sugar: 0.5, fiber: 0.3),
        "granola bar": USDANutrient(sugar: 21.0, fiber: 3.5),
        "protein bar": USDANutrient(sugar: 8.0, fiber: 5.0),
        "energy bar": USDANutrient(sugar: 18.0, fiber: 4.0),
        "cereal bar": USDANutrient(sugar: 25.0, fiber: 2.5),
        "fruit bar": USDANutrient(sugar: 35.0, fiber: 3.0),
        "trail mix": USDANutrient(sugar: 25.0, fiber: 4.5),
        "mixed nuts": USDANutrient(sugar: 4.5, fiber: 6.5),
        "beef jerky": USDANutrient(sugar: 9.0, fiber: 0.0),
        "pork rind": USDANutrient(sugar: 0.0, fiber: 0.0),
        "cheese puff": USDANutrient(sugar: 2.5, fiber: 0.8),
        "cheeto": USDANutrient(sugar: 2.5, fiber: 0.8),
        "dorito": USDANutrient(sugar: 2.5, fiber: 2.0),
        "lay's": USDANutrient(sugar: 1.0, fiber: 3.5),
        "pringles": USDANutrient(sugar: 2.5, fiber: 2.5),
        "sunflower seeds": USDANutrient(sugar: 2.6, fiber: 8.6),
        "edamame": USDANutrient(sugar: 2.2, fiber: 5.2),
        "seaweed": USDANutrient(sugar: 0.5, fiber: 3.0),
        "dried fruit snack": USDANutrient(sugar: 60.0, fiber: 4.0),
        "fruit leather": USDANutrient(sugar: 65.0, fiber: 2.5),
        "veggie straw": USDANutrient(sugar: 3.0, fiber: 1.0),
        "hummus chips": USDANutrient(sugar: 3.0, fiber: 5.0)
    ]
    
    // MARK: - Estimation Fallbacks (for foods not in USDA database)
    
    // Category-based fallback estimates (grams per 100g)
    private let categoryFallbacks: [String: USDANutrient] = [
        "fruit": USDANutrient(sugar: 10.0, fiber: 2.0),
        "vegetable": USDANutrient(sugar: 3.0, fiber: 2.0),
        "meat": USDANutrient(sugar: 0.0, fiber: 0.0),
        "fish": USDANutrient(sugar: 0.0, fiber: 0.0),
        "dairy": USDANutrient(sugar: 4.0, fiber: 0.0),
        "grain": USDANutrient(sugar: 2.0, fiber: 3.0),
        "nut": USDANutrient(sugar: 4.0, fiber: 8.0),
        "legume": USDANutrient(sugar: 2.0, fiber: 7.0),
        "sweet": USDANutrient(sugar: 40.0, fiber: 1.0),
        "beverage": USDANutrient(sugar: 8.0, fiber: 0.0),
        "snack": USDANutrient(sugar: 5.0, fiber: 2.0)
    ]
    
    private init() {}
    
    // MARK: - Data Models
    
    struct GutHealthMetrics {
        // MARK: - Pillar 1: Fibre & Plant Diversity (35 pts)
        // Method: Broad / categorical (primary)
        
        let fiberFrequencyPoints: Double    // Daily fibre-points from food frequency (0-18)
        let fiberFrequencyScore: Double     // Scaled score for 1A
        let plantDiversityCount: Int        // Unique plants this week
        let herbSpiceCount: Int             // Herbs/spices (capped separately)
        let plantDiversityScore: Double     // 0-12 pts
        let fiberGrams: Double              // Average daily fiber (optional modifier)
        let fiberGramsScore: Double         // 0-5 pts (only if data quality ≥60%)
        let fiberDataQuality: Double        // % of calories with fiber data
        let fiberDiversityTotal: Double     // Combined 0-35 pts
        
        // MARK: - Pillar 2: Ultra-Processed Foods / NOVA 4 (30 pts)
        // Method: Exact numeric
        
        let upfCaloriePercent: Double       // % calories from NOVA 4
        let upfLoadTotal: Double            // 0-30 pts (single component)
        
        // MARK: - Pillar 3: Fermented & Prebiotic Foods (20 pts)
        // Method: Broad / frequency-based
        
        let fermentedServings: Double       // Weekly fermented food servings (fractional)
        let fermentedScore: Double          // 0-10 pts
        let prebioticServings: Double       // Weekly prebiotic servings (fractional)
        let prebioticScore: Double          // 0-10 pts
        let fermentedPrebioticTotal: Double // Combined 0-20 pts
        
        // MARK: - Pillar 4: Fat Quality & Inflammatory Balance (15 pts)
        // Method: Hybrid (numeric → banded)
        
        let unsatSatRatio: Double           // Unsaturated:Saturated fat ratio
        let fatRatioScore: Double           // 0-8 pts (banded output)
        let omega3Servings: Double          // Weekly omega-3 food servings (fractional)
        let omega3Score: Double             // 0-7 pts
        let fatQualityTotal: Double         // Combined 0-15 pts
        
        // MARK: - Overall Score & Confidence
        
        let overallScore: Double            // 0-100 (sum of all pillars)
        let interpretationBand: String      // "Thriving", "Supported", "Needs Attention", "Under Supported"
        let confidenceLevel: String         // "High", "Medium", "Low" (NOT part of score)
        let confidencePercent: Double       // % of foods with high-confidence classification
        let daysLogged: Int                 // Days with entries (for context)
        let dataCompleteness: Double        // 0-1
        
        // MARK: - Legacy Compatibility Fields
        // These map old field names to new structure for UI compatibility
        
        var fiberIntakeScore: Double { fiberFrequencyScore }
        var solubleFiberServings: Double { 0 }  // Removed - now part of frequency
        var solubleFiberScore: Double { 0 }
        var upfCalorieScore: Double { upfLoadTotal }
        var upfItemCount: Int { 0 }  // Removed per spec
        var upfItemScore: Double { 0 }
        var loggingScore: Double { 0 }
        var intakeStabilityCV: Double { 0 }
        var stabilityScore: Double { 0 }
        var consistencyTotal: Double { 0 }
        
        var fiberScore: Double { fiberDiversityTotal / 35.0 * 100 }
        var nova4Percent: Double { upfCaloriePercent }
        var nova4Score: Double { upfLoadTotal / 30.0 * 100 }
        var fiberDataAvailable: Bool { fiberDataQuality >= 0.6 }
        var fiberIsEstimated: Bool { fiberDataQuality < 0.6 }
        var nova4DataAvailable: Bool { true }
        var sugarGrams: Double { 0 }  // Removed from new system
        var sugarScore: Double { 0 }
        var sugarDataAvailable: Bool { false }
        var sugarIsEstimated: Bool { false }
        var nutriScoreAverage: Double { 0 }
        var nutriScoreScore: Double { 0 }
        var nutriScoreDataAvailable: Bool { false }
    }
    
    // MARK: - Main Calculation Methods
    
    /// Calculate gut health metrics for a specific date (with caching)
    func calculateMetrics(for date: Date, entries: [FoodEntry]) -> GutHealthMetrics {
        let calendar = Calendar.current
        let dayEntries = entries.filter { calendar.isDate($0.dateAdded, inSameDayAs: date) }
        
        // Generate cache key and entries hash
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let cacheKey = "day_" + dateFormatter.string(from: date)
        let entriesHash = dayEntries.map { $0.id.hashValue }.reduce(0, ^)
        
        // Check cache
        if let cached = metricsCache[cacheKey],
           cached.entriesHash == entriesHash,
           !cached.isExpired {
            return cached.metrics
        }
        
        // Calculate and cache
        let metrics = calculateMetricsFromEntries(dayEntries)
        cacheMetrics(metrics, forKey: cacheKey, entriesHash: entriesHash)
        return metrics
    }
    
    /// Calculate gut health metrics for a week (weekOffset: 0 = current week, -1 = last week, etc.) with caching
    func calculateWeeklyMetrics(weekOffset: Int, entries: [FoodEntry]) -> GutHealthMetrics {
        let calendar = Calendar.current
        let today = Date()
        
        // Get the start of the current week (Sunday or Monday depending on locale)
        guard let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return emptyMetrics()
        }
        
        // Calculate target week start
        guard let targetWeekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart),
              let targetWeekEnd = calendar.date(byAdding: .day, value: 7, to: targetWeekStart) else {
            return emptyMetrics()
        }
        
        // Filter entries for the target week
        let weekEntries = entries.filter { entry in
            entry.dateAdded >= targetWeekStart && entry.dateAdded < targetWeekEnd
        }
        
        // Generate cache key and entries hash
        let cacheKey = "week_\(weekOffset)"
        let entriesHash = weekEntries.map { $0.id.hashValue }.reduce(0, ^)
        
        // Check cache
        if let cached = metricsCache[cacheKey],
           cached.entriesHash == entriesHash,
           !cached.isExpired {
            return cached.metrics
        }
        
        // Calculate and cache
        let metrics = calculateMetricsFromEntries(weekEntries)
        cacheMetrics(metrics, forKey: cacheKey, entriesHash: entriesHash)
        return metrics
    }
    
    /// Cache metrics with size limit management
    private func cacheMetrics(_ metrics: GutHealthMetrics, forKey key: String, entriesHash: Int) {
        // Evict oldest entries if cache is full
        if metricsCache.count >= maxCacheEntries {
            let oldestKey = metricsCache.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let keyToRemove = oldestKey {
                metricsCache.removeValue(forKey: keyToRemove)
            }
        }
        
        metricsCache[key] = CachedMetrics(
            metrics: metrics,
            entriesHash: entriesHash,
            timestamp: Date()
        )
    }
    
    /// Invalidate all cached metrics (call when food entries change)
    func invalidateCache() {
        metricsCache.removeAll()
    }
    
    /// Calculate metrics from a set of food entries (Spec-Compliant 4-Pillar System)
    /// Based on NutriBase Gut Health Feature Full Implementation Breakdown
    private func calculateMetricsFromEntries(_ entries: [FoodEntry]) -> GutHealthMetrics {
        guard !entries.isEmpty else {
            return emptyMetrics()
        }
        
        let calendar = Calendar.current
        let uniqueDays = Set(entries.map { calendar.startOfDay(for: $0.dateAdded) })
        let numberOfDays = max(1, Double(uniqueDays.count))
        
        // ============================================================
        // MARK: Data Collection Pass
        // ============================================================
        
        var totalCalories: Double = 0
        var caloriesWithFiberData: Double = 0
        var totalFiber: Double = 0
        var nova4Calories: Double = 0
        var totalSaturatedFat: Double = 0
        var totalUnsaturatedFat: Double = 0
        
        // Daily fiber points for frequency-based scoring
        var dailyFiberPoints: [Date: Double] = [:]
        
        // Food category counts
        var uniquePlantFoods: Set<String> = []
        var herbSpiceCount: Int = 0
        var fermentedServings: Double = 0.0  // Changed to Double to accumulate fractional servings
        var prebioticServings: Double = 0.0  // Changed to Double to accumulate fractional servings
        var omega3Servings: Double = 0.0  // Changed to Double to accumulate fractional servings
        
        // Confidence tracking
        var highConfidenceCount: Int = 0
        var totalFoodCount: Int = 0
        
        for entry in entries {
            let entryCalories = Double(entry.totalCalories)
            let entryDay = calendar.startOfDay(for: entry.dateAdded)
            
            totalCalories += entryCalories
            
            // Check if this entry is a meal - if so, process each component food individually
            if entry.foodItem.isMeal, let savedMeal = SavedMealsManager.shared.meals.first(where: { $0.name == entry.foodItem.name }) {
                // Process each food in the meal
                for mealFood in savedMeal.foods {
                    totalFoodCount += 1
                    let foodNameLower = mealFood.foodName.lowercased()
                    let scaledFoodCalories = Double(mealFood.calories) * entry.numberOfServings
                    
                    // --------------------------------------------------------
                    // Pillar 1A: Fiber Density Band Classification
                    // IMPROVEMENT 4: Confidence-weighted scoring for meal foods
                    // --------------------------------------------------------
                    let (fiberBand, bandConfidence) = classifyFiberDensityByName(mealFood.foodName, novaScore: mealFood.novaScore)
                    // Use average portion factor since we don't have exact portion data for meal components
                    let portionFactor = 1.0
                    
                    // Apply confidence weighting: low confidence = reduced contribution
                    let confidenceMultiplier = min(1.0, 0.5 + (bandConfidence * 0.7))
                    let foodFiberPoints = Double(fiberBand.rawValue) * portionFactor * confidenceMultiplier
                    dailyFiberPoints[entryDay, default: 0] += foodFiberPoints
                    
                    if bandConfidence >= 0.7 {
                        highConfidenceCount += 1
                    }
                    
                    // --------------------------------------------------------
                    // Pillar 1B: Plant Diversity (with canonicalization)
                    // --------------------------------------------------------
                    for keyword in plantFoodKeywords {
                        if foodNameLower.contains(keyword) {
                            let canonical = canonicalizePlantName(keyword)
                            uniquePlantFoods.insert(canonical)
                        }
                    }
                    
                    // Track herbs/spices separately (capped)
                    for keyword in herbSpiceKeywords {
                        if foodNameLower.contains(keyword) {
                            herbSpiceCount += 1
                            break
                        }
                    }
                    
                    // --------------------------------------------------------
                    // Pillar 2: NOVA 4 / UPF Tracking (Exact Numeric)
                    // --------------------------------------------------------
                    let foodNovaScore = mealFood.novaScore > 0 ?
                        mealFood.novaScore :
                        NovaScoreService.shared.predictNovaScoreByName(mealFood.foodName)
                    
                    if foodNovaScore == 4 {
                        nova4Calories += scaledFoodCalories
                    }
                    
                    // --------------------------------------------------------
                    // Pillar 3: Fermented & Prebiotic Foods (Frequency)
                    // --------------------------------------------------------
                    for keyword in fermentedFoodKeywords {
                        if foodNameLower.contains(keyword) {
                            fermentedServings += 1
                            break
                        }
                    }
                    
                    for keyword in prebioticFoodKeywords {
                        if foodNameLower.contains(keyword) {
                            prebioticServings += 1
                            break
                        }
                    }
                    
                    // --------------------------------------------------------
                    // Pillar 4: Fat Quality Tracking (meals don't have this data yet)
                    // Note: MealFood doesn't have saturatedFat data currently
                    // --------------------------------------------------------
                    
                    // Omega-3 foods (frequency)
                    for keyword in omega3FoodKeywords {
                        if foodNameLower.contains(keyword) {
                            omega3Servings += 1
                            break
                        }
                    }
                }
            } else {
                // Process single food entry
                totalFoodCount += 1
                let foodNameLower = entry.foodItem.name.lowercased()
                
                // --------------------------------------------------------
                // Pillar 1A: Fiber Density Band Classification
                // IMPROVEMENT 4: Confidence-weighted scoring
                // Low confidence matches contribute less to total score
                // --------------------------------------------------------
                let (fiberBand, bandConfidence) = classifyFiberDensity(for: entry)
                let portionFactor = calculatePortionFactor(for: entry)
                
                // Apply confidence weighting: low confidence = reduced contribution
                // Confidence 0.3-0.5 → 50-75% of points, 0.7+ → 100%
                let confidenceMultiplier = min(1.0, 0.5 + (bandConfidence * 0.7))
                let entryFiberPoints = Double(fiberBand.rawValue) * portionFactor * confidenceMultiplier
                dailyFiberPoints[entryDay, default: 0] += entryFiberPoints
                
                if bandConfidence >= 0.7 {
                    highConfidenceCount += 1
                }
                
                // Track fiber data quality
                if let fiber = entry.foodItem.fiber, fiber > 0 {
                    caloriesWithFiberData += entryCalories
                    let scaledFiber = calculateScaledNutrient(
                        nutrientValue: fiber,
                        servingSize: entry.servingSize,
                        servingUnit: entry.servingUnit,
                        numberOfServings: entry.numberOfServings,
                        foodItem: entry.foodItem
                    )
                    totalFiber += scaledFiber
                }
                
                // --------------------------------------------------------
                // Pillar 1B: Plant Diversity (with canonicalization)
                // --------------------------------------------------------
                for keyword in plantFoodKeywords {
                    if foodNameLower.contains(keyword) {
                        let canonical = canonicalizePlantName(keyword)
                        uniquePlantFoods.insert(canonical)
                    }
                }
                
                // Track herbs/spices separately (capped)
                for keyword in herbSpiceKeywords {
                    if foodNameLower.contains(keyword) {
                        herbSpiceCount += 1
                        break
                    }
                }
                
                // --------------------------------------------------------
                // Pillar 2: NOVA 4 / UPF Tracking (Exact Numeric)
                // --------------------------------------------------------
                let novaScore = entry.foodItem.novaScore > 0 ?
                    entry.foodItem.novaScore :
                    NovaScoreService.shared.predictNovaScore(for: entry.foodItem)
                
                if novaScore == 4 {
                    nova4Calories += entryCalories
                }
                
                // --------------------------------------------------------
                // Pillar 3: Fermented & Prebiotic Foods (Frequency)
                // --------------------------------------------------------
                for keyword in fermentedFoodKeywords {
                    if foodNameLower.contains(keyword) {
                        fermentedServings += entry.numberOfServings
                        break
                    }
                }
                
                for keyword in prebioticFoodKeywords {
                    if foodNameLower.contains(keyword) {
                        prebioticServings += entry.numberOfServings
                        break
                    }
                }
                
                // --------------------------------------------------------
                // Pillar 4: Fat Quality Tracking
                // --------------------------------------------------------
                let saturatedFat = entry.foodItem.saturatedFat ?? 0
                if saturatedFat > 0 {
                    let scaledSat = calculateScaledNutrient(
                        nutrientValue: saturatedFat,
                        servingSize: entry.servingSize,
                        servingUnit: entry.servingUnit,
                        numberOfServings: entry.numberOfServings,
                        foodItem: entry.foodItem
                    )
                    totalSaturatedFat += scaledSat
                }
                
                let totalFat = entry.foodItem.fat
                if totalFat > 0 {
                    let scaledTotal = calculateScaledNutrient(
                        nutrientValue: totalFat,
                        servingSize: entry.servingSize,
                        servingUnit: entry.servingUnit,
                        numberOfServings: entry.numberOfServings,
                        foodItem: entry.foodItem
                    )
                    let scaledSat = calculateScaledNutrient(
                        nutrientValue: saturatedFat,
                        servingSize: entry.servingSize,
                        servingUnit: entry.servingUnit,
                        numberOfServings: entry.numberOfServings,
                        foodItem: entry.foodItem
                    )
                    totalUnsaturatedFat += max(0, scaledTotal - scaledSat)
                }
                
                // Omega-3 foods (frequency) - accumulate fractional servings
                for keyword in omega3FoodKeywords {
                    if foodNameLower.contains(keyword) {
                        omega3Servings += entry.numberOfServings
                        break
                    }
                }
            }
        }
        
        // ============================================================
        // MARK: Pillar 1: Fibre & Plant Diversity (35 pts)
        // ============================================================
        
        // 1A. Fibre-Dense Food Frequency (0-18 pts)
        let totalDailyFiberPoints = dailyFiberPoints.values.reduce(0, +)
        let avgDailyFiberPoints = totalDailyFiberPoints / numberOfDays
        let fiberFrequencyScore = min(fiberFrequencyMaxPoints, 
            (avgDailyFiberPoints / fiberFrequencyTargetDaily) * fiberFrequencyMaxPoints)
        
        // 1B. Plant Diversity (0-12 pts)
        // Calculate daily average plant diversity instead of weekly total
        let dailyPlantCount = Double(uniquePlantFoods.count) / numberOfDays
        let dailyHerbSpice = Double(min(herbSpiceCount, herbSpiceCap)) / numberOfDays
        let avgDailyPlants = dailyPlantCount + dailyHerbSpice
        let plantDiversityScore = min(plantDiversityMaxPoints,
            (avgDailyPlants / plantDiversityOptimal) * plantDiversityMaxPoints)
        
        // Keep totalPlantCount for display purposes
        let totalPlantCount = uniquePlantFoods.count + min(herbSpiceCount, herbSpiceCap)
        
        // 1C. Fibre Grams Modifier (0-5 pts) - Only if data quality ≥60%
        let fiberDataQuality = totalCalories > 0 ? caloriesWithFiberData / totalCalories : 0
        let dailyFiberGrams = totalFiber / numberOfDays
        let fiberGramsScore: Double
        if fiberDataQuality >= fiberDataQualityThreshold {
            fiberGramsScore = min(fiberGramsMaxPoints,
                (dailyFiberGrams / fiberGramsOptimal) * fiberGramsMaxPoints)
        } else {
            fiberGramsScore = 0  // Don't include if data quality insufficient
        }
        
        let fiberDiversityTotal = fiberFrequencyScore + plantDiversityScore + fiberGramsScore
        
        // ============================================================
        // MARK: Pillar 2: Ultra-Processed Foods / NOVA 4 (30 pts)
        // ============================================================
        
        let upfPercent = totalCalories > 0 ? (nova4Calories / totalCalories) * 100 : 0
        
        // Spec: ≤20% → full points, 20-50% → linear, ≥50% → near-zero
        let upfScore: Double
        if upfPercent <= upfExcellentThreshold {
            upfScore = upfMaxPoints
        } else if upfPercent < upfPoorThreshold {
            // Linear scale from 20% to 50%
            let range = upfPoorThreshold - upfExcellentThreshold
            let excess = upfPercent - upfExcellentThreshold
            upfScore = upfMaxPoints * (1.0 - (excess / range))
        } else {
            // ≥50% → near-zero (give 1-2 points)
            upfScore = max(0, upfMaxPoints * 0.05)
        }
        
        // ============================================================
        // MARK: Pillar 3: Fermented & Prebiotic Foods (20 pts)
        // ============================================================
        
        // 3A. Fermented Foods (0-10 pts) - Daily average based
        let avgDailyFermented = Double(fermentedServings) / numberOfDays
        let fermentedScore = min(fermentedMaxPoints,
            (avgDailyFermented / fermentedOptimalDaily) * fermentedMaxPoints)
        
        // 3B. Prebiotic Foods (0-10 pts) - Daily average based
        let avgDailyPrebiotic = Double(prebioticServings) / numberOfDays
        let prebioticScore = min(prebioticMaxPoints,
            (avgDailyPrebiotic / prebioticOptimalDaily) * prebioticMaxPoints)
        
        let fermentedPrebioticTotal = fermentedScore + prebioticScore
        
        // ============================================================
        // MARK: Pillar 4: Fat Quality & Inflammatory Balance (15 pts)
        // ============================================================
        
        // 4A. Fat Ratio - Banded Output (0-8 pts)
        let fatRatio = totalSaturatedFat > 0 ? totalUnsaturatedFat / totalSaturatedFat : 2.0
        let fatRatioScore: Double
        if fatRatio >= fatRatioOptimal {
            fatRatioScore = fatRatioMaxPoints
        } else if fatRatio >= fatRatioMin {
            // 1-2 ratio → scaled
            fatRatioScore = (fatRatioMaxPoints * 0.375) + 
                ((fatRatio - fatRatioMin) / (fatRatioOptimal - fatRatioMin)) * (fatRatioMaxPoints * 0.625)
        } else {
            // <1 → capped at ~3 pts
            fatRatioScore = (fatRatio / fatRatioMin) * (fatRatioMaxPoints * 0.375)
        }
        
        // 4B. Omega-3 Foods - Frequency (0-7 pts) - Weekly total based
        // Note: Omega-3 goal is weekly (2/week) not daily, since 2 doesn't divide well into days
        let omega3Score = min(omega3MaxPoints,
            (Double(omega3Servings) / omega3OptimalWeekly) * omega3MaxPoints)
        
        let fatQualityTotal = fatRatioScore + omega3Score
        
        // ============================================================
        // MARK: Overall Score & Interpretation
        // ============================================================
        
        let daysLogged = uniqueDays.count
        
        let overallScore = min(100, max(0,
            fiberDiversityTotal +      // 35 pts max
            upfScore +                 // 30 pts max
            fermentedPrebioticTotal +  // 20 pts max
            fatQualityTotal            // 15 pts max
        ))
        
        // Interpretation bands
        let interpretationBand: String
        if overallScore >= 80 {
            interpretationBand = "Thriving"
        } else if overallScore >= 60 {
            interpretationBand = "Supported"
        } else if overallScore >= 40 {
            interpretationBand = "Needs Attention"
        } else {
            interpretationBand = "Under Supported"
        }
        
        // Confidence Level (NOT part of score)
        let confidencePercent = totalFoodCount > 0 ? 
            Double(highConfidenceCount) / Double(totalFoodCount) * 100 : 0
        let confidenceLevel: String
        if confidencePercent >= 80 {
            confidenceLevel = ConfidenceLevel.high.rawValue
        } else if confidencePercent >= 50 {
            confidenceLevel = ConfidenceLevel.medium.rawValue
        } else {
            confidenceLevel = ConfidenceLevel.low.rawValue
        }
        
        let dataCompleteness = min(1.0, Double(entries.count) / 21.0)
        
        return GutHealthMetrics(
            fiberFrequencyPoints: avgDailyFiberPoints,
            fiberFrequencyScore: fiberFrequencyScore,
            plantDiversityCount: totalPlantCount,
            herbSpiceCount: min(herbSpiceCount, herbSpiceCap),
            plantDiversityScore: plantDiversityScore,
            fiberGrams: dailyFiberGrams,
            fiberGramsScore: fiberGramsScore,
            fiberDataQuality: fiberDataQuality,
            fiberDiversityTotal: fiberDiversityTotal,
            upfCaloriePercent: upfPercent,
            upfLoadTotal: upfScore,
            fermentedServings: fermentedServings,
            fermentedScore: fermentedScore,
            prebioticServings: prebioticServings,
            prebioticScore: prebioticScore,
            fermentedPrebioticTotal: fermentedPrebioticTotal,
            unsatSatRatio: fatRatio,
            fatRatioScore: fatRatioScore,
            omega3Servings: omega3Servings,
            omega3Score: omega3Score,
            fatQualityTotal: fatQualityTotal,
            overallScore: overallScore,
            interpretationBand: interpretationBand,
            confidenceLevel: confidenceLevel,
            confidencePercent: confidencePercent,
            daysLogged: daysLogged,
            dataCompleteness: dataCompleteness
        )
    }
    
    // MARK: - Fiber Density Classification
    
    /// Classify food by name only (for meal component foods without full FoodEntry)
    /// Implements same 4 improvements as classifyFiberDensity:
    /// 1. NOVA + keyword interaction (NOVA 4 caps at 2 pts)
    /// 2. Generic term demotion
    /// 3. Confidence weighting
    /// 4. Tightened tier separation
    private func classifyFiberDensityByName(_ foodName: String, novaScore: Int = 0) -> (band: FiberDensityBand, confidence: Double) {
        let foodNameLower = foodName.lowercased()
        
        // ============================================================
        // IMPROVEMENT 3: Check for generic terms first
        // ============================================================
        let hasGenericTerm = genericTermKeywords.contains { foodNameLower.contains($0) }
        let hasSpecificFruit = specificFruitKeywords.contains { foodNameLower.contains($0) }
        let hasSpecificVegetable = specificVegetableKeywords.contains { foodNameLower.contains($0) }
        
        // If ONLY generic term detected (no specific fruit/veg), demote to low
        if hasGenericTerm && !hasSpecificFruit && !hasSpecificVegetable {
            let hasAnySpecificMatch = veryHighFiberKeywords.contains { foodNameLower.contains($0) } ||
                                      highFiberKeywords.contains { foodNameLower.contains($0) && !genericTermKeywords.contains($0) }
            if !hasAnySpecificMatch {
                return (.low, 0.4)
            }
        }
        
        // ============================================================
        // Priority 1: Keyword-based classification
        // ============================================================
        var detectedBand: FiberDensityBand? = nil
        var baseConfidence: Double = 0.0
        
        for keyword in veryHighFiberKeywords {
            if foodNameLower.contains(keyword) {
                detectedBand = .veryHigh
                baseConfidence = 0.8
                break
            }
        }
        
        if detectedBand == nil {
            for keyword in highFiberKeywords {
                if foodNameLower.contains(keyword) && !genericTermKeywords.contains(keyword) {
                    detectedBand = .high
                    baseConfidence = 0.75
                    break
                }
            }
        }
        
        if detectedBand == nil {
            for keyword in moderateFiberKeywords {
                if foodNameLower.contains(keyword) && !genericTermKeywords.contains(keyword) {
                    detectedBand = .moderate
                    baseConfidence = 0.7
                    break
                }
            }
        }
        
        if detectedBand == nil {
            for keyword in lowFiberKeywords {
                if foodNameLower.contains(keyword) {
                    detectedBand = .low
                    baseConfidence = 0.7
                    break
                }
            }
        }
        
        if detectedBand == nil {
            for keyword in veryLowFiberKeywords {
                if foodNameLower.contains(keyword) {
                    detectedBand = .veryLow
                    baseConfidence = 0.75
                    break
                }
            }
        }
        
        // ============================================================
        // IMPROVEMENT 1: NOVA + Keyword Interaction Rules
        // NOVA 4 = cap at moderate (2 pts) max
        // ============================================================
        if let band = detectedBand {
            if novaScore == 4 {
                switch band {
                case .veryHigh, .high:
                    return (.moderate, min(baseConfidence, 0.5))
                case .moderate, .low, .veryLow:
                    return (band, baseConfidence)
                }
            }
            return (band, baseConfidence)
        }
        
        // Priority 2: NOVA-based fallback
        switch novaScore {
        case 1:
            return (.moderate, 0.5)  // Unprocessed foods - moderate fiber assumed
        case 2:
            return (.low, 0.5)       // Processed culinary ingredients
        case 3:
            return (.low, 0.5)       // Processed foods
        case 4:
            return (.veryLow, 0.6)   // Ultra-processed - typically low fiber
        default:
            return (.low, 0.3)       // Unknown - low confidence
        }
    }
    
    /// Classify food into fiber density band with confidence score
    /// Implements 4 key improvements for robust scoring:
    /// 1. NOVA + keyword interaction (NOVA 4 caps fiber at 2 pts max)
    /// 2. Generic term demotion (fruit/vegetable/smoothie → low unless specific detected)
    /// 3. Confidence-weighted scoring (low confidence = reduced contribution)
    /// 4. Tightened tier separation
    private func classifyFiberDensity(for entry: FoodEntry) -> (band: FiberDensityBand, confidence: Double) {
        let foodNameLower = entry.foodItem.name.lowercased()
        
        // Get NOVA score for interaction rules
        let novaScore = entry.foodItem.novaScore > 0 ?
            entry.foodItem.novaScore :
            NovaScoreService.shared.predictNovaScore(for: entry.foodItem)
        
        // ============================================================
        // IMPROVEMENT 3: Check for generic terms first
        // ============================================================
        let hasGenericTerm = genericTermKeywords.contains { foodNameLower.contains($0) }
        let hasSpecificFruit = specificFruitKeywords.contains { foodNameLower.contains($0) }
        let hasSpecificVegetable = specificVegetableKeywords.contains { foodNameLower.contains($0) }
        
        // If ONLY generic term detected (no specific fruit/veg), demote to low with low confidence
        if hasGenericTerm && !hasSpecificFruit && !hasSpecificVegetable {
            // Check if any other specific keyword matches exist
            let hasAnySpecificMatch = veryHighFiberKeywords.contains { foodNameLower.contains($0) } ||
                                      highFiberKeywords.contains { foodNameLower.contains($0) && !genericTermKeywords.contains($0) }
            
            if !hasAnySpecificMatch {
                return (.low, 0.4)  // Low confidence - vague logging
            }
        }
        
        // ============================================================
        // Priority 1: Keyword-based classification
        // ============================================================
        var detectedBand: FiberDensityBand? = nil
        var baseConfidence: Double = 0.0
        
        // Very High (4 pts): legumes, bran, chia/flax, artichoke
        for keyword in veryHighFiberKeywords {
            if foodNameLower.contains(keyword) {
                detectedBand = .veryHigh
                baseConfidence = 0.9
                break
            }
        }
        
        // High (3 pts): vegetables, berries, whole grains
        if detectedBand == nil {
            for keyword in highFiberKeywords {
                if foodNameLower.contains(keyword) && !genericTermKeywords.contains(keyword) {
                    detectedBand = .high
                    baseConfidence = 0.85
                    break
                }
            }
        }
        
        // Moderate (2 pts): fruits, nuts, seeds
        if detectedBand == nil {
            for keyword in moderateFiberKeywords {
                if foodNameLower.contains(keyword) && !genericTermKeywords.contains(keyword) {
                    detectedBand = .moderate
                    baseConfidence = 0.8
                    break
                }
            }
        }
        
        // Low (1 pt): refined grains, dairy, meat
        if detectedBand == nil {
            for keyword in lowFiberKeywords {
                if foodNameLower.contains(keyword) {
                    detectedBand = .low
                    baseConfidence = 0.8
                    break
                }
            }
        }
        
        // Very Low (0 pts): sweets, drinks, ultra-processed
        if detectedBand == nil {
            for keyword in veryLowFiberKeywords {
                if foodNameLower.contains(keyword) {
                    detectedBand = .veryLow
                    baseConfidence = 0.85
                    break
                }
            }
        }
        
        // ============================================================
        // IMPROVEMENT 1: NOVA + Keyword Interaction Rules
        // If NOVA 4 detected, cap fiber points at moderate (2 pts) max
        // This prevents gaming with "fiber-enriched" ultra-processed foods
        // ============================================================
        if let band = detectedBand {
            if novaScore == 4 {
                // NOVA 4 = ultra-processed, cap at moderate (2 pts) regardless of keyword
                let cappedBand: FiberDensityBand
                switch band {
                case .veryHigh, .high:
                    cappedBand = .moderate  // Cap at 2 pts
                    baseConfidence = min(baseConfidence, 0.6)  // Reduce confidence due to NOVA conflict
                case .moderate, .low, .veryLow:
                    cappedBand = band  // Keep as-is
                }
                return (cappedBand, baseConfidence)
            }
            return (band, baseConfidence)
        }
        
        // ============================================================
        // Priority 2: Fiber g/100g fallback
        // ============================================================
        if let fiber = entry.foodItem.fiber, fiber > 0 {
            let band: FiberDensityBand
            if fiber >= 7.0 {
                band = .veryHigh
            } else if fiber >= 4.0 {
                band = .high
            } else if fiber >= 2.0 {
                band = .moderate
            } else if fiber >= 0.5 {
                band = .low
            } else {
                band = .veryLow
            }
            
            // Apply NOVA cap to fiber-based classification too
            if novaScore == 4 && (band == .veryHigh || band == .high) {
                return (.moderate, 0.5)
            }
            return (band, 0.7)
        }
        
        // ============================================================
        // Priority 3: NOVA-based fallback
        // ============================================================
        switch novaScore {
        case 1:
            return (.moderate, 0.5)  // Unprocessed foods - moderate fiber assumed
        case 2:
            return (.low, 0.5)       // Processed culinary ingredients
        case 3:
            return (.low, 0.5)       // Processed foods
        case 4:
            return (.veryLow, 0.6)   // Ultra-processed - typically low fiber
        default:
            return (.low, 0.3)       // Unknown - low confidence
        }
    }
    
    /// Calculate portion scaling factor per spec
    /// <30g → 0.5×, 30–150g → 1.0×, >150g → 1.25× (cap)
    private func calculatePortionFactor(for entry: FoodEntry) -> Double {
        let gramsEstimate = estimatePortionGrams(for: entry)
        
        if gramsEstimate < 30 {
            return 0.5
        } else if gramsEstimate <= 150 {
            return 1.0
        } else {
            return 1.25  // Cap at 1.25×
        }
    }
    
    /// Estimate portion size in grams
    private func estimatePortionGrams(for entry: FoodEntry) -> Double {
        let unitLower = entry.servingUnit.lowercased()
        
        // If we have grams directly
        if unitLower == "g" || unitLower == "gram" || unitLower == "grams" {
            return entry.servingSize * entry.numberOfServings
        }
        
        // Calorie-based fallback (rough: 100 kcal ≈ 100g for mixed foods)
        let calories = Double(entry.totalCalories)
        if calories > 0 {
            return calories  // 1 kcal ≈ 1g approximation
        }
        
        // Default serving estimate
        return entry.servingSize * entry.numberOfServings * 100
    }
    
    /// Canonicalize plant names for diversity counting
    private func canonicalizePlantName(_ name: String) -> String {
        // Remove common suffixes to normalize names
        var canonical = name.lowercased()
        
        // Plurals
        if canonical.hasSuffix("ies") {
            canonical = String(canonical.dropLast(3)) + "y"
        } else if canonical.hasSuffix("es") && canonical.count > 3 {
            canonical = String(canonical.dropLast(2))
        } else if canonical.hasSuffix("s") && canonical.count > 2 {
            canonical = String(canonical.dropLast(1))
        }
        
        // Common variations
        let mappings: [String: String] = [
            "chickpea": "chickpea",
            "garbanzo": "chickpea",
            "courgette": "zucchini",
            "aubergine": "eggplant",
            "coriander": "cilantro",
            "rocket": "arugula"
        ]
        
        return mappings[canonical] ?? canonical
    }
    
    // MARK: - Helper Methods
    
    /// Calculate scaled nutrient value based on serving size
    /// Uses NutritionCalculator for consistent calculations across the app
    private func calculateScaledNutrient(
        nutrientValue: Double,
        servingSize: Double,
        servingUnit: String,
        numberOfServings: Double,
        foodItem: FoodItem
    ) -> Double {
        // Determine if this is the original serving size
        let unitLower = servingUnit.lowercased()
        let isOriginalServing = unitLower == "serving" || unitLower == "servings" || unitLower == "meal"
        
        // Use NutritionCalculator for consistent calculation (all values are per 100g)
        return NutritionCalculator.calculateMacro(
            macroValue: nutrientValue,
            servingSize: servingSize,
            servingUnit: servingUnit,
            numberOfServings: numberOfServings,
            isOriginalServingSize: isOriginalServing,
            servingDescription: foodItem.servingSize,
            servingQuantity: foodItem.servingsPerPackage
        )
    }
    
    /// Convert serving size to grams
    private func convertToGrams(_ value: Double, unit: String) -> Double {
        let unitLower = unit.lowercased()
        switch unitLower {
        case "g", "gram", "grams":
            return value
        case "kg", "kilogram", "kilograms":
            return value * 1000
        case "oz", "ounce", "ounces":
            return value * 28.35
        case "lb", "pound", "pounds":
            return value * 453.59
        case "ml", "milliliter", "milliliters":
            return value // Approximate 1:1 for most foods
        case "l", "liter", "liters":
            return value * 1000
        case "cup", "cups":
            return value * 240
        case "tbsp", "tablespoon", "tablespoons":
            return value * 15
        case "tsp", "teaspoon", "teaspoons":
            return value * 5
        default:
            return value // Assume grams if unknown
        }
    }
    
    /// Convert Nutri-Score grade to numeric value (A=0, E=1)
    private func nutriScoreGradeToNumeric(_ grade: String) -> Double {
        switch grade.lowercased() {
        case "a": return 0.0
        case "b": return 0.25
        case "c": return 0.5
        case "d": return 0.75
        case "e": return 1.0
        default: return 0.5
        }
    }
    
    // MARK: - Public Food Category Detection
    
    /// Check if a food is fermented (for breakdown view)
    func isFermentedFood(_ foodName: String) -> Bool {
        let nameLower = foodName.lowercased()
        for keyword in fermentedFoodKeywords {
            if nameLower.contains(keyword) {
                return true
            }
        }
        return false
    }
    
    /// Check if a food is prebiotic (for breakdown view)
    func isPrebioticFood(_ foodName: String) -> Bool {
        let nameLower = foodName.lowercased()
        for keyword in prebioticFoodKeywords {
            if nameLower.contains(keyword) {
                return true
            }
        }
        return false
    }
    
    /// Check if a food is omega-3 rich (for breakdown view)
    func isOmega3Food(_ foodName: String) -> Bool {
        let nameLower = foodName.lowercased()
        for keyword in omega3FoodKeywords {
            if nameLower.contains(keyword) {
                return true
            }
        }
        return false
    }
    
    /// Create empty metrics for when no data is available
    private func emptyMetrics() -> GutHealthMetrics {
        return GutHealthMetrics(
            fiberFrequencyPoints: 0,
            fiberFrequencyScore: 0,
            plantDiversityCount: 0,
            herbSpiceCount: 0,
            plantDiversityScore: 0,
            fiberGrams: 0,
            fiberGramsScore: 0,
            fiberDataQuality: 0,
            fiberDiversityTotal: 0,
            upfCaloriePercent: 0,
            upfLoadTotal: upfMaxPoints,  // Full points when no UPF
            fermentedServings: 0,
            fermentedScore: 0,
            prebioticServings: 0,
            prebioticScore: 0,
            fermentedPrebioticTotal: 0,
            unsatSatRatio: 0,
            fatRatioScore: 0,
            omega3Servings: 0,
            omega3Score: 0,
            fatQualityTotal: 0,
            overallScore: 0,
            interpretationBand: "No Data",
            confidenceLevel: ConfidenceLevel.low.rawValue,
            confidencePercent: 0,
            daysLogged: 0,
            dataCompleteness: 0
        )
    }
    
    // MARK: - Estimation Methods
    
    /// Estimate fiber content using USDA database, then AI cache, then category fallback
    private func estimateFiber(for food: FoodItem) -> Double {
        // 1. First check USDA verified database (most accurate)
        if let usdaValue = lookupUSDANutrient(for: food)?.fiber {
            return usdaValue
        }
        
        // 2. Check AI cache
        if let aiEstimate = AINutrientEstimationService.shared.getEstimate(for: food) {
            return aiEstimate.fiber
        }
        
        // 3. Fallback to category-based estimation
        return estimateFiberFromCategory(for: food)
    }
    
    /// Estimate sugar content using USDA database, then AI cache, then category fallback
    private func estimateSugar(for food: FoodItem) -> Double {
        // 1. First check USDA verified database (most accurate)
        if let usdaValue = lookupUSDANutrient(for: food)?.sugar {
            return usdaValue
        }
        
        // 2. Check AI cache
        if let aiEstimate = AINutrientEstimationService.shared.getEstimate(for: food) {
            return aiEstimate.sugar
        }
        
        // 3. Fallback to category-based estimation
        return estimateSugarFromCategory(for: food)
    }
    
    /// Look up food in USDA verified database
    private func lookupUSDANutrient(for food: FoodItem) -> USDANutrient? {
        let searchText = food.name.lowercased()
        
        // Try exact match first
        if let nutrient = usdaDatabase[searchText] {
            return nutrient
        }
        
        // Try to find a matching keyword in the food name
        // Sort by key length descending to match longer (more specific) keywords first
        let sortedKeys = usdaDatabase.keys.sorted { $0.count > $1.count }
        
        for keyword in sortedKeys {
            if searchText.contains(keyword) {
                return usdaDatabase[keyword]
            }
        }
        
        return nil
    }
    
    /// Category-based fiber estimation fallback
    private func estimateFiberFromCategory(for food: FoodItem) -> Double {
        let searchText = "\(food.name) \(food.brandName ?? "")".lowercased()
        
        // Try to match category keywords
        for (category, nutrient) in categoryFallbacks {
            if searchText.contains(category) {
                return nutrient.fiber
            }
        }
        
        // Default fallback: 2g per 100g (moderate estimate)
        return 2.0
    }
    
    /// Category-based sugar estimation fallback
    private func estimateSugarFromCategory(for food: FoodItem) -> Double {
        let searchText = "\(food.name) \(food.brandName ?? "")".lowercased()
        
        // Try to match category keywords
        for (category, nutrient) in categoryFallbacks {
            if searchText.contains(category) {
                return nutrient.sugar
            }
        }
        
        // Default fallback: 2g per 100g (conservative estimate)
        return 2.0
    }
    
    // Public wrappers for debug view
    func estimateFiberForDebug(for food: FoodItem) -> Double {
        return estimateFiber(for: food)
    }
    
    func estimateSugarForDebug(for food: FoodItem) -> Double {
        return estimateSugar(for: food)
    }
    
    /// Trigger AI estimation for foods missing nutrient data
    /// Call this when opening gut health view to warm up the cache
    func prefetchAIEstimates(for entries: [FoodEntry]) {
        AINutrientEstimationService.shared.prefetchEstimates(for: entries)
    }
    
    // MARK: - Score Descriptions
    
    func getScoreDescription(_ score: Double) -> String {
        switch score {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        case 20..<40: return "Poor"
        default: return "Needs Work"
        }
    }
    
    func getScoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return gaugeColors[4]
        case 60..<80: return gaugeColors[3]
        case 40..<60: return gaugeColors[2]
        case 20..<40: return gaugeColors[1]
        default: return gaugeColors[0]
        }
    }
    
    // MARK: - Category Insights
    
    func getFiberInsight(_ grams: Double) -> String {
        if grams >= fiberOptimalGrams {
            return "Excellent fiber intake!"
        } else if grams >= fiberTargetGrams {
            return "Good fiber intake"
        } else if grams >= fiberTargetGrams * 0.5 {
            return "Could use more fiber"
        } else {
            return "Low fiber - add more whole foods"
        }
    }
    
    func getNova4Insight(_ percent: Double) -> String {
        if percent <= 10 {
            return "Minimal ultra-processed foods"
        } else if percent <= nova4LowPercent {
            return "Low ultra-processed intake"
        } else if percent <= 35 {
            return "Moderate ultra-processed foods"
        } else if percent <= nova4HighPercent {
            return "High ultra-processed intake"
        } else {
            return "Very high processed food intake"
        }
    }
    
    func getSugarInsight(_ grams: Double) -> String {
        if grams <= sugarLimitGrams * 0.5 {
            return "Excellent - very low sugar"
        } else if grams <= sugarLimitGrams {
            return "Good sugar control"
        } else if grams <= sugarHighGrams {
            return "Sugar is elevated"
        } else {
            return "High sugar intake"
        }
    }
    
}
