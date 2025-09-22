import SwiftUI
import UIKit // Required for CardStyle

struct NovaGroupsDetailView: View {
    @ObservedObject var foodLogManager: FoodLogManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    @State private var currentWeekOffset: Int = 0
    @State private var animationOpacity: Double = 1.0
    
    // State for tooltip display
    @State private var activeTooltipDay: String? = nil
    
    // Store positions of each day's bar for tooltip positioning
    @State private var barPositions: [CGFloat] = Array(repeating: 0, count: 7)
    
    // State to track the selected week (0 = current week, -1 = last week, etc.)
    @State private var weekOffset = 0
    
    // State for slide animation
    @State private var slideOffset: CGFloat = 0
    @State private var slideOpacity: Double = 1
    @State private var isAnimating = false
    @State private var animationDirection = 0 // -1 for left, 1 for right
    @State private var nextWeekOffset: Int? = nil // Tracks the week offset for the card being swiped in
    
    // Colors for each NOVA group
    private let novaColors: [Color] = [
        Color(hex: "#3f993f"),      // Group 1 - Unprocessed - darker green
        Color(hex: "#b7ce0d"),      // Group 2 - Processed ingredients - lime green
        Color(hex: "#f28e16"),      // Group 3 - Processed - orange
        Color(hex: "#e4032f")       // Group 4 - Ultra-processed - bright red
    ]
    
    // Names for each NOVA group
    private let novaGroupNames = [
        "Unprocessed",
        "Ingredients",
        "Processed",
        "Ultra"
    ]
    
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
                    
                    // NOVA group percentages
                    VStack(alignment: .leading, spacing: 16) {
                        // Title
                        Text("NOVA Group Distribution")
                            .font(.headline)
                            .padding(.top, 16)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 4)
                            
                        // Group percentages grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(0..<4) { index in
                                novaGroupPercentageView(
                                    percentage: calculateWeeklyPercentage(for: index + 1, weekOffset: currentWeekOffset),
                                    groupName: novaGroupNames[index],
                                    color: novaColors[index]
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
                    
                    // NOVA classification explanation
                    novaExplanationView
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("NOVA Groups")
            .navigationBarTitleDisplayMode(.inline)
            }
            .background(Color.white)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("NOVA Groups")
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
    
    // Weekly stacked bar chart
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
                        animateWeekTransition(direction: -1)
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.secondary)
                    }
                    
                    Text(weekDateRangeString(for: offset))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        if offset < 0 {
                            animateWeekTransition(direction: 1)
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(offset < 0 ? .secondary : .gray)
                    }
                    .disabled(offset >= 0)
                }
            }
            .padding(.top, 12) // Consistent with memory about card title spacing
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            
            // Weekly chart for the specific week
            weeklyStackedBarChart(for: offset)
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
    private func weeklyStackedBarChart(for offset: Int) -> some View {
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
                                        // State for long press
                                        let hasEntries = hasFoodEntriesForDay(day, weekOffset: offset)
                                        
                                        // Stacked bar
                                        ZStack(alignment: .bottom) {
                                            // Background
                                            Rectangle()
                                                .fill(Color(.systemGray6))
                                                .frame(height: geometry.size.height * 0.8) // Reduce height to match grid lines
                                            
                                            // Stacked segments
                                            VStack(spacing: 0) {
                                                if hasEntries {
                                                    // Draw segments from bottom to top (Group 1 at bottom, Group 4 at top)
                                                    // This ensures proper stacking order
                                                    let segments = (1...4).map { group -> (group: Int, height: CGFloat) in
                                                        let height = calculateBarSegmentHeight(
                                                            day: day,
                                                            novaGroup: group,
                                                            maxHeight: geometry.size.height,
                                                            weekOffset: offset
                                                        )
                                                        return (group: group, height: height)
                                                    }
                                                    
                                                    // Draw in reverse order (Group 1 at bottom)
                                                    ForEach(segments.indices, id: \.self) { index in
                                                        let segment = segments[index]
                                                        Rectangle()
                                                            .fill(novaColors[segment.group - 1])
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
                                        .contentShape(Rectangle())
                                        .onLongPressGesture(minimumDuration: 0.2, pressing: { isPressing in
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                activeTooltipDay = isPressing && hasEntries ? day : nil
                                            }
                                        }, perform: {})
                                        
                                        // Day label
                                        Text(day)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    // Store the bar position for tooltip positioning
                                    .background(GeometryReader { geo in
                                        Color.clear.onAppear {
                                            if let index = getDaysOfWeek(for: offset).firstIndex(of: day) {
                                                let barFrame = geo.frame(in: .named("chartCoordinateSpace"))
                                                // Store the position for later use
                                                if barPositions[index] != barFrame.midX {
                                                    barPositions[index] = barFrame.midX
                                                }
                                            }
                                        }
                                    })
                                }
                            }
                        }
                    }
                    
                    // Tooltip overlay - appears above all other content
                    if let activeDay = activeTooltipDay, 
                       let dayIndex = getDaysOfWeek(for: offset).firstIndex(of: activeDay),
                       barPositions.count > dayIndex {
                        DayDetailTooltip(
                            day: activeDay,
                            novaPercentages: [
                                calculateDailyPercentage(for: activeDay, novaGroup: 1),
                                calculateDailyPercentage(for: activeDay, novaGroup: 2),
                                calculateDailyPercentage(for: activeDay, novaGroup: 3),
                                calculateDailyPercentage(for: activeDay, novaGroup: 4)
                            ],
                            novaGroupNames: novaGroupNames,
                            novaColors: novaColors,
                            width: 150
                        )
                        .position(x: barPositions[dayIndex], y: geometry.size.height / 2 - 100)
                        .transition(.opacity)
                        .zIndex(100) // Ensure it's above everything else
                    }
                }
                .coordinateSpace(name: "chartCoordinateSpace")
            }
            .frame(height: 180)
            
            // Legend
            HStack(spacing: 16) {
                ForEach(0..<4) { index in
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(novaColors[index])
                            .frame(width: 12, height: 12)
                        
                        Text("Group \(index + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
        }
    }
}

