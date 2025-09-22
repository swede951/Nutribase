import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices
import Combine // For potential ObservableObject usage
import HealthKit

struct WeightLogView: View {
    @ObservedObject private var weightManager = WeightLogManager.shared
    @State private var showingFilePicker = false
    @State private var showingUploadOptions = false
    @State private var showingImportAlert = false
    @State private var importAlertMessage = ""
    @State private var isImportSuccessful = false
    @State private var showingAddWeight = false
    @State private var showingSettings = false
    @State private var hasCheckedHealthUpdates = false
    @State private var autoSyncImportMessage = ""
    @State private var isAutoSyncSuccessful = false
    @State private var showingAutoSyncAlert = false
    @State private var refreshID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            // Custom header with centered title and light peach/orange background
            ZStack {
                // Center - title (positioned absolutely in the center)
                Text("Logbook")
                    .font(.custom("Montserrat-Bold", size: 17))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                
                // Left side - add weight button (only show if there's data)
                HStack {
                    // Add weight button (only show if there's data)
                    if !weightManager.weightEntries.isEmpty {
                        Button(action: {
                            showingAddWeight = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.primary)
                        }
                        .help("Add Weight Entry")
                    }
                    
                    Spacer()
                }
                
                // Right side - buttons (only show if there's data)
                HStack {
                    Spacer()
                    
                    if !weightManager.weightEntries.isEmpty {
                        // Import button
                        Button(action: {
                            showingUploadOptions = true
                        }) {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.primary)
                        }
                        .help("Import CSV")
                        
                        // Settings button
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .padding(.top, 1) // Reduced top padding
            .background(Color(hex: "#F0F1F4"))
            
            if !weightManager.hasLoadedAllEntries {
                // Show loading indicator while entries are being loaded
                VStack {
                    Spacer()
                    ProgressView("Loading weight data...")
                        .progressViewStyle(CircularProgressViewStyle())
                    Spacer()
                }
                .onAppear {
                    print("[WeightLogView] Showing loading screen - hasLoadedAllEntries: \(weightManager.hasLoadedAllEntries), entries count: \(weightManager.weightEntries.count)")
                }
            } else if weightManager.weightEntries.isEmpty {
                // Show empty state view with import options
                WeightEmptyStateView(showingFilePicker: $showingFilePicker, weightManager: weightManager)
            } else {
                // Show weight entries
                ScrollView(.vertical, showsIndicators: true) {
                    // Apply background color to the entire ScrollView
                    ZStack {
                        // Background color layer - using light gray background to match Phases view
                        Color(hex: "#F0F1F4")
                            .ignoresSafeArea(.all)
                        
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
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
                .scrollDisabled(false)
                .clipped()
            }
        }
        .background(Color(hex: "#F0F1F4"))
        .id(refreshID)
        // No need to load sample data as it's handled by the WeightLogManager
        .sheet(isPresented: $showingUploadOptions) {
            WeightUploadOptionsView(showingFilePicker: $showingFilePicker)
        }
        .sheet(isPresented: $showingAddWeight) {
            AddWeightEntryView(weightManager: weightManager)
                .onDisappear {
                    // Force complete UI restart by changing the ID
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        refreshID = UUID()
                        weightManager.hasLoadedAllEntries = false
                        weightManager.loadLocalEntries()
                    }
                }
        }
        .sheet(isPresented: $showingSettings) {
            WeightSettingsView(showingUploadOptions: $showingUploadOptions)
        }
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
        .onAppear {
            // Check for automatic Health app updates when the view appears
            checkForHealthAppUpdates()
        }
        .alert(isPresented: $showingAutoSyncAlert) {
            Alert(
                title: Text(isAutoSyncSuccessful ? "Auto-Sync Successful" : "Auto-Sync Failed"),
                message: Text(autoSyncImportMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Handle CSV import from the WeightLogView (when using the import button in the toolbar)
    private func handleCSVImport(result: Result<[URL], Error>) {
        // Use the shared service to handle the CSV import
        let importResult = WeightImportService.shared.handleCSVImport(result: result, weightManager: weightManager)
        
        // Update the UI based on the result
        importAlertMessage = importResult.message
        isImportSuccessful = importResult.success
        showingImportAlert = true
    }
    
    // Check for new weight entries from Health app when the app opens
    private func checkForHealthAppUpdates() {
        // Only check once per app session and only if the feature is enabled
        if !hasCheckedHealthUpdates && UserDefaults.standard.bool(forKey: "autoSyncHealthWeight") {
            hasCheckedHealthUpdates = true
            
            // Check if HealthKit is available
            guard HKHealthStore.isHealthDataAvailable() else {
                print("HealthKit not available on this device")
                return
            }
            
            // Get the date of the last sync
            let lastSyncDate = UserDefaults.standard.object(forKey: "lastHealthWeightSyncDate") as? Date ?? Date.distantPast
            let currentDate = Date()
            
            // Fetch weight data since the last sync
            let healthKitManager = HealthKitManager.shared
            healthKitManager.fetchWeightData(from: lastSyncDate, to: currentDate) { weightEntries, error in
                if let error = error {
                    print("Error fetching weight data: \(error.localizedDescription)")
                    return
                }
                
                // If we found new entries, add them to the weight log
                if !weightEntries.isEmpty {
                    DispatchQueue.main.async {
                        self.weightManager.addEntries(weightEntries)
                        
                        // Show a subtle notification that new entries were added
                        self.autoSyncImportMessage = "\(weightEntries.count) new weight entries were automatically imported from Health app."
                        self.isAutoSyncSuccessful = true
                        self.showingAutoSyncAlert = true
                    }
                }
                
                // Update the last sync date
                UserDefaults.standard.set(currentDate, forKey: "lastHealthWeightSyncDate")
            }
        }
    }
}

struct MonthCardView: View {
    let monthName: String
    let entries: [WeightLogEntry]
    @StateObject private var weightManager = WeightLogManager.shared
    @State private var showDeleteConfirmation = false
    @State private var entryToDelete: WeightLogEntry? = nil
    @State private var localEntries: [WeightLogEntry]
    
    init(monthName: String, entries: [WeightLogEntry]) {
        self.monthName = monthName
        self.entries = entries
        _localEntries = State(initialValue: entries)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Month header
            Text(monthName.uppercased())
                .font(.custom("Montserrat-SemiBold", size: 17))
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
            
            // Use custom swipe-to-delete implementation
            VStack(spacing: 0) {
                ForEach(localEntries) { entry in
                    SwipeToDeleteRow(
                        entry: entry,
                        onDelete: {
                            entryToDelete = entry
                            showDeleteConfirmation = true
                        }
                    )
                    
                    if entry.id != localEntries.last?.id {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#FFFFFF"))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16)) // Ensure content respects rounded corners
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2) // Shadow applied AFTER clipping
        .alert("Delete Weight Entry?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { 
                entryToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete, let index = weightManager.weightEntries.firstIndex(where: { $0.id == entry.id }) {
                    weightManager.deleteEntry(at: IndexSet(integer: index))
                    
                    // Also remove from local entries to update the UI immediately
                    if let localIndex = localEntries.firstIndex(where: { $0.id == entry.id }) {
                        localEntries.remove(at: localIndex)
                    }
                }
                entryToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this weight entry? This action cannot be undone.")
        }
    }
}

// Custom swipe-to-delete row component
struct SwipeToDeleteRow: View {
    let entry: WeightLogEntry
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var showingDeleteButton = false
    
    private let deleteButtonWidth: CGFloat = 80
    private let swipeThreshold: CGFloat = 50
    
    var body: some View {
        ZStack {
            // Background delete button
            HStack {
                Spacer()
                
                Button(action: onDelete) {
                    VStack {
                        Image(systemName: "trash")
                            .font(.title2)
                        Text("Delete")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: deleteButtonWidth)
                }
                .frame(maxHeight: .infinity)
                .background(Color.red)
            }
            
            // Main content row
            WeightLogRowView(entry: entry)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.white)
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.width
                            let verticalTranslation = value.translation.height
                            
                            // Only handle horizontal swipes that are clearly intentional
                            // Require significant horizontal movement AND minimal vertical movement
                            if abs(translation) > 20 && abs(verticalTranslation) < abs(translation) * 0.5 {
                                if translation < 0 {
                                    offset = max(translation, -deleteButtonWidth)
                                } else if offset < 0 {
                                    offset = min(0, offset + translation)
                                }
                            }
                        }
                        .onEnded { value in
                            let translation = value.translation.width
                            let velocity = value.velocity.width
                            let verticalTranslation = value.translation.height
                            
                            // Only handle horizontal swipes that are clearly intentional
                            if abs(translation) > 20 && abs(verticalTranslation) < abs(translation) * 0.5 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if translation < -swipeThreshold || velocity < -500 {
                                        offset = -deleteButtonWidth
                                        showingDeleteButton = true
                                    } else {
                                        offset = 0
                                        showingDeleteButton = false
                                    }
                                }
                            } else {
                                // Reset if gesture wasn't clearly horizontal
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    offset = 0
                                    showingDeleteButton = false
                                }
                            }
                        }
                )
        }
        .clipped()
        .onTapGesture {
            // Tap to close delete button if showing
            if showingDeleteButton {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    offset = 0
                    showingDeleteButton = false
                }
            }
        }
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

struct AddWeightEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var weightManager: WeightLogManager
    
    @State private var weight: String = ""
    @State private var selectedDate = Date()
    @State private var notes: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDatePicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Weight Entry") {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("0.0", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("kg")
                            .foregroundColor(.secondary)
                    }
                    
