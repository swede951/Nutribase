import SwiftUI
import UniformTypeIdentifiers

// A service to handle weight data import operations
class WeightImportService {
    static let shared = WeightImportService()
    
    private init() {}
    
    // Opens the file picker for CSV import
    func openCSVFilePicker(showingFilePicker: Binding<Bool>) {
        // Set the binding to true to open the file picker
        DispatchQueue.main.async {
            showingFilePicker.wrappedValue = true
        }
    }
    
    // Handle CSV import from file picker result
    func handleCSVImport(result: Result<[URL], Error>, weightManager: WeightLogManager) -> (message: String, success: Bool) {
        do {
            guard let selectedFile = try result.get().first else {
                throw NSError(domain: "ImportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No file was selected"])
            }
            
            // Start file access
            guard selectedFile.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "ImportError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Permission denied to access the file"])
            }
            
            defer {
                selectedFile.stopAccessingSecurityScopedResource()
            }
            
            // Parse CSV file
            let importedEntries = try CSVImportService.parseWeightCSV(from: selectedFile)
            
            // Add entries to the shared manager
            weightManager.addEntries(importedEntries)
            
            // Return success message
            return ("Successfully imported \(importedEntries.count) weight entries.", true)
            
        } catch let error as CSVImportService.CSVImportError {
            return (error.localizedDescription, false)
        } catch {
            return ("Failed to import: \(error.localizedDescription)", false)
        }
    }
}
