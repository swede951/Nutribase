import SwiftUI
import Combine
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct ProfileView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var userProfile = UserProfile.shared
    @State private var showingLogoutAlert = false
    @State private var shouldShowLogin = false
    @State private var showingChangeEmail = false
    @State private var showingChangePassword = false
    @State private var showingDeleteAccountAlert = false
    
    let availableRegions = ["All Regions", "United Kingdom", "United States", "France", "Germany", "Italy", "Spain", "Netherlands", "Belgium", "Switzerland", "Australia", "Canada", "New Zealand", "Ireland", "Norway", "Sweden", "Denmark"]
    
    private var viewBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    // Use display name if set, otherwise extract name from email
    private var displayNameOrDefault: String {
        if !userProfile.displayName.isEmpty {
            return userProfile.displayName
        }
        // Fallback: use email prefix (before @) with capitalized words
        if let email = authService.currentUser?.email {
            let prefix = email.components(separatedBy: "@").first ?? ""
            // Clean up and capitalize (e.g., "john.doe" -> "John Doe")
            return prefix
                .replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .split(separator: " ")
                .map { $0.capitalized }
                .joined(separator: " ")
        }
        return "User"
    }
    
    var body: some View {
        ZStack {
            // Background
            viewBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Profile header
                    VStack(spacing: 16) {
                        // Profile image
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#35b8ff").opacity(0.2))
                                .frame(width: 100, height: 100)
                            
                            if authService.isAuthenticated {
                                Text("U")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(Color(hex: "#35b8ff"))
                            } else {
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(Color(hex: "#35b8ff"))
                            }
                        }
                        
                        // User email
                        Text(authService.currentUser?.email ?? "Authenticated User")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                    
                    // User Information Card
                    VStack(spacing: 0) {
                        ProfileInfoRow(
                            icon: "person.fill",
                            iconColor: Color(hex: "#35b8ff"),
                            title: "Username",
                            value: displayNameOrDefault,
                            showDivider: true
                        )
                        
                        ProfileInfoRow(
                            icon: "envelope.fill",
                            iconColor: Color(hex: "#35b8ff"),
                            title: "Email",
                            value: authService.currentUser?.email ?? "Not set",
                            showDivider: true
                        )
                        
                        // Location picker row
                        VStack(spacing: 0) {
                            HStack(spacing: 15) {
                                Image(systemName: "location.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.green)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Location")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("Location", selection: $userProfile.preferredRegion) {
                                        ForEach(availableRegions, id: \.self) { region in
                                            Text(region).tag(region)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .background(cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    // Account Settings Card
                    VStack(spacing: 0) {
                        // Only show these options for logged in users
                        if authService.isAuthenticated {
                            ProfileCardRow(
                                icon: "envelope.fill",
                                iconColor: Color(hex: "#35b8ff"),
                                title: "Change Email",
                                showDivider: true,
                                action: { showingChangeEmail = true }
                            )
                            
                            ProfileCardRow(
                                icon: "lock.fill",
                                iconColor: Color(hex: "#35b8ff"),
                                title: "Change Password",
                                showDivider: false,
                                action: { showingChangePassword = true }
                            )
                        }
                    }
                    .background(cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 20)
                    
                    // Logout and Delete Account buttons
                    if authService.isAuthenticated {
                        VStack(spacing: 12) {
                            // Log Out button
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.right.square")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                                
                                Text("Log Out")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.red)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(cardBackground)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                            .onTapGesture {
                                print("[ProfileView] Log Out button tapped")
                                showingLogoutAlert = true
                                print("[ProfileView] showingLogoutAlert set to: \(showingLogoutAlert)")
                            }
                            
                            // Delete Account button
                            HStack(spacing: 12) {
                                Image(systemName: "trash")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                                
                                Text("Delete Account")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.red)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(cardBackground)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                            .onTapGesture {
                                print("[ProfileView] Delete Account button tapped")
                                showingDeleteAccountAlert = true
                                print("[ProfileView] showingDeleteAccountAlert set to: \(showingDeleteAccountAlert)")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    // App version
                    Text("NutriBase v1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Profile")
        .toolbarBackground(Color(.systemGray6), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .fullScreenCover(isPresented: $shouldShowLogin) {
            LoginView()
                .environmentObject(authService)
                .onReceive(authService.$isAuthenticated) { isAuthenticated in
                    if isAuthenticated {
                        // Dismiss login screen when user successfully authenticates
                        shouldShowLogin = false
                    }
                }
        }
        .sheet(isPresented: $showingChangeEmail) {
            NavigationStack {
                ChangeEmailView()
                    .environmentObject(authService)
            }
        }
        .sheet(isPresented: $showingChangePassword) {
            NavigationStack {
                ChangePasswordView()
                    .environmentObject(authService)
            }
        }
        .alert(isPresented: $showingDeleteAccountAlert) {
            Alert(
                title: Text("Delete Account"),
                message: Text("Are you sure you want to permanently delete your account? This action cannot be undone and all your data will be lost."),
                primaryButton: .destructive(Text("Delete Account")) {
                    print("[ProfileView] Delete Account confirmed")
                    deleteAccount()
                },
                secondaryButton: .cancel()
            )
        }
        .alert(isPresented: $showingLogoutAlert) {
            Alert(
                title: Text("Log Out"),
                message: Text("Are you sure you want to log out?"),
                primaryButton: .destructive(Text("Log Out")) {
                    print("[ProfileView] Log Out confirmed")
                    
                    // Use the comprehensive force sign out method
                    authService.forceSignOut()
                    
                    // Show login screen
                    shouldShowLogin = true
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // MARK: - Delete Account Function
    private func deleteAccount() {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            print("[ProfileView] No user to delete")
            return
        }
        
        // Delete the user account from Firebase
        user.delete { error in
            if let error = error {
                print("[ProfileView] Error deleting account: \(error.localizedDescription)")
                // You might want to show an error alert here
                // Some errors require re-authentication before deletion
                if (error as NSError).code == AuthErrorCode.requiresRecentLogin.rawValue {
                    print("[ProfileView] Account deletion requires recent login - user needs to re-authenticate")
                    // TODO: Show re-authentication flow
                }
            } else {
                print("[ProfileView] Account successfully deleted")
                
                // Clear local data
                authService.forceSignOut()
                
                // Show login screen
                shouldShowLogin = true
            }
        }
        #else
        print("[ProfileView] Firebase not available - cannot delete account")
        #endif
    }
}

// Info row component for displaying user information
struct ProfileInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    var showDivider: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(iconColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(value)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .padding(.leading, 55)
            }
        }
    }
}

// Card-style row component matching Settings view
struct ProfileCardRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var titleColor: Color = .primary
    var showDivider: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                        .frame(width: 24, height: 24)
                    
                    // Title
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundColor(titleColor)
                    
                    Spacer()
                    
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(.systemGray3))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // Divider
                if showDivider {
                    Divider()
                        .padding(.leading, 60)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProfileView()
        }
    }
}
