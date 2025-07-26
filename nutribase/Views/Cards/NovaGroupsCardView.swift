import SwiftUI

// Custom wrapper to match the standard DashboardCardView styling
struct NovaCardWrapper<Content: View>: View {
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
                    Text("NOVA Groups")
                        .font(.custom("Montserrat-Bold", size: 17))
                    Spacer()
                    Button(action: {
                        showingInfo = true
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 4)
                
                content
                
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

struct NovaGroupsCardView: View {
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    
    // State for showing the detailed view
    @State private var showingDetailView = false
    
    // Info button action
    @State private var showingInfo = false
    
    // State to track the selected week (0 = current week, -1 = last week, etc.)
    @State private var weekOffset = 0
    
    // NOVA group colors
    private let novaColors: [Int: Color] = [
        1: Color(hex: "#81b4a3"),      // Unprocessed
        2: Color(hex: "#f9d061"),       // Processed culinary ingredients
        3: Color(hex: "#2e3fc5"),     // Processed foods
        4: Color(hex: "#f46a71")         // Ultra-processed foods
    ]
    
    // Calculate NOVA scores and distribution for each day
    private var weekdayData: [String: (score: Double, distribution: [Int: Double])] {
        let days = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
        var data: [String: (score: Double, distribution: [Int: Double])] = [:]
        
        for day in days {
            // Get the date for this day
            let date = getDateForDay(day)
            
            // Get entries for this date (all meal types)
            let entries = getAllEntriesForDate(date)
            
            if entries.isEmpty {
                data[day] = (score: 0.0, distribution: [:])
            } else {
                // Calculate total calories
                let totalCalories = entries.reduce(0) { $0 + $1.totalCalories }
                
                // Initialize distribution counters for each NOVA group
                var groupCalories: [Int: Double] = [1: 0, 2: 0, 3: 0, 4: 0]
                
                // Calculate weighted score and group distribution
                var weightedScore = 0.0
                for entry in entries {
                    let novaScore = entry.foodItem.novaScore > 0 ? 
                        entry.foodItem.novaScore : 
                        NovaScoreService.shared.predictNovaScore(for: entry.foodItem)
                    
                    // Add calories to the appropriate NOVA group
                    groupCalories[novaScore, default: 0] += Double(entry.totalCalories)
                    
                    // Invert the NOVA score (1 is best, 4 is worst)
                    let invertedScore = 5.0 - Double(novaScore)
                    
                    // Weight by calories
                    let entryWeight = Double(entry.totalCalories) / Double(totalCalories)
                    weightedScore += entryWeight * invertedScore / 4.0 // Normalize to 0-1
                }
                
                // Convert calorie counts to percentages
                var distribution: [Int: Double] = [:]
                for (group, calories) in groupCalories {
                    distribution[group] = calories / Double(totalCalories)
                }
                
                data[day] = (score: weightedScore, distribution: distribution)
            }
        }
        
        return data
    }
    
    var body: some View {
        NovaCardWrapper(showingDetailView: $showingDetailView, showingInfo: $showingInfo) {
            // Main content with bars on left, percentages on right
            HStack(alignment: .center, spacing: 12) {
                // Weekday bars on the left
                HStack(alignment: .bottom, spacing: 8) {
                    // Break up the complex expression into simpler parts
                    let sortedDays = weekdayData.keys.sorted(by: { weekdayOrder($0) < weekdayOrder($1) })
                    ForEach(sortedDays, id: \.self) { day in
                        if let dayData = weekdayData[day] {
                            WeekdayBar(day: day, score: dayData.score, novaDistribution: dayData.distribution, novaColors: novaColors)
                                .frame(height: 35) // Height for bars
                        }
                    }
                }
                .frame(width: 180) // Fixed width for the bars section
                
                Spacer() // Add flexible space between bars and percentages
                
                // Weekly average percentages stacked vertically on the right
                VStack(spacing: 2) {
                    percentageView(value: calculateWeeklyPercentage(for: 1), label: "Unprocessed", color: novaColors[1] ?? .gray)
                    percentageView(value: calculateWeeklyPercentage(for: 2), label: "Ingredients", color: novaColors[2] ?? .gray)
                    percentageView(value: calculateWeeklyPercentage(for: 3), label: "Processed", color: novaColors[3] ?? .gray)
                    percentageView(value: calculateWeeklyPercentage(for: 4), label: "Ultra", color: novaColors[4] ?? .gray)
                }
                .frame(width: 110) // Fixed width for the percentage column
            }
        }
        .sheet(isPresented: $showingDetailView) {
            NovaGroupsDetailView()
        }
        .sheet(isPresented: $showingInfo) {
            NovaInfoView()
        }
    }
    
    // Helper function to determine weekday order
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
    
    // Calculate the weekly percentage for a specific NOVA group
    private func calculateWeeklyPercentage(for novaGroup: Int) -> Double {
        let days = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
        var totalGroupCalories = 0
        var totalCalories = 0
        
        // Sum up calories for each day
        for day in days {
            let date = getDateForDay(day)
            let entries = getAllEntriesForDate(date)
            
            // Add to total calories
            let dayTotalCalories = entries.reduce(0) { $0 + $1.totalCalories }
            totalCalories += dayTotalCalories
            
            // Add to group calories
            let dayGroupCalories = entries.reduce(0) { result, entry in
                let entryNovaScore = entry.foodItem.novaScore > 0 ? 
                    entry.foodItem.novaScore : 
                    NovaScoreService.shared.predictNovaScore(for: entry.foodItem)
                
                return result + (entryNovaScore == novaGroup ? entry.totalCalories : 0)
            }
            totalGroupCalories += dayGroupCalories
        }
        
        // Calculate percentage
        return totalCalories > 0 ? (Double(totalGroupCalories) / Double(totalCalories) * 100.0) : 0
    }
    
    // Week navigation view with arrows and date display
    private func weekNavigationView() -> some View {
        HStack {
            Button(action: {
                weekOffset -= 1
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text(weekDateRangeString())
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                if weekOffset < 0 {
                    weekOffset += 1
                }
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(weekOffset < 0 ? .blue : .gray)
            }
            .disabled(weekOffset >= 0)
        }
        .padding(.bottom, 8)
    }
    
    // Generate a string representation of the selected week's date range
    private func weekDateRangeString() -> String {
        let calendar = Calendar.current
        
        // Get the start of the current week (Sunday)
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday - 1 // 1 = Sunday
        
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
            return "Week of \(formatDate(today))"
        }
        
        // Apply the week offset
        guard let selectedWeekStart = calendar.date(byAdding: .day, value: 7 * weekOffset, to: currentWeekStart),
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
    private func getDateForDay(_ day: String) -> Date {
        let calendar = Calendar.current
        let today = Date()
        
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

struct WeekdayBar: View {
    let day: String
    let score: Double
    let novaDistribution: [Int: Double]
    let novaColors: [Int: Color]
    
    init(day: String, score: Double, novaDistribution: [Int: Double] = [:], novaColors: [Int: Color]) {
        self.day = day
        self.score = score
        self.novaDistribution = novaDistribution
        self.novaColors = novaColors
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
                    // Stacked bars for each NOVA group
                    GeometryReader { geometry in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            
                            // If we have distribution data, show stacked bars
                            if !novaDistribution.isEmpty {
                                ForEach(1...4, id: \.self) { group in
                                    if let percentage = novaDistribution[group], percentage > 0 {
                                        RoundedRectangle(cornerRadius: 0)
                                            .fill(novaColors[group] ?? .gray)
                                            .frame(width: 8, height: geometry.size.height * percentage)
                                    }
                                }
                            } else {
                                // Fallback to simple score representation
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.green.opacity(score))
                                    .frame(width: 8, height: max(3, geometry.size.height * score))
                            }
                        }
                    }
                )
        }
    }
}

struct NovaInfoView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text("About NOVA Classification")
                        .font(.headline)
                    
