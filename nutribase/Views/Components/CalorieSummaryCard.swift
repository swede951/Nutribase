import SwiftUI

struct CalorieSummaryCard: View {
    var consumedCalories: Int
    var targetCalories: Int
    
    private var remainingCalories: Int {
        max(0, targetCalories - consumedCalories)
    }
    
    private var progress: Double {
        if targetCalories == 0 { return 0 }
        return Double(consumedCalories) / Double(targetCalories)
    }
    
    private var progressColor: Color {
        if progress > 1.0 {
            return .red
        } else if progress > 0.9 {
            return .orange
        } else {
            return .blue
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calories Remaining")
                        .font(.custom("Montserrat-SemiBold", size: 17))
                        .foregroundColor(.primary)
                    
                    Text("\(remainingCalories)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                CircularProgressBar(
                    progress: progress,
                    total: targetCalories,
                    current: consumedCalories,
                    color: progressColor,
                    lineWidth: 8
                )
                .frame(width: 100, height: 100)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .cardStyle()
    }
}

#Preview {
    VStack {
        CalorieSummaryCard(consumedCalories: 1450, targetCalories: 2100)
        CalorieSummaryCard(consumedCalories: 2000, targetCalories: 2100)
        CalorieSummaryCard(consumedCalories: 2200, targetCalories: 2100)
    }
    .background(Color(.systemGray6))
}
