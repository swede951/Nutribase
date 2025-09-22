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
    
    private let supabaseService = SupabaseService.shared
    
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
        if UserDefaults.standard.bool(forKey: "guest_mode") {
            return "weightPhases_guest"
        } else if let authenticatedUser = SimpleAuthService.shared.currentUser {
            // Use Supabase user ID for authenticated users
            return "weightPhases_\(authenticatedUser.id)"
        } else {
            // Fallback to local UUID for users not yet authenticated
            return "weightPhases_\(currentUserId)"
        }
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
        if SimpleAuthService.shared.currentUser != nil {
            syncFromCloud()
        } else {
            print("[WeightPhaseManager] Not authenticated - using local storage only")
        }
    }
    
    private func loadPhasesFromLocal() {
        if let savedPhases = UserDefaults.standard.data(forKey: phasesKey),
           let decodedPhases = try? JSONDecoder().decode([WeightPhase].self, from: savedPhases) {
            phases = decodedPhases.sorted { $0.startDate < $1.startDate }
        } else {
            // Load sample phases for new users
            phases = WeightPhase.samplePhases
            savePhasesToLocal()
        }
    }
    
    private func savePhasesToLocal() {
        if let encoded = try? JSONEncoder().encode(phases) {
            UserDefaults.standard.set(encoded, forKey: phasesKey)
        }
    }
    
    private func syncFromCloud() {
        isLoading = true
        syncError = nil
        
        supabaseService.loadWeightPhases { [weak self] phasesData in
            guard let self = self else { return }
            
            self.isLoading = false
            
            guard let phasesData = phasesData else {
                print("[WeightPhaseManager] No phases data from Supabase")
                return
            }
            
            // Convert Supabase data to WeightPhase objects
            let cloudPhases = phasesData.compactMap { data -> WeightPhase? in
                return self.convertSupabaseToWeightPhase(data)
            }
            
            // Merge with local phases (cloud takes precedence)
            self.mergeCloudPhases(cloudPhases)
            
            print("[WeightPhaseManager] ✅ Synced \(cloudPhases.count) phases from Supabase")
        }
    }
    
    private func syncToCloud(_ phase: WeightPhase, operation: CloudOperation, completion: @escaping (Bool) -> Void = { _ in }) {
        // Only sync if authenticated
        guard SimpleAuthService.shared.currentUser != nil else {
            print("[WeightPhaseManager] Not authenticated - skipping cloud sync")
            completion(true)
            return
        }
        
        switch operation {
        case .add:
            let phaseData = convertWeightPhaseToSupabase(phase)
            supabaseService.saveWeightPhases([phaseData]) { success in
                if success {
                    print("[WeightPhaseManager] ✅ Phase added to Supabase")
                } else {
                    print("[WeightPhaseManager] ❌ Failed to add phase to Supabase")
                }
                completion(success)
            }
            
        case .update:
            let phaseData = convertWeightPhaseToSupabase(phase)
            supabaseService.updateWeightPhase(phaseData) { success in
                if success {
                    print("[WeightPhaseManager] ✅ Phase updated in Supabase")
                } else {
                    print("[WeightPhaseManager] ❌ Failed to update phase in Supabase")
                }
                completion(success)
            }
            
        case .delete:
            supabaseService.deleteWeightPhase(phase.id.uuidString) { success in
                if success {
                    print("[WeightPhaseManager] ✅ Phase deleted from Supabase")
                } else {
                    print("[WeightPhaseManager] ❌ Failed to delete phase from Supabase")
                }
                completion(success)
            }
        }
    }
    
    private enum CloudOperation {
        case add, update, delete
    }
    
    private func clearCurrentUserData() {
        phases = []
    }
    
    // MARK: - Data Conversion Methods
    
    private func convertWeightPhaseToSupabase(_ phase: WeightPhase) -> [String: Any] {
        guard let currentUser = SimpleAuthService.shared.currentUser else {
            return [:]
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        return [
            "id": phase.id.uuidString,
            "user_id": currentUser.id,
            "name": phase.name,
            "description": phase.description,
            "start_date": dateFormatter.string(from: phase.startDate),
            "end_date": dateFormatter.string(from: phase.endDate),
            "target_weekly_rate": phase.targetWeeklyRate,
            "color": phase.color.rawValue,
            "notes": phase.notes ?? ""
        ]
    }
    
    private func convertSupabaseToWeightPhase(_ data: [String: Any]) -> WeightPhase? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = data["name"] as? String,
              let description = data["description"] as? String,
              let startDateString = data["start_date"] as? String,
              let endDateString = data["end_date"] as? String,
              let targetWeeklyRate = data["target_weekly_rate"] as? Double,
              let colorString = data["color"] as? String,
              let phaseColor = PhaseColor(rawValue: colorString) else {
            return nil
        }
        
        let dateFormatter = ISO8601DateFormatter()
        guard let startDate = dateFormatter.date(from: startDateString),
              let endDate = dateFormatter.date(from: endDateString) else {
            return nil
        }
        
        let notes = data["notes"] as? String
        
        return WeightPhase(
            id: id,
            name: name,
            description: description,
            startDate: startDate,
            endDate: endDate,
            targetWeeklyRate: targetWeeklyRate,
            color: phaseColor,
            notes: notes?.isEmpty == false ? notes : nil
        )
    }
    
    private func mergeCloudPhases(_ cloudPhases: [WeightPhase]) {
        // Create a dictionary of cloud phases by ID for quick lookup
        let cloudPhasesDict = Dictionary(uniqueKeysWithValues: cloudPhases.map { ($0.id, $0) })
        
        // Start with cloud phases (they take precedence)
        var mergedPhases = cloudPhases
        
        // Add any local phases that don't exist in cloud
        for localPhase in phases {
            if cloudPhasesDict[localPhase.id] == nil {
                mergedPhases.append(localPhase)
            }
        }
        
        // Update phases and save locally
        phases = mergedPhases.sorted { $0.startDate < $1.startDate }
        savePhasesToLocal()
    }
    
    // MARK: - Phase Operations
    
    func addPhase(_ phase: WeightPhase) {
        // Update local data immediately
        phases.append(phase)
        phases.sort { $0.startDate < $1.startDate }
        savePhasesToLocal()
        
        // Sync to cloud
        syncToCloud(phase, operation: .add)
    }
    
    func updatePhase(_ phase: WeightPhase) {
        if let index = phases.firstIndex(where: { $0.id == phase.id }) {
            // Update local data immediately
            phases[index] = phase
            phases.sort { $0.startDate < $1.startDate }
            savePhasesToLocal()
            
            // Sync to cloud
            syncToCloud(phase, operation: .update)
        }
    }
    
    func deletePhase(_ phase: WeightPhase) {
        // Update local data immediately
        phases.removeAll { $0.id == phase.id }
        savePhasesToLocal()
        
        // Sync to cloud
        syncToCloud(phase, operation: .delete)
    }
    
    func deletePhase(at indexSet: IndexSet) {
        // Store phases to delete for cloud sync
        let phasesToDelete = indexSet.map { phases[$0] }
        
        // Update local data immediately
        phases.remove(atOffsets: indexSet)
        savePhasesToLocal()
        
        // Sync deletions to cloud
        for phase in phasesToDelete {
            syncToCloud(phase, operation: .delete)
        }
    }
    
    // MARK: - Query Methods
    
    // Get the currently active phase
    var currentPhase: WeightPhase? {
        return phases.first { $0.isActive }
    }
    
    // Get phase for a specific date
    func phase(for date: Date) -> WeightPhase? {
        let calendar = Calendar.current
        return phases.first { phase in
            let startOfStartDate = calendar.startOfDay(for: phase.startDate)
            let startOfEndDate = calendar.startOfDay(for: phase.endDate)
            let startOfDate = calendar.startOfDay(for: date)
            
            return startOfDate >= startOfStartDate && startOfDate <= startOfEndDate
        }
    }
    
    // Get all phases that overlap with a date range
    func phases(overlapping startDate: Date, endDate: Date) -> [WeightPhase] {
        return phases.filter { phase in
            // Check if phases overlap
            phase.startDate <= endDate && phase.endDate >= startDate
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
}
