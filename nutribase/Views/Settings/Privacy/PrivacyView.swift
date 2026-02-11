import SwiftUI

struct PrivacyView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    private var viewBackground: Color {
        Color.appBackground
    }
    
    var body: some View {
        ZStack {
            // Background
            viewBackground
                .ignoresSafeArea()
            
            Form {
                Section {
                    NavigationLink(destination: TermsOfServiceView()) {
                        HStack(spacing: 15) {
                            Image(systemName: "doc.text")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.blue)
                            
                            Text("Terms of Service")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.appCardBackground)
                    
                    NavigationLink(destination: PrivacyPolicyView()) {
                        HStack(spacing: 15) {
                            Image(systemName: "hand.raised")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.blue)
                            
                            Text("Privacy Policy")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.appCardBackground)
                    
                    NavigationLink(destination: DataConsentsView()) {
                        HStack(spacing: 15) {
                            Image(systemName: "checkmark.shield")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.green)
                            
                            Text("Data Consents")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.appCardBackground)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Privacy")
        .toolbarBackground(viewBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        PrivacyView()
    }
}
