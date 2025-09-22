//
//  ContentView.swift
//  nutribase
//
//  Created by Alex Sweet on 03/06/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    // Setup notification observer for tab navigation
    init() {
        setupNotifications()
    }
    
    // Setup notification observers
    private func setupNotifications() {
        // Listen for navigation to food log tab
        NotificationCenter.default.addObserver(forName: .navigateToFoodLog, object: nil, queue: .main) { [self] _ in
            // Switch to the food log tab (index 1)
            selectedTab = 1
        }
    }
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
            // Dashboard Tab
            NavigationView {
                DashboardView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Image(systemName: "square.grid.2x2")
            }
            .tag(0)
            
            // Food Log Tab
            NavigationView {
                FoodLogView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Image(systemName: "fork.knife")
            }
            .tag(1)
            
            // Phases Tab (center button)
            NavigationView {
                PhasesView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Image(systemName: "calendar")
                    .font(.title)
            }
            .tag(2)
            
            // Weight Log Tab
            NavigationView {
                WeightLogView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Image(systemName: "chart.line.uptrend.xyaxis")
            }
            .tag(3)
            
            // Settings Tab
            NavigationView {
                SettingsView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Image(systemName: "gear")
            }
            .tag(4)
            }
            .accentColor(.blue) // Set the accent color for the selected tab
        }
    }
}



#Preview {
    ContentView()
}