                    // Description
                    Text("NOVA is a food classification system that categorizes foods according to the extent and purpose of processing, rather than in terms of nutrients.")
                    
                    // Group 1
                    groupInfoView(number: 1, title: "Unprocessed or minimally processed foods", description: "Natural foods with minimal processing like fresh fruits, vegetables, grains, and meats.")
                    
                    // Group 2
                    groupInfoView(number: 2, title: "Processed culinary ingredients", description: "Substances derived from Group 1 foods or nature, like oils, butter, sugar, and salt.")
                    
                    // Group 3
                    groupInfoView(number: 3, title: "Processed foods", description: "Made by adding Group 2 ingredients to Group 1 foods, like canned vegetables, cheese, and fresh bread.")
                    
                    // Group 4
                    groupInfoView(number: 4, title: "Ultra-processed foods", description: "Industrial formulations with five or more ingredients, often including additives not used in home cooking.")
                    
                    // Footer
                    Text("Your daily NOVA score is calculated based on the proportion of unprocessed or minimally processed foods in your diet. Higher scores indicate a diet with more natural foods.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("NOVA Groups")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // Helper function to create consistent group info views
    private func groupInfoView(number: Int, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Group \(number): \(title)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack {
        NovaGroupsCardView()
            .frame(width: 350,height: 120)
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}
