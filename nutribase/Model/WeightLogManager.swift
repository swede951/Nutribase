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
    
    // Sync status
    @Published var isLoading = false
    @Published var syncError: String?
    
    // Currently displayed entries (for lazy loading)
    @Published var weightEntries: [WeightLogEntry] = [] {
        didSet {
            if weightEntries.count > allWeightEntries.count {
                // Only save if we're adding new entries, not when we're just loading more
                saveEntries()
            }
        }
    }
    
    // Number of entries threshold for lazy loading (only use lazy loading for very large datasets)
    private let lazyLoadingThreshold = 200
    
    // Track if we've loaded all entries
    @Published var hasLoadedAllEntries = false
    
    // Track if we're currently loading more entries
    @Published var isLoadingMore = false
    
    // Public access to all weight entries for charts and analytics
    var allEntries: [WeightLogEntry] {
        return allWeightEntries
    }
    
    // Current user identifier for local storage (use authenticated user's UUID)
    private var currentUserId: String {
        // Use authenticated user's UUID if available, otherwise fallback to local UUID
        if let authenticatedUserId = SimpleAuthService.shared.currentUser?.id {
            return authenticatedUserId
        }
        
        // Fallback to local UUID for offline usage
        if let existingId = UserDefaults.standard.string(forKey: "current_user_id") {
            return existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "current_user_id")
            return newId
        }
    }
    
    // Key for UserDefaults storage (user-specific)
    private var weightEntriesKey: String {
        if UserDefaults.standard.bool(forKey: "guest_mode") {
            return "weightEntries_guest"
        } else {
            return "weightEntries_\(currentUserId)"
        }
    }
    
    // Singleton instance for app-wide access
    static let shared = WeightLogManager()
    
    private init() {
        print("[WeightLogManager] 🚀 Initializing WeightLogManager...")
        // First load local entries
        loadLocalEntries()
        
        // Subscribe to authentication changes
        NotificationCenter.default.publisher(for: .userDidSignIn)
            .sink { [weak self] _ in
                print("[WeightLogManager] 🔑 User signed in - syncing weight data")
                // When user signs in, clear current data and reload for the new user
                self?.clearCurrentUserData()
                self?.loadLocalEntries()
                // Delay sync to ensure authentication is complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self?.syncFromSupabase()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .userDidSignOut)
            .sink { [weak self] _ in
                print("[WeightLogManager] 🚪 User signed out - clearing weight data")
                // When user signs out, clear current data and load fresh data for new user context
                self?.clearCurrentUserData()
                self?.loadLocalEntries()
            }
            .store(in: &cancellables)
        
        // Try initial sync after a delay to allow for app startup authentication
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.syncFromSupabase()
        }
    }
    
    // Save entries to UserDefaults and Supabase if authenticated
    private func saveEntries() {
        // Always save locally
        if let encoded = try? JSONEncoder().encode(allWeightEntries) {
            UserDefaults.standard.set(encoded, forKey: weightEntriesKey)
        }
        
        // Sync to Supabase if authenticated
        syncToSupabase()
    }
    
    // Clear current user's weight data (called on sign out)
    private func clearCurrentUserData() {
        print("[WeightLogManager] ⚠️ CLEARING CURRENT USER DATA - had \(allWeightEntries.count) entries, hasLoadedAllEntries was \(hasLoadedAllEntries)")
        // Clear in-memory data
        allWeightEntries.removeAll()
        weightEntries.removeAll()
        hasLoadedAllEntries = false
        print("[WeightLogManager] ⚠️ Set hasLoadedAllEntries = false")
    }
    
    // Load entries from UserDefaults
    func loadLocalEntries() {
        print("[WeightLogManager] Loading local entries from key: \(weightEntriesKey)")
        
        if let savedEntries = UserDefaults.standard.data(forKey: weightEntriesKey),
           let decodedEntries = try? JSONDecoder().decode([WeightLogEntry].self, from: savedEntries) {
            // Store all entries
            allWeightEntries = decodedEntries
            // Sort by date, newest first
            allWeightEntries.sort { $0.date > $1.date }
            
            // Calculate weekly rates
            calculateWeeklyRates()
            
            print("[WeightLogManager] Loaded \(allWeightEntries.count) entries from UserDefaults")
            
            // Load initial entries
            loadInitialEntries()
            
            // Force set hasLoadedAllEntries = true to fix loading screen issue
            hasLoadedAllEntries = true
            print("[WeightLogManager] 🔄 Force set hasLoadedAllEntries = true after loading from UserDefaults")
        } else {
            print("[WeightLogManager] No saved entries found, starting with empty data")
            // Start with empty data instead of loading sample data
            allWeightEntries = []
            weightEntries = []
            hasLoadedAllEntries = true
        }
    }
    
    // MARK: - Supabase Sync Methods
    
    private func syncFromSupabase() {
        guard SimpleAuthService.shared.isAuthenticated else {
            print("[WeightLogManager] Not authenticated, skipping sync from Supabase")
            return
        }
        
        print("[WeightLogManager] Loading weight logs from Supabase...")
        isLoading = true
        syncError = nil
        
        supabaseService.loadWeightLogs { [weak self] weightLogsData in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                guard let weightLogsData = weightLogsData else {
                    print("[WeightLogManager] No weight logs found in Supabase")
                    return
                }
                
                print("[WeightLogManager] Loaded \(weightLogsData.count) weight logs from Supabase")
                
                // Convert Supabase data to WeightLogEntry objects
                let entries = weightLogsData.compactMap { data -> WeightLogEntry? in
                    guard let idString = data["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let dateString = data["date"] as? String,
                          let date = ISO8601DateFormatter().date(from: dateString),
                          let weight = data["weight"] as? Double else {
                        return nil
                    }
                    
                    let movingAverage = data["moving_average"] as? Double
                    // Include id field when loading from Supabase
                    
                    return WeightLogEntry(
                        id: id,
                        date: date,
                        weight: weight,
                        movingAverage: movingAverage ?? weight,
                        weeklyRate: nil // Will be calculated locally
                    )
                }
                
                // Merge with local entries (avoid duplicates)
                self?.mergeWeightEntries(entries)
            }
        }
    }
    
    private func syncToSupabase() {
        print("[WeightLogManager] syncToSupabase called")
        print("[WeightLogManager] Authentication check: \(SimpleAuthService.shared.isAuthenticated)")
        print("[WeightLogManager] Current user ID: \(SimpleAuthService.shared.currentUser?.id ?? "nil")")
        print("[WeightLogManager] Access token exists: \(SimpleAuthService.shared.accessToken != nil)")
        
        guard SimpleAuthService.shared.isAuthenticated else {
            print("[WeightLogManager] ❌ Not authenticated, skipping sync to Supabase")
            return
        }
        
        guard !allWeightEntries.isEmpty else {
            print("[WeightLogManager] ❌ No weight entries to sync")
            return
        }
        
        print("[WeightLogManager] ✅ Starting sync of \(allWeightEntries.count) weight entries to Supabase...")
        
        // Process entries in batches to avoid overwhelming Supabase
        let batchSize = 50
        let batches = allWeightEntries.chunked(into: batchSize)
        
        print("[WeightLogManager] Created \(batches.count) batches of size \(batchSize)")
        
        syncBatches(batches, currentIndex: 0) { success in
            if success {
                print("✅ All weight logs synced to Supabase successfully")
            } else {
                print("❌ Failed to sync some weight logs to Supabase")
            }
        }
    }
    
    private func syncBatches(_ batches: [[WeightLogEntry]], currentIndex: Int, completion: @escaping (Bool) -> Void) {
        guard currentIndex < batches.count else {
            completion(true)
            return
        }
        
        let batch = batches[currentIndex]
        let weightLogsData = batch.map { entry in
            return [
                "id": entry.id.uuidString,
                "user_id": SimpleAuthService.shared.currentUser?.id ?? "",
                "date": ISO8601DateFormatter().string(from: entry.date),
                "weight": round(entry.weight * 10) / 10, // Round to 1 decimal place
                "moving_average": round(entry.movingAverage * 10) / 10 // Round to 1 decimal place
                // Fixed floating point precision issues
            ]
        }
        
        print("[WeightLogManager] Syncing batch \(currentIndex + 1)/\(batches.count) (\(batch.count) entries)")
        
        supabaseService.saveWeightLogs(weightLogsData) { success in
            if success {
                // Continue with next batch
                self.syncBatches(batches, currentIndex: currentIndex + 1, completion: completion)
            } else {
                print("❌ Failed to sync batch \(currentIndex + 1)")
                completion(false)
            }
        }
    }
    
    private func mergeWeightEntries(_ newEntries: [WeightLogEntry]) {
        // Create a set of existing dates for fast lookup
        let existingDates = Set(allWeightEntries.map { Calendar.current.startOfDay(for: $0.date) })
        
        // Filter out entries that already exist locally
        let uniqueEntries = newEntries.filter { entry in
            let entryDate = Calendar.current.startOfDay(for: entry.date)
            return !existingDates.contains(entryDate)
        }
        
        if !uniqueEntries.isEmpty {
            print("[WeightLogManager] Adding \(uniqueEntries.count) new entries from Supabase")
            allWeightEntries.append(contentsOf: uniqueEntries)
            allWeightEntries.sort { $0.date > $1.date }
            
            // Calculate weekly rates for merged data
            calculateWeeklyRates()
            
            // Update displayed entries
            weightEntries = allWeightEntries
            hasLoadedAllEntries = true
            
            // Save merged data locally
            if let encoded = try? JSONEncoder().encode(allWeightEntries) {
                UserDefaults.standard.set(encoded, forKey: weightEntriesKey)
            }
        } else {
            print("[WeightLogManager] No new entries to add from Supabase")
        }
    }
    
    // Add entry
    func addEntry(_ entry: WeightLogEntry) {
        print("[WeightLogManager] Adding entry: \(entry.weight) kg on \(entry.date)")
        print("[WeightLogManager] Current entries count before add: \(allWeightEntries.count)")
        
        // Check if an entry for this date already exists
        let calendar = Calendar.current
        let entryDateComponents = calendar.dateComponents([.year, .month, .day], from: entry.date)
        
        // Check if we already have an entry for this date
        if let existingEntryIndex = allWeightEntries.firstIndex(where: { existingEntry in
            let existingDateComponents = calendar.dateComponents([.year, .month, .day], from: existingEntry.date)
            return existingDateComponents.year == entryDateComponents.year &&
                   existingDateComponents.month == entryDateComponents.month &&
                   existingDateComponents.day == entryDateComponents.day
        }) {
            // Replace the existing entry instead of adding a duplicate
            print("[WeightLogManager] Found existing entry for this date. Replacing instead of adding duplicate.")
            allWeightEntries[existingEntryIndex] = entry
        } else {
            // No existing entry for this date, add the new one
            allWeightEntries.append(entry)
        }
        
        // Sort by date, newest first
        allWeightEntries.sort { $0.date > $1.date }
        
        // Calculate weekly rates for all entries
        calculateWeeklyRates()
        
        print("[WeightLogManager] Entries count after add: \(allWeightEntries.count)")
        
        // Invalidate weight chart cache when new entry is added
        WeightChartCache.shared.invalidateCache()
        
        // Save to UserDefaults immediately
        if let encoded = try? JSONEncoder().encode(allWeightEntries) {
            UserDefaults.standard.set(encoded, forKey: weightEntriesKey)
            print("[WeightLogManager] Saved \(allWeightEntries.count) entries to UserDefaults with key: \(weightEntriesKey)")
        }
        
        // Force UI update on main thread
        DispatchQueue.main.async {
            // Refresh displayed entries
            self.weightEntries = self.allWeightEntries
            self.hasLoadedAllEntries = true
            print("[WeightLogManager] Updated weightEntries to \(self.allWeightEntries.count) entries on main thread")
            
            // Trigger UI refresh
            self.objectWillChange.send()
        }
        
        // Sync to Supabase if authenticated
        syncToSupabase()
    }
    
    func deleteEntry(at indexSet: IndexSet) {
        // Get the entries to delete from the displayed entries
        let entriesToDelete = indexSet.map { weightEntries[$0] }
        
        // Delete from Supabase first if authenticated
        if SimpleAuthService.shared.isAuthenticated {
            let weightLogsToDelete = entriesToDelete.map { entry in
                return [
                    "user_id": SimpleAuthService.shared.currentUser?.id ?? "",
                    "date": ISO8601DateFormatter().string(from: entry.date)
                ]
            }
            
            supabaseService.deleteWeightLogs(weightLogsToDelete) { success in
                if success {
                    print("✅ Weight entries deleted from Supabase")
                } else {
                    print("❌ Failed to delete some weight entries from Supabase")
                }
            }
        }
        
        // Remove from all entries
        for entry in entriesToDelete {
            if let index = allWeightEntries.firstIndex(where: { $0.id == entry.id }) {
                allWeightEntries.remove(at: index)
            }
        }
        
        // Remove from displayed entries
        weightEntries.remove(atOffsets: indexSet)
        
        // Save to UserDefaults
        saveEntries()
    }
    
    func clearAllData() {
        // Delete all entries from Supabase if authenticated
        if SimpleAuthService.shared.isAuthenticated {
            let weightLogsToDelete = allWeightEntries.map { entry in
                return [
                    "user_id": SimpleAuthService.shared.currentUser?.id ?? "",
                    "date": ISO8601DateFormatter().string(from: entry.date)
                ]
            }
            
            supabaseService.deleteWeightLogs(weightLogsToDelete) { success in
                if success {
                    print("✅ All weight entries deleted from Supabase")
                } else {
                    print("❌ Failed to delete some weight entries from Supabase")
                }
            }
        }
        
        // Clear local data
        weightEntries.removeAll()
        allWeightEntries.removeAll()
        UserDefaults.standard.removeObject(forKey: weightEntriesKey)
    }
    
    func addEntries(_ entries: [WeightLogEntry]) {
        // Create a calendar for date comparisons
        let calendar = Calendar.current
        
        // Create a dictionary to track entries by date (year-month-day)
        var entriesByDate: [String: WeightLogEntry] = [:]
        
        // First add existing entries to the dictionary
        for entry in allWeightEntries {
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: entry.date)
            let dateKey = "\(dateComponents.year!)-\(dateComponents.month!)-\(dateComponents.day!)"
            entriesByDate[dateKey] = entry
        }
        
        // Then process new entries, which will overwrite existing entries for the same date
        var newEntries: [WeightLogEntry] = []
        for entry in entries {
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: entry.date)
            let dateKey = "\(dateComponents.year!)-\(dateComponents.month!)-\(dateComponents.day!)"
            
            // Check if we already have an entry for this date
            if let existingEntry = entriesByDate[dateKey] {
                print("[WeightLogManager] Found existing entry for date \(dateKey). Replacing.")
            } else {
                newEntries.append(entry)
            }
            
            // New entries take precedence over existing ones
            entriesByDate[dateKey] = entry
        }
        
        // Convert back to array
        let mergedEntries = Array(entriesByDate.values)
        
        // Update all entries
        allWeightEntries = mergedEntries
        allWeightEntries.sort { $0.date > $1.date } // Sort by date, newest first
        
        // Calculate weekly rates for all entries
        calculateWeeklyRates()
        
        // Update the visible entries
        weightEntries = allWeightEntries
        
        // Since we've loaded all entries after an import
        hasLoadedAllEntries = true
        
        // Save to UserDefaults
        saveEntries()
        
        // Sync imported entries to Supabase if authenticated
        print("[WeightLogManager] About to sync \(allWeightEntries.count) entries to Supabase after import")
        print("[WeightLogManager] Authentication status: \(SimpleAuthService.shared.isAuthenticated)")
        print("[WeightLogManager] Current user: \(SimpleAuthService.shared.currentUser?.id ?? "none")")
        
        // Add a small delay to ensure authentication is stable
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.syncToSupabase()
        }
    }
    
    // Group entries by month for display
    var groupedEntries: [String: [WeightLogEntry]] {
        weightEntries.groupedByMonth()
    }
    
    // Load initial set of entries (all entries by default)
    private func loadInitialEntries() {
        print("[WeightLogManager] loadInitialEntries called with \(allWeightEntries.count) entries")
        
        // Always load all entries regardless of dataset size
        // This ensures users see their complete weight history
        DispatchQueue.main.async {
            self.weightEntries = self.allWeightEntries
            self.hasLoadedAllEntries = true
            print("[WeightLogManager] Set hasLoadedAllEntries = true, loaded all \(self.allWeightEntries.count) entries")
        }
    }
    
    // Load more entries when user scrolls down (local lazy loading)
    func loadMoreEntriesLocally() {
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
        
        allWeightEntries = [
            // May 2025 - showing weight loss trend
            WeightLogEntry(date: may20, weight: 79.9, movingAverage: 79.5, weeklyRate: nil, notes: nil),
            WeightLogEntry(date: may18, weight: 78.8, movingAverage: 79.4, weeklyRate: nil, notes: nil),
            WeightLogEntry(date: may16, weight: 79.9, movingAverage: 79.7, weeklyRate: nil, notes: nil),
            
            // April 2025 - gradual weight loss
            WeightLogEntry(date: apr23, weight: 79.0, movingAverage: 80.3, weeklyRate: nil, notes: nil),
            WeightLogEntry(date: apr16, weight: 82.6, movingAverage: 81.3, weeklyRate: nil, notes: nil),
            WeightLogEntry(date: apr03, weight: 82.0, movingAverage: 82.0, weeklyRate: nil, notes: nil),
            WeightLogEntry(date: apr01, weight: 81.9, movingAverage: 82.1, weeklyRate: nil, notes: nil),
            
            // March 2025 - starting point
            WeightLogEntry(date: mar28, weight: 82.5, movingAverage: 82.3, weeklyRate: nil, notes: nil)
        ]
        
        // Sort by date, newest first
        allWeightEntries.sort { $0.date > $1.date }
        
        print("[WeightLogManager] Loaded \(allWeightEntries.count) sample entries")
        
        // Calculate weekly rates for sample data
        calculateWeeklyRates()
        
        // Load initial entries
        loadInitialEntries()
        
    }
    
    // Calculate moving averages and weekly rates to match reference app
    private func calculateWeeklyRates() {
        // Sort entries by date (oldest first) for calculation
        let sortedEntries = allWeightEntries.sorted { $0.date < $1.date }
        
        if sortedEntries.isEmpty {
            return
        }
        
        var updatedEntries: [WeightLogEntry] = []
        
        // Calculate moving averages and weekly rates
        for i in 0..<sortedEntries.count {
            let currentEntry = sortedEntries[i]
            
            // Calculate moving average using simple moving average approach
            var movingAverage: Double
            if i == 0 {
                // First entry: moving average = recorded weight
                movingAverage = currentEntry.weight
            } else {
                // Use a weighted average that gives more weight to recent entries
                // Based on analysis of reference data, appears to use alpha ≈ 0.05
                let alpha = 0.05
                let previousMovingAverage = updatedEntries[i-1].movingAverage
                movingAverage = alpha * currentEntry.weight + (1 - alpha) * previousMovingAverage
                movingAverage = round(movingAverage * 10) / 10  // Round to 1 decimal
            }
            
            // Calculate weekly rate - simplified approach
            var weeklyRate: Double? = nil
            
            // Look for entries to calculate rate (need at least 2 entries)
            if i >= 1 {
                // Find the best entry around 7 days ago, but be more flexible
                var bestPreviousIndex: Int? = nil
                var bestTimeDifference: Double = Double.greatestFiniteMagnitude
                
                // Look backwards for entries
                for j in (0..<i).reversed() {
                    let daysDifference = currentEntry.date.timeIntervalSince(sortedEntries[j].date) / (24 * 60 * 60)
                    
                    // Accept entries between 1 and 14 days ago (more flexible range)
                    if daysDifference >= 1 && daysDifference <= 14 {
                        let distanceFrom7Days = abs(daysDifference - 7.0)
                        if distanceFrom7Days < bestTimeDifference {
                            bestTimeDifference = distanceFrom7Days
                            bestPreviousIndex = j
                        }
                    }
                }
                
                // Calculate weekly rate if we found a suitable previous entry
                if let previousIndex = bestPreviousIndex {
                    let previousEntry = updatedEntries[previousIndex]
                    let actualDaysDifference = currentEntry.date.timeIntervalSince(sortedEntries[previousIndex].date) / (24 * 60 * 60)
                    
                    // Use moving averages for rate calculation
                    let weightDifference = movingAverage - previousEntry.movingAverage
                    let rawWeeklyRate = weightDifference * (7.0 / actualDaysDifference)
                    
                    // Round to 1 decimal place
                    let roundedRate = round(rawWeeklyRate * 10) / 10
                    
                    // Show rate if it's meaningful (>= 0.1) and within reasonable range
                    if abs(roundedRate) >= 0.1 && abs(roundedRate) <= 5.0 {
                        weeklyRate = roundedRate
                    }
                }
            }
            
            // Create updated entry
            let updatedEntry = WeightLogEntry(
                id: currentEntry.id,
                date: currentEntry.date,
                weight: currentEntry.weight,
                movingAverage: movingAverage,
                weeklyRate: weeklyRate,
                notes: currentEntry.notes
            )
            
            updatedEntries.append(updatedEntry)
        }
        
        // Sort back to newest first order
        updatedEntries.sort { $0.date > $1.date }
        
        // Replace entries with updated ones
        allWeightEntries = updatedEntries
        
        // Update visible entries if they've been loaded
        if hasLoadedAllEntries {
            weightEntries = allWeightEntries
        }
    }
    
    // Load more entries when user scrolls to the bottom
    func loadMoreEntries() {
        guard !isLoadingMore,
              !hasLoadedAllEntries else {
            return
        }
        
        isLoadingMore = true
        let currentOffset = allWeightEntries.count
        
        print("[WeightLogManager] Loading more entries from offset: \(currentOffset)")
        
        // Simplified sync - just save locally for now
        isLoadingMore = false
    }
}

// Extension to chunk arrays into smaller batches
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
