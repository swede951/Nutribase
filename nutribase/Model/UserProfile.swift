import Foundation
import Combine

class UserProfile: ObservableObject {
    // Singleton instance
    static let shared = UserProfile()
    
    // Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // Timer for debouncing saves
    private var saveTimer: Timer?
    
    // Current user identifier for local storage
    private var currentUserId: String {
        // Try to get user ID from UserDefaults, or create a new one
        if let existingId = UserDefaults.standard.string(forKey: "current_user_id") {
            return existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "current_user_id")
            return newId
        }
    }
    
    // Helper method to get user-specific UserDefaults key
    private func userSpecificKey(_ baseKey: String) -> String {
        if UserDefaults.standard.bool(forKey: "guest_mode") {
            return "\(baseKey)_guest"
        } else if let authenticatedUser = SimpleAuthService.shared.currentUser {
            // Use Supabase user ID for authenticated users
            return "\(baseKey)_\(authenticatedUser.id)"
        } else {
            // Fallback to local UUID for users not yet authenticated
            return "\(baseKey)_\(currentUserId)"
        }
    }
    
    // Personal Information
    @Published var age: Int = 30 {
        didSet { 
            UserDefaults.standard.set(age, forKey: userSpecificKey("userAge"))
            saveToLocalStorageIfNeeded()
        }
    }
    
    @Published var gender: Gender = .notSpecified {
        didSet { 
            UserDefaults.standard.set(gender.rawValue, forKey: userSpecificKey("userGender"))
            saveToLocalStorageIfNeeded()
        }
    }
    
    @Published var heightCm: Double = 170.0 {
        didSet { 
            UserDefaults.standard.set(heightCm, forKey: userSpecificKey("userHeightCm"))
            saveToLocalStorageIfNeeded()
        }
    }
    
    @Published var weightKg: Double = 70.0 {
        didSet { 
            UserDefaults.standard.set(weightKg, forKey: userSpecificKey("userWeightKg"))
            saveToLocalStorageIfNeeded()
        }
    }
    
    @Published var activityLevel: ActivityLevel = .moderate {
        didSet { 
            UserDefaults.standard.set(activityLevel.rawValue, forKey: userSpecificKey("userActivityLevel"))
            saveToLocalStorageIfNeeded()
        }
    }
    
    // Weight Goals
    @Published var weightGoalType: WeightGoalType = .maintain {
        didSet { 
            UserDefaults.standard.set(weightGoalType.rawValue, forKey: userSpecificKey("weightGoalType"))
            updateNutritionGoals()
            saveToLocalStorageIfNeeded()
        }
    }
    
    @Published var weeklyWeightChangeKg: Double = 0.5 {
        didSet { 
            UserDefaults.standard.set(weeklyWeightChangeKg, forKey: userSpecificKey("weeklyWeightChangeKg"))
            updateNutritionGoals()
            saveToLocalStorageIfNeeded()
        }
    }
    
    // Nutrition Goals
    @Published var dailyCalorieGoal: Int = 2000 {
        didSet { 
            UserDefaults.standard.set(dailyCalorieGoal, forKey: userSpecificKey("dailyCalorieGoal"))
            saveToLocalStorageIfNeeded()
        }
    }
    
    @Published var proteinPercentage: Int = 25 {
        didSet { 
            UserDefaults.standard.set(proteinPercentage, forKey: userSpecificKey("proteinPercentage"))
            updateMacroGoals()
            saveToLocalStorageIfNeeded()
        }
    }
    
    @Published var carbPercentage: Int = 45 {
        didSet { 
            UserDefaults.standard.set(carbPercentage, forKey: userSpecificKey("carbPercentage"))
            updateMacroGoals()
            saveToLocalStorageIfNeeded()
        }
    }
    
    @Published var fatPercentage: Int = 30 {
        didSet { 
            UserDefaults.standard.set(fatPercentage, forKey: userSpecificKey("fatPercentage"))
            updateMacroGoals()
            saveToLocalStorageIfNeeded()
        }
    }
    
    @Published var proteinGoalGrams: Int = 125 {
        didSet { 
            UserDefaults.standard.set(proteinGoalGrams, forKey: userSpecificKey("proteinGoalGrams"))
            saveToLocalStorageIfNeeded()
        }
    }
    
    @Published var carbGoalGrams: Int = 225 {
        didSet { 
            UserDefaults.standard.set(carbGoalGrams, forKey: userSpecificKey("carbGoalGrams"))
            saveToLocalStorageIfNeeded()
        }
    }
    
    @Published var fatGoalGrams: Int = 67 {
        didSet { 
            UserDefaults.standard.set(fatGoalGrams, forKey: userSpecificKey("fatGoalGrams"))
            saveToLocalStorageIfNeeded()
        }
    }
    
    // Water goal in liters
    @Published var waterGoalLiters: Double = 2.5 {
        didSet { 
            UserDefaults.standard.set(waterGoalLiters, forKey: userSpecificKey("waterGoalLiters"))
            saveToLocalStorageIfNeeded()
        }
    }
    
    private init() {
        // Load user-specific data from UserDefaults
        loadFromUserDefaults()
        
        // Setup authentication notification observers
        setupAuthenticationObservers()
        
        // Default macro percentages
        if proteinPercentage <= 0 {
            proteinPercentage = 30
        }
        
        if carbPercentage <= 0 {
            carbPercentage = 40
        }
        
        if fatPercentage <= 0 {
            fatPercentage = 30
        }
        
        // Default nutrition goals
        if dailyCalorieGoal <= 0 {
            dailyCalorieGoal = 2000
        }
        
        if proteinGoalGrams <= 0 {
            proteinGoalGrams = 150
        }
        
        if carbGoalGrams <= 0 {
            carbGoalGrams = 200
        }
        
        if fatGoalGrams <= 0 {
            fatGoalGrams = 67
        }
        
        // Do not calculate TDEE during initialization to prevent potential crashes
        // Instead, we'll set reasonable defaults and let the user update their info later
    }
    
    // Calculate TDEE based on personal information and update goals
    func calculateTDEE() {
        let tdee = calculateTDEEOnly()
        
        // Update calorie goal based on TDEE
        updateNutritionGoals(basedOn: tdee)
    }
    
    // Calculate TDEE without updating goals (to avoid recursion)
    private func calculateTDEEOnly() -> Int {
        // Calculate BMR using Mifflin-St Jeor Equation
        var bmr: Double
        
        switch gender {
        case .male:
            bmr = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
        case .female:
            bmr = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
        case .notSpecified:
            // Use average of male and female equations
            let maleBMR = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
            let femaleBMR = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
            bmr = (maleBMR + femaleBMR) / 2
        }
        
        // Apply activity multiplier
        return Int(bmr * activityLevel.multiplier)
    }
    
    // Update nutrition goals based on TDEE and weight goals
    private func updateNutritionGoals(basedOn tdee: Int? = nil) {
        // Use provided TDEE or calculate from scratch
        let calculatedTDEE: Int
        if let tdee = tdee, tdee > 0 {
            calculatedTDEE = tdee
        } else {
            // Calculate TDEE without updating goals to avoid recursion
            calculatedTDEE = max(calculateTDEEOnly(), 1500) // Ensure minimum value
        }
        
        // Calculate new calorie goal based on weight goal type
        var newCalorieGoal = calculatedTDEE
        
        // If weekly weight change is 0 or very close to 0, just maintain
        if abs(weeklyWeightChangeKg) < 0.01 {
            // No adjustment needed, maintain current weight
            newCalorieGoal = calculatedTDEE
        } else {
            // 1kg of body fat ≈ 7700 calories, so for weekly changes:
            // Calculate daily calorie adjustment
            let safeWeeklyChange = max(min(abs(weeklyWeightChangeKg), 1.0), 0.1) // Limit to reasonable range
            let calorieAdjustment = Int(safeWeeklyChange * 7700 / 7) // 7700 calories per kg / 7 days
            
            switch weightGoalType {
            case .lose:
                newCalorieGoal = calculatedTDEE - calorieAdjustment
            case .gain:
                newCalorieGoal = calculatedTDEE + calorieAdjustment
            case .maintain:
                newCalorieGoal = calculatedTDEE
            }
        }
        
        // Ensure calorie goal is reasonable (at least 1200 calories)
        dailyCalorieGoal = max(newCalorieGoal, 1200)
        
        // Update macro goals based on new calorie goal
        // Use async to prevent UI freezes
        DispatchQueue.main.async {
            self.updateMacroGoals()
        }
        
        // Note: Notification is now posted inside updateMacroGoals to avoid duplicate notifications
    }
    
    // Update macro goals based on calorie goal and percentages
    private func updateMacroGoals() {
        // Prevent recursive calls
        DispatchQueue.main.async {
            // Ensure percentages add up to 100%
            let totalPercentage = self.proteinPercentage + self.carbPercentage + self.fatPercentage
            
            // If total is 0 or not 100%, set default values
            if totalPercentage == 0 {
                self.proteinPercentage = 30
                self.carbPercentage = 40
                self.fatPercentage = 30
            } else if totalPercentage != 100 {
                // Adjust percentages proportionally
                self.proteinPercentage = Int(Double(self.proteinPercentage) / Double(totalPercentage) * 100)
                self.carbPercentage = Int(Double(self.carbPercentage) / Double(totalPercentage) * 100)
                self.fatPercentage = 100 - self.proteinPercentage - self.carbPercentage
            }
            
            // Ensure we have a positive calorie goal
            let safeCalorieGoal = max(self.dailyCalorieGoal, 1500) // Use 1500 as minimum if goal is 0 or negative
            
            // Calculate macro goals in grams with safety checks
            // Protein: 4 calories per gram
            if self.proteinPercentage > 0 {
                self.proteinGoalGrams = (safeCalorieGoal * self.proteinPercentage) / (100 * 4)
            } else {
                self.proteinGoalGrams = 0
            }
            
            // Carbs: 4 calories per gram
            if self.carbPercentage > 0 {
                self.carbGoalGrams = (safeCalorieGoal * self.carbPercentage) / (100 * 4)
            } else {
                self.carbGoalGrams = 0
            }
            
            // Fat: 9 calories per gram
            if self.fatPercentage > 0 {
                self.fatGoalGrams = (safeCalorieGoal * self.fatPercentage) / (100 * 9)
            } else {
                self.fatGoalGrams = 0
            }
            
            // Post notification that nutrition goals have been updated
            NotificationCenter.default.post(name: .nutritionGoalsUpdated, object: nil)
        }
    }
    
    // Save profile to Supabase
    private func saveToSupabaseIfAuthenticated() {
        // Only save if user is authenticated
        guard let currentUser = SimpleAuthService.shared.currentUser else {
            print("[UserProfile] Not authenticated - skipping Supabase save")
            return
        }
        
        print("[UserProfile] Saving profile to Supabase for user: \(currentUser.id)")
        
        // Save profile data matching exact Supabase schema
        let profileData: [String: Any] = [
            "user_id": currentUser.id,
            "age": age,
            "gender": gender.rawValue,
            "height_cm": heightCm,
            "weight_kg": weightKg,
            "activity_level": activityLevel.rawValue,
            "target_weight_kg": weightKg,
            "daily_calorie_target": dailyCalorieGoal,
            "weekly_weight_goal": weeklyWeightChangeKg,
            "protein_percentage": proteinPercentage,
            "carb_percentage": carbPercentage,
            "fat_percentage": fatPercentage,
            "protein_goal_grams": proteinGoalGrams,
            "carb_goal_grams": carbGoalGrams,
            "fat_goal_grams": fatGoalGrams,
            "water_goal_liters": waterGoalLiters
        ]
        
        SupabaseService.shared.saveUserProfile(profileData) { success in
            if success {
                print("✅ Profile synced to Supabase")
            } else {
                print("❌ Failed to sync profile")
            }
        }
    }
    
    // Load profile from Supabase
    func fetchFromSupabase() {
        print("[UserProfile] Fetching profile from Supabase...")
        
        SupabaseService.shared.loadUserProfile { [weak self] profileData in
            guard let self = self, let data = profileData else {
                print("❌ No profile data found")
                return
            }
            
            self.updateFromProfileData(data)
        }
    }
    
    // Update profile from Supabase data
    
    private func updateFromProfileData(_ data: [String: Any]) {
        print("[UserProfile] Updating from Supabase data: \(data)")
        
        if let age = data["age"] as? Int { 
            print("[UserProfile] Setting age: \(age)")
            self.age = age 
        }
        if let genderString = data["gender"] as? String, let gender = Gender(rawValue: genderString) { 
            print("[UserProfile] Setting gender: \(gender)")
            self.gender = gender 
        }
        if let height = data["height_cm"] as? Double { 
            print("[UserProfile] Setting height: \(height)")
            self.heightCm = height 
        }
        if let weight = data["weight_kg"] as? Double { 
            print("[UserProfile] Setting weight: \(weight)")
            self.weightKg = weight 
        }
        if let activityString = data["activity_level"] as? String, let activity = ActivityLevel(rawValue: activityString) { 
            print("[UserProfile] Setting activity: \(activity)")
            self.activityLevel = activity 
        }
        if let weeklyChange = data["weekly_weight_goal"] as? Double { 
            print("[UserProfile] Setting weekly change: \(weeklyChange)")
            self.weeklyWeightChangeKg = weeklyChange 
        }
        if let calories = data["daily_calorie_target"] as? Int { 
            print("[UserProfile] Setting calories: \(calories)")
            self.dailyCalorieGoal = calories 
        }
        if let protein = data["protein_percentage"] as? Int { self.proteinPercentage = protein }
        if let carbs = data["carb_percentage"] as? Int { self.carbPercentage = carbs }
        if let fat = data["fat_percentage"] as? Int { self.fatPercentage = fat }
        if let proteinGoal = data["protein_goal_grams"] as? Int { self.proteinGoalGrams = proteinGoal }
        if let carbGoal = data["carb_goal_grams"] as? Int { self.carbGoalGrams = carbGoal }
        if let fatGoal = data["fat_goal_grams"] as? Int { self.fatGoalGrams = fatGoal }
        if let water = data["water_goal_liters"] as? Double { self.waterGoalLiters = water }
        
        print("✅ Profile updated from Supabase")
    }

    // Authentication event handlers
    private func setupAuthenticationObservers() {
        // Listen for sign-in events
        NotificationCenter.default.addObserver(
            forName: .userDidSignIn,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[UserProfile] User signed in - switching to authenticated mode")
            self?.handleUserSignIn()
        }
        // Listen for sign-out events
        NotificationCenter.default.publisher(for: .userDidSignOut)
            .sink { [weak self] _ in
                print("[UserProfile] User signed out - switching to guest mode")
                self?.handleUserSignOut()
            }
            .store(in: &cancellables)
    }
    
    private func handleUserSignIn() {
        // Switch to authenticated mode (no longer using local UUID system)
        UserDefaults.standard.set(false, forKey: "guest_mode")
        UserDefaults.standard.removeObject(forKey: "current_user_id") // Remove local UUID
        
        // Clear current data and load user-specific data
        clearCurrentUserData()
        loadFromUserDefaults()
        
        // Fetch profile from Supabase after a delay to ensure authentication is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.fetchFromSupabase()
        }
        
        print("[UserProfile] User signed in - switched to authenticated mode")
    }
    
    private func handleUserSignOut() {
        // Switch to guest mode
        UserDefaults.standard.set(true, forKey: "guest_mode")
        UserDefaults.standard.removeObject(forKey: "current_user_id")
        
        // Clear current data and load guest data
        clearCurrentUserData()
        loadFromUserDefaults()
        
        print("User signed out - switched to guest mode")
    }
    
    private func clearCurrentUserData() {
        // Reset to default values without triggering UserDefaults saves
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Temporarily disable auto-save during reset
            self.age = 30
            self.gender = .notSpecified
            self.heightCm = 170.0
            self.weightKg = 70.0
            self.activityLevel = .moderate
            self.weightGoalType = .maintain
            self.weeklyWeightChangeKg = 0.5
            self.dailyCalorieGoal = 2000
            self.proteinPercentage = 25
            self.carbPercentage = 45
            self.fatPercentage = 30
            self.proteinGoalGrams = 125
            self.carbGoalGrams = 225
            self.fatGoalGrams = 67
            self.waterGoalLiters = 2.5
        }
    }
    
    private func loadFromUserDefaults() {
        // Load values from user-specific UserDefaults keys
        let loadedAge = UserDefaults.standard.integer(forKey: userSpecificKey("userAge"))
        if loadedAge > 0 { age = loadedAge }
        
        if let genderString = UserDefaults.standard.string(forKey: userSpecificKey("userGender")),
           let genderEnum = Gender(rawValue: genderString) {
            gender = genderEnum
        }
        
        let loadedHeight = UserDefaults.standard.double(forKey: userSpecificKey("userHeightCm"))
        if loadedHeight > 0 { heightCm = loadedHeight }
        
        let loadedWeight = UserDefaults.standard.double(forKey: userSpecificKey("userWeightKg"))
        if loadedWeight > 0 { weightKg = loadedWeight }
        
        if let activityString = UserDefaults.standard.string(forKey: userSpecificKey("userActivityLevel")),
           let activityEnum = ActivityLevel(rawValue: activityString) {
            activityLevel = activityEnum
        }
        
        if let goalTypeString = UserDefaults.standard.string(forKey: userSpecificKey("weightGoalType")),
           let goalEnum = WeightGoalType(rawValue: goalTypeString) {
            weightGoalType = goalEnum
        }
        
        let loadedWeeklyChange = UserDefaults.standard.double(forKey: userSpecificKey("weeklyWeightChangeKg"))
        // Check if the key exists (UserDefaults returns 0.0 for non-existent keys)
        if UserDefaults.standard.object(forKey: userSpecificKey("weeklyWeightChangeKg")) != nil {
            weeklyWeightChangeKg = loadedWeeklyChange
        }
        
        let loadedCalorieGoal = UserDefaults.standard.integer(forKey: userSpecificKey("dailyCalorieGoal"))
        if loadedCalorieGoal > 0 { dailyCalorieGoal = loadedCalorieGoal }
        
        let loadedProteinPerc = UserDefaults.standard.integer(forKey: userSpecificKey("proteinPercentage"))
        if loadedProteinPerc > 0 { proteinPercentage = loadedProteinPerc }
        
        let loadedCarbPerc = UserDefaults.standard.integer(forKey: userSpecificKey("carbPercentage"))
        if loadedCarbPerc > 0 { carbPercentage = loadedCarbPerc }
        
        let loadedFatPerc = UserDefaults.standard.integer(forKey: userSpecificKey("fatPercentage"))
        if loadedFatPerc > 0 { fatPercentage = loadedFatPerc }
        
        let loadedProteinGoal = UserDefaults.standard.integer(forKey: userSpecificKey("proteinGoalGrams"))
        if loadedProteinGoal > 0 { proteinGoalGrams = loadedProteinGoal }
        
        let loadedCarbGoal = UserDefaults.standard.integer(forKey: userSpecificKey("carbGoalGrams"))
        if loadedCarbGoal > 0 { carbGoalGrams = loadedCarbGoal }
        
        let loadedFatGoal = UserDefaults.standard.integer(forKey: userSpecificKey("fatGoalGrams"))
        if loadedFatGoal > 0 { fatGoalGrams = loadedFatGoal }
        
        let loadedWaterGoal = UserDefaults.standard.double(forKey: userSpecificKey("waterGoalLiters"))
        if loadedWaterGoal > 0 { waterGoalLiters = loadedWaterGoal }
    }
    
    private func saveToLocalStorageIfNeeded() {
        // Debounce saves to avoid too many writes
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.saveToLocalStorage()
            self?.saveToSupabaseIfAuthenticated()
        }
    }
    
    private func saveToLocalStorage() {
        // All data is already being saved to UserDefaults via the @AppStorage properties
        // This method exists for consistency and future enhancements
        print("User profile data saved to local storage")
    }
    
    // Method to manually save profile (can be called from UI)
    func saveProfile() {
        saveToLocalStorage()
        print("Profile saved successfully to local storage")
    }
    
    // Method to manually load profile (can be called from UI)
    func loadProfile() {
        loadFromUserDefaults()
        print("Profile loaded from local storage")
    }
}
// Enums for user profile properties
enum Gender: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    case notSpecified = "Not Specified"
    
    var id: String { self.rawValue }
}

enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary = "Sedentary (little or no exercise)"
    case lightlyActive = "Lightly Active (light exercise 1-3 days/week)"
    case moderate = "Moderately Active (moderate exercise 3-5 days/week)"
    case veryActive = "Very Active (hard exercise 6-7 days/week)"
    case extraActive = "Extra Active (very hard exercise & physical job)"
    
    var id: String { self.rawValue }
    
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderate: return 1.55
        case .veryActive: return 1.725
        case .extraActive: return 1.9
        }
    }
}

enum WeightGoalType: String, CaseIterable, Identifiable {
    case lose = "Lose Weight"
    case maintain = "Maintain Weight"
    case gain = "Gain Weight"
    
    var id: String { self.rawValue }
}

// Notification name extension
extension Notification.Name {
    static let nutritionGoalsUpdated = Notification.Name("nutritionGoalsUpdated")
}
