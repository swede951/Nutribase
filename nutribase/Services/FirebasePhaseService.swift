import SwiftUI
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// Firebase Phase Service for weight phases data
class FirebasePhaseService: ObservableObject {
    static let shared = FirebasePhaseService()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif
    
    private init() {}
    
    // MARK: - Phase Management
    
    func savePhase(_ phase: WeightPhase, userId: String, completion: @escaping (Bool) -> Void) {
        print("[FirebasePhase] Saving phase for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        
        let data = phase.toFirebaseData()
        let docRef = db.collection("users").document(userId).collection("weight_phases").document(phase.id.uuidString)
        
        docRef.setData(data, merge: true) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[FirebasePhase] ❌ Save error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("[FirebasePhase] ✅ Phase saved successfully")
                    completion(true)
                }
            }
        }
        #else
        // Fallback when Firebase is not available
        print("[FirebasePhase] Firebase not available, using local storage only")
        completion(true)
        #endif
    }
    
    func fetchPhases(userId: String, completion: @escaping ([WeightPhase]) -> Void) {
        print("[FirebasePhase] Fetching phases for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        
        let collectionRef = db.collection("users").document(userId).collection("weight_phases")
        
        collectionRef.order(by: "start_date", descending: true).getDocuments { [weak self] querySnapshot, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[FirebasePhase] ❌ Fetch error: \(error.localizedDescription)")
                    completion([])
                } else if let documents = querySnapshot?.documents {
                    let phases = documents.compactMap { doc -> WeightPhase? in
                        return WeightPhase.fromFirebaseData(doc.data(), id: doc.documentID)
                    }
                    print("[FirebasePhase] ✅ Fetched \(phases.count) phases")
                    completion(phases)
                } else {
                    print("[FirebasePhase] No phases found")
                    completion([])
                }
            }
        }
        #else
        // Fallback when Firebase is not available
        print("[FirebasePhase] Firebase not available")
        completion([])
        #endif
    }
    
    func deletePhase(phaseId: String, userId: String, completion: @escaping (Bool) -> Void) {
        print("[FirebasePhase] Deleting phase: \(phaseId) for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        
        let docRef = db.collection("users").document(userId).collection("weight_phases").document(phaseId)
        
        docRef.delete { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[FirebasePhase] ❌ Delete error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("[FirebasePhase] ✅ Phase deleted successfully")
                    completion(true)
                }
            }
        }
        #else
        // Fallback when Firebase is not available
        completion(true)
        #endif
    }
    
    // MARK: - Batch Operations
    
    func batchSavePhases(_ phases: [WeightPhase], userId: String, completion: @escaping (Bool) -> Void) {
        print("[FirebasePhase] Batch saving \(phases.count) phases for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        
        let batch = db.batch()
        let collectionRef = db.collection("users").document(userId).collection("weight_phases")
        
        for phase in phases {
            let docRef = collectionRef.document(phase.id.uuidString)
            let data = phase.toFirebaseData()
            batch.setData(data, forDocument: docRef, merge: true)
        }
        
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[FirebasePhase] ❌ Batch save error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("[FirebasePhase] ✅ Batch save successful")
                    completion(true)
                }
            }
        }
        #else
        // Fallback when Firebase is not available
        completion(true)
        #endif
    }
    
    // MARK: - Real-time Phase Listener
    
    func listenToPhases(userId: String, completion: @escaping ([WeightPhase]) -> Void) -> ListenerRegistration? {
        print("[FirebasePhase] Setting up real-time listener for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        let collectionRef = db.collection("users").document(userId).collection("weight_phases")
        
        let listener = collectionRef.order(by: "start_date", descending: true).addSnapshotListener { querySnapshot, error in
            if let error = error {
                print("[FirebasePhase] ❌ Listener error: \(error.localizedDescription)")
                completion([])
            } else if let documents = querySnapshot?.documents {
                let phases = documents.compactMap { doc -> WeightPhase? in
                    return WeightPhase.fromFirebaseData(doc.data(), id: doc.documentID)
                }
                print("[FirebasePhase] 🔄 Phases updated via listener: \(phases.count)")
                completion(phases)
            } else {
                print("[FirebasePhase] No phases in listener")
                completion([])
            }
        }
        
        return listener
        #else
        // Fallback when Firebase is not available
        return nil
        #endif
    }
    
    // MARK: - Query Operations
    
    func fetchActivePhases(userId: String, completion: @escaping ([WeightPhase]) -> Void) {
        print("[FirebasePhase] Fetching active phases for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        
        let collectionRef = db.collection("users").document(userId).collection("weight_phases")
        let now = Timestamp(date: Date())
        
        collectionRef
            .whereField("start_date", isLessThanOrEqualTo: now)
            .whereField("end_date", isGreaterThanOrEqualTo: now)
            .order(by: "start_date", descending: true)
            .getDocuments { [weak self] querySnapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        print("[FirebasePhase] ❌ Active phases fetch error: \(error.localizedDescription)")
                        completion([])
                    } else if let documents = querySnapshot?.documents {
                        let phases = documents.compactMap { doc -> WeightPhase? in
                            return WeightPhase.fromFirebaseData(doc.data(), id: doc.documentID)
                        }
                        print("[FirebasePhase] ✅ Fetched \(phases.count) active phases")
                        completion(phases)
                    } else {
                        print("[FirebasePhase] No active phases found")
                        completion([])
                    }
                }
            }
        #else
        // Fallback when Firebase is not available
        completion([])
        #endif
    }
    
    func fetchPhasesInDateRange(userId: String, startDate: Date, endDate: Date, completion: @escaping ([WeightPhase]) -> Void) {
        print("[FirebasePhase] Fetching phases for user: \(userId) from \(startDate) to \(endDate)")
        
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        
        let collectionRef = db.collection("users").document(userId).collection("weight_phases")
        
        collectionRef
            .whereField("start_date", isLessThanOrEqualTo: Timestamp(date: endDate))
            .whereField("end_date", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .order(by: "start_date", descending: true)
            .getDocuments { [weak self] querySnapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        print("[FirebasePhase] ❌ Date range fetch error: \(error.localizedDescription)")
                        completion([])
                    } else if let documents = querySnapshot?.documents {
                        let phases = documents.compactMap { doc -> WeightPhase? in
                            return WeightPhase.fromFirebaseData(doc.data(), id: doc.documentID)
                        }
                        print("[FirebasePhase] ✅ Fetched \(phases.count) phases in date range")
                        completion(phases)
                    } else {
                        print("[FirebasePhase] No phases found in date range")
                        completion([])
                    }
                }
            }
        #else
        // Fallback when Firebase is not available
        completion([])
        #endif
    }
}

