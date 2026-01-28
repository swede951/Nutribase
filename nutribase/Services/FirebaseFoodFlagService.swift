import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

class FirebaseFoodFlagService {
    static let shared = FirebaseFoodFlagService()
    
    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif
    
    #if canImport(FirebaseFunctions)
    private let functions = Functions.functions()
    #endif
    
    enum FlagIssue: String, CaseIterable {
        case incorrectNutrition = "Incorrect nutrition information"
        case wrongServingSize = "Wrong serving sizes"
        case duplicate = "Duplicate entry"
        case misleadingInfo = "Misleading name or brand"
        case missingInfo = "Missing information"
        case other = "Other issue"
    }
    
    struct FoodFlag: Codable, Identifiable {
        var id: String?
        let userId: String?
        let foodId: String
        let foodName: String
        let brand: String?
        let barcode: String?
        let issueType: String
        let details: String?
        let status: String
        let createdAt: Date
        var reviewedAt: Date?
        var reviewedBy: String?
        var resolutionNotes: String?
    }
    
    // MARK: - Submit Flag (via Cloud Function for security)
    
    func submitFlag(
        foodId: String,
        foodName: String,
        brand: String?,
        barcode: String?,
        issueType: FlagIssue,
        details: String?
    ) async throws {
        #if canImport(FirebaseFunctions) && canImport(FirebaseAuth)
        let userId = Auth.auth().currentUser?.uid ?? "anonymous"
        
        let flagData: [String: Any] = [
            "userId": userId,
            "foodId": foodId,
            "foodName": foodName,
            "brand": brand ?? "",
            "barcode": barcode ?? "",
            "issueType": issueType.rawValue,
            "details": details ?? ""
        ]
        
        do {
            // Call Cloud Function instead of writing directly to Firestore
            let result = try await functions.httpsCallable("submitFoodFlag").call(flagData)
            
            if let response = result.data as? [String: Any],
               let success = response["success"] as? Bool,
               success {
                print("✅ Food flag submitted successfully")
                
                // Track analytics
                AnalyticsService.shared.trackEvent(
                    "food_flagged",
                    parameters: [
                        "issue_type": issueType.rawValue,
                        "has_details": details != nil && !details!.isEmpty
                    ]
                )
            } else {
                throw NSError(domain: "FirebaseFoodFlagService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to submit flag"])
            }
        } catch {
            print("❌ Error submitting food flag: \(error.localizedDescription)")
            throw error
        }
        #else
        throw NSError(domain: "FirebaseFoodFlagService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase Functions not available"])
        #endif
    }
    
    // MARK: - Get User's Flags
    
    func getUserFlags() async throws -> [FoodFlag] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseFoodFlagService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let snapshot = try await db.collection("food_flags")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> FoodFlag? in
            try? doc.data(as: FoodFlag.self)
        }
    }
    
    // MARK: - Get Pending Flags (Admin Only)
    
    func getPendingFlags() async throws -> [FoodFlag] {
        let snapshot = try await db.collection("food_flags")
            .whereField("status", isEqualTo: "pending")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> FoodFlag? in
            var flag = try? doc.data(as: FoodFlag.self)
            flag?.id = doc.documentID
            return flag
        }
    }
    
    // MARK: - Get Flags for Specific Food
    
    func getFlagsForFood(foodId: String) async throws -> [FoodFlag] {
        let snapshot = try await db.collection("food_flags")
            .whereField("foodId", isEqualTo: foodId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> FoodFlag? in
            try? doc.data(as: FoodFlag.self)
        }
    }
    
    // MARK: - Update Flag Status (Admin Only)
    
    func updateFlagStatus(
        flagId: String,
        status: String,
        resolutionNotes: String?
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseFoodFlagService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        var updateData: [String: Any] = [
            "status": status,
            "reviewedAt": FieldValue.serverTimestamp(),
            "reviewedBy": userId
        ]
        
        if let notes = resolutionNotes {
            updateData["resolutionNotes"] = notes
        }
        
        try await db.collection("food_flags").document(flagId).updateData(updateData)
        print("✅ Flag \(flagId) updated to status: \(status)")
    }
    
    // MARK: - Get Flag Statistics
    
    func getFlagStatistics() async throws -> [String: Int] {
        let snapshot = try await db.collection("food_flags").getDocuments()
        
        var stats: [String: Int] = [
            "total": snapshot.documents.count,
            "pending": 0,
            "resolved": 0,
            "dismissed": 0
        ]
        
        for doc in snapshot.documents {
            if let status = doc.data()["status"] as? String {
                stats[status, default: 0] += 1
            }
        }
        
        return stats
    }
    
    // MARK: - Get Most Flagged Foods
    
    func getMostFlaggedFoods(limit: Int = 10) async throws -> [(foodId: String, foodName: String, count: Int)] {
        let snapshot = try await db.collection("food_flags")
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        
        // Group by foodId and count
        var foodCounts: [String: (name: String, count: Int)] = [:]
        
        for doc in snapshot.documents {
            if let foodId = doc.data()["foodId"] as? String,
               let foodName = doc.data()["foodName"] as? String {
                if foodCounts[foodId] != nil {
                    foodCounts[foodId]?.count += 1
                } else {
                    foodCounts[foodId] = (name: foodName, count: 1)
                }
            }
        }
        
        // Sort by count and return top N
        return foodCounts
            .map { (foodId: $0.key, foodName: $0.value.name, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }
}
