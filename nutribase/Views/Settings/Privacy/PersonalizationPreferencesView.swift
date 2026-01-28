import SwiftUI

struct PersonalizationPreferencesView: View {
    @State private var personalizedRecommendations = UserDefaults.standard.bool(forKey: "personalizedRecommendations")
    @State private var mealSuggestions = UserDefaults.standard.bool(forKey: "mealSuggestions")
    @State private var nutritionInsights = UserDefaults.standard.bool(forKey: "nutritionInsights")
    
    var body: some View {
        Form {
            Section(header: Text("Personalization"), footer: Text("These features use your food log and health data to provide personalized recommendations.")) {
                Toggle("Personalized Recommendations", isOn: $personalizedRecommendations)
                    .onChange(of: personalizedRecommendations) {
                        UserDefaults.standard.set(personalizedRecommendations, forKey: "personalizedRecommendations")
                    }
                
                Toggle("Meal Suggestions", isOn: $mealSuggestions)
                    .onChange(of: mealSuggestions) {
                        UserDefaults.standard.set(mealSuggestions, forKey: "mealSuggestions")
                    }
                
                Toggle("Nutrition Insights", isOn: $nutritionInsights)
                    .onChange(of: nutritionInsights) {
                        UserDefaults.standard.set(nutritionInsights, forKey: "nutritionInsights")
                    }
            }
            
            Section(header: Text("Data Usage")) {
                HStack {
                    Text("Data Used")
                    Spacer()
                    Text("Local Only")
                        .foregroundColor(.secondary)
                }
                
                Text("All personalization happens on your device. Your data is never sent to third parties for marketing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Personalization")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemGray6), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        PersonalizationPreferencesView()
    }
}
