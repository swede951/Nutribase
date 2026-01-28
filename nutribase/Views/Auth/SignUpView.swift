import SwiftUI

struct SignUpView: View {
    @StateObject private var authService = FirebaseAuthService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSigningUp = false
    @State private var errorMessage: String?
    @State private var showingAlert = false
    @State private var showingVerificationMessage = false
    @State private var verificationMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 5) {
                    Image("app-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                    
                    Text("Create Account")
                        .font(.custom("Montserrat-ExtraBold", size: 28))
                        .foregroundColor(.white)
                    
                    Text("Join NutriBase to track your nutrition")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(.top, 40)
                .padding(.bottom, 0)
                
                // Sign up form
                VStack(spacing: 16) {
                    // Email field
                    TextField("Email", text: $email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    // Password field
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    // Confirm password field
                    SecureField("Confirm Password", text: $confirmPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    // Password validation message
                    if !password.isEmpty && password.count < 6 {
                        Text("Password must be at least 6 characters")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    if !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    // Sign up button
                    Button(action: signUp) {
                        if isSigningUp {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Create Account")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isFormValid || isSigningUp)
                    .padding()
                    .background(
                        isFormValid && !isSigningUp ?
                            Color(UIColor.black) : Color(UIColor.black).opacity(0.8)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Back to login button
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Already have an account? Log In")
                        .foregroundColor(.white)
                }
                .padding(.bottom)
            }
            .padding()
            .background(
                Color(hex: "35b8ff")
                    .ignoresSafeArea(.all)
            )
            .navigationBarHidden(true)
            .overlay(
                // Close button in top-left corner
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            )
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(isPresented: $showingVerificationMessage) {
                Alert(
                    title: Text("Verify Your Email"),
                    message: Text(verificationMessage),
                    dismissButton: .default(Text("OK")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
        .keyboardDismissToolbar()
    }
    
    private var isFormValid: Bool {
        return !email.isEmpty && 
               !password.isEmpty && 
               password.count >= 6 && 
               password == confirmPassword
    }
    
    private func signUp() {
        isSigningUp = true
        errorMessage = nil
        
        authService.signUp(email: email, password: password) { success, error in
            DispatchQueue.main.async {
                self.isSigningUp = false
                
                if success {
                    // Sign up successful, show verification message
                    self.verificationMessage = "Account created successfully! Please check your email (\(self.email)) and click the verification link before signing in."
                    self.showingVerificationMessage = true
                } else {
                    // Show error message
                    self.errorMessage = error ?? "Sign up failed. Please try again."
                    self.showingAlert = true
                }
            }
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
    }
}