// MARK: - WeightPhase Firebase Extensions

extension WeightPhase {
    func toFirebaseData() -> [String: Any] {
        var data: [String: Any] = [
            "name": name,
            "description": description,
            "target_weekly_rate": targetWeeklyRate,
            "color": color.rawValue,
            "created_at": FieldValue.serverTimestamp()
        ]
        
        #if canImport(FirebaseFirestore)
        data["start_date"] = Timestamp(date: startDate)
        data["end_date"] = Timestamp(date: endDate)
        #else
        // Fallback for when Firebase is not available
        let formatter = ISO8601DateFormatter()
        data["start_date"] = formatter.string(from: startDate)
        data["end_date"] = formatter.string(from: endDate)
        #endif
        
        if let notes = notes, !notes.isEmpty {
            data["notes"] = notes
        }
        
        // Add goal weight if available
        if let goalWeight = goalWeight {
            data["goal_weight"] = goalWeight
        }
        
        return data
    }
    
    static func fromFirebaseData(_ data: [String: Any], id: String) -> WeightPhase? {
        guard let name = data["name"] as? String,
              let description = data["description"] as? String,
              let targetWeeklyRate = data["target_weekly_rate"] as? Double,
              let color = data["color"] as? String else {
            return nil
        }
        
        var startDate = Date()
        var endDate = Date()
        
        #if canImport(FirebaseFirestore)
        if let startTimestamp = data["start_date"] as? Timestamp {
            startDate = startTimestamp.dateValue()
        }
        if let endTimestamp = data["end_date"] as? Timestamp {
            endDate = endTimestamp.dateValue()
        }
        #endif
        
        let notes = data["notes"] as? String
        let goalWeight = data["goal_weight"] as? Double
        
        guard let uuid = UUID(uuidString: id) else {
            return nil
        }
        
        return WeightPhase(
            id: uuid,
            name: name,
            description: description,
            startDate: startDate,
            endDate: endDate,
            targetWeeklyRate: targetWeeklyRate,
            color: PhaseColor(rawValue: color) ?? .blue,
            notes: notes,
            goalWeight: goalWeight
        )
    }
}
