import SwiftUI

enum MacroDistributionMode: String, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case custom = "Custom"
    
    var id: String { self.rawValue }
}

struct WeightGoalsView: View {
    @StateObject private var userProfile = UserProfile.shared
    @State private var weeklyChangeAmount = 0.0
    
    // Local state for macro percentages to prevent UI freezes
    @State private var proteinPercentage: Int = UserProfile.shared.proteinPercentage
    @State private var carbPercentage: Int = UserProfile.shared.carbPercentage
    @State private var fatPercentage: Int = UserProfile.shared.fatPercentage
    
    // Macro distribution mode - persisted in UserDefaults
    @State private var macroDistributionMode: MacroDistributionMode = .custom
    
    // Track original values to detect changes
    @State private var originalProteinPercentage: Int = 0
    @State private var originalCarbPercentage: Int = 0
    @State private var originalFatPercentage: Int = 0
    @State private var originalMacroMode: MacroDistributionMode = .custom
    
    var body: some View {
        Form {
            Section(header: Text("Weight Goal")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Weekly Weight Change")
                        .font(.headline)
                    
                    Slider(value: $weeklyChangeAmount, in: -1.0...1.0, step: 0.1) {
                        Text("Weekly Change")
                    } minimumValueLabel: {
                        Text("-1.0")
                            .font(.caption)
                    } maximumValueLabel: {
                        Text("+1.0")
                            .font(.caption)
                    }
                    
                    HStack {
                        Text(weeklyChangeDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(String(format: "%.1f", weeklyChangeAmount)) kg per week")
                            .font(.subheadline)
                            .bold()
                    }
                }
                .padding(.vertical, 8)
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
                        Text("\(calculateProteinGrams())g (\(currentProteinPercentage)%)")
                            .bold()
                    }
                    
                    HStack {
                        Text("Carbohydrates")
                        Spacer()
                        Text("\(calculateCarbGrams())g (\(currentCarbPercentage)%)")
                            .bold()
                    }
                    
                    HStack {
                        Text("Fat")
                        Spacer()
                        Text("\(calculateFatGrams())g (\(currentFatPercentage)%)")
                            .bold()
                    }
                } else {
                    Text("Complete your personal information to see nutrition goals")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Macro Distribution")) {
                // Segmented picker for Automatic vs Custom
                Picker("Macro Distribution Mode", selection: $macroDistributionMode) {
                    ForEach(MacroDistributionMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 8)
                
                if macroDistributionMode == .custom {
                    // Custom macro sliders
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
                } else {
                    // Automatic macro distribution info
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Protein")
                            Spacer()
                            Text("20%")
                                .bold()
                        }
                        
                        HStack {
                            Text("Carbohydrates")
                            Spacer()
                            Text("50%")
                                .bold()
                        }
                        
                        HStack {
                            Text("Fat")
                            Spacer()
                            Text("30%")
                                .bold()
                        }
                        
                        Text("These are recommended values for a balanced diet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                }
                
                // Only show apply button if changes have been made
                if hasChanges {
                    Button(action: {
                    if macroDistributionMode == .automatic {
                        // Set recommended values
                        userProfile.proteinPercentage = 20
                        userProfile.carbPercentage = 50
                        userProfile.fatPercentage = 30
                        
                        // Update local state
                        proteinPercentage = 20
                        carbPercentage = 50
                        fatPercentage = 30
                    } else {
                        // Apply custom changes to the user profile
                        userProfile.proteinPercentage = proteinPercentage
                        userProfile.carbPercentage = carbPercentage
                        userProfile.fatPercentage = fatPercentage
                    }
                }) {
                    Text(macroDistributionMode == .automatic ? "Apply Recommended Macros" : "Apply Custom Macros")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(macroDistributionMode == .custom && proteinPercentage + carbPercentage + fatPercentage != 100)
                .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Weight Goals")
        .onAppear {
            // Initialize weekly change amount from user profile (preserve sign)
            weeklyChangeAmount = userProfile.weeklyWeightChangeKg
            
            // Initialize macro percentages from user profile
            proteinPercentage = userProfile.proteinPercentage
            carbPercentage = userProfile.carbPercentage
            fatPercentage = userProfile.fatPercentage
            
            // Store original values to track changes
            originalProteinPercentage = userProfile.proteinPercentage
            originalCarbPercentage = userProfile.carbPercentage
            originalFatPercentage = userProfile.fatPercentage
            
            // Load persisted macro distribution mode
            let savedModeString = UserDefaults.standard.string(forKey: "macroDistributionMode") ?? "custom"
            macroDistributionMode = MacroDistributionMode(rawValue: savedModeString.capitalized) ?? .custom
            originalMacroMode = macroDistributionMode
        }
        .onChange(of: weeklyChangeAmount) { oldValue, newValue in
            // Update user profile with the new weekly change amount
            userProfile.weeklyWeightChangeKg = newValue
            
            // Update weight goal type based on the sign
            if newValue < 0 {
                userProfile.weightGoalType = .lose
            } else if newValue > 0 {
                userProfile.weightGoalType = .gain
            } else {
                userProfile.weightGoalType = .maintain
            }
        }
        .onChange(of: macroDistributionMode) { oldValue, newValue in
            // Persist macro distribution mode
            UserDefaults.standard.set(newValue.rawValue.lowercased(), forKey: "macroDistributionMode")
        }
    }
    
    // Computed property to check if any changes have been made
    private var hasChanges: Bool {
        return macroDistributionMode != originalMacroMode ||
               proteinPercentage != originalProteinPercentage ||
               carbPercentage != originalCarbPercentage ||
               fatPercentage != originalFatPercentage
    }
    
    // Helper function to reset to original values
    private func resetToOriginalValues() {
        proteinPercentage = originalProteinPercentage
        carbPercentage = originalCarbPercentage
        fatPercentage = originalFatPercentage
        macroDistributionMode = originalMacroMode
    }
    
    // Computed properties for current percentages (either local state or automatic values)
    private var currentProteinPercentage: Int {
        return macroDistributionMode == .automatic ? 20 : proteinPercentage
    }
    
    private var currentCarbPercentage: Int {
        return macroDistributionMode == .automatic ? 50 : carbPercentage
    }
    
    private var currentFatPercentage: Int {
        return macroDistributionMode == .automatic ? 30 : fatPercentage
    }
    
    // Helper functions to calculate grams based on current percentages
    private func calculateProteinGrams() -> Int {
        let caloriesFromProtein = Double(userProfile.dailyCalorieGoal) * (Double(currentProteinPercentage) / 100.0)
        return Int(caloriesFromProtein / 4.0) // 4 calories per gram of protein
    }
    
    private func calculateCarbGrams() -> Int {
        let caloriesFromCarbs = Double(userProfile.dailyCalorieGoal) * (Double(currentCarbPercentage) / 100.0)
        return Int(caloriesFromCarbs / 4.0) // 4 calories per gram of carbs
    }
    
    private func calculateFatGrams() -> Int {
        let caloriesFromFat = Double(userProfile.dailyCalorieGoal) * (Double(currentFatPercentage) / 100.0)
        return Int(caloriesFromFat / 9.0) // 9 calories per gram of fat
    }
    
    // Computed property for weekly change description
    private var weeklyChangeDescription: String {
        if weeklyChangeAmount < 0 {
            return "Lose Weight"
        } else if weeklyChangeAmount > 0 {
            return "Gain Weight"
        } else {
            return "Maintain Weight"
        }
    }
}

#Preview {
    NavigationStack {
        WeightGoalsView()
    }
}
