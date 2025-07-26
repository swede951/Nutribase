import SwiftUI

struct ActivityCardView: View {
    @ObservedObject private var activityManager = ActivityManager.shared
    @State private var isLoading = false
    
    // State to track the selected date (defaults to today)
    @State private var selectedDate = Date()
    
    var body: some View {
        StatisticsCardView(
            statTitle: "Steps",
            statValue: formatSteps(activityManager.currentActivity.steps),
            statChange: 0.0, // Remove percentage change to focus only on today's data
            systemImage: nil,
            color: .primary,
            isLoading: isLoading
        )
        .onAppear {
            refreshData()
        }
        // Listen for date changes
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            // Reset to today's data when the day changes
            self.selectedDate = Date()
            refreshData()
        }
    }
    
    private func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }
    
    private func refreshData() {
        isLoading = true
        activityManager.refreshActivityData()
        
        // Set a timeout to prevent indefinite loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
        }
    }
}
