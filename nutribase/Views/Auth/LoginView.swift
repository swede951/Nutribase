import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var authService = FirebaseAuthService.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    @State private var email = ""
    @State private var password = ""
    
    // Adaptive colors for dark/light mode
    private var backgroundColor: Color {
        Color.appBackground
    }
    
    private var inputFieldBackground: Color {
        Color.appCardBackground
    }
    @State private var isLoggingIn = false
    @State private var showingSignUp = false
    @State private var showingForgotPassword = false
    @State private var errorMessage: String?
    @State private var showingAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Adaptive background that extends to all edges
                backgroundColor
                    .ignoresSafeArea()
                
                // Blue gradient fade at top (like dashboard)
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#35b8ff"),
                        backgroundColor
                    ]),
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.55)
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // Logo and app name
                    VStack(spacing: 5) {
                        Image("app-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                        
                        Text("NUTRIBASE")
                            .font(.custom("Montserrat-ExtraBold", size: 32))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 0)
                    
                    // Login form
                    VStack(spacing: 16) {
                        // Email field
                        TextField("Email", text: $email)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .padding()
                            .background(inputFieldBackground)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                        
                        // Password field
                        SecureField("Password", text: $password)
                            .padding()
                            .background(inputFieldBackground)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                        
                        // Forgot Password link
                        HStack {
                            Spacer()
                            Button(action: { showingForgotPassword = true }) {
                                Text("Forgot Password?")
                                    .font(.subheadline)
                                    .foregroundColor(Color(hex: "#35b8ff"))
                            }
                        }
                        .padding(.top, -8)
                        
                        // Login button
                        Button(action: login) {
                            if isLoggingIn {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
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
                                Color(hex: "#35b8ff").opacity(0.6) : Color(hex: "#35b8ff")
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                        
                        // Inline error message
                        if let error = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(12)
                        }
                        
                        // Divider with "or"
                        HStack {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                            Text("or")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 8)
                        
                        // Sign in with Apple button
                        SignInWithAppleButton(
                            onRequest: { request in
                                let appleRequest = authService.prepareAppleSignInRequest()
                                request.requestedScopes = appleRequest.requestedScopes
                                request.nonce = appleRequest.nonce
                            },
                            onCompletion: handleAppleSignIn
                        )
                        .frame(height: 50)
                        .cornerRadius(12)
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        
                        // Sign up button
                        Button(action: { showingSignUp = true }) {
                            Text("Don't have an account? Sign Up")
                                .foregroundColor(Color(hex: "#35b8ff"))
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarHidden(true)
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
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
            }
        }
        .navigationViewStyle(.stack)
        .keyboardDismissToolbar()
    }
    
    private func login() {
        isLoggingIn = true
        errorMessage = nil
        
        print("🔍 Starting login process...")
        
        // Track sign-in attempt
        analyticsService.trackSignInStarted()
        
        authService.signIn(email: email, password: password)
        
        // Monitor auth state changes for completion - poll until we get a result
        checkLoginResult(attempts: 0)
    }
    
    private func checkLoginResult(attempts: Int) {
        // Give up after 30 attempts (3 seconds)
        guard attempts < 30 else {
            isLoggingIn = false
            errorMessage = "Login timed out. Please check your connection and try again."
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Check if we have a result
            if authService.isAuthenticated {
                // Success!
                isLoggingIn = false
                analyticsService.trackSignInSucceeded()
            } else if let error = authService.errorMessage {
                // Got an error
                isLoggingIn = false
                
                // Track failed sign-in
                let errorCategory = error.contains("password") ? "invalid_credentials" : "network_error"
                analyticsService.trackSignInFailed(error: errorCategory)
                
                // Show user-friendly error message
                if error.lowercased().contains("password") || error.lowercased().contains("invalid") || error.lowercased().contains("wrong") || error.lowercased().contains("credential") || error.lowercased().contains("malform") {
                    errorMessage = "The password or username is incorrect"
                } else if error.lowercased().contains("user") && error.lowercased().contains("not found") {
                    errorMessage = "No account found with this email. Please sign up first."
                } else if error.lowercased().contains("network") || error.lowercased().contains("connection") {
                    errorMessage = "Network error. Please check your connection and try again."
                } else if error.lowercased().contains("too many") {
                    errorMessage = "Too many failed attempts. Please try again later."
                } else {
                    errorMessage = error
                }
            } else if !authService.isLoading {
                // Not loading anymore but no result - keep waiting a bit more
                checkLoginResult(attempts: attempts + 1)
            } else {
                // Still loading, keep waiting
                checkLoginResult(attempts: attempts + 1)
            }
        }
    }
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // Track Apple sign-in attempt
                analyticsService.trackEvent("apple_signin_started")
                
                print("[LoginView] Processing Apple Sign-In credential...")
                
                authService.handleAppleSignIn(credential: appleIDCredential) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            print("[LoginView] Apple Sign-In successful")
                            analyticsService.trackEvent("apple_signin_succeeded")
                        } else {
                            print("[LoginView] Apple Sign-In failed: \(error ?? "unknown error")")
                            analyticsService.trackEvent("apple_signin_failed")
                            errorMessage = error ?? "Apple Sign-In failed"
                            showingAlert = true
                        }
                    }
                }
            }
        case .failure(let error):
            print("[LoginView] Apple Sign-In authorization failed: \(error.localizedDescription)")
            analyticsService.trackEvent("apple_signin_failed")
            errorMessage = "Apple Sign-In was cancelled or failed. Please try again."
            showingAlert = true
        }
    }
    
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
