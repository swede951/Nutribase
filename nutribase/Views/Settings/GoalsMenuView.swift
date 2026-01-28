import SwiftUI

struct GoalsMenuView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    private var viewBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    var body: some View {
        ZStack {
            // Background
            viewBackground
                .ignoresSafeArea()
            
            Form {
                Section {
                    NavigationLink(destination: WeightGoalsViewRedesigned()) {
                        HStack(spacing: 15) {
                            Image(systemName: "arrow.clockwise")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Weight")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Text("Set your weekly weight goals")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    NavigationLink(destination: StepsGoalView()) {
                        HStack(spacing: 15) {
                            Image(systemName: "figure.walk")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Steps")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Text("Set your daily step goal")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    NavigationLink(destination: NovaScoreGoalView()) {
                        HStack(spacing: 15) {
                            Image(systemName: "chart.bar.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NOVA Score")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Text("Set your NOVA 4 limit")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Goals")
        .toolbarBackground(viewBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

// MARK: - Steps Goal View
struct StepsGoalView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var userProfile = UserProfile.shared
    @State private var stepsGoal: Int = 10000
    
    private var viewBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    var body: some View {
        ZStack {
            viewBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    SettingsSection(title: "Daily Steps Goal") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Steps Goal")
                                    .font(.system(size: 17))
                                Spacer()
                                Text("\(stepsGoal)")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            
                            VStack(spacing: 8) {
                                Slider(value: Binding(
                                    get: { Double(stepsGoal) },
                                    set: { stepsGoal = Int($0) }
                                ), in: 1000...30000, step: 500)
                                .accentColor(.blue)
                                .padding(.horizontal, 20)
                                
                                HStack {
                                    Text("1,000")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("30,000")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    
                    Text("Set your daily step goal to track your activity level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .navigationTitle("Steps Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(viewBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            stepsGoal = UserDefaults.standard.integer(forKey: "stepsGoal")
            if stepsGoal == 0 {
                stepsGoal = 10000
            }
        }
        .onChange(of: stepsGoal) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "stepsGoal")
        }
    }
}

// MARK: - NOVA Score Goal View
struct NovaScoreGoalView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var nova4Limit: Int = 20
    
    private var viewBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    var body: some View {
        ZStack {
            viewBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    SettingsSection(title: "NOVA 4 Limit") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("NOVA 4 Limit")
                                    .font(.system(size: 17))
                                Spacer()
                                Text("\(nova4Limit)%")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            
                            VStack(spacing: 8) {
                                Slider(value: Binding(
                                    get: { Double(nova4Limit) },
                                    set: { nova4Limit = Int($0) }
                                ), in: 0...100, step: 5)
                                .accentColor(.orange)
                                .padding(.horizontal, 20)
                                
                                HStack {
                                    Text("0%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("100%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About NOVA 4")
                            .font(.headline)
                        
                        Text("NOVA 4 foods are ultra-processed foods that typically contain ingredients not commonly used in home cooking, such as preservatives, emulsifiers, and artificial flavors.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Set a limit for the maximum percentage of your daily calories that should come from NOVA 4 foods. Lower is generally better for health.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .navigationTitle("NOVA Score Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(viewBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            nova4Limit = UserDefaults.standard.integer(forKey: "nova4Limit")
            if nova4Limit == 0 {
                nova4Limit = 20
            }
        }
        .onChange(of: nova4Limit) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "nova4Limit")
        }
    }
}
