//
//  WeightPhaseManager.swift
//  nutribase
//
//  Created on 14/08/2025.
//

import Foundation
import SwiftUI
import Combine

class WeightPhaseManager: ObservableObject {
    @Published var phases: [WeightPhase] = []
    @Published var isLoading: Bool = false
    @Published var syncError: String?
    
    private let firebasePhaseService = FirebasePhaseService.shared
    
    // Current user identifier for local storage (same pattern as other managers)
    private var currentUserId: String {
        if let existingId = UserDefaults.standard.string(forKey: "current_user_id") {
            return existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "current_user_id")
            return newId
        }
    }
    
    // Key for UserDefaults storage (user-specific)
    private var phasesKey: String {
        if let authenticatedUser = FirebaseAuthService.shared.currentUser {
            return "weightPhases_\(authenticatedUser.id)"
        } else {
            // Fallback to local UUID for users not yet authenticated
            return "weightPhases_\(currentUserId)"
        }
    }
    
    // Fallback key for migration (local UUID key)
    private var fallbackPhasesKey: String {
        return "weightPhases_\(currentUserId)"
    }
    
    // Singleton instance
    static let shared = WeightPhaseManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadPhases()
        
        // Subscribe to authentication changes
        NotificationCenter.default.publisher(for: .userDidSignIn)
            .sink { [weak self] _ in
                print("[WeightPhaseManager] User signed in - switching to authenticated mode")
                self?.clearCurrentUserData()
                self?.loadPhases()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .userDidSignOut)
            .sink { [weak self] _ in
                print("[WeightPhaseManager] User signed out - switching to guest mode")
                self?.clearCurrentUserData()
                self?.loadPhases()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Management
    
    private func loadPhases() {
        // Always load from local storage first for immediate UI update
        loadPhasesFromLocal()
        
        // Sync from cloud if authenticated
        if FirebaseAuthService.shared.currentUser != nil {
            syncFromCloud()
        } else {
            print("[WeightPhaseManager] Not authenticated - using local storage only")
        }
    }
    
    private func loadPhasesFromLocal() {
        let primaryKey = phasesKey
        print("[WeightPhaseManager] Loading phases with primary key: \(primaryKey)")
        
        // Try primary key first
        if let savedPhases = UserDefaults.standard.data(forKey: primaryKey) {
            do {
                let decodedPhases = try JSONDecoder().decode([WeightPhase].self, from: savedPhases)
                phases = decodedPhases.sorted { $0.startDate < $1.startDate }
                print("[WeightPhaseManager] Loaded \(phases.count) phases from primary key")
                return
            } catch {
                print("[WeightPhaseManager] Failed to decode phases from primary key: \(error)")
            }
        }
        
        // Try fallback key if primary key had no data (for migration scenarios)
        let fallbackKey = fallbackPhasesKey
        if primaryKey != fallbackKey {
            print("[WeightPhaseManager] Trying fallback key: \(fallbackKey)")
            if let savedPhases = UserDefaults.standard.data(forKey: fallbackKey) {
                do {
                    let decodedPhases = try JSONDecoder().decode([WeightPhase].self, from: savedPhases)
                    phases = decodedPhases.sorted { $0.startDate < $1.startDate }
                    print("[WeightPhaseManager] Loaded \(phases.count) phases from fallback key - migrating to primary key")
                    // Migrate data to primary key
                    savePhasesToLocal()
                    return
                } catch {
                    print("[WeightPhaseManager] Failed to decode phases from fallback key: \(error)")
                }
            }
        }
        
        print("[WeightPhaseManager] No saved phases found")
        phases = []
    }
    
    private func savePhasesToLocal() {
        let key = phasesKey
        do {
            let encoded = try JSONEncoder().encode(phases)
            UserDefaults.standard.set(encoded, forKey: key)
            UserDefaults.standard.synchronize() // Force immediate write
            print("[WeightPhaseManager] Saved \(phases.count) phases to key: \(key)")
        } catch {
            print("[WeightPhaseManager] Failed to encode phases: \(error)")
        }
    }
    
    private func syncFromCloud() {
        guard let user = FirebaseAuthService.shared.currentUser else {
            print("[WeightPhaseManager] No authenticated user for Firebase sync")
            return
        }
        
        isLoading = true
        syncError = nil
        
        print("[WeightPhaseManager] Syncing phases from Firebase for user: \(user.id)")
        
        firebasePhaseService.fetchPhases(userId: user.id) { [weak self] cloudPhases in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if cloudPhases.isEmpty && !self.phases.isEmpty {
                    // No cloud data but we have local data - push to cloud
                    print("[WeightPhaseManager] No cloud phases found, uploading \(self.phases.count) local phases")
                    self.uploadAllPhasesToCloud()
                } else if !cloudPhases.isEmpty {
                    // Cloud has data - merge with local (cloud takes precedence)
                    print("[WeightPhaseManager] Received \(cloudPhases.count) phases from cloud")
                    self.phases = cloudPhases.sorted { $0.startDate < $1.startDate }
                    self.savePhasesToLocal()
                }
            }
        }
    }
    
    private func uploadAllPhasesToCloud() {
        guard let user = FirebaseAuthService.shared.currentUser else { return }
        
        firebasePhaseService.batchSavePhases(phases, userId: user.id) { success in
            if success {
                print("[WeightPhaseManager] Successfully uploaded all phases to cloud")
            } else {
                print("[WeightPhaseManager] Failed to upload phases to cloud")
            }
        }
    }
    
    private func syncPhaseToCloud(_ phase: WeightPhase) {
        guard let user = FirebaseAuthService.shared.currentUser else {
            print("[WeightPhaseManager] Not authenticated - skipping cloud sync")
            return
        }
        
        firebasePhaseService.savePhase(phase, userId: user.id) { success in
            if success {
                print("[WeightPhaseManager] Phase synced to cloud: \(phase.name)")
            } else {
                print("[WeightPhaseManager] Failed to sync phase to cloud: \(phase.name)")
            }
        }
    }
    
    private func deletePhaseFromCloud(_ phaseId: UUID) {
        guard let user = FirebaseAuthService.shared.currentUser else {
            print("[WeightPhaseManager] Not authenticated - skipping cloud delete")
            return
        }
        
        firebasePhaseService.deletePhase(phaseId: phaseId.uuidString, userId: user.id) { success in
            if success {
                print("[WeightPhaseManager] Phase deleted from cloud")
            } else {
                print("[WeightPhaseManager] Failed to delete phase from cloud")
            }
        }
    }
    
    private func clearCurrentUserData() {
        phases = []
    }
    
    // MARK: - Public Methods
    
    func addPhase(_ phase: WeightPhase) {
        // Prevent duplicates: skip if a phase with the same name and overlapping dates already exists
        let isDuplicate = phases.contains { existing in
            existing.name == phase.name &&
            existing.startDate <= phase.endDate &&
            existing.endDate >= phase.startDate
        }
        if isDuplicate {
            print("[WeightPhaseManager] Skipping duplicate phase: \(phase.name)")
            return
        }
        
        phases.append(phase)
        phases.sort { $0.startDate < $1.startDate }
        savePhasesToLocal()
        
        // Sync to Firebase
        syncPhaseToCloud(phase)
        print("[WeightPhaseManager] Added phase: \(phase.name)")
    }
    
    func updatePhase(_ phase: WeightPhase) {
        print("[WeightPhaseManager] Attempting to update phase: \(phase.name) with ID: \(phase.id)")
        print("[WeightPhaseManager] New dates: \(phase.startDate) - \(phase.endDate)")
        print("[WeightPhaseManager] Current phases count: \(phases.count)")
        
        if let index = phases.firstIndex(where: { $0.id == phase.id }) {
            let oldPhase = phases[index]
            print("[WeightPhaseManager] Found phase at index \(index), old dates: \(oldPhase.startDate) - \(oldPhase.endDate)")
            
            phases[index] = phase
            phases.sort { $0.startDate < $1.startDate }
            savePhasesToLocal()
            
            // Clear cached data for this phase since dates may have changed
            clearPhaseCache(for: phase.id.uuidString)
            
            print("[WeightPhaseManager] Updated phase successfully: \(phase.name)")
            
            // Sync to Firebase
            syncPhaseToCloud(phase)
            
            // Verify the save worked
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.verifyPhaseSaved(phase)
            }
        } else {
            print("[WeightPhaseManager] ERROR: Could not find phase with ID: \(phase.id)")
            print("[WeightPhaseManager] Available phase IDs: \(phases.map { $0.id })")
        }
    }
    
    private func verifyPhaseSaved(_ phase: WeightPhase) {
        let key = phasesKey
        if let savedData = UserDefaults.standard.data(forKey: key),
           let savedPhases = try? JSONDecoder().decode([WeightPhase].self, from: savedData),
           let savedPhase = savedPhases.first(where: { $0.id == phase.id }) {
            print("[WeightPhaseManager] VERIFIED: Phase saved correctly with dates: \(savedPhase.startDate) - \(savedPhase.endDate)")
        } else {
            print("[WeightPhaseManager] WARNING: Could not verify phase was saved!")
        }
    }
    
    private func clearPhaseCache(for phaseId: String) {
        // Post notification to clear cache - this avoids circular imports
        NotificationCenter.default.post(
            name: Notification.Name("clearPhaseCache"),
            object: nil,
            userInfo: ["phaseId": phaseId]
        )
    }
    
    func deletePhase(_ phase: WeightPhase) {
        if let index = phases.firstIndex(where: { $0.id == phase.id }) {
            phases.remove(at: index)
            savePhasesToLocal()
            
            // Sync to Firebase
            deletePhaseFromCloud(phase.id)
            print("[WeightPhaseManager] Deleted phase: \(phase.name)")
        }
    }
    
    func deletePhase(at indexSet: IndexSet) {
        // Store phases to delete for syncing
        let phasesToDelete = indexSet.map { phases[$0] }
        
        // Update local data immediately
        phases.remove(atOffsets: indexSet)
        savePhasesToLocal()
        
        // Sync deletions to Firebase
        for phase in phasesToDelete {
            deletePhaseFromCloud(phase.id)
            print("[WeightPhaseManager] Deleted phase: \(phase.name)")
        }
    }
    
    // MARK: - Helper Methods
    
    func currentPhase(for date: Date = Date()) -> WeightPhase? {
        return phases.first { phase in
            date >= phase.startDate && date <= phase.endDate
        }
    }
    
    func phase(for date: Date) -> WeightPhase? {
        return phases.first { phase in
            date >= phase.startDate && date <= phase.endDate
        }
    }
    
    func upcomingPhase(for date: Date = Date()) -> WeightPhase? {
        return phases.first { phase in
            phase.startDate > date
        }
    }
    
    func phases(in dateRange: ClosedRange<Date>) -> [WeightPhase] {
        return phases.filter { phase in
            // Phase overlaps with date range if it starts before range ends and ends after range starts
            phase.startDate <= dateRange.upperBound && phase.endDate >= dateRange.lowerBound
        }
    }
    
    func hasPhase(on date: Date) -> Bool {
        return phases.contains { phase in
            date >= phase.startDate && date <= phase.endDate
        }
    }
    
    // Check if a date range conflicts with existing phases
    func hasConflict(startDate: Date, endDate: Date, excluding phaseId: UUID? = nil) -> Bool {
        return phases.contains { phase in
            if let excludeId = phaseId, phase.id == excludeId {
                return false // Don't check against the phase being edited
            }
            return phase.startDate <= endDate && phase.endDate >= startDate
        }
    }
    
    // Get all phases that overlap with a date range
    func phases(overlapping startDate: Date, endDate: Date) -> [WeightPhase] {
        return phases.filter { phase in
            // Check if phases overlap
            phase.startDate <= endDate && phase.endDate >= startDate
        }
    }
}
