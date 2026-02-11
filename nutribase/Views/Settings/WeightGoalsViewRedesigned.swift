import SwiftUI

struct WeightGoalsViewRedesigned: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var userProfile = UserProfile.shared
    
    private var viewBackground: Color {
        Color.appBackground
    }
    
    // Expanded state for each card
    @State private var isCalorieGoalExpanded = false
    @State private var isNutritionGoalsExpanded = false
    @State private var isMacroDistributionExpanded = false
    
    // State variables from original view
    @State private var weeklyChangeAmount = 0.0
    @State private var proteinPercentage: Int = UserProfile.shared.proteinPercentage
    @State private var carbPercentage: Int = UserProfile.shared.carbPercentage
    @State private var fatPercentage: Int = UserProfile.shared.fatPercentage
    @State private var dailyCaloriesText: String = ""
    @State private var proteinGramsText: String = ""
    @State private var carbGramsText: String = ""
    @State private var fatGramsText: String = ""
    @State private var caloriesDebounceTimer: Timer?
    @State private var macroDebounceTimer: Timer?
    @State private var calorieGoalMode: CalorieGoalMode = .automatic
    @State private var macroDistributionMode: MacroDistributionMode = .custom
    @State private var macroInputMode: MacroInputMode = .percentages
    @State private var originalProteinPercentage: Int = 0
    @State private var originalCarbPercentage: Int = 0
    @State private var originalFatPercentage: Int = 0
    @State private var originalMacroMode: MacroDistributionMode = .custom
    @State private var displayedCalories: Int = 0
    
    var body: some View {
        ZStack {
            viewBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Calorie Goal Card
                    CollapsibleCard(
                        title: "Weekly Weight Goal",
                        subtitle: calorieGoalMode == .automatic ? "\(weeklyChangeAmount >= 0 ? "+" : "")\(String(format: "%.1f", weeklyChangeAmount)) kg/week, \(displayedCalories) calories" : "Custom calories",
                        isExpanded: $isCalorieGoalExpanded
                    ) {
                        calorieGoalContent
                    }
                    
                    // Nutrition Goals Card
                    CollapsibleCard(
                        title: "Nutrition Goals",
                        subtitle: "Protein, Carbs, Fat",
                        isExpanded: $isNutritionGoalsExpanded
                    ) {
                        nutritionGoalsContent
                    }
                    
                    // Macro Distribution Card
                    CollapsibleCard(
                        title: "Macro Distribution",
                        subtitle: macroDistributionMode == .automatic ? "Automatic" : "Custom",
                        isExpanded: $isMacroDistributionExpanded
                    ) {
                        macroDistributionContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Weight Goals")
        .toolbarBackground(viewBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            loadSettings()
        }
        .onChange(of: weeklyChangeAmount) { _, newValue in
            print("[WeightGoalsView] Slider changed to: \(newValue)")
            print("[WeightGoalsView] Current dailyCalorieGoal BEFORE: \(userProfile.dailyCalorieGoal)")
            
            // Update weight goal type based on direction
            if newValue > 0.05 {
                print("[WeightGoalsView] Setting weightGoalType to .gain")
                userProfile.weightGoalType = .gain
            } else if newValue < -0.05 {
                print("[WeightGoalsView] Setting weightGoalType to .lose")
                userProfile.weightGoalType = .lose
            } else {
                print("[WeightGoalsView] Setting weightGoalType to .maintain")
                userProfile.weightGoalType = .maintain
            }
            print("[WeightGoalsView] Setting weeklyWeightChangeKg to: \(abs(newValue))")
            userProfile.weeklyWeightChangeKg = abs(newValue)
            
            print("[WeightGoalsView] Current dailyCalorieGoal AFTER: \(userProfile.dailyCalorieGoal)")
        }
        .onChange(of: userProfile.dailyCalorieGoal) { oldValue, newValue in
            print("[WeightGoalsView] dailyCalorieGoal changed from \(oldValue) to \(newValue)")
            displayedCalories = newValue
        }
        .onChange(of: calorieGoalMode) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "calorieGoalMode")
        }
        .onChange(of: macroDistributionMode) { _, newValue in
            handleMacroModeChange(newValue)
        }
        .onChange(of: proteinPercentage) { _, _ in
            debouncedMacroUpdate()
        }
        .onChange(of: carbPercentage) { _, _ in
            debouncedMacroUpdate()
        }
        .onChange(of: fatPercentage) { _, _ in
            debouncedMacroUpdate()
        }
    }
    
    // MARK: - Calorie Goal Content
    private var calorieGoalContent: some View {
        VStack(spacing: 16) {
            // Calorie Goal Mode Toggle
            Picker("Calorie Goal Mode", selection: $calorieGoalMode) {
                ForEach(CalorieGoalMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            if calorieGoalMode == .automatic {
                // Automatic mode - Weight goal slider
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
                    
                    Divider()
                    
                    HStack {
                        Text("Calculated Daily Calories:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(displayedCalories)")
                            .font(.title2)
                            .bold()
                    }
                }
            } else {
                // Custom mode - Manual calorie input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Daily Calorie Target")
                        .font(.headline)
                    
                    TextField("Enter calories", text: $dailyCaloriesText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: dailyCaloriesText) { _, newValue in
                            caloriesDebounceTimer?.invalidate()
                            caloriesDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: false) { _ in
                                updateCaloriesAndBalance()
                            }
                        }
                    
                    Text("Enter your desired daily calorie target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Nutrition Goals Content
    private var nutritionGoalsContent: some View {
        VStack(spacing: 12) {
            if userProfile.dailyCalorieGoal > 0 {
                HStack {
                    Text("Protein")
                    Spacer()
                    Text("\(calculateProteinGrams())g (\(currentProteinPercentage)%)")
                        .bold()
                }
                
                Divider()
                
                HStack {
                    Text("Carbohydrates")
                    Spacer()
                    Text("\(calculateCarbGrams())g (\(currentCarbPercentage)%)")
                        .bold()
                }
                
                Divider()
                
                HStack {
                    Text("Fat")
                    Spacer()
                    Text("\(calculateFatGrams())g (\(currentFatPercentage)%)")
                        .bold()
                }
                
                Text("Based on your calorie goal and macro distribution settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            } else {
                Text("Complete your personal information to see nutrition goals")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    // MARK: - Macro Distribution Content
    private var macroDistributionContent: some View {
        VStack(spacing: 16) {
            // Segmented picker for Automatic vs Custom
            Picker("Macro Distribution Mode", selection: $macroDistributionMode) {
                ForEach(MacroDistributionMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            if macroDistributionMode == .custom {
                // Input mode toggle for custom macros
                Picker("Macro Input Mode", selection: $macroInputMode) {
                    ForEach(MacroInputMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                
                if macroInputMode == .percentages {
                    // Percentage-based sliders
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
                        
                        Button("Balance") {
                            balanceMacros()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                } else {
                    // Gram-based inputs
                    VStack(spacing: 12) {
                        HStack {
                            Text("Protein")
                            Spacer()
                            TextField("g", text: $proteinGramsText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Carbohydrates")
                            Spacer()
                            TextField("g", text: $carbGramsText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Fat")
                            Spacer()
                            TextField("g", text: $fatGramsText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            } else {
                // Automatic mode - show current percentages
                VStack(spacing: 12) {
                    HStack {
                        Text("Protein")
                        Spacer()
                        Text("\(currentProteinPercentage)%")
                            .bold()
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Carbohydrates")
                        Spacer()
                        Text("\(currentCarbPercentage)%")
                            .bold()
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Fat")
                        Spacer()
                        Text("\(currentFatPercentage)%")
                            .bold()
                    }
                    
                    Text("Macros are automatically calculated based on your goals")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Helper Functions (from original WeightGoalsView)
    
    private func loadSettings() {
        // Load the weight change with correct sign based on goal type
        let weightChange = userProfile.weeklyWeightChangeKg
        switch userProfile.weightGoalType {
        case .lose:
            weeklyChangeAmount = -weightChange
        case .gain:
            weeklyChangeAmount = weightChange
        case .maintain:
            weeklyChangeAmount = 0
        }
        
        dailyCaloriesText = String(userProfile.dailyCalorieGoal)
        displayedCalories = userProfile.dailyCalorieGoal
        
        if let savedMode = UserDefaults.standard.string(forKey: "calorieGoalMode"),
           let mode = CalorieGoalMode(rawValue: savedMode) {
            calorieGoalMode = mode
        }
        
        if let savedMacroMode = UserDefaults.standard.string(forKey: "macroDistributionMode"),
           let mode = MacroDistributionMode(rawValue: savedMacroMode) {
            macroDistributionMode = mode
            originalMacroMode = mode
        }
        
        if let savedInputMode = UserDefaults.standard.string(forKey: "macroInputMode"),
           let mode = MacroInputMode(rawValue: savedInputMode) {
            macroInputMode = mode
        }
        
        proteinPercentage = userProfile.proteinPercentage
        carbPercentage = userProfile.carbPercentage
        fatPercentage = userProfile.fatPercentage
        
        originalProteinPercentage = proteinPercentage
        originalCarbPercentage = carbPercentage
        originalFatPercentage = fatPercentage
        
        proteinGramsText = String(userProfile.proteinGoalGrams)
        carbGramsText = String(userProfile.carbGoalGrams)
        fatGramsText = String(userProfile.fatGoalGrams)
    }
    
    private var weeklyChangeDescription: String {
        if weeklyChangeAmount < -0.05 {
            return "Lose Weight"
        } else if weeklyChangeAmount > 0.05 {
            return "Gain Weight"
        } else {
            return "Maintain Weight"
        }
    }
    
    private var currentProteinPercentage: Int {
        macroDistributionMode == .custom ? proteinPercentage : userProfile.proteinPercentage
    }
    
    private var currentCarbPercentage: Int {
        macroDistributionMode == .custom ? carbPercentage : userProfile.carbPercentage
    }
    
    private var currentFatPercentage: Int {
        macroDistributionMode == .custom ? fatPercentage : userProfile.fatPercentage
    }
    
    private func calculateProteinGrams() -> Int {
        let percentage = currentProteinPercentage
        return Int(Double(userProfile.dailyCalorieGoal) * Double(percentage) / 100.0 / 4.0)
    }
    
    private func calculateCarbGrams() -> Int {
        let percentage = currentCarbPercentage
        return Int(Double(userProfile.dailyCalorieGoal) * Double(percentage) / 100.0 / 4.0)
    }
    
    private func calculateFatGrams() -> Int {
        let percentage = currentFatPercentage
        return Int(Double(userProfile.dailyCalorieGoal) * Double(percentage) / 100.0 / 9.0)
    }
    
    private func balanceMacros() {
        let total = proteinPercentage + carbPercentage + fatPercentage
        if total != 100 {
            let difference = 100 - total
            carbPercentage += difference
        }
    }
    
    private func debouncedMacroUpdate() {
        macroDebounceTimer?.invalidate()
        macroDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            updateMacrosInProfile()
        }
    }
    
    private func updateMacrosInProfile() {
        if macroDistributionMode == .custom {
            userProfile.proteinPercentage = proteinPercentage
            userProfile.carbPercentage = carbPercentage
            userProfile.fatPercentage = fatPercentage
        }
    }
    
    private func handleMacroModeChange(_ newMode: MacroDistributionMode) {
        UserDefaults.standard.set(newMode.rawValue, forKey: "macroDistributionMode")
        
        if newMode == .automatic {
            // Reset to default automatic distribution
            proteinPercentage = 25
            carbPercentage = 45
            fatPercentage = 30
            
            // Update UserProfile directly
            userProfile.proteinPercentage = proteinPercentage
            userProfile.carbPercentage = carbPercentage
            userProfile.fatPercentage = fatPercentage
        }
    }
    
    private func updateCaloriesAndBalance() {
        if let calories = Int(dailyCaloriesText), calories > 0 {
            userProfile.dailyCalorieGoal = calories
        }
    }
}

// MARK: - Collapsible Card Component
struct CollapsibleCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String
    @Binding var isExpanded: Bool
    let content: () -> Content
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
                .background(Color.appCardBackground)
                .cornerRadius(isExpanded ? 12 : 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded Content
            if isExpanded {
                content()
                    .background(Color.appCardBackground)
                    .cornerRadius(12)
            }
        }
        .background(Color.appCardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}
