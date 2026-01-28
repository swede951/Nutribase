import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    private let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let bodyMassQuantityType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
    private let activeEnergyQuantityType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    
    @Published var todaySteps: Int = 0
    @Published var weeklySteps: [Int] = Array(repeating: 0, count: 7)
    @Published var todayActiveCalories: Int = 0
    @Published var isAuthorized: Bool = false
    @Published var isWeightAuthorized: Bool = false
    
    // Store query for observer
    private var stepCountObserverQuery: HKObserverQuery?
    private var activeEnergyObserverQuery: HKObserverQuery?
    
    private init() {
        checkAuthorizationStatus()
    }
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        print("[HealthKitManager] Requesting HealthKit authorization...")
        
        // Check if HealthKit is available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HealthKitManager] HealthKit not available on this device")
            completion(false, nil)
            return
        }
        
        // First check current authorization status
        let currentWeightStatus = healthStore.authorizationStatus(for: bodyMassQuantityType)
        let currentStepsStatus = healthStore.authorizationStatus(for: stepsQuantityType)
        print("[HealthKitManager] Current authorization status - Weight: \(currentWeightStatus.rawValue), Steps: \(currentStepsStatus.rawValue)")
        
        // Define the types we want to read
        let typesToRead: Set<HKObjectType> = [
            stepsQuantityType,
            bodyMassQuantityType,
            activeEnergyQuantityType
        ]
        
        // Request authorization
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { (success, error) in
            print("[HealthKitManager] Authorization request completed - Success: \(success), Error: \(error?.localizedDescription ?? "none")")
            
            DispatchQueue.main.async {
                // Always consider it successful if no error occurred
                // HealthKit may return false even when permissions are granted for privacy reasons
                let effectiveSuccess = (error == nil)
                
                self.isAuthorized = effectiveSuccess
                self.checkWeightAuthorization()
                
                print("[HealthKitManager] Final authorization state - isAuthorized: \(self.isAuthorized), isWeightAuthorized: \(self.isWeightAuthorized)")
                
                if effectiveSuccess {
                    // Set up observers after successful authorization
                    self.setupStepCountObserver()
                    self.setupActiveEnergyObserver()
                    // Initial fetch
                    self.fetchTodaySteps { _, _ in }
                    self.fetchWeeklySteps { _, _ in }
                    self.fetchTodayActiveCalories { _, _ in }
                }
                completion(effectiveSuccess, error)
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        // Check if HealthKit is available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }
        
        let status = healthStore.authorizationStatus(for: stepsQuantityType)
        isAuthorized = (status == .sharingAuthorized)
        checkWeightAuthorization()
        
        if isAuthorized {
            // Set up observers if already authorized
            setupStepCountObserver()
            setupActiveEnergyObserver()
            // Initial fetch
            fetchTodaySteps { _, _ in }
            fetchWeeklySteps { _, _ in }
            fetchTodayActiveCalories { _, _ in }
        }
    }
    
    // Setup observer for step count changes
    private func setupStepCountObserver() {
        // Stop any existing query
        if let existingQuery = stepCountObserverQuery {
            healthStore.stop(existingQuery)
        }
        
        // Create a new observer query
        let query = HKObserverQuery(sampleType: stepsQuantityType, predicate: nil) { [weak self] (query, completionHandler, error) in
            guard let self = self else { return }
            
            if error == nil {
                // Update step counts when changes are detected
                self.fetchTodaySteps { _, _ in }
                self.fetchWeeklySteps { _, _ in }
            }
            
            // Call the completion handler to allow future updates
            completionHandler()
        }
        
        // Execute the query and enable background delivery if available
        healthStore.execute(query)
        
        // Use the completion-handler based version instead of the async version
        healthStore.enableBackgroundDelivery(for: stepsQuantityType, frequency: .immediate) { success, error in
            if let error = error {
                print("Failed to enable background delivery: \(error.localizedDescription)")
            } else if success {
                print("Successfully enabled background delivery for step count")
            }
        }
        
        // Save the query
        stepCountObserverQuery = query
    }
    
    // Setup observer for active energy changes
    private func setupActiveEnergyObserver() {
        // Stop any existing query
        if let existingQuery = activeEnergyObserverQuery {
            healthStore.stop(existingQuery)
        }
        
        // Create a new observer query
        let query = HKObserverQuery(sampleType: activeEnergyQuantityType, predicate: nil) { [weak self] (query, completionHandler, error) in
            guard let self = self else { return }
            
            if error == nil {
                // Update active calories when changes are detected
                self.fetchTodayActiveCalories { _, _ in }
            }
            
            // Call the completion handler to allow future updates
            completionHandler()
        }
        
        // Execute the query and enable background delivery if available
        healthStore.execute(query)
        
        healthStore.enableBackgroundDelivery(for: activeEnergyQuantityType, frequency: .immediate) { success, error in
            if let error = error {
                print("Failed to enable background delivery for active energy: \(error.localizedDescription)")
            } else if success {
                print("Successfully enabled background delivery for active energy")
            }
        }
        
        // Save the query
        activeEnergyObserverQuery = query
    }
    
    func fetchTodayActiveCalories(completion: @escaping (Int, Error?) -> Void) {
        guard isAuthorized else {
            completion(0, nil)
            return
        }
        
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        let queryStartDate = startOfDay > now ? calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? now : startOfDay
        
        let predicate = HKQuery.predicateForSamples(
            withStart: queryStartDate,
            end: now,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: activeEnergyQuantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let result = result, let sum = result.sumQuantity() else {
                    completion(0, error)
                    return
                }
                
                let calories = Int(sum.doubleValue(for: HKUnit.kilocalorie()))
                self.todayActiveCalories = calories
                completion(calories, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchActiveCaloriesForDateRange(start: Date, end: Date, completion: @escaping (Int, Error?) -> Void) {
        guard isAuthorized else {
            completion(0, nil)
            return
        }
        
        let now = Date()
        let queryEnd = end > now ? now : end
        
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: queryEnd,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: activeEnergyQuantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            DispatchQueue.main.async {
                guard let result = result, let sum = result.sumQuantity() else {
                    completion(0, error)
                    return
                }
                
                let calories = Int(sum.doubleValue(for: HKUnit.kilocalorie()))
                completion(calories, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchTodaySteps(completion: @escaping (Int, Error?) -> Void) {
        guard isAuthorized else {
            completion(0, nil)
            return
        }
        
        // Use a calendar with the user's current timezone to ensure correct date boundaries
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        // Make sure we're not querying future data by checking if startOfDay is in the future
        let queryStartDate = startOfDay > now ? calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? now : startOfDay
        
        let predicate = HKQuery.predicateForSamples(
            withStart: queryStartDate,
            end: now,
            options: .strictStartDate
        )
        
        // Use anchor query to get updates since last fetch
        let query = HKStatisticsQuery(
            quantityType: stepsQuantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let result = result, let sum = result.sumQuantity() else {
                    completion(0, error)
                    return
                }
                
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                self.todaySteps = steps
                completion(steps, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchStepsForDateRange(start: Date, end: Date, completion: @escaping (Int, Error?) -> Void) {
        guard isAuthorized else {
            completion(0, nil)
            return
        }
        
        // Ensure we're not querying future data
        let now = Date()
        let queryEnd = end > now ? now : end
        
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: queryEnd,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: stepsQuantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            DispatchQueue.main.async {
                guard let result = result, let sum = result.sumQuantity() else {
                    completion(0, error)
                    return
                }
                
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                completion(steps, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchWeeklySteps(completion: @escaping ([Int], Error?) -> Void) {
        guard isAuthorized else {
            completion(Array(repeating: 0, count: 7), nil)
            return
        }
        
        // Use a calendar with the user's current timezone to ensure correct date boundaries
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        let now = Date()
        let endDate = calendar.startOfDay(for: now)
        
        // Check if startOfDay is in the future (timezone issue)
        let adjustedEndDate = endDate > now ? calendar.date(byAdding: .day, value: -1, to: endDate) ?? now : endDate
        
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: adjustedEndDate) else {
            completion(Array(repeating: 0, count: 7), nil)
            return
        }
        
        var weeklySteps = Array(repeating: 0, count: 7)
        let group = DispatchGroup()
        
        for dayOffset in 0..<7 {
            group.enter()
            
            guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: startDate),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                group.leave()
                continue
            }
            
            // Ensure we don't query future data
            let currentTime = Date()
            let queryEnd = dayEnd > currentTime ? currentTime : dayEnd
            
            // Skip this day entirely if it's completely in the future
            if dayStart > currentTime {
                group.leave()
                continue
            }
            
            let predicate = HKQuery.predicateForSamples(
                withStart: dayStart,
                end: queryEnd,
                options: .strictStartDate
            )
            
            let query = HKStatisticsQuery(
                quantityType: stepsQuantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                defer { group.leave() }
                
                guard let result = result, let sum = result.sumQuantity() else {
                    return
                }
                
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                weeklySteps[dayOffset] = steps
            }
            
            healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            self.weeklySteps = weeklySteps
            completion(weeklySteps, nil)
        }
    }
    
    // Force refresh all health data
    func refreshHealthData() {
        fetchTodaySteps { _, _ in }
        fetchWeeklySteps { _, _ in }
    }
    
    /// Batch fetch daily steps for a date range using HKStatisticsCollectionQuery
    /// This is much more efficient than making individual queries for each day
    func fetchDailyStepsForRange(start: Date, end: Date, completion: @escaping ([Date: Int]) -> Void) {
        guard isAuthorized else {
            completion([:])
            return
        }
        
        let calendar = Calendar.current
        let startOfStartDay = calendar.startOfDay(for: start)
        let now = Date()
        let queryEnd = end > now ? now : end
        
        // Create a predicate for the date range
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfStartDay,
            end: queryEnd,
            options: .strictStartDate
        )
        
        // Create interval components for daily aggregation
        var interval = DateComponents()
        interval.day = 1
        
        // Create the statistics collection query
        let query = HKStatisticsCollectionQuery(
            quantityType: stepsQuantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startOfStartDay,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { _, results, error in
            var dailySteps: [Date: Int] = [:]
            
            if let statsCollection = results {
                statsCollection.enumerateStatistics(from: startOfStartDay, to: queryEnd) { statistics, _ in
                    let date = calendar.startOfDay(for: statistics.startDate)
                    if let sum = statistics.sumQuantity() {
                        dailySteps[date] = Int(sum.doubleValue(for: HKUnit.count()))
                    } else {
                        dailySteps[date] = 0
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion(dailySteps)
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Weight Data Methods
    
    private func checkWeightAuthorization() {
        let status = healthStore.authorizationStatus(for: bodyMassQuantityType)
        print("[HealthKitManager] Weight authorization status: \(status.rawValue)")
        
        // For privacy reasons, HealthKit may return .notDetermined even when access is granted
        // We'll be very aggressive and assume access is available unless explicitly denied
        switch status {
        case .sharingDenied:
            isWeightAuthorized = false
            print("[HealthKitManager] Weight access explicitly denied")
        case .sharingAuthorized:
            isWeightAuthorized = true
            print("[HealthKitManager] Weight access explicitly authorized")
        case .notDetermined:
            // Assume access is available and test with a query
            isWeightAuthorized = true
            print("[HealthKitManager] Weight access not determined - assuming available and testing")
            performTestWeightQuery()
        @unknown default:
            // For any unknown status, assume access is available
            isWeightAuthorized = true
            print("[HealthKitManager] Unknown weight authorization status - assuming available")
        }
        
        print("[HealthKitManager] Final isWeightAuthorized: \(isWeightAuthorized)")
    }
    
    private func performTestWeightQuery() {
        print("[HealthKitManager] Performing test weight query...")
        
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .day, value: -7, to: Date()), // Look back 7 days instead of 1
            end: Date(),
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: bodyMassQuantityType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: nil
        ) { _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[HealthKitManager] Test query failed: \(error.localizedDescription)")
                    // Only set to false if it's clearly an authorization error
                    if error.localizedDescription.contains("authorization") || error.localizedDescription.contains("not authorized") {
                        self.isWeightAuthorized = false
                        print("[HealthKitManager] Authorization error detected - setting isWeightAuthorized to false")
                    } else {
                        print("[HealthKitManager] Non-authorization error - keeping isWeightAuthorized as true")
                    }
                } else {
                    // If no error, we definitely have access
                    self.isWeightAuthorized = true
                    print("[HealthKitManager] Test query successful - confirmed weight access available")
                    if let samples = samples {
                        print("[HealthKitManager] Found \(samples.count) weight samples in test query")
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchWeightData(from startDate: Date, to endDate: Date, completion: @escaping ([WeightLogEntry], Error?) -> Void) {
        print("[HealthKitManager] fetchWeightData called - bypassing authorization check and attempting direct query")
        // Let the actual HealthKit query handle authorization - don't pre-check isWeightAuthorized
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(
            sampleType: bodyMassQuantityType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            print("[HealthKitManager] HealthKit query completed - Samples: \(samples?.count ?? 0), Error: \(error?.localizedDescription ?? "none")")
            
            DispatchQueue.main.async {
                if let error = error {
                    print("[HealthKitManager] Query error: \(error.localizedDescription)")
                    completion([], error)
                    return
                }
                
                guard let samples = samples as? [HKQuantitySample] else {
                    print("[HealthKitManager] No samples or wrong type")
                    completion([], nil)
                    return
                }
                
                print("[HealthKitManager] Successfully retrieved \(samples.count) weight samples")
                
                // Convert HKQuantitySample to WeightLogEntry
                let weightEntries = samples.compactMap { sample -> WeightLogEntry? in
                    let weightInKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    
                    // Create a basic WeightLogEntry (moving average and weekly rate will be calculated later)
                    return WeightLogEntry(
                        date: sample.startDate,
                        weight: weightInKg,
                        movingAverage: weightInKg, // Will be recalculated
                        weeklyRate: nil, // Will be calculated
                        notes: nil
                    )
                }
                
                print("[HealthKitManager] Converted to \(weightEntries.count) WeightLogEntry objects")
                completion(weightEntries, nil)
            }
        }
        
        print("[HealthKitManager] Executing HealthKit query...")
        healthStore.execute(query)
    }
    
    func fetchAllWeightData(completion: @escaping ([WeightLogEntry], Error?) -> Void) {
        // Always try to fetch data - let the actual HealthKit query determine if we have access
        // HealthKit authorization status can be misleading due to privacy protections
        
        // Fetch all available weight data (no date limit)
        let endDate = Date()
        let startDate = Date.distantPast // This will fetch all available data
        
        fetchWeightData(from: startDate, to: endDate) { [weak self] entries, error in
            if let error = error {
                // Check if it's actually an authorization error
                if error.localizedDescription.contains("authorization") || error.localizedDescription.contains("not authorized") {
                    // Update our authorization status
                    DispatchQueue.main.async {
                        self?.isWeightAuthorized = false
                    }
                }
            }
            completion(entries, error)
        }
    }
    
    func requestWeightAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }
        
        let typesToRead: Set<HKObjectType> = [bodyMassQuantityType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { (success, error) in
            DispatchQueue.main.async {
                self.checkWeightAuthorization()
                completion(success, error)
            }
        }
    }
}
