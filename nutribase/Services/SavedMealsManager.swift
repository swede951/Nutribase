import Foundation
import Combine

class SavedMealsManager: ObservableObject {
    static let shared = SavedMealsManager()
    
    @Published var meals: [SavedMeal] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    // User-specific key for saved meals
    private var mealsKey: String {
        if let authenticatedUser = FirebaseAuthService.shared.currentUser {
            return "saved_meals_\(authenticatedUser.id)"
        } else {
            // Fallback to local UUID for offline usage
            if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
                return "saved_meals_\(localUserId)"
            }
            return "saved_meals_default"
        }
    }
    
    init() {
        loadMeals()
        setupAuthenticationObservers()
    }
    
    // Set up authentication notification observers
    private func setupAuthenticationObservers() {
        // Listen for user sign-in events
        NotificationCenter.default.publisher(for: .userDidSignIn)
            .sink { [weak self] _ in
                self?.loadMeals()
            }
            .store(in: &cancellables)
        
        // Listen for user sign-out events
        NotificationCenter.default.publisher(for: .userDidSignOut)
            .sink { [weak self] _ in
                self?.loadMeals()
            }
            .store(in: &cancellables)
    }
    
    func loadMeals() {
        if let data = UserDefaults.standard.data(forKey: mealsKey),
           let decoded = try? JSONDecoder().decode([SavedMeal].self, from: data) {
            meals = decoded
        }
    }
    
    func saveMeal(_ meal: SavedMeal) {
        meals.append(meal)
        persistMeals()
    }
    
    func deleteMeal(_ meal: SavedMeal) {
        meals.removeAll { $0.id == meal.id }
        persistMeals()
    }
    
    func persistMeals() {
        if let encoded = try? JSONEncoder().encode(meals) {
            UserDefaults.standard.set(encoded, forKey: mealsKey)
        }
    }
}
