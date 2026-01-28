import Foundation
import FirebaseFunctions

/// Service for interacting with Typesense via Firebase Functions (secure)
/// This replaces direct Typesense API calls with Firebase Function proxies
class TypesenseCloudService {
    
    // MARK: - Singleton
    static let shared = TypesenseCloudService()
    
    private init() {}
    
    // MARK: - Properties
    private lazy var functions = Functions.functions()
    
    // MARK: - Search
    
    /// Search for foods using Firebase Function proxy
    func searchFoods(
        query: String,
        collection: String? = nil,
        filters: String? = nil,
        perPage: Int = 50,
        completion: @escaping (Result<TypesenseSearchResult, Error>) -> Void
    ) {
        var data: [String: Any] = [
            "query": query,
            "perPage": perPage
        ]
        
        if let collection = collection {
            data["collection"] = collection
        }
        
        if let filters = filters {
            data["filters"] = filters
        }
        
        functions.httpsCallable("typesenseSearch").call(data) { result, error in
            if let error = error {
                print("❌ TypesenseCloudService search error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let resultData = result?.data as? [String: Any],
                  let success = resultData["success"] as? Bool,
                  success else {
                completion(.failure(TypesenseCloudError.invalidResponse))
                return
            }
            
            let found = resultData["found"] as? Int ?? 0
            let hits = resultData["hits"] as? [[String: Any]] ?? []
            let searchTimeMs = resultData["search_time_ms"] as? Int ?? 0
            
            let searchResult = TypesenseSearchResult(
                found: found,
                hits: hits,
                searchTimeMs: searchTimeMs
            )
            
            print("✅ TypesenseCloudService search: \(found) results in \(searchTimeMs)ms")
            completion(.success(searchResult))
        }
    }
    
    /// Multi-search for two-lane ingredient/product search
    func multiSearch(
        searches: [[String: Any]],
        completion: @escaping (Result<[TypesenseSearchResult], Error>) -> Void
    ) {
        let data: [String: Any] = ["searches": searches]
        
        functions.httpsCallable("typesenseMultiSearch").call(data) { result, error in
            if let error = error {
                print("❌ TypesenseCloudService multi-search error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let resultData = result?.data as? [String: Any],
                  let success = resultData["success"] as? Bool,
                  success,
                  let results = resultData["results"] as? [[String: Any]] else {
                completion(.failure(TypesenseCloudError.invalidResponse))
                return
            }
            
            let searchResults = results.map { result -> TypesenseSearchResult in
                let found = result["found"] as? Int ?? 0
                let hits = result["hits"] as? [[String: Any]] ?? []
                let searchTimeMs = result["search_time_ms"] as? Int ?? 0
                return TypesenseSearchResult(found: found, hits: hits, searchTimeMs: searchTimeMs)
            }
            
            print("✅ TypesenseCloudService multi-search: \(searchResults.count) queries completed")
            completion(.success(searchResults))
        }
    }
    
    // MARK: - Popularity
    
    /// Increment popularity for a food (flywheel effect)
    func incrementPopularity(
        documentId: String,
        collection: String? = nil
    ) {
        var data: [String: Any] = ["documentId": documentId]
        
        if let collection = collection {
            data["collection"] = collection
        }
        
        // Fire and forget - don't block on popularity updates
        functions.httpsCallable("typesenseIncrementPopularity").call(data) { result, error in
            if let error = error {
                print("⚠️ Popularity update failed: \(error.localizedDescription)")
                return
            }
            
            if let resultData = result?.data as? [String: Any],
               let success = resultData["success"] as? Bool,
               success,
               let newPopularity = resultData["newPopularity"] as? Int {
                print("🔥 Popularity flywheel: \(documentId) → \(newPopularity)")
            }
        }
    }
    
    // MARK: - Barcode Lookup
    
    /// Look up a food by barcode
    func lookupBarcode(
        barcode: String,
        completion: @escaping (Result<[String: Any]?, Error>) -> Void
    ) {
        let data: [String: Any] = ["barcode": barcode]
        
        functions.httpsCallable("typesenseBarcodeLookup").call(data) { result, error in
            if let error = error {
                print("❌ TypesenseCloudService barcode lookup error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let resultData = result?.data as? [String: Any],
                  let success = resultData["success"] as? Bool,
                  success else {
                completion(.failure(TypesenseCloudError.invalidResponse))
                return
            }
            
            let found = resultData["found"] as? Bool ?? false
            
            if found, let document = resultData["document"] as? [String: Any] {
                print("✅ TypesenseCloudService barcode found: \(barcode)")
                completion(.success(document))
            } else {
                print("❌ TypesenseCloudService barcode not found: \(barcode)")
                completion(.success(nil))
            }
        }
    }
}

// MARK: - Supporting Types

struct TypesenseSearchResult {
    let found: Int
    let hits: [[String: Any]]
    let searchTimeMs: Int
}

enum TypesenseCloudError: Error, LocalizedError {
    case invalidResponse
    case notAuthenticated
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from search service"
        case .notAuthenticated:
            return "User must be signed in to search"
        case .rateLimited:
            return "Too many requests. Please try again later."
        }
    }
}
