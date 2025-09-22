import SwiftUI
import UniformTypeIdentifiers
import HealthKit

struct WeightUploadOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showingFilePicker: Bool
    
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var showingHealthImportAlert = false
    @State private var healthImportMessage = ""
    @State private var isHealthImportSuccessful = false
    @State private var isImportingFromHealth = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Import Weight Data")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose how you'd like to import your weight data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Options
                VStack(spacing: 16) {
                    // CSV File Import Option
                    Button(action: {
                        dismiss()
                        // Use the shared service to open the file picker
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            WeightImportService.shared.openCSVFilePicker(showingFilePicker: $showingFilePicker)
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Import from CSV File")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Import weight data from a CSV file")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Manual Entry Option (for future implementation)
                    Button(action: {
                        // TODO: Implement manual entry
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                                .foregroundColor(.green)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Manual Entry")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Add weight entries manually")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Health App Import Option
                    Button(action: {
                        importFromHealthApp()
                    }) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Import from Health App")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(isImportingFromHealth ? "Importing weight data..." : "Sync weight data from Apple Health")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isImportingFromHealth {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isImportingFromHealth)
                }
                
                Spacer()
                
                // CSV Format Info
                VStack(spacing: 8) {
                    Text("CSV Format Requirements")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Your CSV file should have columns: Date, Weight\nDate format: YYYY-MM-DD\nWeight in kg or lbs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    dismiss()
                }
            )
        }
        .alert("Health App Import", isPresented: $showingHealthImportAlert) {
            Button("OK") {
                if isHealthImportSuccessful {
                    dismiss()
                }
            }
        } message: {
            Text(healthImportMessage)
        }
    }
    
    // MARK: - Health App Import Function
    
    private func importFromHealthApp() {
        print("[WeightUploadOptionsView] Starting Health App import...")
        isImportingFromHealth = true
        
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[WeightUploadOptionsView] HealthKit not available")
            healthImportMessage = "HealthKit is not available on this device."
            isHealthImportSuccessful = false
            showingHealthImportAlert = true
            isImportingFromHealth = false
            return
        }
        
        // Skip authorization checking and go straight to data fetch
        // The actual HealthKit query will handle authorization properly
        print("[WeightUploadOptionsView] Attempting direct data fetch...")
        performHealthImport()
    }
    
    private func performHealthImport() {
        print("[WeightUploadOptionsView] Calling fetchAllWeightData...")
        healthKitManager.fetchAllWeightData { [self] weightEntries, error in
            print("[WeightUploadOptionsView] fetchAllWeightData completed - Entries: \(weightEntries.count), Error: \(error?.localizedDescription ?? "none")")
            self.isImportingFromHealth = false
            
            if let error = error {
                print("[WeightUploadOptionsView] Import error: \(error.localizedDescription)")
                // Check if it's an authorization error
                if error.localizedDescription.contains("not authorized") || error.localizedDescription.contains("authorization") {
                    self.healthImportMessage = "Weight data access was not granted. Please go to Settings > Health > Data Access & Devices > Nutribase and enable weight data access. You may need to restart the app after granting permission."
                } else {
                    self.healthImportMessage = "Failed to import weight data: \(error.localizedDescription)"
                }
                self.isHealthImportSuccessful = false
                self.showingHealthImportAlert = true
                return
            }
            
            if weightEntries.isEmpty {
                self.healthImportMessage = "No weight data found in Health app."
                self.isHealthImportSuccessful = false
                self.showingHealthImportAlert = true
                return
            }
            
            // Import the weight entries using WeightLogManager
            let weightLogManager = WeightLogManager.shared
            
            // Add the weight entries as-is (no additional notes)
            weightLogManager.addEntries(weightEntries)
            
            self.healthImportMessage = "Successfully imported \(weightEntries.count) weight entries from Health app."
            self.isHealthImportSuccessful = true
            self.showingHealthImportAlert = true
        }
    }
}

#Preview {
    WeightUploadOptionsView(showingFilePicker: .constant(false))
}
