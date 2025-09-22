import SwiftUI

struct LoginView: View {
    @StateObject private var authService = SimpleAuthService.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var showingSignUp = false
    @State private var errorMessage: String?
    @State private var showingAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                // Logo and app name
                VStack(spacing: 5) {
                    Image("nutrition-balance-icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                    
                    Text("NUTRIBASE")
                        .font(.custom("Montserrat-ExtraBold", size: 32))
                        .foregroundColor(.primary)
                    
                    Text("Balancing your nutrition and goals")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 80)
                .padding(.bottom, 0)
                
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
                            Color.black.opacity(0.8) : Color.black
                    )
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    // Sign up button
                    Button(action: { showingSignUp = true }) {
                        Text("Don't have an account? Sign Up")
                            .foregroundColor(.black)
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
            .background(Color(hex: "b6e2ff"))
            .ignoresSafeArea(.all)
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
            }
        }
    }
    
    private func login() {
        isLoggingIn = true
        errorMessage = nil
        
        print("🔍 Starting login process...")
        
        // Track sign-in attempt
        analyticsService.trackSignInStarted()
        
        authService.signIn(email: email, password: password) { success, error in
            isLoggingIn = false
            
            if success {
                // Track successful sign-in
                analyticsService.trackSignInSucceeded()
            } else {
                // Track failed sign-in
                let errorCategory = error?.contains("password") == true ? "invalid_credentials" : "network_error"
                analyticsService.trackSignInFailed(error: errorCategory)
                
                errorMessage = error
                showingAlert = true
            }
        }
    }
    
    private func skipLogin() {
        // Track guest mode usage
        analyticsService.trackEvent("guest_mode_selected")
        
        // Set guest mode - this allows the app to function without authentication
        UserDefaults.standard.set(true, forKey: "guest_mode")
        // Don't set authService.isAuthenticated = true for guest mode
        // The app navigation logic checks for guest_mode separately
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(SupabaseService.shared)
    }
}
