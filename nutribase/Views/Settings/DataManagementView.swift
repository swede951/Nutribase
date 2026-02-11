import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var weightManager = WeightLogManager.shared
    @State private var showingFilePicker = false
    @State private var showingImportAlert = false
    @State private var importAlertMessage = ""
    @State private var isImportSuccessful = false
    @State private var showingClearConfirmation = false
    @State private var csvDocument: CSVDocument? = nil
    @State private var showingExporter = false
    
    private var viewBackground: Color {
        Color.appBackground
    }
    
    var body: some View {
        ZStack {
            // Background
            viewBackground
                .ignoresSafeArea()
            
            Form {
                Section {
                    // Import CSV
                    Button(action: {
                        showingFilePicker = true
                    }) {
                        HStack(spacing: 15) {
                            Image(systemName: "arrow.down.doc")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.gray)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Import CSV")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("Import weight entries from a CSV file")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.appCardBackground)
                    
                    // Connect Health App
                    NavigationLink(destination: HealthKitConnectionView()) {
                        HStack(spacing: 15) {
                            Image(systemName: "heart.circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.pink)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Connect Health App")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("Sync with Apple Health")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.appCardBackground)
                    
                    // Export Weight Data
                    Button(action: {
                        exportWeightData()
                    }) {
                        HStack(spacing: 15) {
                            Image(systemName: "arrow.up.doc")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.gray)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Export Weight Data")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("Export weight entries to CSV")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.appCardBackground)
                    
                    // Clear Weight Data
                    Button(action: {
                        showingClearConfirmation = true
                    }) {
                        HStack(spacing: 15) {
                            Image(systemName: "trash")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Clear Weight Data")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("Delete all weight entries")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.appCardBackground)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Data Management")
        .toolbarBackground(viewBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleCSVImport(result: result)
        }
        .alert(
            isImportSuccessful ? "Import Successful" : "Import Failed",
            isPresented: $showingImportAlert,
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(importAlertMessage) }
        )
        .alert("Clear Weight Data", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                weightManager.clearAllData()
                importAlertMessage = "All weight entries have been deleted."
                isImportSuccessful = true
                showingImportAlert = true
            }
        } message: {
            Text("Are you sure you want to delete all weight entries? This action cannot be undone.")
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "nutribase_weight_export"
        ) { result in
            switch result {
            case .success(let url):
                importAlertMessage = "Weight data exported successfully!"
                isImportSuccessful = true
                showingImportAlert = true
            case .failure(let error):
                print("Export error: \(error.localizedDescription)")
                importAlertMessage = "Export failed. Please check your storage and try again."
                isImportSuccessful = false
                showingImportAlert = true
            }
        }
    }
    
    private func exportWeightData() {
        let entries = weightManager.weightEntries.sorted { $0.date < $1.date }
        
        guard !entries.isEmpty else {
            importAlertMessage = "No weight entries to export."
            isImportSuccessful = false
            showingImportAlert = true
            return
        }
        
        // Create CSV content
        var csvContent = "Date,Weight (kg),Moving Average (kg),Weekly Rate (kg/week),Notes\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for entry in entries {
            let dateStr = dateFormatter.string(from: entry.date)
            let weight = String(format: "%.1f", entry.weight)
            let movingAvg = String(format: "%.1f", entry.movingAverage)
            let weeklyRate = entry.weeklyRate != nil ? String(format: "%.2f", entry.weeklyRate!) : ""
            let notes = entry.notes?.replacingOccurrences(of: ",", with: ";").replacingOccurrences(of: "\n", with: " ") ?? ""
            
            csvContent += "\(dateStr),\(weight),\(movingAvg),\(weeklyRate),\(notes)\n"
        }
        
        csvDocument = CSVDocument(content: csvContent)
        showingExporter = true
    }
    
    private func handleCSVImport(result: Result<[URL], Error>) {
        do {
            guard let selectedFile = try result.get().first else {
                throw NSError(domain: "ImportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No file was selected"])
            }
            
            guard selectedFile.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "ImportError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Permission denied to access the file"])
            }
            
            defer {
                selectedFile.stopAccessingSecurityScopedResource()
            }
            
            let importedEntries = try CSVImportService.parseWeightCSV(from: selectedFile)
            weightManager.addEntries(importedEntries)
            
            importAlertMessage = "Successfully imported \(importedEntries.count) weight entries."
            isImportSuccessful = true
            showingImportAlert = true
            
        } catch let error as CSVImportService.CSVImportError {
            print("CSV import error: \(error.localizedDescription)")
            importAlertMessage = "Import failed. Please ensure the CSV file is properly formatted."
            isImportSuccessful = false
            showingImportAlert = true
        } catch {
            print("Import error: \(error.localizedDescription)")
            importAlertMessage = "Failed to import. Please check the file format and try again."
            isImportSuccessful = false
            showingImportAlert = true
        }
    }
}

// MARK: - CSV Document for FileExporter
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    
    var content: String
    
    init(content: String = "") {
        self.content = content
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            content = string
        } else {
            content = ""
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    NavigationStack {
        DataManagementView()
    }
}
