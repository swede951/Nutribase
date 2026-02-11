import SwiftUI

struct CalorieSummaryCard: View {
    var consumedCalories: Int
    var targetCalories: Int
    var activityCalories: Int = 0
    var onCardTap: (() -> Void)? = nil
    
    @State private var showingSettings = false
    @AppStorage("includeActivityCaloriesInGoal") private var includeActivityCalories = false
    
    private var adjustedGoal: Int {
        includeActivityCalories ? targetCalories + activityCalories : targetCalories
    }
    
    private var remainingCalories: Int {
        adjustedGoal - consumedCalories
    }
    
    private var progress: Double {
        if adjustedGoal == 0 { return 0 }
        return Double(consumedCalories) / Double(adjustedGoal)
    }
    
    private var progressColor: Color {
        if progress > 1.0 {
            return .red
        } else if progress > 0.9 {
            return .orange
        } else {
            return .blue
        }
    }
    
    var body: some View {
        FixedSizeCard(
            title: "Calories Remaining",
            onCardTap: onCardTap,
            customHeight: 130,
            titleAction: { showingSettings = true },
            titleActionIcon: "gearshape"
        ) {
            HStack(spacing: 0) {
                Spacer()
                
                // Goal section - simple display
                VStack(spacing: 4) {
                    Text("\(targetCalories)")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Goal")
                        .font(.custom("Montserrat-SemiBold", size: 12))
                        .foregroundColor(.gray)
                        .offset(y: 23)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("-")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(" ")
                        .font(.custom("Montserrat-SemiBold", size: 12))
                        .foregroundColor(.clear)
                        .offset(y: 23)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("\(consumedCalories)")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Consumed")
                        .font(.custom("Montserrat-SemiBold", size: 12))
                        .foregroundColor(.gray)
                        .offset(y: 23)
                }
                
                Spacer()
                
                // Show activity calories if enabled (even if 0 to show feature is active)
                if includeActivityCalories {
                    VStack(spacing: 4) {
                        Text("+")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(" ")
                            .font(.custom("Montserrat-SemiBold", size: 12))
                            .foregroundColor(.clear)
                            .offset(y: 23)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("\(activityCalories)")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Activity")
                            .font(.custom("Montserrat-SemiBold", size: 12))
                            .foregroundColor(.gray)
                            .offset(y: 23)
                    }
                    
                    Spacer()
                }
                
                VStack(spacing: 4) {
                    Text("=")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(" ")
                        .font(.custom("Montserrat-SemiBold", size: 12))
                        .foregroundColor(.clear)
                        .offset(y: 23)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    CircularProgressBar(
                        progress: 1.0 - progress,
                        total: targetCalories,
                        current: remainingCalories,
                        color: progressColor,
                        lineWidth: 6
                    )
                    .frame(width: 70, height: 70)
                    
                    Text("Remaining")
                        .font(.custom("Montserrat-SemiBold", size: 12))
                        .foregroundColor(.gray)
                        .fixedSize()
                }
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingSettings) {
            CaloriesSummarySettingsView(
                includeActivityCalories: $includeActivityCalories,
                activityCalories: activityCalories
            )
        }
    }
}

// Settings view for calories summary card
struct CaloriesSummarySettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) private var dismiss
    @Binding var includeActivityCalories: Bool
    let activityCalories: Int
    
    @State private var showWeightGoals: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle(isOn: $includeActivityCalories) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Include Activity Calories")
                                .font(.body)
                            Text("Add \(activityCalories) active calories to your daily goal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Calorie Goal Adjustment")
                } footer: {
                    Text("When enabled, your calorie goal will be increased by the number of active calories you burn through exercise and activity. This follows the principle of 'eating back' exercise calories.")
                }
                
                Section {
                    Button {
                        showWeightGoals = true
                    } label: {
                        HStack {
                            Text("Base Goal")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(UserProfile.shared.dailyCalorieGoal)")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if includeActivityCalories {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.orange)
                            Text("Activity Calories")
                            Spacer()
                            Text("+\(activityCalories)")
                                .foregroundColor(.orange)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Adjusted Goal")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(UserProfile.shared.dailyCalorieGoal + activityCalories)")
                                .fontWeight(.semibold)
                        }
                    }
                } header: {
                    Text("Goal Breakdown")
                }
            }
            .navigationTitle("Calorie Goal Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .sheet(isPresented: $showWeightGoals) {
                NavigationView {
                    WeightGoalsView()
                        .id(UUID()) // Force fresh view instance each time sheet opens
                }
            }
        }
    }
}

#Preview {
    VStack {
        CalorieSummaryCard(consumedCalories: 1450, targetCalories: 2100, activityCalories: 340)
        CalorieSummaryCard(consumedCalories: 2000, targetCalories: 2100, activityCalories: 340)
        CalorieSummaryCard(consumedCalories: 2200, targetCalories: 2100, activityCalories: 340)
    }
    .background(Color(.systemGray6))
}
