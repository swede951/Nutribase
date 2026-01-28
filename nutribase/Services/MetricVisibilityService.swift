import Foundation
import Combine

/// Service to manage which metrics are visible throughout the app
/// Allows users to hide calories, macros, NOVA score, or Nutri-Score for a more personalized experience
class MetricVisibilityService: ObservableObject {
    static let shared = MetricVisibilityService()
    
    private var cancellables = Set<AnyCancellable>()
    
    // User-specific keys
    private var caloriesKey: String {
        if let authenticatedUser = FirebaseAuthService.shared.currentUser {
            return "metricVisibility_calories_\(authenticatedUser.id)"
        } else {
            if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
                return "metricVisibility_calories_\(localUserId)"
            }
            return "metricVisibility_calories_default"
        }
    }
    
    private var proteinKey: String {
        if let authenticatedUser = FirebaseAuthService.shared.currentUser {
            return "metricVisibility_protein_\(authenticatedUser.id)"
        } else {
            if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
                return "metricVisibility_protein_\(localUserId)"
            }
            return "metricVisibility_protein_default"
        }
    }
    
    private var carbsKey: String {
        if let authenticatedUser = FirebaseAuthService.shared.currentUser {
            return "metricVisibility_carbs_\(authenticatedUser.id)"
        } else {
            if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
                return "metricVisibility_carbs_\(localUserId)"
            }
            return "metricVisibility_carbs_default"
        }
    }
    
    private var fatKey: String {
        if let authenticatedUser = FirebaseAuthService.shared.currentUser {
            return "metricVisibility_fat_\(authenticatedUser.id)"
        } else {
            if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
                return "metricVisibility_fat_\(localUserId)"
            }
            return "metricVisibility_fat_default"
        }
    }
    
    private var novaScoreKey: String {
        if let authenticatedUser = FirebaseAuthService.shared.currentUser {
            return "metricVisibility_novaScore_\(authenticatedUser.id)"
        } else {
            if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
                return "metricVisibility_novaScore_\(localUserId)"
            }
            return "metricVisibility_novaScore_default"
        }
    }
    
    private var nutriScoreKey: String {
        if let authenticatedUser = FirebaseAuthService.shared.currentUser {
            return "metricVisibility_nutriScore_\(authenticatedUser.id)"
        } else {
            if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
                return "metricVisibility_nutriScore_\(localUserId)"
            }
            return "metricVisibility_nutriScore_default"
        }
    }
    
    // MARK: - Published Properties
    @Published var showCalories: Bool {
        didSet {
            UserDefaults.standard.set(showCalories, forKey: caloriesKey)
        }
    }
    
    @Published var showProtein: Bool {
        didSet {
            UserDefaults.standard.set(showProtein, forKey: proteinKey)
        }
    }
    
    @Published var showCarbs: Bool {
        didSet {
            UserDefaults.standard.set(showCarbs, forKey: carbsKey)
        }
    }
    
    @Published var showFat: Bool {
        didSet {
            UserDefaults.standard.set(showFat, forKey: fatKey)
        }
    }
    
    @Published var showNovaScore: Bool {
        didSet {
            UserDefaults.standard.set(showNovaScore, forKey: novaScoreKey)
        }
    }
    
    @Published var showNutriScore: Bool {
        didSet {
            UserDefaults.standard.set(showNutriScore, forKey: nutriScoreKey)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if at least one macro is visible
    var anyMacroVisible: Bool {
        return showProtein || showCarbs || showFat
    }
    
    /// Returns true if at least one food score is visible
    var anyFoodScoreVisible: Bool {
        return showNovaScore || showNutriScore
    }
    
    // MARK: - Initialization
    
    private init() {
        // Compute keys inline to avoid 'self' usage before initialization
        let userId = FirebaseAuthService.shared.currentUser?.id
        let localUserId = UserDefaults.standard.string(forKey: "current_user_id")
        
        let caloriesKey = userId.map { "metricVisibility_calories_\($0)" } ?? localUserId.map { "metricVisibility_calories_\($0)" } ?? "metricVisibility_calories_default"
        let proteinKey = userId.map { "metricVisibility_protein_\($0)" } ?? localUserId.map { "metricVisibility_protein_\($0)" } ?? "metricVisibility_protein_default"
        let carbsKey = userId.map { "metricVisibility_carbs_\($0)" } ?? localUserId.map { "metricVisibility_carbs_\($0)" } ?? "metricVisibility_carbs_default"
        let fatKey = userId.map { "metricVisibility_fat_\($0)" } ?? localUserId.map { "metricVisibility_fat_\($0)" } ?? "metricVisibility_fat_default"
        let novaScoreKey = userId.map { "metricVisibility_novaScore_\($0)" } ?? localUserId.map { "metricVisibility_novaScore_\($0)" } ?? "metricVisibility_novaScore_default"
        let nutriScoreKey = userId.map { "metricVisibility_nutriScore_\($0)" } ?? localUserId.map { "metricVisibility_nutriScore_\($0)" } ?? "metricVisibility_nutriScore_default"
        
        // Load saved preferences or use defaults (all visible by default)
        self.showCalories = UserDefaults.standard.object(forKey: caloriesKey) as? Bool ?? true
        self.showProtein = UserDefaults.standard.object(forKey: proteinKey) as? Bool ?? true
        self.showCarbs = UserDefaults.standard.object(forKey: carbsKey) as? Bool ?? true
        self.showFat = UserDefaults.standard.object(forKey: fatKey) as? Bool ?? true
        self.showNovaScore = UserDefaults.standard.object(forKey: novaScoreKey) as? Bool ?? true
        self.showNutriScore = UserDefaults.standard.object(forKey: nutriScoreKey) as? Bool ?? true
        
        setupAuthenticationObservers()
    }
    
    // Set up authentication notification observers
    private func setupAuthenticationObservers() {
        NotificationCenter.default.publisher(for: .userDidSignIn)
            .sink { [weak self] _ in
                self?.loadPreferences()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .userDidSignOut)
            .sink { [weak self] _ in
                self?.loadPreferences()
            }
            .store(in: &cancellables)
    }
    
    // Load preferences for current user
    private func loadPreferences() {
        showCalories = UserDefaults.standard.object(forKey: caloriesKey) as? Bool ?? true
        showProtein = UserDefaults.standard.object(forKey: proteinKey) as? Bool ?? true
        showCarbs = UserDefaults.standard.object(forKey: carbsKey) as? Bool ?? true
        showFat = UserDefaults.standard.object(forKey: fatKey) as? Bool ?? true
        showNovaScore = UserDefaults.standard.object(forKey: novaScoreKey) as? Bool ?? true
        showNutriScore = UserDefaults.standard.object(forKey: nutriScoreKey) as? Bool ?? true
    }
    
    // MARK: - Reset Methods
    
    /// Reset all metrics to visible
    func resetToDefaults() {
        showCalories = true
        showProtein = true
        showCarbs = true
        showFat = true
        showNovaScore = true
        showNutriScore = true
    }
}
