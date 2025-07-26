import Foundation
import Combine

class UserProfile: ObservableObject {
    // Singleton instance
    static let shared = UserProfile()
    
    // Personal Information
    @Published var age: Int = UserDefaults.standard.integer(forKey: "userAge") {
        didSet { UserDefaults.standard.set(age, forKey: "userAge") }
    }
    
    @Published var gender: Gender = Gender(rawValue: UserDefaults.standard.string(forKey: "userGender") ?? "") ?? .notSpecified {
        didSet { UserDefaults.standard.set(gender.rawValue, forKey: "userGender") }
    }
    
    @Published var heightCm: Double = UserDefaults.standard.double(forKey: "userHeightCm") {
        didSet { UserDefaults.standard.set(heightCm, forKey: "userHeightCm") }
    }
    
    @Published var weightKg: Double = UserDefaults.standard.double(forKey: "userWeightKg") {
        didSet { UserDefaults.standard.set(weightKg, forKey: "userWeightKg") }
    }
    
    @Published var activityLevel: ActivityLevel = ActivityLevel(rawValue: UserDefaults.standard.string(forKey: "userActivityLevel") ?? "") ?? .moderate {
        didSet { UserDefaults.standard.set(activityLevel.rawValue, forKey: "userActivityLevel") }
    }
    
    // Weight Goals
    @Published var weightGoalType: WeightGoalType = WeightGoalType(rawValue: UserDefaults.standard.string(forKey: "weightGoalType") ?? "") ?? .maintain {
        didSet { 
            UserDefaults.standard.set(weightGoalType.rawValue, forKey: "weightGoalType")
            updateNutritionGoals()
        }
    }
    
    @Published var weeklyWeightChangeKg: Double = UserDefaults.standard.double(forKey: "weeklyWeightChangeKg") > 0 ? UserDefaults.standard.double(forKey: "weeklyWeightChangeKg") : 0.5 {
        didSet { 
            UserDefaults.standard.set(weeklyWeightChangeKg, forKey: "weeklyWeightChangeKg") 
            updateNutritionGoals()
        }
    }
    
    // Nutrition Goals
    @Published var dailyCalorieGoal: Int = UserDefaults.standard.integer(forKey: "dailyCalorieGoal") {
        didSet { UserDefaults.standard.set(dailyCalorieGoal, forKey: "dailyCalorieGoal") }
    }
    
    @Published var proteinPercentage: Int = UserDefaults.standard.integer(forKey: "proteinPercentage") {
        didSet { 
            UserDefaults.standard.set(proteinPercentage, forKey: "proteinPercentage") 
            updateMacroGoals()
        }
    }
    
    @Published var carbPercentage: Int = UserDefaults.standard.integer(forKey: "carbPercentage") {
        didSet { 
            UserDefaults.standard.set(carbPercentage, forKey: "carbPercentage") 
            updateMacroGoals()
        }
    }
    
    @Published var fatPercentage: Int = UserDefaults.standard.integer(forKey: "fatPercentage") {
        didSet { 
            UserDefaults.standard.set(fatPercentage, forKey: "fatPercentage") 
            updateMacroGoals()
        }
    }
    
    @Published var proteinGoalGrams: Int = UserDefaults.standard.integer(forKey: "proteinGoalGrams") {
        didSet { UserDefaults.standard.set(proteinGoalGrams, forKey: "proteinGoalGrams") }
    }
    
    @Published var carbGoalGrams: Int = UserDefaults.standard.integer(forKey: "carbGoalGrams") {
        didSet { UserDefaults.standard.set(carbGoalGrams, forKey: "carbGoalGrams") }
    }
    
    @Published var fatGoalGrams: Int = UserDefaults.standard.integer(forKey: "fatGoalGrams") {
        didSet { UserDefaults.standard.set(fatGoalGrams, forKey: "fatGoalGrams") }
    }
    
    // Water goal in liters
    @Published var waterGoalLiters: Double = UserDefaults.standard.double(forKey: "waterGoalLiters") {
        didSet { UserDefaults.standard.set(waterGoalLiters, forKey: "waterGoalLiters") }
    }
    
    private init() {
        // Set safe default values immediately to prevent any potential crashes
        
        // Default personal information
        if age <= 0 {
            age = 30
        }
        
        if heightCm <= 0 {
            heightCm = 170.0
        }
        
        if weightKg <= 0 {
            weightKg = 70.0
        }
        
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
