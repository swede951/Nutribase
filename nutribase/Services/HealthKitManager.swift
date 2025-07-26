import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    private let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    
    @Published var todaySteps: Int = 0
    @Published var weeklySteps: [Int] = Array(repeating: 0, count: 7)
    @Published var isAuthorized: Bool = false
    
    // Store query for observer
    private var stepCountObserverQuery: HKObserverQuery?
    
    private init() {
        checkAuthorizationStatus()
    }
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        // Check if HealthKit is available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }
        
        // Define the types we want to read
        let typesToRead: Set<HKObjectType> = [
            stepsQuantityType
        ]
        
        // Request authorization
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { (success, error) in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if success {
                    // Set up observers after successful authorization
                    self.setupStepCountObserver()
                    // Initial fetch
                    self.fetchTodaySteps { _, _ in }
                    self.fetchWeeklySteps { _, _ in }
                }
                completion(success, error)
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
        
        if isAuthorized {
            // Set up observers if already authorized
            setupStepCountObserver()
            // Initial fetch
            fetchTodaySteps { _, _ in }
            fetchWeeklySteps { _, _ in }
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
}
