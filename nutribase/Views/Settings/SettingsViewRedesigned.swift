import SwiftUI
import UniformTypeIdentifiers
import Combine

// MARK: - Modern Card-Based Settings View
// Redesigned to match Dashboard, Food Log, and Weight Log styling
struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var analyticsService = AnalyticsService.shared
    
    private var viewBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color matching other views
                viewBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom header to match other views
                    ZStack {
                        Text("Settings")
                            .font(.custom("Montserrat-Bold", size: 17))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .padding(.top, 1)
                    .background(viewBackground)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // 1. Account Section
                            SettingsSection(title: "Account") {
                                SettingsNavigationRow(
                                    icon: "person.circle",
                                    iconColor: .blue,
                                    title: "Profile",
                                    subtitle: "Account settings and login options",
                                    destination: AnyView(ProfileView())
                                )
                            }
                            
                            // 2. App Preferences Section
                            SettingsSection(title: "App Preferences") {
                                VStack(spacing: 0) {
                                    SettingsNavigationRow(
                                        icon: "paintbrush.fill",
                                        iconColor: Color(hex: "#35b8ff"),
                                        title: "Theme",
                                        subtitle: "Choose light or dark mode",
                                        destination: AnyView(ThemeSettingsView())
                                    )
                                    
                                    Divider().padding(.leading, 55)
                                    
                                    SettingsNavigationRow(
                                        icon: "bell.fill",
                                        iconColor: Color(hex: "#35b8ff"),
                                        title: "Notifications",
                                        subtitle: "Manage notification preferences",
                                        destination: AnyView(NotificationSettingsView())
                                    )
                                    
                                    Divider().padding(.leading, 55)
                                    
                                    SettingsNavigationRow(
                                        icon: "eye.slash",
                                        iconColor: Color(hex: "#35b8ff"),
                                        title: "Metric Visibility",
                                        subtitle: "Choose which metrics to display",
                                        destination: AnyView(MetricVisibilityPreferencesView())
                                    )
                                    
                                    Divider().padding(.leading, 55)
                                    
                                    SettingsNavigationRow(
                                        icon: "envelope",
                                        iconColor: .purple,
                                        title: "Sharing & Email",
                                        subtitle: "Configure sharing preferences",
                                        destination: AnyView(SharingSettingsView())
                                    )
                                }
                            }
                            
                            // 3. Tracking Settings Section
                            SettingsSection(title: "Personal Settings") {
                                VStack(spacing: 0) {
                                    SettingsNavigationRow(
                                        icon: "person.crop.circle",
                                        iconColor: .gray,
                                        title: "Personal Information",
                                        subtitle: "Update your personal details",
                                        destination: AnyView(PersonalInformationView())
                                    )
                                    
                                    Divider().padding(.leading, 55)
                                    
                                    SettingsNavigationRow(
                                        icon: "target",
                                        iconColor: .blue,
                                        title: "Goals",
                                        subtitle: "Manage your weight, steps, and NOVA goals",
                                        destination: AnyView(GoalsMenuView())
                                    )
                                }
                            }
                            
                            // 4. Food Database Section
                            SettingsSection(title: "Food Database") {
                                SettingsNavigationRow(
                                    icon: "plus.circle",
                                    iconColor: .green,
                                    title: "Add New Food",
                                    subtitle: "Contribute to the food database",
                                    destination: AnyView(AddFoodView())
                                )
                            }
                            
                            // 5. Data Management Section
                            SettingsSection(title: "Data Management") {
                                SettingsNavigationRow(
                                    icon: "externaldrive",
                                    iconColor: .gray,
                                    title: "Data Management",
                                    subtitle: "Import, export, and manage your data",
                                    destination: AnyView(DataManagementView())
                                )
                            }
                            
                            // 6. Privacy Section
                            SettingsSection(title: "Privacy") {
                                SettingsNavigationRow(
                                    icon: "lock.shield",
                                    iconColor: .blue,
                                    title: "Privacy",
                                    subtitle: "Terms, policies, and data consents",
                                    destination: AnyView(PrivacyView())
                                )
                            }
                            
                            // 7. Support Section
                            SettingsSection(title: "Support") {
                                VStack(spacing: 0) {
                                    SettingsNavigationRow(
                                        icon: "questionmark.circle",
                                        iconColor: Color(hex: "#35b8ff"),
                                        title: "Contact Support",
                                        subtitle: "Get help and send feedback",
                                        destination: AnyView(ContactSupportView())
                                    )
                                    
                                    Divider().padding(.leading, 55)
                                    
                                    SettingsNavigationRow(
                                        icon: "doc.text.magnifyingglass",
                                        iconColor: .green,
                                        title: "Sources & Citations",
                                        subtitle: "Scientific sources for health calculations",
                                        destination: AnyView(SourcesCitationsView())
                                    )
                                }
                            }
                            
                            Spacer(minLength: 20)
                        }
                        .padding(.top, 16)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Settings Section Component
struct SettingsSection<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let content: Content
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
            
            content
                .background(cardBackground)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Settings Navigation Row Component
struct SettingsNavigationRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(iconColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Settings Button Row Component
struct SettingsButtonRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(iconColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

#Preview {
    SettingsView()
}
