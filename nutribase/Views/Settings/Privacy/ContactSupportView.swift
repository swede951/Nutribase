import SwiftUI

struct ContactSupportView: View {
    @State private var subject = ""
    @State private var message = ""
    @State private var showingAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("Contact Information")) {
                HStack {
                    Text("Email")
                    Spacer()
                    Text("nutribase951@gmail.com")
                        .foregroundColor(.blue)
                }
                
                Button("Send Email") {
                    openEmail()
                }
            }
            
            Section(header: Text("Quick Links")) {
                Link(destination: URL(string: "https://nutribase.app/faq")!) {
                    HStack {
                        Text("FAQ")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://nutribase.app/help")!) {
                    HStack {
                        Text("Help Center")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("App Information")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("100")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Feedback")) {
                Button("Report a Bug") {
                    openEmail(subject: "Bug Report")
                }
                
                Button("Request a Feature") {
                    openEmail(subject: "Feature Request")
                }
                
                Button("General Feedback") {
                    openEmail(subject: "Feedback")
                }
            }
        }
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemGray6), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    private func openEmail(subject: String = "") {
        let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:nutribase951@gmail.com?subject=\(subjectEncoded)") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationStack {
        ContactSupportView()
    }
}
