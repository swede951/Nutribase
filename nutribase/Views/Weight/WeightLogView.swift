import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices
import Combine // For potential ObservableObject usage

struct WeightLogView: View {
    @StateObject private var weightManager = WeightLogManager.shared
    @State private var showingFilePicker = false
    @State private var showingImportAlert = false
    @State private var importAlertMessage = ""
    @State private var isImportSuccessful = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header with centered title and light peach/orange background
            ZStack {
                // Center - title (positioned absolutely in the center)
                Text("Logbook")
                    .font(.headline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                
                // Right side - buttons
                HStack {
                    Spacer()
                    
                    // Import button
                    Button(action: {
                        showingFilePicker = true
                    }) {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.primary)
                    }
                    .help("Import CSV")
                    
                    // Settings button
                    Button(action: {
                        // Show settings
                    }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .padding(.top, 1) // Reduced top padding
            .background(Color(red: 1.0, green: 0.827, blue: 0.651)) // #ffd2a6 converted to RGB
            
            // Main content
            ScrollView {
                // Apply background color to the entire ScrollView
                ZStack {
                    // Background color layer - using system background
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    
                    LazyVStack(spacing: 16) {
                        ForEach(Array(weightManager.groupedEntries.keys.sorted(by: >)), id: \.self) { monthKey in
                            if let entries = weightManager.groupedEntries[monthKey] {
                                MonthCardView(
                                    monthName: weightManager.weightEntries.monthDisplayName(for: monthKey),
                                    entries: entries
                                )
                                .id(monthKey) // Add id for scroll position tracking
                            }
                        }
                        
                        // Load more indicator at the bottom
                        if !weightManager.hasLoadedAllEntries {
                            ProgressView("Loading more entries...")
                                .padding()
                                .onAppear {
                                    // Load more entries when this view appears (user scrolled to bottom)
                                    weightManager.loadMoreEntries()
                                }
                        }
                    }
                    .padding()
                }
            }

        }
        // No need to load sample data as it's handled by the WeightLogManager
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
    }
    
    // Handle CSV import from the WeightLogView (when using the import button in the toolbar)
    private func handleCSVImport(result: Result<[URL], Error>) {
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
            
            // Show success message
            importAlertMessage = "Successfully imported \(importedEntries.count) weight entries."
            isImportSuccessful = true
            showingImportAlert = true
            
        } catch let error as CSVImportService.CSVImportError {
            importAlertMessage = error.localizedDescription
            isImportSuccessful = false
            showingImportAlert = true
        } catch {
            importAlertMessage = "Failed to import: \(error.localizedDescription)"
            isImportSuccessful = false
            showingImportAlert = true
        }
    }
}

struct MonthCardView: View {
    let monthName: String
    let entries: [WeightLogEntry]
    
    var body: some View {
        VStack(spacing: 0) {
            // Month header
            Text(monthName.uppercased())
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            
            // Table header
            HStack {
                Text("Date")
                    .frame(width: 60, alignment: .leading)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Recorded")
                    .frame(maxWidth: .infinity)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Moving\nAverage")
                    .frame(maxWidth: .infinity)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Weekly\nRate")
                    .frame(maxWidth: .infinity)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Notes")
                    .frame(maxWidth: .infinity)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // Table rows
            ForEach(entries) { entry in
                WeightLogRowView(entry: entry)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                
                if entry.id != entries.last?.id {
                    Divider()
                        .padding(.horizontal)
                }
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.2)) // Increased shadow opacity
                    .offset(y: 3) // Increased shadow offset
                    .blur(radius: 6) // Increased blur radius
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1.0) // Border
                    )
            }
        )
        .padding(8) // Increased padding around the card for shadow visibility
    }
}

struct WeightLogRowView: View {
    let entry: WeightLogEntry
    
    var body: some View {
        HStack(alignment: .center) {
            // Date column
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.formattedDate)
                    .font(.system(size: 18, weight: .medium))
                Text(entry.dayOfWeek)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60, alignment: .leading)
            
            // Recorded weight
            Text(String(format: "%.1f", entry.weight))
                .font(.system(size: 18, weight: .medium))
                .frame(maxWidth: .infinity)
            
            // Moving average
            Text(String(format: "%.1f", entry.movingAverage))
                .font(.system(size: 18, weight: .medium))
                .frame(maxWidth: .infinity)
            
            // Weekly rate
            if let weeklyRate = entry.weeklyRate {
                HStack(spacing: 2) {
                    Image(systemName: weeklyRate < 0 ? "arrow.down" : "arrow.up")
                        .foregroundColor(weeklyRate < 0 ? .red : .green)
                        .font(.caption)
                    
                    Text(String(format: "%.1f", abs(weeklyRate)))
                        .foregroundColor(weeklyRate < 0 ? .red : .green)
                        .font(.system(size: 18, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(weeklyRate < 0 ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                )
                .frame(maxWidth: .infinity)
            } else {
                Text("-")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
            
            // Notes
            if let notes = entry.notes, !notes.isEmpty {
                Text(notes)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("-")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview {
    WeightLogView()
        .preferredColorScheme(.light)
}
