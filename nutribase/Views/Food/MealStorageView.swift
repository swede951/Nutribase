//
//  MealStorageView.swift
//  nutribase
//
//  Created on 11/07/2025.
//

import SwiftUI

struct MealStorageView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var visibleMeals: [MealType]
    @Binding var hiddenMeals: [MealType]
    var onDismiss: () -> Void
    
    // All possible meal types for the food log
    private let allMealTypes: [MealType] = [
        .caloriesSummary,
        .dailyGoals,
        .breakfast,
        .lunch,
        .dinner,
        .snacks
    ]
    
    // Grid layout configuration
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    // All cards section
                    Section {
                        Text("All Cards")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(allMealTypes, id: \.self) { mealType in
                                if hiddenMeals.contains(mealType) || !visibleMeals.contains(mealType) {
                                    mealPreviewCard(for: mealType)
                                        .onTapGesture {
                                            showMeal(mealType)
                                        }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Visible cards section
                    if !visibleMeals.isEmpty {
                        Section {
                            Text("Visible Cards")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(visibleMeals.indices, id: \.self) { index in
                                    let mealType = visibleMeals[index]
                                    mealPreviewCard(for: mealType)
                                        .overlay(
                                            // Only show remove button if there's more than one visible card
                                            visibleMeals.count > 1 ? 
                                            Button(action: {
                                                hideMeal(mealType)
                                            }) {
                                                Image(systemName: "minus.circle.fill")
                                                    .font(.title2)
                                                    .foregroundColor(.red)
                                                    .background(Circle().fill(Color.white))
                                                    .padding(6)
                                            }
                                            .position(x: 20, y: 20)
                                            : nil
                                        )
                                        .onDrag {
                                            // Only enable drag when there's more than one card
                                            guard visibleMeals.count > 1 else { return NSItemProvider() }
                                            MealDropDelegate.draggedIndex = index
                                            return NSItemProvider(object: mealType.rawValue as NSString)
                                        }
                                        .onDrop(of: [.text], delegate: MealDropDelegate(item: mealType, items: $visibleMeals, current: index))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("Customize Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        resetToDefault()
                    }
                }
            }
        }
    }
    
    private func showMeal(_ mealType: MealType) {
        // Debug print to help diagnose the issue
        print("Showing meal: \(mealType.rawValue)")
        print("Before - Visible meals: \(visibleMeals.map { $0.rawValue })")
        print("Before - Hidden meals: \(hiddenMeals.map { $0.rawValue })")
        
        // Add to visible meals if not already there
        if !visibleMeals.contains(mealType) {
            visibleMeals.append(mealType)
        }
        
        // Remove from hidden meals
        if let index = hiddenMeals.firstIndex(of: mealType) {
            hiddenMeals.remove(at: index)
        }
        
        print("After - Visible meals: \(visibleMeals.map { $0.rawValue })")
        print("After - Hidden meals: \(hiddenMeals.map { $0.rawValue })")
    }
    
    private func hideMeal(_ mealType: MealType) {
        // Debug print to help diagnose the issue
        print("Hiding meal: \(mealType.rawValue)")
        print("Before - Visible meals: \(visibleMeals.map { $0.rawValue })")
        print("Before - Hidden meals: \(hiddenMeals.map { $0.rawValue })")
        
        // Only allow hiding if there's more than one visible meal
        if visibleMeals.count > 1 {
            // Add to hidden meals if not already there
            if !hiddenMeals.contains(mealType) {
                hiddenMeals.append(mealType)
            }
            
            // Remove from visible meals
            if let index = visibleMeals.firstIndex(of: mealType) {
                visibleMeals.remove(at: index)
            }
            
            print("After - Visible meals: \(visibleMeals.map { $0.rawValue })")
            print("After - Hidden meals: \(hiddenMeals.map { $0.rawValue })")
        } else {
            print("Cannot hide - need at least one visible card")
        }
    }
    
    private func resetToDefault() {
        // Reset to default (all meals visible in default order)
        visibleMeals = [
            .caloriesSummary,
            .dailyGoals,
            .breakfast,
            .lunch,
            .dinner,
            .snacks
        ]
        hiddenMeals = []
    }
    
    @ViewBuilder
    private func mealPreviewCard(for mealType: MealType) -> some View {
        VStack {
            Image(systemName: mealType.systemImage)
                .font(.largeTitle)
                .foregroundColor(mealType.color)
                .frame(width: 60, height: 60)
                .padding()
            
            Text(mealType.rawValue)
                .font(.caption)
                .multilineTextAlignment(.center)
            
            // Only show Add button for cards in the All Cards section
            if hiddenMeals.contains(mealType) || !visibleMeals.contains(mealType) {
                Button(action: {
                    showMeal(mealType)
                }) {
                    Text("Add")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.0, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}

#Preview {
    MealStorageView(
        visibleMeals: .constant(MealType.allCases),
        hiddenMeals: .constant([]),
        onDismiss: {}
    )
}
