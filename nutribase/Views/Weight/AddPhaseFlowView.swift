//
//  AddPhaseFlowView.swift
//  nutribase
//
//  Created on 26/01/2026.
//

import SwiftUI

// MARK: - Phase Template
struct PhaseTemplate: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let iconColor: Color
    let durationWeeks: Int
    let weeklyChangeKg: Double
    let phaseColor: PhaseColor
    var isCustom: Bool = false
    
    static func == (lhs: PhaseTemplate, rhs: PhaseTemplate) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Add Phase Flow Steps
enum AddPhaseFlowStep: Int, CaseIterable {
    case goal = 0
    case startDate = 1
    case planSelection = 2
    case customDetails = 3  // Only shown if custom plan selected
    
    var progress: Double {
        return Double(self.rawValue) / 3.0
    }
}

// MARK: - Add Phase Flow View
struct AddPhaseFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var phaseManager = WeightPhaseManager.shared
    @StateObject private var weightManager = WeightLogManager.shared
    @ObservedObject private var userProfile = UserProfile.shared
    
    // Flow state
    @State private var currentStep: AddPhaseFlowStep = .goal
    @State private var selectedGoal: HealthGoal?
    @State private var availableTemplates: [PhaseTemplate] = []
    @State private var selectedTemplate: PhaseTemplate?
    @State private var visibleTemplateIndex: Int? = 0
    
    // Custom phase details
    @State private var customName: String = ""
    @State private var customStartDate: Date = Date()
    @State private var customEndDate: Date = Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date()
    @State private var customHasEndDate: Bool = true
    @State private var customGoalWeight: String = ""
    @State private var customColor: PhaseColor = .blue
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(hex: "#F0F1F4")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Content
                    TabView(selection: $currentStep) {
                        goalSelectionStep
                            .tag(AddPhaseFlowStep.goal)
                        
                        startDateStep
                            .tag(AddPhaseFlowStep.startDate)
                        
                        planSelectionStep
                            .tag(AddPhaseFlowStep.planSelection)
                        
                        customDetailsStep
                            .tag(AddPhaseFlowStep.customDetails)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                    
                    // Bottom button
                    VStack(spacing: 16) {
                        Button(action: handleContinue) {
                            Text(continueButtonText)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(canContinue ? Color(hex: "#35b8ff") : Color.gray.opacity(0.3))
                                )
                        }
                        .disabled(!canContinue)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#F0F1F4"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep == .goal {
                        Button("Cancel") {
                            dismiss()
                        }
                    } else {
                        Button(action: handleBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Navigation
    
    private var navigationTitle: String {
        switch currentStep {
        case .goal: return "Add Phase"
        case .startDate: return "Start Date"
        case .planSelection: return "Choose Plan"
        case .customDetails: return "Custom Phase"
        }
    }
    
    private var continueButtonText: String {
        switch currentStep {
        case .goal: return "Continue"
        case .startDate: return "Continue"
        case .planSelection:
            if selectedTemplate?.isCustom == true {
                return "Customise"
            }
            return "Create Phase"
        case .customDetails: return "Create Phase"
        }
    }
    
    private var canContinue: Bool {
        switch currentStep {
        case .goal: return selectedGoal != nil
        case .startDate: return true // Date is always valid
        case .planSelection: return selectedTemplate != nil
        case .customDetails: return !customName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
    
    private func handleContinue() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        switch currentStep {
        case .goal:
            withAnimation {
                currentStep = .startDate
            }
            
        case .startDate:
            generateTemplatesForGoal()
            withAnimation {
                currentStep = .planSelection
            }
            
        case .planSelection:
            if let template = selectedTemplate {
                if template.isCustom {
                    // Set defaults for custom phase based on goal
                    setupCustomDefaults()
                    withAnimation {
                        currentStep = .customDetails
                    }
                } else {
                    // Create phase from template
                    createPhaseFromTemplate(template)
                    dismiss()
                }
            }
            
        case .customDetails:
            createCustomPhase()
            dismiss()
        }
    }
    
    private func handleBack() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        withAnimation {
            if currentStep == .customDetails {
                currentStep = .planSelection
            } else if currentStep == .planSelection {
                currentStep = .startDate
            } else if currentStep == .startDate {
                currentStep = .goal
            }
        }
    }
    
    // MARK: - Step 1: Goal Selection
    
    private var goalSelectionStep: some View {
        VStack(spacing: 24) {
            // Title
            VStack(spacing: 8) {
                Text("What's Your Goal?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("We'll suggest the best phases for you")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            
            // Goal cards
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(HealthGoal.allCases) { goal in
                        PhaseGoalCard(
                            goal: goal,
                            isSelected: selectedGoal == goal
                        ) {
                            selectedGoal = goal
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 4) // Prevent border clipping on first card
                .padding(.bottom, 100)
            }
        }
    }
    
    // MARK: - Step 2: Start Date Selection
    
    private var startDateStep: some View {
        VStack(spacing: 24) {
            // Title
            VStack(spacing: 8) {
                Text("When Do You Start?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Choose when your phase begins")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // Custom calendar with phase visualization
            PhaseAwareCalendarView(
                selectedDate: $customStartDate,
                phases: phaseManager.phases
            )
            .padding(.horizontal, 16)
            
            // Quick select buttons
            HStack(spacing: 12) {
                QuickDateButton(title: "Today", isSelected: Calendar.current.isDateInToday(customStartDate)) {
                    customStartDate = Date()
                }
                
                QuickDateButton(title: "Tomorrow", isSelected: Calendar.current.isDateInTomorrow(customStartDate)) {
                    customStartDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                }
                
                QuickDateButton(title: "Next Monday", isSelected: isNextMonday(customStartDate)) {
                    customStartDate = getNextMonday()
                }
            }
            .padding(.horizontal, 24)
            
            // Phase legend (if there are existing phases)
            if !phaseManager.phases.isEmpty {
                phaseLegend
                    .padding(.horizontal, 24)
            }
            
            Spacer()
        }
    }
    
    private var phaseLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Existing Phases")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(phaseManager.phases.sorted(by: { $0.startDate < $1.startDate })) { phase in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(phase.color.swiftUIColor)
                                .frame(width: 10, height: 10)
                            
                            Text(phase.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(phase.color.swiftUIColor.opacity(0.15))
                        )
                    }
                }
            }
        }
    }
    
    // Helper functions for date quick select
    private func isNextMonday(_ date: Date) -> Bool {
        let nextMonday = getNextMonday()
        return Calendar.current.isDate(date, inSameDayAs: nextMonday)
    }
    
    private func getNextMonday() -> Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        // weekday: 1 = Sunday, 2 = Monday, etc.
        let daysUntilMonday = weekday == 1 ? 1 : (9 - weekday)
        return calendar.date(byAdding: .day, value: daysUntilMonday, to: today) ?? today
    }
    
    // MARK: - Step 3: Plan Selection
    
    private var planSelectionStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Title
            VStack(spacing: 8) {
                Text("Choose Your Plan")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Personalised options based on your goal")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            
            // Plan cards carousel
            GeometryReader { geometry in
                let cardWidth = geometry.size.width * 0.75
                let cardSpacing: CGFloat = 16
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: cardSpacing) {
                        ForEach(Array(availableTemplates.enumerated()), id: \.element.id) { index, template in
                            PhaseTemplateCard(
                                template: template,
                                isSelected: selectedTemplate?.id == template.id,
                                currentWeight: getCurrentWeight()
                            ) {
                                selectedTemplate = template
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }
                            .frame(width: cardWidth)
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, (geometry.size.width - cardWidth) / 2, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: Binding(
                    get: { visibleTemplateIndex },
                    set: { newValue in
                        if let newValue = newValue {
                            visibleTemplateIndex = newValue
                            // Auto-select the centered card
                            if newValue < availableTemplates.count {
                                selectedTemplate = availableTemplates[newValue]
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                        }
                    }
                ))
                // Force ScrollView to re-render when goal changes
                .id(selectedGoal?.rawValue ?? "none")
            }
            .frame(height: 380)
            
            // Plan indicator dots
            HStack(spacing: 8) {
                ForEach(0..<availableTemplates.count, id: \.self) { index in
                    Circle()
                        .fill(index == visibleTemplateIndex ? Color(hex: "#35b8ff") : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == visibleTemplateIndex ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: visibleTemplateIndex)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 0)
        .onAppear {
            // Auto-select first template
            if let firstTemplate = availableTemplates.first {
                selectedTemplate = firstTemplate
                visibleTemplateIndex = 0
            }
        }
    }
    
    // MARK: - Step 3: Custom Details
    
    private var customDetailsStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Title
                VStack(spacing: 8) {
                    Text("Customise Your Phase")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Set your own targets and timeline")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 24)
                
                // Phase name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phase Name")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    TextField("e.g. Summer Cut, Lean Bulk", text: $customName)
                        .font(.system(size: 17))
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                        )
                }
                .padding(.horizontal, 24)
                
                // Date range
                VStack(alignment: .leading, spacing: 12) {
                    Text("Timeline")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 0) {
                        // Start date
                        HStack {
                            Text("Start Date")
                                .foregroundColor(.primary)
                            Spacer()
                            DatePicker("", selection: $customStartDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        .padding(16)
                        
                        Divider()
                            .padding(.leading, 16)
                        
                        // End date toggle
                        HStack {
                            Text("Set End Date")
                                .foregroundColor(.primary)
                            Spacer()
                            Toggle("", isOn: $customHasEndDate)
                                .labelsHidden()
                        }
                        .padding(16)
                        
                        if customHasEndDate {
                            Divider()
                                .padding(.leading, 16)
                            
                            HStack {
                                Text("End Date")
                                    .foregroundColor(.primary)
                                Spacer()
                                DatePicker("", selection: $customEndDate, in: customStartDate..., displayedComponents: .date)
                                    .labelsHidden()
                            }
                            .padding(16)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                    )
                }
                .padding(.horizontal, 24)
                
                // Goal weight
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal Weight (Optional)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        if let currentWeight = getCurrentWeight() {
                            Text("Current: \(String(format: "%.1f", currentWeight)) kg")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        TextField("Goal", text: $customGoalWeight)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 17))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        
                        Text("kg")
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                    )
                }
                .padding(.horizontal, 24)
                
                // Color selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Color")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        ForEach(PhaseColor.allCases, id: \.self) { color in
                            Button(action: {
                                customColor = color
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }) {
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: customColor == color ? 3 : 0)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func getCurrentWeight() -> Double? {
        weightManager.allEntries.sorted { $0.date > $1.date }.first?.weight ?? userProfile.weightKg
    }
    
    private func generateTemplatesForGoal() {
        guard let goal = selectedGoal else {
            availableTemplates = []
            return
        }
        
        switch goal {
        case .loseWeight:
            availableTemplates = [
                PhaseTemplate(
                    name: "Gentle Cut",
                    description: "Sustainable fat loss, preserve muscle",
                    icon: "leaf.fill",
                    iconColor: .green,
                    durationWeeks: 16,
                    weeklyChangeKg: -0.25,
                    phaseColor: .pink
                ),
                PhaseTemplate(
                    name: "Moderate Cut",
                    description: "Steady progress with good energy",
                    icon: "flame.fill",
                    iconColor: .orange,
                    durationWeeks: 12,
                    weeklyChangeKg: -0.5,
                    phaseColor: .pink
                ),
                PhaseTemplate(
                    name: "Aggressive Cut",
                    description: "Larger deficit for faster progress",
                    icon: "bolt.fill",
                    iconColor: .red,
                    durationWeeks: 8,
                    weeklyChangeKg: -0.75,
                    phaseColor: .pink
                ),
                PhaseTemplate(
                    name: "Custom Phase",
                    description: "Set your own timeline and targets",
                    icon: "slider.horizontal.3",
                    iconColor: .gray,
                    durationWeeks: 0,
                    weeklyChangeKg: 0,
                    phaseColor: .blue,
                    isCustom: true
                )
            ]
            
        case .buildMuscle:
            availableTemplates = [
                PhaseTemplate(
                    name: "Lean Bulk",
                    description: "Slow, steady muscle gains with minimal fat",
                    icon: "figure.strengthtraining.traditional",
                    iconColor: .blue,
                    durationWeeks: 16,
                    weeklyChangeKg: 0.15,
                    phaseColor: .green
                ),
                PhaseTemplate(
                    name: "Moderate Bulk",
                    description: "Balanced approach for consistent progress",
                    icon: "dumbbell.fill",
                    iconColor: .purple,
                    durationWeeks: 12,
                    weeklyChangeKg: 0.25,
                    phaseColor: .green
                ),
                PhaseTemplate(
                    name: "Aggressive Bulk",
                    description: "Higher surplus for faster weight gain",
                    icon: "bolt.fill",
                    iconColor: .orange,
                    durationWeeks: 8,
                    weeklyChangeKg: 0.4,
                    phaseColor: .green
                ),
                PhaseTemplate(
                    name: "Custom Phase",
                    description: "Set your own timeline and targets",
                    icon: "slider.horizontal.3",
                    iconColor: .gray,
                    durationWeeks: 0,
                    weeklyChangeKg: 0,
                    phaseColor: .blue,
                    isCustom: true
                )
            ]
            
        case .gainWeight:
            availableTemplates = [
                PhaseTemplate(
                    name: "Steady Gain",
                    description: "Gradual weight gain for health",
                    icon: "arrow.up.circle.fill",
                    iconColor: .blue,
                    durationWeeks: 16,
                    weeklyChangeKg: 0.3,
                    phaseColor: .green
                ),
                PhaseTemplate(
                    name: "Moderate Gain",
                    description: "Balanced caloric surplus",
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .purple,
                    durationWeeks: 12,
                    weeklyChangeKg: 0.5,
                    phaseColor: .green
                ),
                PhaseTemplate(
                    name: "Custom Phase",
                    description: "Set your own timeline and targets",
                    icon: "slider.horizontal.3",
                    iconColor: .gray,
                    durationWeeks: 0,
                    weeklyChangeKg: 0,
                    phaseColor: .blue,
                    isCustom: true
                )
            ]
            
        case .maintainWeight:
            availableTemplates = [
                PhaseTemplate(
                    name: "Maintenance",
                    description: "Stay at your current weight",
                    icon: "equal.circle.fill",
                    iconColor: .blue,
                    durationWeeks: 12,
                    weeklyChangeKg: 0,
                    phaseColor: .blue
                ),
                PhaseTemplate(
                    name: "Body Recomp",
                    description: "Build muscle while losing fat",
                    icon: "arrow.triangle.swap",
                    iconColor: .purple,
                    durationWeeks: 12,
                    weeklyChangeKg: 0,
                    phaseColor: .purple
                ),
                PhaseTemplate(
                    name: "Custom Phase",
                    description: "Set your own timeline and targets",
                    icon: "slider.horizontal.3",
                    iconColor: .gray,
                    durationWeeks: 0,
                    weeklyChangeKg: 0,
                    phaseColor: .blue,
                    isCustom: true
                )
            ]
            
        case .improveHealth:
            availableTemplates = [
                PhaseTemplate(
                    name: "Balanced Health",
                    description: "Focus on whole foods & nutrients",
                    icon: "heart.fill",
                    iconColor: .red,
                    durationWeeks: 12,
                    weeklyChangeKg: 0,
                    phaseColor: .pink
                ),
                PhaseTemplate(
                    name: "Active Lifestyle",
                    description: "Support for increased activity",
                    icon: "figure.run",
                    iconColor: .green,
                    durationWeeks: 12,
                    weeklyChangeKg: 0,
                    phaseColor: .green
                ),
                PhaseTemplate(
                    name: "Custom Phase",
                    description: "Set your own timeline and targets",
                    icon: "slider.horizontal.3",
                    iconColor: .gray,
                    durationWeeks: 0,
                    weeklyChangeKg: 0,
                    phaseColor: .blue,
                    isCustom: true
                )
            ]
        }
        
        // Reset selection
        selectedTemplate = availableTemplates.first
        visibleTemplateIndex = 0
    }
    
    private func setupCustomDefaults() {
        // Set name based on goal
        switch selectedGoal {
        case .loseWeight:
            customName = "My Cut"
            customColor = .pink
        case .buildMuscle, .gainWeight:
            customName = "My Bulk"
            customColor = .green
        case .maintainWeight:
            customName = "Maintenance"
            customColor = .blue
        case .improveHealth:
            customName = "Health Focus"
            customColor = .green
        case .none:
            customName = ""
            customColor = .blue
        }
        
        customStartDate = Date()
        customEndDate = Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date()
        customHasEndDate = true
        customGoalWeight = ""
    }
    
    private func createPhaseFromTemplate(_ template: PhaseTemplate) {
        let startDate = customStartDate
        let endDate = Calendar.current.date(byAdding: .weekOfYear, value: template.durationWeeks, to: startDate) ?? startDate
        
        // Calculate goal weight if we have current weight
        var goalWeight: Double? = nil
        if let currentWeight = getCurrentWeight(), template.weeklyChangeKg != 0 {
            let totalChange = template.weeklyChangeKg * Double(template.durationWeeks)
            goalWeight = currentWeight + totalChange
        }
        
        let phase = WeightPhase(
            name: template.name,
            description: template.description,
            startDate: Calendar.current.startOfDay(for: startDate),
            endDate: Calendar.current.startOfDay(for: endDate),
            targetWeeklyRate: template.weeklyChangeKg,
            color: template.phaseColor,
            notes: nil,
            goalWeight: goalWeight,
            isOpenEnded: false
        )
        
        phaseManager.addPhase(phase)
    }
    
    private func createCustomPhase() {
        let effectiveEndDate = customHasEndDate ? customEndDate : getDefaultEndDate()
        
        // Calculate weekly rate from goal weight if provided
        var weeklyRate: Double = 0
        if let goalWeightValue = Double(customGoalWeight),
           goalWeightValue > 0,
           let currentWeight = getCurrentWeight() {
            let weightDifference = goalWeightValue - currentWeight
            let durationWeeks = calculateDurationInWeeks(from: customStartDate, to: effectiveEndDate)
            weeklyRate = durationWeeks > 0 ? weightDifference / durationWeeks : 0
        }
        
        let phase = WeightPhase(
            name: customName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: generateDescription(weeklyRate: weeklyRate),
            startDate: Calendar.current.startOfDay(for: customStartDate),
            endDate: Calendar.current.startOfDay(for: effectiveEndDate),
            targetWeeklyRate: weeklyRate,
            color: customColor,
            notes: nil,
            goalWeight: customGoalWeight.isEmpty ? nil : Double(customGoalWeight),
            isOpenEnded: !customHasEndDate
        )
        
        phaseManager.addPhase(phase)
    }
    
    private func getDefaultEndDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        guard let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.startOfDay(for: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)) else {
            return now
        }
        return endOfMonth
    }
    
    private func calculateDurationInWeeks(from start: Date, to end: Date) -> Double {
        let totalDays = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        return Double(totalDays) / 7.0
    }
    
    private func generateDescription(weeklyRate: Double) -> String {
        if weeklyRate < -0.1 {
            return "Focus on fat loss while maintaining muscle mass"
        } else if weeklyRate > 0.1 {
            return "Build muscle mass with controlled weight gain"
        } else {
            return "Maintain current weight and body composition"
        }
    }
}

