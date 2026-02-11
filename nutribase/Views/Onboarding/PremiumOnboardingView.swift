import SwiftUI
import HealthKit
import Charts
import UniformTypeIdentifiers

// MARK: - Premium Onboarding Steps
enum PremiumOnboardingStep: Int, CaseIterable {
    case welcome = 0
    case privacy = 1
    case region = 2
    case age = 3
    case gender = 4
    case height = 5
    case weight = 6
    case activity = 7
    case goal = 8
    case trackingPreferences = 9
    case planSelection = 10
    case personalPlan = 11
    case building = 12
    case dashboardSetup = 13
    case emailVerification = 14
    case complete = 15
    
    var progress: Double {
        return Double(self.rawValue) / Double(PremiumOnboardingStep.allCases.count - 1)
    }
    
    var canSkip: Bool {
        switch self {
        case .welcome, .privacy:
            return true
        default:
            return false
        }
    }
}

// MARK: - Nutrition Plan
struct NutritionPlan: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let iconColor: Color
    let durationWeeks: Int
    let weeklyChangeKg: Double
    let calorieAdjustment: Int // +/- from maintenance
    let proteinMultiplier: Double // g per kg bodyweight
    var isCustom: Bool = false // User creates their own targets
    
    static func == (lhs: NutritionPlan, rhs: NutritionPlan) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Onboarding Metric Category for Tracking Preferences
enum OnboardingMetricCategory: String, CaseIterable {
    case nutrition = "Nutrition"
    case bodyMetrics = "Body Metrics"
    case activity = "Activity"
    case foodQuality = "Food Quality"
    
    var icon: String {
        switch self {
        case .nutrition: return "fork.knife"
        case .bodyMetrics: return "figure.arms.open"
        case .activity: return "figure.walk"
        case .foodQuality: return "leaf.fill"
        }
    }
    
    var metrics: [TrackingMetric] {
        switch self {
        case .nutrition:
            return [.calories, .protein, .carbs, .fat, .fiber, .sugar, .sodium]
        case .bodyMetrics:
            return [.weight]
        case .activity:
            return [.steps]
        case .foodQuality:
            return [.novaScore, .nutriScore, .gutHealth]
        }
    }
}

// MARK: - Tracking Preset (Legacy - kept for compatibility)
enum TrackingPreset: String, CaseIterable, Identifiable {
    case simple = "Simple"
    case balanced = "Balanced"
    case advanced = "Advanced"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .simple: return "target"
        case .balanced: return "scale.3d"
        case .advanced: return "brain.head.profile"
        }
    }
    
    var title: String {
        switch self {
        case .simple: return "Simple View"
        case .balanced: return "Balanced View"
        case .advanced: return "Advanced View"
        }
    }
    
    var description: String {
        switch self {
        case .simple: return "Calories, Steps & Weight"
        case .balanced: return "Plus Protein, Carbs & Fat"
        case .advanced: return "Full metrics including NOVA & Nutri-Score"
        }
    }
    
    var metrics: Set<TrackingMetric> {
        switch self {
        case .simple:
            return [.calories, .steps, .weight]
        case .balanced:
            return [.calories, .steps, .weight, .protein, .carbs, .fat]
        case .advanced:
            return Set(TrackingMetric.allCases)
        }
    }
}

