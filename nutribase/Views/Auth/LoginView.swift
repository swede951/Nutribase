import SwiftUI

struct LoginView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var showingSignUp = false
    @State private var errorMessage: String?
    @State private var showingAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo and app name
                VStack(spacing: 10) {
                    Image(systemName: "leaf.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.green)
                    
                    Text("NutriBase")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Track your nutrition journey")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)
                
                // Login form
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
                    
                    // Login button
                    Button(action: login) {
                        if isLoggingIn {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Log In")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoggingIn)
                    .padding()
                    .background(
                        (email.isEmpty || password.isEmpty || isLoggingIn) ?
                            Color.green.opacity(0.5) : Color.green
                    )
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    // Sign up button
                    Button(action: { showingSignUp = true }) {
                        Text("Don't have an account? Sign Up")
                            .foregroundColor(.green)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Guest mode button
                Button(action: skipLogin) {
                    Text("Continue as Guest")
                        .foregroundColor(.secondary)
                }
                .padding(.bottom)
            }
            .padding()
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
                    .environmentObject(supabaseService)
            }
        }
    }
    
    private func login() {
        isLoggingIn = true
        errorMessage = nil
        
        supabaseService.signIn(email: email, password: password) { success, error in
            isLoggingIn = false
            
            if !success {
                errorMessage = error
                showingAlert = true
            }
        }
    }
    
    private func skipLogin() {
        // Set guest mode - this allows the app to function without authentication
        UserDefaults.standard.set(true, forKey: "guest_mode")
        supabaseService.isAuthenticated = true
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(SupabaseService.shared)
    }
}
