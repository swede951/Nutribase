import SwiftUI
import FirebaseAuth

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var authService: FirebaseAuthService
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var passwordChanged = false
    
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
                    // Current Password Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Password")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        SecureField("Enter current password", text: $currentPassword)
                            .textContentType(.password)
                            .padding()
                            .background(cardBackground)
                            .cornerRadius(12)
                    }
                    
                    // New Password Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Password")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        SecureField("Enter new password", text: $newPassword)
                            .textContentType(.newPassword)
                            .padding()
                            .background(cardBackground)
                            .cornerRadius(12)
                    }
                    
                    // Confirm Password Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm New Password")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        SecureField("Confirm new password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding()
                            .background(cardBackground)
                            .cornerRadius(12)
                    }
                    
                    // Password Requirements
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 20))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Password Requirements")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    RequirementRow(text: "At least 6 characters", isMet: newPassword.count >= 6)
                                    RequirementRow(text: "Passwords match", isMet: !newPassword.isEmpty && newPassword == confirmPassword)
                                }
                                .font(.caption)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Update Button
                    Button(action: updatePassword) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            Text("Update Password")
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
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(viewBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") {
                if passwordChanged {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword.count >= 6 &&
        newPassword == confirmPassword
    }
    
    private func updatePassword() {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            showAlert(title: "Error", message: "No user logged in")
            return
        }
        
        isLoading = true
        
        // Step 1: Re-authenticate user
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        
        user.reauthenticate(with: credential) { result, error in
            if let error = error {
                isLoading = false
                handleAuthError(error)
                return
            }
            
            // Step 2: Update password
            user.updatePassword(to: newPassword) { error in
                isLoading = false
                
                if let error = error {
                    handleAuthError(error)
                    return
                }
                
                // Success
                passwordChanged = true
                showAlert(
                    title: "Success!",
                    message: "Your password has been updated successfully."
                )
            }
        }
    }
    
    private func handleAuthError(_ error: Error) {
        let nsError = error as NSError
        
        switch nsError.code {
        case AuthErrorCode.wrongPassword.rawValue:
            showAlert(title: "Incorrect Password", message: "The current password you entered is incorrect. Please try again.")
        case AuthErrorCode.weakPassword.rawValue:
            showAlert(title: "Weak Password", message: "Please choose a stronger password. Use at least 6 characters.")
        case AuthErrorCode.requiresRecentLogin.rawValue:
            showAlert(title: "Session Expired", message: "For security reasons, please log out and log back in before changing your password.")
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

// Helper view for password requirements
struct RequirementRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? .green : .secondary)
                .font(.system(size: 12))
            
            Text(text)
                .foregroundColor(isMet ? .primary : .secondary)
        }
    }
}

#Preview {
    NavigationStack {
        ChangePasswordView()
    }
}
