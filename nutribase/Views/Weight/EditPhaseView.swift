//
//  EditPhaseView.swift
//  nutribase
//
//  Created on 25/08/2025.
//

import SwiftUI

struct EditPhaseView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var phaseManager = WeightPhaseManager.shared
    let phase: WeightPhase
    
    @State private var name: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var targetWeeklyRate: Double = -0.5
    @State private var goalWeight: String = ""
    @State private var currentWeight: Double = 0.0
    @State private var selectedColor: PhaseColor = .red
    @State private var notes: String = ""
    
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Phase Details") {
                    TextField("Phase Name", text: $name)
                        .textInputAutocapitalization(.words)
                }
                
                Section("Date Range") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    
                    if startDate >= endDate {
                        Text("End date must be after start date")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section("Target") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Current Weight:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(String(format: "%.1f", currentWeight)) kg")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Goal Weight:")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            TextField("Enter goal weight", text: $goalWeight)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 100)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        if let goalWeightValue = Double(goalWeight), goalWeightValue > 0 {
                            let weightDifference = goalWeightValue - currentWeight
                            let phaseDurationWeeks = calculatePhaseDurationInWeeks()
                            let calculatedWeeklyRate = phaseDurationWeeks > 0 ? weightDifference / phaseDurationWeeks : 0
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Required Weekly Rate:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(calculatedWeeklyRate >= 0 ? "+" : "")\(String(format: "%.2f", calculatedWeeklyRate)) kg/week")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(calculatedWeeklyRate < 0 ? .red : calculatedWeeklyRate > 0 ? .green : .blue)
                                }
                                
                                HStack {
                                    Text("Total Change:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(weightDifference >= 0 ? "+" : "")\(String(format: "%.1f", weightDifference)) kg")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(weightDifference < 0 ? .red : weightDifference > 0 ? .green : .blue)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(PhaseColor.allCases, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                            }) {
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Notes (Optional)") {
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                }
                
                // Delete Phase Section
                Section {
                    Button("Delete Phase") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Edit Phase")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadPhaseData()
                loadCurrentWeight()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePhase()
                    }
                    .disabled(!isValidPhase)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Delete Phase", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deletePhase()
                }
            } message: {
                Text("Are you sure you want to delete \"\(phase.name)\"? This action cannot be undone.")
            }
        }
    }
    
    private var isValidPhase: Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               startDate < endDate
    }
    
    private func calculatePhaseDurationInWeeks() -> Double {
        let totalDays = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return Double(totalDays) / 7.0
    }
    
    private func loadPhaseData() {
        // Get the latest phase data from the manager
        guard let currentPhase = phaseManager.phases.first(where: { $0.id == phase.id }) else {
            // Fallback to original phase if not found in manager
            loadFromOriginalPhase()
            return
        }
        
        name = currentPhase.name
        startDate = currentPhase.startDate
        endDate = currentPhase.endDate
        targetWeeklyRate = currentPhase.targetWeeklyRate
        selectedColor = currentPhase.color
        notes = currentPhase.notes ?? ""
        
        // Load the stored goal weight if available
        if let storedGoalWeight = currentPhase.goalWeight {
            goalWeight = String(format: "%.1f", storedGoalWeight)
        } else {
            goalWeight = ""
        }
    }
    
    private func loadFromOriginalPhase() {
        name = phase.name
        startDate = phase.startDate
        endDate = phase.endDate
        targetWeeklyRate = phase.targetWeeklyRate
        selectedColor = phase.color
        notes = phase.notes ?? ""
        
        if let storedGoalWeight = phase.goalWeight {
            goalWeight = String(format: "%.1f", storedGoalWeight)
        } else {
            goalWeight = ""
        }
    }
    
    private func loadCurrentWeight() {
        let weightManager = WeightLogManager.shared
        if let latestEntry = weightManager.weightEntries.first {
            currentWeight = latestEntry.weight
        }
    }
    
    private func savePhase() {
        // Check for date conflicts (excluding current phase)
        if phaseManager.hasConflict(startDate: startDate, endDate: endDate, excluding: phase.id) {
            errorMessage = "This date range conflicts with an existing phase. Please choose different dates."
            showingError = true
            return
        }
        
        // Calculate weekly rate from goal weight if provided
        let finalWeeklyRate: Double
        if let goalWeightValue = Double(goalWeight), goalWeightValue > 0 {
            let weightDifference = goalWeightValue - currentWeight
            let phaseDurationWeeks = calculatePhaseDurationInWeeks()
            finalWeeklyRate = phaseDurationWeeks > 0 ? weightDifference / phaseDurationWeeks : 0
        } else {
            finalWeeklyRate = targetWeeklyRate
        }
        
        let updatedPhase = WeightPhase(
            id: phase.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: generateDefaultDescription(weeklyRate: finalWeeklyRate),
            startDate: startDate,
            endDate: endDate,
            targetWeeklyRate: finalWeeklyRate,
            color: selectedColor,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            goalWeight: goalWeight.isEmpty ? nil : Double(goalWeight)
        )
        
        phaseManager.updatePhase(updatedPhase)
        dismiss()
    }
    
    private func deletePhase() {
        phaseManager.deletePhase(phase)
        dismiss()
    }
    
    private func generateDefaultDescription(weeklyRate: Double) -> String {
        if weeklyRate < 0 {
            return "Focus on fat loss while maintaining muscle mass"
        } else if weeklyRate > 0 {
            return "Build muscle mass with controlled weight gain"
        } else {
            return "Maintain current weight and body composition"
        }
    }
}

#Preview {
    EditPhaseView(phase: WeightPhase(
        name: "Sample Phase",
        description: "Sample description",
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date(),
        targetWeeklyRate: -0.5,
        color: .red
    ))
}
