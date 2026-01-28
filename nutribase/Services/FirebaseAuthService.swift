import SwiftUI
import Combine
import AuthenticationServices
import CryptoKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

// Firebase Authentication Service
class FirebaseAuthService: ObservableObject {
    static let shared = FirebaseAuthService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: FirebaseUser?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isEmailVerified = false
    @Published var needsEmailVerification = false
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    // For Apple Sign-In nonce generation
    private var currentNonce: String?
    
    private init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            #if canImport(FirebaseAuth)
            Auth.auth().removeStateDidChangeListener(listener)
            #endif
        }
    }
    
    // MARK: - Auth State Management
    
    private func setupAuthStateListener() {
        #if canImport(FirebaseAuth)
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.updateAuthState(user: user)
            }
        }
        #endif
    }
    
    private func updateAuthState(user: User?) {
        if let user = user {
            self.currentUser = FirebaseUser(
                id: user.uid,
                email: user.email ?? "",
                accessToken: nil // Firebase handles tokens internally
            )
            self.isEmailVerified = user.isEmailVerified
            
            // Mark as authenticated regardless of email verification status
            // Email verification will be enforced after onboarding is complete
            self.isAuthenticated = true
            self.needsEmailVerification = !user.isEmailVerified
            
            // Post notification for other services
            NotificationCenter.default.post(name: .userDidSignIn, object: nil)
            
            if user.isEmailVerified {
                print("[FirebaseAuth] User signed in (verified): \(user.email ?? "unknown")")
            } else {
                print("[FirebaseAuth] User signed in (needs verification): \(user.email ?? "unknown")")
            }
        } else {
            self.currentUser = nil
            self.isAuthenticated = false
            self.isEmailVerified = false
            self.needsEmailVerification = false
            
            // Post notification for other services
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
            print("[FirebaseAuth] User signed out")
        }
    }
    
    // MARK: - Authentication Methods
    
    func signIn(email: String, password: String) {
        guard !email.isEmpty, !password.isEmpty else {
            self.errorMessage = "Email and password are required"
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        #if canImport(FirebaseAuth)
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[FirebaseAuth] Sign in error: \(error.localizedDescription)")
                } else if let user = result?.user {
                    print("[FirebaseAuth] Sign in successful: \(user.email ?? "unknown")")
                    // Auth state listener will handle the rest
                }
            }
        }
        #else
        // Fallback for when Firebase is not available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isLoading = false
            self.errorMessage = "Firebase Auth not available"
        }
        #endif
    }
    
    func signUp(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        guard !email.isEmpty, !password.isEmpty else {
            let error = "Email and password are required"
            self.errorMessage = error
            completion(false, error)
            return
        }
        
        guard password.count >= 6 else {
            let error = "Password must be at least 6 characters"
            self.errorMessage = error
            completion(false, error)
            return
        }
        
        // Check rate limiting
        if !checkSignUpRateLimit() {
            let error = "Too many sign-up attempts. Please try again in 5 minutes."
            self.errorMessage = error
            completion(false, error)
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        #if canImport(FirebaseAuth)
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    let errorMessage = error.localizedDescription
                    self?.errorMessage = errorMessage
                    print("[FirebaseAuth] Sign up error: \(errorMessage)")
                    completion(false, errorMessage)
                } else if let user = result?.user {
                    print("[FirebaseAuth] Sign up successful: \(user.email ?? "unknown")")
                    
                    // Send email verification
                    user.sendEmailVerification { verificationError in
                        if let verificationError = verificationError {
                            print("[FirebaseAuth] Email verification send error: \(verificationError.localizedDescription)")
                        } else {
                            print("[FirebaseAuth] Verification email sent to: \(user.email ?? "unknown")")
                        }
                    }
                    
                    // Mark that this is a new user who needs onboarding
                    UserDefaults.standard.set(true, forKey: "isNewUser")
                    // Reset onboarding state for new account (prevents stale state from previous accounts)
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    
                    // Record sign-up attempt for rate limiting
                    self?.recordSignUpAttempt()
                    
                    // Auth state listener will handle the rest
                    completion(true, nil)
                }
            }
        }
        #else
        // Fallback for when Firebase is not available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let error = "Firebase Auth not available"
            self.isLoading = false
            self.errorMessage = error
            completion(false, error)
        }
        #endif
    }
    
    func signOut() {
        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
            print("[FirebaseAuth] Sign out successful")
            // Auth state listener will handle the rest
        } catch {
            self.errorMessage = error.localizedDescription
            print("[FirebaseAuth] Sign out error: \(error.localizedDescription)")
        }
        #else
        // Fallback for when Firebase is not available
        self.currentUser = nil
        self.isAuthenticated = false
        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
        #endif
    }
    
    func forceSignOut() {
        // Clear all authentication state immediately
        self.currentUser = nil
        self.isAuthenticated = false
        self.errorMessage = nil
        
        // Clear Firebase auth
        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
            print("[FirebaseAuth] Force sign out successful")
        } catch {
            print("[FirebaseAuth] Force sign out error: \(error.localizedDescription)")
        }
        #endif
        
        // Clear all auth-related UserDefaults
        UserDefaults.standard.removeObject(forKey: "guest_mode")
        UserDefaults.standard.removeObject(forKey: "current_user_id")
        UserDefaults.standard.removeObject(forKey: "firebase_user_id")
        UserDefaults.standard.removeObject(forKey: "user_authenticated")
        UserDefaults.standard.synchronize()
        
        // Post notification
        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
        
        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("[FirebaseAuth] Force sign out completed")
    }
    
    func resetPassword(email: String) {
        guard !email.isEmpty else {
            self.errorMessage = "Email is required"
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        #if canImport(FirebaseAuth)
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[FirebaseAuth] Password reset error: \(error.localizedDescription)")
                } else {
                    print("[FirebaseAuth] Password reset email sent to: \(email)")
                    // Could show success message to user
                }
            }
        }
        #else
        // Fallback for when Firebase is not available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isLoading = false
            self.errorMessage = "Firebase Auth not available"
        }
        #endif
    }
    
    // MARK: - Token Management
    
    func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        #if canImport(FirebaseAuth)
        guard let currentUser = Auth.auth().currentUser else {
            completion(false)
            return
        }
        
        currentUser.getIDTokenForcingRefresh(true) { token, error in
            if let error = error {
                print("[FirebaseAuth] Token refresh error: \(error.localizedDescription)")
                completion(false)
            } else {
                print("[FirebaseAuth] Token refreshed successfully")
                completion(true)
            }
        }
        #else
        completion(false)
        #endif
    }
    
    func getCurrentUserToken(completion: @escaping (String?) -> Void) {
        #if canImport(FirebaseAuth)
        guard let currentUser = Auth.auth().currentUser else {
            completion(nil)
            return
        }
        
        currentUser.getIDToken { token, error in
            if let error = error {
                print("[FirebaseAuth] Get token error: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(token)
            }
        }
        #else
        completion(nil)
        #endif
    }
    
    // MARK: - Apple Sign-In
    
    func prepareAppleSignInRequest() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        #if canImport(FirebaseAuth)
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        return request
        #else
        // Fallback for when Firebase is not available
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        return request
        #endif
    }
    
    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential, completion: @escaping (Bool, String?) -> Void) {
        guard let nonce = currentNonce else {
            completion(false, "Invalid state: A login callback was received, but no login request was sent.")
            return
        }
        
        guard let appleIDToken = credential.identityToken else {
            completion(false, "Unable to fetch identity token")
            return
        }
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            completion(false, "Unable to serialize token string from data")
            return
        }
        
        // Store fullName for later use
        let fullName = credential.fullName
        
        self.isLoading = true
        self.errorMessage = nil
        
        #if canImport(FirebaseAuth)
        // Create OAuth credential for Apple Sign-In
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: fullName
        )
        
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    let errorMessage = error.localizedDescription
                    self?.errorMessage = errorMessage
                    print("[FirebaseAuth] Apple Sign-In error: \(errorMessage)")
                    completion(false, errorMessage)
                } else if let user = authResult?.user {
                    print("[FirebaseAuth] Apple Sign-In successful: \(user.email ?? user.uid)")
                    
                    // Check if this is a new user (account just created)
                    // Firebase sets creationDate when account is created
                    if let metadata = user.metadata.creationDate,
                       Date().timeIntervalSince(metadata) < 5 {
                        // Account was created within last 5 seconds, so it's a new user
                        UserDefaults.standard.set(true, forKey: "isNewUser")
                        print("[FirebaseAuth] New user detected via Apple Sign-In")
                    }
                    
                    // Auth state listener will handle the rest
                    completion(true, nil)
                }
            }
        }
        #else
        // Fallback for when Firebase is not available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isLoading = false
            let error = "Firebase Auth not available"
            self.errorMessage = error
            completion(false, error)
        }
        #endif
    }
    
    // MARK: - Email Verification
    
    func sendVerificationEmail(completion: @escaping (Bool, String?) -> Void) {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            completion(false, "No user is currently signed in")
            return
        }
        
        user.sendEmailVerification { error in
            DispatchQueue.main.async {
                if let error = error {
                    let errorMessage = error.localizedDescription
                    print("[FirebaseAuth] Email verification send error: \(errorMessage)")
                    completion(false, errorMessage)
                } else {
                    print("[FirebaseAuth] Verification email sent")
                    completion(true, nil)
                }
            }
        }
        #else
        completion(false, "Firebase Auth not available")
        #endif
    }
    
    func checkEmailVerification() {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return }
        
        user.reload { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[FirebaseAuth] Error reloading user: \(error.localizedDescription)")
                } else {
                    self?.updateAuthState(user: user)
                }
            }
        }
        #endif
    }
    
    // MARK: - Rate Limiting
    
    private func checkSignUpRateLimit() -> Bool {
        let defaults = UserDefaults.standard
        let timestampsKey = "signUpTimestamps_\(getDeviceIdentifier())"
        
        // Get existing timestamps
        var timestamps = defaults.array(forKey: timestampsKey) as? [Date] ?? []
        
        // Remove timestamps older than 5 minutes
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        timestamps = timestamps.filter { $0 > fiveMinutesAgo }
        
        // Check if we've exceeded the limit (3 attempts per 5 minutes)
        if timestamps.count >= 3 {
            print("[FirebaseAuth] Rate limit exceeded: \(timestamps.count) attempts in last 5 minutes")
            return false
        }
        
        return true
    }
    
    private func recordSignUpAttempt() {
        let defaults = UserDefaults.standard
        let timestampsKey = "signUpTimestamps_\(getDeviceIdentifier())"
        
        // Get existing timestamps
        var timestamps = defaults.array(forKey: timestampsKey) as? [Date] ?? []
        
        // Add current timestamp
        timestamps.append(Date())
        
        // Remove timestamps older than 5 minutes
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        timestamps = timestamps.filter { $0 > fiveMinutesAgo }
        
        // Save updated timestamps
        defaults.set(timestamps, forKey: timestampsKey)
        defaults.synchronize()
        
        print("[FirebaseAuth] Recorded sign-up attempt. Total in last 5 minutes: \(timestamps.count)")
    }
    
    private func getDeviceIdentifier() -> String {
        // Use a persistent device identifier
        let key = "deviceIdentifier"
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: key)
            return newId
        }
    }
    
    // MARK: - Helper Methods for Apple Sign-In
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - Firebase User Model

struct FirebaseUser {
    let id: String
    let email: String
    let accessToken: String?
}