// MARK: - Premium Onboarding View
struct PremiumOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = FirebaseAuthService.shared
    
    // Test mode - when launched from Settings, shows close button and doesn't save profile
    var isTestMode: Bool = false
    
    // Step state
    @State private var currentStep: PremiumOnboardingStep = .welcome
    @State private var isAnimating = false
    
    // Welcome carousel
    @State private var welcomeCardIndex = 0
    @State private var welcomeCarouselTimer: Timer?
    @State private var scrolledCardId: Int? = 0
    @State private var swipeDirection: Edge = .trailing
    
    // Privacy consents
    @State private var crashReportingConsent = false
    @State private var analyticsConsent = false
    @State private var healthKitConsent = false
    @State private var termsAgreed = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    
    // Region
    @State private var selectedRegion: String = ""
    @State private var detectedRegion: String = ""
    
    // Activity
    @State private var selectedActivity: ActivityLevel = .moderate
    @State private var visibleActivityIndex: Int = 2 // Default to moderate (index 2)
    
    // Goal
    @State private var selectedGoal: HealthGoal? = nil
    
    // Personal info (micro-steps)
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    
    // Computed age from date of birth
    private var age: Int {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return ageComponents.year ?? 30
    }
    
    @State private var selectedGender: Gender = .male
    @State private var heightCm: Double = 170
    @State private var weightKg: Double = 70
    @State private var useImperialHeight: Bool = false  // false = cm, true = ft/inches
    @State private var useImperialWeight: Bool = false  // false = kg, true = stones/lbs
    
    // Tracking
    @State private var selectedPreset: TrackingPreset = .balanced
    @State private var selectedMetrics: Set<TrackingMetric> = Set(TrackingMetric.allCases) // All metrics selected by default
    
    // Plan selection
    @State private var availablePlans: [NutritionPlan] = []
    @State private var selectedPlan: NutritionPlan? = nil
    @State private var visiblePlanIndex: Int = 0
    
    // Animation states
    @State private var showContent = false
    @State private var cardOffset: CGFloat = 50
    @State private var logoScale: CGFloat = 0.8
    @State private var logoPulse = false
    
    // Building step state
    @State private var buildingProgress: CGFloat = 0
    @State private var currentFeatureIndex: Int = 0
    @State private var featureOpacity: Double = 1.0
    @State private var buildingCarouselTimer: Timer?
    @State private var buildingSwipeDirection: Edge = .trailing
    
    // Dashboard setup state
    @State private var onboardingCardOrder: [CardType] = []
    @State private var onboardingHiddenCards: [CardType] = []
    @State private var showingOnboardingWidgetStorage = false
    
    // Complete step confetti
    @State private var showConfetti = false
    
    // Guard against duplicate phase creation
    @State private var hasCreatedPhase = false
    
    // Email verification step
    @State private var showingVerificationAlert = false
    @State private var verificationAlertMessage = ""
    
    // HealthKit
    @State private var showHealthKitPrompt = false
    @State private var healthKitImported = false
    
    private let welcomeCards = [
        WelcomeCard(icon: "chart.line.uptrend.xyaxis", title: "Smart Weight Trends", description: "Understand every phase of your journey with intelligent trend analysis"),
        WelcomeCard(icon: "leaf.fill", title: "Smarter Nutrition", description: "NOVA scores, Nutri-Score & food quality insights at your fingertips"),
        WelcomeCard(icon: "flame.fill", title: "Personalised Goals", description: "Daily targets based on your metabolism, activity & unique goals"),
        WelcomeCard(icon: "heart.fill", title: "A More Human Tracker", description: "Designed to keep you consistent, not obsessed")
    ]
    
    private let regions = [
        ("All Regions", "🌍"),
        ("United States", "🇺🇸"),
        ("United Kingdom", "🇬🇧"),
        ("Canada", "🇨🇦"),
        ("Australia", "🇦🇺"),
        ("France", "🇫🇷"),
        ("Germany", "🇩🇪"),
        ("Spain", "🇪🇸"),
        ("Italy", "🇮🇹"),
        ("Netherlands", "🇳🇱"),
        ("Belgium", "🇧🇪"),
        ("Switzerland", "🇨🇭"),
        ("Sweden", "🇸🇪"),
        ("Norway", "🇳🇴"),
        ("Denmark", "🇩🇰"),
        ("Ireland", "🇮🇪"),
        ("New Zealand", "🇳🇿")
    ]
    
    var body: some View {
        ZStack {
            // Premium gradient background
            PremiumGradientBackground()
                .ignoresSafeArea()
            
            // Blue gradient for welcome step (covers entire screen including safe area)
            // Adapts to dark mode by using darker end color
            if currentStep == .welcome {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#35b8ff").opacity(1),
                        Color.appCardBackground
                    ]),
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.5)
                )
                .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // Top bar with progress
                topBar
                
                // Main content - no swipe between steps, only button navigation
                Group {
                    switch currentStep {
                    case .welcome: welcomeStep
                    case .privacy: privacyStep
                    case .region: regionStep
                    case .activity: activityStep
                    case .goal: goalStep
                    case .age: ageStep
                    case .gender: genderStep
                    case .height: heightStep
                    case .weight: weightStep
                    case .trackingPreferences: trackingPreferencesStep
                    case .planSelection: planSelectionStep
                    case .personalPlan: personalPlanStep
                    case .building: buildingStep
                    case .dashboardSetup: dashboardSetupStep
                    case .emailVerification: emailVerificationStep
                    case .complete: completeStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
                
                Spacer(minLength: 0)
                
                // Bottom navigation - always visible at bottom
                bottomNavigation
            }
        }
        .onAppear {
            detectRegion()
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
                cardOffset = 0
                logoScale = 1.0
            }
            startLogoPulse()
        }
        .onChange(of: currentStep) { _, _ in
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        .keyboardDismissToolbar()
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        Group {
            // Hide top bar during building and complete steps (unless test mode)
            if (currentStep == .building || currentStep == .complete) && !isTestMode {
                Spacer().frame(height: 40)
            } else if (currentStep == .building || currentStep == .complete) && isTestMode {
                // In test mode, show just the close button during building/complete
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color.appInsetBackground)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)
            } else {
                VStack(spacing: 12) {
                    // Progress bar with optional close button
                    HStack {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 4)
                                
                                // Progress
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: "#35b8ff"))
                                    .frame(width: geometry.size.width * currentStep.progress, height: 4)
                                    .animation(.spring(response: 0.4), value: currentStep)
                            }
                        }
                        .frame(height: 4)
                        
                        if isTestMode {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 30, height: 30)
                                    .background(Color.appInsetBackground)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - Bottom Navigation
    private var bottomNavigation: some View {
        Group {
            // Hide navigation during building and dashboard setup steps
            if currentStep == .building {
                Spacer().frame(height: 80)
            } else if currentStep == .dashboardSetup {
                EmptyView()
            } else {
                HStack(spacing: 16) {
                    // Back button
                    if currentStep.rawValue > 0 && currentStep != .complete {
                        Button(action: goBack) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.appInsetBackground)
                                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                            )
                        }
                    }
                    
                    Spacer()
                    
                    // Continue button (hidden on email verification and complete steps - they have their own buttons)
                    if currentStep != .complete && currentStep != .emailVerification {
                        Button(action: goNext) {
                            HStack(spacing: 6) {
                                Text(currentStep == .personalPlan ? "Build My Experience" : (currentStep == .dashboardSetup ? "Looks Good!" : "Continue"))
                                    .font(.system(size: 16, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(hex: "#35b8ff"))
                                    .shadow(color: Color(hex: "#35b8ff").opacity(0.3), radius: 8, y: 4)
                            )
                        }
                        .disabled(!canContinue)
                        .opacity(canContinue ? 1 : 0.5)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 0)
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - Step 1: Welcome
    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Logo
            Image("app-logo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .scaleEffect(logoScale)
                .scaleEffect(logoPulse ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: logoPulse)
                .padding(.bottom, 32)
                .padding(.horizontal, 24)
            
            // Title
            VStack(spacing: 12) {
                Text("Welcome to")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("NutriBase")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.primary)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)
            .padding(.horizontal, 24)
            
            // Swipeable cards with slide animation
            ZStack {
                ForEach(0..<welcomeCards.count, id: \.self) { index in
                    if index == welcomeCardIndex {
                        WelcomeCardView(card: welcomeCards[index])
                            .padding(.horizontal, 40)
                            .transition(.asymmetric(
                                insertion: .move(edge: swipeDirection).combined(with: .opacity),
                                removal: .move(edge: swipeDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                            ))
                    }
                }
            }
            .frame(height: 240)
            .contentShape(Rectangle())
            .padding(.top, 32)
            .gesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        if horizontal < -30 {
                            // Swipe left → next card
                            swipeDirection = .trailing
                            withAnimation(.easeInOut(duration: 0.7)) {
                                welcomeCardIndex = (welcomeCardIndex + 1) % welcomeCards.count
                            }
                            startWelcomeCarouselTimer()
                        } else if horizontal > 30 {
                            // Swipe right → previous card
                            swipeDirection = .leading
                            withAnimation(.easeInOut(duration: 0.7)) {
                                welcomeCardIndex = (welcomeCardIndex - 1 + welcomeCards.count) % welcomeCards.count
                            }
                            startWelcomeCarouselTimer()
                        }
                    }
            )
            
            // Page indicator dots
            HStack(spacing: 8) {
                ForEach(0..<welcomeCards.count, id: \.self) { index in
                    Circle()
                        .fill(index == welcomeCardIndex ? Color(hex: "#35b8ff") : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == welcomeCardIndex ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: welcomeCardIndex)
                }
            }
            .padding(.top, 12)
            
            Spacer()
        }
        .onAppear {
            startWelcomeCarouselTimer()
        }
        .onDisappear {
            welcomeCarouselTimer?.invalidate()
        }
    }
    
    private func startWelcomeCarouselTimer() {
        welcomeCarouselTimer?.invalidate()
        welcomeCarouselTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            swipeDirection = .trailing
            withAnimation(.easeInOut(duration: 0.7)) {
                welcomeCardIndex = (welcomeCardIndex + 1) % welcomeCards.count
            }
        }
    }
    
    // MARK: - Step 2: Privacy
    private var privacyStep: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Icon
            /*Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#35b8ff"))
                .symbolRenderingMode(.hierarchical)*/
            
            // Title
            VStack(spacing: 8) {
                Text("Your Privacy")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("We respect and protect your data")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Privacy cards and policy in ScrollView
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    PrivacyCard(
                        icon: "lock.fill",
                        title: "Your Data Stays Yours",
                        subtitle: "We never sell your information",
                        isToggle: false,
                        isOn: .constant(true)
                    )
                    
                    PrivacyCard(
                        icon: "chart.bar.fill",
                        title: "Crash Reporting",
                        subtitle: "Required · Helps us fix bugs faster",
                        isToggle: true,
                        isOn: $crashReportingConsent
                    )
                    
                    PrivacyCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Anonymous Analytics",
                        subtitle: "Required · Helps us improve NutriBase",
                        isToggle: true,
                        isOn: $analyticsConsent
                    )
                    
                    PrivacyCard(
                        icon: "heart.fill",
                        title: "Apple Health",
                        subtitle: "Required · Sync weight & activity data",
                        isToggle: true,
                        isOn: $healthKitConsent,
                        iconColor: .red
                    )
                    
                    // Agreement checkbox
                    Button(action: {
                        termsAgreed.toggle()
                        HapticManager.shared.lightFeedback()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: termsAgreed ? "checkmark.square.fill" : "square")
                                .font(.system(size: 22))
                                .foregroundColor(termsAgreed ? Color(hex: "#35b8ff") : .gray)
                            
                            Text("I agree to the ")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                            +
                            Text("Privacy Policy")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#35b8ff"))
                            +
                            Text(" and ")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                            +
                            Text("Terms of Service")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#35b8ff"))
                        }
                        .multilineTextAlignment(.center)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 8)
                    
                    // Legal links
                    HStack(spacing: 24) {
                        Button("Privacy Policy") {
                            showingPrivacyPolicy = true
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#35b8ff"))
                        
                        Button("Terms of Service") {
                            showingTermsOfService = true
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#35b8ff"))
                    }
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)
            }
            
            Spacer()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            LegalDocumentView(title: "Privacy Policy", documentType: .privacyPolicy)
        }
        .sheet(isPresented: $showingTermsOfService) {
            LegalDocumentView(title: "Terms of Service", documentType: .termsOfService)
        }
        .onChange(of: healthKitConsent) { oldValue, newValue in
            if newValue {
                // Request HealthKit authorization when enabled
                HealthKitManager.shared.requestAuthorization { success, error in
                    if !success {
                        // If authorization fails, turn off the toggle
                        DispatchQueue.main.async {
                            healthKitConsent = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Step 3: Region
    private var regionStep: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Select Your Region")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("This helps us show you relevant food products")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)
            
            // Region list
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(regions, id: \.0) { region in
                        RegionRow(
                            name: region.0,
                            flag: region.1,
                            isSelected: selectedRegion == region.0,
                            isRecommended: region.0 == detectedRegion
                        ) {
                            selectedRegion = region.0
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    }
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }
    
    // MARK: - Step 4: Activity
    private var activityStep: some View {
        VStack(spacing: 32) {
            // Title
            VStack(spacing: 8) {
                Text("Your Activity Level")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("This helps calculate your daily calorie needs")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            
            // Activity cards carousel with peek effect - centered card is auto-selected
            GeometryReader { geometry in
                let cardWidth = geometry.size.width * 0.75
                let cardSpacing: CGFloat = 16
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: cardSpacing) {
                        ForEach(Array(ActivityLevel.allCases.enumerated()), id: \.element) { index, activity in
                            ActivityCard(activity: activity, isSelected: selectedActivity == activity)
                                .frame(width: cardWidth)
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, (geometry.size.width - cardWidth) / 2, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: Binding(
                    get: { visibleActivityIndex },
                    set: { newValue in
                        if let newValue = newValue {
                            visibleActivityIndex = newValue
                            // Auto-select the centered card
                            if newValue < ActivityLevel.allCases.count {
                                selectedActivity = ActivityLevel.allCases[newValue]
                                hapticFeedback(.light)
                            }
                        }
                    }
                ))
            }
            .frame(height: 340)
            
            // Page indicator dots
            HStack(spacing: 8) {
                ForEach(0..<ActivityLevel.allCases.count, id: \.self) { index in
                    Circle()
                        .fill(index == visibleActivityIndex ? Color(hex: "#35b8ff") : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == visibleActivityIndex ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: visibleActivityIndex)
                }
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 0)
        .padding(.top, 16)
        .onAppear {
            // Set initial visible index based on selected activity
            visibleActivityIndex = ActivityLevel.allCases.firstIndex(of: selectedActivity) ?? 2
        }
    }
    
    // MARK: - Step 5: Goal
    private var goalStep: some View {
        VStack(spacing: 24) {
            // Title
            VStack(spacing: 8) {
                Text("What's Your Goal?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("We'll personalise your experience")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 16)
            
            // Goal cards
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(HealthGoal.allCases) { goal in
                        GoalCard(
                            goal: goal,
                            isSelected: selectedGoal == goal
                        ) {
                            selectedGoal = goal
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }
                    }
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }
    
    // MARK: - Step 6: Age (Micro-step)
    private var ageStep: some View {
        MicroStepContainer(
            title: "Date of birth",
            subtitle: "This helps calculate your metabolism"
        ) {
            // Date picker in card
            DatePicker(
                "Date of Birth",
                selection: $dateOfBirth,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 180)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.appInsetBackground)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            )
            .padding(.horizontal, 24)
            .onChange(of: dateOfBirth) { oldValue, newValue in
                hapticFeedback(.light)
            }
        }
    }
    
    // MARK: - Step 7: Gender (Micro-step)
    private var genderStep: some View {
        MicroStepContainer(
            title: "What's your biological sex?",
            subtitle: "Used for accurate calorie calculations"
        ) {
            VStack(spacing: 16) {
                ForEach(Gender.allCases) { gender in
                    GenderCard(
                        gender: gender,
                        isSelected: selectedGender == gender
                    ) {
                        selectedGender = gender
                        hapticFeedback()
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Step 8: Height (Micro-step)
    private var heightStep: some View {
        MicroStepContainer(
            title: "What's your height?",
            subtitle: "Used to calculate your BMR"
        ) {
            VStack(spacing: 20) {
                // Wheel picker for height in card
                Group {
                    if useImperialHeight {
                        // Feet and inches picker
                        HStack(spacing: 0) {
                            // Feet picker
                            Picker("Feet", selection: Binding(
                                get: { Int(heightCm / 2.54 / 12) },
                                set: { newFeet in
                                    let currentInches = Int((heightCm / 2.54).truncatingRemainder(dividingBy: 12))
                                    heightCm = Double(newFeet * 12 + currentInches) * 2.54
                                    hapticFeedback(.light)
                                }
                            )) {
                                ForEach(3...8, id: \.self) { feet in
                                    Text("\(feet) ft").tag(feet)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100)
                            .clipped()
                            
                            // Inches picker
                            Picker("Inches", selection: Binding(
                                get: { Int((heightCm / 2.54).truncatingRemainder(dividingBy: 12)) },
                                set: { newInches in
                                    let currentFeet = Int(heightCm / 2.54 / 12)
                                    heightCm = Double(currentFeet * 12 + newInches) * 2.54
                                    hapticFeedback(.light)
                                }
                            )) {
                                ForEach(0...11, id: \.self) { inches in
                                    Text("\(inches) in").tag(inches)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100)
                            .clipped()
                        }
                        .frame(height: 150)
                    } else {
                        // Centimeters picker
                        Picker("Height", selection: Binding(
                            get: { Int(heightCm) },
                            set: { newValue in
                                heightCm = Double(newValue)
                                hapticFeedback(.light)
                            }
                        )) {
                            ForEach(100...250, id: \.self) { cm in
                                Text("\(cm) cm").tag(cm)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 150)
                    }
                }
                .frame(height: 180)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appInsetBackground)
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                )
                
                // Unit toggle
                HStack(spacing: 0) {
                    Button(action: {
                        hapticFeedback(.light)
                        useImperialHeight = false
                    }) {
                        Text("cm")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(useImperialHeight ? .secondary : .white)
                            .frame(width: 60, height: 32)
                            .background(useImperialHeight ? Color.clear : Color(hex: "#35b8ff"))
                    }
                    
                    Button(action: {
                        hapticFeedback(.light)
                        useImperialHeight = true
                    }) {
                        Text("ft/in")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(useImperialHeight ? .white : .secondary)
                            .frame(width: 60, height: 32)
                            .background(useImperialHeight ? Color(hex: "#35b8ff") : Color.clear)
                    }
                }
                .background(Color.appInsetBackground)
                .cornerRadius(8)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Step 9: Weight (Micro-step)
    private var weightStep: some View {
        MicroStepContainer(
            title: "What's your current weight?",
            subtitle: "This is your starting point"
        ) {
            VStack(spacing: 20) {
                // Wheel picker for weight in card
                Group {
                    if useImperialWeight {
                        // Stones and pounds picker
                        HStack(spacing: 0) {
                            // Stones picker
                            Picker("Stones", selection: Binding(
                                get: { Int(weightKg * 2.20462 / 14) },
                                set: { newStones in
                                    let currentLbs = Int((weightKg * 2.20462).truncatingRemainder(dividingBy: 14))
                                    weightKg = Double(newStones * 14 + currentLbs) / 2.20462
                                    hapticFeedback(.light)
                                }
                            )) {
                                ForEach(4...31, id: \.self) { stones in
                                    Text("\(stones) st").tag(stones)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100)
                            .clipped()
                            
                            // Pounds picker
                            Picker("Pounds", selection: Binding(
                                get: { Int((weightKg * 2.20462).truncatingRemainder(dividingBy: 14)) },
                                set: { newLbs in
                                    let currentStones = Int(weightKg * 2.20462 / 14)
                                    weightKg = Double(currentStones * 14 + newLbs) / 2.20462
                                    hapticFeedback(.light)
                                }
                            )) {
                                ForEach(0...13, id: \.self) { lbs in
                                    Text("\(lbs) lb").tag(lbs)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100)
                            .clipped()
                        }
                        .frame(height: 150)
                    } else {
                        // Kilograms picker (whole kg + decimal)
                        HStack(spacing: 0) {
                            // Whole kg picker
                            Picker("Kilograms", selection: Binding(
                                get: { Int(weightKg) },
                                set: { newKg in
                                    let decimal = weightKg - Double(Int(weightKg))
                                    weightKg = Double(newKg) + decimal
                                    hapticFeedback(.light)
                                }
                            )) {
                                ForEach(30...200, id: \.self) { kg in
                                    Text("\(kg)").tag(kg)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                            .clipped()
                            
                            Text(".")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            // Decimal picker
                            Picker("Decimal", selection: Binding(
                                get: { Int((weightKg - Double(Int(weightKg))) * 10) },
                                set: { newDecimal in
                                    let wholeKg = Int(weightKg)
                                    weightKg = Double(wholeKg) + Double(newDecimal) / 10.0
                                    hapticFeedback(.light)
                                }
                            )) {
                                ForEach(0...9, id: \.self) { decimal in
                                    Text("\(decimal)").tag(decimal)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 60)
                            .clipped()
                            
                            Text("kg")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                        .frame(height: 150)
                    }
                }
                .frame(height: 180)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appInsetBackground)
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                )
                
                // Unit toggle
                HStack(spacing: 0) {
                    Button(action: {
                        hapticFeedback(.light)
                        useImperialWeight = false
                    }) {
                        Text("kg")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(useImperialWeight ? .secondary : .white)
                            .frame(width: 60, height: 32)
                            .background(useImperialWeight ? Color.clear : Color(hex: "#35b8ff"))
                    }
                    
                    Button(action: {
                        hapticFeedback(.light)
                        useImperialWeight = true
                    }) {
                        Text("st/lb")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(useImperialWeight ? .white : .secondary)
                            .frame(width: 60, height: 32)
                            .background(useImperialWeight ? Color(hex: "#35b8ff") : Color.clear)
                    }
                }
                .background(Color.appInsetBackground)
                .cornerRadius(8)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Step 10: Plan Selection
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
            
            // Plan cards carousel with peek effect - centered card is auto-selected
            GeometryReader { geometry in
                let cardWidth = geometry.size.width * 0.75
                let cardSpacing: CGFloat = 16
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: cardSpacing) {
                        ForEach(Array(availablePlans.enumerated()), id: \.element.id) { index, plan in
                            PlanCard(
                                plan: plan,
                                isSelected: selectedPlan?.id == plan.id,
                                baseCalories: calculateMaintenanceCalories() ?? 2000,
                                bodyWeight: weightKg,
                                selectedMetrics: selectedMetrics
                            ) {
                                selectedPlan = plan
                                hapticFeedback(.medium)
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
                    get: { visiblePlanIndex },
                    set: { newValue in
                        if let newValue = newValue {
                            visiblePlanIndex = newValue
                            // Auto-select the centered card
                            if newValue < availablePlans.count {
                                selectedPlan = availablePlans[newValue]
                                hapticFeedback(.light)
                            }
                        }
                    }
                ))
            }
            .frame(height: 380)
            
            // Plan indicator dots
            HStack(spacing: 8) {
                ForEach(0..<availablePlans.count, id: \.self) { index in
                    Circle()
                        .fill(index == visiblePlanIndex ? Color(hex: "#35b8ff") : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == visiblePlanIndex ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: visiblePlanIndex)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 0)
        .onAppear {
            generatePlansForGoal()
            // Auto-select first plan
            if let firstPlan = availablePlans.first {
                selectedPlan = firstPlan
                visiblePlanIndex = 0
            }
        }
    }
    
    // MARK: - Step 11: Tracking Preferences
    private var trackingPreferencesStep: some View {
        VStack(spacing: 20) {
            // Title
            VStack(spacing: 8) {
                Text("What to Track?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Choose metrics you care about")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            
            // Metric categories
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(OnboardingMetricCategory.allCases, id: \.rawValue) { category in
                        MetricCategoryCard(
                            category: category,
                            selectedMetrics: $selectedMetrics
                        )
                    }
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func generatePlansForGoal() {
        guard let goal = selectedGoal else {
            availablePlans = []
            return
        }
        
        switch goal {
        case .buildMuscle:
            availablePlans = [
                NutritionPlan(
                    name: "Lean Bulk",
                    description: "Slow, steady muscle gains with minimal fat",
                    icon: "figure.strengthtraining.traditional",
                    iconColor: .blue,
                    durationWeeks: 16,
                    weeklyChangeKg: 0.15,
                    calorieAdjustment: 250,
                    proteinMultiplier: 2.0
                ),
                NutritionPlan(
                    name: "Moderate Bulk",
                    description: "Balanced approach for consistent progress",
                    icon: "dumbbell.fill",
                    iconColor: .purple,
                    durationWeeks: 12,
                    weeklyChangeKg: 0.25,
                    calorieAdjustment: 400,
                    proteinMultiplier: 2.0
                ),
                NutritionPlan(
                    name: "Aggressive Bulk",
                    description: "Higher surplus for faster weight gain",
                    icon: "bolt.fill",
                    iconColor: .orange,
                    durationWeeks: 8,
                    weeklyChangeKg: 0.4,
                    calorieAdjustment: 600,
                    proteinMultiplier: 2.0
                ),
                NutritionPlan(
                    name: "Custom Plan",
                    description: "Set your own calorie and macro targets",
                    icon: "slider.horizontal.3",
                    iconColor: .gray,
                    durationWeeks: 0,
                    weeklyChangeKg: 0,
                    calorieAdjustment: 0,
                    proteinMultiplier: 1.6,
                    isCustom: true
                )
            ]
        case .loseWeight:
            availablePlans = [
                NutritionPlan(
                    name: "Gentle Cut",
                    description: "Sustainable fat loss, preserve muscle",
                    icon: "leaf.fill",
                    iconColor: .green,
                    durationWeeks: 16,
                    weeklyChangeKg: -0.25,
                    calorieAdjustment: -300,
                    proteinMultiplier: 2.0
                ),
                NutritionPlan(
                    name: "Moderate Cut",
                    description: "Steady progress with good energy",
                    icon: "flame.fill",
                    iconColor: .orange,
                    durationWeeks: 12,
                    weeklyChangeKg: -0.5,
                    calorieAdjustment: -500,
                    proteinMultiplier: 2.0
                ),
                NutritionPlan(
                    name: "Aggressive Cut",
                    description: "Larger deficit for faster progress",
                    icon: "bolt.fill",
                    iconColor: .red,
                    durationWeeks: 8,
                    weeklyChangeKg: -0.75,
                    calorieAdjustment: -750,
                    proteinMultiplier: 2.0
                ),
                NutritionPlan(
                    name: "Custom Plan",
                    description: "Set your own calorie and macro targets",
                    icon: "slider.horizontal.3",
                    iconColor: .gray,
                    durationWeeks: 0,
                    weeklyChangeKg: 0,
                    calorieAdjustment: 0,
                    proteinMultiplier: 1.6,
                    isCustom: true
                )
            ]
        case .gainWeight:
            availablePlans = [
                NutritionPlan(
                    name: "Steady Gain",
                    description: "Gradual weight gain for health",
                    icon: "arrow.up.circle.fill",
                    iconColor: .blue,
                    durationWeeks: 16,
                    weeklyChangeKg: 0.3,
                    calorieAdjustment: 350,
                    proteinMultiplier: 2.0
                ),
                NutritionPlan(
                    name: "Moderate Gain",
                    description: "Balanced caloric surplus",
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .purple,
                    durationWeeks: 12,
                    weeklyChangeKg: 0.5,
                    calorieAdjustment: 500,
                    proteinMultiplier: 2.0
                ),
                NutritionPlan(
                    name: "Custom Plan",
                    description: "Set your own calorie and macro targets",
                    icon: "slider.horizontal.3",
                    iconColor: .gray,
                    durationWeeks: 0,
                    weeklyChangeKg: 0,
                    calorieAdjustment: 0,
                    proteinMultiplier: 1.6,
                    isCustom: true
                )
            ]
        case .maintainWeight:
            availablePlans = [
                NutritionPlan(
                    name: "Maintain",
                    description: "Stay at your current weight",
                    icon: "equal.circle.fill",
                    iconColor: .blue,
                    durationWeeks: 0,
                    weeklyChangeKg: 0,
                    calorieAdjustment: 0,
                    proteinMultiplier: 1.6
                ),
                NutritionPlan(
                    name: "Body Recomp",
                    description: "Build muscle while losing fat",
                    icon: "arrow.triangle.swap",
                    iconColor: .purple,
                    durationWeeks: 12,
                    weeklyChangeKg: 0,
                    calorieAdjustment: 0,
                    proteinMultiplier: 2.0
                ),
                NutritionPlan(
                    name: "Custom Plan",
                    description: "Set your own calorie and macro targets",
                    icon: "slider.horizontal.3",
                    iconColor: .gray,
                    durationWeeks: 0,
                    weeklyChangeKg: 0,
                    calorieAdjustment: 0,
                    proteinMultiplier: 1.6,
                    isCustom: true
                )
            ]
        case .improveHealth:
            availablePlans = [
                NutritionPlan(
                    name: "Balanced Nutrition",
                    description: "Focus on whole foods & nutrients",
                    icon: "heart.fill",
                    iconColor: .red,
                    durationWeeks: 0,
                    weeklyChangeKg: 0,
                    calorieAdjustment: 0,
                    proteinMultiplier: 1.4
                ),
                NutritionPlan(
                    name: "Active Lifestyle",
                    description: "Support for increased activity",
                    icon: "figure.run",
                    iconColor: .green,
                    durationWeeks: 0,
                    weeklyChangeKg: 0,
                    calorieAdjustment: 200,
                    proteinMultiplier: 1.6
                ),
                NutritionPlan(
                    name: "Custom Plan",
                    description: "Set your own calorie and macro targets",
                    icon: "slider.horizontal.3",
                    iconColor: .gray,
                    durationWeeks: 0,
                    weeklyChangeKg: 0,
                    calorieAdjustment: 0,
                    proteinMultiplier: 1.6,
                    isCustom: true
                )
            ]
        }
        
        // Select first plan by default
        if selectedPlan == nil {
            selectedPlan = availablePlans.first
        }
    }
    
    private func calculateMaintenanceCalories() -> Int? {
        // Mifflin-St Jeor equation
        let bmr: Double
        if selectedGender == .male {
            bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) + 5
        } else {
            bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) - 161
        }
        
        let activityMultiplier: Double
        switch selectedActivity {
        case .sedentary: activityMultiplier = 1.2
        case .lightlyActive: activityMultiplier = 1.375
        case .moderate: activityMultiplier = 1.55
        case .veryActive: activityMultiplier = 1.725
        case .extraActive: activityMultiplier = 1.9
        }
        
        return Int(bmr * activityMultiplier)
    }
    
    // MARK: - Step 12: Personal Plan Summary
    private var personalPlanStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Animated checkmark
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                }
                .padding(.top, 40)
                
                // Title
                VStack(spacing: 8) {
                    Text("Your Plan Is Ready")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Based on your unique profile")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            
            // Plan summary card
            VStack(spacing: 16) {
                if let plan = selectedPlan, let maintenance = calculateMaintenanceCalories() {
                    let targetCalories = maintenance + plan.calorieAdjustment
                    let proteinGrams = Int(weightKg * plan.proteinMultiplier)
                    let proteinCalories = proteinGrams * 4
                    let remainingCalories = targetCalories - proteinCalories
                    let carbCalories = Int(Double(remainingCalories) * 0.55)
                    let carbGrams = carbCalories / 4
                    let fatCalories = targetCalories - proteinCalories - carbCalories
                    let fatGrams = fatCalories / 9
                    
                    PlanSummaryRow(
                        icon: plan.icon,
                        iconColor: plan.iconColor,
                        title: "Your Plan",
                        value: plan.name
                    )
                    
                    // Show calories if tracking
                    if selectedMetrics.contains(.calories) {
                        PlanSummaryRow(
                            icon: "flame.fill",
                            iconColor: .orange,
                            title: "Daily Calories",
                            value: "\(targetCalories) kcal"
                        )
                    }
                    
                    // Show protein if tracking
                    if selectedMetrics.contains(.protein) {
                        PlanSummaryRow(
                            icon: "p.circle.fill",
                            iconColor: .red,
                            title: "Protein Target",
                            value: "\(proteinGrams)g"
                        )
                    }
                    
                    // Show carbs if tracking
                    if selectedMetrics.contains(.carbs) {
                        PlanSummaryRow(
                            icon: "c.circle.fill",
                            iconColor: .green,
                            title: "Carbs Target",
                            value: "\(carbGrams)g"
                        )
                    }
                    
                    // Show fat if tracking
                    if selectedMetrics.contains(.fat) {
                        PlanSummaryRow(
                            icon: "f.circle.fill",
                            iconColor: .purple,
                            title: "Fat Target",
                            value: "\(fatGrams)g"
                        )
                    }
                    
                    if plan.durationWeeks > 0 {
                        Divider()
                        
                        // Phase timeline preview
                        let endDate = Calendar.current.date(byAdding: .weekOfYear, value: plan.durationWeeks, to: Date()) ?? Date()
                        let goalWeight = weightKg + (plan.weeklyChangeKg * Double(plan.durationWeeks))
                        let phaseColor: Color = plan.weeklyChangeKg < 0 ? .red : (plan.weeklyChangeKg > 0 ? .green : .blue)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(phaseColor)
                                Text("Your Phase Timeline")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                            }
                            
                            // Timeline visualization
                            HStack(spacing: 0) {
                                // Start
                                VStack(spacing: 4) {
                                    Text("Today")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.1fkg", weightKg))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 60)
                                
                                // Progress line
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 4)
                                    
                                    Rectangle()
                                        .fill(phaseColor)
                                        .frame(width: 20, height: 4)
                                }
                                .frame(maxWidth: .infinity)
                                .overlay(
                                    Text("\(plan.durationWeeks)w")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .offset(y: -12)
                                )
                                
                                // End
                                VStack(spacing: 4) {
                                    Text(endDate.formatted(.dateTime.month(.abbreviated).day()))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.1fkg", goalWeight))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(phaseColor)
                                }
                                .frame(width: 60)
                            }
                            .padding(.vertical, 8)
                            
                            Text("This phase will be added to your weight tracking")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(phaseColor.opacity(0.08))
                        )
                    }
                }
                
                Divider()
                
                PlanSummaryRow(
                    icon: "square.grid.2x2",
                    iconColor: Color(hex: "#35b8ff"),
                    title: "Tracking",
                    value: "\(selectedMetrics.count) metrics"
                )
            }
            .padding(20)
            .background(GlassCard(cornerRadius: 20))
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Step 13: Building Your Experience
    private var buildingStep: some View {
        let features = [
            BuildingFeature(
                icon: "square.grid.2x2.fill",
                title: "Personalised Dashboard",
                description: "Your metrics, arranged exactly how you want them",
                color: Color(hex: "#35b8ff")
            ),
            BuildingFeature(
                icon: "eye.fill",
                title: "Metric Visibility Control",
                description: "Show what matters, hide what doesn't",
                color: .purple
            ),
            BuildingFeature(
                icon: "leaf.fill",
                title: "Processed Food Tracking",
                description: "NOVA scores help you make informed choices",
                color: .green
            ),
            BuildingFeature(
                icon: "chart.line.uptrend.xyaxis",
                title: "Smart Weight Trends",
                description: "AI-powered phase detection for your journey",
                color: .orange
            )
        ]
        
        return VStack(spacing: 32) {
            Spacer()
            
            // Animated loading indicator
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 100, height: 100)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: buildingProgress)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#35b8ff"), Color(hex: "#35b8ff").opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                
                // Center icon
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "#35b8ff"))
                    .rotationEffect(.degrees(buildingProgress * 360))
            }
            
            // Title
            VStack(spacing: 8) {
                Text("Building Your Experience")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Personalising NutriBase just for you...")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            // Feature showcase - swipeable carousel
            ZStack {
                ForEach(0..<features.count, id: \.self) { index in
                    if index == currentFeatureIndex {
                        let feature = features[index]
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(feature.color.opacity(0.15))
                                    .frame(width: 70, height: 70)
                                
                                Image(systemName: feature.icon)
                                    .font(.system(size: 32))
                                    .foregroundColor(feature.color)
                            }
                            
                            Text(feature.title)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text(feature.description)
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.appInsetBackground)
                                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: buildingSwipeDirection).combined(with: .opacity),
                            removal: .move(edge: buildingSwipeDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                        ))
                    }
                }
            }
            .frame(height: 200)
            .contentShape(Rectangle())
            .padding(.horizontal, 24)
            .gesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        if horizontal < -30 {
                            buildingSwipeDirection = .trailing
                            withAnimation(.easeInOut(duration: 0.7)) {
                                currentFeatureIndex = (currentFeatureIndex + 1) % features.count
                            }
                            startBuildingCarouselTimer(featureCount: features.count)
                        } else if horizontal > 30 {
                            buildingSwipeDirection = .leading
                            withAnimation(.easeInOut(duration: 0.7)) {
                                currentFeatureIndex = (currentFeatureIndex - 1 + features.count) % features.count
                            }
                            startBuildingCarouselTimer(featureCount: features.count)
                        }
                    }
            )
            
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<features.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentFeatureIndex ? Color(hex: "#35b8ff") : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentFeatureIndex ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: currentFeatureIndex)
                }
            }
            
            Spacer()
        }
        .onAppear {
            startBuildingAnimation(featureCount: features.count)
        }
        .onDisappear {
            buildingCarouselTimer?.invalidate()
        }
    }
    
    private func startBuildingAnimation(featureCount: Int) {
        // Reset state
        buildingProgress = 0
        currentFeatureIndex = 0
        
        let totalDuration: Double = 6.0 // Total time for the "loading"
        
        // Animate progress bar
        withAnimation(.linear(duration: totalDuration)) {
            buildingProgress = 1.0
        }
        
        // Start feature carousel timer
        startBuildingCarouselTimer(featureCount: featureCount)
        
        // Pre-load app data while the user watches the building animation
        preloadAppData()
        
        // Auto-advance to dashboard setup step
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.5) {
            buildingCarouselTimer?.invalidate()
            withAnimation {
                currentStep = .dashboardSetup
            }
        }
    }
    
    private func preloadAppData() {
        DispatchQueue.global(qos: .userInitiated).async {
            // Touch shared singletons to trigger their lazy initialization
            _ = FoodLogManager.shared
            _ = WeightLogManager.shared
            _ = WeightPhaseManager.shared
            _ = DailyNutritionCache.shared
            _ = UserProfile.shared
            
            DispatchQueue.main.async {
                // Pre-warm nutrition cache for faster dashboard rendering
                DailyNutritionCache.shared.prewarmCommonDates()
                
                print("[Onboarding] Pre-loaded app data during building animation")
            }
        }
    }
    
    private func startBuildingCarouselTimer(featureCount: Int) {
        buildingCarouselTimer?.invalidate()
        buildingCarouselTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            buildingSwipeDirection = .trailing
            withAnimation(.easeInOut(duration: 0.7)) {
                currentFeatureIndex = (currentFeatureIndex + 1) % featureCount
            }
        }
    }
    
    // MARK: - Step 14: Dashboard Setup
    private var dashboardSetupStep: some View {
        VStack(spacing: 0) {
            EmbeddedDashboardEditorView(
                cardOrder: $onboardingCardOrder,
                hiddenCards: $onboardingHiddenCards,
                onShowWidgetStorage: {
                    showingOnboardingWidgetStorage = true
                },
                cardViewProvider: { cardType in
                    EditorCardViewProvider.cardView(for: cardType, isWeightChartExpanded: true)
                },
                isWeightChartExpanded: true,
                headerView: AnyView(onboardingDashboardHeader),
                headerHeight: 80,
                footerView: AnyView(onboardingDashboardFooter),
                footerHeight: 60
            )
        }
        .onAppear {
            setupOnboardingDashboardCards()
        }
        .sheet(isPresented: $showingOnboardingWidgetStorage) {
            WidgetStorageView(
                cardOrder: $onboardingCardOrder,
                hiddenCards: $onboardingHiddenCards
            )
        }
    }
    
    private var onboardingDashboardHeader: some View {
        VStack(spacing: 0) {
            Text("Your Dashboard")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Drag to arrange, tap ─ to remove")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.horizontal, 24)
    }
    
    private var onboardingDashboardFooter: some View {
        HStack(spacing: 16) {
            Button(action: goBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.appInsetBackground)
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                )
            }
            
            Spacer()
            
            Button(action: goNext) {
                HStack(spacing: 6) {
                    Text("Looks Good!")
                        .font(.system(size: 16, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "#35b8ff"))
                        .shadow(color: Color(hex: "#35b8ff").opacity(0.3), radius: 8, y: 4)
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
    
    private func populateOnboardingPreviewData() {
        let data = CapturedCardData.shared
        
        // MARK: Weight card - use onboarding weight
        data.currentWeight = weightKg
        data.hasWeightData = true
        data.weightUnit = "kg"
        
        // MARK: Calorie & macro targets from selected plan
        let maintenance = calculateMaintenanceCalories() ?? 2000
        let targetCalories: Int
        let proteinGrams: Int
        let carbGrams: Int
        let fatGrams: Int
        
        if let plan = selectedPlan {
            targetCalories = maintenance + plan.calorieAdjustment
            proteinGrams = Int(weightKg * plan.proteinMultiplier)
            let proteinCalories = proteinGrams * 4
            let remainingCalories = max(0, targetCalories - proteinCalories)
            let rawFatGrams = Int(Double(remainingCalories) * 0.25 / 9)
            let minFatGrams = Int(weightKg * 0.25)
            fatGrams = max(rawFatGrams, minFatGrams)
            let fatCalories = fatGrams * 9
            carbGrams = max(0, (targetCalories - proteinCalories - fatCalories) / 4)
            
            // Weekly weight rate based on plan deficit/surplus
            data.weeklyWeightRate = Double(plan.calorieAdjustment) / 1100.0
        } else {
            targetCalories = maintenance
            proteinGrams = Int(weightKg * 1.6)
            fatGrams = Int(Double(maintenance) * 0.30 / 9)
            carbGrams = Int(Double(maintenance) * 0.45 / 4)
            data.weeklyWeightRate = 0.0
        }
        
        data.calorieTarget = targetCalories
        data.proteinTarget = proteinGrams
        data.carbsTarget = carbGrams
        data.fatTarget = fatGrams
        data.fibreTarget = 30
        data.stepsTarget = 10000
        
        // MARK: Sample "today" consumption (~70% of targets)
        data.caloriesConsumed = Int(Double(targetCalories) * 0.72)
        data.proteinConsumed = Int(Double(proteinGrams) * 0.65)
        data.carbsConsumed = Int(Double(carbGrams) * 0.70)
        data.fatConsumed = Int(Double(fatGrams) * 0.68)
        data.fibreConsumed = 21
        data.stepsCount = 7500
        
        // MARK: Weekly bar chart data (sample variation)
        let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
        let calFactors  = [0.85, 0.92, 0.78, 0.95, 0.88, 1.05, 0.72]
        let protFactors = [0.80, 0.88, 0.72, 0.90, 0.85, 0.95, 0.65]
        let carbFactors = [0.82, 0.90, 0.75, 0.92, 0.86, 1.00, 0.70]
        let fatFactors  = [0.78, 0.85, 0.70, 0.88, 0.82, 0.98, 0.68]
        let fibreFactors = [0.75, 0.80, 0.65, 0.85, 0.78, 0.90, 0.60]
        let stepValues  = [8200, 6500, 9800, 7200, 8800, 11000, 7500]
        
        data.weeklyCalorieData = (0..<7).map { i in (day: dayLetters[i], consumed: Int(Double(targetCalories) * calFactors[i])) }
        data.weeklyProteinData = (0..<7).map { i in (day: dayLetters[i], consumed: Int(Double(proteinGrams) * protFactors[i])) }
        data.weeklyCarbsData   = (0..<7).map { i in (day: dayLetters[i], consumed: Int(Double(carbGrams) * carbFactors[i])) }
        data.weeklyFatData     = (0..<7).map { i in (day: dayLetters[i], consumed: Int(Double(fatGrams) * fatFactors[i])) }
        data.weeklyFibreData   = (0..<7).map { i in (day: dayLetters[i], consumed: Int(30.0 * fibreFactors[i])) }
        data.weeklyStepsData   = (0..<7).map { i in (day: dayLetters[i], steps: stepValues[i]) }
        
        // MARK: Weight chart - forward projection for the phase duration
        // Starts at current weight today, ends at phase target weight
        let calendar = Calendar.current
        let today = Date()
        var chartPoints: [(date: Date, weight: Double)] = []
        let phaseWeeks = selectedPlan?.durationWeeks ?? 12
        let weeklyChange = selectedPlan?.weeklyChangeKg ?? 0.0
        let endWeight = weightKg + (weeklyChange * Double(phaseWeeks))
        
        for week in 0...phaseWeeks {
            if let date = calendar.date(byAdding: .weekOfYear, value: week, to: today) {
                let projectedWeight = weightKg + (weeklyChange * Double(week))
                chartPoints.append((date: date, weight: projectedWeight))
            }
        }
        data.weightChartPoints = chartPoints
        
        // Update weekly rate for the weight card subtitle
        data.weeklyWeightRate = weeklyChange
        
        // MARK: NOVA Groups - moderately positive (mostly unprocessed)
        data.novaDistribution = [1: 0.55, 2: 0.15, 3: 0.20, 4: 0.10]
        data.weeklyNovaData = dayLetters.map { day in
            (day: day, distribution: [1: 0.55, 2: 0.15, 3: 0.20, 4: 0.10])
        }
        
        // MARK: Nutri-Score - moderately positive (mostly A & B)
        data.nutriScoreDistribution = ["A": 0.43, "B": 0.31, "C": 0.16, "D": 0.06, "E": 0.02]
        data.weeklyNutriScoreData = dayLetters.map { day in
            (day: day, distribution: ["A": 0.43, "B": 0.31, "C": 0.16, "D": 0.06, "E": 0.02])
        }
        
        // MARK: Gut Health - moderately positive
        data.gutHealthScore = 72.0
        data.fiberScore = 65.0
        data.upfScore = 40.0
        data.fermentedScore = 50.0
        data.fatQualityScore = 60.0
    }
    
    private func setupOnboardingDashboardCards() {
        // Only set up once (avoid re-initializing when view re-appears)
        guard onboardingCardOrder.isEmpty else { return }
        
        // Populate CapturedCardData with preview values for the editor cards
        populateOnboardingPreviewData()
        
        var cards: [CardType] = []
        var hidden: [CardType] = []
        
        // Set weight chart to expanded (2×3) mode for onboarding
        UserDefaults.standard.set(WeightChartSizeMode.expanded.rawValue, forKey: "weightChartSizeMode")
        
        // Current weight at the top
        cards.append(.currentWeight)
        
        // Add nutrition cards based on tracking preferences
        if selectedMetrics.contains(.calories) { cards.append(.calorieTarget) }
        if selectedMetrics.contains(.protein) { cards.append(.protein) }
        if selectedMetrics.contains(.carbs) { cards.append(.carbs) }
        if selectedMetrics.contains(.fat) { cards.append(.fat) }
        if selectedMetrics.contains(.fiber) { cards.append(.fibre) }
        
        // Steps after fibre
        if selectedMetrics.contains(.steps) { cards.append(.activity) }
        
        // Add food quality cards
        if selectedMetrics.contains(.novaScore) { cards.append(.novaGroups) }
        if selectedMetrics.contains(.nutriScore) { cards.append(.nutriScore) }
        if selectedMetrics.contains(.gutHealth) { cards.append(.gutHealth) }
        
        // Weight chart at the bottom (expanded 2×3)
        cards.append(.weightChart)
        
        // Daily goals always starts in hidden/available widgets
        hidden.append(.dailyGoals)
        
        // Any card types not added to dashboard go to hidden
        let allCardTypes: [CardType] = [.currentWeight, .weightChart, .calorieTarget, .protein, .carbs, .fat, .fibre, .activity, .novaGroups, .nutriScore, .gutHealth, .dailyGoals]
        for cardType in allCardTypes {
            if !cards.contains(cardType) && !hidden.contains(cardType) {
                hidden.append(cardType)
            }
        }
        
        onboardingCardOrder = cards
        onboardingHiddenCards = hidden
    }
    
    private func saveDashboardLayout() {
        // Save the card order to UserDefaults
        if let encodedData = try? JSONEncoder().encode(onboardingCardOrder) {
            UserDefaults.standard.set(encodedData, forKey: "dashboardCardOrder")
        }
        // Save hidden cards to UserDefaults
        if let encodedHidden = try? JSONEncoder().encode(onboardingHiddenCards) {
            UserDefaults.standard.set(encodedHidden, forKey: "dashboardHiddenCards")
        }
    }
    
    // MARK: - Step 15: Email Verification
    private var emailVerificationStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Email icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "#35b8ff").opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: "#35b8ff"))
                }
                .padding(.top, 16)
                
                VStack(spacing: 8) {
                    Text("One Last Step!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Verify your email to unlock all features")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                
                // Email display
                if let email = FirebaseAuthService.shared.currentUser?.email {
                    VStack(spacing: 4) {
                        Text("We've sent a verification link to:")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        Text(email)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                
                // Benefits of verifying
                VStack(alignment: .leading, spacing: 14) {
                    Text("Why verify?")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(Color(hex: "#35b8ff"))
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Cloud Backup")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Your data syncs across devices")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.green)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Account Recovery")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Reset your password if you forget it")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Full Access")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Unlock all premium features")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(16)
                .background(GlassCard(cornerRadius: 16))
                .padding(.horizontal, 24)
                
                // Action buttons
                VStack(spacing: 10) {
                    Button(action: checkVerificationAndContinue) {
                        Text("I've Verified My Email")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(hex: "#35b8ff"))
                            )
                    }
                    
                    Button(action: resendVerificationEmail) {
                        Text("Resend Verification Email")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#35b8ff"))
                    }
                    
                    Button(action: skipVerificationForNow) {
                        Text("Skip for now")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
        }
        .alert("Verification Status", isPresented: $showingVerificationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(verificationAlertMessage)
        }
    }
    
    // MARK: - Step 16: Complete
    private var completeStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success animation
            ZStack {
                // Confetti effect
                ForEach(0..<12, id: \.self) { index in
                    Circle()
                        .fill(confettiColor(index))
                        .frame(width: 8, height: 8)
                        .offset(confettiOffset(index))
                        .opacity(showConfetti ? 1 : 0)
                        .animation(.easeOut(duration: 1).delay(Double(index) * 0.05), value: showConfetti)
                }
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                    .scaleEffect(showConfetti ? 1 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showConfetti)
            }
            
            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Your nutrition journey starts now")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            
            // What happens next
            VStack(alignment: .leading, spacing: 16) {
                Text("What happens next:")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                NextStepRow(icon: "magnifyingglass", text: "Search or scan foods to log meals")
                NextStepRow(icon: "chart.line.uptrend.xyaxis", text: "Track your weight & see trends")
                NextStepRow(icon: "star.fill", text: "Discover food quality scores")
                NextStepRow(icon: "flame.fill", text: "Hit your daily targets")
            }
            .padding(20)
            .background(GlassCard(cornerRadius: 16))
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Start button
            Button(action: completeOnboarding) {
                HStack(spacing: 8) {
                    Text("Let's Go!")
                        .font(.system(size: 18, weight: .bold))
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "#35b8ff"))
                        .shadow(color: Color(hex: "#35b8ff").opacity(0.3), radius: 12, y: 6)
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            // Reset and trigger confetti animation
            showConfetti = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
            }
        }
    }
    
    // MARK: - Helper Functions
    private var canContinue: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .privacy:
            // Require all consent toggles AND terms agreement
            return termsAgreed && crashReportingConsent && analyticsConsent && healthKitConsent
        case .region:
            return !selectedRegion.isEmpty
        case .activity:
            return true
        case .goal:
            return selectedGoal != nil
        case .age:
            return age >= 13 && age <= 100
        case .gender:
            return true
        case .height:
            return heightCm >= 100 && heightCm <= 250
        case .weight:
            return weightKg >= 30 && weightKg <= 200
        case .planSelection:
            return selectedPlan != nil
        case .trackingPreferences:
            return !selectedMetrics.isEmpty
        case .personalPlan, .building, .dashboardSetup, .emailVerification, .complete:
            return true
        }
    }
    
    private func goNext() {
        // Save dashboard layout when leaving the dashboard setup step
        if currentStep == .dashboardSetup {
            saveDashboardLayout()
        }
        
        if currentStep.rawValue < PremiumOnboardingStep.allCases.count - 1 {
            currentStep = PremiumOnboardingStep(rawValue: currentStep.rawValue + 1)!
        }
    }
    
    private func goBack() {
        if currentStep.rawValue > 0 {
            currentStep = PremiumOnboardingStep(rawValue: currentStep.rawValue - 1)!
        }
    }
    
    private func checkVerificationAndContinue() {
        // Reload user to get latest verification status
        FirebaseAuthService.shared.checkEmailVerification()
        
        // Give it a moment to update, then check
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if FirebaseAuthService.shared.isEmailVerified {
                // Email verified - sync profile and continue to complete
                UserProfile.shared.saveToFirebase()
                currentStep = .complete
            } else {
                verificationAlertMessage = "Email not verified yet. Please check your inbox and spam folder, then tap the verification link."
                showingVerificationAlert = true
            }
        }
    }
    
    private func resendVerificationEmail() {
        FirebaseAuthService.shared.sendVerificationEmail { success, error in
            if success {
                verificationAlertMessage = "Verification email sent! Check your inbox."
            } else {
                verificationAlertMessage = error ?? "Failed to send verification email"
            }
            showingVerificationAlert = true
        }
    }
    
    private func skipVerificationForNow() {
        // Allow user to skip but profile won't sync until verified
        currentStep = .complete
    }
    
    private func skipToQuickSetup() {
        // Skip to region selection
        currentStep = .region
    }
    
    private func detectRegion() {
        let locale = Locale.current
        if let regionCode = locale.region?.identifier {
            let regionMap: [String: String] = [
                "US": "United States",
                "GB": "United Kingdom",
                "CA": "Canada",
                "AU": "Australia",
                "FR": "France",
                "DE": "Germany",
                "ES": "Spain",
                "IT": "Italy",
                "NL": "Netherlands",
                "BE": "Belgium",
                "CH": "Switzerland",
                "SE": "Sweden",
                "NO": "Norway",
                "DK": "Denmark",
                "IE": "Ireland",
                "NZ": "New Zealand"
            ]
            detectedRegion = regionMap[regionCode] ?? "All Regions"
            if selectedRegion.isEmpty {
                selectedRegion = detectedRegion
            }
        } else {
            detectedRegion = "All Regions"
            if selectedRegion.isEmpty {
                selectedRegion = "All Regions"
            }
        }
    }
    
    private func startLogoPulse() {
        logoPulse = true
    }
    
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    private func importFromHealthKit() {
        // TODO: Implement HealthKit import
        hapticFeedback(.medium)
    }
    
    private func calculateDailyCalories() -> Int? {
        let bmr: Double
        switch selectedGender {
        case .male:
            bmr = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
        case .female:
            bmr = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
        case .notSpecified:
            let maleBMR = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
            let femaleBMR = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
            bmr = (maleBMR + femaleBMR) / 2
        }
        
        let tdee = bmr * selectedActivity.multiplier
        var finalCalories = tdee
        if let goal = selectedGoal {
            finalCalories = tdee * (1 + goal.calorieModifier)
        }
        
        return Int(finalCalories.rounded())
    }
    
    private func calculateMacros(calories: Int) -> (protein: Int, carbs: Int, fat: Int)? {
        let proteinCalories = Double(calories) * 0.25
        let carbCalories = Double(calories) * 0.45
        let fatCalories = Double(calories) * 0.30
        
        return (
            protein: Int((proteinCalories / 4).rounded()),
            carbs: Int((carbCalories / 4).rounded()),
            fat: Int((fatCalories / 9).rounded())
        )
    }
    
    private func confettiColor(_ index: Int) -> Color {
        let colors: [Color] = [.green, .blue, .orange, .pink, .purple, .yellow]
        return colors[index % colors.count]
    }
    
    private func confettiOffset(_ index: Int) -> CGSize {
        let angle = Double(index) * (360.0 / 12.0) * .pi / 180
        let radius: Double = showConfetti ? 80 : 0
        return CGSize(
            width: Foundation.cos(angle) * radius,
            height: Foundation.sin(angle) * radius
        )
    }
    
    private func saveUserProfile() {
        // In test mode, don't persist any profile changes
        if isTestMode {
            print("🧪 Test mode - skipping profile save")
            return
        }
        UserProfile.shared.dateOfBirth = dateOfBirth
        UserProfile.shared.gender = selectedGender
        UserProfile.shared.heightCm = heightCm
        UserProfile.shared.weightKg = weightKg
        UserProfile.shared.activityLevel = selectedActivity
        
        // Save region preference to UserProfile (which syncs to Firebase)
        UserProfile.shared.preferredRegion = selectedRegion
        
        UserDefaults.standard.set(analyticsConsent, forKey: "analyticsEnabled")
        UserDefaults.standard.set(crashReportingConsent, forKey: "crashReportingEnabled")
        UserDefaults.standard.set(healthKitConsent, forKey: "healthKitEnabled")
        UserDefaults.standard.set(true, forKey: "termsAccepted")
        UserDefaults.standard.set(true, forKey: "privacyPolicyAccepted")
        UserDefaults.standard.set(Date(), forKey: "consentDate")
        
        // Calculate calories based on selected plan
        if let plan = selectedPlan, let maintenance = calculateMaintenanceCalories() {
            let targetCalories = maintenance + plan.calorieAdjustment
            UserProfile.shared.dailyCalorieGoal = targetCalories
            
            // Calculate macros based on plan's protein multiplier
            let proteinGrams = Int(weightKg * plan.proteinMultiplier)
            let proteinCalories = proteinGrams * 4
            let remainingCalories = max(0, targetCalories - proteinCalories)
            // Fat = 25% of remaining calories after protein, with floor of 0.25g/kg bodyweight
            let fatFromPercentage = Int(Double(remainingCalories) * 0.25) / 9
            let fatFloor = Int(weightKg * 0.25)
            let fatGrams = max(fatFromPercentage, fatFloor)
            let fatCalories = fatGrams * 9
            // Carbs = remaining calories after protein and fat
            let carbGrams = max(0, targetCalories - proteinCalories - fatCalories) / 4
            
            UserProfile.shared.proteinGoalGrams = proteinGrams
            UserProfile.shared.carbGoalGrams = carbGrams
            UserProfile.shared.fatGoalGrams = fatGrams
            
            // Save plan details
            UserDefaults.standard.set(plan.name, forKey: "selectedPlanName")
            UserDefaults.standard.set(plan.durationWeeks, forKey: "selectedPlanDuration")
            UserDefaults.standard.set(plan.weeklyChangeKg, forKey: "selectedPlanWeeklyChange")
            
            // Create a weight phase from the selected plan if it has a duration (only once)
            if plan.durationWeeks > 0 && !hasCreatedPhase {
                let startDate = Date()
                let endDate = Calendar.current.date(byAdding: .weekOfYear, value: plan.durationWeeks, to: startDate) ?? startDate
                
                // Determine phase color based on plan type
                let phaseColor: PhaseColor
                if plan.weeklyChangeKg < 0 {
                    phaseColor = .pink // Cutting
                } else if plan.weeklyChangeKg > 0 {
                    phaseColor = .green // Bulking
                } else {
                    phaseColor = .blue // Maintenance
                }
                
                // Calculate goal weight
                let totalWeightChange = plan.weeklyChangeKg * Double(plan.durationWeeks)
                let goalWeight = weightKg + totalWeightChange
                
                let phase = WeightPhase(
                    name: plan.name,
                    description: plan.description,
                    startDate: startDate,
                    endDate: endDate,
                    targetWeeklyRate: plan.weeklyChangeKg,
                    color: phaseColor,
                    notes: nil,
                    goalWeight: goalWeight
                )
                
                WeightPhaseManager.shared.addPhase(phase)
                hasCreatedPhase = true
                print("📅 Created weight phase: \(plan.name) for \(plan.durationWeeks) weeks")
            }
        } else if let calories = calculateDailyCalories() {
            UserProfile.shared.dailyCalorieGoal = calories
            if let macros = calculateMacros(calories: calories) {
                UserProfile.shared.proteinGoalGrams = macros.protein
                UserProfile.shared.carbGoalGrams = macros.carbs
                UserProfile.shared.fatGoalGrams = macros.fat
            }
        }
        
        // Save selected tracking metrics
        let metricStrings = selectedMetrics.map { $0.rawValue }
        UserDefaults.standard.set(metricStrings, forKey: "selectedTrackingMetrics")
        
        // Map to card types based on selected metrics
        let cardTypes: [CardType] = selectedMetrics.compactMap { metric in
            switch metric {
            case .calories: return .calorieTarget
            case .protein: return .protein
            case .weight: return .currentWeight
            case .steps: return .activity
            case .novaScore: return .novaGroups
            case .nutriScore: return .nutriScore
            case .gutHealth: return .gutHealth
            default: return nil
            }
        }
        let cardTypeStrings = (cardTypes + [.weightChart]).map { $0.rawValue }
        UserDefaults.standard.set(cardTypeStrings, forKey: "onboardingSelectedCards")
        
        // Delay setting hasCompletedOnboarding to allow this view to dismiss gracefully
        // before the app switches to email verification or main content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set(Date(), forKey: "onboardingCompletionDate")
            // Clear the new user flag now that onboarding is complete
            UserDefaults.standard.set(false, forKey: "isNewUser")
            
            print("✅ Premium onboarding completed!")
            print("📊 Selected metrics: \(selectedMetrics.map { $0.rawValue })")
            if let plan = selectedPlan {
                print("📋 Selected plan: \(plan.name)")
            }
            
            // Sync profile to Firebase only after onboarding is complete
            // This ensures all data is collected before uploading
            if FirebaseAuthService.shared.isEmailVerified {
                print("📤 User verified - syncing profile to Firebase")
                UserProfile.shared.saveToFirebase()
            } else {
                print("⏳ User not yet verified - profile saved locally, will sync after verification")
            }
        }
    }
    
    private func completeOnboarding() {
        saveUserProfile()
        // The app will automatically transition to email verification or main content
        // after a brief delay (set in saveUserProfile) to allow smooth transition
    }
}

