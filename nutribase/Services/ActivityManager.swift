import Foundation
import SwiftUI
import Combine

class ActivityManager: ObservableObject {
    static let shared = ActivityManager()
    
    @Published var currentActivity: ActivityData = .empty
    @Published var isLoading: Bool = false
    
    private let healthKitManager = HealthKitManager.shared
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    private init() {
        loadSavedData()
        setupObservers()
        startRefreshTimer()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    private func setupObservers() {
        // Observe changes to todaySteps in HealthKitManager
        healthKitManager.$todaySteps
            .dropFirst() // Skip initial value
            .sink { [weak self] newSteps in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.currentActivity.steps = newSteps
                    self.saveCurrentData()
                }
            }
            .store(in: &cancellables)
    }
    
    private func startRefreshTimer() {
        // Refresh activity data every 2 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.refreshActivityData()
        }
        refreshTimer?.tolerance = 10 // Allow some tolerance for better battery performance
    }
    
    func loadSavedData() {
        if let savedSteps = userDefaults.object(forKey: "lastSavedSteps") as? Int,
           let savedPreviousSteps = userDefaults.object(forKey: "lastSavedPreviousSteps") as? Int {
            currentActivity = ActivityData(steps: savedSteps, previousSteps: savedPreviousSteps)
        }
    }
    
    func saveCurrentData() {
        userDefaults.set(currentActivity.steps, forKey: "lastSavedSteps")
        userDefaults.set(currentActivity.previousSteps, forKey: "lastSavedPreviousSteps")
    }
    
    func refreshActivityData() {
        guard healthKitManager.isAuthorized else { return }
        
        isLoading = true
        
        // Get yesterday's steps for comparison
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // Check if today is actually tomorrow due to timezone issues
        let adjustedToday = today > now ? calendar.date(byAdding: .day, value: -1, to: today) ?? now : today
        
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: adjustedToday) else {
            isLoading = false
            return
        }
        
        let yesterdayStart = calendar.startOfDay(for: yesterday)
        let yesterdayEnd = adjustedToday
        
        // Use the refreshHealthData method to ensure we get the latest data
        healthKitManager.refreshHealthData()
        
        // First get yesterday's steps
        getStepsForDateRange(start: yesterdayStart, end: yesterdayEnd) { [weak self] yesterdaySteps in
            guard let self = self else { return }
            
            // Then get today's steps
            self.getStepsForDateRange(start: adjustedToday, end: now) { todaySteps in
                DispatchQueue.main.async {
                    self.currentActivity = ActivityData(steps: todaySteps, previousSteps: yesterdaySteps)
                    self.saveCurrentData()
                    self.isLoading = false
                }
            }
        }
    }
    
    private func getStepsForDateRange(start: Date, end: Date, completion: @escaping (Int) -> Void) {
        healthKitManager.fetchStepsForDateRange(start: start, end: end) { steps, error in
            if let error = error {
                print("Error fetching steps: \(error.localizedDescription)")
                completion(0)
                return
            }
            
            completion(steps)
        }
    }
}
