import SwiftUI

struct WeeklyOverviewView: View {
    let currentDate: Date
    @Binding var selectedDate: Date
    
    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let calendar = Calendar.current
    
    // Get the dates for the current week
    private var weekDates: [Date] {
        let today = currentDate
        let weekday = calendar.component(.weekday, from: today)
        
        // Adjust to get Monday as the first day (weekday 2 in Calendar)
        let daysToSubtract = (weekday + 5) % 7
        
        guard let monday = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
            return []
        }
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: monday)
        }
    }
    
    // Check if a date is selected
    private func isSelected(_ date: Date) -> Bool {
        return calendar.isDate(date, inSameDayAs: selectedDate)
    }
    
    // Check if a date is today
    private func isToday(_ date: Date) -> Bool {
        return calendar.isDateInToday(date)
    }
    
    // Format day number
    private func dayNumber(for date: Date) -> String {
        let day = calendar.component(.day, from: date)
        return String(day)
    }
    
    // Get progress for a specific day (0.0 to 1.0)
    // This would normally come from your data model
    private func progressForDay(_ date: Date) -> Double {
        // Mock data - in a real app, you'd calculate this based on actual data
        // For example, calories consumed / calorie goal
        if date < Date() {
            return Double.random(in: 0.3...0.9)
        } else {
            return 0.0
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Week days row
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.gray)
                }
            }
            
            // Days with progress circles
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    VStack(spacing: 4) {
                        Text(dayNumber(for: date))
                            .font(.subheadline)
                            .fontWeight(isToday(date) ? .bold : .regular)
                        
                        ZStack {
                            // Progress circle
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 30, height: 30)
                            
                            // Progress indicator
                            Circle()
                                .trim(from: 0, to: progressForDay(date))
                                .stroke(isSelected(date) ? Color.blue : Color.gray, lineWidth: 2)
                                .frame(width: 30, height: 30)
                                .rotationEffect(.degrees(-90))
                            
                            // Selection indicator
                            if isSelected(date) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            selectedDate = date
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

#Preview {
    WeeklyOverviewView(currentDate: Date(), selectedDate: .constant(Date()))
}
