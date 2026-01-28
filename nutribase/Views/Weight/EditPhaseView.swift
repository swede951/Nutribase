//
//  EditPhaseView.swift
//  nutribase
//
//  Created on 25/08/2025.
//

import SwiftUI

struct EditPhaseView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var phaseManager = WeightPhaseManager.shared
    let phase: WeightPhase
    
    @State private var name: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var hasEndDate: Bool = true
    @State private var targetWeeklyRate: Double = -0.5
    @State private var goalWeight: String = ""
    @State private var currentWeight: Double = 0.0
    @State private var selectedColor: PhaseColor = .blue
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
                    
                    Toggle("Set End Date", isOn: $hasEndDate)
                        .onChange(of: hasEndDate) { oldValue, newValue in
                            if newValue {
                                // When enabling end date, set it to a reasonable default
                                endDate = Calendar.current.date(byAdding: .month, value: 2, to: startDate) ?? startDate
                            }
                        }
                    
                    if hasEndDate {
                        DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        
                        if startDate >= endDate {
                            Text("End date must be after start date")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    } else {
                        HStack {
                            Text("End Date")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Open-ended")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
                
                Section("Target") {
                    VStack(alignment: .leading, spacing: 12) {
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
                
                // Delete Phase Section
                Section {
                    Button("Delete Phase") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    }
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
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePhase()
                    }
                    .foregroundColor(.primary)
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
        let nameValid = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let dateValid = hasEndDate ? startDate < endDate : true
        return nameValid && dateValid
    }
    
    private func calculatePhaseDurationInWeeks() -> Double {
        let effectiveEndDate = hasEndDate ? endDate : getDefaultEndDate()
        let totalDays = Calendar.current.dateComponents([.day], from: startDate, to: effectiveEndDate).day ?? 0
        return Double(totalDays) / 7.0
    }
    
    private func getDefaultEndDate() -> Date {
        // For open-ended phases, use end of current month
        let calendar = Calendar.current
        let now = Date()
        
        // Get the end of the current month
        guard let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.startOfDay(for: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)) else {
            return now
        }
        
        return endOfMonth
    }
    
    private func getDisplayEndDate() -> Date {
        // For display purposes, show end of current month
        let calendar = Calendar.current
        let currentDate = Date()
        let startOfCurrentMonth = calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
        let endOfCurrentMonth = calendar.date(byAdding: .day, value: -1, to: calendar.date(byAdding: .month, value: 1, to: startOfCurrentMonth) ?? startOfCurrentMonth) ?? currentDate
        return endOfCurrentMonth
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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
        // Check if this phase has a meaningful end date or is open-ended
        hasEndDate = !isOpenEndedPhase(currentPhase)
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
        hasEndDate = !isOpenEndedPhase(phase)
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
        let effectiveEndDate = hasEndDate ? endDate : getDefaultEndDate()
        
        // Phases are allowed to overlap - no conflict check needed
        
        // Calculate weekly rate from goal weight if provided
        let finalWeeklyRate: Double
        if let goalWeightValue = Double(goalWeight), goalWeightValue > 0 {
            let weightDifference = goalWeightValue - currentWeight
            let phaseDurationWeeks = calculatePhaseDurationInWeeks()
            finalWeeklyRate = phaseDurationWeeks > 0 ? weightDifference / phaseDurationWeeks : 0
        } else {
            finalWeeklyRate = targetWeeklyRate
        }
        
        // Normalize dates to start of day to avoid time component issues
        let calendar = Calendar.current
        let normalizedStartDate = calendar.startOfDay(for: startDate)
        let normalizedEndDate = calendar.startOfDay(for: effectiveEndDate)
        
        let updatedPhase = WeightPhase(
            id: phase.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: generateDefaultDescription(weeklyRate: finalWeeklyRate),
            startDate: normalizedStartDate,
            endDate: normalizedEndDate,
            targetWeeklyRate: finalWeeklyRate,
            color: selectedColor,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            goalWeight: goalWeight.isEmpty ? nil : Double(goalWeight),
            isOpenEnded: !hasEndDate
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
    
    private func isOpenEndedPhase(_ phase: WeightPhase) -> Bool {
        // Check the isOpenEnded flag
        return phase.isOpenEnded
    }
}

#Preview {
    EditPhaseView(phase: WeightPhase(
        name: "Sample Phase",
        description: "Sample description",
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date(),
        targetWeeklyRate: -0.5,
        color: .blue
    ))
}
