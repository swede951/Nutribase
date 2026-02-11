import SwiftUI

struct FoodFlagSheet: View {
    @Environment(\.dismiss) private var dismiss
    let food: FoodItem
    
    @State private var selectedIssue: FirebaseFoodFlagService.FlagIssue = .incorrectNutrition
    @State private var additionalDetails = ""
    @State private var isSubmitting = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Food Information")
                            .font(.headline)
                        
                        HStack {
                            Text("Name:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(food.name)
                                .fontWeight(.medium)
                        }
                        
                        if let brand = food.brandName, !brand.isEmpty {
                            HStack {
                                Text("Brand:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(brand)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        if let barcode = food.barcode, !barcode.isEmpty {
                            HStack {
                                Text("Barcode:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(barcode)
                                    .fontWeight(.medium)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                }
                
                Section("What's wrong with this food?") {
                    Picker("Issue Type", selection: $selectedIssue) {
                        ForEach(FirebaseFoodFlagService.FlagIssue.allCases, id: \.self) { issue in
                            Text(issue.rawValue).tag(issue)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Additional Details (Optional)") {
                    TextEditor(text: $additionalDetails)
                        .frame(minHeight: 100)
                        .overlay(
                            Group {
                                if additionalDetails.isEmpty {
                                    Text("Please provide specific details about the issue...")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Your report helps improve data quality", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("We'll review your report and update the food information if needed. Thank you for helping make Nutribase better!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                    .disabled(isSubmitting)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitFlag()
                    }
                    .foregroundColor(.primary)
                    .disabled(isSubmitting)
                    .fontWeight(.semibold)
                }
            }
            .overlay {
                if isSubmitting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Submitting report...")
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appCardBackground)
                        )
                    }
                }
            }
        }
        .alert("Report Submitted", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Thank you for your report! We'll review it and update the food information if needed.")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func submitFlag() {
        isSubmitting = true
        
        Task {
            do {
                try await FirebaseFoodFlagService.shared.submitFlag(
                    foodId: food.id.uuidString,
                    foodName: food.name,
                    brand: food.brandName,
                    barcode: food.barcode,
                    issueType: selectedIssue,
                    details: additionalDetails.isEmpty ? nil : additionalDetails
                )
                
                await MainActor.run {
                    isSubmitting = false
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    print("Food flag error: \(error.localizedDescription)")
                    errorMessage = "Unable to submit your report. Please try again later."
                    showingErrorAlert = true
                }
            }
        }
    }
}

// Preview
#Preview {
    FoodFlagSheet(food: FoodItem(
        name: "Banana",
        brandName: "Fairtrade",
        barcode: "1234567890",
        calories: 89,
        protein: 1,
        carbs: 23,
        fat: 0,
        novaScore: 1,
        nutriScoreGrade: "A"
    ))
}
