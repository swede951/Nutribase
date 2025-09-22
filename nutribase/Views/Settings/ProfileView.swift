import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var authService: SimpleAuthService
    @State private var showingLogoutAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile header
            VStack(spacing: 16) {
                // Profile image
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    if authService.isAuthenticated {
                        Text("U")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.green)
                    }
                }
                
                // User email or guest label
                Text(authService.isAuthenticated ? (authService.currentUser?.email ?? "Authenticated User") : "Guest User")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if UserDefaults.standard.bool(forKey: "guest_mode") {
                    Text("Limited functionality in guest mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 20)
            
            Divider()
                .padding(.vertical)
            
            // Account options
            VStack(spacing: 0) {
                // Only show these options for logged in users
                if authService.isAuthenticated {
                    ProfileOptionRow(icon: "envelope.fill", title: "Change Email", action: {
                        // Email change functionality would go here
                    })
                    
                    ProfileOptionRow(icon: "lock.fill", title: "Change Password", action: {
                        // Password change functionality would go here
                    })
                    
                    Divider()
                        .padding(.leading, 50)
                }
                
                // Show for all users
                ProfileOptionRow(icon: "bell.fill", title: "Notifications", action: {
                    // Notifications settings would go here
                })
                
                ProfileOptionRow(icon: "hand.raised.fill", title: "Privacy", action: {
                    // Privacy settings would go here
                })
                
                Divider()
                    .padding(.leading, 50)
                
                // Logout or login option
                if authService.isAuthenticated {
                    ProfileOptionRow(icon: "arrow.right.square", title: "Log Out", textColor: .red, action: {
                        showingLogoutAlert = true
                    })
                } else {
                    ProfileOptionRow(icon: "arrow.right.square", title: "Log In", textColor: .blue, action: {
                        // Clear guest mode and authentication state to go back to login screen
                        UserDefaults.standard.removeObject(forKey: "guest_mode")
                        authService.signOut()
                    })
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            
            Spacer()
            
            // App version
            Text("NutriBase v1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 10)
        }
        .navigationTitle("Profile")
        .alert(isPresented: $showingLogoutAlert) {
            Alert(
                title: Text("Log Out"),
                message: Text("Are you sure you want to log out?"),
                primaryButton: .destructive(Text("Log Out")) {
                    // Clear authentication state and guest mode to return to login screen
                    authService.signOut()
                    UserDefaults.standard.removeObject(forKey: "guest_mode")
                },
                secondaryButton: .cancel()
            )
        }
    }
}

// Reusable row component for profile options
struct ProfileOptionRow: View {
    let icon: String
    let title: String
    var textColor: Color = .primary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 30, height: 30)
                    .foregroundColor(.green)
                    .padding(.trailing, 10)
                
                Text(title)
                    .foregroundColor(textColor)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(.systemGray3))
                    .font(.system(size: 14))
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
        }
        .background(Color(.systemBackground))
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProfileView()
                .environmentObject(SupabaseService.shared)
                .environmentObject(SimpleAuthService.shared)
        }
    }
}
