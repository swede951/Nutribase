import Foundation

struct ActivityData {
    var steps: Int
    var previousSteps: Int
    
    var percentChange: Double {
        guard previousSteps > 0 else { return 0 }
        return Double(steps - previousSteps) / Double(previousSteps) * 100.0
    }
    
    var formattedPercentChange: String {
        let value = abs(percentChange)
        let sign = percentChange >= 0 ? "" : "-"
        return String(format: "%@%.1f%%", sign, value)
    }
    
    var isIncreasing: Bool {
        return steps >= previousSteps
    }
    
    static let empty = ActivityData(steps: 0, previousSteps: 0)
}
