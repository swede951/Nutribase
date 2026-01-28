import SwiftUI

// MARK: - HealthGoal Enum
enum HealthGoal: String, CaseIterable, Identifiable {
    case loseWeight = "Lose Weight"
    case maintainWeight = "Maintain Weight"
    case buildMuscle = "Build Muscle"
    case gainWeight = "Gain Weight"
    case improveHealth = "Improve Health"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .loseWeight:
            return "arrow.down.circle.fill"
        case .gainWeight:
            return "arrow.up.circle.fill"
        case .maintainWeight:
            return "equal.circle.fill"
        case .buildMuscle:
            return "figure.strengthtraining.traditional"
        case .improveHealth:
            return "heart.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .loseWeight:
            return .red
        case .gainWeight:
            return .green
        case .maintainWeight:
            return .blue
        case .buildMuscle:
            return .orange
        case .improveHealth:
            return .pink
        }
    }
    
    var description: String {
        switch self {
        case .loseWeight:
            return "Reduce body weight through caloric deficit"
        case .gainWeight:
            return "Increase body weight through caloric surplus"
        case .maintainWeight:
            return "Keep current weight stable"
        case .buildMuscle:
            return "Gain lean muscle mass with proper nutrition"
        case .improveHealth:
            return "Focus on overall health and wellness"
        }
    }
    
    var calorieModifier: Double {
        switch self {
        case .loseWeight:
            return -0.2 // 20% deficit
        case .gainWeight:
            return 0.15 // 15% surplus
        case .maintainWeight:
            return 0.0 // No change
        case .buildMuscle:
            return 0.1 // 10% surplus
        case .improveHealth:
            return 0.0 // Maintenance
        }
    }
}

// MARK: - ActivityLevel Extension for UI
extension ActivityLevel {
    var icon: String {
        switch self {
        case .sedentary: return "bed.double"
        case .lightlyActive: return "figure.walk"
        case .moderate: return "figure.run"
        case .veryActive: return "figure.strengthtraining.traditional"
        case .extraActive: return "bolt.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .sedentary: return .gray
        case .lightlyActive: return .blue
        case .moderate: return .green
        case .veryActive: return .orange
        case .extraActive: return .red
        }
    }
    
    var shortDescription: String {
        switch self {
        case .sedentary: return "Little to no exercise, desk job"
        case .lightlyActive: return "Light exercise 1-3 days/week"
        case .moderate: return "Moderate exercise 3-5 days/week"
        case .veryActive: return "Hard exercise 6-7 days/week"
        case .extraActive: return "Very hard exercise, physical job"
        }
    }
}

