import Foundation
import FirebaseFunctions

/// Response structure for AI-generated food nutrition data
struct AIFoodNutritionResponse: Codable {
    let servingSize: Double?
    let servingUnit: String?
    let servingsPerContainer: Double?
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let fiber: Double?
    let sugar: Double?
    let sodium: Double?
    let saturatedFat: Double?
    let transFat: Double?
    let cholesterol: Double?
    let potassium: Double?
    let calcium: Double?
    let iron: Double?
    let vitaminC: Double?
    let vitaminA: Double?
    let ingredients: String?
    let confidence: String? // "high", "medium", "low"
    
    enum CodingKeys: String, CodingKey {
        case servingSize = "serving_size"
        case servingUnit = "serving_unit"
        case servingsPerContainer = "servings_per_container"
        case calories, protein, carbs, fat, fiber, sugar, sodium
        case saturatedFat = "saturated_fat"
        case transFat = "trans_fat"
        case cholesterol, potassium, calcium, iron
        case vitaminC = "vitamin_c"
        case vitaminA = "vitamin_a"
        case ingredients, confidence
    }
}

/// Service for AI-powered food nutrition autofill using Firebase Cloud Functions
/// API key is securely stored server-side, not in the app
class AIFoodAutofillService: ObservableObject {
    static let shared = AIFoodAutofillService()
    
    @Published var isLoading = false
    @Published var lastError: String?
    
    // Firebase Functions reference
    private lazy var functions = Functions.functions()
    
    /// AI feature is always available (handled by Firebase)
    var hasAPIKey: Bool {
        // Always return true - the API key is managed server-side
        // Authentication is required by the Cloud Function
        return FirebaseAuthService.shared.isAuthenticated
    }
    
    /// Fetch nutrition data for a food item using AI via Firebase Cloud Function
    /// - Parameters:
    ///   - foodName: The name of the food
    ///   - brandName: Optional brand name
    ///   - barcode: Optional barcode
    ///   - completion: Callback with result or error
    func fetchNutritionData(
        foodName: String,
        brandName: String? = nil,
        barcode: String? = nil,
        completion: @escaping (Result<AIFoodNutritionResponse, Error>) -> Void
    ) {
        // Check if user is authenticated (required by Cloud Function)
        guard FirebaseAuthService.shared.isAuthenticated else {
            completion(.failure(AIFoodAutofillError.notAuthenticated))
            return
        }
        
        guard !foodName.isEmpty else {
            completion(.failure(AIFoodAutofillError.invalidInput("Food name is required")))
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.lastError = nil
        }
        
        print("🤖 AI Autofill: Requesting nutrition data for '\(foodName)' via Firebase")
        
        // Build request data for Cloud Function
        var requestData: [String: Any] = ["foodName": foodName]
        if let brand = brandName, !brand.isEmpty {
            requestData["brandName"] = brand
        }
        if let code = barcode, !code.isEmpty {
            requestData["barcode"] = code
        }
        
        // Call Firebase Cloud Function
        functions.httpsCallable("aiNutritionLookup").call(requestData) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
            }
            
            if let error = error {
                print("❌ AI Autofill: Firebase function error - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.lastError = error.localizedDescription
                    completion(.failure(error))
                }
                return
            }
            
            guard let resultData = result?.data as? [String: Any],
                  let success = resultData["success"] as? Bool,
                  success,
                  let nutritionDict = resultData["data"] as? [String: Any] else {
                let error = AIFoodAutofillError.invalidResponse
                DispatchQueue.main.async {
                    self?.lastError = error.localizedDescription
                    completion(.failure(error))
                }
                return
            }
            
            // Convert dictionary to AIFoodNutritionResponse
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: nutritionDict)
                let nutritionResponse = try JSONDecoder().decode(AIFoodNutritionResponse.self, from: jsonData)
                
                print("✅ AI Autofill: Successfully received nutrition data")
                print("   Serving: \(nutritionResponse.servingSize ?? 0) \(nutritionResponse.servingUnit ?? "?")")
                print("   Calories: \(nutritionResponse.calories ?? 0)")
                print("   Protein: \(nutritionResponse.protein ?? 0)g")
                print("   Carbs: \(nutritionResponse.carbs ?? 0)g")
                print("   Fat: \(nutritionResponse.fat ?? 0)g")
                print("   Confidence: \(nutritionResponse.confidence ?? "unknown")")
                
                DispatchQueue.main.async {
                    completion(.success(nutritionResponse))
                }
            } catch {
                print("❌ AI Autofill: Parse error - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.lastError = "Failed to parse response: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - Errors
enum AIFoodAutofillError: LocalizedError {
    case notAuthenticated
    case invalidInput(String)
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to use AI features."
        case .invalidInput(let message):
            return message
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return "AI error: \(message)"
        }
    }
}