                    // Custom date picker that auto-hides after selection
                    VStack(alignment: .leading, spacing: 0) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingDatePicker.toggle()
                            }
                        }) {
                            HStack {
                                Text("Date")
                                Spacer()
                                Text(DateFormatter.shortDate.string(from: selectedDate))
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showingDatePicker {
                            DatePicker("", selection: Binding(
                                get: { selectedDate },
                                set: { newDate in
                                    selectedDate = newDate
                                    // Auto-hide calendar after selection
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showingDatePicker = false
                                    }
                                }
                            ), displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                }
                
                Section("Notes (Optional)") {
                    TextField("Add any notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveWeightEntry()
                    }
                    .disabled(weight.isEmpty)
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveWeightEntry() {
        guard let weightValue = Double(weight), weightValue > 0 else {
            errorMessage = "Please enter a valid weight"
            showingError = true
            return
        }
        
        let newEntry = WeightLogEntry(
            id: UUID(),
            date: selectedDate,
            weight: weightValue,
            movingAverage: weightValue, // Will be recalculated by the manager
            weeklyRate: nil,
            notes: notes.isEmpty ? nil : notes
        )
        
        print("DEBUG: About to add entry with weight: \(weightValue), date: \(selectedDate)")
        weightManager.addEntry(newEntry)
        print("DEBUG: Entry added, current weightEntries count: \(weightManager.weightEntries.count)")
        
        // Clear the form to show it was saved
        weight = ""
        notes = ""
        selectedDate = Date()
    }
}

// MARK: - Empty State View
struct WeightEmptyStateView: View {
    @Binding var showingFilePicker: Bool
    @State private var showingAddWeight = false
    @State private var showingHealthImportAlert = false
    @State private var healthImportMessage = ""
    @State private var isHealthImportSuccessful = false
    @State private var isImportingFromHealth = false
    @State private var showingImportAlert = false
    @State private var importAlertMessage = ""
    @State private var isImportSuccessful = false
    
    @StateObject private var healthKitManager = HealthKitManager.shared
    @ObservedObject var weightManager: WeightLogManager
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
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
            
            // Options
            VStack(spacing: 16) {
                // CSV File Import Option
                Button(action: {
                    showingFilePicker = true
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
                
                // Manual Entry Option
                Button(action: {
                    // Show the add weight entry form
                    showingAddWeight = true
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
                        Image(systemName: "heart")
                            .font(.title2)
                            .foregroundColor(.red)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Import from Health App")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Sync weight data from Apple Health")
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
            .padding(.horizontal, 20)
            
            Spacer()
            
            // CSV Format Info
            VStack(spacing: 8) {
                Text("CSV Format Requirements")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Your CSV file should have columns: Date, Weight")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Date format: YYYY-MM-DD")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Weight in kg or lbs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .alert("Health App Import", isPresented: $showingHealthImportAlert) {
            Button("OK") {
                // Alert dismissed
            }
        } message: {
            Text(healthImportMessage)
        }
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
        .sheet(isPresented: $showingAddWeight) {
            AddWeightEntryView(weightManager: weightManager)
                .onDisappear {
                    // Force complete refresh like app startup
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        weightManager.hasLoadedAllEntries = false
                        weightManager.loadLocalEntries()
                    }
                }
        }
    }
    
    private func importFromHealthApp() {
        print("[WeightEmptyStateView] Starting Health App import...")
        isImportingFromHealth = true
        
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[WeightEmptyStateView] HealthKit not available")
            healthImportMessage = "HealthKit is not available on this device."
            isHealthImportSuccessful = false
            showingHealthImportAlert = true
            isImportingFromHealth = false
            return
        }
        
        // Skip authorization checking and go straight to data fetch
        // The actual HealthKit query will handle authorization properly
        print("[WeightEmptyStateView] Attempting direct data fetch...")
        performHealthImport()
    }
    
    private func performHealthImport() {
        print("[WeightEmptyStateView] Calling fetchAllWeightData...")
        healthKitManager.fetchAllWeightData { [self] weightEntries, error in
            print("[WeightEmptyStateView] fetchAllWeightData completed - Entries: \(weightEntries.count), Error: \(error?.localizedDescription ?? "none")")
            self.isImportingFromHealth = false
            
            if let error = error {
                print("[WeightEmptyStateView] Import error: \(error.localizedDescription)")
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
    
    // Handle CSV import from the empty state view
    private func handleCSVImport(result: Result<[URL], Error>) {
        // Use the shared service to handle the CSV import
        let importResult = WeightImportService.shared.handleCSVImport(result: result, weightManager: weightManager)
        
        // Update the UI based on the result
        importAlertMessage = importResult.message
        isImportSuccessful = importResult.success
        showingImportAlert = true
    }
}

// MARK: - Weight Settings View
struct WeightSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var weightManager = WeightLogManager.shared
    @State private var showingDeleteConfirmation = false
    @State private var showingExportSuccess = false
    @State private var exportMessage = ""
    @Binding var showingUploadOptions: Bool
    
    // State for auto-sync toggle
    @State private var autoSyncHealthData: Bool = UserDefaults.standard.bool(forKey: "autoSyncHealthWeight")
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Display Options")) {
                    Toggle("Show Moving Average", isOn: .constant(true))
                    Toggle("Show Weekly Rate", isOn: .constant(true))
                }
                
                Section(header: Text("Health App Integration")) {
                    Toggle("Auto-sync Weight from Health", isOn: $autoSyncHealthData)
                        .onChange(of: autoSyncHealthData) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "autoSyncHealthWeight")
                        }
                    
                    Text("When enabled, new weight entries from the Health app will be automatically imported each time the app is opened.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Units")) {
                    Picker("Weight Unit", selection: .constant(0)) {
                        Text("kg").tag(0)
                        Text("lbs").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Data Management")) {
                    Button(action: {
                        showingUploadOptions = true
                        dismiss()
                    }) {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }
                    
                    Button(action: {
                        // Export data as CSV
                        exportWeightDataToCSV()
                    }) {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive, action: {
                        showingDeleteConfirmation = true
                    }) {
                        Label("Clear All Data", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Weight Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete All Weight Data?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    weightManager.clearAllData()
                }
            } message: {
                Text("This will permanently delete all your weight entries. This action cannot be undone.")
            }
            .alert(isPresented: $showingExportSuccess) {
                Alert(
                    title: Text("Export Complete"),
                    message: Text(exportMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // No need for a computed property anymore as we're using @Binding
    
    // Function to export weight data to CSV
    private func exportWeightDataToCSV() {
        let entries = weightManager.weightEntries
        
        if entries.isEmpty {
            exportMessage = "No weight data to export."
            showingExportSuccess = true
            return
        }
        
        // Create CSV content
        var csvString = "Date,Weight,Notes\n"
        
        for entry in entries {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: entry.date)
            
            // Format weight with 1 decimal place
            let weightString = String(format: "%.1f", entry.weight)
            
            // Escape notes if they contain commas
            var notes = entry.notes ?? ""
            if notes.contains(",") {
                notes = "\"\(notes)\""
            }
            
            csvString += "\(dateString),\(weightString),\(notes)\n"
        }
        
        // Get the documents directory URL
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            exportMessage = "Error accessing documents directory."
            showingExportSuccess = true
            return
        }
        
        // Create a unique filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "weight_export_\(timestamp).csv"
        
        // Create the file URL
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        do {
            // Write to file
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // Share the file
            exportMessage = "Weight data exported successfully to \(filename) in your Documents folder."
            showingExportSuccess = true
            
            // Here you could also add code to share the file via UIActivityViewController if desired
            
        } catch {
            exportMessage = "Error exporting data: \(error.localizedDescription)"
            showingExportSuccess = true
        }
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

#Preview {
    Group {
        WeightLogView()
            .preferredColorScheme(.light)
        
        // Preview for WeightSettingsView
        WeightSettingsView(showingUploadOptions: .constant(false))
            .preferredColorScheme(.light)
    }
}