// MARK: - Supporting Views

// App-consistent background (adapts to dark mode)
struct OnboardingBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Color.appBackground
    }
}

// Alias for compatibility
struct PremiumGradientBackground: View {
    var body: some View {
        OnboardingBackground()
    }
}

// Card matching app design (adapts to dark mode)
struct OnboardingCard: View {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = 16
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(cardBackground)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// Alias for compatibility
struct GlassCard: View {
    var cornerRadius: CGFloat = 16
    
    var body: some View {
        OnboardingCard(cornerRadius: cornerRadius)
    }
}

struct WelcomeCard: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct BuildingFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct WelcomeCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let card: WelcomeCard
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: card.icon)
                .font(.system(size: 36))
                .foregroundColor(Color(hex: "#35b8ff"))
            
            Text(card.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            Text(card.description)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        )
    }
}

struct PrivacyCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let title: String
    let subtitle: String
    let isToggle: Bool
    @Binding var isOn: Bool
    var iconColor: Color = Color(hex: "#35b8ff")
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            if isToggle {
                Toggle("", isOn: $isOn)
                    .tint(Color(hex: "#35b8ff"))
                    .labelsHidden()
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 22))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        )
    }
}

struct RegionRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let name: String
    let flag: String
    let isSelected: Bool
    let isRecommended: Bool
    let onTap: () -> Void
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(flag)
                    .font(.system(size: 28))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if isRecommended {
                        Text("Recommended for you")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#35b8ff"))
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#35b8ff"))
                        .font(.system(size: 22))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardBackground)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color(hex: "#35b8ff") : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ActivityCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let activity: ActivityLevel
    let isSelected: Bool
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Activity illustration
            ZStack {
                Circle()
                    .fill(activity.iconColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: activity.icon)
                    .font(.system(size: 44))
                    .foregroundColor(activity.iconColor)
            }
            
            VStack(spacing: 8) {
                Text(activity.rawValue)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(activity.shortDescription)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardBackground)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(isSelected ? activity.iconColor : Color.clear, lineWidth: 3)
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct GoalCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let goal: HealthGoal
    let isSelected: Bool
    let onTap: () -> Void
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    private var motivationalText: String {
        switch goal {
        case .loseWeight: return "We'll build a sustainable calorie deficit"
        case .gainWeight: return "Healthy surplus for steady progress"
        case .maintainWeight: return "Support long-term consistency"
        case .buildMuscle: return "Balanced surplus to maximise growth"
        case .improveHealth: return "Focus on quality & balance"
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
                    .fill(cardBackground)
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

struct MicroStepContainer<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                
                content()
                    .frame(maxWidth: 500)
                
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct StepperButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemName: String
    let action: () -> Void
    
    private var buttonBackground: Color {
        Color.appCardBackground
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: "#35b8ff"))
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(buttonBackground)
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                )
        }
    }
}

