import SwiftUI
import UniformTypeIdentifiers
import Combine

struct SettingsView: View {
    @StateObject private var weightManager = WeightLogManager.shared
    @State private var showingFilePicker = false
    @State private var showingImportAlert = false
    @State private var importAlertMessage = ""
    @State private var isImportSuccessful = false
    @State private var showingClearConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section(header: Text("Account")) {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        HStack(spacing: 15) {
                            Image(systemName: "person.circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Profile")
                                    .font(.body)
                                Text("Account settings and login options")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Food Database Section - Added at the top for visibility
                Section(header: Text("Food Database")) {
                    NavigationLink {
                        AddFoodView()
                    } label: {
                        HStack(spacing: 15) {
                            Image(systemName: "plus.circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add New Food")
                                    .font(.body)
                                Text("Contribute to the food database")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Personal Information Section
                Section {
                    NavigationLink(destination: PersonalInformationView()) {
                        HStack(spacing: 15) {
                            Image(systemName: "person.crop.circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.gray)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Personal Information")
                                    .font(.body)
                                Text("Update your personal details")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    NavigationLink(destination: WeightGoalsView()) {
                        HStack(spacing: 15) {
                            Image(systemName: "arrow.clockwise")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.gray)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Weight Goals")
                                    .font(.body)
                                Text("Set your weekly weight goals")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Data Section
                Section(header: Text("Data")) {
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
                                Text("Import weight entries from a CSV file")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                    
                    NavigationLink(destination: HealthKitConnectionView()) {
                        HStack(spacing: 15) {
                            Image(systemName: "heart.circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.gray)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Connect Health App")
                                    .font(.body)
                                Text("Sync with Apple Health/Google Fit")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button(action: {
                        // Export weight data
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
                                Text("Export weight entries to a CSV file")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                    
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
                                Text("Delete all weight entries")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                
                // App Settings Section
                Section(header: Text("App Settings")) {
                    
                    NavigationLink(destination: Text("Notification Settings")) {
                        HStack(spacing: 15) {
                            Image(systemName: "bell")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.gray)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notifications")
                                    .font(.body)
                                Text("Manage app notifications")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
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
                    // Clear all weight data
                    weightManager.clearAllData()
                    
                    // Show confirmation
                    importAlertMessage = "All weight entries have been deleted."
                    isImportSuccessful = true
                    showingImportAlert = true
                }
            } message: {
                Text("Are you sure you want to delete all weight entries? This action cannot be undone.")
            }
        }
    }
    
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

#Preview {
    SettingsView()
}
