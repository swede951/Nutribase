import SwiftUI

struct SharingSettingsView: View {
    @State private var emailNotifications = UserDefaults.standard.bool(forKey: "emailNotifications")
    @State private var productUpdates = UserDefaults.standard.bool(forKey: "productUpdates")
    @State private var tipsAndTricks = UserDefaults.standard.bool(forKey: "tipsAndTricks")
    
    private var viewBackground: Color {
        Color.appBackground
    }
    
    var body: some View {
        ZStack {
            viewBackground
                .ignoresSafeArea()
            
        Form {
            Section(header: Text("Email Preferences")) {
                Toggle("Email Notifications", isOn: $emailNotifications)
                    .onChange(of: emailNotifications) {
                        UserDefaults.standard.set(emailNotifications, forKey: "emailNotifications")
                    }
                
                Toggle("Product Updates", isOn: $productUpdates)
                    .onChange(of: productUpdates) {
                        UserDefaults.standard.set(productUpdates, forKey: "productUpdates")
                    }
                
                Toggle("Tips & Tricks", isOn: $tipsAndTricks)
                    .onChange(of: tipsAndTricks) {
                        UserDefaults.standard.set(tipsAndTricks, forKey: "tipsAndTricks")
                    }
            }
            .listRowBackground(Color.appCardBackground)
            
            Section(header: Text("Data Export")) {
                Button("Export My Data") {
                    // TODO: Implement data export
                }
                
                Text("Download all your food logs, weight data, and settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color.appCardBackground)
            
            Section(header: Text("Account")) {
                Button("Delete My Account", role: .destructive) {
                    // TODO: Implement account deletion
                }
                
                Text("Permanently delete your account and all associated data.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color.appCardBackground)
        }
        .scrollContentBackground(.hidden)
        }
        .navigationTitle("Sharing & Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        SharingSettingsView()
    }
}
