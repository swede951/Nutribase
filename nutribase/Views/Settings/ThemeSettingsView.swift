import SwiftUI

// Theme preference manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.system.rawValue
        self.selectedTheme = AppTheme(rawValue: savedTheme) ?? .system
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var id: String { self.rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
    
    var icon: String {
        switch self {
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        case .system:
            return "circle.lefthalf.filled"
        }
    }
    
    var description: String {
        switch self {
        case .light:
            return "Always use light mode"
        case .dark:
            return "Always use dark mode"
        case .system:
            return "Match system appearance"
        }
    }
}

struct ThemeSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var themeManager = ThemeManager.shared
    
    private var viewBackground: Color {
        Color.appBackground
    }
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    var body: some View {
        ZStack {
            // Background
            viewBackground
                .ignoresSafeArea()
            
            List {
                Section {
                    ForEach(AppTheme.allCases) { theme in
                        Button(action: {
                            themeManager.selectedTheme = theme
                        }) {
                            HStack(spacing: 15) {
                                Image(systemName: theme.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(iconColor(for: theme))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(theme.rawValue)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Text(theme.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if themeManager.selectedTheme == theme {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(hex: "#35b8ff"))
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowBackground(cardBackground)
                    }
                } header: {
                    Text("APPEARANCE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                } footer: {
                    Text("Choose how the app looks. System will automatically switch between light and dark based on your device settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Theme")
        .toolbarBackground(viewBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    private func iconColor(for theme: AppTheme) -> Color {
        switch theme {
        case .light:
            return .orange
        case .dark:
            return .indigo
        case .system:
            return Color(hex: "#35b8ff")
        }
    }
}

#Preview {
    NavigationStack {
        ThemeSettingsView()
    }
}
