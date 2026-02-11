import SwiftUI

struct DataConsentsView: View {
    @State private var healthKitEnabled = false
    @State private var analyticsEnabled = UserDefaults.standard.bool(forKey: "analyticsEnabled")
    @State private var crashReportingEnabled = UserDefaults.standard.bool(forKey: "crashReportingEnabled")
    
    private var viewBackground: Color {
        Color.appBackground
    }
    
    var body: some View {
        ZStack {
            viewBackground
                .ignoresSafeArea()
            
        Form {
            Section(header: Text("Health Data")) {
                Toggle("HealthKit Integration", isOn: $healthKitEnabled)
                Text("Allow Nutribase to read and write health data including weight, activity, and nutrition information.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color.appCardBackground)
            
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
            .listRowBackground(Color.appCardBackground)
            
            Section(footer: Text("You can change these permissions at any time. Disabling may limit some app features.")) {
                EmptyView()
            }
        }
        .scrollContentBackground(.hidden)
        }
        .navigationTitle("Data Consents")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        DataConsentsView()
    }
}
