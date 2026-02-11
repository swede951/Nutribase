import Foundation

/// Service managing verified staple foods with accurate, curated nutrition data
/// These foods appear at the top of search results with a verified badge
class VerifiedFoodsService: ObservableObject {
    static let shared = VerifiedFoodsService()
    
    @Published private(set) var verifiedFoods: [FoodItem] = []
    
    private init() {
        loadVerifiedFoods()
    }
    
    /// Search verified foods by query string
    func searchVerifiedFoods(query: String) -> [FoodItem] {
        guard !query.isEmpty else { return [] }
        
        let lowercasedQuery = query.lowercased()
        
        return verifiedFoods.filter { food in
            food.name.lowercased().contains(lowercasedQuery)
        }
    }
    
    /// Load the curated list of verified foods
    private func loadVerifiedFoods() {
        verifiedFoods = [
            // MARK: - Fruits
            createVerifiedFood(
                name: "Banana",
                servingSize: "1 medium (118g)", servingGrams: 118,
                calories: 105, protein: 1.3, carbs: 27, fat: 0.4,
                fiber: 3.1, sugar: 14.4, sodium: 1, saturatedFat: 0.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Apple",
                servingSize: "1 medium (182g)", servingGrams: 182,
                calories: 95, protein: 0.5, carbs: 25, fat: 0.3,
                fiber: 4.4, sugar: 19, sodium: 2, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Orange",
                servingSize: "1 medium (131g)", servingGrams: 131,
                calories: 62, protein: 1.2, carbs: 15.4, fat: 0.2,
                fiber: 3.1, sugar: 12.2, sodium: 0, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Strawberries",
                servingSize: "1 cup (144g)", servingGrams: 144,
                calories: 46, protein: 1, carbs: 11, fat: 0.4,
                fiber: 2.9, sugar: 7, sodium: 1, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Blueberries",
                servingSize: "1 cup (148g)", servingGrams: 148,
                calories: 84, protein: 1.1, carbs: 21, fat: 0.5,
                fiber: 3.6, sugar: 15, sodium: 1, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Avocado",
                servingSize: "1/2 fruit (100g)", servingGrams: 100,
                calories: 160, protein: 2, carbs: 8.5, fat: 14.7,
                fiber: 6.7, sugar: 0.7, sodium: 7, saturatedFat: 2.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Grapes",
                servingSize: "1 cup (151g)", servingGrams: 151,
                calories: 104, protein: 1.1, carbs: 27, fat: 0.2,
                fiber: 1.4, sugar: 23, sodium: 3, saturatedFat: 0.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Mango",
                servingSize: "1 cup (165g)", servingGrams: 165,
                calories: 99, protein: 1.4, carbs: 25, fat: 0.6,
                fiber: 2.6, sugar: 23, sodium: 2, saturatedFat: 0.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Pineapple",
                servingSize: "1 cup (165g)", servingGrams: 165,
                calories: 82, protein: 0.9, carbs: 22, fat: 0.2,
                fiber: 2.3, sugar: 16, sodium: 2, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            
            // MARK: - Vegetables
            createVerifiedFood(
                name: "Broccoli, raw",
                servingSize: "1 cup (91g)", servingGrams: 91,
                calories: 31, protein: 2.5, carbs: 6, fat: 0.3,
                fiber: 2.4, sugar: 1.5, sodium: 30, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Broccoli, cooked",
                servingSize: "1 cup (156g)", servingGrams: 156,
                calories: 55, protein: 3.7, carbs: 11, fat: 0.6,
                fiber: 5.1, sugar: 2.2, sodium: 64, saturatedFat: 0.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Spinach, raw",
                servingSize: "1 cup (30g)", servingGrams: 30,
                calories: 7, protein: 0.9, carbs: 1.1, fat: 0.1,
                fiber: 0.7, sugar: 0.1, sodium: 24, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Spinach, cooked",
                servingSize: "1 cup (180g)", servingGrams: 180,
                calories: 41, protein: 5.3, carbs: 6.8, fat: 0.5,
                fiber: 4.3, sugar: 0.8, sodium: 126, saturatedFat: 0.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Carrot, raw",
                servingSize: "1 medium (61g)", servingGrams: 61,
                calories: 25, protein: 0.6, carbs: 6, fat: 0.1,
                fiber: 1.7, sugar: 2.9, sodium: 42, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Sweet Potato, baked",
                servingSize: "1 medium (114g)", servingGrams: 114,
                calories: 103, protein: 2.3, carbs: 24, fat: 0.1,
                fiber: 3.8, sugar: 7, sodium: 41, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Tomato, raw",
                servingSize: "1 medium (123g)", servingGrams: 123,
                calories: 22, protein: 1.1, carbs: 4.8, fat: 0.2,
                fiber: 1.5, sugar: 3.2, sodium: 6, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Cucumber, raw",
                servingSize: "1/2 cup (52g)", servingGrams: 52,
                calories: 8, protein: 0.3, carbs: 1.9, fat: 0.1,
                fiber: 0.3, sugar: 0.9, sodium: 1, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Onion, raw",
                servingSize: "1 medium (110g)", servingGrams: 110,
                calories: 44, protein: 1.2, carbs: 10, fat: 0.1,
                fiber: 1.9, sugar: 4.7, sodium: 4, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Bell Pepper, raw",
                servingSize: "1 medium (119g)", servingGrams: 119,
                calories: 31, protein: 1, carbs: 6, fat: 0.4,
                fiber: 2.1, sugar: 4.2, sodium: 4, saturatedFat: 0.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Courgette/Zucchini, raw",
                servingSize: "1 cup (124g)", servingGrams: 124,
                calories: 21, protein: 1.5, carbs: 3.9, fat: 0.4,
                fiber: 1.2, sugar: 3.1, sodium: 10, saturatedFat: 0.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Mushrooms, raw",
                servingSize: "1 cup (70g)", servingGrams: 70,
                calories: 15, protein: 2.2, carbs: 2.3, fat: 0.2,
                fiber: 0.7, sugar: 1.4, sodium: 4, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Lettuce, raw",
                servingSize: "1 cup (36g)", servingGrams: 36,
                calories: 5, protein: 0.5, carbs: 1, fat: 0.1,
                fiber: 0.5, sugar: 0.4, sodium: 5, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Potato, baked",
                servingSize: "1 medium (173g)", servingGrams: 173,
                calories: 161, protein: 4.3, carbs: 37, fat: 0.2,
                fiber: 3.8, sugar: 1.7, sodium: 17, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Potato, boiled",
                servingSize: "1 medium (136g)", servingGrams: 136,
                calories: 118, protein: 2.5, carbs: 27, fat: 0.1,
                fiber: 2.4, sugar: 1.2, sodium: 5, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Frozen Mixed Vegetables, plain",
                servingSize: "1 cup (134g)", servingGrams: 134,
                calories: 82, protein: 4, carbs: 16, fat: 0.3,
                fiber: 5, sugar: 4, sodium: 64, saturatedFat: 0.1,
                novaScore: 1, nutriScore: "A"
            ),
            
            // MARK: - Proteins
            createVerifiedFood(
                name: "Chicken Breast, raw, skinless",
                servingSize: "100g", servingGrams: 100,
                calories: 120, protein: 22.5, carbs: 0, fat: 2.6,
                fiber: 0, sugar: 0, sodium: 45, saturatedFat: 0.6,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Chicken Breast, cooked, grilled",
                servingSize: "100g", servingGrams: 100,
                calories: 165, protein: 31, carbs: 0, fat: 3.6,
                fiber: 0, sugar: 0, sodium: 74, saturatedFat: 1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Chicken Thigh, raw, skinless",
                servingSize: "100g", servingGrams: 100,
                calories: 119, protein: 19, carbs: 0, fat: 4.3,
                fiber: 0, sugar: 0, sodium: 84, saturatedFat: 1.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Chicken Thigh, cooked, roasted",
                servingSize: "100g", servingGrams: 100,
                calories: 209, protein: 26, carbs: 0, fat: 10.9,
                fiber: 0, sugar: 0, sodium: 84, saturatedFat: 3,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Turkey Breast, raw",
                servingSize: "100g", servingGrams: 100,
                calories: 104, protein: 24, carbs: 0, fat: 0.7,
                fiber: 0, sugar: 0, sodium: 45, saturatedFat: 0.2,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Turkey Breast, cooked",
                servingSize: "100g", servingGrams: 100,
                calories: 135, protein: 30, carbs: 0, fat: 0.7,
                fiber: 0, sugar: 0, sodium: 46, saturatedFat: 0.2,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Salmon, raw",
                servingSize: "100g", servingGrams: 100,
                calories: 208, protein: 20, carbs: 0, fat: 13,
                fiber: 0, sugar: 0, sodium: 59, saturatedFat: 3.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Salmon, cooked",
                servingSize: "100g", servingGrams: 100,
                calories: 208, protein: 20, carbs: 0, fat: 13.4,
                fiber: 0, sugar: 0, sodium: 59, saturatedFat: 3.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Salmon, tinned",
                servingSize: "100g", servingGrams: 100,
                calories: 167, protein: 21, carbs: 0, fat: 9,
                fiber: 0, sugar: 0, sodium: 380, saturatedFat: 2,
                novaScore: 3, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Cod, raw",
                servingSize: "100g", servingGrams: 100,
                calories: 82, protein: 18, carbs: 0, fat: 0.7,
                fiber: 0, sugar: 0, sodium: 54, saturatedFat: 0.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Cod, cooked",
                servingSize: "100g", servingGrams: 100,
                calories: 105, protein: 23, carbs: 0, fat: 0.9,
                fiber: 0, sugar: 0, sodium: 78, saturatedFat: 0.2,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Tuna, canned in water",
                servingSize: "1 can (142g)", servingGrams: 142,
                calories: 165, protein: 36, carbs: 0, fat: 1.1,
                fiber: 0, sugar: 0, sodium: 350, saturatedFat: 0.3,
                novaScore: 3, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Egg, whole, large, raw",
                servingSize: "1 large (50g)", servingGrams: 50,
                calories: 72, protein: 6.3, carbs: 0.4, fat: 5,
                fiber: 0, sugar: 0.2, sodium: 71, saturatedFat: 1.6,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Egg, whole, large, boiled",
                servingSize: "1 large (50g)", servingGrams: 50,
                calories: 78, protein: 6.3, carbs: 0.6, fat: 5.3,
                fiber: 0, sugar: 0.6, sodium: 62, saturatedFat: 1.6,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Egg, whole, large, fried",
                servingSize: "1 large (46g)", servingGrams: 46,
                calories: 90, protein: 6.3, carbs: 0.4, fat: 7,
                fiber: 0, sugar: 0.4, sodium: 94, saturatedFat: 2,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Egg, whole, medium, raw",
                servingSize: "1 medium (44g)", servingGrams: 44,
                calories: 63, protein: 5.5, carbs: 0.3, fat: 4.4,
                fiber: 0, sugar: 0.2, sodium: 62, saturatedFat: 1.4,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Egg, whole, medium, boiled",
                servingSize: "1 medium (44g)", servingGrams: 44,
                calories: 68, protein: 5.5, carbs: 0.5, fat: 4.6,
                fiber: 0, sugar: 0.5, sodium: 54, saturatedFat: 1.4,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Egg White, raw",
                servingSize: "1 large (33g)", servingGrams: 33,
                calories: 17, protein: 3.6, carbs: 0.2, fat: 0.1,
                fiber: 0, sugar: 0.2, sodium: 55, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Ground Beef, 90% lean, raw",
                servingSize: "100g", servingGrams: 100,
                calories: 176, protein: 20, carbs: 0, fat: 10,
                fiber: 0, sugar: 0, sodium: 66, saturatedFat: 3.8,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Ground Beef, 90% lean, cooked",
                servingSize: "100g", servingGrams: 100,
                calories: 217, protein: 26, carbs: 0, fat: 12,
                fiber: 0, sugar: 0, sodium: 76, saturatedFat: 4.5,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Ground Beef, 95% lean, cooked",
                servingSize: "100g", servingGrams: 100,
                calories: 174, protein: 27, carbs: 0, fat: 7,
                fiber: 0, sugar: 0, sodium: 72, saturatedFat: 2.8,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Pork Loin, raw",
                servingSize: "100g", servingGrams: 100,
                calories: 143, protein: 21, carbs: 0, fat: 6,
                fiber: 0, sugar: 0, sodium: 48, saturatedFat: 2,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Pork Loin, cooked",
                servingSize: "100g", servingGrams: 100,
                calories: 197, protein: 27, carbs: 0, fat: 9,
                fiber: 0, sugar: 0, sodium: 53, saturatedFat: 3,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Shrimp, cooked",
                servingSize: "100g", servingGrams: 100,
                calories: 99, protein: 24, carbs: 0.2, fat: 0.3,
                fiber: 0, sugar: 0, sodium: 111, saturatedFat: 0.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Tofu, firm",
                servingSize: "1/2 cup (126g)", servingGrams: 126,
                calories: 181, protein: 22, carbs: 3.5, fat: 11,
                fiber: 2.9, sugar: 0.8, sodium: 18, saturatedFat: 1.6,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Tempeh",
                servingSize: "100g", servingGrams: 100,
                calories: 192, protein: 20, carbs: 7.6, fat: 11,
                fiber: 0, sugar: 0, sodium: 9, saturatedFat: 2.5,
                novaScore: 1, nutriScore: "A"
            ),
            
            // MARK: - Grains & Carbs
            createVerifiedFood(
                name: "Oats, dry",
                servingSize: "1/2 cup (40g)", servingGrams: 40,
                calories: 152, protein: 6.7, carbs: 27, fat: 2.8,
                fiber: 4, sugar: 0.4, sodium: 1, saturatedFat: 0.5,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Brown Rice, dry",
                servingSize: "1/4 cup (45g)", servingGrams: 45,
                calories: 160, protein: 3.5, carbs: 34, fat: 1.3,
                fiber: 1.6, sugar: 0, sodium: 3, saturatedFat: 0.3,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Brown Rice, cooked",
                servingSize: "1 cup (195g)", servingGrams: 195,
                calories: 216, protein: 5, carbs: 45, fat: 1.8,
                fiber: 3.5, sugar: 0, sodium: 10, saturatedFat: 0.4,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "White Rice, dry",
                servingSize: "1/4 cup (45g)", servingGrams: 45,
                calories: 160, protein: 3, carbs: 36, fat: 0.3,
                fiber: 0.6, sugar: 0, sodium: 1, saturatedFat: 0.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "White Rice, cooked",
                servingSize: "1 cup (158g)", servingGrams: 158,
                calories: 206, protein: 4.3, carbs: 45, fat: 0.4,
                fiber: 0.6, sugar: 0, sodium: 2, saturatedFat: 0.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Quinoa, dry",
                servingSize: "1/4 cup (43g)", servingGrams: 43,
                calories: 156, protein: 6, carbs: 27, fat: 2.6,
                fiber: 2.8, sugar: 0, sodium: 5, saturatedFat: 0.3,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Quinoa, cooked",
                servingSize: "1 cup (185g)", servingGrams: 185,
                calories: 222, protein: 8.1, carbs: 39, fat: 3.6,
                fiber: 5.2, sugar: 0, sodium: 13, saturatedFat: 0.4,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Pasta, dry",
                servingSize: "100g", servingGrams: 100,
                calories: 371, protein: 13, carbs: 75, fat: 1.5,
                fiber: 3, sugar: 2.7, sodium: 6, saturatedFat: 0.3,
                novaScore: 3, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Pasta, cooked",
                servingSize: "1 cup (140g)", servingGrams: 140,
                calories: 220, protein: 8.1, carbs: 43, fat: 1.3,
                fiber: 2.5, sugar: 0.8, sodium: 1, saturatedFat: 0.2,
                novaScore: 3, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Couscous, dry",
                servingSize: "1/4 cup (44g)", servingGrams: 44,
                calories: 163, protein: 5.6, carbs: 34, fat: 0.3,
                fiber: 2, sugar: 0, sodium: 5, saturatedFat: 0,
                novaScore: 3, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Couscous, cooked",
                servingSize: "1 cup (157g)", servingGrams: 157,
                calories: 176, protein: 6, carbs: 36, fat: 0.3,
                fiber: 2.2, sugar: 0, sodium: 8, saturatedFat: 0,
                novaScore: 3, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "White Bread",
                servingSize: "1 slice (30g)", servingGrams: 30,
                calories: 79, protein: 2.7, carbs: 15, fat: 1,
                fiber: 0.7, sugar: 1.5, sodium: 147, saturatedFat: 0.2,
                novaScore: 3, nutriScore: "C"
            ),
            createVerifiedFood(
                name: "Whole Wheat Bread",
                servingSize: "1 slice (43g)", servingGrams: 43,
                calories: 110, protein: 5, carbs: 20, fat: 1.8,
                fiber: 3, sugar: 3, sodium: 170, saturatedFat: 0.4,
                novaScore: 3, nutriScore: "B"
            ),
            createVerifiedFood(
                name: "Tortilla Wrap, plain wheat",
                servingSize: "1 wrap (49g)", servingGrams: 49,
                calories: 146, protein: 4, carbs: 24, fat: 3.5,
                fiber: 1.5, sugar: 0.8, sodium: 270, saturatedFat: 0.8,
                novaScore: 3, nutriScore: "B"
            ),
            createVerifiedFood(
                name: "Flour, plain/all-purpose",
                servingSize: "1/4 cup (31g)", servingGrams: 31,
                calories: 114, protein: 3.2, carbs: 24, fat: 0.3,
                fiber: 0.8, sugar: 0, sodium: 1, saturatedFat: 0,
                novaScore: 1, nutriScore: "A"
            ),
            
            // MARK: - Dairy
            createVerifiedFood(
                name: "Whole Milk",
                servingSize: "1 cup (244ml)", servingGrams: 244,
                calories: 149, protein: 8, carbs: 12, fat: 8,
                fiber: 0, sugar: 12, sodium: 105, saturatedFat: 4.6,
                novaScore: 1, nutriScore: "B"
            ),
            createVerifiedFood(
                name: "Semi-Skimmed Milk (2%)",
                servingSize: "1 cup (244ml)", servingGrams: 244,
                calories: 122, protein: 8.1, carbs: 12, fat: 4.8,
                fiber: 0, sugar: 12, sodium: 115, saturatedFat: 3,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Skim Milk",
                servingSize: "1 cup (245ml)", servingGrams: 245,
                calories: 83, protein: 8.3, carbs: 12, fat: 0.2,
                fiber: 0, sugar: 12, sodium: 103, saturatedFat: 0.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Greek Yogurt, plain, full-fat",
                servingSize: "1 container (170g)", servingGrams: 170,
                calories: 165, protein: 15, carbs: 6, fat: 9,
                fiber: 0, sugar: 5, sodium: 61, saturatedFat: 5,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Greek Yogurt, plain, low-fat",
                servingSize: "1 container (170g)", servingGrams: 170,
                calories: 120, protein: 17, carbs: 7, fat: 2.5,
                fiber: 0, sugar: 6, sodium: 65, saturatedFat: 1.5,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Skyr",
                servingSize: "1 container (150g)", servingGrams: 150,
                calories: 100, protein: 17, carbs: 6, fat: 0.3,
                fiber: 0, sugar: 4, sodium: 55, saturatedFat: 0.2,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Cheddar Cheese",
                servingSize: "1 slice (28g)", servingGrams: 28,
                calories: 113, protein: 7, carbs: 0.4, fat: 9.3,
                fiber: 0, sugar: 0.1, sodium: 174, saturatedFat: 5.9,
                novaScore: 3, nutriScore: "D"
            ),
            createVerifiedFood(
                name: "Mozzarella Cheese",
                servingSize: "1 slice (28g)", servingGrams: 28,
                calories: 85, protein: 6.3, carbs: 0.6, fat: 6.3,
                fiber: 0, sugar: 0.2, sodium: 178, saturatedFat: 3.7,
                novaScore: 3, nutriScore: "C"
            ),
            createVerifiedFood(
                name: "Cream Cheese",
                servingSize: "2 tbsp (29g)", servingGrams: 29,
                calories: 99, protein: 1.7, carbs: 1.6, fat: 9.8,
                fiber: 0, sugar: 0.7, sodium: 91, saturatedFat: 5.5,
                novaScore: 3, nutriScore: "D"
            ),
            createVerifiedFood(
                name: "Cottage Cheese",
                servingSize: "1/2 cup (113g)", servingGrams: 113,
                calories: 111, protein: 12.5, carbs: 3.8, fat: 4.9,
                fiber: 0, sugar: 3, sodium: 411, saturatedFat: 1.9,
                novaScore: 3, nutriScore: "B"
            ),
            
            // MARK: - Legumes & Nuts
            createVerifiedFood(
                name: "Black Beans, cooked",
                servingSize: "1/2 cup (86g)", servingGrams: 86,
                calories: 114, protein: 7.6, carbs: 20, fat: 0.5,
                fiber: 7.5, sugar: 0.3, sodium: 1, saturatedFat: 0.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Chickpeas, cooked",
                servingSize: "1/2 cup (82g)", servingGrams: 82,
                calories: 134, protein: 7.3, carbs: 22, fat: 2.1,
                fiber: 6.2, sugar: 4, sodium: 6, saturatedFat: 0.2,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Lentils, cooked",
                servingSize: "1/2 cup (99g)", servingGrams: 99,
                calories: 115, protein: 9, carbs: 20, fat: 0.4,
                fiber: 7.8, sugar: 1.8, sodium: 2, saturatedFat: 0.1,
                novaScore: 1, nutriScore: "A"
            ),
            createVerifiedFood(
                name: "Peanut Butter, natural",
                servingSize: "2 tbsp (32g)", servingGrams: 32,
                calories: 188, protein: 8, carbs: 6, fat: 16,
                fiber: 1.9, sugar: 1.7, sodium: 5, saturatedFat: 2.5,
                novaScore: 1, nutriScore: "C"
            ),
            createVerifiedFood(
                name: "Almonds",
                servingSize: "1/4 cup (28g)", servingGrams: 28,
                calories: 164, protein: 6, carbs: 6, fat: 14,
                fiber: 3.5, sugar: 1.2, sodium: 0, saturatedFat: 1.1,
                novaScore: 1, nutriScore: "A"
            ),
            
            // MARK: - Fats & Oils
            createVerifiedFood(
                name: "Olive Oil",
                servingSize: "1 tbsp (14ml)", servingGrams: 14,
                calories: 119, protein: 0, carbs: 0, fat: 13.5,
                fiber: 0, sugar: 0, sodium: 0, saturatedFat: 1.9,
                novaScore: 1, nutriScore: "B"
            ),
            createVerifiedFood(
                name: "Butter",
                servingSize: "1 tbsp (14g)", servingGrams: 14,
                calories: 102, protein: 0.1, carbs: 0, fat: 11.5,
                fiber: 0, sugar: 0, sodium: 91, saturatedFat: 7.3,
                novaScore: 3, nutriScore: "E"
            ),
            createVerifiedFood(
                name: "Coconut Oil",
                servingSize: "1 tbsp (14ml)", servingGrams: 14,
                calories: 121, protein: 0, carbs: 0, fat: 13.6,
                fiber: 0, sugar: 0, sodium: 0, saturatedFat: 11.8,
                novaScore: 1, nutriScore: "D"
            ),
            
            // MARK: - Other Staples
            createVerifiedFood(
                name: "Honey",
                servingSize: "1 tbsp (21g)", servingGrams: 21,
                calories: 64, protein: 0.1, carbs: 17, fat: 0,
                fiber: 0, sugar: 17, sodium: 1, saturatedFat: 0,
                novaScore: 1, nutriScore: "D"
            ),
        ]
    }
    
    /// Helper to create a verified FoodItem with all required fields
    /// Note: Input nutrition values are per serving (servingGrams), but we normalize to per 100g
    /// to match the app's standard calculation model where all nutrition is stored per 100g
    private func createVerifiedFood(
        name: String,
        servingSize: String,
        servingGrams: Double,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double,
        sugar: Double,
        sodium: Double,
        saturatedFat: Double,
        novaScore: Int,
        nutriScore: String
    ) -> FoodItem {
        // Normalize all nutrition values to per 100g
        // Input values are per serving (servingGrams), scale to 100g equivalent
        let scaleFactor = servingGrams > 0 ? 100.0 / servingGrams : 1.0
        
        let caloriesPer100g = Int(round(Double(calories) * scaleFactor))
        let proteinPer100g = protein * scaleFactor
        let carbsPer100g = carbs * scaleFactor
        let fatPer100g = fat * scaleFactor
        let fiberPer100g = fiber * scaleFactor
        let sugarPer100g = sugar * scaleFactor
        let sodiumPer100g = sodium * scaleFactor
        let saturatedFatPer100g = saturatedFat * scaleFactor
        
        return FoodItem(
            name: name,
            brandName: nil,
            barcode: nil,
            calories: caloriesPer100g,
            protein: proteinPer100g,
            carbs: carbsPer100g,
            fat: fatPer100g,
            novaScore: novaScore,
            novaScoreIsEstimated: false,
            nutriScoreGrade: nutriScore.lowercased(),
            nutriScoreIsEstimated: false,
            servingSize: servingSize,
            servingsPerPackage: nil,
            servingType: "serving",
            fiber: fiberPer100g,
            sugar: sugarPer100g,
            sodium: sodiumPer100g,
            saturatedFat: saturatedFatPer100g,
            ingredients: nil,
            cachedServingSize: servingGrams,
            cachedServingUnit: "g",
            cachedNumberOfServings: 1.0,
            cachedSelectedServingSizeOption: nil,
            countries: nil,
            purchasePlaces: nil,
            origins: nil,
            isMeal: false,
            isVerified: true,
            dataSource: "verified"
        )
    }
}