struct GenderCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let gender: Gender
    let isSelected: Bool
    let onTap: () -> Void
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    private var icon: String {
        switch gender {
        case .male: return "figure.stand"
        case .female: return "figure.stand.dress"
        case .notSpecified: return "person.fill"
        }
    }
    
    private var iconColor: Color {
        switch gender {
        case .male: return .blue
        case .female: return .pink
        case .notSpecified: return .gray
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(iconColor)
                    .frame(width: 40)
                
                Text(gender.rawValue)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#35b8ff"))
                        .font(.system(size: 24))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
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

struct PresetCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let preset: TrackingPreset
    let isSelected: Bool
    let onTap: () -> Void
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    private var iconColor: Color {
        switch preset {
        case .simple: return .green
        case .balanced: return .blue
        case .advanced: return .purple
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: preset.icon)
                        .font(.system(size: 24))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(preset.description)
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
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
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

struct PlanSummaryRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

struct NextStepRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#35b8ff"))
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Plan Card
struct PlanCard: View {
    let plan: NutritionPlan
    let isSelected: Bool
    let baseCalories: Int
    let bodyWeight: Double
    let selectedMetrics: Set<TrackingMetric>
    let onTap: () -> Void
    
    private var targetCalories: Int {
        baseCalories + plan.calorieAdjustment
    }
    
    private var proteinGrams: Int {
        Int(bodyWeight * plan.proteinMultiplier)
    }
    
    private var fatGrams: Int {
        // Fat = 25% of remaining calories after protein, with floor of 0.25g/kg bodyweight
        let proteinCalories = proteinGrams * 4
        let remainingCalories = max(0, targetCalories - proteinCalories)
        let fatFromPercentage = Int(Double(remainingCalories) * 0.25) / 9
        let fatFloor = Int(bodyWeight * 0.25)
        return max(fatFromPercentage, fatFloor)
    }
    
    private var carbGrams: Int {
        // Carbs = remaining calories after protein and fat
        let proteinCalories = proteinGrams * 4
        let fatCalories = fatGrams * 9
        let carbCalories = max(0, targetCalories - proteinCalories - fatCalories)
        return carbCalories / 4
    }
    
    // Check which nutrition metrics are selected
    private var showCalories: Bool { selectedMetrics.contains(.calories) }
    private var showProtein: Bool { selectedMetrics.contains(.protein) }
    private var showCarbs: Bool { selectedMetrics.contains(.carbs) }
    private var showFat: Bool { selectedMetrics.contains(.fat) }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(plan.iconColor.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: plan.icon)
                        .font(.system(size: 28))
                        .foregroundColor(plan.iconColor)
                }
                
                // Title & description
                VStack(spacing: 6) {
                    Text(plan.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(plan.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Stats - show based on selected metrics
                VStack(spacing: 12) {
                    // First row: Calories and Protein (if selected)
                    let firstRowItems = [
                        showCalories ? AnyView(StatItem(icon: "flame.fill", value: "\(targetCalories)", label: "kcal/day", color: .orange)) : nil,
                        showProtein ? AnyView(StatItem(icon: "p.circle.fill", value: "\(proteinGrams)g", label: "protein", color: .red)) : nil
                    ].compactMap { $0 }
                    
                    if !firstRowItems.isEmpty {
                        HStack(spacing: 24) {
                            ForEach(0..<firstRowItems.count, id: \.self) { index in
                                firstRowItems[index]
                            }
                        }
                    }
                    
                    // Second row: Carbs and Fat (if selected)
                    let secondRowItems = [
                        showCarbs ? AnyView(StatItem(icon: "c.circle.fill", value: "\(carbGrams)g", label: "carbs", color: .green)) : nil,
                        showFat ? AnyView(StatItem(icon: "f.circle.fill", value: "\(fatGrams)g", label: "fat", color: .purple)) : nil
                    ].compactMap { $0 }
                    
                    if !secondRowItems.isEmpty {
                        HStack(spacing: 24) {
                            ForEach(0..<secondRowItems.count, id: \.self) { index in
                                secondRowItems[index]
                            }
                        }
                    }
                    
                    // Third row: Duration and weekly change (if plan has duration)
                    if plan.durationWeeks > 0 {
                        HStack(spacing: 24) {
                            StatItem(
                                icon: "calendar",
                                value: "\(plan.durationWeeks)",
                                label: "weeks",
                                color: .blue
                            )
                            
                            StatItem(
                                icon: plan.weeklyChangeKg >= 0 ? "arrow.up.right" : "arrow.down.right",
                                value: String(format: "%.2fkg", abs(plan.weeklyChangeKg)),
                                label: "/week",
                                color: plan.weeklyChangeKg >= 0 ? .green : .orange
                            )
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.appInsetBackground)
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

struct StatItem: View {
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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 70)
    }
}

// MARK: - Metric Category Card
struct MetricCategoryCard: View {
    let category: OnboardingMetricCategory
    @Binding var selectedMetrics: Set<TrackingMetric>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#35b8ff"))
                
                Text(category.rawValue)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Select all / none
                Button(action: toggleAll) {
                    Text(allSelected ? "Clear" : "All")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#35b8ff"))
                }
            }
            
            // Metrics grid - single column for Food Quality to avoid text truncation
            LazyVGrid(columns: category == .foodQuality ? [
                GridItem(.flexible())
            ] : [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(category.metrics, id: \.self) { metric in
                    MetricToggle(
                        metric: metric,
                        isSelected: selectedMetrics.contains(metric)
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appInsetBackground)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        )
    }
    
    private var allSelected: Bool {
        category.metrics.allSatisfy { selectedMetrics.contains($0) }
    }
    
    private func toggleAll() {
        if allSelected {
            category.metrics.forEach { selectedMetrics.remove($0) }
        } else {
            category.metrics.forEach { selectedMetrics.insert($0) }
        }
    }
}

struct MetricToggle: View {
    let metric: TrackingMetric
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: metric.icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? metric.iconColor : .gray)
                
                Text(metric.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? Color(hex: "#35b8ff") : .gray.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color(hex: "#35b8ff").opacity(0.08) : Color.gray.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color(hex: "#35b8ff").opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Onboarding Card Drop Delegate
// Uses the same approach as GridCardDropDelegate from the dashboard for consistency
struct OnboardingCardDropDelegate: DropDelegate {
    let card: DashboardCard
    @Binding var cards: [DashboardCard]
    @Binding var draggingCard: DashboardCard?
    
    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.text]).first else {
            draggingCard = nil
            return false
        }
        
        item.loadItem(forTypeIdentifier: UTType.text.identifier as String, options: nil) { (data, error) in
            DispatchQueue.main.async {
                guard let data = data as? Data,
                      let cardTypeRawValue = String(data: data, encoding: .utf8),
                      let draggedCardType = CardType(rawValue: cardTypeRawValue),
                      let draggedCard = cards.first(where: { $0.cardType == draggedCardType }),
                      let fromIndex = cards.firstIndex(of: draggedCard),
                      let toIndex = cards.firstIndex(of: card) else {
                    draggingCard = nil
                    return
                }
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    if fromIndex != toIndex {
                        cards.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                        HapticManager.shared.lightFeedback()
                    }
                }
                draggingCard = nil
            }
        }
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Visual feedback only - actual reordering happens in performDrop
        guard let draggingCard = draggingCard,
              draggingCard.id != card.id else { return }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// Drop delegate for empty cells - inserts card at a specific position
struct OnboardingEmptyCellDropDelegate: DropDelegate {
    let insertIndex: Int
    @Binding var cards: [DashboardCard]
    @Binding var draggingCard: DashboardCard?
    
    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.text]).first else {
            draggingCard = nil
            return false
        }
        
        item.loadItem(forTypeIdentifier: UTType.text.identifier as String, options: nil) { (data, error) in
            DispatchQueue.main.async {
                guard let data = data as? Data,
                      let cardTypeRawValue = String(data: data, encoding: .utf8),
                      let draggedCardType = CardType(rawValue: cardTypeRawValue),
                      let draggedCard = cards.first(where: { $0.cardType == draggedCardType }),
                      let fromIndex = cards.firstIndex(of: draggedCard) else {
                    draggingCard = nil
                    return
                }
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    // Remove from old position and insert at new position
                    cards.remove(at: fromIndex)
                    let adjustedIndex = fromIndex < insertIndex ? insertIndex - 1 : insertIndex
                    let safeIndex = min(adjustedIndex, cards.count)
                    cards.insert(draggedCard, at: safeIndex)
                    HapticManager.shared.lightFeedback()
                }
                draggingCard = nil
            }
        }
        
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// MARK: - View Extension for Conditional Modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Static Helpers
extension PremiumOnboardingView {
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
        print("🔄 Premium onboarding reset - user can see onboarding again")
    }
}

// MARK: - Legal Document View
enum LegalDocumentType {
    case privacyPolicy
    case termsOfService
}

struct LegalDocumentView: View {
    let title: String
    let documentType: LegalDocumentType
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if documentType == .privacyPolicy {
                        privacyPolicyContent
                    } else {
                        termsOfServiceContent
                    }
                }
                .padding(24)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
    
    private var privacyPolicyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last Updated: December 2024")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            legalSection(title: "1. Information We Collect", content: """
            NutriBase collects and stores the following information locally on your device:
            • Personal information (age, gender, height, weight)
            • Dietary preferences and goals
            • Food logs and nutritional data
            • Weight tracking history
            
            If you choose to create an account, some data may be synced to our secure servers to enable cross-device access.
            """)
            
            legalSection(title: "2. How We Use Your Information", content: """
            We use your information to:
            • Provide personalized nutrition recommendations
            • Track your progress toward your health goals
            • Improve our app and services
            • Send you relevant notifications (if enabled)
            """)
            
            legalSection(title: "3. Data Storage & Security", content: """
            Your data is primarily stored locally on your device. If you enable cloud sync, your data is encrypted and stored securely. We implement industry-standard security measures to protect your information.
            """)
            
            legalSection(title: "4. Third-Party Services", content: """
            NutriBase may integrate with:
            • Apple Health (with your permission)
            • Analytics services (if you opt in)
            • Crash reporting services (if you opt in)
            
            These services have their own privacy policies.
            """)
            
            legalSection(title: "5. Your Rights", content: """
            You have the right to:
            • Access your personal data
            • Delete your account and data
            • Opt out of analytics and crash reporting
            • Export your data
            """)
            
            legalSection(title: "6. Contact Us", content: """
            If you have questions about this Privacy Policy, please contact us at support@nutribase.app
            """)
        }
    }
    
    private var termsOfServiceContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last Updated: December 2024")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            legalSection(title: "1. Acceptance of Terms", content: """
            By using NutriBase, you agree to these Terms of Service. If you do not agree, please do not use the app.
            """)
            
            legalSection(title: "2. Description of Service", content: """
            NutriBase is a nutrition tracking and health monitoring application. The app provides tools to log food, track weight, and monitor nutritional intake.
            """)
            
            legalSection(title: "3. Medical Disclaimer", content: """
            NutriBase is not a medical device and should not be used as a substitute for professional medical advice, diagnosis, or treatment. Always consult with a qualified healthcare provider before making changes to your diet or exercise routine.
            """)
            
            legalSection(title: "4. User Responsibilities", content: """
            You are responsible for:
            • Maintaining the accuracy of your information
            • Keeping your account credentials secure
            • Using the app in compliance with applicable laws
            • Not misusing or attempting to hack the service
            """)
            
            legalSection(title: "5. Intellectual Property", content: """
            All content, features, and functionality of NutriBase are owned by us and are protected by copyright, trademark, and other intellectual property laws.
            """)
            
            legalSection(title: "6. Limitation of Liability", content: """
            NutriBase is provided "as is" without warranties of any kind. We are not liable for any damages arising from your use of the app.
            """)
            
            legalSection(title: "7. Changes to Terms", content: """
            We may update these terms from time to time. Continued use of the app after changes constitutes acceptance of the new terms.
            """)
            
            legalSection(title: "8. Contact", content: """
            For questions about these Terms, contact us at support@nutribase.app
            """)
        }
    }
    
    private func legalSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(content)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
    }
}

// MARK: - Onboarding Weight Chart Preview
struct OnboardingWeightChartPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let startWeight: Double
    let endWeight: Double
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    private var sampleWeightData: [(date: Date, weight: Double)] {
        let calendar = Calendar.current
        let today = Date()
        var data: [(Date, Double)] = []
        
        // Generate 12 months of smooth declining weight data
        let totalDays = 365
        let weightLoss = startWeight - endWeight
        
        // Generate data every 3 days for smooth curve
        for i in stride(from: totalDays, through: 0, by: -3) {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let progress = Double(totalDays - i) / Double(totalDays)
            
            // Smooth exponential-like decline (slightly faster at start, slower at end)
            let smoothProgress = 1 - pow(1 - progress, 1.2)
            let weight = startWeight - (weightLoss * smoothProgress)
            
            data.append((date, weight))
        }
        
        return data
    }
    
    private var yAxisRange: ClosedRange<Double> {
        let weights = sampleWeightData.map { $0.weight }
        let minW = (weights.min() ?? endWeight) - 2
        let maxW = (weights.max() ?? startWeight) + 2
        return minW...maxW
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - matches FixedSizeCard title style
            HStack {
                Text("Weight Chart")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                    .padding(.trailing, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // Chart with Y-axis labels on left
            Chart(sampleWeightData, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(Color(hex: "#5ec5ff"))
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 1)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1.0))
                        .foregroundStyle(Color.gray.opacity(0.4))
                    AxisValueLabel(format: .dateTime.month(.narrow))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.black)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1.0))
                        .foregroundStyle(Color.gray.opacity(0.4))
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.black)
                }
            }
            .chartYScale(domain: yAxisRange)
            .frame(height: 280)
            .padding(.leading, 8)
            .padding(.trailing, 16)
            
            // Time frame buttons - matches dashboard styling, centered
            HStack(spacing: 8) {
                Spacer()
                ForEach(["1W", "1M", "3M", "1Y", "All"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(label == "1Y" ? .white : .blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(label == "1Y" ? Color.blue : Color.blue.opacity(0.1))
                        )
                }
                Spacer()
            }
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Preview
#Preview {
    PremiumOnboardingView()
}
