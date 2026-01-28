import SwiftUI

struct DataConsentsView: View {
    @State private var healthKitEnabled = false
    @State private var analyticsEnabled = UserDefaults.standard.bool(forKey: "analyticsEnabled")
    @State private var crashReportingEnabled = UserDefaults.standard.bool(forKey: "crashReportingEnabled")
    
    var body: some View {
        Form {
            Section(header: Text("Health Data")) {
                Toggle("HealthKit Integration", isOn: $healthKitEnabled)
                Text("Allow Nutribase to read and write health data including weight, activity, and nutrition information.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("App Improvement")) {
                Toggle("Analytics", isOn: $analyticsEnabled)
                    .onChange(of: analyticsEnabled) {
                        UserDefaults.standard.set(analyticsEnabled, forKey: "analyticsEnabled")
                    }
                Text("Help improve the app by sharing anonymous usage data.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Toggle("Crash Reporting", isOn: $crashReportingEnabled)
                    .onChange(of: crashReportingEnabled) {
                        UserDefaults.standard.set(crashReportingEnabled, forKey: "crashReportingEnabled")
                    }
                Text("Automatically send crash reports to help fix bugs.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(footer: Text("You can change these permissions at any time. Disabling may limit some app features.")) {
                EmptyView()
            }
        }
        .navigationTitle("Data Consents")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemGray6), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        DataConsentsView()
    }
}
