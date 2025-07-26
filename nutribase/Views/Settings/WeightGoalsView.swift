import SwiftUI

struct WeightGoalsView: View {
    @StateObject private var userProfile = UserProfile.shared
    @State private var weeklyChangeAmount = 0.5
    
    // Local state for macro percentages to prevent UI freezes
    @State private var proteinPercentage: Int = UserProfile.shared.proteinPercentage
    @State private var carbPercentage: Int = UserProfile.shared.carbPercentage
    @State private var fatPercentage: Int = UserProfile.shared.fatPercentage
    
    var body: some View {
        Form {
            Section(header: Text("Weight Goal")) {
                Picker("Goal Type", selection: $userProfile.weightGoalType) {
                    ForEach(WeightGoalType.allCases) { goal in
                        Text(goal.rawValue).tag(goal)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 8)
                
                if userProfile.weightGoalType != .maintain {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekly \(userProfile.weightGoalType == .lose ? "Loss" : "Gain") Rate")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        Slider(value: $weeklyChangeAmount, in: 0.25...1.0, step: 0.25) {
                            Text("Weekly Change")
                        } minimumValueLabel: {
                            Text("0.25")
                                .font(.caption)
                        } maximumValueLabel: {
                            Text("1.0")
                                .font(.caption)
                        }
                        
                        Text("\(String(format: "%.2f", weeklyChangeAmount)) kg per week")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)
                }
            }
            
            Section(header: Text("Nutrition Goals"), footer: Text("These goals are automatically calculated based on your personal information and weight goals.")) {
                if userProfile.dailyCalorieGoal > 0 {
                    HStack {
                        Text("Daily Calories")
                        Spacer()
                        Text("\(userProfile.dailyCalorieGoal)")
                            .bold()
                    }
                    
                    HStack {
                        Text("Protein")
                        Spacer()
                        Text("\(userProfile.proteinGoalGrams)g (\(userProfile.proteinPercentage)%)")
                            .bold()
                    }
                    
                    HStack {
                        Text("Carbohydrates")
                        Spacer()
                        Text("\(userProfile.carbGoalGrams)g (\(userProfile.carbPercentage)%)")
                            .bold()
                    }
                    
                    HStack {
                        Text("Fat")
                        Spacer()
                        Text("\(userProfile.fatGoalGrams)g (\(userProfile.fatPercentage)%)")
                            .bold()
                    }
                } else {
                    Text("Complete your personal information to see nutrition goals")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Macro Distribution")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Protein: \(proteinPercentage)%")
                    Slider(value: Binding(
                        get: { Double(proteinPercentage) },
                        set: { proteinPercentage = Int($0) }
                    ), in: 10...60, step: 1)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Carbohydrates: \(carbPercentage)%")
                    Slider(value: Binding(
                        get: { Double(carbPercentage) },
                        set: { carbPercentage = Int($0) }
                    ), in: 10...70, step: 1)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fat: \(fatPercentage)%")
                    Slider(value: Binding(
                        get: { Double(fatPercentage) },
                        set: { fatPercentage = Int($0) }
                    ), in: 10...60, step: 1)
                }
                
                HStack {
                    Text("Total: \(proteinPercentage + carbPercentage + fatPercentage)% (should equal 100%)")
                        .font(.caption)
                        .foregroundColor(proteinPercentage + carbPercentage + fatPercentage == 100 ? .green : .red)
                    
                    Spacer()
                    
                    if proteinPercentage + carbPercentage + fatPercentage != 100 {
                        Button("Balance") {
                            // Calculate how to adjust to reach 100%
                            let total = proteinPercentage + carbPercentage + fatPercentage
                            let difference = 100 - total
                            
                            if difference > 0 {
                                // Need to add percentage points
                                carbPercentage += difference
                            } else if difference < 0 {
                                // Need to subtract percentage points
                                // Try to keep protein at least at 10%
                                let excess = abs(difference)
                                
                                if carbPercentage > (10 + excess) {
                                    carbPercentage -= excess
                                } else if fatPercentage > (10 + excess) {
                                    fatPercentage -= excess
                                } else {
                                    // Distribute the reduction
                                    let carbReduction = min(carbPercentage - 10, excess / 2)
                                    carbPercentage -= carbReduction
                                    fatPercentage -= (excess - carbReduction)
                                }
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                    
                Button(action: {
                    // Apply changes to the user profile only when the button is pressed
                    userProfile.proteinPercentage = proteinPercentage
                    userProfile.carbPercentage = carbPercentage
                    userProfile.fatPercentage = fatPercentage
                }) {
                    Text("Apply Macro Changes")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(proteinPercentage + carbPercentage + fatPercentage != 100)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Weight Goals")
        .onAppear {
            // Initialize weekly change amount from user profile
            weeklyChangeAmount = abs(userProfile.weeklyWeightChangeKg)
            
            // Initialize macro percentages from user profile
            proteinPercentage = userProfile.proteinPercentage
            carbPercentage = userProfile.carbPercentage
            fatPercentage = userProfile.fatPercentage
        }
        .onChange(of: weeklyChangeAmount) { oldValue, newValue in
            // Update user profile with the new weekly change amount
            // Use positive value for gain, negative for loss
            userProfile.weeklyWeightChangeKg = userProfile.weightGoalType == .lose ? -newValue : newValue
        }
        .onChange(of: userProfile.weightGoalType) { oldValue, newValue in
            // Update weekly weight change sign based on goal type
            userProfile.weeklyWeightChangeKg = newValue == .lose ? -abs(weeklyChangeAmount) : abs(weeklyChangeAmount)
        }
    }
}

#Preview {
    NavigationStack {
        WeightGoalsView()
    }
}
