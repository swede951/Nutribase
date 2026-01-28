//
//  ContentView.swift
//  nutribase
//
//  Created by Alex Sweet on 03/06/2025.
//

import SwiftUI

// Tab enum for iOS 26 Tab syntax
enum AppTab: Int, Hashable, CaseIterable {
    case dashboard = 0
    case foodLog = 1
    case phases = 2
    case weightLog = 3
    case settings = 4
}

// Custom modifier to handle iOS 26 specific features with availability check
struct iOS26TabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .tabBarMinimizeBehavior(.never)
        } else {
            content
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .dashboard
    @State private var isDashboardLoaded = false
    
    // Setup notification observer for tab navigation
    init() {
        setupNotifications()
        configureTabBarAppearance()
    }
    
    // Configure tab bar appearance for iOS < 26
    private func configureTabBarAppearance() {
        if #unavailable(iOS 26.0) {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            
            // Set unselected item color to black
            appearance.stackedLayoutAppearance.normal.iconColor = .black
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.black]
            
            // Set selected item color to blue
            let selectedColor = UIColor(red: 0.21, green: 0.72, blue: 1.0, alpha: 1.0) // #35b8ff
            appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    // Setup notification observers
    private func setupNotifications() {
        // Listen for navigation to food log tab
        NotificationCenter.default.addObserver(forName: .navigateToFoodLog, object: nil, queue: .main) { [self] _ in
            // Switch to the food log tab
            selectedTab = .foodLog
        }
    }
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Dashboard Tab
                Tab("Dashboard", systemImage: "square.grid.2x2", value: .dashboard) {
                    NavigationStack {
                        DashboardView(onLoaded: { isDashboardLoaded = true })
                            .navigationBarHidden(true)
                    }
                }
                
                // Food Log Tab
                Tab("Food", systemImage: "fork.knife", value: .foodLog) {
                    NavigationStack {
                        FoodLogView()
                            .navigationBarHidden(true)
                    }
                }
                
                // Phases Tab
                Tab("Phases", systemImage: "calendar", value: .phases) {
                    NavigationStack {
                        TestPhasesView()
                            .navigationBarHidden(true)
                    }
                }
                
                // Weight Log Tab
                Tab("Weight", systemImage: "chart.line.uptrend.xyaxis", value: .weightLog) {
                    NavigationStack {
                        WeightLogView()
                            .navigationBarHidden(true)
                    }
                }
                
                // Settings Tab
                Tab("Settings", systemImage: "gear", value: .settings) {
                    NavigationStack {
                        SettingsView()
                            .navigationBarHidden(true)
                    }
                }
            }
            .tabViewStyle(.tabBarOnly)
            .modifier(iOS26TabBarModifier())
            .tint(Color(hex: "#35b8ff"))
            .keyboardDismissToolbar()
            .transaction { transaction in
                // Disable animation for instant tab switching
                transaction.animation = nil
            }
            .onChange(of: selectedTab) { oldTab, newTab in
                // Notify views to exit edit mode when switching tabs
                NotificationCenter.default.post(name: .exitEditMode, object: nil)
            }
            
            // Show loading screen overlay until dashboard is loaded
            if !isDashboardLoaded {
                LoadingScreenView()
                    .transition(.opacity)
            }
        }
    }
}



#Preview {
    ContentView()
}
