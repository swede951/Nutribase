//
//  MealStorageView.swift
//  nutribase
//
//  Created on 11/07/2025.
//

import SwiftUI

struct MealStorageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Binding var visibleMeals: [MealType]
    @Binding var hiddenMeals: [MealType]
    var onDismiss: () -> Void
    
    // Adaptive colors for dark mode support
    private var galleryBackground: Color {
        Color.appBackground
    }
    
    // Available cards (not visible) - simple filter like WidgetStorageView
    private var availableCards: [MealType] {
        MealType.allCases.filter { !visibleMeals.contains($0) }
    }
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    // All cards section
                    Text("All Cards")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    // Show cards in a vertical stack
                    VStack(spacing: 16) {
                        ForEach(availableCards, id: \.self) { mealType in
                            cardPreviewWithOverlay(for: mealType)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(galleryBackground.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("Add Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(galleryBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
    
    private func addCard(_ mealType: MealType) {
        // Add to visible meals
        visibleMeals.append(mealType)
        
        // Remove from hidden meals if present
        if let index = hiddenMeals.firstIndex(of: mealType) {
            hiddenMeals.remove(at: index)
        }
        
        // Dismiss
        dismiss()
    }
    
    // Card preview with green plus overlay
    @ViewBuilder
    private func cardPreviewWithOverlay(for mealType: MealType) -> some View {
        ZStack {
            // Actual card preview
            cardPreview(for: mealType)
                .allowsHitTesting(false)
            
            // Green plus button overlay - positioned outside card bounds
            VStack {
                HStack {
                    Button(action: {
                        addCard(mealType)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.green.opacity(0.9))
                            .background(Circle().fill(Color.appCardBackground))
                    }
                    Spacer()
                }
                Spacer()
            }
            .offset(x: -10, y: -10)
        }
    }
    
    // Returns static preview for each meal type - no actual components to avoid freezing
    @ViewBuilder
    private func cardPreview(for mealType: MealType) -> some View {
        switch mealType {
        case .caloriesSummary:
            CaloriesSummaryPreview()
            
        case .dailyGoals:
            DailyGoalsPreview()
            
        case .breakfast, .lunch, .dinner, .snacks:
            EmptyMealCardPreview(mealType: mealType)
        }
    }
}

// Static preview that looks like CalorieSummaryCard
struct CaloriesSummaryPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Calories Remaining")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Image(systemName: "gearshape")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Content - Goal - Consumed = Remaining with circle
            HStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 4) {
                    Text("2,000")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Goal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("-")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("377")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Consumed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("=")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Circular progress with remaining
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.19)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("1,623")
                            .font(.system(size: 14, weight: .bold))
                        Text("Remaining")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
}

// Static preview that looks like DailyGoalsCard
struct DailyGoalsPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Daily Goals")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Image(systemName: "gearshape")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Metrics row - centered like the real card
            HStack(spacing: 0) {
                // Protein
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                            .frame(width: 50, height: 50)
                        Circle()
                            .trim(from: 0, to: 0.1)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("12")
                                .font(.system(size: 14, weight: .bold))
                            Text("/120g")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                        }
                    }
                    Text("Protein")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // NOVA 4
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                            .frame(width: 50, height: 50)
                        Circle()
                            .trim(from: 0, to: 0)
                            .stroke(Color.purple, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("0%")
                                .font(.system(size: 14, weight: .bold))
                            Text("/20%")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                        }
                    }
                    Text("NOVA 4")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // Calories
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                            .frame(width: 50, height: 50)
                        Circle()
                            .trim(from: 0, to: 0.19)
                            .stroke(Color.purple, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("377")
                                .font(.system(size: 14, weight: .bold))
                            Text("/2000")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                        }
                    }
                    Text("Calories")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // Remaining
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                            .frame(width: 50, height: 50)
                        Circle()
                            .trim(from: 0, to: 0.81)
                            .stroke(Color.purple, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("1623")
                                .font(.system(size: 12, weight: .bold))
                            Text("remaining")
                                .font(.system(size: 7))
                                .foregroundColor(.gray)
                        }
                    }
                    Text("Calories")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
}

// Empty meal card preview that matches the actual MealCardView appearance
struct EmptyMealCardPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let mealType: MealType
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Meal header - matching MealCardView
            HStack {
                Text(mealType.rawValue)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.vertical, 16)
                    .padding(.horizontal)
                
                Spacer()
                
                Text("0 kcal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                // Chevron indicator
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.trailing)
            }
            
            // Add food buttons - matching MealCardView
            HStack(spacing: 16) {
                Image(systemName: "plus")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))
                
                Image(systemName: "barcode.viewfinder")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
}

#Preview {
    MealStorageView(
        visibleMeals: .constant([.breakfast, .lunch, .dinner, .snacks]),
        hiddenMeals: .constant([.caloriesSummary, .dailyGoals]),
        onDismiss: {}
    )
}