// MARK: - TrackingMetric Enum for Dashboard Customization
enum TrackingMetric: String, CaseIterable, Identifiable {
    case calories = "Calories"
    case protein = "Protein"
    case carbs = "Carbohydrates"
    case fat = "Fat"
    case fiber = "Fiber"
    case sugar = "Sugar"
    case sodium = "Sodium"
    case novaScore = "NOVA Score"
    case nutriScore = "Nutri-Score"
    case steps = "Steps"
    case weight = "Weight"
    // case water = "Water Intake" // TEMPORARILY DISABLED
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .calories: return "flame.fill"
        case .protein: return "p.circle.fill"
        case .carbs: return "c.circle.fill"
        case .fat: return "f.circle.fill"
        case .fiber: return "leaf.fill"
        case .sugar: return "s.circle.fill"
        case .sodium: return "drop.fill"
        case .novaScore: return "star.circle.fill"
        case .nutriScore: return "checkmark.seal.fill"
        case .steps: return "figure.walk.circle.fill"
        case .weight: return "scalemass.fill"
        // case .water: return "drop.circle.fill" // TEMPORARILY DISABLED
        }
    }
    
    var iconColor: Color {
        switch self {
        case .calories: return .orange
        case .protein: return .red
        case .carbs: return .blue
        case .fat: return .yellow
        case .fiber: return .green
        case .sugar: return .pink
        case .sodium: return .purple
        case .novaScore: return .indigo
        case .nutriScore: return .mint
        case .steps: return .cyan
        case .weight: return .brown
        // case .water: return .blue // TEMPORARILY DISABLED
        }
    }
    
    var description: String {
        switch self {
        case .calories: return "Daily calorie intake and goals"
        case .protein: return "Protein intake and targets"
        case .carbs: return "Carbohydrate consumption"
        case .fat: return "Fat intake tracking"
        case .fiber: return "Dietary fiber monitoring"
        case .sugar: return "Sugar consumption tracking"
        case .sodium: return "Sodium intake monitoring"
        case .novaScore: return "Food processing level (NOVA)"
        case .nutriScore: return "Overall nutrition quality"
        case .steps: return "Daily step count and activity"
        case .weight: return "Weight tracking and trends"
        // case .water: return "Daily hydration tracking" // TEMPORARILY DISABLED
        }
    }
    
    var category: TrackingMetricCategory {
        switch self {
        case .calories, .protein, .carbs, .fat, .fiber, .sugar, .sodium:
            return .nutrition
        case .novaScore, .nutriScore:
            return .quality
        case .steps, .weight: // .water TEMPORARILY DISABLED
            return .health
        }
    }
    
    var isEssential: Bool {
        return false // No metrics are required - all are optional
    }
}

enum TrackingMetricCategory: String, CaseIterable {
    case nutrition = "Nutrition"
    case quality = "Food Quality"
    case health = "Health & Fitness"
    
