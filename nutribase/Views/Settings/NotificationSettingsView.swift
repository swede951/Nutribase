//
//  NotificationSettingsView.swift
//  nutribase
//
//  Created on 13/11/2025.
//

import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingPermissionAlert = false
    
    private var viewBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    var body: some View {
        ZStack {
            viewBackground.ignoresSafeArea()
        List {
            // Master Toggle
            Section {
                Toggle("Enable Notifications", isOn: $notificationManager.notificationsEnabled)
                    .onChange(of: notificationManager.notificationsEnabled) { _, newValue in
                        if newValue {
                            // Request permission if enabling
                            notificationManager.requestPermission { granted in
                                if !granted {
                                    showingPermissionAlert = true
                                    notificationManager.notificationsEnabled = false
                                }
                            }
                        }
                    }
            } footer: {
                Text("Enable notifications to receive helpful reminders and celebrate your progress.")
            }
            
            if notificationManager.notificationsEnabled {
                // Daily Reminder
                Section {
                    Toggle("Daily Logging Reminder", isOn: $notificationManager.dailyReminderEnabled)
                    
                    if notificationManager.dailyReminderEnabled {
                        DatePicker("Reminder Time", selection: $notificationManager.dailyReminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Daily Reminders")
                } footer: {
                    Text("Get a gentle reminder to log your weight at your preferred time.")
                }
                
                // Milestones & Achievements
                Section {
                    Toggle("Milestone Celebrations", isOn: $notificationManager.milestonesEnabled)
                } header: {
                    Text("Achievements")
                } footer: {
                    Text("Celebrate streaks, phase completions, and personal records.")
                }
                
                // Weekly Summary
                Section {
                    Toggle("Weekly Summary", isOn: $notificationManager.weeklySummaryEnabled)
                } header: {
                    Text("Progress Updates")
                } footer: {
                    Text("Receive a weekly overview of your progress every Sunday evening.")
                }
                
                // Re-engagement
                Section {
                    Toggle("Re-engagement Reminders", isOn: $notificationManager.reEngagementEnabled)
                } header: {
                    Text("Stay Connected")
                } footer: {
                    Text("Gentle reminders if you haven't logged in a while. No pressure, just support.")
                }
                
                // Data Insights
                Section {
                    Toggle("Data Insights", isOn: $notificationManager.dataInsightsEnabled)
                } header: {
                    Text("Learn About Your Patterns")
                } footer: {
                    Text("Occasional insights about your weight trends and patterns.")
                }
                
                // Quiet Hours
                Section {
                    Toggle("Quiet Hours", isOn: $notificationManager.quietHoursEnabled)
                    
                    if notificationManager.quietHoursEnabled {
                        DatePicker("Start", selection: $notificationManager.quietHoursStart, displayedComponents: .hourAndMinute)
                        DatePicker("End", selection: $notificationManager.quietHoursEnd, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Do Not Disturb")
                } footer: {
                    Text("No notifications will be sent during quiet hours.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(viewBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable notifications in Settings to receive reminders and updates.")
        }
    }
}

#Preview {
    NavigationView {
        NotificationSettingsView()
    }
}
