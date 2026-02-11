import SwiftUI

struct MetricVisibilityPreferencesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var visibilityService = MetricVisibilityService.shared
    @State private var showResetConfirmation = false
    
    private var viewBackground: Color {
        Color.appBackground
    }
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    var body: some View {
        ZStack {
            viewBackground.ignoresSafeArea()
            
        ScrollView {
            VStack(spacing: 20) {
                // Introduction Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Personalize Your Experience")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Choose which metrics to display throughout the app")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                }
                .background(cardBackground)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 16)
                
                // Calories Section
                MetricToggleSection(
                            title: "Calories",
                            icon: "flame.fill",
                            iconColor: .orange,
                            description: "Total energy content of foods",
                            isOn: $visibilityService.showCalories
                )
                
                // Macronutrients Section
                VStack(alignment: .leading, spacing: 12) {
                            Text("Macronutrients")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                            
                            VStack(spacing: 0) {
                                MetricToggleRow(
                                    title: "Protein",
                                    icon: "p.circle.fill",
                                    iconColor: .green,
                                    description: "Essential for muscle growth and repair",
                                    isOn: $visibilityService.showProtein
                                )
                                
                                Divider().padding(.leading, 55)
                                
                                MetricToggleRow(
                                    title: "Carbohydrates",
                                    icon: "c.circle.fill",
                                    iconColor: .orange,
                                    description: "Primary energy source for your body",
                                    isOn: $visibilityService.showCarbs
                                )
                                
                                Divider().padding(.leading, 55)
                                
                                MetricToggleRow(
                                    title: "Fat",
                                    icon: "f.circle.fill",
                                    iconColor: .pink,
                                    description: "Essential for hormone production and nutrient absorption",
                                    isOn: $visibilityService.showFat
                                )
                            }
                            .background(cardBackground)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                }
                .padding(.horizontal, 16)
                
                // Food Processing Scores Section
                VStack(alignment: .leading, spacing: 12) {
                            Text("Food Processing Scores")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                            
                            VStack(spacing: 0) {
                                MetricToggleRow(
                                    title: "NOVA Score",
                                    icon: "chart.bar.fill",
                                    iconColor: .blue,
                                    description: "Food processing classification (1-4)",
                                    isOn: $visibilityService.showNovaScore
                                )
                                
                                Divider().padding(.leading, 55)
                                
                                MetricToggleRow(
                                    title: "Nutri-Score",
                                    icon: "chart.pie.fill",
                                    iconColor: .purple,
                                    description: "Nutritional quality rating (A-E)",
                                    isOn: $visibilityService.showNutriScore
                                )
                            }
                            .background(cardBackground)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                }
                .padding(.horizontal, 16)
                
                // Reset Button
                Button(action: {
                            showResetConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Reset to Defaults")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(cardBackground)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                }
                .padding(.horizontal, 16)
                
                // Info Card
                VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Why hide metrics?")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            
                            Text("We believe nutrition tracking should support your wellbeing. If focusing on certain numbers doesn't serve you, you can hide them while still tracking other aspects of your diet.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal, 16)
                
                Spacer(minLength: 20)
            }
            .padding(.top, 16)
        }
        }
        .navigationTitle("Metric Visibility")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(viewBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Reset to Defaults", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                visibilityService.resetToDefaults()
            }
        } message: {
            Text("This will show all metrics again. You can customize them anytime.")
        }
    }
}

// MARK: - Metric Toggle Section (Single Item)
struct MetricToggleSection: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let icon: String
    let iconColor: Color
    let description: String
    @Binding var isOn: Bool
    
    private var cardBackground: Color {
        Color.appCardBackground
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
            
            MetricToggleRow(
                title: title,
                icon: icon,
                iconColor: iconColor,
                description: description,
                isOn: $isOn
            )
            .background(cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Metric Toggle Row Component
struct MetricToggleRow: View {
    let title: String
    let icon: String
    let iconColor: Color
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    NavigationStack {
        MetricVisibilityPreferencesView()
    }
}
