//
//  AnalyticsService.swift
//  nutribase
//
//  Created by Alex Sweet on 22/08/2025.
//

import Foundation
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

/// Analytics service wrapper for tracking user interactions and feature usage
/// Provides a clean interface that can be swapped between different analytics providers
class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()
    
    @Published private(set) var isEnabled: Bool = false
    private var isInitialized: Bool = false
    
    private init() {
        // Load consent state from UserDefaults
        self.isEnabled = UserDefaults.standard.bool(forKey: "analytics_consent_granted")
    }
    
    // MARK: - Initialization
    
    /// Initialize the analytics service (call after Firebase.configure())
    func initialize() {
        guard !isInitialized else { return }
        
        #if DEBUG
        print("🔍 AnalyticsService: Initializing (Debug mode)")
        #endif
        
        // Configure Firebase Analytics
        configureFirebase()
        
        isInitialized = true
    }
    
    private func configureFirebase() {
        // Set initial analytics collection state
        setAnalyticsCollectionEnabled(isEnabled)
        
        #if DEBUG
        print("🔍 AnalyticsService: Firebase Analytics configured")
        #endif
    }
    
    // MARK: - Consent Management
    
    /// Enable or disable analytics collection based on user consent
    func setAnalyticsCollectionEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "analytics_consent_granted")
        
        #if DEBUG
        print("🔍 AnalyticsService: Analytics collection \(enabled ? "enabled" : "disabled")")
        #endif
        
        // Firebase Analytics collection control
        #if canImport(FirebaseAnalytics)
        Analytics.setAnalyticsCollectionEnabled(enabled)
        #endif
    }
    
    // MARK: - Event Tracking
    
    /// Track a custom event with optional parameters
    func trackEvent(_ name: String, parameters: [String: Any]? = nil) {
        guard isEnabled && isInitialized else { return }
        
        #if DEBUG
        let paramString = parameters?.map { "\($0.key): \($0.value)" }.joined(separator: ", ") ?? "none"
        print("🔍 AnalyticsService: Event '\(name)' - Parameters: \(paramString)")
        #endif
        
        // Filter parameters to ensure no PII/health data
        let filteredParams = filterParameters(parameters)
        
        // Firebase Analytics event logging
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: filteredParams)
        #endif
    }
    
    /// Track screen view events
    func trackScreenView(_ screenName: String, screenClass: String? = nil) {
        var parameters: [String: Any] = [
            "screen_name": screenName
        ]
        
        if let screenClass = screenClass {
            parameters["screen_class"] = screenClass
        }
        
        trackEvent("screen_view", parameters: parameters)
    }
    
    /// Set user properties (non-identifying)
    func setUserProperty(_ value: String?, forName name: String) {
        guard isEnabled && isInitialized else { return }
        guard !containsPII(value) else {
            #if DEBUG
            print("🔍 AnalyticsService: Blocked user property '\(name)' - contains PII")
            #endif
            return
        }
        
        #if DEBUG
        print("🔍 AnalyticsService: User property '\(name)': \(value ?? "nil")")
        #endif
        
        // Firebase Analytics user property
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
        #endif
    }
    
    // MARK: - Privacy Helpers
    
    /// Filter out any parameters that might contain PII or health data
    private func filterParameters(_ parameters: [String: Any]?) -> [String: Any]? {
        guard let parameters = parameters else { return nil }
        
        var filtered: [String: Any] = [:]
        
        for (key, value) in parameters {
            // Skip parameters that might contain sensitive data
            let lowerKey = key.lowercased()
            if lowerKey.contains("email") || 
               lowerKey.contains("name") || 
               lowerKey.contains("weight") || 
               lowerKey.contains("calorie") ||
               lowerKey.contains("user") ||
               lowerKey.contains("id") {
                continue
            }
            
            // Check if value contains PII
            if let stringValue = value as? String, containsPII(stringValue) {
                continue
            }
            
            filtered[key] = value
        }
        
        return filtered.isEmpty ? nil : filtered
    }
    
    /// Check if a string might contain personally identifiable information
    private func containsPII(_ value: String?) -> Bool {
        guard let value = value?.lowercased() else { return false }
        
        // Basic PII detection
        let piiPatterns = [
            "@", // Email addresses
            "\\d{10,}", // Long numbers (phone, ID)
            "user_", // User IDs
            "uuid", // UUIDs
        ]
        
        for pattern in piiPatterns {
            if value.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Convenience Event Methods

extension AnalyticsService {
    
    // MARK: - Authentication Events
    func trackSignInStarted() {
        trackEvent("auth_sign_in_started")
    }
    
    func trackSignInSucceeded() {
        trackEvent("auth_sign_in_succeeded")
    }
    
    func trackSignInFailed(error: String? = nil) {
        var params: [String: Any] = [:]
        if let error = error {
            params["error_category"] = error
        }
        trackEvent("auth_sign_in_failed", parameters: params)
    }
    
    func trackSignOut() {
        trackEvent("auth_sign_out")
    }
    
    // MARK: - Search Events
    func trackFoodSearchStarted(source: String, queryLength: Int? = nil) {
        var params: [String: Any] = ["source": source]
        if let queryLength = queryLength {
            params["query_length_category"] = queryLength < 3 ? "short" : queryLength < 10 ? "medium" : "long"
        }
        trackEvent("food_search_started", parameters: params)
    }
    
    func trackFoodSearchResultTapped(position: Int, source: String) {
        trackEvent("food_search_result_tapped", parameters: [
            "position": position,
            "source": source
        ])
    }
    
    // MARK: - Barcode Events
    func trackBarcodeScanStarted() {
        trackEvent("barcode_scan_started")
    }
    
    func trackBarcodeScanSucceeded(symbology: String? = nil) {
        var params: [String: Any] = [:]
        if let symbology = symbology {
            params["symbology"] = symbology
        }
        trackEvent("barcode_scan_succeeded", parameters: params)
    }
    
    func trackBarcodeScanFailed() {
        trackEvent("barcode_scan_failed")
    }
    
    func trackBarcodeManualEntryUsed() {
        trackEvent("barcode_manual_entry_used")
    }
    
    // MARK: - Food Logging Events
    func trackFoodEntryAdded(meal: String, source: String) {
        trackEvent("food_entry_added", parameters: [
            "meal": meal,
            "source": source
        ])
    }
    
    func trackFoodEntryDeleted() {
        trackEvent("food_entry_deleted")
    }
    
    // MARK: - Weight Events
    func trackWeightEntryAdded() {
        trackEvent("weight_entry_added")
    }
    
    func trackWeightHealthImportStarted() {
        trackEvent("weight_health_import_started")
    }
    
    func trackWeightHealthImportSucceeded(entriesCount: Int? = nil) {
        var params: [String: Any] = [:]
        if let count = entriesCount {
            params["entries_category"] = count < 10 ? "few" : count < 50 ? "moderate" : "many"
        }
        trackEvent("weight_health_import_succeeded", parameters: params)
    }
    
    func trackWeightHealthImportFailed(errorCategory: String) {
        trackEvent("weight_health_import_failed", parameters: [
            "error_category": errorCategory
        ])
    }
    
    func trackCSVImportStarted() {
        trackEvent("csv_import_started")
    }
    
    func trackCSVImportSucceeded(entriesCount: Int? = nil) {
        var params: [String: Any] = [:]
        if let count = entriesCount {
            params["entries_category"] = count < 10 ? "few" : count < 50 ? "moderate" : "many"
        }
        trackEvent("csv_import_succeeded", parameters: params)
    }
    
    func trackCSVImportFailed() {
        trackEvent("csv_import_failed")
    }
    
    func trackWeightChartTimeframeSelected(range: String) {
        trackEvent("weight_chart_timeframe_selected", parameters: [
            "range": range
        ])
    }
    
    // MARK: - Phase Events
    func trackPhaseCreated() {
        trackEvent("phase_created")
    }
    
    func trackPhaseUpdated() {
        trackEvent("phase_updated")
    }
    
    func trackPhaseDeleted() {
        trackEvent("phase_deleted")
    }
    
    // MARK: - Feature Interaction Events
    func trackFeatureTapped(featureName: String) {
        trackEvent("feature_tapped", parameters: [
            "feature_name": featureName
        ])
    }
}
