//
//  AddPhaseView.swift
//  nutribase
//
//  Created on 14/08/2025.
//

import SwiftUI

struct AddPhaseView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var phaseManager = WeightPhaseManager.shared
    @StateObject private var weightManager = WeightLogManager.shared
    
    @State private var name: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date()
    @State private var targetWeeklyRate: Double = -0.5
    @State private var goalWeight: String = ""
    @State private var useGoalWeight: Bool = true
    @State private var selectedColor: PhaseColor = .red
    @State private var notes: String = ""
    
    @State private var showingError = false
    @State private var errorMessage = ""
    

    
    var body: some View {
        NavigationView {
            Form {
                Section("Phase Details") {
                    TextField("Phase Name", text: $name)
                        .textInputAutocapitalization(.words)
                }
                
                Section("Date Range") {
                    VStack(alignment: .leading, spacing: 8) {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        
                        // Weight data indicator for start date
                        if hasWeightData(for: startDate) {
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(.blue)
                                Text("Weight data available for this date")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack {
                                Image(systemName: "circle")
                                    .font(.system(size: 6))
                                    .foregroundColor(.gray)
                                Text("No weight data for this date")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        
                        // Weight data indicator for end date
                        if hasWeightData(for: endDate) {
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(.blue)
                                Text("Weight data available for this date")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack {
                                Image(systemName: "circle")
                                    .font(.system(size: 6))
                                    .foregroundColor(.gray)
                                Text("No weight data for this date")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if startDate >= endDate {
                        Text("End date must be after start date")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section("Target") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let startWeight = getWeightForDate(startDate) {
                            HStack {
                                Text("Start Weight:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(String(format: "%.1f", startWeight)) kg")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        } else {
                            HStack {
                                Text("Start Weight:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("No data for start date")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
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
                        
                        if let goalWeightValue = Double(goalWeight), 
                           goalWeightValue > 0,
                           let startWeight = getWeightForDate(startDate) {
                            let weightDifference = goalWeightValue - startWeight
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
            }
            .navigationTitle("Add Phase")
            .navigationBarTitleDisplayMode(.inline)
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
    
    
    private func hasWeightData(for date: Date) -> Bool {
        let calendar = Calendar.current
        return weightManager.allEntries.contains { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }
    }
    
    private func getWeightForDate(_ date: Date) -> Double? {
        let calendar = Calendar.current
        return weightManager.allEntries.first { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }?.weight
    }
    

    
    private func savePhase() {
        // Check for date conflicts
        if phaseManager.hasConflict(startDate: startDate, endDate: endDate) {
            errorMessage = "This date range conflicts with an existing phase. Please choose different dates."
            showingError = true
            return
        }
        
        // Calculate weekly rate from goal weight if provided
        let finalWeeklyRate: Double
        if let goalWeightValue = Double(goalWeight), 
           goalWeightValue > 0,
           let startWeight = getWeightForDate(startDate) {
            let weightDifference = goalWeightValue - startWeight
            let phaseDurationWeeks = calculatePhaseDurationInWeeks()
            finalWeeklyRate = phaseDurationWeeks > 0 ? weightDifference / phaseDurationWeeks : 0
        } else {
            finalWeeklyRate = targetWeeklyRate
        }
        
        let updatedPhase = WeightPhase(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: generateDefaultDescription(weeklyRate: finalWeeklyRate),
            startDate: startDate,
            endDate: endDate,
            targetWeeklyRate: finalWeeklyRate,
            color: selectedColor,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            goalWeight: goalWeight.isEmpty ? nil : Double(goalWeight)
        )
        
        phaseManager.addPhase(updatedPhase)
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
    AddPhaseView()
}
