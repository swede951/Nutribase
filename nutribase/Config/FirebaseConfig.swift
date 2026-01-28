import Foundation

/// Firebase configuration for HTTP/1.1 client
struct FirebaseConfig {
    // TODO: Replace with your actual Firebase project credentials
    static let apiKey = "AIzaSyCm6rRCLrWUnpCeIRn4AvEIaoPmRdweFPM"
    static let projectId = "swedeapps-nutribase"
    
    // Firebase Analytics batch log endpoint (using Measurement Protocol)
    static let batchLogUrl = "https://www.google-analytics.com/mp/collect"
    
    // App information
    static let bundleId = Bundle.main.bundleIdentifier ?? "com.nutribase.app"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
}
