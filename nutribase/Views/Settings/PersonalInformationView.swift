import SwiftUI

struct PersonalInformationView: View {
    @StateObject private var userProfile = UserProfile.shared
    @State private var showingHeightPicker = false
    @State private var showingWeightPicker = false
    
    // Temporary state for pickers
    @State private var heightCm = 170.0
    @State private var weightKg = 70.0
    
    var body: some View {
        Form {
            Section(header: Text("Basic Information")) {
                // Age picker
                HStack {
                    Text("Age")
                    Spacer()
                    Picker("Age", selection: $userProfile.age) {
                        ForEach(12...100, id: \.self) { age in
                            Text("\(age) years").tag(age)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                
                // Gender picker
                HStack {
                    Text("Gender")
                    Spacer()
                    Picker("Gender", selection: $userProfile.gender) {
                        ForEach(Gender.allCases) { gender in
                            Text(gender.rawValue).tag(gender)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                
                // Height button that shows sheet
                HStack {
                    Text("Height")
                    Spacer()
                    Button {
                        heightCm = userProfile.heightCm
                        showingHeightPicker = true
                    } label: {
                        Text(formatHeight(userProfile.heightCm))
                            .foregroundColor(.blue)
                    }
                }
                
                // Weight button that shows sheet
                HStack {
                    Text("Weight")
                    Spacer()
                    Button {
                        weightKg = userProfile.weightKg
                        showingWeightPicker = true
                    } label: {
                        Text(formatWeight(userProfile.weightKg))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Section(header: Text("Activity Level")) {
                Picker("Activity Level", selection: $userProfile.activityLevel) {
                    ForEach(ActivityLevel.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.navigationLink)
            }
            
            Section(footer: Text("Your Total Daily Energy Expenditure (TDEE) is calculated based on your personal information and activity level.")) {
                if userProfile.dailyCalorieGoal > 0 {
                    HStack {
                        Text("Estimated TDEE")
                        Spacer()
                        Text("\(userProfile.dailyCalorieGoal) calories")
                            .bold()
                    }
                } else {
                    Button("Calculate TDEE") {
                        userProfile.calculateTDEE()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle("Personal Information")
        .sheet(isPresented: $showingHeightPicker) {
            heightPickerView
        }
        .sheet(isPresented: $showingWeightPicker) {
            weightPickerView
        }
        .onChange(of: userProfile.age) { updateTDEE() }
        .onChange(of: userProfile.gender) { updateTDEE() }
        .onChange(of: userProfile.heightCm) { updateTDEE() }
        .onChange(of: userProfile.weightKg) { updateTDEE() }
        .onChange(of: userProfile.activityLevel) { updateTDEE() }
    }
    
    // Height picker sheet
    var heightPickerView: some View {
        NavigationStack {
            VStack {
                Picker("Height", selection: $heightCm) {
                    ForEach(120...220, id: \.self) { cm in
                        Text(formatHeight(Double(cm))).tag(Double(cm))
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
            .navigationTitle("Select Height")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingHeightPicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        userProfile.heightCm = heightCm
                        showingHeightPicker = false
                    }
                }
            }
        }
        .presentationDetents([.height(250)])
    }
    
    // Weight picker sheet
    var weightPickerView: some View {
        NavigationStack {
            VStack {
                Picker("Weight", selection: $weightKg) {
                    ForEach(Array(stride(from: 40.0, through: 150.0, by: 0.5)), id: \.self) { kg in
                        Text(formatWeight(kg)).tag(kg)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
            .navigationTitle("Select Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingWeightPicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        userProfile.weightKg = weightKg
                        showingWeightPicker = false
                    }
                }
            }
        }
        .presentationDetents([.height(250)])
    }
    
    // Helper functions
    private func formatHeight(_ cm: Double) -> String {
        let feet = Int(cm / 30.48)
        let inches = Int((cm.truncatingRemainder(dividingBy: 30.48)) / 2.54)
        return "\(feet)'\(inches)\" (\(Int(cm)) cm)"
    }
    
    private func formatWeight(_ kg: Double) -> String {
        let lbs = kg * 2.20462
        return String(format: "%.1f kg (%.1f lbs)", kg, lbs)
    }
    
    private func updateTDEE() {
        if userProfile.age > 0 && userProfile.heightCm > 0 && userProfile.weightKg > 0 && userProfile.gender != .notSpecified {
            userProfile.calculateTDEE()
        }
    }
}

#Preview {
    NavigationStack {
        PersonalInformationView()
    }
}
