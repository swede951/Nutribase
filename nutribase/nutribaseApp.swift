//
//  nutribaseApp.swift
//  nutribase
//
//  Created by Alex Sweet on 03/06/2025.
//

import SwiftUI
import HealthKit
import CoreText

// Create an AppDelegate class to handle initialization tasks
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Register custom fonts
        registerCustomFonts()
        
        // Initialize HealthKit on app launch
        initializeHealthKit()
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
            
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterGraphicsFont(font, &error) {
                if let error = error?.takeRetainedValue() {
                    print("Failed to register font \(fontName): \(error)")
                } else {
                    print("Failed to register font \(fontName): Unknown error")
                }
            } else {
                print("Successfully registered font: \(fontName)")
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
}

@main
struct nutribaseApp: App {
    // Register the AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Create StateObjects for the managers
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var activityManager = ActivityManager.shared
    @StateObject private var supabaseService = SupabaseService.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if supabaseService.isAuthenticated || UserDefaults.standard.bool(forKey: "guest_mode") {
                    // Show main app content if authenticated or in guest mode
                    ContentView()
                        .environmentObject(healthKitManager)
                        .environmentObject(activityManager)
                        .environmentObject(supabaseService)
                } else {
                    // Show login screen if not authenticated
                    LoginView()
                        .environmentObject(supabaseService)
                }
            }
            .preferredColorScheme(.light) // Force light mode only
        }
    }
}
