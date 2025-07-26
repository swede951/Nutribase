import Foundation
import SwiftUI
import Combine

class WeightLogManager: ObservableObject {
    // All weight entries stored in the app
    private var allWeightEntries: [WeightLogEntry] = []
    
    // Reference to the Supabase service
    private let supabaseService = SupabaseService.shared
    
    // Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // Currently displayed entries (for lazy loading)
    @Published var weightEntries: [WeightLogEntry] = [] {
        didSet {
            if weightEntries.count > allWeightEntries.count {
                // Only save if we're adding new entries, not when we're just loading more
                saveEntries()
            }
        }
    }
    
    // Number of months to load initially
    private let initialLoadMonths = 2
    
    // Track if we've loaded all entries
    @Published var hasLoadedAllEntries = false
    
    // Key for UserDefaults storage
    private let weightEntriesKey = "weightEntries"
    
    // Singleton instance for app-wide access
    static let shared = WeightLogManager()
    
    private init() {
        // First load local entries
        loadLocalEntries()
        
        // Then try to sync with Supabase if user is authenticated
        syncWithSupabase()
        
        // Subscribe to authentication changes
        NotificationCenter.default.publisher(for: .userDidSignIn)
            .sink { [weak self] _ in
                self?.syncWithSupabase()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .userDidSignOut)
            .sink { [weak self] _ in
                // When user signs out, revert to local entries only
                self?.loadLocalEntries()
            }
            .store(in: &cancellables)
    }
    
    // Save entries to UserDefaults and Supabase if authenticated
    private func saveEntries() {
        // Always save locally
        if let encoded = try? JSONEncoder().encode(allWeightEntries) {
            UserDefaults.standard.set(encoded, forKey: weightEntriesKey)
        }
        
        // If authenticated, sync with Supabase
        if supabaseService.isAuthenticated {
            syncToSupabase()
        }
    }
    
    // Load entries from UserDefaults
    private func loadLocalEntries() {
        if let savedEntries = UserDefaults.standard.data(forKey: weightEntriesKey),
           let decodedEntries = try? JSONDecoder().decode([WeightLogEntry].self, from: savedEntries) {
            // Store all entries
            allWeightEntries = decodedEntries
            // Sort by date, newest first
            allWeightEntries.sort { $0.date > $1.date }
            
            // Load only the initial set of entries
            loadInitialEntries()
        } else {
            // Load sample data if no saved entries
            loadSampleData()
        }
    }
    
