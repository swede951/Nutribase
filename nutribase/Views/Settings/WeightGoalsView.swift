import SwiftUI

enum MacroDistributionMode: String, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case custom = "Custom"
    
    var id: String { self.rawValue }
}

enum CalorieGoalMode: String, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case custom = "Custom"
    
    var id: String { self.rawValue }
}

enum MacroInputMode: String, CaseIterable, Identifiable {
    case percentages = "Percentages"
    case grams = "Grams"
    
    var id: String { self.rawValue }
}

struct WeightGoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userProfile = UserProfile.shared
    @State private var weeklyChangeAmount: Double
    
    init() {
        // Initialize all state from UserProfile to ensure sync
        _weeklyChangeAmount = State(initialValue: UserProfile.shared.weeklyWeightChangeKg)
        _proteinPercentage = State(initialValue: UserProfile.shared.proteinPercentage)
        _carbPercentage = State(initialValue: UserProfile.shared.carbPercentage)
        _fatPercentage = State(initialValue: UserProfile.shared.fatPercentage)
        _calorieGoalMode = State(initialValue: UserProfile.shared.useCustomCalorieGoal ? .custom : .automatic)
        _dailyCaloriesText = State(initialValue: "\(UserProfile.shared.dailyCalorieGoal)")
        
        // Load persisted modes from UserDefaults
        let savedModeString = UserDefaults.standard.string(forKey: "macroDistributionMode") ?? "custom"
        _macroDistributionMode = State(initialValue: MacroDistributionMode(rawValue: savedModeString.capitalized) ?? .custom)
        
        let savedInputModeString = UserDefaults.standard.string(forKey: "macroInputMode") ?? "percentages"
        _macroInputMode = State(initialValue: MacroInputMode(rawValue: savedInputModeString.capitalized) ?? .percentages)
    }
    
    // Local state for macro percentages to prevent UI freezes
    @State private var proteinPercentage: Int
    @State private var carbPercentage: Int
    @State private var fatPercentage: Int
    
    // Local state for editable nutrition values
    @State private var dailyCaloriesText: String
    @State private var proteinGramsText: String = ""
    @State private var carbGramsText: String = ""
    @State private var fatGramsText: String = ""
    
    // Debouncing timers
    @State private var caloriesDebounceTimer: Timer?
    @State private var macroDebounceTimer: Timer?
    
    // Calorie goal mode - persisted in UserDefaults
    @State private var calorieGoalMode: CalorieGoalMode
    
    // Macro distribution mode - persisted in UserDefaults
    @State private var macroDistributionMode: MacroDistributionMode
    
    // Macro input mode - persisted in UserDefaults
    @State private var macroInputMode: MacroInputMode
    
    // Track original values to detect changes
    @State private var originalProteinPercentage: Int = 0
    @State private var originalCarbPercentage: Int = 0
    @State private var originalFatPercentage: Int = 0
    @State private var originalMacroMode: MacroDistributionMode = .custom
    @State private var originalDailyCalories: Int = 0
    @State private var originalWeeklyChange: Double = 0.0
    @State private var originalCalorieMode: CalorieGoalMode = .automatic
    
    // Save state
    @State private var showUnsavedChangesAlert = false
    @State private var showSaveConfirmation = false
    @State private var isSaving = false
    
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
                    VStack(spacing: 16) {
                    // Calorie Goal Mode Toggle
                    Picker("Calorie Goal Mode", selection: $calorieGoalMode) {
                        ForEach(CalorieGoalMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: calorieGoalMode) { oldValue, newValue in
                        // Just track mode change - actual UserProfile update happens on Save
                    }
                    
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
                            .onChange(of: weeklyChangeAmount) { oldValue, newValue in
                                // Just track the change - don't update UserProfile until Save
                                // The calculated value will be shown via computed property
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
                            
                            // Show calculated calories
                            HStack {
                                Text("Calculated Daily Calories:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(calculatedCalorieGoal)")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.primary)
                            }
                            .padding(.top, 8)
                        }
                    } else {
                        // Custom mode - Manual calorie input
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Custom Daily Calories")
                                .font(.headline)
                            
                            HStack {
                                Text("Daily Calories")
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                TextField("", text: $dailyCaloriesText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 100)
                                    .onChange(of: dailyCaloriesText) { oldValue, newValue in
                                        // Cancel previous timer
                                        caloriesDebounceTimer?.invalidate()
                                        
                                        // Start new timer with 0.75 second delay
                                        caloriesDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: false) { _ in
                                            updateCaloriesAndBalance()
                                        }
                                    }
                            }
                            
                            Text("Enter your desired daily calorie target")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Calorie Goal")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                        //.padding(.leading, 14)
                        .textCase(nil)
                }
            
            Section {
                if userProfile.dailyCalorieGoal > 0 {
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
            } header: {
                Text("Nutrition Goals")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                    //.padding(.leading, 14)
                    .textCase(nil)
            } footer: {
                Text("Based on your calorie goal and macro distribution settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                // Segmented picker for Automatic vs Custom
                Picker("Macro Distribution Mode", selection: $macroDistributionMode) {
                    ForEach(MacroDistributionMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 8)
                
                if macroDistributionMode == .custom {
                    // Input mode toggle for custom macros
                    Picker("Macro Input Mode", selection: $macroInputMode) {
                        ForEach(MacroInputMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 8)
                    
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
                        // Gram-based input fields
                        VStack(spacing: 12) {
                            HStack {
                                Text("Protein")
                                Spacer()
                                HStack(spacing: 4) {
                                    TextField("", text: $proteinGramsText)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 60)
                                        .onChange(of: proteinGramsText) { oldValue, newValue in
                                            debounceMacroGramUpdate()
                                        }
                                    Text("g")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack {
                                Text("Carbohydrates")
                                Spacer()
                                HStack(spacing: 4) {
                                    TextField("", text: $carbGramsText)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 60)
                                        .onChange(of: carbGramsText) { oldValue, newValue in
                                            debounceMacroGramUpdate()
                                        }
                                    Text("g")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack {
                                Text("Fat")
                                Spacer()
                                HStack(spacing: 4) {
                                    TextField("", text: $fatGramsText)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 60)
                                        .onChange(of: fatGramsText) { oldValue, newValue in
                                            debounceMacroGramUpdate()
                                        }
                                    Text("g")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Show total calories from macros
                            HStack {
                                Text("Total from macros: \(calculateTotalCaloriesFromGrams()) cal")
                                    .font(.caption)
                                    .foregroundColor(abs(calculateTotalCaloriesFromGrams() - userProfile.dailyCalorieGoal) <= 50 ? .green : .orange)
                                
                                Spacer()
                                
                                if abs(calculateTotalCaloriesFromGrams() - userProfile.dailyCalorieGoal) > 50 {
                                    Button("Balance") {
                                        balanceMacroGrams()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                            }
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
            } header: {
                Text("Macro Distribution")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                    //.padding(.leading, 8)
                    .textCase(nil)
            }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Weight Goals")
        .toolbarBackground(viewBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(hasUnsavedChanges)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if hasUnsavedChanges {
                    Button(action: {
                        showUnsavedChangesAlert = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Goals")
                        }
                        .foregroundColor(Color(hex: "#35b8ff"))
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: saveChanges) {
                    if isSaving {
                        ProgressView()
                            .tint(Color(hex: "#35b8ff"))
                    } else {
                        Text("Save")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(hasUnsavedChanges ? Color(hex: "#35b8ff") : .gray)
                    }
                }
                .disabled(!hasUnsavedChanges || isSaving)
            }
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Save", role: .none) {
                saveChanges()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Would you like to save them before leaving?")
        }
        .overlay {
            if showSaveConfirmation {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Changes saved")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    )
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            // Initialize weekly change amount from user profile (preserve sign)
            weeklyChangeAmount = userProfile.weeklyWeightChangeKg
            
            // Initialize macro percentages from user profile
            proteinPercentage = userProfile.proteinPercentage
            carbPercentage = userProfile.carbPercentage
            fatPercentage = userProfile.fatPercentage
            
            // Initialize text fields with current values
            dailyCaloriesText = "\(userProfile.dailyCalorieGoal)"
            proteinGramsText = "\(calculateProteinGrams())"
            carbGramsText = "\(calculateCarbGrams())"
            fatGramsText = "\(calculateFatGrams())"
            
            // Store original values to track changes
            originalProteinPercentage = userProfile.proteinPercentage
            originalCarbPercentage = userProfile.carbPercentage
            originalFatPercentage = userProfile.fatPercentage
            originalDailyCalories = userProfile.dailyCalorieGoal
            originalWeeklyChange = userProfile.weeklyWeightChangeKg
            
            // Initialize calorie goal mode from UserProfile's useCustomCalorieGoal flag
            calorieGoalMode = userProfile.useCustomCalorieGoal ? .custom : .automatic
            originalCalorieMode = calorieGoalMode
            
            // If in automatic mode, trigger recalculation with current weekly change
            if calorieGoalMode == .automatic {
                userProfile.recalculateCalorieGoal()
            }
            
            // Load persisted macro distribution mode
            let savedModeString = UserDefaults.standard.string(forKey: "macroDistributionMode") ?? "custom"
            macroDistributionMode = MacroDistributionMode(rawValue: savedModeString.capitalized) ?? .custom
            originalMacroMode = macroDistributionMode
            
            // Load persisted macro input mode
            let savedInputModeString = UserDefaults.standard.string(forKey: "macroInputMode") ?? "percentages"
            macroInputMode = MacroInputMode(rawValue: savedInputModeString.capitalized) ?? .percentages
        }
        .onChange(of: weeklyChangeAmount) { oldValue, newValue in
            // Don't auto-save - just track the change for hasUnsavedChanges
            // The actual save happens when user taps Save button
        }
        .onChange(of: calorieGoalMode) { oldValue, newValue in
            // Persist calorie goal mode
            UserDefaults.standard.set(newValue.rawValue.lowercased(), forKey: "calorieGoalMode")
        }
        .onChange(of: macroDistributionMode) { oldValue, newValue in
            // Persist macro distribution mode
            UserDefaults.standard.set(newValue.rawValue.lowercased(), forKey: "macroDistributionMode")
        }
        .onChange(of: macroInputMode) { oldValue, newValue in
            // Persist macro input mode
            UserDefaults.standard.set(newValue.rawValue.lowercased(), forKey: "macroInputMode")
        }
        .onDisappear {
            // Clean up timers when view disappears
            caloriesDebounceTimer?.invalidate()
            macroDebounceTimer?.invalidate()
        }
    }
    
    // Computed property to check if any changes have been made (for macro apply button)
    private var hasChanges: Bool {
        return macroDistributionMode != originalMacroMode ||
               carbPercentage != originalCarbPercentage ||
               fatPercentage != originalFatPercentage
    }
    
    // Computed property to check if there are any unsaved changes (for Save button and warning)
    private var hasUnsavedChanges: Bool {
        let caloriesChanged = (Int(dailyCaloriesText) ?? originalDailyCalories) != originalDailyCalories
        let weeklyChanged = weeklyChangeAmount != originalWeeklyChange
        let calorieModeChanged = calorieGoalMode != originalCalorieMode
        let macrosChanged = proteinPercentage != originalProteinPercentage ||
                           carbPercentage != originalCarbPercentage ||
                           fatPercentage != originalFatPercentage
        let macroModeChanged = macroDistributionMode != originalMacroMode
        
        return caloriesChanged || weeklyChanged || calorieModeChanged || macrosChanged || macroModeChanged
    }
    
    // MARK: - Save Changes
    private func saveChanges() {
        isSaving = true
        
        // Save calorie goal
        if calorieGoalMode == .custom {
            if let calories = Int(dailyCaloriesText), calories > 0 {
                userProfile.useCustomCalorieGoal = true
                userProfile.dailyCalorieGoal = calories
            }
        } else {
            // If automatic mode, update weekly change and recalculate
            userProfile.useCustomCalorieGoal = false
            userProfile.weeklyWeightChangeKg = weeklyChangeAmount
            userProfile.recalculateCalorieGoal()
        }
        
        // Save weekly change (for automatic mode)
        userProfile.weeklyWeightChangeKg = weeklyChangeAmount
        
        // Update weight goal type based on the sign
        if weeklyChangeAmount < 0 {
            userProfile.weightGoalType = .lose
        } else if weeklyChangeAmount > 0 {
            userProfile.weightGoalType = .gain
        } else {
            userProfile.weightGoalType = .maintain
        }
        
        // Save macro distribution
        if macroDistributionMode == .automatic {
            userProfile.proteinPercentage = 20
            userProfile.carbPercentage = 50
            userProfile.fatPercentage = 30
        } else {
            userProfile.proteinPercentage = proteinPercentage
            userProfile.carbPercentage = carbPercentage
            userProfile.fatPercentage = fatPercentage
        }
        
        // Calculate and save gram goals based on percentages
        let calories = userProfile.dailyCalorieGoal
        userProfile.proteinGoalGrams = Int(Double(calories) * Double(userProfile.proteinPercentage) / 100.0 / 4.0)
        userProfile.carbGoalGrams = Int(Double(calories) * Double(userProfile.carbPercentage) / 100.0 / 4.0)
        userProfile.fatGoalGrams = Int(Double(calories) * Double(userProfile.fatPercentage) / 100.0 / 9.0)
        
        // Persist mode settings
        UserDefaults.standard.set(calorieGoalMode.rawValue.lowercased(), forKey: "calorieGoalMode")
        UserDefaults.standard.set(macroDistributionMode.rawValue.lowercased(), forKey: "macroDistributionMode")
        
        // Post notification to update dashboard cards
        NotificationCenter.default.post(name: NSNotification.Name("UserProfileDidUpdate"), object: nil)
        
        // Save to Firebase (only happens on explicit save button press)
        userProfile.saveToFirebase()
        
        // Update original values to reflect saved state
        originalDailyCalories = userProfile.dailyCalorieGoal
        originalWeeklyChange = weeklyChangeAmount
        originalCalorieMode = calorieGoalMode
        originalProteinPercentage = userProfile.proteinPercentage
        originalCarbPercentage = userProfile.carbPercentage
        originalFatPercentage = userProfile.fatPercentage
        originalMacroMode = macroDistributionMode
        
        // Update local state to match saved values
        proteinPercentage = userProfile.proteinPercentage
        carbPercentage = userProfile.carbPercentage
        fatPercentage = userProfile.fatPercentage
        
        // Show save confirmation
        isSaving = false
        withAnimation(.spring(response: 0.4)) {
            showSaveConfirmation = true
        }
        
        // Hide confirmation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showSaveConfirmation = false
            }
        }
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        print("✅ Weight goals saved: Calories=\(userProfile.dailyCalorieGoal), P=\(userProfile.proteinGoalGrams)g, C=\(userProfile.carbGoalGrams)g, F=\(userProfile.fatGoalGrams)g")
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
    
    // Computed property for calculated calorie goal based on current slider position
    private var calculatedCalorieGoal: Int {
        let calculatedTDEE = max(userProfile.calculateTDEEOnly(), 1500)
        var newCalorieGoal = calculatedTDEE
        
        if abs(weeklyChangeAmount) >= 0.01 {
            let safeWeeklyChange = max(min(abs(weeklyChangeAmount), 1.0), 0.1)
            let calorieAdjustment = Int(safeWeeklyChange * 7700 / 7)
            
            if weeklyChangeAmount < 0 {
                newCalorieGoal = calculatedTDEE - calorieAdjustment
            } else if weeklyChangeAmount > 0 {
                newCalorieGoal = calculatedTDEE + calorieAdjustment
            }
        }
        
        return max(newCalorieGoal, 1200)
    }
    
    // MARK: - Nutrition Input Handling
    
    // Debounce macro updates to avoid excessive calculations
    private func debounceMacroUpdate() {
        // Cancel previous timer
        macroDebounceTimer?.invalidate()
        
        // Start new timer with 0.75 second delay
        macroDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: false) { _ in
            updateMacroFromGrams()
        }
    }
    
    // Debounce macro gram updates for the new gram input mode
    private func debounceMacroGramUpdate() {
        // Cancel previous timer
        macroDebounceTimer?.invalidate()
        
        // Start new timer with 0.75 second delay
        macroDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: false) { _ in
            updateMacroFromGramInputs()
        }
    }
    
    // Update calories and automatically balance macros based on current percentages
    private func updateCaloriesAndBalance() {
        // Allow empty fields - don't auto-reset
        guard !dailyCaloriesText.isEmpty else { return }
        
        guard let newCalories = Int(dailyCaloriesText), newCalories > 0 else {
            // Don't auto-reset invalid values - let user fix them
            return
        }
        
        // Update the daily calorie goal
        userProfile.dailyCalorieGoal = newCalories
        
        // Only update macro grams if they're currently empty (not being edited)
        if proteinGramsText.isEmpty {
            proteinGramsText = "\(calculateProteinGrams())"
        }
        if carbGramsText.isEmpty {
            carbGramsText = "\(calculateCarbGrams())"
        }
        if fatGramsText.isEmpty {
            fatGramsText = "\(calculateFatGrams())"
        }
    }
    
    // Update macro percentages based on gram inputs
    private func updateMacroFromGrams() {
        // Allow empty fields - don't auto-reset
        guard !dailyCaloriesText.isEmpty else { return }
        
        guard let calories = Int(dailyCaloriesText), calories > 0 else {
            // Don't auto-reset invalid values - let user fix them
            return
        }
        
        // Only calculate if we have valid gram inputs (allow some to be empty)
        let proteinGrams = Int(proteinGramsText) ?? 0
        let carbGrams = Int(carbGramsText) ?? 0
        let fatGrams = Int(fatGramsText) ?? 0
        
        // Skip calculation if all fields are empty
        if proteinGrams == 0 && carbGrams == 0 && fatGrams == 0 { return }
        
        // Calculate calories from each macro
        let proteinCalories = proteinGrams * 4
        let carbCalories = carbGrams * 4
        let fatCalories = fatGrams * 9
        
        // Calculate percentages
        let totalCalories = Double(calories)
        let newProteinPercentage = Int(round(Double(proteinCalories) / totalCalories * 100))
        let newCarbPercentage = Int(round(Double(carbCalories) / totalCalories * 100))
        let newFatPercentage = Int(round(Double(fatCalories) / totalCalories * 100))
        
        // Update percentages
        proteinPercentage = max(10, min(60, newProteinPercentage))
        carbPercentage = max(10, min(70, newCarbPercentage))
        fatPercentage = max(10, min(60, newFatPercentage))
        
        // Switch to custom mode when manually adjusting
        macroDistributionMode = .custom
    }
    
    // Update macro percentages based on gram inputs (for gram input mode)
    private func updateMacroFromGramInputs() {
        // Allow empty fields - don't auto-reset
        guard !dailyCaloriesText.isEmpty else { return }
        
        guard let calories = Int(dailyCaloriesText), calories > 0 else {
            // Don't auto-reset invalid values - let user fix them
            return
        }
        
        // Only calculate if we have valid gram inputs (allow some to be empty)
        let proteinGrams = Int(proteinGramsText) ?? 0
        let carbGrams = Int(carbGramsText) ?? 0
        let fatGrams = Int(fatGramsText) ?? 0
        
        // Skip calculation if all fields are empty
        if proteinGrams == 0 && carbGrams == 0 && fatGrams == 0 { return }
        
        // Calculate calories from each macro
        let proteinCalories = proteinGrams * 4
        let carbCalories = carbGrams * 4
        let fatCalories = fatGrams * 9
        
        // Calculate percentages
        let totalCalories = Double(calories)
        let newProteinPercentage = Int(round(Double(proteinCalories) / totalCalories * 100))
        let newCarbPercentage = Int(round(Double(carbCalories) / totalCalories * 100))
        let newFatPercentage = Int(round(Double(fatCalories) / totalCalories * 100))
        
        // Update percentages (with reasonable bounds)
        proteinPercentage = max(5, min(80, newProteinPercentage))
        carbPercentage = max(5, min(80, newCarbPercentage))
        fatPercentage = max(5, min(80, newFatPercentage))
    }
    
    // Calculate total calories from current gram inputs
    private func calculateTotalCaloriesFromGrams() -> Int {
        let proteinGrams = Int(proteinGramsText) ?? calculateProteinGrams()
        let carbGrams = Int(carbGramsText) ?? calculateCarbGrams()
        let fatGrams = Int(fatGramsText) ?? calculateFatGrams()
        
        return (proteinGrams * 4) + (carbGrams * 4) + (fatGrams * 9)
    }
    
    // Balance macro grams to match target calories
    private func balanceMacroGrams() {
        let targetCalories = userProfile.dailyCalorieGoal
        let currentProteinGrams = Int(proteinGramsText) ?? calculateProteinGrams()
        let currentCarbGrams = Int(carbGramsText) ?? calculateCarbGrams()
        let currentFatGrams = Int(fatGramsText) ?? calculateFatGrams()
        
        // Calculate current calories
        let currentCalories = (currentProteinGrams * 4) + (currentCarbGrams * 4) + (currentFatGrams * 9)
        let difference = targetCalories - currentCalories
        
        if abs(difference) <= 50 { return } // Close enough
        
        // Adjust carbs first (most flexible macro)
        let carbAdjustment = difference / 4
        let newCarbGrams = max(20, currentCarbGrams + carbAdjustment) // Minimum 20g carbs
        
        carbGramsText = "\(newCarbGrams)"
        
        // Update percentages
        updateMacroFromGramInputs()
    }
}

#Preview {
    NavigationStack {
        WeightGoalsView()
    }
}
