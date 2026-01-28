import SwiftUI
import FirebaseAuth

struct ChangeEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var authService: FirebaseAuthService
    
    @State private var newEmail = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var emailSent = false
    
    private var viewBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    var body: some View {
        ZStack {
            viewBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Current Email
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Email")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(Auth.auth().currentUser?.email ?? "No email")
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(cardBackground)
                            .cornerRadius(12)
                    }
                    
                    // New Email Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Email")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter new email", text: $newEmail)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .padding()
                            .background(cardBackground)
                            .cornerRadius(12)
                    }
                    
                    // Password for Re-authentication
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Password")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        SecureField("Enter your password", text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(cardBackground)
                            .cornerRadius(12)
                    }
                    
                    // Info Box
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email Verification Required")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("We'll send a verification email to your new address. You'll need to verify it before the change takes effect.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Update Button
                    Button(action: updateEmail) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            Text("Update Email")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                    .background(isFormValid ? Color.blue : Color.gray)
                    .cornerRadius(12)
                    .disabled(!isFormValid || isLoading)
                    
                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("Change Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(viewBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") {
                if emailSent {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isFormValid: Bool {
        !newEmail.isEmpty && 
        newEmail.contains("@") && 
        newEmail.contains(".") &&
        !password.isEmpty &&
        newEmail != Auth.auth().currentUser?.email
    }
    
    private func updateEmail() {
        guard let user = Auth.auth().currentUser,
              let currentEmail = user.email else {
            showAlert(title: "Error", message: "No user logged in")
            return
        }
        
        isLoading = true
        
        // Step 1: Re-authenticate user
        let credential = EmailAuthProvider.credential(withEmail: currentEmail, password: password)
        
        user.reauthenticate(with: credential) { result, error in
            if let error = error {
                isLoading = false
                handleAuthError(error)
                return
            }
            
            // Step 2: Update email using new API
            user.sendEmailVerification(beforeUpdatingEmail: newEmail) { error in
                isLoading = false
                
                if error != nil {
                    showAlert(
                        title: "Error",
                        message: "Failed to update email. Please try again or contact support."
                    )
                } else {
                    emailSent = true
                    showAlert(
                        title: "Success!",
                        message: "Your email has been updated to \(newEmail). Please check your inbox and verify your new email address."
                    )
                }
            }
        }
    }
    
    private func handleAuthError(_ error: Error) {
        let nsError = error as NSError
        
        switch nsError.code {
        case AuthErrorCode.wrongPassword.rawValue:
            showAlert(title: "Incorrect Password", message: "The password you entered is incorrect. Please try again.")
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            showAlert(title: "Email In Use", message: "This email address is already associated with another account.")
        case AuthErrorCode.invalidEmail.rawValue:
            showAlert(title: "Invalid Email", message: "Please enter a valid email address.")
        case AuthErrorCode.requiresRecentLogin.rawValue:
            showAlert(title: "Session Expired", message: "For security reasons, please log out and log back in before changing your email.")
        case AuthErrorCode.networkError.rawValue:
            showAlert(title: "Network Error", message: "Please check your internet connection and try again.")
        default:
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

#Preview {
    NavigationStack {
        ChangeEmailView()
    }
}
