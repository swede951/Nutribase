import SwiftUI
import VisionKit
import AVKit

struct AddFoodView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var supabaseService = SupabaseService()
    private let novaScoreService = NovaScoreService.shared
    
    // Form fields
    @State private var name: String = ""
    @State private var brandName: String = ""
    @State private var barcode: String = ""
    @State private var ingredients: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var servingSize: String = ""
    @State private var servingSizeOption: ServingSizeOption?
    @State private var showCustomServingSize: Bool = false
    @State private var servingsPerPackage: String = ""
    @State private var servingType: ServingType = .weight
    @State private var novaScore: Int = 1
    @State private var isPredictedScore: Bool = false
    
    // Success feedback states
    @State private var showSuccessOverlay = false
    @State private var showSuccessToast = false
    
    // Serving type options
    enum ServingType: String, CaseIterable, Identifiable {
        case weight = "Weight"
        case volume = "Volume"
        
        var id: String { self.rawValue }
        
        var placeholder: String {
            switch self {
            case .weight:
                return "e.g., 100g, 1 oz"
            case .volume:
                return "e.g., 250ml, 1 cup"
            }
        }
        
        var icon: String {
            switch self {
            case .weight:
                return "scalemass"
            case .volume:
                return "cup.and.saucer"
            }
        }
        
        // Common serving size options based on type
        var commonOptions: [ServingSizeOption] {
            switch self {
            case .weight:
                return [
                    ServingSizeOption(label: "100g (standard)", value: "100g"),
                    ServingSizeOption(label: "1 oz (28g)", value: "28g"),
                    ServingSizeOption(label: "1 serving", value: "1 serving"),
                    ServingSizeOption(label: "1 piece", value: "1 piece"),
                    ServingSizeOption(label: "1 package", value: "1 package"),
                    ServingSizeOption(label: "Custom...", value: "")
                ]
            case .volume:
                return [
                    ServingSizeOption(label: "100ml (standard)", value: "100ml"),
                    ServingSizeOption(label: "1 cup (240ml)", value: "240ml"),
                    ServingSizeOption(label: "1 tbsp (15ml)", value: "15ml"),
                    ServingSizeOption(label: "1 tsp (5ml)", value: "5ml"),
                    ServingSizeOption(label: "1 fl oz (30ml)", value: "30ml"),
                    ServingSizeOption(label: "Custom...", value: "")
                ]
            }
        }
    }
    
    // Serving Size Option model
    struct ServingSizeOption: Identifiable, Hashable {
        let id = UUID()
        let label: String
        let value: String
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: ServingSizeOption, rhs: ServingSizeOption) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    // UI state
    @State private var isSubmitting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    @State private var shouldDismiss = false
    
    // Scanner error handling
    @State private var showingScannerError = false
    @State private var scannerErrorMessage = ""
    
    // Camera scanning state
    @State private var isScanningBarcode = false
    @State private var isScanningText = false
    @State private var isScanningNutrition = false
    @State private var scannedBarcode: String? = nil
    @State private var scannedText: String? = nil
    @State private var scannedNutrition: [String: String]? = nil
    
    // NOVA score options
    let novaOptions = [1, 2, 3, 4]
    let novaDescriptions = [
        "Unprocessed or minimally processed foods",
        "Processed culinary ingredients",
        "Processed foods",
        "Ultra-processed foods"
    ]
    
    // NOVA score colors
    func novaColor(for score: Int) -> Color {
        switch score {
        case 1: return .green
        case 2: return .blue
        case 3: return .orange
        case 4: return .red
        default: return .gray
        }
    }
    
    // Initialize notification observer for scanner errors
    init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ScannerError"),
            object: nil,
            queue: .main
        ) { [self] notification in
            if let message = notification.userInfo?["message"] as? String {
                self.scannerErrorMessage = message
                self.showingScannerError = true
            }
        }
    }
    
    // Handle changes in serving type
    private func onServingTypeChanged() {
        // Reset serving size option when type changes
        servingSizeOption = nil
        showCustomServingSize = false
        servingSize = ""
        print("🔄 Serving type changed to: \(servingType.rawValue)")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Food Information")) {
                    HStack {
                        TextField("Food Name", text: $name)
                        
                        Button(action: {
                            isScanningBarcode = true
                        }) {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .help("Scan barcode to identify food")
                    }
                    
                    HStack {
                        TextField("Brand Name", text: $brandName)
                    }
                    
                    HStack {
                        TextField("Barcode", text: $barcode)
                            .keyboardType(.numberPad)
                        
                        if !barcode.isEmpty {
                            Button(action: {
                                barcode = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Ingredients (comma separated)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            TextEditor(text: $ingredients)
                                .frame(height: 80)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            
                            Button(action: {
                                isScanningText = true
                            }) {
                                VStack {
                                    Image(systemName: "text.viewfinder")
                                        .foregroundColor(.blue)
                                        .padding(8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                            }
                            .help("Scan ingredients from packaging")
                        }
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Text("Scan nutrition label")
                        Spacer()
                        Button(action: {
                            isScanningNutrition = true
                        }) {
                            Image(systemName: "doc.viewfinder")
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .help("Scan nutrition table from packaging")
                    }
                    .padding(.bottom, 8)
                    
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("0", text: $calories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("0.0", text: $protein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Carbs (g)")
                        Spacer()
                        TextField("0.0", text: $carbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Fat (g)")
                        Spacer()
                        TextField("0.0", text: $fat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Divider()
                    
                    Picker("Serving Type", selection: $servingType) {
                        ForEach(ServingType.allCases) { type in
                            Label(type.rawValue, systemImage: type.icon)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.vertical, 4)
                    .onChange(of: servingType) { oldValue, newValue in
                        onServingTypeChanged()
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Serving Size")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        Menu {
                            ForEach(servingType.commonOptions) { option in
                                Button(action: {
                                    if option.value.isEmpty {
                                        // Custom option selected
                                        showCustomServingSize = true
                                    } else {
                                        servingSize = option.value
                                        servingSizeOption = option
                                        showCustomServingSize = false
                                    }
                                }) {
                                    Text(option.label)
                                }
                            }
                        } label: {
                            HStack {
                                Text(servingSizeOption?.label ?? "Select serving size")
                                    .foregroundColor(servingSizeOption == nil ? .gray : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        if showCustomServingSize {
                            TextField(servingType.placeholder, text: $servingSize)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.top, 4)
                        }
                    }
                    
                    HStack {
                        Text("Servings Per Package")
                        Spacer()
                        TextField("e.g., 4", text: $servingsPerPackage)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("NOVA Classification")) {
                    HStack {
                        Text("NOVA Score")
                        Spacer()
                        Button(action: predictNovaScore) {
                            Label("Predict", systemImage: "sparkles")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Picker("NOVA Score", selection: $novaScore) {
                        ForEach(novaOptions, id: \.self) { score in
                            HStack {
                                Text("Group \(score)")
                                    .foregroundColor(novaColor(for: score))
                            }
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Selected: Group \(novaScore)")
                                .font(.headline)
                                .foregroundColor(novaColor(for: novaScore))
                            
                            if isPredictedScore {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                            }
                        }
                        
                        Text(novaDescriptions[novaScore - 1])
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Button {
                        print("🔘 Add Food to Database button tapped")
                        submitFood()
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Add Food to Database")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .frame(minHeight: 44)
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle to ensure our custom styling works
                    .disabled(isSubmitting || name.isEmpty)
                }
            }
            .navigationBarTitle("Add New Food", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: HStack {
                    Button(action: {
                        isScanningBarcode = true
                    }) {
                        Image(systemName: "barcode.viewfinder")
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .help("Scan barcode to identify food")
                    
                    Button(action: {
                        isScanningText = true
                    }) {
                        VStack {
                            Image(systemName: "text.viewfinder")
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .help("Scan ingredients from packaging")
                }
            )
            // Success overlay
            .overlay(
                ZStack {
                    if showSuccessOverlay {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 20) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.white)
                                )
                            
                            Text("Food Added Successfully!")
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray6).opacity(0.9))
                        )
                        .shadow(radius: 10)
                    }
                }
                .animation(.easeInOut, value: showSuccessOverlay)
            )
            // Success toast
            .overlay(
                VStack {
                    Spacer()
                    if showSuccessToast {
                        HStack(spacing: 15) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            
                            Text("\(name) added to database")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray6))
                                .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
                        )
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(), value: showSuccessToast)
            )
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(isSuccess ? "Success" : "Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(isPresented: $showingScannerError) {
                Alert(
                    title: Text("Camera Error"),
                    message: Text(scannerErrorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $isScanningBarcode) {
                BarcodeScannerView(scannedBarcode: $scannedBarcode, isPresented: $isScanningBarcode)
                    .onDisappear {
                        if let barcode = scannedBarcode {
                            lookupFoodByBarcode(barcode)
                        }
                    }
            }
            .sheet(isPresented: $isScanningText) {
                TextScannerView(scannedText: $scannedText, isPresented: $isScanningText)
                    .onDisappear {
                        if let text = scannedText {
                            ingredients = text
                        }
                    }
            }
            .sheet(isPresented: $isScanningNutrition) {
                NutritionScannerView(scannedNutrition: $scannedNutrition, isPresented: $isScanningNutrition)
                    .onDisappear {
                        if let nutritionData = scannedNutrition {
                            // Update nutrition fields with scanned data
                            if let caloriesValue = nutritionData["calories"] {
                                calories = caloriesValue
                            }
                            if let proteinValue = nutritionData["protein"] {
                                protein = proteinValue
                            }
                            if let carbsValue = nutritionData["carbs"] {
                                carbs = carbsValue
                            }
                            if let fatValue = nutritionData["fat"] {
                                fat = fatValue
                            }
                        }
                    }
            }
        }
    }
    
    private func lookupFoodByBarcode(_ barcode: String) {
        // Show loading
        isSubmitting = true
        
        // Call Supabase to search for the barcode
        supabaseService.searchFoodByBarcode(barcode: barcode) { foodItem, error in
            isSubmitting = false
            
            if let error = error {
                alertMessage = "Error looking up barcode: \(error)"
                showingAlert = true
                return
            }
            
            if let foodItem = foodItem {
                // Populate form with food item data
                name = foodItem.name
                calories = String(foodItem.calories)
                protein = String(foodItem.protein)
                carbs = String(foodItem.carbs)
                fat = String(foodItem.fat)
                novaScore = foodItem.novaScore
                
                alertMessage = "Food found: \(foodItem.name)"
                showingAlert = true
            } else {
                alertMessage = "No food found with barcode \(barcode)"
                showingAlert = true
            }
        }
    }
    
    private func submitFood() {
        print("🍽️ Submit Food button pressed")
        
        // Validate inputs
        guard !name.isEmpty else {
            alertMessage = "Please enter a food name"
            showingAlert = true
            print("❌ Validation failed: Empty food name")
            return
        }
        
        // Parse numeric values
        print("📊 Parsing numeric values")
        print("- Calories: '\(calories)'")
        print("- Protein: '\(protein)'")
        print("- Carbs: '\(carbs)'")
        print("- Fat: '\(fat)'")
        
        guard let caloriesValue = Int(calories.isEmpty ? "0" : calories),
              let proteinValue = Double(protein.isEmpty ? "0" : protein),
              let carbsValue = Double(carbs.isEmpty ? "0" : carbs),
              let fatValue = Double(fat.isEmpty ? "0" : fat) else {
            alertMessage = "Please enter valid numeric values"
            showingAlert = true
            print("❌ Validation failed: Invalid numeric values")
            return
        }
        
        print("✅ Numeric values parsed successfully")
        
        // Parse ingredients
        let ingredientsList = ingredients.isEmpty ? [] : ingredients.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        
        // Parse serving values
        print("📊 Parsing serving values")
        
        // Get serving size from either dropdown selection or custom input
        var finalServingSize: String? = nil
        if let option = servingSizeOption, !option.value.isEmpty {
            // Use the selected option from dropdown
            finalServingSize = option.value
            print("- Serving Size (from dropdown): '\(option.label)' -> '\(option.value)'")
        } else if showCustomServingSize && !servingSize.isEmpty {
            // Use custom serving size input
            finalServingSize = servingSize
            print("- Serving Size (custom): '\(servingSize)'")
        } else if !servingSize.isEmpty {
            // Fallback to direct input if available
            finalServingSize = servingSize
            print("- Serving Size (direct): '\(servingSize)'")
        }
        
        print("- Servings Per Package: '\(servingsPerPackage)'")
        print("- Serving Type: '\(servingType.rawValue)'")
        
        let servingSizeValue = finalServingSize
        let servingsPerPackageValue = Double(servingsPerPackage.isEmpty ? "0" : servingsPerPackage)
        let servingTypeValue = servingType.rawValue
        
        print("✅ Serving values parsed successfully: \(String(describing: servingSizeValue))")
        
        // Create food item
        let foodItem = FoodItem(
            name: name,
            brandName: brandName.isEmpty ? nil : brandName,
            barcode: barcode.isEmpty ? nil : barcode,
            calories: caloriesValue,
            protein: proteinValue,
            carbs: carbsValue,
            fat: fatValue,
            novaScore: novaScore,
            servingSize: servingSizeValue,
            servingsPerPackage: servingsPerPackageValue,
            servingType: servingTypeValue
        )
        
        // Submit to Supabase
        print("📡 Submitting to Supabase...")
        isSubmitting = true
        showingAlert = false // Reset any previous alerts
        
        supabaseService.addFoodItem(foodItem, ingredients: ingredientsList) { success, error in
            DispatchQueue.main.async {
                self.isSubmitting = false
                
                if success {
                    print("✅ Food item added successfully!")
                    self.isSuccess = true
                    self.alertMessage = "Food item added successfully!"
                    
                    // Show success feedback
                    self.showSuccessOverlay = true
                    
                    // Play haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // Hide overlay after delay and show toast
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.showSuccessOverlay = false
                        self.showSuccessToast = true
                        
                        // Hide toast and dismiss after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            self.showSuccessToast = false
                            self.presentationMode.wrappedValue.dismiss()
                        }
                    }
                } else {
                    print("❌ Failed to add food item: \(error ?? "Unknown error")")
                    self.isSuccess = false
                    self.alertMessage = error ?? "Failed to add food item"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func predictNovaScore() {
        // Parse numeric values with defaults for empty fields
        let caloriesValue = Int(calories.isEmpty ? "0" : calories) ?? 0
        let proteinValue = Double(protein.isEmpty ? "0" : protein) ?? 0.0
        let carbsValue = Double(carbs.isEmpty ? "0" : carbs) ?? 0.0
        let fatValue = Double(fat.isEmpty ? "0" : fat) ?? 0.0
        
        // Parse ingredients
        let ingredientsList = ingredients.isEmpty ? [] : ingredients.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        
        // Use the NovaScoreService to predict the NOVA score
        // For better prediction, also consider the ingredients in the name
        let nameWithIngredients = name + " " + ingredientsList.joined(separator: " ")
        let tempFoodWithIngredients = FoodItem(
            name: nameWithIngredients,
            calories: caloriesValue,
            protein: proteinValue,
            carbs: carbsValue,
            fat: fatValue
        )
        
        let predictedScore = novaScoreService.predictNovaScore(for: tempFoodWithIngredients)
        
        // Update the UI
        withAnimation {
            novaScore = predictedScore
            isPredictedScore = true
        }
    }
}

#Preview {
    AddFoodView()
}

// Barcode Scanner View using VisionKit
struct BarcodeScannerView: UIViewControllerRepresentable {
    @Binding var scannedBarcode: String?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .fast,  // Changed from balanced to fast for quicker recognition
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,  // Disabled guidance for faster performance
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        
        // Set camera to auto-focus near mode for better barcode scanning
        if let captureDevice = AVCaptureDevice.default(for: .video) {
            try? captureDevice.lockForConfiguration()
            if captureDevice.isAutoFocusRangeRestrictionSupported {
                captureDevice.autoFocusRangeRestriction = .near
            }
            captureDevice.unlockForConfiguration()
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        try? uiViewController.startScanning()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: BarcodeScannerView
        private var lastProcessedTime: Date? = nil
        
        init(_ parent: BarcodeScannerView) {
            self.parent = parent
        }
        
        // Auto-detect barcodes as soon as they're recognized
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Process only the first barcode found
            guard let firstBarcode = addedItems.first else { return }
            
            // Prevent multiple rapid detections (debounce)
            let now = Date()
            if let lastTime = lastProcessedTime, now.timeIntervalSince(lastTime) < 1.0 {
                return // Skip if less than 1 second since last detection
            }
            lastProcessedTime = now
            
            // Process the barcode
            switch firstBarcode {
            case .barcode(let barcode):
                // Run on main thread and dismiss scanner
                DispatchQueue.main.async {
                    self.parent.scannedBarcode = barcode.payloadStringValue
                    self.parent.isPresented = false
                }
            default:
                break
            }
        }
        
        // Keep the tap handler for manual selection if needed
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .barcode(let barcode):
                parent.scannedBarcode = barcode.payloadStringValue
                parent.isPresented = false
            default:
                break
            }
        }
    }
}

// Text Scanner View using VisionKit
struct TextScannerView: UIViewControllerRepresentable {
    @Binding var scannedText: String?
    @Binding var isPresented: Bool
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // Check if scanning is available first
        Task { @MainActor in
            if DataScannerViewController.isAvailable && DataScannerViewController.isSupported {
                do {
                    // Check camera authorization status
                    switch AVCaptureDevice.authorizationStatus(for: .video) {
                    case .authorized:
                        // Camera access is authorized, start scanning
                        try uiViewController.startScanning()
                    case .notDetermined:
                        // Request camera access
                        let granted = await AVCaptureDevice.requestAccess(for: .video)
                        if granted {
                            try uiViewController.startScanning()
                        } else {
                            // User denied camera access
                            context.coordinator.handleError("Camera access is required for scanning")
                        }
                    case .denied, .restricted:
                        // Camera access was previously denied
                        context.coordinator.handleError("Camera access is denied. Please enable it in Settings")
                    @unknown default:
                        context.coordinator.handleError("Unknown camera authorization status")
                    }
                } catch {
                    // Handle any errors starting the scanner
                    context.coordinator.handleError("Could not start scanning: \(error.localizedDescription)")
                }
            } else {
                // Device doesn't support scanning
                context.coordinator.handleError("This device doesn't support text scanning")
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: TextScannerView
        
        init(_ parent: TextScannerView) {
            self.parent = parent
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text):
                parent.scannedText = text.transcript
                parent.isPresented = false
            default:
                break
            }
        }
        
        func handleError(_ message: String) {
            // Display error and dismiss scanner
            print("Scanner error: \(message)")
            DispatchQueue.main.async {
                self.parent.isPresented = false
                // Show an alert in the parent view
                NotificationCenter.default.post(
                    name: Notification.Name("ScannerError"),
                    object: nil,
                    userInfo: ["message": message]
                )
            }
        }
    }
}

// Nutrition Scanner View using VisionKit and Vision for nutrition table recognition
import Vision

struct NutritionScannerView: UIViewControllerRepresentable {
    @Binding var scannedNutrition: [String: String]?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // Check if scanning is available first
        Task { @MainActor in
            if DataScannerViewController.isAvailable && DataScannerViewController.isSupported {
                do {
                    // Check camera authorization status
                    switch AVCaptureDevice.authorizationStatus(for: .video) {
                    case .authorized:
                        // Camera access is authorized, start scanning
                        try uiViewController.startScanning()
                    case .notDetermined:
                        // Request camera access
                        let granted = await AVCaptureDevice.requestAccess(for: .video)
                        if granted {
                            try uiViewController.startScanning()
                        } else {
                            // User denied camera access
                            context.coordinator.handleError("Camera access is required for scanning nutrition labels")
                        }
                    case .denied, .restricted:
                        // Camera access was previously denied
                        context.coordinator.handleError("Camera access is denied. Please enable it in Settings")
                    @unknown default:
                        context.coordinator.handleError("Unknown camera authorization status")
                    }
                } catch {
                    // Handle any errors starting the scanner
                    context.coordinator.handleError("Could not start scanning: \(error.localizedDescription)")
                }
            } else {
                // Device doesn't support scanning
                context.coordinator.handleError("This device doesn't support text scanning")
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: NutritionScannerView
        var collectedText: [String] = []
        var scanStartTime: Date? = nil
        var processingInProgress = false
        
        init(_ parent: NutritionScannerView) {
            self.parent = parent
            super.init()
            scanStartTime = Date()
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .text(let text) = item {
                    // Add new recognized text to our collection
                    if !collectedText.contains(text.transcript) {
                        collectedText.append(text.transcript)
                    }
                }
            }
            
            // Check if we've been scanning for at least 3 seconds and have collected enough text
            if let startTime = scanStartTime, 
               Date().timeIntervalSince(startTime) > 3.0, 
               collectedText.count >= 5,
               !processingInProgress {
                
                processingInProgress = true
                
                // Process the collected text
                let nutritionData = parseNutritionData(from: collectedText)
                
                // If we found at least some nutrition data, return it
                if !nutritionData.isEmpty {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.parent.scannedNutrition = nutritionData
                        self.parent.isPresented = false
                    }
                } else {
                    // Reset and continue scanning if we didn't find anything useful
                    processingInProgress = false
                    scanStartTime = Date()
                }
            }
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Optional: Handle removed items if needed
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            // When user taps on a recognized text item, process all collected text
            let nutritionData = parseNutritionData(from: collectedText)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.scannedNutrition = nutritionData
                self.parent.isPresented = false
            }
        }
        
        func handleError(_ message: String) {
            // Display error and dismiss scanner
            print("Scanner error: \(message)")
            DispatchQueue.main.async {
                self.parent.isPresented = false
                // Show an alert in the parent view
                NotificationCenter.default.post(
                    name: Notification.Name("ScannerError"),
                    object: nil,
                    userInfo: ["message": message]
                )
            }
        }
        
        // MARK: - Nutrition Data Parsing
        
        func parseNutritionData(from textLines: [String]) -> [String: String] {
            var nutritionData: [String: String] = [:]
            
            // Common nutrition label keywords and their variations
            let caloriesPatterns = ["calories", "energy", "kcal"]
            let proteinPatterns = ["protein", "proteins"]
            let carbsPatterns = ["carbohydrate", "carbs", "total carbohydrate"]
            let fatPatterns = ["fat", "total fat", "fats"]
            
            // Process each line of text
            for line in textLines {
                let lowercaseLine = line.lowercased()
                
                // Extract calories
                if nutritionData["calories"] == nil, let calories = extractNutrientValue(from: lowercaseLine, patterns: caloriesPatterns) {
                    nutritionData["calories"] = calories
                }
                
                // Extract protein
                if nutritionData["protein"] == nil, let protein = extractNutrientValue(from: lowercaseLine, patterns: proteinPatterns) {
                    nutritionData["protein"] = protein
                }
                
                // Extract carbs
                if nutritionData["carbs"] == nil, let carbs = extractNutrientValue(from: lowercaseLine, patterns: carbsPatterns) {
                    nutritionData["carbs"] = carbs
                }
                
                // Extract fat
                if nutritionData["fat"] == nil, let fat = extractNutrientValue(from: lowercaseLine, patterns: fatPatterns) {
                    nutritionData["fat"] = fat
                }
            }
            
            return nutritionData
        }
        
        // Helper method to extract numeric values for a nutrient
        func extractNutrientValue(from line: String, patterns: [String]) -> String? {
            // Check if the line contains any of the patterns
            guard patterns.contains(where: { line.contains($0) }) else { return nil }
            
            // Extract numeric values using regex
            let numericRegex = try? NSRegularExpression(pattern: "\\d+([.,]\\d+)?")
            if let match = numericRegex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                if let range = Range(match.range, in: line) {
                    return String(line[range])
                }
            }
            
            return nil
        }
    }
}
