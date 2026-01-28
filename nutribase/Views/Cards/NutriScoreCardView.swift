import SwiftUI

// Custom wrapper to match the standard DashboardCardView styling
struct NutriScoreCardWrapper<Content: View>: View {
    let content: Content
    @Binding var showingDetailView: Bool
    @Binding var showingInfo: Bool
    let isPreview: Bool
    
    init(showingDetailView: Binding<Bool>, showingInfo: Binding<Bool>, isPreview: Bool = false, @ViewBuilder content: () -> Content) {
        self._showingDetailView = showingDetailView
        self._showingInfo = showingInfo
        self.isPreview = isPreview
        self.content = content()
    }
    
    var body: some View {
        // Don't pass tap actions in preview mode to allow drag gestures to work
        FixedSizeCard(
            title: "Nutri-Score",
            showInfoButton: !isPreview,
            onInfoTap: isPreview ? nil : { showingInfo = true },
            onCardTap: isPreview ? nil : { showingDetailView = true }
        ) {
            content
        }
    }
}

struct NutriScoreCardView: View {
    var isPreview: Bool = false
    
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    
    // State for showing the detailed view
    @State private var showingDetailView = false
    
    // Info button action
    @State private var showingInfo = false
    
    // Cached data to avoid recalculating on every render
    @State private var cachedWeeklyNutriScores: [(day: String, grades: [String: Int])] = []
    @State private var lastEntriesCount: Int = 0
    
    // Preview data
    private var previewWeeklyNutriScores: [(day: String, grades: [String: Int])] {
        [
            (day: "S", grades: ["a": 3, "b": 2, "c": 1, "d": 0, "e": 0]),
            (day: "S", grades: ["a": 2, "b": 3, "c": 1, "d": 1, "e": 0]),
            (day: "M", grades: ["a": 4, "b": 2, "c": 0, "d": 0, "e": 0]),
            (day: "T", grades: ["a": 2, "b": 2, "c": 2, "d": 1, "e": 0]),
            (day: "W", grades: ["a": 3, "b": 3, "c": 1, "d": 0, "e": 0]),
            (day: "T", grades: ["a": 5, "b": 1, "c": 1, "d": 0, "e": 0]),
            (day: "F", grades: ["a": 2, "b": 2, "c": 2, "d": 1, "e": 1])
        ]
    }
    
    // Use cached weekly Nutri-Scores
    private var weeklyNutriScores: [(day: String, grades: [String: Int])] {
        if isPreview { return previewWeeklyNutriScores }
        return cachedWeeklyNutriScores
    }
    
    // Calculate Nutri-Score distribution for the last 7 days
    private func calculateWeeklyNutriScores() -> [(day: String, grades: [String: Int])] {
        var scores: [(day: String, grades: [String: Int])] = []
        
        for daysAgo in (0..<7).reversed() {
            // Get the date for this day (last 7 days)
            let date = getDateForLastDays(daysAgo: daysAgo)
            
            // Get day letter
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: date)
            let dayLetters = ["S", "M", "T", "W", "T", "F", "S"] // Sunday = 1, Monday = 2, etc.
            let dayLetter = dayLetters[weekday - 1]
            
            // Get entries for this date (all meal types)
            let entries = getAllEntriesForDate(date)
            
            // Count entries by Nutri-Score grade
            var gradeCounts: [String: Int] = ["a": 0, "b": 0, "c": 0, "d": 0, "e": 0]
            
            for entry in entries {
                // Check if this is a meal - if so, count individual foods
                if entry.foodItem.isMeal, let savedMeal = SavedMealsManager.shared.meals.first(where: { $0.name == entry.foodItem.name }) {
                    for mealFood in savedMeal.foods {
                        if let grade = mealFood.nutriScoreGrade?.lowercased(), ["a", "b", "c", "d", "e"].contains(grade) {
                            gradeCounts[grade, default: 0] += 1
                        }
                    }
                } else {
                    // Regular food item
                    if let grade = entry.foodItem.nutriScoreGrade?.lowercased(), ["a", "b", "c", "d", "e"].contains(grade) {
                        gradeCounts[grade, default: 0] += 1
                    }
                }
            }
            
            scores.append((day: dayLetter, grades: gradeCounts))
        }
        
