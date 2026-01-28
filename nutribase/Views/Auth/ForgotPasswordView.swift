import SwiftUI
import FirebaseAuth

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var emailSent = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Icon
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "#35b8ff"))
                            .padding(.top, 40)
                        
                        // Title and Description
                        VStack(spacing: 8) {
                            Text("Reset Password")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Enter your email address and we'll send you a link to reset your password.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.bottom, 16)
                        
                        // Email Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email Address")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("Enter your email", text: $email)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // Send Reset Link Button
                        Button(action: sendPasswordReset) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            } else {
                                Text("Send Reset Link")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                        }
                        .background(isEmailValid ? Color(hex: "#35b8ff") : Color.gray)
                        .cornerRadius(12)
                        .disabled(!isEmailValid || isLoading)
                        .padding(.horizontal)
                        
                        // Info Box
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 20))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Check Your Inbox")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text("The password reset link will be sent to your email. Make sure to check your spam folder if you don't see it.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
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
        .keyboardDismissToolbar()
    }
    
    private var isEmailValid: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }
    
    private func sendPasswordReset() {
        isLoading = true
        
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            isLoading = false
            
            if let error = error {
                handleError(error)
            } else {
                emailSent = true
                showAlert(
                    title: "Email Sent!",
                    message: "We've sent a password reset link to \(email). Please check your inbox and follow the instructions to reset your password."
                )
            }
        }
    }
    
    private func handleError(_ error: Error) {
        let nsError = error as NSError
        
        switch nsError.code {
        case AuthErrorCode.invalidEmail.rawValue:
            showAlert(title: "Invalid Email", message: "Please enter a valid email address.")
        case AuthErrorCode.userNotFound.rawValue:
            // For security, we don't want to reveal if an email exists or not
            // So we show a success message even if the user doesn't exist
            emailSent = true
            showAlert(
                title: "Email Sent!",
                message: "If an account exists with \(email), you will receive a password reset link shortly."
            )
        case AuthErrorCode.networkError.rawValue:
            showAlert(title: "Network Error", message: "Please check your internet connection and try again.")
        default:
            showAlert(title: "Error", message: "Unable to send reset email. Please check your email address and try again.")
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

#Preview {
    ForgotPasswordView()
}
