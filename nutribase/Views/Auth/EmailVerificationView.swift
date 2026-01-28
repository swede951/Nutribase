import SwiftUI

struct EmailVerificationView: View {
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var isChecking = false
    @State private var showingResendAlert = false
    @State private var resendMessage = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#35b8ff"), Color(hex: "#5ec5ff")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Title
            Text("One Last Step!")
                .font(.custom("Montserrat-ExtraBold", size: 28))
                .foregroundColor(.primary)
            
            // Subtitle
            Text("Verify your email to unlock all features")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Message
            VStack(spacing: 12) {
                Text("We've sent a verification link to:")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text(authService.currentUser?.email ?? "your email")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .padding(.top, 8)
            
            // Why verify section
            VStack(alignment: .leading, spacing: 12) {
                Text("Why verify?")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VerificationBenefitRow(
                    icon: "icloud.fill",
                    color: .blue,
                    title: "Cloud Backup",
                    description: "Your data syncs across devices"
                )
                
                VerificationBenefitRow(
                    icon: "arrow.triangle.2.circlepath",
                    color: .green,
                    title: "Account Recovery",
                    description: "Reset your password if you forget it"
                )
                
                VerificationBenefitRow(
                    icon: "star.fill",
                    color: .orange,
                    title: "Full Access",
                    description: "Unlock all premium features"
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Check verification button
            Button(action: checkVerification) {
                if isChecking {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("I've Verified My Email")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color(hex: "#35b8ff"), Color(hex: "#5ec5ff")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal, 40)
            .disabled(isChecking)
            .padding(.top, 16)
            
            // Resend email button
            Button(action: resendVerificationEmail) {
                Text("Resend Verification Email")
                    .font(.body)
                    .foregroundColor(Color(hex: "#35b8ff"))
            }
            .padding(.top, 8)
            
            // Spam folder tip
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                Text("Check your spam folder if you don't see it")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
            
            Spacer()
            
            // Sign out button
            Button(action: signOut) {
                Text("Sign Out")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
        }
        .padding()
        .alert(isPresented: $showingResendAlert) {
            Alert(
                title: Text("Email Sent"),
                message: Text(resendMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func checkVerification() {
        isChecking = true
        authService.checkEmailVerification()
        
        // Give it a moment to reload
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isChecking = false
            
            if authService.isEmailVerified {
                // User just verified - sync their onboarding profile to Firebase
                print("✅ Email verified - syncing profile to Firebase")
                UserProfile.shared.saveToFirebase()
            } else {
                resendMessage = "Email not verified yet. Please check your inbox and spam folder."
                showingResendAlert = true
            }
        }
    }
    
    private func resendVerificationEmail() {
        authService.sendVerificationEmail { success, error in
            if success {
                resendMessage = "Verification email sent! Please check your inbox."
            } else {
                resendMessage = error ?? "Failed to send verification email. Please try again."
            }
            showingResendAlert = true
        }
    }
    
    private func signOut() {
        authService.signOut()
    }
}

// MARK: - Supporting Views

struct VerificationBenefitRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    EmailVerificationView()
}