// MARK: - Phase Goal Card
struct PhaseGoalCard: View {
    let goal: HealthGoal
    let isSelected: Bool
    let onTap: () -> Void
    
    private var motivationalText: String {
        switch goal {
        case .loseWeight: return "We'll suggest sustainable deficit phases"
        case .gainWeight: return "Phases designed for healthy surplus"
        case .maintainWeight: return "Stay consistent with maintenance phases"
        case .buildMuscle: return "Lean bulk phases for muscle growth"
        case .improveHealth: return "Focus on wellness and balance"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(goal.iconColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: goal.icon)
                        .font(.system(size: 24))
                        .foregroundColor(goal.iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.rawValue)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(motivationalText)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#35b8ff"))
                        .font(.system(size: 24))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color(hex: "#35b8ff") : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Phase Template Card
struct PhaseTemplateCard: View {
    let template: PhaseTemplate
    let isSelected: Bool
    let currentWeight: Double?
    let onTap: () -> Void
    
    private var goalWeight: Double? {
        guard let current = currentWeight, template.weeklyChangeKg != 0, template.durationWeeks > 0 else {
            return nil
        }
        return current + (template.weeklyChangeKg * Double(template.durationWeeks))
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(template.iconColor.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: template.icon)
                        .font(.system(size: 28))
                        .foregroundColor(template.iconColor)
                }
                
                // Title & description
                VStack(spacing: 6) {
                    Text(template.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(template.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                
                if !template.isCustom {
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // Stats
                    VStack(spacing: 12) {
                        // Duration and rate
                        HStack(spacing: 24) {
                            PhaseStatItem(
                                icon: "calendar",
                                value: "\(template.durationWeeks)",
                                label: "weeks",
                                color: .blue
                            )
                            
                            if template.weeklyChangeKg != 0 {
                                PhaseStatItem(
                                    icon: template.weeklyChangeKg > 0 ? "arrow.up.right" : "arrow.down.right",
                                    value: String(format: "%.2fkg", abs(template.weeklyChangeKg)),
                                    label: "/week",
                                    color: template.weeklyChangeKg > 0 ? .green : .orange
                                )
                            }
                        }
                        
                        // Weight projection
                        if let current = currentWeight, let goal = goalWeight {
                            HStack(spacing: 8) {
                                Text(String(format: "%.1fkg", current))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                
                                Text(String(format: "%.1fkg", goal))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(template.phaseColor.swiftUIColor)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(template.phaseColor.swiftUIColor.opacity(0.1))
                            )
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? Color(hex: "#35b8ff") : Color.clear, lineWidth: 3)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Phase Stat Item
struct PhaseStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Quick Date Button
struct QuickDateButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : Color(hex: "#35b8ff"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color(hex: "#35b8ff") : Color(hex: "#35b8ff").opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Phase Aware Calendar View
struct PhaseAwareCalendarView: View {
    @Binding var selectedDate: Date
    let phases: [WeightPhase]
    
    @State private var displayedMonth: Date = Date()
    
    private let calendar = Calendar.current
    private let weekdaySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Month navigation header
            HStack {
                Text(monthFormatter.string(from: displayedMonth))
                    .font(.system(size: 17, weight: .semibold))
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#35b8ff"))
                    }
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#35b8ff"))
                    }
                }
            }
            .padding(.horizontal, 8)
            
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            let days = generateDaysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        dayCell(for: date)
                    } else {
                        Text("")
                            .frame(height: 40)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let phase = getPhase(for: date)
        let dayNumber = calendar.component(.day, from: date)
        
        Button(action: {
            selectedDate = date
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            ZStack {
                // Phase background
                if let phase = phase {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(phase.color.swiftUIColor.opacity(0.3))
                }
                
                // Selection or today indicator
                if isSelected {
                    Circle()
                        .fill(Color(hex: "#35b8ff"))
                        .frame(width: 36, height: 36)
                } else if isToday {
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 36, height: 36)
                }
                
                Text("\(dayNumber)")
                    .font(.system(size: 16, weight: isSelected || isToday ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : (isToday ? .red : .primary))
            }
            .frame(height: 40)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getPhase(for date: Date) -> WeightPhase? {
        for phase in phases {
            let startOfDay = calendar.startOfDay(for: date)
            let phaseStart = calendar.startOfDay(for: phase.startDate)
            
            if phase.isOpenEnded {
                // Open-ended phase extends indefinitely
                if startOfDay >= phaseStart {
                    return phase
                }
            } else {
                let phaseEnd = calendar.startOfDay(for: phase.endDate)
                if startOfDay >= phaseStart && startOfDay <= phaseEnd {
                    return phase
                }
            }
        }
        return nil
    }
    
    private func generateDaysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        
        let firstDayOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        // Convert to Monday-first (1 = Monday, 7 = Sunday)
        let startingSpaces = (firstWeekday == 1) ? 6 : firstWeekday - 2
        
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
        
        var days: [Date?] = []
        
        // Add empty cells for days before the first of the month
        for _ in 0..<startingSpaces {
            days.append(nil)
        }
        
        // Add all days of the month
        for day in 1...daysInMonth {
            if let date = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: displayedMonth),
                month: calendar.component(.month, from: displayedMonth),
                day: day
            )) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
    
    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}

#Preview {
    AddPhaseFlowView()
}
