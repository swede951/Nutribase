import Foundation
import Typesense
import Combine

/// Document structure for Typesense food documents
struct FoodDocument: Codable, Sendable {
    let id: String?
    let name: String?
    let calories: Int?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let sugar: Double?
    let fiber: Double?
    let barcode: String?
    let brand: String?
    let serving_size: Double?
    let serving_unit: String?
    let nova_score: Int?
    let nutri_score: String?
}

/// Service for interacting with Typesense using the official Swift SDK
class TypesenseSDKService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = TypesenseSDKService()
    
    private init() {
        setupClient()
    }
    
    // MARK: - Properties
    
    private var client: Typesense.Client? = nil
    
    private struct TypesenseConfig {
        static let apiURL = "h8ugnjal1c65sm2op-1.a1.typesense.net"
        // Using the Search-only API Key from Typesense Cloud
        static let searchOnlyApiKey = "qcEQwXYRKT7mCLFiJ8fZc4AwqTw7"
        static let collectionName = "foods"
    }
    
    // MARK: - Setup
    
    private func setupClient() {
        // Create a node with the correct parameters - don't include https:// in the host
        let node = Typesense.Node(
            host: "h8ugnjal1c65sm2op-1.a1.typesense.net",
            port: "443",
            nodeProtocol: "https"
            //scheme: "https"
        )
        
        // Create configuration with the node
        let configuration = Typesense.Configuration(
            nodes: [node],
            apiKey: TypesenseConfig.searchOnlyApiKey,
            connectionTimeoutSeconds: 10
        )
        
        client = Typesense.Client(config: configuration)
    }
    
    // MARK: - Public Methods
    
    /// Search for foods matching the given query
    func searchFoods(query: String, completion: @escaping ([FoodItem]?, Error?) -> Void) {
        guard !query.isEmpty else {
            completion([], nil)
            return
        }
        
        print("🔍 Searching Typesense for: \(query) using SDK")
        
        // Create search parameters
        let searchParameters = SearchParameters(
            q: query,
            queryBy: "name",
            perPage: 20
        )
        
        // Execute search using the SDK
        Task { @MainActor in
            do {
                // Using the correct API based on the SDK documentation
                guard let client = client else {
                    completion(nil, NSError(domain: "TypesenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Client not initialized"]))
                    return
                }
                
                // Use the FoodDocument struct for decoding
                let (searchResultOpt, _) = try await client.collection(name: TypesenseConfig.collectionName).documents().search(searchParameters, for: FoodDocument.self)
                
                print("📝 Raw Typesense response received")
                
                // Parse the response into FoodItem objects
                var foods: [FoodItem] = []
                
                // Unwrap the optional searchResult
                if let searchResult = searchResultOpt, let hits = searchResult.hits {
                    for hit in hits {
                        if let doc = hit.document, let name = doc.name {
                            // Convert Typesense document to FoodItem using the correct initializer
                            let food = FoodItem(
                                name: name,
                                brandName: doc.brand,
                                barcode: doc.barcode,
                                calories: doc.calories ?? 0,
                                protein: doc.protein ?? 0,
                                carbs: doc.carbs ?? 0,
                                fat: doc.fat ?? 0,
                                novaScore: doc.nova_score ?? 0,
                                nutriScoreGrade: doc.nutri_score,
                                servingSize: doc.serving_size != nil ? "\(doc.serving_size!)" : nil,
                                servingsPerPackage: nil,
                                servingType: doc.serving_unit,
                                fiber: doc.fiber,
                                sugar: doc.sugar
                            )
                            
                            foods.append(food)
                        }
                    }
                }
                
                print("✅ Found \(foods.count) foods matching query: \(query)")
                
                // Since we're using @MainActor, we're already on the main thread
                completion(foods, nil)
            } catch {
                print("❌ Typesense search error: \(error)")
                completion(nil, error)
            }
        }
    }
    
    /// Test the connection to Typesense using the SDK
    func testConnection(completion: @escaping (Bool, String?) -> Void) {
        print("🔍 Testing Typesense connection with SDK...")
        
        Task { @MainActor in
            do {
                guard let client = client else {
                    completion(false, "Client not initialized")
                    return
                }
                
                // Use the correct API to retrieve health status
                let (healthData, _) = try await client.operations().getHealth()
                
                // Safely unwrap optional for string interpolation
                let healthDataString = String(describing: healthData)
                print("✅ Typesense health check successful: \(healthDataString)")
                
                completion(true, "Connection successful")
            } catch {
                print("❌ Typesense connection error: \(error)")
                completion(false, "Connection error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Search for a food by barcode
    func searchByBarcode(barcode: String, completion: @escaping (FoodItem?, Error?) -> Void) {
        print("🔍 Searching Typesense for barcode: \(barcode) using SDK")
        
        // Create search parameters for exact barcode match
        let searchParameters = SearchParameters(
            q: barcode,
            queryBy: "barcode",
            perPage: 1
        )
        
        // Execute search using the SDK
        Task { @MainActor in
            do {
                // Using the correct API based on the SDK documentation
                guard let client = client else {
                    completion(nil, NSError(domain: "TypesenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Client not initialized"]))
                    return
                }
                
                // Use the FoodDocument struct for decoding
                let (searchResultOpt, _) = try await client.collection(name: TypesenseConfig.collectionName).documents().search(searchParameters, for: FoodDocument.self)
                
                print("📝 Raw Typesense barcode response received")
                
                // Parse the response into a FoodItem
                // Unwrap the optional searchResult
                if let searchResult = searchResultOpt, let hits = searchResult.hits, !hits.isEmpty {
                    // Get the first hit
                    if let doc = hits.first?.document, let name = doc.name {
                        // Convert Typesense document to FoodItem using the correct initializer
                        let food = FoodItem(
                            name: name,
                            brandName: doc.brand,
                            barcode: doc.barcode,
                            calories: doc.calories ?? 0,
                            protein: doc.protein ?? 0,
                            carbs: doc.carbs ?? 0,
                            fat: doc.fat ?? 0,
                            novaScore: doc.nova_score ?? 0,
                            nutriScoreGrade: doc.nutri_score,
                            servingSize: doc.serving_size != nil ? "\(doc.serving_size!)" : nil,
                            servingsPerPackage: nil,
                            servingType: doc.serving_unit,
                            fiber: doc.fiber,
                            sugar: doc.sugar
                        )
                        
                        print("✅ Found food with barcode: \(barcode)")
                        
                        // Since we're using @MainActor, we're already on the main thread
                        completion(food, nil)
                        return
                    }
                }
                
                // If we get here, no results were found
                completion(nil, NSError(domain: "TypesenseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No food found with barcode: \(barcode)"]))
            } catch {
                print("❌ Typesense barcode search error: \(error)")
                completion(nil, error)
            }
        }
    }
    
    /// Test searching for a sample query
    func testSearch(completion: @escaping (Bool, String?) -> Void) {
        print("🔍 Testing Typesense search with SDK...")
        
        Task { @MainActor in
            do {
                guard let client = client else {
                    completion(false, "Client not initialized")
                    return
                }
                
                // Skip collections listing for now since it's causing issues
                print("📜 Skipping collections list due to API limitations")
                
                // Now try a simple search
                searchFoods(query: "apple") { (foods, error) in
                    if let error = error {
                        print("❌ Search test failed: \(error)")
                        completion(false, "Search test failed: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let foods = foods, !foods.isEmpty else {
                        completion(false, "No search results found")
                        return
                    }
                    
                    print("✅ Search test successful! Found \(foods.count) results")
                    completion(true, "Search successful! Found \(foods.count) results with first item: \(foods[0].name)")
                }
            } catch {
                print("❌ Failed to initialize test: \(error)")
                completion(false, "Failed to initialize test: \(error.localizedDescription)")
            }
        }
    }
}
