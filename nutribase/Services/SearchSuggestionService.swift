import Foundation
import Combine

/// Hybrid search suggestion service that combines:
/// 1. Local suggestions (instant) - recent searches + logged foods
/// 2. Server suggestions (fast) - Typesense autocomplete
class SearchSuggestionService: ObservableObject {
    static let shared = SearchSuggestionService()
    
    // MARK: - Published Properties
    
    /// Combined suggestions from local + server sources
    @Published var suggestions: [SearchSuggestion] = []
    
    /// Loading state for server suggestions
    @Published var isLoadingServerSuggestions = false
    
    // MARK: - Configuration
    
    private let recentSearchesKey = "recentFoodSearches"
    private let maxRecentSearches = 15
    private let maxSuggestions = 6
    private let debounceDelay: TimeInterval = 0.15 // Fast debounce for responsiveness
    
    // Debounce timer
    private var debounceTimer: Timer?
    private var currentQuery = ""
    
    // MARK: - Suggestion Model
    
    struct SearchSuggestion: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let type: SuggestionType
        let subtitle: String?
        
        enum SuggestionType {
            case recentSearch      // Clock icon - user's recent searches
            case recentFood        // Fork/knife icon - recently logged food
            case serverSuggestion  // Magnifying glass - from Typesense
        }
        
        var icon: String {
            switch type {
            case .recentSearch: return "clock"
            case .recentFood: return "fork.knife"
            case .serverSuggestion: return "magnifyingglass"
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Get suggestions for a query (hybrid: local instant + server async)
    func getSuggestions(for query: String) {
        currentQuery = query
        
        // If query is empty, clear suggestions
        if query.isEmpty {
            DispatchQueue.main.async {
                self.suggestions = []
                self.isLoadingServerSuggestions = false
            }
            debounceTimer?.invalidate()
            return
        }
        
        // Step 1: Show local suggestions immediately (instant feedback)
        let localSuggestions = getLocalSuggestions(for: query)
        DispatchQueue.main.async {
            self.suggestions = localSuggestions
        }
        
        // Step 2: Fetch server suggestions with debounce
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceDelay, repeats: false) { [weak self] _ in
            self?.fetchServerSuggestions(for: query)
        }
    }
    
    /// Add a term to recent searches when user performs a search
    func addToRecentSearches(_ term: String) {
        guard !term.isEmpty else { return }
        
        var recentSearches = getRecentSearches()
        
        // Remove if already exists (to move to top)
        recentSearches.removeAll { $0.lowercased() == term.lowercased() }
        
        // Add to beginning
        recentSearches.insert(term, at: 0)
        
        // Limit to max number
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        
        UserDefaults.standard.set(recentSearches, forKey: recentSearchesKey)
    }
    
    /// Clear all recent searches
    func clearRecentSearches() {
        UserDefaults.standard.removeObject(forKey: recentSearchesKey)
        if !currentQuery.isEmpty {
            getSuggestions(for: currentQuery)
        }
    }
    
    // MARK: - Local Suggestions (Instant)
    
    private func getLocalSuggestions(for query: String) -> [SearchSuggestion] {
        // No local suggestions - History section already shows logged foods
        // Only server suggestions will be shown in Suggested Searches
        return []
    }
    
    private func getRecentSearches() -> [String] {
        return UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }
    
    private func getRecentlyLoggedFoodNames() -> [(name: String, brand: String?)] {
        // Get unique food names from FoodLogManager
        let entries = FoodLogManager.shared.entries
        var seen = Set<String>()
        var foods: [(name: String, brand: String?)] = []
        
        for entry in entries.prefix(50) { // Check last 50 entries
            let key = entry.foodItem.name.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                foods.append((name: entry.foodItem.name, brand: entry.foodItem.brandName))
            }
        }
        
        return foods
    }
    
    // MARK: - Server Suggestions (via Firebase Functions - Secure)
    
    private func fetchServerSuggestions(for query: String) {
        guard query.count >= 2 else { return } // Only fetch for 2+ characters
        
        DispatchQueue.main.async {
            self.isLoadingServerSuggestions = true
        }
        
        // Use Firebase Functions proxy for secure API access
        TypesenseCloudService.shared.searchFoods(
            query: query,
            collection: "foods",
            perPage: 8
        ) { [weak self] result in
            guard let self = self else { return }
            
            // Check if query is still current (user may have typed more)
            guard self.currentQuery == query else { return }
            
            DispatchQueue.main.async {
                self.isLoadingServerSuggestions = false
            }
            
            switch result {
            case .success(let searchResult):
                // Extract unique food names from results
                var serverSuggestions: [SearchSuggestion] = []
                var seenNames = Set<String>()
                
                for hit in searchResult.hits {
                    guard let document = hit["document"] as? [String: Any],
                          let name = document["name"] as? String else { continue }
                    
                    let nameLower = name.lowercased()
                    if !seenNames.contains(nameLower) {
                        seenNames.insert(nameLower)
                        let brand = document["brand"] as? String
                        serverSuggestions.append(SearchSuggestion(
                            text: name,
                            type: .serverSuggestion,
                            subtitle: brand?.isEmpty == false ? brand : nil
                        ))
                    }
                }
                
                // Merge with existing local suggestions
                DispatchQueue.main.async {
                    self.mergeServerSuggestions(serverSuggestions)
                }
                
            case .failure(let error):
                print("⚠️ Server suggestions failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func mergeServerSuggestions(_ serverSuggestions: [SearchSuggestion]) {
        // Keep local suggestions at top, add unique server suggestions below
        var merged = suggestions.filter { $0.type != .serverSuggestion }
        let existingNames = Set(merged.map { $0.text.lowercased() })
        
        for suggestion in serverSuggestions {
            if !existingNames.contains(suggestion.text.lowercased()) {
                merged.append(suggestion)
            }
        }
        
        suggestions = Array(merged.prefix(maxSuggestions))
    }
}
