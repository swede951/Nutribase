//
//  nutribaseApp.swift
//  nutribase
//
//  Created by Alex Sweet on 03/06/2025.
//

import SwiftUI
import HealthKit
import CoreText
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif
#if canImport(FirebasePerformance)
import FirebasePerformance
#endif

// Create an AppDelegate class to handle initialization tasks
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Initialize Firebase
        configureFirebase()
        
        
        // Register custom fonts
        registerCustomFonts()
        
        // Initialize HealthKit on app launch
        initializeHealthKit()
        
        // Initialize Analytics Service
        initializeAnalytics()
        
        // Configure navigation bar appearance
        configureNavigationBarAppearance()
        
        return true
    }
    
    
    private func registerCustomFonts() {
        let fontNames = ["Montserrat-Bold.ttf", "Montserrat-ExtraBold.ttf", "Montserrat-SemiBold.ttf"]
        
        for fontName in fontNames {
            guard let fontURL = Bundle.main.url(forResource: fontName.replacingOccurrences(of: ".ttf", with: ""), withExtension: "ttf") else {
                print("Could not find font file: \(fontName)")
                continue
            }
            
            guard let fontData = NSData(contentsOf: fontURL) else {
                print("Could not load font data for: \(fontName)")
                continue
            }
            
            guard let dataProvider = CGDataProvider(data: fontData) else {
                print("Could not create data provider for: \(fontName)")
                continue
            }
            
            guard let font = CGFont(dataProvider) else {
                print("Could not create font from data provider for: \(fontName)")
                continue
            }
            
            // Use modern API on iOS 18+, fallback to deprecated API for older versions
            if #available(iOS 18.0, *) {
                // Use CTFontManagerRegisterFontsForURL for iOS 18+
                var error: Unmanaged<CFError>?
                if !CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
                    if let error = error?.takeRetainedValue() {
                        print("Failed to register font \(fontName): \(error)")
                    }
                } else {
                    print("Successfully registered font: \(fontName)")
                }
            } else {
                // Use deprecated API for iOS < 18
                var error: Unmanaged<CFError>?
                if !CTFontManagerRegisterGraphicsFont(font, &error) {
                    if let error = error?.takeRetainedValue() {
                        print("Failed to register font \(fontName): \(error)")
                    }
                } else {
                    print("Successfully registered font: \(fontName)")
                }
            }
        }
    }
    
    private func initializeHealthKit() {
        let healthKitManager = HealthKitManager.shared
        let activityManager = ActivityManager.shared
        
        // Request HealthKit permissions if not already authorized
        if HKHealthStore.isHealthDataAvailable() && !healthKitManager.isAuthorized {
            healthKitManager.requestAuthorization { success, error in
                if success {
                    activityManager.refreshActivityData()
                } else if let error = error {
                    print("HealthKit authorization failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func configureFirebase() {
        // Initialize Firebase Core and Analytics
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        
        // Firebase Analytics is now enabled and will respect user consent
        #if canImport(FirebaseAnalytics)
        // Explicitly enable analytics collection
        Analytics.setAnalyticsCollectionEnabled(true)
        #if DEBUG
        print("🔥 Firebase: Analytics collection explicitly enabled")
        #endif
        #endif
        
        // Disable Firebase Crashlytics (optional - can enable if needed)
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        #endif
        
        // Disable Firebase Performance (optional - can enable if needed)
        #if canImport(FirebasePerformance)
        Performance.sharedInstance().isDataCollectionEnabled = false
        #endif
        
        #if DEBUG
        print("🔥 Firebase: Core and Analytics configured")
        #endif
        #else
        #if DEBUG
        print("🔥 Firebase: SDK not available")
        #endif
        #endif
    }
    
    
    private func initializeAnalytics() {
        // Initialize the analytics service
        let analyticsService = AnalyticsService.shared
        analyticsService.initialize()
        
        #if DEBUG
        print("📊 Analytics: Service initialized")
        #endif
    }
    
    private func configureNavigationBarAppearance() {
        // Configure navigation bar to always have white background
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor.systemBackground
        navAppearance.shadowColor = UIColor.clear
        
        // Apply to all navigation bar states
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        
        if #available(iOS 15.0, *) {
            UINavigationBar.appearance().compactScrollEdgeAppearance = navAppearance
        }
        
        // Configure tab bar to always have white background
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor.systemBackground
        tabAppearance.shadowColor = UIColor.black.withAlphaComponent(0.2)
        
        // Note: Tab bar icon positioning adjustments removed due to threading issues
        
        // Apply to all tab bar states
        UITabBar.appearance().standardAppearance = tabAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        }
    }
}

@main
struct nutribaseApp: App {
    // Register the AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Create StateObjects for the managers
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var activityManager = ActivityManager.shared
    @StateObject private var firebaseAuthService = FirebaseAuthService.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    // Session tracking
    @State private var sessionStartTime = Date()
    @State private var isInitializing = true
    
    // Onboarding state - uses AppStorage to automatically react to changes
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isInitializing {
                    // Show custom loading screen with app icon and spinner
                    LoadingScreenView()
                        .onAppear {
                            // Quick check to determine which view to show
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isInitializing = false
                            }
                        }
                } else {
                    let isAuthenticated = firebaseAuthService.isAuthenticated
                    let needsEmailVerification = firebaseAuthService.needsEmailVerification
                    
                    if isAuthenticated {
                        // Check if user needs onboarding first (before email verification)
                        let isNewUser = UserDefaults.standard.bool(forKey: "isNewUser")
                        
                        if isNewUser || !hasCompletedOnboarding {
                            // Show onboarding (even if email not verified)
                            PremiumOnboardingView()
                                .environmentObject(healthKitManager)
                                .environmentObject(activityManager)
                                .environmentObject(firebaseAuthService)
                                .environmentObject(analyticsService)
                                .onAppear {
                                    print("[NutribaseApp] Showing premium onboarding for new user")
                                    // Don't clear isNewUser here - wait until onboarding is completed
                                    // This prevents the view from switching during async operations
                                }
                        } else if needsEmailVerification {
                            // Show email verification AFTER onboarding is complete
                            EmailVerificationView()
                                .environmentObject(firebaseAuthService)
                                .environmentObject(analyticsService)
                                .onAppear {
                                    print("[NutribaseApp] Showing email verification screen (post-onboarding)")
                                }
                        } else {
                            // Show main app content if authenticated, onboarded, and verified
                            ContentView()
                                .environmentObject(healthKitManager)
                                .environmentObject(activityManager)
                                .environmentObject(firebaseAuthService)
                                .environmentObject(analyticsService)
                                .onAppear {
                                    print("[NutribaseApp] Showing main app - isAuthenticated: \(isAuthenticated)")
                                    // Track session start
                                    sessionStartTime = Date()
                                    analyticsService.trackSessionStart()
                                    analyticsService.trackAppOpen()
                                }
                        }
                    } else {
                        // Show login screen if not authenticated
                        LoginView()
                            .environmentObject(firebaseAuthService)
                            .environmentObject(analyticsService)
                            .onAppear {
                                print("[NutribaseApp] Showing login screen - isAuthenticated: \(isAuthenticated)")
                            }
                    }
                }
            }
            .preferredColorScheme(themeManager.selectedTheme.colorScheme)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                // Track when app goes to background
                let sessionDuration = Date().timeIntervalSince(sessionStartTime)
                analyticsService.trackAppBackground()
                analyticsService.trackSessionEnd(duration: sessionDuration)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Track when app becomes active
                sessionStartTime = Date()
                analyticsService.trackAppOpen()
                analyticsService.trackSessionStart()
            }
        }
    }
}