        return scores
    }
    
    // Calculate weekly percentages for each Nutri-Score grade
    private var weeklyGradePercentages: [String: Double] {
        var totalCounts: [String: Int] = ["a": 0, "b": 0, "c": 0, "d": 0, "e": 0]
        var totalItems = 0
        
        for dayData in weeklyNutriScores {
            for (grade, count) in dayData.grades {
                totalCounts[grade, default: 0] += count
                totalItems += count
            }
        }
        
        var percentages: [String: Double] = [:]
        for (grade, count) in totalCounts {
            percentages[grade] = totalItems > 0 ? (Double(count) / Double(totalItems) * 100.0) : 0.0
        }
        
        return percentages
    }
    
    // Calculate the percentage of high-quality foods (A and B grades)
    private var highQualityPercentage: Double {
        let percentages = weeklyGradePercentages
        return (percentages["a"] ?? 0.0) + (percentages["b"] ?? 0.0)
    }
    
    // Calculate the percentage of low-quality foods (D and E grades)
    private var lowQualityPercentage: Double {
        let percentages = weeklyGradePercentages
        return (percentages["d"] ?? 0.0) + (percentages["e"] ?? 0.0)
    }
    
    var body: some View {
        NutriScoreCardWrapper(showingDetailView: $showingDetailView, showingInfo: $showingInfo, isPreview: isPreview) {
            // Main content with 25%/75% split layout
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left side: Grade percentages centered at 25% from left
                    VStack(spacing: 3) {
                        gradePercentageRow(grade: "A", percentage: weeklyGradePercentages["a"] ?? 0, color: .green)
                        gradePercentageRow(grade: "B", percentage: weeklyGradePercentages["b"] ?? 0, color: .blue)
                        gradePercentageRow(grade: "C", percentage: weeklyGradePercentages["c"] ?? 0, color: .yellow)
                        gradePercentageRow(grade: "D", percentage: weeklyGradePercentages["d"] ?? 0, color: .orange)
                        gradePercentageRow(grade: "E", percentage: weeklyGradePercentages["e"] ?? 0, color: .red)
                    }
                    .frame(width: geometry.size.width * 0.5, alignment: .center)
                    
                    // Right side: Weekday bars centered at 75% from left
                    HStack(alignment: .bottom, spacing: 6) {
                        // Show all 7 days in order (oldest to newest, left to right)
                        ForEach(Array(weeklyNutriScores.enumerated()), id: \.offset) { index, dayData in
                            NutriScoreStackedDayBar(day: dayData.day, grades: dayData.grades)
                        }
                    }
                    .frame(width: geometry.size.width * 0.5, alignment: .center)
                }
            }
            .frame(height: 80)
        }
        .sheet(isPresented: $showingDetailView) {
            NutriScoreDetailView()
        }
        .sheet(isPresented: $showingInfo) {
            NutriScoreInfoView()
        }
        .allowsHitTesting(!isPreview)
        .onAppear {
            updateCacheIfNeeded()
        }
        .onChange(of: foodLogManager.entries.count) { _, _ in
            updateCacheIfNeeded()
        }
    }
    
    // Update cache only when entries change
    private func updateCacheIfNeeded() {
        guard !isPreview else { return }
        let currentCount = foodLogManager.entries.count
        if currentCount != lastEntriesCount || cachedWeeklyNutriScores.isEmpty {
            cachedWeeklyNutriScores = calculateWeeklyNutriScores()
            lastEntriesCount = currentCount
        }
    }
    
    // Get date for X days ago
    private func getDateForLastDays(daysAgo: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
    }
    
    // Helper function to create individual grade percentage rows
    private func gradePercentageRow(grade: String, percentage: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(grade)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 12, alignment: .leading)
            
            Text("\(Int(percentage))%")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    // Helper function to create a percentage view with inactive state handling
    private func percentageView(value: Double, label: String, color: Color) -> some View {
        let isInactive = value == 0.0
        
        return HStack(alignment: .center, spacing: 4) {
            Text("\(Int(value))%")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isInactive ? color.opacity(0.3) : color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(isInactive ? .secondary.opacity(0.5) : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .opacity(isInactive ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isInactive)
    }
    
    // Get the date for a specific day abbreviation in the current week (Monday to Sunday)
    private func getDateForDay(_ day: String) -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        // Get the start of the current week (Monday)
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday == 1 ? 6 : weekday - 2 // Adjust for Monday start (weekday 1 = Sunday, 2 = Monday)
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
            return today
        }
        
        // Map day string to weekday integer (0 = Monday, 1 = Tuesday, etc.)
        let dayMap = ["M": 0, "Tu": 1, "W": 2, "Th": 3, "F": 4, "Sa": 5, "Su": 6]
        guard let dayOffset = dayMap[day] else { return today }
        
        // Create a date for the target day in the current week
        return calendar.date(byAdding: .day, value: dayOffset, to: currentWeekStart) ?? today
    }
    
    // Helper to get all entries for a date across all meal types
    private func getAllEntriesForDate(_ date: Date) -> [FoodEntry] {
        // Common meal types in the app
        let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snacks"]
        
        // Collect entries from all meal types
        var allEntries: [FoodEntry] = []
        for mealType in mealTypes {
            allEntries.append(contentsOf: foodLogManager.entries(for: date, mealType: mealType))
        }
        
        return allEntries
    }
}

struct NutriScoreStackedDayBar: View {
    let day: String
    let grades: [String: Int]
    
    private let nutriScoreColors: [String: Color] = [
        "a": Color(hex: "#22e83d"),      // Grade A - bright green
        "b": Color(hex: "#8eff00"),      // Grade B - lime green  
        "c": Color(hex: "#f4df70"),      // Grade C - yellow
        "d": Color(hex: "#ffb300"),      // Grade D - orange
        "e": Color(hex: "#ff5722")       // Grade E - red
    ]
    
