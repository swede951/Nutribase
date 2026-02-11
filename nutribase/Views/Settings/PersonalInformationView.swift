import SwiftUI

struct PersonalInformationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var userProfile = UserProfile.shared
    @State private var showingHeightPicker = false
    @State private var showingWeightPicker = false
    
    private var viewBackground: Color {
        Color.appBackground
    }
    
    // Temporary state for pickers
    @State private var heightCm = 170.0
    @State private var weightKg = 70.0
    @State private var weightInputText = ""
    @State private var weightUnit: WeightUnit = .kg
    
    enum WeightUnit: String, CaseIterable {
        case kg = "kg"
        case lbs = "lbs"
    }
    
    let availableRegions = ["All Regions", "United Kingdom", "United States", "France", "Germany", "Italy", "Spain", "Netherlands", "Belgium", "Switzerland", "Australia", "Canada", "New Zealand", "Ireland", "Norway", "Sweden", "Denmark"]
    
    var body: some View {
        ZStack {
            viewBackground
                .ignoresSafeArea()
            
        Form {
            Section(header: Text("Basic Information")) {
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
                .listRowBackground(Color.appCardBackground)
                
                // Date of Birth picker
                DatePicker(
                    "Date of Birth",
                    selection: $userProfile.dateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .listRowBackground(Color.appCardBackground)
                
                // Age display (computed from DOB)
                HStack {
                    Text("Age")
                    Spacer()
                    Text("\(userProfile.age) years")
                        .foregroundColor(.secondary)
                }
                .listRowBackground(Color.appCardBackground)
                
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
                .listRowBackground(Color.appCardBackground)
                
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
                .listRowBackground(Color.appCardBackground)
                
                // Preferred Region picker
                HStack {
                    Text("Preferred Region")
                    Spacer()
                    Picker("Region", selection: $userProfile.preferredRegion) {
                        ForEach(availableRegions, id: \.self) { region in
                            Text(region).tag(region)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .listRowBackground(Color.appCardBackground)
            }
            
            Section(header: Text("Activity Level")) {
                Picker("Activity Level", selection: $userProfile.activityLevel) {
                    ForEach(ActivityLevel.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.navigationLink)
                .listRowBackground(Color.appCardBackground)
            }
        }
        .scrollContentBackground(.hidden)
        }
        .navigationTitle("Personal Information")
        .toolbarBackground(viewBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(120...220, id: \.self) { cm in
                            Button {
                                heightCm = Double(cm)
                            } label: {
                                Text(formatHeight(Double(cm)))
                                    .font(.title3)
                                    .foregroundColor(Int(heightCm) == cm ? .blue : .primary)
                                    .fontWeight(Int(heightCm) == cm ? .semibold : .regular)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Int(heightCm) == cm ? Color.blue.opacity(0.1) : Color.clear)
                                    .cornerRadius(8)
                            }
                            .id(cm)
                        }
                    }
                    .padding(.horizontal)
                }
                .onAppear {
                    // Scroll to current height with animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(Int(heightCm), anchor: .center)
                        }
                    }
                }
            }
            .navigationTitle("Select Height")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingHeightPicker = false
                    }
                    .foregroundColor(.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        userProfile.heightCm = heightCm
                        showingHeightPicker = false
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // Weight picker sheet with text input and unit toggle
    var weightPickerView: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Unit toggle
                Picker("Unit", selection: $weightUnit) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .onChange(of: weightUnit) { oldValue, newValue in
                    // Convert the current input value when switching units
                    if let currentValue = Double(weightInputText) {
                        if newValue == .lbs && oldValue == .kg {
                            // Converting from kg to lbs
                            weightInputText = String(format: "%.1f", currentValue * 2.20462)
                        } else if newValue == .kg && oldValue == .lbs {
                            // Converting from lbs to kg
                            weightInputText = String(format: "%.1f", currentValue / 2.20462)
                        }
                    }
                }
                
                // Weight input
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField(weightUnit == .kg ? "70.0" : "154.0", text: $weightInputText)
                            .font(.system(size: 48, weight: .medium))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 180)
                        
                        Text(weightUnit.rawValue)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Show converted value
                    if let inputValue = Double(weightInputText), inputValue > 0 {
                        Text(weightUnit == .kg 
                             ? String(format: "%.1f lbs", inputValue * 2.20462)
                             : String(format: "%.1f kg", inputValue / 2.20462))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .navigationTitle("Enter Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingWeightPicker = false
                    }
                    .foregroundColor(.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveWeight()
                    }
                    .foregroundColor(.primary)
                    .disabled(!isValidWeight)
                }
            }
            .onAppear {
                // Initialize with current weight in selected unit
                if weightUnit == .kg {
                    weightInputText = String(format: "%.1f", weightKg)
                } else {
                    weightInputText = String(format: "%.1f", weightKg * 2.20462)
                }
            }
        }
        .presentationDetents([.height(280)])
    }
    
    // Validate weight input
    private var isValidWeight: Bool {
        guard let value = Double(weightInputText) else { return false }
        if weightUnit == .kg {
            return value >= 30.0 && value <= 300.0
        } else {
            return value >= 66.0 && value <= 660.0
        }
    }
    
    // Save weight in kg
    private func saveWeight() {
        guard let value = Double(weightInputText) else { return }
        
        if weightUnit == .kg {
            userProfile.weightKg = value
        } else {
            // Convert lbs to kg
            userProfile.weightKg = value / 2.20462
        }
        showingWeightPicker = false
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