    // Sync with Supabase - fetch remote entries and merge with local
    private func syncWithSupabase() {
        guard supabaseService.isAuthenticated else { return }
        
        supabaseService.fetchWeightLogs { [weak self] remoteEntries, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching weight logs: \(error.localizedDescription)")
                return
            }
            
            guard let remoteEntries = remoteEntries else { return }
            
            // Create a dictionary of local entries by ID for quick lookup
            let localEntriesDict = Dictionary(uniqueKeysWithValues: self.allWeightEntries.map { ($0.id, $0) })
            
            // Create a set of all entry IDs from both local and remote
            var allEntryIds = Set(localEntriesDict.keys)
            allEntryIds.formUnion(remoteEntries.map { $0.id })
            
            // Merge entries, preferring remote entries when there's a conflict
            var mergedEntries: [WeightLogEntry] = []
            
            for id in allEntryIds {
                if let remoteEntry = remoteEntries.first(where: { $0.id == id }) {
                    // Use remote entry
                    mergedEntries.append(remoteEntry)
                } else if let localEntry = localEntriesDict[id] {
                    // Use local entry
                    mergedEntries.append(localEntry)
                }
            }
            
            // Sort by date, newest first
            mergedEntries.sort { $0.date > $1.date }
            
            // Update @Published properties on main thread
            DispatchQueue.main.async {
                // Update all entries
                self.allWeightEntries = mergedEntries
                
                // Save merged entries locally
                if let encoded = try? JSONEncoder().encode(mergedEntries) {
                    UserDefaults.standard.set(encoded, forKey: self.weightEntriesKey)
                }
                
                // Update displayed entries
                self.loadInitialEntries()
                
                // If there are local entries that don't exist remotely, sync them to Supabase
                self.syncToSupabase()
            }
        }
    }
    
    // Sync local entries to Supabase
    private func syncToSupabase() {
        guard supabaseService.isAuthenticated else { return }
        
        // Get all entries that need to be synced
        let entriesToSync = allWeightEntries
        
        // Create a dispatch group to track completion
        let group = DispatchGroup()
        
        // Track any errors
        var syncErrors: [Error] = []
        
        for entry in entriesToSync {
            group.enter()
            
            supabaseService.addWeightLog(entry: entry) { success, error in
                if let error = error {
                    syncErrors.append(error)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !syncErrors.isEmpty {
                print("Errors syncing weight logs: \(syncErrors)")
            }
        }
    }
    
    func addEntry(_ entry: WeightLogEntry) {
        // Add to all entries
        allWeightEntries.append(entry)
        
        // Sort by date, newest first
        allWeightEntries.sort { $0.date > $1.date }
        
        // Save to UserDefaults and sync with Supabase
        saveEntries()
        
        // Refresh displayed entries
        loadInitialEntries()
        
        // If authenticated, add to Supabase directly
        if supabaseService.isAuthenticated {
            supabaseService.addWeightLog(entry: entry) { success, error in
                if let error = error {
                    print("Error adding weight log to Supabase: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func deleteEntry(at indexSet: IndexSet) {
        // Get the entries to delete from the displayed entries
        let entriesToDelete = indexSet.map { weightEntries[$0] }
        
        // Remove from all entries
        for entry in entriesToDelete {
            if let index = allWeightEntries.firstIndex(where: { $0.id == entry.id }) {
                allWeightEntries.remove(at: index)
            }
            
            // If authenticated, delete from Supabase
            if supabaseService.isAuthenticated {
                supabaseService.deleteWeightLog(entryId: entry.id) { success, error in
                    if let error = error {
                        print("Error deleting weight log from Supabase: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Remove from displayed entries
        weightEntries.remove(atOffsets: indexSet)
        
        // Save to UserDefaults
        saveEntries()
    }
    
    func clearAllData() {
        // Get all entries to delete from Supabase
        let entriesToDelete = allWeightEntries
        
        // Clear local data
        weightEntries.removeAll()
        allWeightEntries.removeAll()
        UserDefaults.standard.removeObject(forKey: weightEntriesKey)
        
        // If authenticated, delete all entries from Supabase
        if supabaseService.isAuthenticated {
            let group = DispatchGroup()
            
            for entry in entriesToDelete {
                group.enter()
                supabaseService.deleteWeightLog(entryId: entry.id) { _, error in
                    if let error = error {
                        print("Error deleting weight log from Supabase: \(error.localizedDescription)")
                    }
                    group.leave()
                }
            }
        }
    }
    
    func addEntries(_ entries: [WeightLogEntry]) {
        // Add new entries, avoiding duplicates by date
        let existingDates = Set(allWeightEntries.map { $0.date })
        let newEntries = entries.filter { !existingDates.contains($0.date) }
        
        // Add to both collections
        allWeightEntries.append(contentsOf: newEntries)
        allWeightEntries.sort { $0.date > $1.date } // Sort by date, newest first
        
        // Update the visible entries
        weightEntries = allWeightEntries
        
        // Since we've loaded all entries after an import
        hasLoadedAllEntries = true
        
        // Save to UserDefaults
        saveEntries()
        
        // If authenticated, sync new entries to Supabase
        if supabaseService.isAuthenticated && !newEntries.isEmpty {
            let group = DispatchGroup()
            
            for entry in newEntries {
                group.enter()
                supabaseService.addWeightLog(entry: entry) { _, error in
                    if let error = error {
                        print("Error adding weight log to Supabase: \(error.localizedDescription)")
                    }
                    group.leave()
                }
            }
        }
    }
    
    // Group entries by month for display
    var groupedEntries: [String: [WeightLogEntry]] {
        weightEntries.groupedByMonth()
    }
    
    // Load initial set of entries (most recent months)
    private func loadInitialEntries() {
        // If we have very few entries, just load them all
        if allWeightEntries.count < 20 {
            weightEntries = allWeightEntries
            hasLoadedAllEntries = true
            return
        }
        
        // Get the unique month keys from all entries
        let allMonthKeys = Set(allWeightEntries.map { $0.monthYearKey }).sorted(by: >)
        
        // Determine how many months to load initially
        let monthsToLoad = min(initialLoadMonths, allMonthKeys.count)
        
        if monthsToLoad > 0 {
            // Get the most recent months
            let recentMonthKeys = Array(allMonthKeys.prefix(monthsToLoad))
            
            // Filter entries to only include those from recent months
            weightEntries = allWeightEntries.filter { entry in
                recentMonthKeys.contains(entry.monthYearKey)
            }
            
            hasLoadedAllEntries = (weightEntries.count == allWeightEntries.count)
        } else {
            weightEntries = []
            hasLoadedAllEntries = true
        }
    }
    
    // Load more entries when user scrolls down
    func loadMoreEntries() {
        if hasLoadedAllEntries {
            return // Already loaded everything
        }
        
        // Get the unique month keys from all entries
        let allMonthKeys = Set(allWeightEntries.map { $0.monthYearKey }).sorted(by: >)
        
        // Get the month keys we've already loaded
        let loadedMonthKeys = Set(weightEntries.map { $0.monthYearKey })
        
        // Find the next months to load
        let remainingMonthKeys = allMonthKeys.filter { !loadedMonthKeys.contains($0) }
        
        // Load 2 more months if available
        let additionalMonthsToLoad = min(2, remainingMonthKeys.count)
        
        if additionalMonthsToLoad > 0 {
            // Get the next months to load
            let nextMonthKeys = Array(remainingMonthKeys.prefix(additionalMonthsToLoad))
            
            // Get entries for these months
            let additionalEntries = allWeightEntries.filter { entry in
                nextMonthKeys.contains(entry.monthYearKey)
            }
            
            // Add to the visible entries
            weightEntries.append(contentsOf: additionalEntries)
            
            // Sort by date, newest first
            weightEntries.sort { $0.date > $1.date }
            
            // Check if we've loaded everything
            hasLoadedAllEntries = (weightEntries.count == allWeightEntries.count)
        } else {
            hasLoadedAllEntries = true
        }
    }
    
    // Load all entries at once
    func loadAllEntries() {
        weightEntries = allWeightEntries
        hasLoadedAllEntries = true
    }
    
    // Load sample data for demonstration
    private func loadSampleData() {
        let calendar = Calendar.current
        
        // May 2025
        let may20 = calendar.date(from: DateComponents(year: 2025, month: 5, day: 20))!
        let may18 = calendar.date(from: DateComponents(year: 2025, month: 5, day: 18))!
        let may16 = calendar.date(from: DateComponents(year: 2025, month: 5, day: 16))!
        
        // April 2025
        let apr23 = calendar.date(from: DateComponents(year: 2025, month: 4, day: 23))!
        let apr16 = calendar.date(from: DateComponents(year: 2025, month: 4, day: 16))!
        let apr03 = calendar.date(from: DateComponents(year: 2025, month: 4, day: 3))!
        let apr01 = calendar.date(from: DateComponents(year: 2025, month: 4, day: 1))!
        
        // March 2025
        let mar28 = calendar.date(from: DateComponents(year: 2025, month: 3, day: 28))!
        
        weightEntries = [
            // May 2025
            WeightLogEntry(date: may20, weight: 79.9, movingAverage: 79.5, weeklyRate: nil, notes: nil),
            WeightLogEntry(date: may18, weight: 78.8, movingAverage: 79.4, weeklyRate: nil, notes: nil),
            WeightLogEntry(date: may16, weight: 79.9, movingAverage: 79.7, weeklyRate: nil, notes: nil),
            
            // April 2025
            WeightLogEntry(date: apr23, weight: 79.0, movingAverage: 80.3, weeklyRate: -0.8, notes: nil),
            WeightLogEntry(date: apr16, weight: 82.6, movingAverage: 81.3, weeklyRate: -0.3, notes: nil),
            WeightLogEntry(date: apr03, weight: 82.0, movingAverage: 82.0, weeklyRate: -0.1, notes: nil),
            WeightLogEntry(date: apr01, weight: 81.9, movingAverage: 82.1, weeklyRate: -0.1, notes: nil),
            
            // March 2025
            WeightLogEntry(date: mar28, weight: 82.5, movingAverage: 82.3, weeklyRate: 0.2, notes: nil)
        ]
    }
}
