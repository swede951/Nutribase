import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title)
                    .bold()
                
                Text("Last Updated: January 2025")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Group {
                    SectionHeader(title: "1. Data We Collect")
                    Text("• Food and nutrition logs\n• Weight and body measurements\n• Health goals and preferences\n• HealthKit data (with permission)\n• Account information (email)")
                    
                    SectionHeader(title: "2. How We Use Data")
                    Text("• Provide app functionality\n• Calculate nutrition goals\n• Sync across devices\n• Improve app features")
                    
                    SectionHeader(title: "3. Data Storage")
                    Text("• Stored locally on your device\n• Synced via Firebase (if signed in)\n• Encrypted in transit\n• You control your data")
                    
                    SectionHeader(title: "4. Data Sharing")
                    Text("We do NOT sell or share your personal data with third parties for advertising.")
                    
                    SectionHeader(title: "5. HealthKit")
                    Text("• Optional integration\n• You control permissions\n• Data stays private\n• Not shared with third parties")
                    
                    SectionHeader(title: "6. Your Rights")
                    Text("• Access your data\n• Delete your data\n• Export your data\n• Opt out of analytics")
                    
                    SectionHeader(title: "7. Children's Privacy")
                    Text("App not intended for users under 13.")
                    
                    SectionHeader(title: "8. Contact")
                    Text("Questions? Email: support@nutribase.app")
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemGray6), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
