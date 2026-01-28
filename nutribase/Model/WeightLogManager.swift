import Foundation
import SwiftUI
import Combine

class WeightLogManager: ObservableObject {
    // All weight entries stored in the app
    private var allWeightEntries: [WeightLogEntry] = []
    
    // Reference to the Firebase service
    private let firebaseWeightService = FirebaseWeightService.shared
    
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
        if let authenticatedUserId = FirebaseAuthService.shared.currentUser?.id {
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
        return "weightEntries_\(currentUserId)"
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
                    self?.syncFromFirebase()
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
            self.syncFromFirebase()
        }
    }
    
    // Save entries to UserDefaults and Firebase if authenticated
    private func saveEntries() {
        // Always save locally
        if let encoded = try? JSONEncoder().encode(allWeightEntries) {
            UserDefaults.standard.set(encoded, forKey: weightEntriesKey)
        }
        
        // Sync to Firebase if authenticated
        syncToFirebase()
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
            
            print("[WeightLogManager] Loaded \(allWeightEntries.count) entries from UserDefaults")
            
            // Load initial entries immediately so UI can show data
            loadInitialEntries()
            hasLoadedAllEntries = true
            
            // Recalculate moving averages on background thread to avoid blocking UI
            print("[WeightLogManager] 🔄 Recalculating moving averages on background thread...")
            calculateWeeklyRates { [weak self] in
                print("[WeightLogManager] ✅ Moving averages recalculated")
                self?.objectWillChange.send()
            }
        } else {
            print("[WeightLogManager] No saved entries found, starting with empty data")
            // Start with empty data instead of loading sample data
            allWeightEntries = []
            weightEntries = []
            hasLoadedAllEntries = true
        }
    }
    
    // MARK: - Firebase Sync Methods
    
    private func syncFromFirebase() {
        guard FirebaseAuthService.shared.isAuthenticated else {
            print("[WeightLogManager] Not authenticated, skipping sync from Firebase")
            return
        }
        
        guard let currentUser = FirebaseAuthService.shared.currentUser else {
            print("[WeightLogManager] No current user, skipping Firebase sync")
            return
        }
        
        print("[WeightLogManager] Loading weight logs from Firebase...")
        isLoading = true
        syncError = nil
        
        firebaseWeightService.fetchWeightEntries(userId: currentUser.id) { [weak self] entries in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                print("[WeightLogManager] Loaded \(entries.count) weight logs from Firebase")
                
                // Merge with local entries (avoid duplicates)
                self?.mergeWeightEntries(entries)
            }
        }
    }
    
    private func syncToFirebase() {
        print("[WeightLogManager] syncToFirebase called")
        print("[WeightLogManager] Authentication check: \(FirebaseAuthService.shared.isAuthenticated)")
        
        guard FirebaseAuthService.shared.isAuthenticated else {
            print("[WeightLogManager] ❌ Not authenticated, skipping sync to Firebase")
            return
        }
        
        guard let currentUser = FirebaseAuthService.shared.currentUser else {
            print("[WeightLogManager] ❌ No current user, skipping Firebase sync")
            return
        }
        
        guard !allWeightEntries.isEmpty else {
            print("[WeightLogManager] ❌ No weight entries to sync")
            return
        }
        
        print("[WeightLogManager] ✅ Starting sync of \(allWeightEntries.count) weight entries to Firebase...")
        
        // Use Firebase batch save for efficiency
        firebaseWeightService.batchSaveWeightEntries(allWeightEntries, userId: currentUser.id) { success in
            if success {
                print("✅ All weight logs synced to Firebase successfully")
            } else {
                print("❌ Failed to sync some weight logs to Firebase")
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
            print("[WeightLogManager] Adding \(uniqueEntries.count) new entries from Firebase")
            allWeightEntries.append(contentsOf: uniqueEntries)
            allWeightEntries.sort { $0.date > $1.date }
            
            // Calculate weekly rates for merged data (async)
            calculateWeeklyRates { [weak self] in
                guard let self = self else { return }
                
                // Update displayed entries (already on main thread)
                self.hasLoadedAllEntries = true
                
                // Save merged data locally
                if let encoded = try? JSONEncoder().encode(self.allWeightEntries) {
                    UserDefaults.standard.set(encoded, forKey: self.weightEntriesKey)
                }
            }
        } else {
            print("[WeightLogManager] No new entries to add from Firebase")
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
        
        print("[WeightLogManager] Entries count after add: \(allWeightEntries.count)")
        
        // Invalidate weight chart cache when new entry is added
        WeightChartCache.shared.invalidateCache()
        
        // Calculate weekly rates for all entries (async to avoid blocking UI)
        calculateWeeklyRates { [weak self] in
            guard let self = self else { return }
            
            // Save to UserDefaults after calculation completes
            if let encoded = try? JSONEncoder().encode(self.allWeightEntries) {
                UserDefaults.standard.set(encoded, forKey: self.weightEntriesKey)
                print("[WeightLogManager] Saved \(self.allWeightEntries.count) entries to UserDefaults with key: \(self.weightEntriesKey)")
            }
            
            // UI is already updated in calculateWeeklyRates completion
            self.hasLoadedAllEntries = true
            print("[WeightLogManager] Updated weightEntries to \(self.allWeightEntries.count) entries")
            
            // Trigger UI refresh
            self.objectWillChange.send()
        }
        
        // Sync to Firebase if authenticated
        syncToFirebase()
    }
    
    func deleteEntry(at indexSet: IndexSet) {
        // Get the entries to delete from the displayed entries
        let entriesToDelete = indexSet.map { weightEntries[$0] }
        
        // Delete from Firebase first if authenticated
        if FirebaseAuthService.shared.isAuthenticated {
            guard let currentUser = FirebaseAuthService.shared.currentUser else { return }
            
            for entry in entriesToDelete {
                firebaseWeightService.deleteWeightEntry(entryId: entry.id.uuidString, userId: currentUser.id) { success in
                    if success {
                        print("✅ Weight entry deleted from Firebase")
                    } else {
                        print("❌ Failed to delete weight entry from Firebase")
                    }
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
        
        // Recalculate moving averages and weekly rates for remaining entries
        recalculateMovingAverages()
    }
    
    func clearAllData() {
        // Delete all entries from Firebase if authenticated
        if FirebaseAuthService.shared.isAuthenticated {
            guard let currentUser = FirebaseAuthService.shared.currentUser else { return }
            
            for entry in allWeightEntries {
                firebaseWeightService.deleteWeightEntry(entryId: entry.id.uuidString, userId: currentUser.id) { success in
                    if success {
                        print("✅ Weight entry deleted from Firebase")
                    } else {
                        print("❌ Failed to delete weight entry from Firebase")
                    }
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
            if entriesByDate[dateKey] != nil {
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
        
        // Update the visible entries immediately so UI shows data
        weightEntries = allWeightEntries
        hasLoadedAllEntries = true
        
        // Calculate weekly rates for all entries (async to avoid blocking UI)
        calculateWeeklyRates { [weak self] in
            guard let self = self else { return }
            
            // Save to UserDefaults after calculation
            self.saveEntries()
            
            // Sync imported entries to Firebase if authenticated
            print("[WeightLogManager] About to sync \(self.allWeightEntries.count) entries to Firebase after import")
            print("[WeightLogManager] Authentication status: \(FirebaseAuthService.shared.isAuthenticated)")
            print("[WeightLogManager] Current user: \(FirebaseAuthService.shared.currentUser?.id ?? "none")")
            
            // Add a small delay to ensure authentication is stable
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.syncToFirebase()
            }
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
        
        // Load initial entries immediately so UI shows data
        loadInitialEntries()
        
        // Calculate moving averages and weekly rates (async to avoid blocking UI)
        calculateWeeklyRates { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    // Calculate moving averages and weekly rates using bidirectional EMA + Savitzky-Golay
    // Runs on background thread to avoid blocking UI
    private func calculateWeeklyRates(completion: (() -> Void)? = nil) {
        if allWeightEntries.isEmpty {
            completion?()
            return
        }
        
        let entriesToProcess = allWeightEntries
        
        // Move heavy computation to background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let processedEntries = WeightMovingAverageCalculator.calculateMovingAverages(for: entriesToProcess)
            
            // Update on main thread
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.allWeightEntries = processedEntries
                
                // Update visible entries if they've been loaded
                if self.hasLoadedAllEntries {
                    self.weightEntries = self.allWeightEntries
                }
                
                completion?()
            }
        }
    }
    
    // Public method to force recalculation of moving averages
    func recalculateMovingAverages() {
        print("[WeightLogManager] Force recalculating moving averages for \(allWeightEntries.count) entries")
        calculateWeeklyRates { [weak self] in
            guard let self = self else { return }
            // Force UI update (already on main thread from completion)
            self.objectWillChange.send()
            // Save updated entries
            self.saveEntries()
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
