import Foundation

/// Service for managing user's favorite foods
/// Favorites appear at the top of the search screen and get priority in search results
class FavoriteFoodsService: ObservableObject {
    static let shared = FavoriteFoodsService()
    
    @Published var favorites: [FoodItem] = []
    
    private var favoritesKey: String {
        if let userId = UserDefaults.standard.string(forKey: "currentUserId"), !userId.isEmpty {
            return "favoriteFoods_\(userId)"
        }
        return "favoriteFoods_default"
    }
    
    private let maxFavorites = 50
    
    init() {
        loadFavorites()
    }
    
    // MARK: - Public Methods
    
    func isFavorite(_ food: FoodItem) -> Bool {
        return favorites.contains { favoriteKey(for: $0) == favoriteKey(for: food) }
    }
    
    func toggleFavorite(_ food: FoodItem) {
        if isFavorite(food) {
            removeFavorite(food)
        } else {
            addFavorite(food)
        }
    }
    
    func addFavorite(_ food: FoodItem) {
        guard !isFavorite(food) else { return }
        
        favorites.insert(food, at: 0)
        
        if favorites.count > maxFavorites {
            favorites = Array(favorites.prefix(maxFavorites))
        }
        
        saveFavorites()
        print("❤️ Added favorite: \(food.name)")
    }
    
    func removeFavorite(_ food: FoodItem) {
        let key = favoriteKey(for: food)
        favorites.removeAll { favoriteKey(for: $0) == key }
        saveFavorites()
        print("💔 Removed favorite: \(food.name)")
    }
    
    func searchFavorites(query: String) -> [FoodItem] {
        guard !query.isEmpty else { return [] }
        let queryLower = query.lowercased()
        return favorites.filter { food in
            food.name.lowercased().contains(queryLower) ||
            (food.brandName?.lowercased().contains(queryLower) ?? false)
        }
    }
    
    // MARK: - Private Methods
    
    private func favoriteKey(for food: FoodItem) -> String {
        let name = food.name.lowercased()
        let brand = food.brandName?.lowercased() ?? ""
        let barcode = food.barcode ?? ""
        return "\(name)|\(brand)|\(barcode)"
    }
    
    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey),
              let foods = try? JSONDecoder().decode([FoodItem].self, from: data) else {
            favorites = []
            return
        }
        favorites = foods
    }
    
    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }
}
