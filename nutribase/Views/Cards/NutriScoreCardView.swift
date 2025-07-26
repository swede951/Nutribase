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
                        .font(.custom("Montserrat-Bold", size: 17))
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
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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
    
    // Calculate Nutri-Score distribution for the current week
    private var weeklyNutriScores: [String: [String: Int]] {
        let days = ["Su", "M", "Tu", "W", "Th", "F", "Sa"]
        var scores: [String: [String: Int]] = [:]
        
        for day in days {
            // Get the date for this day
            let date = getDateForDay(day)
            
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
            let sortedGrades = grades.sorted { $0.value > $1.value }
            dominantGrades[day] = sortedGrades.first?.key ?? "?"
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
            HStack(alignment: .center, spacing: 12) {
                // Weekday bars on the left
                HStack(alignment: .bottom, spacing: 8) {
                    let sortedDays = dailyDominantGrades.keys.sorted(by: { weekdayOrder($0) < weekdayOrder($1) })
                    ForEach(sortedDays, id: \.self) { day in
                        NutriScoreDayBar(day: day, grade: dailyDominantGrades[day] ?? "?")
                            .frame(height: 25) // Reduced height for bars to 25 points
                    }
                }
                .frame(minWidth: 180) // Minimum width for the bars section
                
                Spacer() // Add flexible space between bars and percentages
                
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
    
    // Helper function to determine weekday order
    private func weekdayOrder(_ day: String) -> Int {
        let order = ["Su", "M", "Tu", "W", "Th", "F", "Sa"]
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
    
    // Get the date for a specific day abbreviation
    private func getDateForDay(_ day: String) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        
        // Map day string to weekday integer (1 = Sunday, 2 = Monday, etc.)
        let dayMap = ["Su": 1, "M": 2, "Tu": 3, "W": 4, "Th": 5, "F": 6, "Sa": 7]
        guard let targetWeekday = dayMap[day] else { return today }
        
        // Calculate the difference between today and the target day
        var daysToAdd = targetWeekday - weekday
        
        // If the target day is earlier in the week, go back to the previous week
        if daysToAdd > 0 {
            daysToAdd -= 7
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
    
    var body: some View {
        VStack(spacing: 4) {
            Text(day)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 20, height: 20)
                
                Text(grade.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(gradeColor)
                    )
            }
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
    
    // Calculate Nutri-Score distribution for the current week
    private var weeklyNutriScoreData: [String: Double] {
        // Get all entries for the past week
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(byAdding: .day, value: -6, to: today)!
        
        var gradeCounts: [String: Int] = ["a": 0, "b": 0, "c": 0, "d": 0, "e": 0]
        var totalItems = 0
        
        // Common meal types in the app
        let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snacks"]
        
        // Iterate through each day of the week
        for dayOffset in 0...6 {
            let currentDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)!
            
            // Collect entries from all meal types for this day
            for mealType in mealTypes {
                let entries = foodLogManager.entries(for: currentDate, mealType: mealType)
                
                // Count entries by Nutri-Score grade
                for entry in entries {
                    if let grade = entry.foodItem.nutriScoreGrade?.lowercased(), ["a", "b", "c", "d", "e"].contains(grade) {
                        gradeCounts[grade, default: 0] += 1
                        totalItems += 1
                    }
                }
            }
        }
        
        // Calculate percentages
        var percentages: [String: Double] = [:]
        for (grade, count) in gradeCounts {
            percentages[grade] = totalItems > 0 ? (Double(count) / Double(totalItems) * 100.0) : 0.0
        }
        
        return percentages
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title and description
                    Text("Your Weekly Nutri-Score")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    Text("This chart shows the distribution of Nutri-Score grades in your diet over the past week.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Nutri-Score distribution chart
                    VStack(spacing: 16) {
                        ForEach(["a", "b", "c", "d", "e"], id: \.self) { grade in
                            nutriScoreBar(grade: grade, percentage: weeklyNutriScoreData[grade] ?? 0)
                        }
                    }
                    .padding(.vertical)
                    
                    // Explanation
                    Text("Understanding Your Results")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("A higher percentage of A and B grades indicates a diet rich in nutritious foods. Try to minimize D and E grade foods for better nutritional balance.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
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
            .toolbarBackground(Color(hex: "#ffd2a6"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
    
    // Helper function to create Nutri-Score bar
    private func nutriScoreBar(grade: String, percentage: Double) -> some View {
        let gradeColor: Color
        let gradeTitle: String
        
        switch grade.lowercased() {
        case "a":
            gradeColor = .green
            gradeTitle = "Excellent"
        case "b":
            gradeColor = .blue
            gradeTitle = "Good"
        case "c":
            gradeColor = .yellow
            gradeTitle = "Average"
        case "d":
            gradeColor = .orange
            gradeTitle = "Poor"
        case "e":
            gradeColor = .red
            gradeTitle = "Very Poor"
        default:
            gradeColor = .gray
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