// NOVA group percentages view
private func novaGroupPercentageView(percentage: Double, groupName: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        HStack {
            Text("\(Int(percentage))%")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(groupName)
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
    
    // NOVA explanation view
    private var novaExplanationView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About NOVA Classification")
                .font(.headline)
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                novaGroupExplanation(
                    number: 1,
                    name: "Unprocessed or minimally processed foods",
                    description: "Natural foods with minimal processing like fresh fruits, vegetables, grains, and meats.",
                    color: novaColors[0]
                )
                
                novaGroupExplanation(
                    number: 2,
                    name: "Processed culinary ingredients",
                    description: "Substances derived from Group 1 foods or nature, like oils, butter, sugar, and salt.",
                    color: novaColors[1]
                )
                
                novaGroupExplanation(
                    number: 3,
                    name: "Processed foods",
                    description: "Made by adding Group 2 ingredients to Group 1 foods, like canned vegetables, cheese, and fresh bread.",
                    color: novaColors[2]
                )
                
                novaGroupExplanation(
                    number: 4,
                    name: "Ultra-processed foods",
                    description: "Industrial formulations with five or more ingredients, often including additives not used in home cooking.",
                    color: novaColors[3]
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
    
    // NOVA group explanation item
    private func novaGroupExplanation(number: Int, name: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Group number indicator
            Text("\(number)")
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
    
    // Calculate the bar segment height for a specific day and NOVA group
    private func calculateBarSegmentHeight(day: String, novaGroup: Int, maxHeight: CGFloat, weekOffset: Int = 0) -> CGFloat {
        let percentage = calculateDailyPercentage(for: day, novaGroup: novaGroup, weekOffset: weekOffset)
        return CGFloat(percentage / 100.0) * (maxHeight * 0.8) // Adjust to 80% of max height to align with grid lines
    }
    
    // Calculate the percentage of calories from a specific NOVA group for a specific day
    private func calculateDailyPercentage(for day: String, novaGroup: Int, weekOffset: Int = 0) -> Double {
        // Get the date for the specified day with the correct week offset
        let date = getDateForDay(day, weekOffset: weekOffset)
        
        // Get all entries for that date
        let entries = getAllEntriesForDate(date)
        
        // If no entries, return 0
        if entries.isEmpty {
            return 0
        }
        
        // Calculate total calories for the day
        let totalCalories = entries.reduce(0) { $0 + $1.totalCalories }
        
        // Calculate calories from the specified NOVA group
        let groupCalories = entries.reduce(0) { result, entry in
            let entryNovaScore = entry.foodItem.novaScore > 0 ? 
                entry.foodItem.novaScore : 
                NovaScoreService.shared.predictNovaScore(for: entry.foodItem)
            
            return result + (entryNovaScore == novaGroup ? entry.totalCalories : 0)
        }
        
        // Calculate percentage
        return totalCalories > 0 ? (Double(groupCalories) / Double(totalCalories) * 100.0) : 0
    }
    
    // Check if there are any food entries for a specific day
    private func hasFoodEntriesForDay(_ day: String, weekOffset: Int = 0) -> Bool {
        let date = getDateForDay(day, weekOffset: weekOffset)
        let entries = getAllEntriesForDate(date)
        return !entries.isEmpty
    }
    
    // Animate the transition between weeks with a slide effect
    private func animateWeekTransition(direction: Int) {
        // Only proceed if not already animating
        if isAnimating {
            return
        }
        
        // Set animation direction (-1 for left swipe, 1 for right swipe)
        animationDirection = direction
        isAnimating = true
        
        // Only allow right swipe if not at current week
        if direction > 0 && weekOffset >= 0 {
            isAnimating = false
            return
        }
        
        // Set the next week offset
        nextWeekOffset = weekOffset + direction
        
        let screenWidth = UIScreen.main.bounds.width
        
        // Determine if we're going to an older week (more negative offset)
        let goingToOlderWeek = (nextWeekOffset ?? 0) < weekOffset
        
        // Step 1: Slide current card out completely
        withAnimation(.easeOut(duration: 0.3)) {
            // When going to an older week (more negative offset), current card slides left
            // When going to a newer week (less negative offset), current card slides right
            slideOffset = goingToOlderWeek ? -screenWidth : screenWidth
            slideOpacity = 0
        }
        
        // Step 2: Update week offset after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            weekOffset = nextWeekOffset ?? weekOffset
            slideOffset = 0
            slideOpacity = 1
            nextWeekOffset = nil
            
            // Reset animation state after completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isAnimating = false
                animationDirection = 0
            }
        }
    }
    
    // Calculate the weekly percentage for a specific NOVA group with a specific week offset
    private func calculateWeeklyPercentage(for novaGroup: Int, weekOffset: Int = 0) -> Double {
        let days = getDaysOfWeek(for: weekOffset)
        var totalGroupCalories = 0
        var totalCalories = 0
        
        // Sum up calories for each day
        for day in days {
            let date = getDateForDay(day, weekOffset: weekOffset)
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
    
    // Calculate the offset for the next card based on swipe direction and progress
    private func calculateNextCardOffset() -> CGFloat {
        guard let nextOffset = nextWeekOffset else { return UIScreen.main.bounds.width }
        
        let screenWidth = UIScreen.main.bounds.width
        let isGoingBack = nextOffset < weekOffset // Going back in time (right swipe)
        
        if isGoingBack {
            // Next card starts from the right and slides in from right to left
            return screenWidth + slideOffset
        } else {
            // Next card starts from the left and slides in from left to right
            return -screenWidth + slideOffset
        }
    }
    
    // Get the date range string for a specific week offset
    private func weekDateRangeString(for offset: Int = 0) -> String {
        let calendar = Calendar.current
        
        // Get the start of the current week (Sunday)
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday - 1 // 1 = Sunday
        
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
    
    // Scroll to current week in carousel
    private func scrollToCurrentWeek() {
        // This will be handled by the ScrollViewReader if we add it
        // For now, the carousel will start at the current week (offset 0)
    }
    
    // Get the date for a specific day abbreviation in the selected week
    private func getDateForDay(_ day: String, weekOffset: Int = 0) -> Date {
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
}

// Tooltip view for displaying detailed percentages on long press
struct DayDetailTooltip: View {
    let day: String
    let novaPercentages: [Double]
    let novaGroupNames: [String]
    let novaColors: [Color]
    let width: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(day)
                .font(.headline)
                .padding(.bottom, 4)
            
            // Display NOVA groups in order from 1 to 4
            ForEach(0..<4) { index in
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(novaColors[index])
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                    
                    Text("Group \(index + 1)")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(novaPercentages[index]))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(novaColors[index])
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
        )
        .frame(width: width)
    }
}

#Preview {
    NovaGroupsDetailView(foodLogManager: FoodLogManager.shared)
}
