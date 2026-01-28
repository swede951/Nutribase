// Monthly chart template for macro detail views
// This template can be used for Carbs, Fat, and Steps detail views

// Add this to replace the "// Weekly chart" section:
/*
            // Chart based on view mode
            if viewMode == .weekly {
                weeklyBarChart(for: offset)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                monthlyBarChart(for: offset)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
*/

// Add these functions after monthDateRangeString:

    // Create the bar chart for a specific month offset
    private func monthlyBarChart(for offset: Int) -> some View {
        VStack(spacing: 20) {
            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 0) {
                    // Y-axis labels
                    VStack(alignment: .trailing, spacing: 0) {
                        let maxValue = TARGET_VAR * 12 / 10 // 120% of target
                        let roundedMax = Int(ceil(Double(maxValue) / ROUND_TO) * ROUND_TO)
                        Text("\(roundedMax)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(height: geometry.size.height / 5)
                        Text("\(roundedMax * 3/4)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(height: geometry.size.height / 5)
                        Text("\(roundedMax / 2)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(height: geometry.size.height / 5)
                        Text("\(roundedMax / 4)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(height: geometry.size.height / 5)
                        Text("0")
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
                        
                        // Bars for each day of the month
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .bottom, spacing: 2) {
                                ForEach(getDaysOfMonth(for: offset), id: \.self) { day in
                                    VStack(spacing: 2) {
                                        let consumed = getMonthlyDailyValue(day: day, monthOffset: offset)
                                        let hasEntries = getMonthlyHasEntries(day: day, monthOffset: offset)
                                        let maxValue = TARGET_VAR * 12 / 10
                                        let barHeight = consumed > 0 ? max(CGFloat(consumed) / CGFloat(maxValue) * geometry.size.height, 2) : 0
                                        
                                        Rectangle()
                                            .fill(hasEntries ? COLOR_VAR : Color.gray.opacity(0.3))
                                            .frame(width: max(8, (geometry.size.width - 50) / 31), height: barHeight)
                                            .cornerRadius(2)
                                            .contentShape(Rectangle())
                                            .onLongPressGesture(minimumDuration: 0.2, pressing: { isPressing in
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    activeTooltipDay = isPressing && hasEntries ? String(day) : nil
                                                }
                                            }, perform: {})
                                        
                                        Text("\(day)")
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 5)
                        }
                        
                        // Target line
                        GeometryReader { _ in
                            let maxValue = TARGET_VAR * 12 / 10
                            let targetHeight = CGFloat(TARGET_VAR) / CGFloat(maxValue) * geometry.size.height
                            
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 2)
                                .offset(y: -targetHeight)
                        }
                        
                        // Tooltip overlay for monthly view
                        if let activeDay = activeTooltipDay {
                            let consumed = getMonthlyDailyValue(day: Int(activeDay) ?? 1, monthOffset: offset)
                            TOOLTIP_VIEW(
                                day: activeDay,
                                value: consumed,
                                target: TARGET_VAR,
                                unit: "UNIT_STRING",
                                color: COLOR_VAR
                            )
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 60)
                            .transition(.opacity)
                            .zIndex(100)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 180)
            
            // Legend
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(COLOR_VAR)
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                    Text("Consumed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 20, height: 2)
                    Text("Target (\(TARGET_VAR)UNIT_SUFFIX)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // Helper function to get days of the month
    private func getDaysOfMonth(for offset: Int) -> [Int] {
        let calendar = Calendar.current
        let today = Date()
        
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else {
            return Array(1...30)
        }
        
        guard let targetMonth = calendar.date(byAdding: .month, value: offset, to: currentMonthStart) else {
            return Array(1...30)
        }
        
        let range = calendar.range(of: .day, in: .month, for: targetMonth) ?? 1..<31
        return Array(range)
    }
    
    // Helper function to get monthly daily value
    private func getMonthlyDailyValue(day: Int, monthOffset: Int) -> Int {
        let calendar = Calendar.current
        let today = Date()
        
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else {
            return 0
        }
        
        guard let targetMonth = calendar.date(byAdding: .month, value: monthOffset, to: currentMonthStart),
              let targetDate = calendar.date(byAdding: .day, value: day - 1, to: targetMonth) else {
            return 0
        }
        
        // For macros:
        let entries = foodLogManager.getEntriesForDate(targetDate)
        return entries.reduce(0) { $0 + $1.PROPERTY_NAME }
        
        // For steps:
        // return activityManager.getStepsForDate(targetDate)
    }
    
    // Helper function to check if day has entries in month
    private func getMonthlyHasEntries(day: Int, monthOffset: Int) -> Bool {
        return getMonthlyDailyValue(day: day, monthOffset: monthOffset) > 0
    }

/* Variable replacements:
For CarbsDetailView:
- TARGET_VAR: carbsTarget
- ROUND_TO: 10.0
- COLOR_VAR: CardType.carbs.color
- TOOLTIP_VIEW: MacroTooltip
- UNIT_STRING: "g"
- UNIT_SUFFIX: g
- PROPERTY_NAME: carbs

For FatDetailView:
- TARGET_VAR: fatTarget
- ROUND_TO: 10.0
- COLOR_VAR: CardType.fat.color
- TOOLTIP_VIEW: MacroTooltip
- UNIT_STRING: "g"
- UNIT_SUFFIX: g
- PROPERTY_NAME: fat

For StepsDetailView:
- TARGET_VAR: stepsGoal
- ROUND_TO: 1000.0
- COLOR_VAR: Color.orange
- TOOLTIP_VIEW: StepsTooltip
- UNIT_STRING: ""
- UNIT_SUFFIX: (empty or " steps")
- PROPERTY_NAME: N/A (use activityManager.getStepsForDate)
*/
