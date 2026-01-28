import SwiftUI
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// Firebase Profile Service for user profile data
class FirebaseProfileService: ObservableObject {
    static let shared = FirebaseProfileService()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif
    
    private init() {}
    
    // MARK: - Profile Management
    
    func saveUserProfile(_ profileData: [String: Any], userId: String, completion: @escaping (Bool) -> Void) {
        print("[FirebaseProfile] Saving profile for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        
        // Add timestamp
        var data = profileData
        data["updated_at"] = FieldValue.serverTimestamp()
        
        let docRef = db.collection("users").document(userId).collection("profile").document("settings")
        
        docRef.setData(data, merge: true) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[FirebaseProfile] ❌ Save error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("[FirebaseProfile] ✅ Profile saved successfully")
                    completion(true)
                }
            }
        }
        #else
        // Fallback when Firebase is not available
        print("[FirebaseProfile] Firebase not available, using local storage only")
        completion(true)
        #endif
    }
    
    func fetchUserProfile(userId: String, completion: @escaping ([String: Any]?) -> Void) {
        print("[FirebaseProfile] Fetching profile for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        
        let docRef = db.collection("users").document(userId).collection("profile").document("settings")
        
        docRef.getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[FirebaseProfile] ❌ Fetch error: \(error.localizedDescription)")
                    completion(nil)
                } else if let document = document, document.exists {
                    let data = document.data()
                    print("[FirebaseProfile] ✅ Profile fetched successfully")
                    completion(data)
                } else {
                    print("[FirebaseProfile] No profile document found")
                    completion(nil)
                }
            }
        }
        #else
        // Fallback when Firebase is not available
        print("[FirebaseProfile] Firebase not available")
        completion(nil)
        #endif
    }
    
    func deleteUserProfile(userId: String, completion: @escaping (Bool) -> Void) {
        print("[FirebaseProfile] Deleting profile for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        
        let docRef = db.collection("users").document(userId).collection("profile").document("settings")
        
        docRef.delete { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[FirebaseProfile] ❌ Delete error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("[FirebaseProfile] ✅ Profile deleted successfully")
                    completion(true)
                }
            }
        }
        #else
        // Fallback when Firebase is not available
        completion(true)
        #endif
    }
    
    // MARK: - Real-time Profile Listener
    
    func listenToUserProfile(userId: String, completion: @escaping ([String: Any]?) -> Void) -> ListenerRegistration? {
        print("[FirebaseProfile] Setting up real-time listener for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        let docRef = db.collection("users").document(userId).collection("profile").document("settings")
        
        let listener = docRef.addSnapshotListener { document, error in
            if let error = error {
                print("[FirebaseProfile] ❌ Listener error: \(error.localizedDescription)")
                completion(nil)
            } else if let document = document, document.exists {
                let data = document.data()
                print("[FirebaseProfile] 🔄 Profile updated via listener")
                completion(data)
            } else {
                print("[FirebaseProfile] No profile document in listener")
                completion(nil)
            }
        }
        
        return listener
        #else
        // Fallback when Firebase is not available
        return nil
        #endif
    }
    
    // MARK: - Batch Operations
    
    func batchUpdateProfile(userId: String, updates: [[String: Any]], completion: @escaping (Bool) -> Void) {
        print("[FirebaseProfile] Batch updating profile for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        
        let batch = db.batch()
        let docRef = db.collection("users").document(userId).collection("profile").document("settings")
        
        for update in updates {
            var data = update
            data["updated_at"] = FieldValue.serverTimestamp()
            batch.setData(data, forDocument: docRef, merge: true)
        }
        
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[FirebaseProfile] ❌ Batch update error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("[FirebaseProfile] ✅ Batch update successful")
                    completion(true)
                }
            }
        }
        #else
        // Fallback when Firebase is not available
        completion(true)
        #endif
    }
}

// MARK: - Profile Data Models

struct FirebaseProfileData {
    let heightCm: Double?
    let weightKg: Double?
    let age: Int?
    let gender: String?
    let activityLevel: String?
    let calorieTarget: Int?
    let proteinGoalGrams: Double?
    let carbGoalGrams: Double?
    let fatGoalGrams: Double?
    let waterGoalLiters: Double?
    let proteinPercentage: Double?
    let carbPercentage: Double?
    let fatPercentage: Double?
    let updatedAt: Date?
    
    init(from data: [String: Any]) {
        self.heightCm = data["height_cm"] as? Double
        self.weightKg = data["weight_kg"] as? Double
        self.age = data["age"] as? Int
        self.gender = data["gender"] as? String
        self.activityLevel = data["activity_level"] as? String
        self.calorieTarget = data["calorie_target"] as? Int
        self.proteinGoalGrams = data["protein_goal_grams"] as? Double
        self.carbGoalGrams = data["carb_goal_grams"] as? Double
        self.fatGoalGrams = data["fat_goal_grams"] as? Double
        self.waterGoalLiters = data["water_goal_liters"] as? Double
        self.proteinPercentage = data["protein_percentage"] as? Double
        self.carbPercentage = data["carb_percentage"] as? Double
        self.fatPercentage = data["fat_percentage"] as? Double
        
        #if canImport(FirebaseFirestore)
        if let timestamp = data["updated_at"] as? Timestamp {
            self.updatedAt = timestamp.dateValue()
        } else {
            self.updatedAt = nil
        }
        #else
        self.updatedAt = nil
        #endif
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let heightCm = heightCm { dict["height_cm"] = heightCm }
        if let weightKg = weightKg { dict["weight_kg"] = weightKg }
        if let age = age { dict["age"] = age }
        if let gender = gender { dict["gender"] = gender }
        if let activityLevel = activityLevel { dict["activity_level"] = activityLevel }
        if let calorieTarget = calorieTarget { dict["calorie_target"] = calorieTarget }
        if let proteinGoalGrams = proteinGoalGrams { dict["protein_goal_grams"] = proteinGoalGrams }
        if let carbGoalGrams = carbGoalGrams { dict["carb_goal_grams"] = carbGoalGrams }
        if let fatGoalGrams = fatGoalGrams { dict["fat_goal_grams"] = fatGoalGrams }
        if let waterGoalLiters = waterGoalLiters { dict["water_goal_liters"] = waterGoalLiters }
        if let proteinPercentage = proteinPercentage { dict["protein_percentage"] = proteinPercentage }
        if let carbPercentage = carbPercentage { dict["carb_percentage"] = carbPercentage }
        if let fatPercentage = fatPercentage { dict["fat_percentage"] = fatPercentage }
        
        return dict
    }
}
