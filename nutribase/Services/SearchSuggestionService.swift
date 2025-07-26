import Foundation
import Combine

class SearchSuggestionService: ObservableObject {
    static let shared = SearchSuggestionService()
    
    // Published property for search suggestions
    @Published var suggestions: [String] = []
    
    // Common food search terms
    private let commonSearchTerms = [
        "apple", "banana", "orange", "chicken", "beef", "salmon", "rice", "pasta", 
        "bread", "milk", "yogurt", "cheese", "eggs", "coffee", "tea", "water",
        "salad", "pizza", "burger", "sandwich", "avocado", "tomato", "potato",
        "broccoli", "spinach", "kale", "oatmeal", "cereal", "protein", "shake",
        "smoothie", "nuts", "almonds", "peanut butter", "chocolate", "ice cream"
    ]
    
    // Recent search terms (stored in UserDefaults)
    private let recentSearchesKey = "recentFoodSearches"
    private let maxRecentSearches = 10
    
    // Get suggestions based on current input
    func getSuggestions(for query: String) {
        // If query is empty, return empty suggestions
        if query.isEmpty {
            DispatchQueue.main.async {
                self.suggestions = []
            }
            return
        }
        
        // Combine recent searches with common terms
        var allTerms = getRecentSearches() + commonSearchTerms
        
        // Remove duplicates
        allTerms = Array(Set(allTerms))
        
        // Filter terms that start with the query (case insensitive)
        let lowercaseQuery = query.lowercased()
        let filteredTerms = allTerms.filter { 
            $0.lowercased().contains(lowercaseQuery) 
        }
        
        // Sort by relevance (terms that start with the query come first)
        let sortedTerms = filteredTerms.sorted { term1, term2 in
            let startsWithQuery1 = term1.lowercased().hasPrefix(lowercaseQuery)
            let startsWithQuery2 = term2.lowercased().hasPrefix(lowercaseQuery)
            
            if startsWithQuery1 && !startsWithQuery2 {
                return true
            } else if !startsWithQuery1 && startsWithQuery2 {
                return false
            } else {
                return term1.count < term2.count // Shorter terms first
            }
        }
        
        // Limit to top 5 suggestions
        let limitedTerms = Array(sortedTerms.prefix(5))
        
        DispatchQueue.main.async {
            self.suggestions = limitedTerms
        }
    }
    
    // Add a term to recent searches
    func addToRecentSearches(_ term: String) {
        if term.isEmpty {
            return
        }
        
        var recentSearches = getRecentSearches()
        
        // Remove if already exists (to avoid duplicates)
        recentSearches.removeAll { $0.lowercased() == term.lowercased() }
        
        // Add to beginning
        recentSearches.insert(term, at: 0)
        
        // Limit to max number
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        
        // Save to UserDefaults
        UserDefaults.standard.set(recentSearches, forKey: recentSearchesKey)
    }
    
    // Get recent searches from UserDefaults
    private func getRecentSearches() -> [String] {
        return UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }
}
