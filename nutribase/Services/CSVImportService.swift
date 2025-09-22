import Foundation
import SwiftUI
import UniformTypeIdentifiers

class CSVImportService {
    enum CSVImportError: Error {
        case invalidFormat
        case parsingError
        case dateFormatError
        
        var localizedDescription: String {
            switch self {
            case .invalidFormat:
                return "The file format is invalid. Please ensure it's a CSV file with the correct columns."
            case .parsingError:
                return "There was an error parsing the CSV data."
            case .dateFormatError:
                return "There was an error parsing dates in the CSV file."
            }
        }
    }
    
    static func parseWeightCSV(from url: URL) throws -> [WeightLogEntry] {
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw CSVImportError.invalidFormat
        }
        
        var lines = content.components(separatedBy: .newlines)
        
        // Ensure we have at least a header and one data row
        guard lines.count >= 2 else {
            throw CSVImportError.invalidFormat
        }
        
        // Parse header to identify columns
        let header = lines[0].components(separatedBy: ",")
        guard header.count >= 3,
              let dateIndex = header.firstIndex(where: { $0.lowercased() == "date" }),
              let recordedIndex = header.firstIndex(where: { $0.lowercased() == "recorded" }),
              let movingAverageIndex = header.firstIndex(where: { $0.lowercased() == "moving average" }) else {
            throw CSVImportError.invalidFormat
        }
        
        // Remove header
        lines.removeFirst()
        
        // Parse data rows
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var entries: [WeightLogEntry] = []
        
        for line in lines {
            // Skip empty lines
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            let columns = line.components(separatedBy: ",")
            
            // Ensure we have enough columns
            guard columns.count >= max(dateIndex, recordedIndex, movingAverageIndex) + 1 else {
                continue
            }
            
            // Parse date
            guard let date = dateFormatter.date(from: columns[dateIndex].trimmingCharacters(in: .whitespacesAndNewlines)) else {
                continue
            }
            
            // Parse recorded weight
            guard let recordedWeight = Double(columns[recordedIndex].trimmingCharacters(in: .whitespacesAndNewlines)) else {
                continue
            }
            
            // Parse moving average
            guard let movingAverage = Double(columns[movingAverageIndex].trimmingCharacters(in: .whitespacesAndNewlines)) else {
                continue
            }
            
            // Calculate weekly rate (if possible)
            // For now, we'll leave it as nil since it's not in the CSV
            let weeklyRate: Double? = nil
            
            // Create entry
            let entry = WeightLogEntry(
                date: date,
                weight: recordedWeight,
                movingAverage: movingAverage,
                weeklyRate: weeklyRate,
                notes: nil
            )
            
            entries.append(entry)
        }
        
        // Sort entries by date (newest first)
        entries.sort { $0.date > $1.date }
        
        return entries
    }
}

// No need for custom UTType extension, we'll use the standard types
