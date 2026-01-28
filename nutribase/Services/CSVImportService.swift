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
        guard header.count >= 2 else {
            throw CSVImportError.invalidFormat
        }
        
        // Try to detect the CSV format
        let isRenphoFormat = header.contains { $0.contains("Time of Measurement") } && header.contains { $0.contains("Weight(kg)") }
        let isNutribaseFormat = header.contains { $0.lowercased() == "date" } && header.contains { $0.lowercased() == "recorded" }
        
        var dateIndex: Int?
        var weightIndex: Int?
        var movingAverageIndex: Int?
        
        if isRenphoFormat {
            // Renpho format: "Time of Measurement", "Weight(kg)", etc.
            dateIndex = header.firstIndex { $0.contains("Time of Measurement") }
            weightIndex = header.firstIndex { $0.contains("Weight(kg)") }
            // Renpho doesn't have moving average, we'll use weight for both
            movingAverageIndex = weightIndex
        } else if isNutribaseFormat {
            // Original Nutribase format: "date", "recorded", "moving average"
            dateIndex = header.firstIndex { $0.lowercased() == "date" }
            weightIndex = header.firstIndex { $0.lowercased() == "recorded" }
            movingAverageIndex = header.firstIndex { $0.lowercased() == "moving average" }
        } else {
            // Try generic weight CSV formats
            dateIndex = header.firstIndex { $0.lowercased().contains("date") || $0.lowercased().contains("time") }
            weightIndex = header.firstIndex { $0.lowercased().contains("weight") }
            movingAverageIndex = weightIndex // Use weight as moving average if no separate column
        }
        
        guard let dateIdx = dateIndex, let weightIdx = weightIndex, let movingAvgIdx = movingAverageIndex else {
            throw CSVImportError.invalidFormat
        }
        
        // Remove header
        lines.removeFirst()
        
        // Setup date formatters for different formats
        let dateFormatters = [
            createDateFormatter("yyyy-MM-dd"), // Nutribase format
            createDateFormatter("MM/dd/yyyy, HH:mm:ss"), // Renpho format
            createDateFormatter("MM/dd/yyyy"), // Simple US format
            createDateFormatter("dd/MM/yyyy"), // Simple EU format
            createDateFormatter("yyyy/MM/dd") // ISO-like format
        ]
        
        var entries: [WeightLogEntry] = []
        
        for line in lines {
            // Skip empty lines
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            // Handle quoted CSV values (Renpho uses quotes)
            let columns = parseCSVLine(line)
            
            // Ensure we have enough columns
            guard columns.count > max(dateIdx, weightIdx, movingAvgIdx) else {
                continue
            }
            
            // Parse date with multiple formatters
            let dateString = columns[dateIdx].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
            var date: Date?
            for formatter in dateFormatters {
                if let parsedDate = formatter.date(from: dateString) {
                    date = parsedDate
                    break
                }
            }
            
            guard let parsedDate = date else {
                print("Failed to parse date: \(dateString)")
                continue
            }
            
            // Parse weight
            let weightString = columns[weightIdx].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
            guard let weight = Double(weightString) else {
                print("Failed to parse weight: \(weightString)")
                continue
            }
            
            // Parse moving average (use weight if no separate column)
            let movingAvgString = columns[movingAvgIdx].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
            let movingAverage = Double(movingAvgString) ?? weight
            
            // Create entry
            let entry = WeightLogEntry(
                date: parsedDate,
                weight: weight,
                movingAverage: movingAverage,
                weeklyRate: nil,
                notes: nil
            )
            
            entries.append(entry)
        }
        
        // Sort entries by date (newest first)
        entries.sort { $0.date > $1.date }
        
        return entries
    }
    
    // Helper function to create date formatter
    private static func createDateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
    
    // Helper function to parse CSV line with quoted values
    private static func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                columns.append(currentColumn)
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }
            
            i = line.index(after: i)
        }
        
        // Add the last column
        columns.append(currentColumn)
        
        return columns
    }
}

// No need for custom UTType extension, we'll use the standard types