    private var totalEntries: Int {
        grades.values.reduce(0, +)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Stacked bar
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.systemGray5))
                    .frame(width: 12, height: 48)
                
                // Stacked segments (bottom to top: A, B, C, D, E)
                if totalEntries > 0 {
                    VStack(spacing: 0) {
                        ForEach(["a", "b", "c", "d", "e"], id: \.self) { grade in
                            let count = grades[grade] ?? 0
                            if count > 0 {
                                let heightPercentage = CGFloat(count) / CGFloat(totalEntries)
                                Rectangle()
                                    .fill(nutriScoreColors[grade] ?? .gray)
                                    .frame(height: 48 * heightPercentage)
                            }
                        }
                    }
                    .frame(width: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            
            Text(day)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct NutriScoreDayBar: View {
    let day: String
    let grade: String
    
    // Nutri-Score color based on grade
    private var gradeColor: Color {
        switch grade.lowercased() {
        case "a": return .green
        case "b": return .blue
        case "c": return .yellow
        case "d": return .orange
        case "e": return .red
        default: return .gray
        }
    }
    
    // Calculate bar height based on grade (A=highest, E=lowest)
    private var barHeight: CGFloat {
        switch grade.lowercased() {
        case "a": return 43.0
        case "b": return 34.0
        case "c": return 25.0
        case "d": return 16.0
        case "e": return 7.0
        default: return 0.0
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Background bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(.systemGray5))
                .frame(width: 12, height: 48)
                .overlay(
                    // Colored bar based on grade
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        
                        // Only show colored bar if we have a valid grade (a-e)
                        if ["a", "b", "c", "d", "e"].contains(grade.lowercased()) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(gradeColor)
                                .frame(width: 12, height: barHeight)
                        }
                    }
                )
            
            Text(day)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct NutriScoreInfoView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text("About Nutri-Score")
                        .font(.headline)
                    
                    // Description
                    Text("Nutri-Score is a nutrition label that converts the nutritional value of products into a simple code consisting of 5 letters, each with its own color.")
                    
                    // Grade A
                    gradeInfoView(grade: "A", title: "Excellent nutritional quality", description: "Products with high nutritional value, typically unprocessed foods like fruits, vegetables, and lean proteins.", color: .green)
                    
                    // Grade B
                    gradeInfoView(grade: "B", title: "Good nutritional quality", description: "Products with good nutritional value, often minimally processed foods with moderate levels of nutrients.", color: .blue)
                    
                    // Grade C
                    gradeInfoView(grade: "C", title: "Average nutritional quality", description: "Products with average nutritional value, typically processed foods with balanced nutrient profiles.", color: .yellow)
                    
                    // Grade D
                    gradeInfoView(grade: "D", title: "Poor nutritional quality", description: "Products with poor nutritional value, often highly processed foods with unfavorable nutrient profiles.", color: .orange)
                    
                    // Grade E
                    gradeInfoView(grade: "E", title: "Very poor nutritional quality", description: "Products with very poor nutritional value, typically ultra-processed foods high in sugar, salt, and fat.", color: .red)
                    
                    // Footer
                    Text("The Nutri-Score is calculated based on a formula that considers both favorable (protein, fiber, fruits, vegetables) and unfavorable (calories, saturated fat, sugar, salt) components.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Nutri-Score")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // Helper function to create consistent grade info views
    private func gradeInfoView(grade: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
                
                Text(grade)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct NutriScoreDetailView: View {
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    
    private var viewBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    private var barEmptyBackground: Color {
        colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)
    }
    
    @State private var currentWeekOffset: Int = 0
    @State private var scrolledWeekID: Int? = 0
    @State private var animationOpacity: Double = 1.0
    @State private var isLoading: Bool = true
    
    // Cache for weekly data to avoid recalculating on every render
    @State private var weeklyDataCache: [Int: WeeklyNutriScoreData] = [:]
    
    // Struct to hold pre-computed weekly data
    struct WeeklyNutriScoreData {
        let gradeCounts: [String: Int]  // a, b, c, d, e -> count
        let score: Double               // 0-100 weighted score
        let dailyData: [String: [String: Int]]  // Day -> grade -> count
    }
    
    // Colors for each Nutri-Score grade
    private let nutriScoreColors: [Color] = [
        Color(hex: "#22e83d"),      // Grade A - bright green
        Color(hex: "#8eff00"),      // Grade B - lime green  
        Color(hex: "#f4df70"),      // Grade C - yellow
        Color(hex: "#ffb300"),      // Grade D - orange
        Color(hex: "#ff5722")       // Grade E - red
    ]
    
    // Names for each Nutri-Score grade
    private let nutriScoreGradeNames = [
        "Excellent",
        "Good", 
        "Average",
        "Poor",
        "Very Poor"
    ]
    
    // Gauge colors (red to green, left to right - lower scores are red, higher scores are green)
    private let gaugeColors: [Color] = [
        Color(hex: "#ff5722"),      // Red (0-20) - Grade E
        Color(hex: "#ffb300"),      // Orange (20-40) - Grade D
        Color(hex: "#f4df70"),      // Yellow (40-60) - Grade C
        Color(hex: "#8eff00"),      // Lime (60-80) - Grade B
        Color(hex: "#22e83d")       // Green (80-100) - Grade A
    ]
    
    // Helper function to get all entries for a date across all meal types
    private func getAllEntriesForDate(_ date: Date) -> [FoodEntry] {
        // Common meal types in the app
        let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snacks"]
        
        // Collect entries from all meal types
        var allEntries: [FoodEntry] = []
        for mealType in mealTypes {
            allEntries.append(contentsOf: foodLogManager.entries(for: date, mealType: mealType))
        }
        
        return allEntries
    }
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        
        NavigationView {
            ZStack {
                viewBackground
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading Nutri-Score data...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Week selector carousel
                        weekSelectorCarousel
                        
                        // Nutri-Score Gauge Card
                        nutriScoreGaugeCard(for: currentWeekOffset)
                            .padding(.horizontal)
                        
                        // Weekly chart card (single card that updates based on selected week)
                        weeklyChartCard(for: currentWeekOffset)
                            .padding(.horizontal)
                            .opacity(animationOpacity)
                    
                    // Nutri-Score grade percentages
                    VStack(alignment: .leading, spacing: 16) {
                        // Title
                        Text("Nutri-Score Grade Distribution")
                            .font(.headline)
                            
                        // Grade percentages grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(0..<5) { index in
                                let grade = ["a", "b", "c", "d", "e"][index]
                                nutriScoreGradePercentageView(
                                    percentage: calculateWeeklyPercentage(for: grade, weekOffset: currentWeekOffset),
                                    gradeName: nutriScoreGradeNames[index],
                                    color: nutriScoreColors[index],
                                    grade: grade.uppercased()
                                )
                            }
                        }
                    }
                    .opacity(animationOpacity)
                    .padding(.horizontal)
                    
                    // Nutri-Score explanation
                    nutriScoreExplanationView
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("Nutri-Score Details")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                await precomputeInitialData()
            }
        }
    }
    
    // MARK: - Data Precomputation
    
    private func precomputeInitialData() async {
        // Compute current week first
        let currentData = await computeWeeklyData(for: 0)
        await MainActor.run {
            weeklyDataCache[0] = currentData
            isLoading = false
        }
        
        // Pre-compute adjacent weeks in background
        Task.detached(priority: .background) {
            let lastWeekData = await self.computeWeeklyData(for: -1)
            await MainActor.run {
                self.weeklyDataCache[-1] = lastWeekData
            }
        }
    }
    
    private func computeWeeklyData(for weekOffset: Int) async -> WeeklyNutriScoreData {
        let days = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
        let grades = ["a", "b", "c", "d", "e"]
        let weights: [Double] = [100, 75, 50, 25, 0]
        
        var gradeCounts: [String: Int] = ["a": 0, "b": 0, "c": 0, "d": 0, "e": 0]
        var dailyData: [String: [String: Int]] = [:]
        
        for (index, day) in days.enumerated() {
            let date = getDateForDay(index, weekOffset: weekOffset)
            let entries = getAllEntriesForDate(date)
            
            var dayCounts: [String: Int] = ["a": 0, "b": 0, "c": 0, "d": 0, "e": 0]
            
            for entry in entries {
                if entry.foodItem.isMeal, let savedMeal = SavedMealsManager.shared.meals.first(where: { $0.name == entry.foodItem.name }) {
                    for mealFood in savedMeal.foods {
                        if let grade = mealFood.nutriScoreGrade?.lowercased(), grades.contains(grade) {
                            gradeCounts[grade, default: 0] += 1
                            dayCounts[grade, default: 0] += 1
                        }
                    }
                } else {
                    if let grade = entry.foodItem.nutriScoreGrade?.lowercased(), grades.contains(grade) {
                        gradeCounts[grade, default: 0] += 1
                        dayCounts[grade, default: 0] += 1
                    }
                }
            }
            
            dailyData[day] = dayCounts
        }
        
        // Calculate weighted score
        var totalWeighted: Double = 0
        var totalCount: Double = 0
        
        for (index, grade) in grades.enumerated() {
            let count = Double(gradeCounts[grade] ?? 0)
            totalWeighted += count * weights[index]
            totalCount += count
        }
        
        let score = totalCount > 0 ? totalWeighted / totalCount : 0
        
        return WeeklyNutriScoreData(
            gradeCounts: gradeCounts,
            score: score,
            dailyData: dailyData
        )
    }
    
    // MARK: - Nutri-Score Gauge
    
    // Get cached score or compute if not available
    private func calculateNutriScore(for weekOffset: Int) -> Double {
        if let cached = weeklyDataCache[weekOffset] {
            return cached.score
        }
        return 0
    }
    
    // Get cached grade count
    private func getCachedGradeCount(for grade: String, weekOffset: Int) -> Int {
        if let cached = weeklyDataCache[weekOffset] {
            return cached.gradeCounts[grade] ?? 0
        }
        return 0
    }
    
    // Get score color based on value
    private func getScoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return gaugeColors[4] // Green (A)
        case 60..<80: return gaugeColors[3]  // Lime (B)
        case 40..<60: return gaugeColors[2]  // Yellow (C)
        case 20..<40: return gaugeColors[1]  // Orange (D)
        default: return gaugeColors[0]       // Red (E)
        }
    }
    
    // Nutri-Score Gauge Card
    private func nutriScoreGaugeCard(for weekOffset: Int) -> some View {
        let score = calculateNutriScore(for: weekOffset)
        
        return VStack(spacing: 8) {
            // Title
            HStack {
                Text("Nutri-Score")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            
            // Gauge
            VStack(spacing: 0) {
                NutriScoreGauge(score: score, gaugeColors: gaugeColors)
                    .frame(height: 120)
                
                // Score display below the gauge
                Text("\(Int(score))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(getScoreColor(score))
                    .offset(y: -20)
            }
            .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    // Get count of a specific grade for a week
    private func getWeeklyGradeCount(for grade: String, weekOffset: Int) -> Int {
        var total = 0
        let days = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
        
        for (index, _) in days.enumerated() {
            let date = getDateForDay(index, weekOffset: weekOffset)
            let entries = getAllEntriesForDate(date)
            
            for entry in entries {
                if entry.foodItem.isMeal, let savedMeal = SavedMealsManager.shared.meals.first(where: { $0.name == entry.foodItem.name }) {
                    for mealFood in savedMeal.foods {
                        if mealFood.nutriScoreGrade?.lowercased() == grade {
                            total += 1
                        }
                    }
                } else {
                    if entry.foodItem.nutriScoreGrade?.lowercased() == grade {
                        total += 1
                    }
                }
            }
        }
        
        return total
    }
    
    // Get date for a specific day index within a week offset
    private func getDateForDay(_ dayIndex: Int, weekOffset: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        // Get the start of the current week (Monday)
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday == 1 ? 6 : weekday - 2
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
            return today
        }
        
        // Apply week offset
        guard let targetWeekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart) else {
            return today
        }
        
        return calendar.date(byAdding: .day, value: dayIndex, to: targetWeekStart) ?? today
    }
    
    // MARK: - Week Selector Carousel
    
    private var weekSelectorCarousel: some View {
        let cardWidth: CGFloat = 170
        
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(-10...0, id: \.self) { offset in
                    weekSelectorCard(for: offset)
                        .frame(width: cardWidth)
                        .id(offset)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrolledWeekID)
        .scrollTargetBehavior(.viewAligned)
        .safeAreaPadding(.horizontal, (UIScreen.main.bounds.width - cardWidth) / 2)
        .defaultScrollAnchor(.trailing)
        .onChange(of: scrolledWeekID) { oldValue, newValue in
            if let newValue = newValue, newValue != currentWeekOffset {
                updateCurrentWeek(to: newValue)
            }
        }
        .frame(height: 50)
    }
    
    private func weekSelectorCard(for offset: Int) -> some View {
        let isSelected = offset == currentWeekOffset
        
        return Text(weekDateRangeString(for: offset))
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "#35b8ff") : cardBackground)
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrolledWeekID = offset
                }
            }
    }
    
    // MARK: - Week Update Animation
    
    // Helper function to update current week with animation
    private func updateCurrentWeek(to offset: Int) {
        if currentWeekOffset != offset {
            withAnimation(.easeInOut(duration: 0.2)) {
                animationOpacity = 0.8
            }
            
            // Load data for new week if not cached
            Task(priority: .userInitiated) {
                if weeklyDataCache[offset] == nil {
                    let data = await computeWeeklyData(for: offset)
                    await MainActor.run {
                        weeklyDataCache[offset] = data
                    }
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                currentWeekOffset = offset
                withAnimation(.easeInOut(duration: 0.2)) {
                    animationOpacity = 1.0
                }
            }
        }
    }
    
    // Create a complete card for a specific week offset
    private func weeklyChartCard(for offset: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card header with week navigation
            HStack {
                Text("Weekly Average")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Date display
                Text(weekDateRangeString(for: offset))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            
            // Weekly chart for the specific week
            weeklyNutriScoreChart(for: offset)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    // Create the stacked bar chart for a specific week offset
    private func weeklyNutriScoreChart(for offset: Int) -> some View {
        VStack(spacing: 20) {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    // Main chart content
                    HStack(alignment: .bottom, spacing: 0) {
                        // Y-axis labels
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("100%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(height: geometry.size.height / 5)
                            Text("75%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(height: geometry.size.height / 5)
                            Text("50%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(height: geometry.size.height / 5)
                            Text("25%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(height: geometry.size.height / 5)
                            Text("0%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(height: geometry.size.height / 5)
                        }
                        .frame(width: 40)
                        
                        // Chart area
                        ZStack(alignment: .bottom) {
                            // Grid lines
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(0..<5) { i in
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 1)
                                        .frame(maxWidth: .infinity)
                                    
                                    if i < 4 {
                                        Spacer()
                                            .frame(height: geometry.size.height / 5 - 1)
                                    }
                                }
                            }
                            .frame(height: geometry.size.height)
                            
                            // Bars
                            HStack(alignment: .bottom, spacing: 0) {
                                ForEach(getDaysOfWeek(for: offset), id: \.self) { day in
                                    VStack(spacing: 4) {
                                        let hasEntries = hasFoodEntriesForDay(day, weekOffset: offset)
                                        
                                        // Stacked bar
                                        ZStack(alignment: .bottom) {
                                            // Background
                                            Rectangle()
                                                .fill(barEmptyBackground)
                                                .frame(height: geometry.size.height * 0.8)
                                            
                                            // Stacked segments
                                            VStack(spacing: 0) {
                                                if hasEntries {
                                                    // Draw segments from bottom to top (Grade A at bottom, Grade E at top)
                                                    let segments = ["a", "b", "c", "d", "e"].map { grade -> (grade: String, height: CGFloat) in
                                                        let height = calculateBarSegmentHeight(
                                                            day: day,
                                                            grade: grade,
                                                            maxHeight: geometry.size.height,
                                                            weekOffset: offset
                                                        )
                                                        return (grade: grade, height: height)
                                                    }
                                                    
                                                    // Draw in order (Grade A at bottom)
                                                    ForEach(segments.indices, id: \.self) { index in
                                                        let segment = segments[index]
                                                        Rectangle()
                                                            .fill(nutriScoreColors[index])
                                                            .frame(height: segment.height)
                                                    }
                                                } else {
                                                    // Empty placeholder for days with no entries
                                                    Rectangle()
                                                        .fill(Color.clear)
                                                        .frame(height: 0)
                                                }
                                            }
                                        }
                                        .frame(width: 30)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        
                                        // Day label
                                        Text(day)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 180)
            
            // Legend
            HStack(spacing: 16) {
                ForEach(0..<5) { index in
                    let grade = ["A", "B", "C", "D", "E"][index]
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(nutriScoreColors[index])
                            .frame(width: 12, height: 12)
                        
                        Text("Grade \(grade)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // Nutri-Score grade percentages view
    private func nutriScoreGradePercentageView(percentage: Double, gradeName: String, color: Color, grade: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(Int(percentage))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text("\(grade) - \(gradeName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    // Nutri-Score explanation view
    private var nutriScoreExplanationView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About Nutri-Score Classification")
                .font(.headline)
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                nutriScoreGradeExplanation(
                    grade: "A",
                    name: "Excellent nutritional quality",
                    description: "Products with high nutritional value, typically unprocessed foods like fruits, vegetables, and lean proteins.",
                    color: nutriScoreColors[0]
                )
                
                nutriScoreGradeExplanation(
                    grade: "B", 
                    name: "Good nutritional quality",
                    description: "Products with good nutritional value, often minimally processed foods with moderate levels of nutrients.",
                    color: nutriScoreColors[1]
                )
                
                nutriScoreGradeExplanation(
                    grade: "C",
                    name: "Average nutritional quality", 
                    description: "Products with average nutritional value, typically processed foods with balanced nutrient profiles.",
                    color: nutriScoreColors[2]
                )
                
                nutriScoreGradeExplanation(
                    grade: "D",
                    name: "Poor nutritional quality",
                    description: "Products with poor nutritional value, often highly processed foods with unfavorable nutrient profiles.",
                    color: nutriScoreColors[3]
                )
                
                nutriScoreGradeExplanation(
                    grade: "E",
                    name: "Very poor nutritional quality",
                    description: "Products with very poor nutritional value, typically ultra-processed foods high in sugar, salt, and fat.",
                    color: nutriScoreColors[4]
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    // Nutri-Score grade explanation item
    private func nutriScoreGradeExplanation(grade: String, name: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Grade indicator
            Text(grade)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(color)
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Get days of week in order (Monday to Sunday)
    private func getDaysOfWeek(for offset: Int = 0) -> [String] {
        return ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
    }
    
    // Calculate the bar segment height for a specific day and Nutri-Score grade
    private func calculateBarSegmentHeight(day: String, grade: String, maxHeight: CGFloat, weekOffset: Int = 0) -> CGFloat {
        let percentage = calculateDailyPercentage(for: day, grade: grade, weekOffset: weekOffset)
        return CGFloat(percentage / 100.0) * (maxHeight * 0.8) // Adjust to 80% of max height to align with grid lines
    }
    
    // Calculate the percentage of items from a specific Nutri-Score grade for a specific day
    private func calculateDailyPercentage(for day: String, grade: String, weekOffset: Int = 0) -> Double {
        // Get the date for the specified day with the correct week offset
        let date = getDateForDay(day, weekOffset: weekOffset)
        
        // Get all entries for that date
        let entries = getAllEntriesForDate(date)
        
        // If no entries, return 0
        if entries.isEmpty {
            return 0
        }
        
        // Count total items and grade items, expanding meals
        var totalItems = 0
        var gradeItems = 0
        
        for entry in entries {
            if entry.foodItem.isMeal, let savedMeal = SavedMealsManager.shared.meals.first(where: { $0.name == entry.foodItem.name }) {
                for mealFood in savedMeal.foods {
                    if let foodGrade = mealFood.nutriScoreGrade?.lowercased(), ["a", "b", "c", "d", "e"].contains(foodGrade) {
                        totalItems += 1
                        if foodGrade == grade {
                            gradeItems += 1
                        }
                    }
                }
            } else {
                if let entryGrade = entry.foodItem.nutriScoreGrade?.lowercased(), ["a", "b", "c", "d", "e"].contains(entryGrade) {
                    totalItems += 1
                    if entryGrade == grade {
                        gradeItems += 1
                    }
                }
            }
        }
        
        // Calculate percentage
        return totalItems > 0 ? (Double(gradeItems) / Double(totalItems) * 100.0) : 0
    }
    
    // Check if there are any food entries for a specific day
    private func hasFoodEntriesForDay(_ day: String, weekOffset: Int = 0) -> Bool {
        let date = getDateForDay(day, weekOffset: weekOffset)
        let entries = getAllEntriesForDate(date)
        return !entries.isEmpty
    }
    
    // Get dominant grade for a specific day
    private func getDominantGrade(for day: String, weekOffset: Int = 0) -> String {
        let date = getDateForDay(day, weekOffset: weekOffset)
        let entries = getAllEntriesForDate(date)
        
        var gradeCounts: [String: Int] = ["a": 0, "b": 0, "c": 0, "d": 0, "e": 0]
        
        for entry in entries {
            if entry.foodItem.isMeal, let savedMeal = SavedMealsManager.shared.meals.first(where: { $0.name == entry.foodItem.name }) {
                for mealFood in savedMeal.foods {
                    if let grade = mealFood.nutriScoreGrade?.lowercased(), ["a", "b", "c", "d", "e"].contains(grade) {
                        gradeCounts[grade, default: 0] += 1
                    }
                }
            } else {
                if let grade = entry.foodItem.nutriScoreGrade?.lowercased(), ["a", "b", "c", "d", "e"].contains(grade) {
                    gradeCounts[grade, default: 0] += 1
                }
            }
        }
        
        let sortedGrades = gradeCounts.sorted { $0.value > $1.value }
        return sortedGrades.first?.key ?? "?"
    }
    
    // Calculate the weekly percentage for a specific grade with a specific week offset - uses cached data
    private func calculateWeeklyPercentage(for grade: String, weekOffset: Int = 0) -> Double {
        // Use cached data if available for performance
        if let cached = weeklyDataCache[weekOffset] {
            let gradeCount = cached.gradeCounts[grade] ?? 0
            let totalItems = cached.gradeCounts.values.reduce(0, +)
            return totalItems > 0 ? (Double(gradeCount) / Double(totalItems) * 100.0) : 0
        }
        return 0
    }
    
    // Get the date range string for a specific week offset
    private func weekDateRangeString(for offset: Int = 0) -> String {
        let calendar = Calendar.current
        let today = Date()
        
        // Use calendar week approach for all weeks (Monday to Sunday)
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday == 1 ? 6 : weekday - 2 // Adjust for Monday start (weekday 1 = Sunday, 2 = Monday)
        
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
            return "Week of \(formatDate(today))"
        }
        
        // Apply the week offset
        guard let selectedWeekStart = calendar.date(byAdding: .day, value: 7 * offset, to: currentWeekStart),
              let selectedWeekEnd = calendar.date(byAdding: .day, value: 6, to: selectedWeekStart) else {
            return "Week of \(formatDate(today))"
        }
        
        return "\(formatDate(selectedWeekStart)) - \(formatDate(selectedWeekEnd))"
    }
    
    // Format date as MMM d (e.g., "Jul 23")
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    // Get the date for a specific day abbreviation in the selected week
    private func getDateForDay(_ day: String, weekOffset: Int = 0) -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        // Use calendar week approach for all weeks (Monday to Sunday)
        // Get the start of the current week (Monday)
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday == 1 ? 6 : weekday - 2 // Adjust for Monday start (weekday 1 = Sunday, 2 = Monday)
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
            return today
        }
        
        // Apply the week offset to get the selected week's start date
        guard let selectedWeekStart = calendar.date(byAdding: .day, value: 7 * weekOffset, to: currentWeekStart) else {
            return today
        }
        
        // Map day string to weekday integer (0 = Monday, 1 = Tuesday, etc.)
        let dayMap = ["M": 0, "Tu": 1, "W": 2, "Th": 3, "F": 4, "Sa": 5, "Su": 6]
        guard let dayOffset = dayMap[day] else { return today }
        
        // Create a date for the target day in the selected week
        return calendar.date(byAdding: .day, value: dayOffset, to: selectedWeekStart) ?? today
    }
    
    // Helper function to determine weekday order (Monday to Sunday)
    private func weekdayOrder(_ day: String) -> Int {
        let order = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
        return order.firstIndex(of: day) ?? 0
    }
    
    // Helper function to create vertical bar for a day
    private func nutriScoreDayBar(day: String, gradePercentages: [String: Double]) -> some View {
        // Determine the dominant grade for this day
        let dominantGrade = gradePercentages.max(by: { $0.value < $1.value })?.key ?? "?"
        let gradeColor = getGradeColor(grade: dominantGrade)
        
        return VStack(spacing: 4) {
            Text(day)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Background bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray5))
                .frame(width: 8, height: 60)
                .overlay(
                    // Colored bar based on grade
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        
                        // Only show colored bar if we have a valid grade (a-e)
                        if ["a", "b", "c", "d", "e"].contains(dominantGrade.lowercased()) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(gradeColor)
                                .frame(width: 8, height: getBarHeight(grade: dominantGrade))
                        }
                    }
                )
        }
    }
    
    // Calculate bar height based on grade (A=highest, E=lowest)
    private func getBarHeight(grade: String) -> CGFloat {
        switch grade.lowercased() {
        case "a": return 60.0
        case "b": return 48.0
        case "c": return 36.0
        case "d": return 24.0
        case "e": return 12.0
        default: return 0.0
        }
    }
    
    // Get color for a grade
    private func getGradeColor(grade: String) -> Color {
        switch grade.lowercased() {
        case "a":
            return Color(hex: "#22e83d")  // Match NOVA Group 1 color
        case "b":
            return Color(hex: "#8eff00")  // Match NOVA Group 2 color
        case "c":
            return Color(hex: "#f4df70")  // Custom yellow color
        case "d":
            return Color(hex: "#ffb300")  // Match NOVA Group 3 color
        case "e":
            return Color(hex: "#ff5722")  // Match NOVA Group 4 color
        default:
            return .gray
        }
    }
    
    // Helper function to create Nutri-Score bar (unused after removing weekly average section)
    private func nutriScoreBar(grade: String, percentage: Double) -> some View {
        // This function is kept for reference but no longer used in the UI
        let gradeColor = getGradeColor(grade: grade)
        let gradeTitle: String
        
        switch grade.lowercased() {
        case "a":
            gradeTitle = "Excellent"
        case "b":
            gradeTitle = "Good"
        case "c":
            gradeTitle = "Average"
        case "d":
            gradeTitle = "Poor"
        case "e":
            gradeTitle = "Very Poor"
        default:
            gradeTitle = "Unknown"
        }
        
        return HStack(spacing: 12) {
            // Grade circle
            ZStack {
                Circle()
                    .fill(gradeColor)
                    .frame(width: 30, height: 30)
                
                Text(grade.uppercased())
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        
                        // Filled bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(gradeColor)
                            .frame(width: max(0, min(CGFloat(percentage) / 100 * geometry.size.width, geometry.size.width)), height: 8)
                    }
                }
                .frame(height: 8)
                
                // Label and percentage
                HStack {
                    Text(gradeTitle)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(Int(percentage))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(height: 40)
    }
}

// 240-degree gauge view with needle for Nutri-Score
struct NutriScoreGauge: View {
    let score: Double // 0-100
    let gaugeColors: [Color]
    
    // 240 degree arc: starts at 150° (bottom-left), ends at 30° (bottom-right)
    // 0 score = 150° (left), 100 score = 390° (30° = 360+30)
    private var needleRotation: Double {
        // Map 0-100 to 150 to 390 degrees (240 degree sweep)
        return 150.0 + (score / 100.0) * 240.0
    }
    
    var body: some View {
        GeometryReader { geometry in
            let centerY = geometry.size.height * 0.6 // Move center up a bit for 240° arc
            let center = CGPoint(x: geometry.size.width / 2, y: centerY)
            let radius = min(geometry.size.width / 2, geometry.size.height * 0.8) - 10
            let innerRadius = radius * 0.70
            let segmentAngle = 240.0 / 5.0 // 48 degrees per segment
            
            ZStack {
                // Draw colored segments (5 segments, 48 degrees each = 240/5)
                ForEach(0..<5, id: \.self) { index in
                    Path { path in
                        // Start at 150° (bottom-left), sweep 240° clockwise to 390° (30°)
                        let startAngle = Angle(degrees: 150.0 + Double(index) * segmentAngle)
                        let endAngle = Angle(degrees: 150.0 + Double(index + 1) * segmentAngle - 2) // Small gap
                        
                        path.addArc(center: center, radius: radius,
                                    startAngle: startAngle, endAngle: endAngle,
                                    clockwise: false)
                        path.addArc(center: center, radius: innerRadius,
                                    startAngle: endAngle, endAngle: startAngle,
                                    clockwise: true)
                        path.closeSubpath()
                    }
                    .fill(gaugeColors[index])
                }
                
                // Needle
                Path { path in
                    let needleLength = radius * 0.80
                    let needleWidth: CGFloat = 6
                    
                    // Needle pointer (triangle)
                    let angle = Angle(degrees: needleRotation).radians
                    let tipX = center.x + cos(angle) * needleLength
                    let tipY = center.y + sin(angle) * needleLength
                    
                    let leftAngle = angle + .pi / 2
                    let rightAngle = angle - .pi / 2
                    let baseLeftX = center.x + cos(leftAngle) * (needleWidth * 0.6)
                    let baseLeftY = center.y + sin(leftAngle) * (needleWidth * 0.6)
                    let baseRightX = center.x + cos(rightAngle) * (needleWidth * 0.6)
                    let baseRightY = center.y + sin(rightAngle) * (needleWidth * 0.6)
                    
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: baseLeftX, y: baseLeftY))
                    path.addLine(to: CGPoint(x: baseRightX, y: baseRightY))
                    path.closeSubpath()
                }
                .fill(Color(.label))
                
                // Center dot
                Circle()
                    .fill(Color(.label))
                    .frame(width: 12, height: 12)
                    .position(center)
                
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 6, height: 6)
                    .position(center)
                
                // Scale labels at arc ends
                let labelRadius = radius + 12
                let startLabelAngle = Angle(degrees: 150).radians
                let endLabelAngle = Angle(degrees: 30).radians
                
                Text("0")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .position(
                        x: center.x + cos(startLabelAngle) * labelRadius,
                        y: center.y + sin(startLabelAngle) * labelRadius
                    )
                
                Text("100")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .position(
                        x: center.x + cos(endLabelAngle) * labelRadius,
                        y: center.y + sin(endLabelAngle) * labelRadius
                    )
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack {
        NutriScoreCardView()
            .frame(width: 350, height: 120)
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}
