//
//  ContentView.swift
//  nutribase
//
//  Created by Alex Sweet on 03/06/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showingQuickAdd = false
    
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
            }
            .tabItem {
                Image(systemName: "square.grid.2x2")
            }
            .tag(0)
            
            // Food Log Tab
            NavigationView {
                FoodLogView()
            }
            .tabItem {
                Image(systemName: "fork.knife")
            }
            .tag(1)
            
            // Quick Add Tab (center button) - This is just a placeholder
            // The actual button functionality is handled by the overlay
            Color.clear
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                }
                .tag(2)
            
            // Weight Log Tab
            NavigationView {
                WeightLogView()
            }
            .tabItem {
                Image(systemName: "chart.line.uptrend.xyaxis")
            }
            .tag(3)
            
            // Settings Tab
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gear")
            }
            .tag(4)
            }
            .accentColor(.blue) // Set the accent color for the selected tab
            
            // Invisible button overlay for the center tab
            // This prevents tab switching and just shows the popup
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showingQuickAdd = true
                    }) {
                        Color.clear
                            .frame(width: UIScreen.main.bounds.width/5, height: 50)
                    }
                    Spacer()
                }
                .padding(.bottom, 5) // Adjust to position over the tab bar
            }
            
            // Quick Add popup overlay
            if showingQuickAdd {
                QuickAddView(isPresented: $showingQuickAdd)
            }
        }
    }
}



#Preview {
    ContentView()
}
