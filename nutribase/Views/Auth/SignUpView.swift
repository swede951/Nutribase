import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSigningUp = false
    @State private var errorMessage: String?
    @State private var showingAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 15) {
                    Image("nutrition-balance-icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                    
                    Text("Create Account")
                        .font(.custom("Montserrat-ExtraBold", size: 28))
                        .foregroundColor(.primary)
                    
                    Text("Join NutriBase to track your nutrition")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
                
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
                            Color.green : Color.green.opacity(0.5)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Back to login button
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Already have an account? Log In")
                        .foregroundColor(.green)
                }
                .padding(.bottom)
            }
            .padding()
            .background(Color(hex: "b6e2ff"))
            .ignoresSafeArea(.all)
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.primary)
            })
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
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
        
        // Sign up functionality disabled - redirect to sign in
        isSigningUp = false
        errorMessage = "Sign up is currently disabled. Please use sign in."
        showingAlert = true
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .environmentObject(SupabaseService.shared)
    }
}
