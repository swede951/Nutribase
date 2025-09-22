import SwiftUI

// Custom wrapper to match the standard DashboardCardView styling
struct NutriScoreCardWrapper<Content: View>: View {
    let content: Content
    @Binding var showingDetailView: Bool
    @Binding var showingInfo: Bool
    
    init(showingDetailView: Binding<Bool>, showingInfo: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._showingDetailView = showingDetailView
        self._showingInfo = showingInfo
        self.content = content()
    }
    
    var body: some View {
        Button(action: {
            showingDetailView = true
        }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Nutri-Score")
                        .font(.custom("Montserrat-SemiBold", size: 17))
                    Spacer()
                    Button(action: {
                        showingInfo = true
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 8)
                
                Spacer()
                
                // Center the content
                VStack {
                    Spacer()
                    content
                    Spacer()
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NutriScoreCardView: View {
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    
    // State for showing the detailed view
    @State private var showingDetailView = false
    
    // Info button action
    @State private var showingInfo = false
    
    // Calculate Nutri-Score distribution for the last 7 days only
    private var weeklyNutriScores: [String: [String: Int]] {
        // Only use days from the past week (today and 6 days before)
        let calendar = Calendar.current
        let today = Date()
        let pastWeekDays = (0...6).compactMap { dayOffset -> (String, Date)? in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { return nil }
            let weekday = calendar.component(.weekday, from: date)
            // Convert weekday to day abbreviation (1=Sunday, 2=Monday, etc.)
            let dayAbbreviations = ["Su", "M", "Tu", "W", "Th", "F", "Sa"]
            return (dayAbbreviations[weekday-1], date)
        }
        
        var scores: [String: [String: Int]] = [:]
        
        for (day, date) in pastWeekDays {
            // Get entries for this date (all meal types)
            let entries = getAllEntriesForDate(date)
            
            // Count entries by Nutri-Score grade
            var gradeCounts: [String: Int] = ["a": 0, "b": 0, "c": 0, "d": 0, "e": 0]
            
            for entry in entries {
                if let grade = entry.foodItem.nutriScoreGrade?.lowercased(), ["a", "b", "c", "d", "e"].contains(grade) {
                    gradeCounts[grade, default: 0] += 1
                }
            }
            
            scores[day] = gradeCounts
        }
        
        return scores
    }
    
    // Calculate the dominant Nutri-Score grade for each day
    private var dailyDominantGrades: [String: String] {
        var dominantGrades: [String: String] = [:]
        
        for (day, grades) in weeklyNutriScores {
            // Only include days that have actual food entries with grades
            let totalEntries = grades.values.reduce(0, +)
            if totalEntries > 0 {
                let sortedGrades = grades.sorted { $0.value > $1.value }
                if let topGrade = sortedGrades.first, topGrade.value > 0 {
                    dominantGrades[day] = topGrade.key
                }
            }
        }
        
        return dominantGrades
    }
    
    // Calculate weekly percentages for each Nutri-Score grade
    private var weeklyGradePercentages: [String: Double] {
        var totalCounts: [String: Int] = ["a": 0, "b": 0, "c": 0, "d": 0, "e": 0]
        var totalItems = 0
        
        for (_, grades) in weeklyNutriScores {
            for (grade, count) in grades {
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
        NutriScoreCardWrapper(showingDetailView: $showingDetailView, showingInfo: $showingInfo) {
            // Main content with bars on left, percentages on right
            HStack(alignment: .center, spacing: 16) {
                // Weekday bars on the left (Monday to Sunday order)
                HStack(alignment: .bottom, spacing: 8) {
                    // Get all days of the week in order
                    let allDays = ["M", "Tu", "W", "Th", "F", "Sa", "Su"].sorted(by: { weekdayOrder($0) < weekdayOrder($1) })
                    
                    // Show all days, but only with data for those that have entries
                    ForEach(allDays, id: \.self) { day in
                        if let grade = dailyDominantGrades[day] {
                            // Day has data, show with grade
                            NutriScoreDayBar(day: day, grade: grade)
                        } else {
                            // Day has no data, show empty bar
                            NutriScoreDayBar(day: day, grade: "?")
                        }
                    }
                }
                .frame(minWidth: 180) // Minimum width for the bars section
                
                // Weekly average percentages stacked vertically on the right
                VStack(spacing: 2) {
                    percentageView(value: highQualityPercentage, label: "High Quality", color: .green)
                    percentageView(value: lowQualityPercentage, label: "Low Quality", color: .red)
                }
                .frame(minWidth: 110) // Minimum width for the percentage column
            }
        }
        .sheet(isPresented: $showingDetailView) {
            NutriScoreDetailView()
        }
        .sheet(isPresented: $showingInfo) {
            NutriScoreInfoView()
        }
    }
    
    // Helper function to determine weekday order (Monday to Sunday)
    private func weekdayOrder(_ day: String) -> Int {
        let order = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
        return order.firstIndex(of: day) ?? 0
    }
    
    // Helper function to create a percentage view
    private func percentageView(value: Double, label: String, color: Color) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Text("\(Int(value))%")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // This function is no longer used as we're now using explicit dates for the past 7 days
    // Kept for reference in case we need to revert
    private func getDateForDay(_ day: String) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        
        // Map day string to weekday integer (1 = Sunday, 2 = Monday, etc.)
        let dayMap = ["Su": 1, "M": 2, "Tu": 3, "W": 4, "Th": 5, "F": 6, "Sa": 7]
        guard let targetWeekday = dayMap[day] else { return today }
        
        // Calculate the difference between today and the target day
        var daysToAdd = targetWeekday - weekday
        
        // If the target day is in the future (later in the week), adjust to show current week
        if daysToAdd > 0 {
            daysToAdd -= 7 // Go back to the current/previous week
        }
        
        // Create a date for the target day
        return calendar.date(byAdding: .day, value: daysToAdd, to: today) ?? today
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
        case "a": return 35.0
        case "b": return 28.0
        case "c": return 21.0
        case "d": return 14.0
        case "e": return 7.0
        default: return 0.0
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(day)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Background bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray5))
                .frame(width: 8, height: 35)
                .overlay(
                    // Colored bar based on grade
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        
                        // Only show colored bar if we have a valid grade (a-e)
                        if ["a", "b", "c", "d", "e"].contains(grade.lowercased()) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(gradeColor)
                                .frame(width: 8, height: barHeight)
                        }
                    }
                )
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
    @State private var currentWeekOffset: Int = 0
    @State private var animationOpacity: Double = 1.0
    
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
                Color(hex: "#F0F1F4")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                    
                    // Weekly chart carousel with snap behavior
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 20) {
                                // Generate cards chronologically: oldest (-10) on left, newest (0) on right
                                ForEach(-10...0, id: \.self) { offset in
                                    weeklyChartCard(for: offset)
                                        .frame(width: screenWidth * 0.85, height: 280)
                                        .fixedSize()
                                        .id(offset)
                                }
                            }
                            .padding(.horizontal, screenWidth * 0.075)
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .defaultScrollAnchor(.trailing)
                        .onScrollTargetVisibilityChange(idType: Int.self) { visibleIDs in
                            if let centerID = visibleIDs.first {
                                self.updateCurrentWeek(to: centerID)
                            }
                        }
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                proxy.scrollTo(0, anchor: .center)
                            }
                        }
                        .frame(height: 320)
                    }
                    
                    // Nutri-Score grade percentages
                    VStack(alignment: .leading, spacing: 16) {
                        // Title
                        Text("Nutri-Score Grade Distribution")
                            .font(.headline)
                            .padding(.top, 16)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 4)
                            
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
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .opacity(animationOpacity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                    )
                    .padding(.horizontal)
                    
                    // Nutri-Score explanation
                    nutriScoreExplanationView
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Nutri-Score Details")
            .navigationBarTitleDisplayMode(.inline)
            }
            .background(Color.white)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Nutri-Score Details")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .toolbarBackground(Color(.systemGray6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
    
    // Helper function to update current week with animation
    private func updateCurrentWeek(to offset: Int) {
        if currentWeekOffset != offset {
            withAnimation(.easeInOut(duration: 0.3)) {
                animationOpacity = 0.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                currentWeekOffset = offset
                withAnimation(.easeInOut(duration: 0.3)) {
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
                    .foregroundColor(.black)
                
                Spacer()
                
                // Week navigation
                HStack(spacing: 12) {
                    Button(action: {
                        // Navigate to previous week
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.secondary)
                    }
                    
                    Text(weekDateRangeString(for: offset))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        // Navigate to next week
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(offset < 0 ? .secondary : .gray)
                    }
                    .disabled(offset >= 0)
                }
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
                .fill(Color.white)
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
                                                .fill(Color(.systemGray6))
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
                .fill(Color.white)
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
                .fill(Color.white)
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
        
        // Calculate total items for the day
        let totalItems = entries.count
        
        // Calculate items from the specified Nutri-Score grade
        let gradeItems = entries.reduce(0) { result, entry in
            let entryGrade = entry.foodItem.nutriScoreGrade?.lowercased() ?? ""
            return result + (entryGrade == grade ? 1 : 0)
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
            if let grade = entry.foodItem.nutriScoreGrade?.lowercased(), ["a", "b", "c", "d", "e"].contains(grade) {
                gradeCounts[grade, default: 0] += 1
            }
        }
        
        let sortedGrades = gradeCounts.sorted { $0.value > $1.value }
        return sortedGrades.first?.key ?? "?"
    }
    
    // Calculate the weekly percentage for a specific grade with a specific week offset
    private func calculateWeeklyPercentage(for grade: String, weekOffset: Int = 0) -> Double {
        let days = getDaysOfWeek(for: weekOffset)
        var totalGradeCount = 0
        var totalItems = 0
        
        // Sum up items for each day
        for day in days {
            let date = getDateForDay(day, weekOffset: weekOffset)
            let entries = getAllEntriesForDate(date)
            
            for entry in entries {
                if let entryGrade = entry.foodItem.nutriScoreGrade?.lowercased(), ["a", "b", "c", "d", "e"].contains(entryGrade) {
                    totalItems += 1
                    if entryGrade == grade {
                        totalGradeCount += 1
                    }
                }
            }
        }
        
        // Calculate percentage
        return totalItems > 0 ? (Double(totalGradeCount) / Double(totalItems) * 100.0) : 0
    }
    
    // Get the date range string for a specific week offset
    private func weekDateRangeString(for offset: Int = 0) -> String {
        let calendar = Calendar.current
        let today = Date()
        
        // For current week (offset 0), show rolling 7-day range
        if offset == 0 {
            guard let startDate = calendar.date(byAdding: .day, value: -6, to: today) else {
                return "Week of \(formatDate(today))"
            }
            return "\(formatDate(startDate)) - \(formatDate(today))"
        } else {
            // For other weeks, use calendar week approach
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
        
        // For current week (offset 0), use rolling 7-day approach like dashboard
        if weekOffset == 0 {
            // Map day abbreviation to how many days ago it was
            let dayMap = ["M": 0, "Tu": 1, "W": 2, "Th": 3, "F": 4, "Sa": 5, "Su": 6]
            
            // Find today's weekday and calculate days back to target day
            let todayWeekday = calendar.component(.weekday, from: today)
            let todayDayAbbrev = ["Su", "M", "Tu", "W", "Th", "F", "Sa"][todayWeekday - 1]
            
            // Calculate how many days back the target day is from today
            let todayIndex = dayMap[todayDayAbbrev] ?? 0
            let targetIndex = dayMap[day] ?? 0
            
            var daysBack = todayIndex - targetIndex
            if daysBack < 0 {
                daysBack += 7 // If target day is "in the future", it's actually last week
            }
            
            return calendar.date(byAdding: .day, value: -daysBack, to: today) ?? today
        } else {
            // For other weeks, use calendar week approach
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

#Preview(traits: .sizeThatFitsLayout) {
    VStack {
        NutriScoreCardView()
            .frame(width: 350, height: 120)
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}