    var icon: String {
        switch self {
        case .nutrition: return "fork.knife"
        case .quality: return "star"
        case .health: return "heart"
        }
    }
}

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case consent = 1
    case region = 2
    case activity = 3
    case goals = 4
    case personalInfo = 5
    case trackingPreferences = 6
    case complete = 7
    
    var title: String {
        switch self {
        case .welcome: return ""
        case .consent: return "Privacy & Terms"
        case .region: return "Your Region"
        case .activity: return "Your Activity"
        case .goals: return "Your Goal"
        case .personalInfo: return "About You"
        case .trackingPreferences: return "Track Metrics"
        case .complete: return "All Set!"
        }
    }
}

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var currentStep: OnboardingStep = .welcome
    @State private var selectedRegion: String = "All Regions"
    @State private var selectedActivity: ActivityLevel? = nil
    @State private var selectedGoal: HealthGoal? = nil
    @State private var selectedMetrics: Set<TrackingMetric> = []
    
    // Consent state
    @State private var analyticsConsent: Bool = false
    @State private var crashReportingConsent: Bool = false
    
    // Personal info state
    @State private var age: String = ""
    @State private var selectedGender: Gender = .male
    @State private var height: String = ""
    @State private var currentWeight: String = ""
    
    // Available regions
    private let availableRegions = [
        "All Regions",
        "United States",
        "United Kingdom",
        "Canada",
        "Australia",
        "France",
        "Germany",
        "Spain",
        "Italy",
        "Netherlands",
        "Belgium",
        "Switzerland",
        "Sweden",
        "Norway",
        "Denmark",
        "Ireland",
        "New Zealand"
    ]
    
    // Auth sheet state
    @State private var showingSignUp = false
    @State private var showingSignIn = false
    
    // Scroll tracking for collapsible header
    @State private var scrollOffset: CGFloat = 0
    @State private var isHeaderVisible = true
    
    // Animation state for typewriter effect and fade-in
    @State private var displayedTitle: String = ""
    @State private var isTypingComplete = false
    @State private var visibleRows: Set<Int> = []
    
    var body: some View {
        ZStack {
            // Background color matching dashboard
            Color(.systemGray6)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress bar - always visible
                HStack(spacing: 4) {
                    ForEach(0..<OnboardingStep.allCases.count, id: \.self) { index in
                        Rectangle()
                            .fill(index <= currentStep.rawValue ? Color(hex: "#5ec5ff") : Color.gray.opacity(0.3))
                            .frame(height: 4)
                            .cornerRadius(2)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .background(Color(.systemGray6))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Progress indicator")
                .accessibilityValue("Step \(currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
                
                // Collapsible header - Step indicator and title
                if isHeaderVisible {
                    VStack(spacing: 8) {
                        Text("Step \(currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(displayedTitle)
                            .font(.system(size: 28, weight: .bold))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        startTypewriterEffect()
                    }
                }
            
                // Content area with scroll detection
                ScrollView {
                    VStack(spacing: 20) {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("scroll")).minY
                            )
                        }
                        .frame(height: 1)
                        // Content based on current step
                        stepContent
                    }
                    .padding(.horizontal)
                    
                    // Bottom navigation - inside scroll content
                    bottomNavigation
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        // Hide header when scrolling down (value becomes negative)
                        // Show header when at top (value is 0 or positive)
                        isHeaderVisible = value > -30
                    }
                }
            }
            .onChange(of: currentStep) { _, _ in
                // Reset animation state when step changes
                displayedTitle = ""
                isTypingComplete = false
                visibleRows = []
                
                // Start typewriter effect for new step
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    startTypewriterEffect()
                }
            }
        }
        .onAppear {
            detectRegion()
        }
    }
    
    // MARK: - Step Content
    @ViewBuilder
    private var stepContent: some View {
        if currentStep == .welcome {
                VStack(spacing: 32) {
                    // App icon/logo
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Color(hex: "#5ec5ff"))
                        .symbolRenderingMode(.hierarchical)
                    
                    VStack(spacing: 16) {
                        Text("Welcome to Nutribase")
                            .font(.system(size: 32, weight: .bold))
                            .multilineTextAlignment(.center)
                        
                        Text("Your personal nutrition and weight tracking companion")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 16) {
                        FeatureCard(
                            icon: "chart.line.uptrend.xyaxis",
                            iconColor: .green,
                            title: "Smart Analytics",
                            description: "Track weight phases, NOVA scores, and nutrition trends"
                        )
                        .opacity(visibleRows.contains(0) ? 1 : 0)
                        .offset(y: visibleRows.contains(0) ? 0 : 20)
                        
                        FeatureCard(
                            icon: "barcode.viewfinder",
                            iconColor: .orange,
                            title: "Easy Food Logging",
                            description: "Scan barcodes or search our comprehensive food database"
                        )
                        .opacity(visibleRows.contains(1) ? 1 : 0)
                        .offset(y: visibleRows.contains(1) ? 0 : 20)
                        
                        FeatureCard(
                            icon: "target",
                            iconColor: .red,
                            title: "Personalized Goals",
                            description: "Custom calorie and macro targets based on your lifestyle"
                        )
                        .opacity(visibleRows.contains(2) ? 1 : 0)
                        .offset(y: visibleRows.contains(2) ? 0 : 20)
                        
                        FeatureCard(
                            icon: "checkmark.circle",
                            iconColor: .blue,
                            title: "Day Completion",
                            description: "Mark days complete for accurate progress tracking"
                        )
                        .opacity(visibleRows.contains(3) ? 1 : 0)
                        .offset(y: visibleRows.contains(3) ? 0 : 20)
                    }
                    .padding(.horizontal)
                }
            } else if currentStep == .consent {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "#5ec5ff"))
                        
                        Text("Privacy & Terms")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("We respect your privacy and protect your data")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Required consents
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("I agree to the Terms of Service")
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    Button("View Terms") {
                                        // TODO: Show terms sheet
                                    }
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "#5ec5ff"))
                                }
                            }
                            .opacity(visibleRows.contains(0) ? 1 : 0)
                            .offset(y: visibleRows.contains(0) ? 0 : 20)
                            
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("I acknowledge the Privacy Policy")
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    Button("View Privacy Policy") {
                                        // TODO: Show privacy policy sheet
                                    }
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "#5ec5ff"))
                                }
                            }
                            .opacity(visibleRows.contains(1) ? 1 : 0)
                            .offset(y: visibleRows.contains(1) ? 0 : 20)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Optional consents
                        Text("Optional")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Toggle(isOn: $analyticsConsent) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Share Anonymous Analytics")
                                    .font(.body)
                                Text("Help improve the app")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Toggle(isOn: $crashReportingConsent) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Crash Reporting")
                                    .font(.body)
                                Text("Help us fix bugs faster")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                .padding(.horizontal)
            } else if currentStep == .region {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "#5ec5ff"))
                        
                        Text("Select Your Region")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("This helps us show you relevant food products from your area")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(Array(availableRegions.enumerated()), id: \.element) { index, region in
                                Button(action: {
                                    selectedRegion = region
                                }) {
                                    HStack {
                                        Text(region == "All Regions" ? "🌍" : regionFlag(for: region))
                                            .font(.title2)
                                        
                                        Text(region)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedRegion == region ? Color(hex: "#5ec5ff").opacity(0.2) : Color(.systemBackground))
                                            .stroke(selectedRegion == region ? Color(hex: "#5ec5ff") : Color.clear, lineWidth: 2)
                                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .opacity(visibleRows.contains(index / 2) ? 1 : 0)
                                .offset(y: visibleRows.contains(index / 2) ? 0 : 20)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            } else if currentStep == .activity {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                        ForEach(Array(ActivityLevel.allCases.enumerated()), id: \.element) { index, activity in
                            Button(action: {
                                selectedActivity = activity
                            }) {
                                VStack(spacing: 12) {
                                    Image(systemName: activity.icon)
                                        .font(.system(size: 32))
                                        .foregroundColor(activity.iconColor)
                                    
                                    Text(activity.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                    
                                    Text(activity.shortDescription)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedActivity == activity ? activity.iconColor.opacity(0.2) : Color(.systemBackground))
                                        .stroke(selectedActivity == activity ? activity.iconColor : Color.clear, lineWidth: 2)
                                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .opacity(visibleRows.contains(index) ? 1 : 0)
                            .offset(y: visibleRows.contains(index) ? 0 : 20)
                        }
                    }
                    .padding()
                }
            } else if currentStep == .goals {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(Array(HealthGoal.allCases.enumerated()), id: \.element) { index, goal in
                            Button(action: {
                                selectedGoal = goal
                            }) {
                                VStack(spacing: 12) {
                                    Image(systemName: goal.icon)
                                        .font(.system(size: 40))
                                        .foregroundColor(goal.iconColor)
                                    
                                    Text(goal.rawValue)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(goal.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedGoal == goal ? goal.iconColor.opacity(0.2) : Color(.systemBackground))
                                        .stroke(selectedGoal == goal ? goal.iconColor : Color.clear, lineWidth: 2)
                                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .opacity(visibleRows.contains(index / 2) ? 1 : 0)
                            .offset(y: visibleRows.contains(index / 2) ? 0 : 20)
                        }
                    }
                    .padding()
                }
            } else if currentStep == .personalInfo {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Age")
                            .font(.system(size: 16, weight: .semibold))
                        TextField("Enter your age", text: $age)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gender")
                            .font(.system(size: 16, weight: .semibold))
                        Picker("Gender", selection: $selectedGender) {
                            ForEach(Gender.allCases) { gender in
                                Text(gender.rawValue).tag(gender)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Height (cm)")
                            .font(.system(size: 16, weight: .semibold))
                        TextField("Enter height", text: $height)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight (kg)")
                            .font(.system(size: 16, weight: .semibold))
                        TextField("Enter weight", text: $currentWeight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
            } else if currentStep == .trackingPreferences {
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Choose the metrics you want to track on your dashboard")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        // All metrics by category
                        ForEach(Array(TrackingMetricCategory.allCases.enumerated()), id: \.element) { categoryIndex, category in
                            let categoryMetrics = TrackingMetric.allCases.filter { $0.category == category }
                            
                            if !categoryMetrics.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: category.icon)
                                            .foregroundColor(Color(hex: "#5ec5ff"))
                                        Text(category.rawValue)
                                            .font(.system(size: 18, weight: .semibold))
                                    }
                                    
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                        ForEach(categoryMetrics) { metric in
                                            OnboardingMetricCard(
                                                metric: metric,
                                                isSelected: selectedMetrics.contains(metric),
                                                isEssential: false
                                            ) {
                                                if selectedMetrics.contains(metric) {
                                                    selectedMetrics.remove(metric)
                                                } else {
                                                    selectedMetrics.insert(metric)
                                                }
                                            }
                                        }
                                    }
                                }
                                .opacity(visibleRows.contains(categoryIndex) ? 1 : 0)
                                .offset(y: visibleRows.contains(categoryIndex) ? 0 : 20)
                            }
                        }
                    }
                    .padding()
                }
            } else if currentStep == .complete {
                VStack(spacing: 32) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .symbolRenderingMode(.hierarchical)
                    
                    VStack(spacing: 16) {
                        Text("You're All Set!")
                            .font(.system(size: 32, weight: .bold))
                        
                        Text(authService.isAuthenticated ? 
                             "Your data is safely synced to the cloud" : 
                             "Your personalized nutrition journey starts now")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Summary of user's setup
                    VStack(spacing: 16) {
                        if let activity = selectedActivity,
                           let goal = selectedGoal {
                            
                            SummaryRow(
                                icon: "target",
                                title: "Goal",
                                value: goal.rawValue
                            )
                            
                            SummaryRow(
                                icon: "figure.run",
                                title: "Activity Level",
                                value: activity.rawValue
                            )
                            
                            // Show calculated calories if available
                            if let calories = calculateDailyCalories() {
                                SummaryRow(
                                    icon: "flame.fill",
                                    title: "Daily Calories",
                                    value: "\(calories) cal"
                                )
                                
                                // Show macros if calories calculated
                                if let macros = calculateMacros(calories: calories) {
                                    SummaryRow(
                                        icon: "p.circle.fill",
                                        title: "Daily Protein",
                                        value: "\(macros.protein)g"
                                    )
                                }
                            }
                            
                            SummaryRow(
                                icon: "chart.bar",
                                title: "Tracking Metrics",
                                value: "\(selectedMetrics.count) selected"
                            )
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                    )
                }
        } else {
            VStack {
                Spacer()
                
                Text("Content for \(currentStep.title)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
    
    // MARK: - Bottom Navigation
    private var bottomNavigation: some View {
        HStack(spacing: 16) {
            // Back button
            if currentStep.rawValue > 0 {
                Button("Back") {
                    currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1)!
                }
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                )
                .foregroundColor(.primary)
                .accessibilityLabel("Go back to previous step")
                .accessibilityHint("Returns to the previous onboarding step")
            }
            
            Spacer()
            
            // Next/Finish button
            Button(currentStep == .complete ? "Get Started" : "Next") {
                if currentStep.rawValue < 5 {
                    currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1)!
                } else {
                    // Save user profile data and complete onboarding
                    saveUserProfile()
                    completeOnboarding()
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canContinue ? Color(hex: "#5ec5ff") : Color.gray)
            )
            .foregroundColor(.white)
            .disabled(!canContinue)
            .accessibilityLabel(currentStep == .complete ? "Complete onboarding and get started" : "Continue to next step")
            .accessibilityHint(canContinue ? "Advances to the next onboarding step" : "Complete the current step to continue")
        }
        .padding(.horizontal)
        .padding(.top, 32)
        .padding(.bottom, 20)
    }
    
    // MARK: - Helper Functions
    private func detectRegion() {
        // Detect user's region from locale
        if let regionCode = Locale.current.region?.identifier {
            switch regionCode {
            case "US": selectedRegion = "United States"
            case "GB": selectedRegion = "United Kingdom"
            case "CA": selectedRegion = "Canada"
            case "AU": selectedRegion = "Australia"
            case "FR": selectedRegion = "France"
            case "DE": selectedRegion = "Germany"
            case "ES": selectedRegion = "Spain"
            case "IT": selectedRegion = "Italy"
            case "NL": selectedRegion = "Netherlands"
            case "BE": selectedRegion = "Belgium"
            case "CH": selectedRegion = "Switzerland"
            default: selectedRegion = "All Regions"
            }
        } else {
            selectedRegion = "All Regions"
        }
    }
    
    private func startTypewriterEffect() {
        // Reset state
        displayedTitle = ""
        isTypingComplete = false
        visibleRows = []
        
        let fullTitle = currentStep.title
        guard !fullTitle.isEmpty else {
            isTypingComplete = true
            startRowFadeIn()
            return
        }
        
        var currentIndex = 0
        let characters = Array(fullTitle)
        
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if currentIndex < characters.count {
                self.displayedTitle.append(characters[currentIndex])
                
                // Light haptic feedback for each character
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred(intensity: 0.3)
                
                currentIndex += 1
            } else {
                timer.invalidate()
                self.isTypingComplete = true
                // Start fading in rows after typing is complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.startRowFadeIn()
                }
            }
        }
    }
    
    private func startRowFadeIn() {
        // Determine number of rows based on current step
        let rowCount = getRowCount()
        
        for index in 0..<rowCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                withAnimation(.easeOut(duration: 0.4)) {
                    _ = self.visibleRows.insert(index)
                }
            }
        }
    }
    
    private func getRowCount() -> Int {
        switch currentStep {
        case .welcome:
            return 4 // 4 feature cards
        case .consent:
            return 2 // 2 consent items
        case .activity:
            return ActivityLevel.allCases.count
        case .goals:
            return (HealthGoal.allCases.count + 1) / 2
        case .region:
            return (availableRegions.count + 1) / 2
        case .trackingPreferences:
            return TrackingMetricCategory.allCases.count
        default:
            return 0
        }
    }
    
    private var canContinue: Bool {
        switch currentStep {
        case .consent:
            return true // Terms and Privacy are implicitly accepted by continuing
        case .region:
            return true // Region is always selected (defaults to "All Regions")
        case .activity:
            return selectedActivity != nil
        case .goals:
            return selectedGoal != nil
        case .personalInfo:
            return !age.isEmpty && 
                   !height.isEmpty && 
                   !currentWeight.isEmpty &&
                   Int(age) != nil &&
                   Double(height) != nil &&
                   Double(currentWeight) != nil
        case .trackingPreferences:
            return true // No minimum selection required
        default:
            return true
        }
    }
    
    private func regionFlag(for region: String) -> String {
        switch region {
        case "United States": return "🇺🇸"
        case "United Kingdom": return "🇬🇧"
        case "Canada": return "🇨🇦"
        case "Australia": return "🇦🇺"
        case "France": return "🇫🇷"
        case "Germany": return "🇩🇪"
        case "Spain": return "🇪🇸"
        case "Italy": return "🇮🇹"
        case "Netherlands": return "🇳🇱"
        case "Belgium": return "🇧🇪"
        case "Switzerland": return "🇨🇭"
        case "Sweden": return "🇸🇪"
        case "Norway": return "🇳🇴"
        case "Denmark": return "🇩🇰"
        case "Ireland": return "🇮🇪"
        case "New Zealand": return "🇳🇿"
        default: return "🌍"
        }
    }
    
    // MARK: - Calorie Calculation Functions
    private func calculateDailyCalories() -> Int? {
        guard let activity = selectedActivity,
              let ageValue = Int(age),
              let heightValue = Double(height),
              let weightValue = Double(currentWeight) else {
            return nil
        }
        
        // Calculate BMR using Mifflin-St Jeor Equation
        let bmr: Double
        switch selectedGender {
        case .male:
            bmr = 10 * weightValue + 6.25 * heightValue - 5 * Double(ageValue) + 5
        case .female:
            bmr = 10 * weightValue + 6.25 * heightValue - 5 * Double(ageValue) - 161
        case .notSpecified:
            // Use average of male and female formulas
            let maleBMR = 10 * weightValue + 6.25 * heightValue - 5 * Double(ageValue) + 5
            let femaleBMR = 10 * weightValue + 6.25 * heightValue - 5 * Double(ageValue) - 161
            bmr = (maleBMR + femaleBMR) / 2
        }
        
        // Apply activity multiplier
        let tdee = bmr * activity.multiplier
        
        // Apply goal modifier if selected
        var finalCalories = tdee
        if let goal = selectedGoal {
            finalCalories = tdee * (1 + goal.calorieModifier)
        }
        
        return Int(finalCalories.rounded())
    }
    
    private func calculateMacros(calories: Int) -> (protein: Int, carbs: Int, fat: Int)? {
        // Standard macro distribution (can be customized based on goals/activity later)
        let proteinPercentage: Double = 0.20  // 20% protein
        let carbPercentage: Double = 0.45     // 45% carbs  
        let fatPercentage: Double = 0.35      // 35% fat
        
        let proteinCalories = Double(calories) * proteinPercentage
        let carbCalories = Double(calories) * carbPercentage
        let fatCalories = Double(calories) * fatPercentage
        
        // Convert to grams (protein: 4 cal/g, carbs: 4 cal/g, fat: 9 cal/g)
        let proteinGrams = Int((proteinCalories / 4).rounded())
        let carbGrams = Int((carbCalories / 4).rounded())
        let fatGrams = Int((fatCalories / 9).rounded())
        
        return (protein: proteinGrams, carbs: carbGrams, fat: fatGrams)
    }
    
    private func mapTrackingMetricToCardType(_ metric: TrackingMetric) -> CardType? {
        switch metric {
        case .calories:
            return .calorieTarget
        case .protein:
            return .protein
        case .carbs:
            return .carbs
        case .fat:
            return .fat
        // case .water: // TEMPORARILY DISABLED
        //     return .water
        case .weight:
            return .currentWeight
        case .steps:
            return .activity
        case .novaScore:
            return .novaGroups
        case .nutriScore:
            return .nutriScore
        case .fiber, .sugar, .sodium:
            return nil // These don't have corresponding dashboard cards yet
        }
    }
    
    private func saveUserProfile() {
        // Save basic personal info - convert age to date of birth
        if let ageValue = Int(age) {
            UserProfile.shared.dateOfBirth = Calendar.current.date(byAdding: .year, value: -ageValue, to: Date()) ?? Date()
        }
        UserProfile.shared.gender = selectedGender
        
        if let heightValue = Double(height) {
            UserProfile.shared.heightCm = heightValue
        }
        
        if let weightValue = Double(currentWeight) {
            UserProfile.shared.weightKg = weightValue
        }
        
        // Save activity level
        if let activity = selectedActivity {
            UserProfile.shared.activityLevel = activity
        }
        
        // Save region preference to UserDefaults
        UserDefaults.standard.set(selectedRegion, forKey: "preferredFoodRegion")
        
        // Save consent preferences
        UserDefaults.standard.set(analyticsConsent, forKey: "analyticsEnabled")
        UserDefaults.standard.set(crashReportingConsent, forKey: "crashReportingEnabled")
        UserDefaults.standard.set(true, forKey: "termsAccepted")
        UserDefaults.standard.set(true, forKey: "privacyPolicyAccepted")
        UserDefaults.standard.set(Date(), forKey: "consentDate")
        
        // Calculate and save nutrition goals
        if let calories = calculateDailyCalories() {
            UserProfile.shared.dailyCalorieGoal = calories
            
            if let macros = calculateMacros(calories: calories) {
                UserProfile.shared.proteinGoalGrams = macros.protein
                UserProfile.shared.carbGoalGrams = macros.carbs
                UserProfile.shared.fatGoalGrams = macros.fat
            }
        }
        
        // Save dashboard customization based on selected tracking metrics
        saveDashboardCustomization()
        
        print("✅ Onboarding completed - User profile saved!")
        print("📊 Daily calories: \(UserProfile.shared.dailyCalorieGoal)")
        print("🏃‍♂️ Activity level: \(UserProfile.shared.activityLevel.rawValue)")
        print("🌍 Region: \(selectedRegion)")
        print("📱 Dashboard widgets: \(selectedMetrics.count) metrics selected")
    }
    
    private func saveDashboardCustomization() {
        // Convert selected tracking metrics to dashboard card types
        let selectedCardTypes = selectedMetrics.compactMap { mapTrackingMetricToCardType($0) }
        
        // Always include essential cards (weight chart) regardless of selection
        let essentialCards: [CardType] = [.weightChart]
        
        // Combine essential cards with user-selected cards
        let allSelectedCards = Array(Set(essentialCards + selectedCardTypes))
        
        // Save to UserDefaults for dashboard to read
        let cardTypeStrings = allSelectedCards.map { $0.rawValue }
        UserDefaults.standard.set(cardTypeStrings, forKey: "onboardingSelectedCards")
        
        // Also save the raw tracking metrics for future reference
        let metricStrings = selectedMetrics.map { $0.rawValue }
        UserDefaults.standard.set(metricStrings, forKey: "selectedTrackingMetrics")
        
        print("💾 Dashboard customization saved: \(allSelectedCards.map { $0.rawValue })")
        
        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(Date(), forKey: "onboardingCompletionDate")
        
        print("🎯 Onboarding completion flag set")
    }
    
    private func completeOnboarding() {
        // Dismiss the onboarding view to show the main app
        dismiss()
        
        // Post notification to refresh the app state
        NotificationCenter.default.post(name: NSNotification.Name("OnboardingCompleted"), object: nil)
        
        print("🎉 Onboarding completed - Opening main app")
    }
    
    // MARK: - Onboarding Completion Helpers
    static func hasCompletedOnboarding() -> Bool {
        return UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
    
    static func getOnboardingCompletionDate() -> Date? {
        return UserDefaults.standard.object(forKey: "onboardingCompletionDate") as? Date
    }
    
    static func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "onboardingCompletionDate")
        UserDefaults.standard.removeObject(forKey: "onboardingSelectedCards")
        UserDefaults.standard.removeObject(forKey: "selectedTrackingMetrics")
        print("🔄 Onboarding reset - user can see onboarding again")
    }
}

// MARK: - FeatureCard Component
struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(iconColor)
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - FeatureRow Component (Legacy)
struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                
                Text(description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - SummaryRow Component
struct SummaryRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#5ec5ff"))
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - OnboardingMetricCard Component
struct OnboardingMetricCard: View {
    let metric: TrackingMetric
    let isSelected: Bool
    let isEssential: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: metric.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? metric.iconColor : .gray)
                
                Text(metric.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? metric.iconColor.opacity(0.15) : Color.white)
                    .stroke(
                        isSelected ? metric.iconColor : Color.clear,
                        lineWidth: isSelected ? 2 : 0
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.rawValue) tracking metric")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to \(isSelected ? "deselect" : "select") this metric for your dashboard")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

// MARK: - ScrollOffsetPreferenceKey
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
