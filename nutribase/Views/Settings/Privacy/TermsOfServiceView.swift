import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms of Service")
                    .font(.title)
                    .bold()
                
                Text("Last Updated: January 2025")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Group {
                    SectionHeader(title: "1. Acceptance")
                    Text("By using Nutribase, you agree to these terms.")
                    
                    SectionHeader(title: "2. Medical Disclaimer")
                    Text("This app is NOT medical advice. Consult healthcare professionals before making health decisions.")
                        .foregroundColor(.red)
                    
                    SectionHeader(title: "3. Data Accuracy")
                    Text("Nutritional data comes from USDA and Open Food Facts. Verify accuracy before use.")
                    
                    SectionHeader(title: "4. User Responsibilities")
                    Text("• Provide accurate information\n• Use legally and responsibly\n• Keep account secure")
                    
                    SectionHeader(title: "5. Privacy")
                    Text("See our Privacy Policy for data handling practices.")
                    
                    SectionHeader(title: "6. Changes")
                    Text("We may update these terms. Continued use means acceptance.")
                }
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemGray6), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .bold()
            .padding(.top, 8)
    }
}

#Preview {
    NavigationStack {
        TermsOfServiceView()
    }
}
