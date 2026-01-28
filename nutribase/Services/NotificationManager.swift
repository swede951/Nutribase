//
//  NotificationManager.swift
//  nutribase
//
//  Created on 13/11/2025.
//

import Foundation
import UserNotifications
import Combine

/// Manages all app notifications with user-controlled settings
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private let center = UNUserNotificationCenter.current()
    private var cancellables = Set<AnyCancellable>()
    
    // User-specific keys
    private var notificationsEnabledKey: String {
        if let userId = FirebaseAuthService.shared.currentUser?.id {
            return "notificationsEnabled_\(userId)"
        } else if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
            return "notificationsEnabled_\(localUserId)"
        }
        return "notificationsEnabled_default"
    }
    
    private var dailyReminderEnabledKey: String {
        if let userId = FirebaseAuthService.shared.currentUser?.id {
            return "dailyReminderEnabled_\(userId)"
        } else if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
            return "dailyReminderEnabled_\(localUserId)"
        }
        return "dailyReminderEnabled_default"
    }
    
    private var dailyReminderTimeKey: String {
        if let userId = FirebaseAuthService.shared.currentUser?.id {
            return "dailyReminderTime_\(userId)"
        } else if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
            return "dailyReminderTime_\(localUserId)"
        }
        return "dailyReminderTime_default"
    }
    
    private var milestonesEnabledKey: String {
        if let userId = FirebaseAuthService.shared.currentUser?.id {
            return "milestonesEnabled_\(userId)"
        } else if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
            return "milestonesEnabled_\(localUserId)"
        }
        return "milestonesEnabled_default"
    }
    
    private var weeklySummaryEnabledKey: String {
        if let userId = FirebaseAuthService.shared.currentUser?.id {
            return "weeklySummaryEnabled_\(userId)"
        } else if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
            return "weeklySummaryEnabled_\(localUserId)"
        }
        return "weeklySummaryEnabled_default"
    }
    
    private var reEngagementEnabledKey: String {
        if let userId = FirebaseAuthService.shared.currentUser?.id {
            return "reEngagementEnabled_\(userId)"
        } else if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
            return "reEngagementEnabled_\(localUserId)"
        }
        return "reEngagementEnabled_default"
    }
    
    private var dataInsightsEnabledKey: String {
        if let userId = FirebaseAuthService.shared.currentUser?.id {
            return "dataInsightsEnabled_\(userId)"
        } else if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
            return "dataInsightsEnabled_\(localUserId)"
        }
        return "dataInsightsEnabled_default"
    }
    
    private var quietHoursEnabledKey: String {
        if let userId = FirebaseAuthService.shared.currentUser?.id {
            return "quietHoursEnabled_\(userId)"
        } else if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
            return "quietHoursEnabled_\(localUserId)"
        }
        return "quietHoursEnabled_default"
    }
    
    private var quietHoursStartKey: String {
        if let userId = FirebaseAuthService.shared.currentUser?.id {
            return "quietHoursStart_\(userId)"
        } else if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
            return "quietHoursStart_\(localUserId)"
        }
        return "quietHoursStart_default"
    }
    
    private var quietHoursEndKey: String {
        if let userId = FirebaseAuthService.shared.currentUser?.id {
            return "quietHoursEnd_\(userId)"
        } else if let localUserId = UserDefaults.standard.string(forKey: "current_user_id") {
            return "quietHoursEnd_\(localUserId)"
        }
        return "quietHoursEnd_default"
    }
    
    // MARK: - Notification Settings (stored in UserDefaults)
    
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: notificationsEnabledKey)
            if !notificationsEnabled {
                cancelAllNotifications()
            }
        }
    }
    
    @Published var dailyReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(dailyReminderEnabled, forKey: dailyReminderEnabledKey)
            if dailyReminderEnabled {
                scheduleDailyReminder()
            } else {
                cancelNotification(identifier: "dailyReminder")
            }
        }
    }
    
    @Published var dailyReminderTime: Date {
        didSet {
            UserDefaults.standard.set(dailyReminderTime, forKey: dailyReminderTimeKey)
            if dailyReminderEnabled {
                scheduleDailyReminder()
            }
        }
    }
    
    @Published var milestonesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(milestonesEnabled, forKey: milestonesEnabledKey)
        }
    }
    
    @Published var weeklySummaryEnabled: Bool {
        didSet {
            UserDefaults.standard.set(weeklySummaryEnabled, forKey: weeklySummaryEnabledKey)
            if weeklySummaryEnabled {
                scheduleWeeklySummary()
            } else {
                cancelNotification(identifier: "weeklySummary")
            }
        }
    }
    
    @Published var reEngagementEnabled: Bool {
        didSet {
            UserDefaults.standard.set(reEngagementEnabled, forKey: reEngagementEnabledKey)
        }
    }
    
    @Published var dataInsightsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(dataInsightsEnabled, forKey: dataInsightsEnabledKey)
        }
    }
    
    @Published var quietHoursEnabled: Bool {
        didSet {
            UserDefaults.standard.set(quietHoursEnabled, forKey: quietHoursEnabledKey)
        }
    }
    
    @Published var quietHoursStart: Date {
        didSet {
            UserDefaults.standard.set(quietHoursStart, forKey: quietHoursStartKey)
        }
    }
    
    @Published var quietHoursEnd: Date {
        didSet {
            UserDefaults.standard.set(quietHoursEnd, forKey: quietHoursEndKey)
        }
    }
    
    private init() {
        // Compute keys inline to avoid 'self' usage before initialization
        let userId = FirebaseAuthService.shared.currentUser?.id
        let localUserId = UserDefaults.standard.string(forKey: "current_user_id")
        
        let notifEnabledKey = userId.map { "notificationsEnabled_\($0)" } ?? localUserId.map { "notificationsEnabled_\($0)" } ?? "notificationsEnabled_default"
        let dailyReminderEnabledKey = userId.map { "dailyReminderEnabled_\($0)" } ?? localUserId.map { "dailyReminderEnabled_\($0)" } ?? "dailyReminderEnabled_default"
        let milestonesEnabledKey = userId.map { "milestonesEnabled_\($0)" } ?? localUserId.map { "milestonesEnabled_\($0)" } ?? "milestonesEnabled_default"
        let weeklySummaryEnabledKey = userId.map { "weeklySummaryEnabled_\($0)" } ?? localUserId.map { "weeklySummaryEnabled_\($0)" } ?? "weeklySummaryEnabled_default"
        let reEngagementEnabledKey = userId.map { "reEngagementEnabled_\($0)" } ?? localUserId.map { "reEngagementEnabled_\($0)" } ?? "reEngagementEnabled_default"
        let dataInsightsEnabledKey = userId.map { "dataInsightsEnabled_\($0)" } ?? localUserId.map { "dataInsightsEnabled_\($0)" } ?? "dataInsightsEnabled_default"
        let quietHoursEnabledKey = userId.map { "quietHoursEnabled_\($0)" } ?? localUserId.map { "quietHoursEnabled_\($0)" } ?? "quietHoursEnabled_default"
        let dailyReminderTimeKey = userId.map { "dailyReminderTime_\($0)" } ?? localUserId.map { "dailyReminderTime_\($0)" } ?? "dailyReminderTime_default"
        let quietHoursStartKey = userId.map { "quietHoursStart_\($0)" } ?? localUserId.map { "quietHoursStart_\($0)" } ?? "quietHoursStart_default"
        let quietHoursEndKey = userId.map { "quietHoursEnd_\($0)" } ?? localUserId.map { "quietHoursEnd_\($0)" } ?? "quietHoursEnd_default"
        
        // Load settings from UserDefaults with defaults
        self.notificationsEnabled = UserDefaults.standard.object(forKey: notifEnabledKey) as? Bool ?? false
        self.dailyReminderEnabled = UserDefaults.standard.object(forKey: dailyReminderEnabledKey) as? Bool ?? false
        self.milestonesEnabled = UserDefaults.standard.object(forKey: milestonesEnabledKey) as? Bool ?? true // Default ON
        self.weeklySummaryEnabled = UserDefaults.standard.object(forKey: weeklySummaryEnabledKey) as? Bool ?? false
        self.reEngagementEnabled = UserDefaults.standard.object(forKey: reEngagementEnabledKey) as? Bool ?? false
        self.dataInsightsEnabled = UserDefaults.standard.object(forKey: dataInsightsEnabledKey) as? Bool ?? false
        self.quietHoursEnabled = UserDefaults.standard.object(forKey: quietHoursEnabledKey) as? Bool ?? false
        
        // Default times
        let calendar = Calendar.current
        self.dailyReminderTime = UserDefaults.standard.object(forKey: dailyReminderTimeKey) as? Date ?? calendar.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
        self.quietHoursStart = UserDefaults.standard.object(forKey: quietHoursStartKey) as? Date ?? calendar.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
        self.quietHoursEnd = UserDefaults.standard.object(forKey: quietHoursEndKey) as? Date ?? calendar.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
        
        setupAuthenticationObservers()
    }
    
    // Set up authentication notification observers
    private func setupAuthenticationObservers() {
        NotificationCenter.default.publisher(for: .userDidSignIn)
            .sink { [weak self] _ in
                self?.loadSettings()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .userDidSignOut)
            .sink { [weak self] _ in
                self?.loadSettings()
            }
            .store(in: &cancellables)
    }
    
    // Load settings for current user
    private func loadSettings() {
        let calendar = Calendar.current
        notificationsEnabled = UserDefaults.standard.object(forKey: notificationsEnabledKey) as? Bool ?? false
        dailyReminderEnabled = UserDefaults.standard.object(forKey: dailyReminderEnabledKey) as? Bool ?? false
        milestonesEnabled = UserDefaults.standard.object(forKey: milestonesEnabledKey) as? Bool ?? true
        weeklySummaryEnabled = UserDefaults.standard.object(forKey: weeklySummaryEnabledKey) as? Bool ?? false
        reEngagementEnabled = UserDefaults.standard.object(forKey: reEngagementEnabledKey) as? Bool ?? false
        dataInsightsEnabled = UserDefaults.standard.object(forKey: dataInsightsEnabledKey) as? Bool ?? false
        quietHoursEnabled = UserDefaults.standard.object(forKey: quietHoursEnabledKey) as? Bool ?? false
        dailyReminderTime = UserDefaults.standard.object(forKey: dailyReminderTimeKey) as? Date ?? calendar.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
        quietHoursStart = UserDefaults.standard.object(forKey: quietHoursStartKey) as? Date ?? calendar.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
        quietHoursEnd = UserDefaults.standard.object(forKey: quietHoursEndKey) as? Date ?? calendar.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    }
    
    // MARK: - Permission Management
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    self.notificationsEnabled = true
                }
                completion(granted)
            }
        }
    }
    
    func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
    
    // MARK: - Notification Scheduling (Infrastructure Only - Not Active)
    
    private func scheduleDailyReminder() {
        guard notificationsEnabled && dailyReminderEnabled else { return }
        
        // Cancel existing
        cancelNotification(identifier: "dailyReminder")
        
        // Schedule new (implementation ready but not active)
        // This will be implemented when notifications are enabled
    }
    
    private func scheduleWeeklySummary() {
        guard notificationsEnabled && weeklySummaryEnabled else { return }
        
        // Cancel existing
        cancelNotification(identifier: "weeklySummary")
        
        // Schedule new (implementation ready but not active)
        // This will be implemented when notifications are enabled
    }
    
    // MARK: - Milestone Notifications (Infrastructure Only)
    
    func notifyMilestone(type: MilestoneType) {
        guard notificationsEnabled && milestonesEnabled else { return }
        
        // Implementation ready but not active
        // This will be implemented when notifications are enabled
    }
    
    // MARK: - Utility Methods
    
    private func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
    
    func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        center.getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(requests)
            }
        }
    }
}

// MARK: - Notification Types

enum MilestoneType {
    case streak7Days
    case streak30Days
    case phaseCompleted
    case personalRecord
    case weekMilestone(percentage: Int)
}
