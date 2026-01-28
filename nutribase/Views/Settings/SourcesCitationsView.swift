import SwiftUI

struct SourcesCitationsView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    private var viewBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    var body: some View {
        ZStack {
            viewBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Disclaimer Card
                    disclaimerCard
                    
                    // Calorie Calculations
                    citationCard(
                        title: "Calorie & BMR Calculations",
                        icon: "flame.fill",
                        iconColor: .orange,
                        description: "Daily calorie needs are calculated using the Mifflin-St Jeor equation, which is considered the most accurate formula for estimating Basal Metabolic Rate (BMR).",
                        citations: [
                            Citation(
                                title: "Mifflin MD, St Jeor ST, et al.",
                                detail: "A new predictive equation for resting energy expenditure in healthy individuals.",
                                journal: "American Journal of Clinical Nutrition, 1990;51(2):241-7",
                                url: "https://pubmed.ncbi.nlm.nih.gov/2305711/"
                            ),
                            Citation(
                                title: "Activity Multipliers",
                                detail: "Total Daily Energy Expenditure (TDEE) is calculated by multiplying BMR by activity level factors based on the Harris-Benedict principle.",
                                journal: "Journal of the American Dietetic Association, 2005",
                                url: "https://pubmed.ncbi.nlm.nih.gov/15883556/"
                            )
                        ]
                    )
                    
                    // NOVA Classification
                    citationCard(
                        title: "NOVA Food Classification",
                        icon: "leaf.fill",
                        iconColor: .green,
                        description: "The NOVA classification system groups foods according to the extent and purpose of food processing, rather than in terms of nutrients.",
                        citations: [
                            Citation(
                                title: "Monteiro CA, Cannon G, et al.",
                                detail: "NOVA. The star shines bright. (Food classification. Public health.)",
                                journal: "World Nutrition, 2016;7(1-3):28-38",
                                url: "https://archive.wphna.org/wp-content/uploads/2016/01/WN-2016-7-1-3-28-38-Monteiro-Cannon-Levy-et-al-NOVA.pdf"
                            ),
                            Citation(
                                title: "Monteiro CA, Cannon G, et al.",
                                detail: "Ultra-processed foods: what they are and how to identify them.",
                                journal: "Public Health Nutrition, 2019;22(5):936-941",
                                url: "https://pubmed.ncbi.nlm.nih.gov/30744710/"
                            )
                        ]
                    )
                    
                    // Nutri-Score
                    citationCard(
                        title: "Nutri-Score Rating",
                        icon: "chart.bar.fill",
                        iconColor: .blue,
                        description: "Nutri-Score is a front-of-pack nutrition label that rates the overall nutritional quality of food products from A (healthiest) to E.",
                        citations: [
                            Citation(
                                title: "Santé Publique France",
                                detail: "Official Nutri-Score algorithm and scientific documentation.",
                                journal: "French Public Health Agency",
                                url: "https://www.santepubliquefrance.fr/en/nutri-score"
                            ),
                            Citation(
                                title: "Julia C, Hercberg S.",
                                detail: "Development of a new front-of-pack nutrition label in France: the five-colour Nutri-Score.",
                                journal: "Public Health Panorama, 2017;3(4):712-725",
                                url: "https://apps.who.int/iris/handle/10665/325207"
                            )
                        ]
                    )
                    
                    // Food Database Sources
                    citationCard(
                        title: "Food Database Sources",
                        icon: "server.rack",
                        iconColor: .purple,
                        description: "Nutritional information is sourced from established food composition databases.",
                        citations: [
                            Citation(
                                title: "USDA FoodData Central",
                                detail: "U.S. Department of Agriculture's food composition database providing detailed nutrient information.",
                                journal: "U.S. Department of Agriculture",
                                url: "https://fdc.nal.usda.gov/"
                            ),
                            Citation(
                                title: "Open Food Facts",
                                detail: "Collaborative, free, and open database of food products from around the world.",
                                journal: "Open Food Facts Foundation",
                                url: "https://world.openfoodfacts.org/"
                            )
                        ]
                    )
                    
                    // Macronutrient Recommendations
                    citationCard(
                        title: "Macronutrient Recommendations",
                        icon: "chart.pie.fill",
                        iconColor: .teal,
                        description: "Default macronutrient distribution ranges are based on Dietary Reference Intakes (DRIs).",
                        citations: [
                            Citation(
                                title: "Institute of Medicine",
                                detail: "Dietary Reference Intakes for Energy, Carbohydrate, Fiber, Fat, Fatty Acids, Cholesterol, Protein, and Amino Acids.",
                                journal: "National Academies Press, 2005",
                                url: "https://nap.nationalacademies.org/catalog/10490/dietary-reference-intakes-for-energy-carbohydrate-fiber-fat-fatty-acids-cholesterol-protein-and-amino-acids"
                            )
                        ]
                    )
                    
                    // Weight Management
                    citationCard(
                        title: "Weight Management",
                        icon: "scalemass.fill",
                        iconColor: Color(hex: "#35b8ff"),
                        description: "Weight trend calculations use exponentially weighted moving averages to smooth daily fluctuations.",
                        citations: [
                            Citation(
                                title: "Hall KD, et al.",
                                detail: "Quantification of the effect of energy imbalance on bodyweight.",
                                journal: "The Lancet, 2011;378(9793):826-837",
                                url: "https://pubmed.ncbi.nlm.nih.gov/21872751/"
                            ),
                            Citation(
                                title: "General Principle",
                                detail: "A caloric deficit of approximately 3,500 calories is associated with a loss of one pound of body weight.",
                                journal: "Based on metabolic research literature",
                                url: nil
                            )
                        ]
                    )
                    
                    Spacer(minLength: 20)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("Sources & Citations")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Disclaimer Card
    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                Text("Important Disclaimer")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Text("NutriBase is designed for informational and educational purposes only. It is not intended to provide medical advice, diagnosis, or treatment.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Always consult with a qualified healthcare professional before making changes to your diet, exercise routine, or health regimen. The calculations and recommendations provided are estimates based on general formulas and may not account for individual health conditions, medications, or other factors.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("If you have specific health concerns or conditions such as diabetes, eating disorders, heart disease, or other medical conditions, please seek guidance from a licensed healthcare provider.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Citation Card
    private func citationCard(title: String, icon: String, iconColor: Color, description: String, citations: [Citation]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title2)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            // Description
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
            
            // Citations
            ForEach(citations) { citation in
                citationRow(citation)
            }
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Citation Row
    private func citationRow(_ citation: Citation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(citation.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(citation.detail)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(citation.journal)
                .font(.caption)
                .italic()
                .foregroundColor(.secondary)
            
            if let url = citation.url, let linkURL = URL(string: url) {
                Link(destination: linkURL) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption2)
                        Text("View Source")
                            .font(.caption)
                    }
                    .foregroundColor(Color(hex: "#35b8ff"))
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Citation Model
struct Citation: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let journal: String
    let url: String?
}

#Preview {
    NavigationStack {
        SourcesCitationsView()
    }
}
