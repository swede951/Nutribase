import SwiftUI
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// Firebase Weight Service for weight log data
class FirebaseWeightService: ObservableObject {
    static let shared = FirebaseWeightService()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif
    
    private init() {}
    
    // MARK: - Weight Entry Management
    
    func saveWeightEntry(_ entry: WeightLogEntry, userId: String, completion: @escaping (Bool) -> Void) {
        print("[FirebaseWeight] Saving weight entry for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        
        let data = entry.toFirebaseData()
        let docRef = db.collection("users").document(userId).collection("weight_logs").document(entry.id.uuidString)
        
        docRef.setData(data, merge: true) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[FirebaseWeight] ❌ Save error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("[FirebaseWeight] ✅ Weight entry saved successfully")
                    completion(true)
                }
            }
        }
        #else
        // Fallback when Firebase is not available
        print("[FirebaseWeight] Firebase not available, using local storage only")
        completion(true)
        #endif
    }
    
    func fetchWeightEntries(userId: String, completion: @escaping ([WeightLogEntry]) -> Void) {
        print("[FirebaseWeight] Fetching weight entries for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        
        let collectionRef = db.collection("users").document(userId).collection("weight_logs")
        
        collectionRef.order(by: "date", descending: true).getDocuments { [weak self] querySnapshot, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[FirebaseWeight] ❌ Fetch error: \(error.localizedDescription)")
                    completion([])
                } else if let documents = querySnapshot?.documents {
                    let entries = documents.compactMap { doc -> WeightLogEntry? in
                        return WeightLogEntry.fromFirebaseData(doc.data(), id: doc.documentID)
                    }
                    print("[FirebaseWeight] ✅ Fetched \(entries.count) weight entries")
                    completion(entries)
                } else {
                    print("[FirebaseWeight] No weight entries found")
                    completion([])
                }
            }
        }
        #else
        // Fallback when Firebase is not available
        print("[FirebaseWeight] Firebase not available")
        completion([])
        #endif
    }
    
    func deleteWeightEntry(entryId: String, userId: String, completion: @escaping (Bool) -> Void) {
        print("[FirebaseWeight] Deleting weight entry: \(entryId) for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        
        let docRef = db.collection("users").document(userId).collection("weight_logs").document(entryId)
        
        docRef.delete { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[FirebaseWeight] ❌ Delete error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("[FirebaseWeight] ✅ Weight entry deleted successfully")
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
    
    func batchSaveWeightEntries(_ entries: [WeightLogEntry], userId: String, completion: @escaping (Bool) -> Void) {
        print("[FirebaseWeight] Batch saving \(entries.count) weight entries for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        
        let batch = db.batch()
        let collectionRef = db.collection("users").document(userId).collection("weight_logs")
        
        for entry in entries {
            let docRef = collectionRef.document(entry.id.uuidString)
            let data = entry.toFirebaseData()
            batch.setData(data, forDocument: docRef, merge: true)
        }
        
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[FirebaseWeight] ❌ Batch save error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("[FirebaseWeight] ✅ Batch save successful")
                    completion(true)
                }
            }
        }
        #else
        // Fallback when Firebase is not available
        completion(true)
        #endif
    }
    
    func batchDeleteWeightEntries(entryIds: [String], userId: String, completion: @escaping (Bool) -> Void) {
        print("[FirebaseWeight] Batch deleting \(entryIds.count) weight entries for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        
        let batch = db.batch()
        let collectionRef = db.collection("users").document(userId).collection("weight_logs")
        
        for entryId in entryIds {
            let docRef = collectionRef.document(entryId)
            batch.deleteDocument(docRef)
        }
        
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[FirebaseWeight] ❌ Batch delete error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("[FirebaseWeight] ✅ Batch delete successful")
                    completion(true)
                }
            }
        }
        #else
        // Fallback when Firebase is not available
        completion(true)
        #endif
    }
    
    // MARK: - Real-time Weight Listener
    
    func listenToWeightEntries(userId: String, completion: @escaping ([WeightLogEntry]) -> Void) -> ListenerRegistration? {
        print("[FirebaseWeight] Setting up real-time listener for user: \(userId)")
        
        #if canImport(FirebaseFirestore)
        let collectionRef = db.collection("users").document(userId).collection("weight_logs")
        
        let listener = collectionRef.order(by: "date", descending: true).addSnapshotListener { querySnapshot, error in
            if let error = error {
                print("[FirebaseWeight] ❌ Listener error: \(error.localizedDescription)")
                completion([])
            } else if let documents = querySnapshot?.documents {
                let entries = documents.compactMap { doc -> WeightLogEntry? in
                    return WeightLogEntry.fromFirebaseData(doc.data(), id: doc.documentID)
                }
                print("[FirebaseWeight] 🔄 Weight entries updated via listener: \(entries.count)")
                completion(entries)
            } else {
                print("[FirebaseWeight] No weight entries in listener")
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
    
    func fetchWeightEntriesInDateRange(userId: String, startDate: Date, endDate: Date, completion: @escaping ([WeightLogEntry]) -> Void) {
        print("[FirebaseWeight] Fetching weight entries for user: \(userId) from \(startDate) to \(endDate)")
        
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        
        let collectionRef = db.collection("users").document(userId).collection("weight_logs")
        
        collectionRef
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("date", isLessThanOrEqualTo: Timestamp(date: endDate))
            .order(by: "date", descending: true)
            .getDocuments { [weak self] querySnapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        print("[FirebaseWeight] ❌ Date range fetch error: \(error.localizedDescription)")
                        completion([])
                    } else if let documents = querySnapshot?.documents {
                        let entries = documents.compactMap { doc -> WeightLogEntry? in
                            return WeightLogEntry.fromFirebaseData(doc.data(), id: doc.documentID)
                        }
                        print("[FirebaseWeight] ✅ Fetched \(entries.count) weight entries in date range")
                        completion(entries)
                    } else {
                        print("[FirebaseWeight] No weight entries found in date range")
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

// MARK: - WeightLogEntry Firebase Extensions

extension WeightLogEntry {
    func toFirebaseData() -> [String: Any] {
        var data: [String: Any] = [
            "weight": weight,
            "moving_average": movingAverage,
            "created_at": FieldValue.serverTimestamp()
        ]
        
        #if canImport(FirebaseFirestore)
        data["date"] = Timestamp(date: date)
        #endif
        
        if let weeklyRate = weeklyRate {
            data["weekly_rate"] = weeklyRate
        }
        
        if let notes = notes {
            data["notes"] = notes
        }
        
        return data
    }
    
    static func fromFirebaseData(_ data: [String: Any], id: String) -> WeightLogEntry? {
        guard let weight = data["weight"] as? Double,
              let movingAverage = data["moving_average"] as? Double else {
            return nil
        }
        
        var date = Date()
        #if canImport(FirebaseFirestore)
        if let timestamp = data["date"] as? Timestamp {
            date = timestamp.dateValue()
        }
        #endif
        
        let weeklyRate = data["weekly_rate"] as? Double
        let notes = data["notes"] as? String
        
        guard let uuid = UUID(uuidString: id) else {
            return nil
        }
        
        return WeightLogEntry(
            id: uuid,
            date: date,
            weight: weight,
            movingAverage: movingAverage,
            weeklyRate: weeklyRate,
            notes: notes
        )
    }
}
