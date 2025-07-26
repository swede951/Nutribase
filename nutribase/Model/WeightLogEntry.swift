import Foundation

struct WeightLogEntry: Identifiable, Codable {
    var id: UUID
    let date: Date
    let weight: Double
    let movingAverage: Double
    let weeklyRate: Double?
    let notes: String?
    
    init(id: UUID = UUID(), date: Date, weight: Double, movingAverage: Double, weeklyRate: Double? = nil, notes: String? = nil) {
        self.id = id
        self.date = date
        self.weight = weight
        self.movingAverage = movingAverage
        self.weeklyRate = weeklyRate
        self.notes = notes
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: date)
    }
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).capitalized
    }
    
    var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    var monthYearKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}

// Extension to group entries by month
extension Array where Element == WeightLogEntry {
    func groupedByMonth() -> [String: [WeightLogEntry]] {
        let grouped = Dictionary(grouping: self) { entry in
            entry.monthYearKey
        }
        
        // Sort the dictionary by date (most recent first)
        return grouped.sorted { first, second in
            first.key > second.key
        }.reduce(into: [String: [WeightLogEntry]]()) { result, item in
            result[item.key] = item.value.sorted { $0.date > $1.date }
        }
    }
    
    func monthDisplayName(for key: String) -> String {
        if let firstEntry = self.first(where: { $0.monthYearKey == key }) {
            return firstEntry.monthYear
        }
        
        // Fallback if no entry found
        let components = key.split(separator: "-")
        if components.count == 2,
           let year = Int(components[0]),
           let month = Int(components[1]),
           month >= 1 && month <= 12 {
            let dateComponents = DateComponents(year: year, month: month)
            if let date = Calendar.current.date(from: dateComponents) {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: date)
            }
        }
        
        return key
    }
}
