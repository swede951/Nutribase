import SwiftUI

struct NutritionBalanceIcon: View {
    var size: CGFloat = 60
    
    var body: some View {
        ZStack {
            // Main scale structure
            VStack(spacing: 0) {
                // Fork at the top
                VStack(spacing: 2) {
                    // Fork prongs
                    HStack(spacing: 3) {
                        ForEach(0..<4) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.primary)
                                .frame(width: 2, height: 8)
                        }
                    }
                    
                    // Fork base
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary)
                        .frame(width: 16, height: 4)
                }
                .offset(y: -2)
                
                // Scale arm (horizontal bar)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary)
                    .frame(width: size * 0.8, height: 6)
                    .overlay(
                        // Center pivot
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 8, height: 8)
                    )
                
                // Scale handle (vertical bar)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary)
                    .frame(width: 4, height: size * 0.4)
                    .offset(y: -3)
            }
            
            // Left scale bowl
            VStack {
                // Chain lines
                VStack(spacing: 1) {
                    ForEach(0..<3) { _ in
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: 1, height: 3)
                    }
                }
                
                // Bowl
                Ellipse()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.orange]),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .overlay(
                        Ellipse()
                            .stroke(Color.primary, lineWidth: 2)
                    )
                    .frame(width: size * 0.25, height: size * 0.15)
            }
            .offset(x: -size * 0.3, y: size * 0.15)
            
            // Right scale bowl
            VStack {
                // Chain lines
                VStack(spacing: 1) {
                    ForEach(0..<3) { _ in
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: 1, height: 3)
                    }
                }
                
                // Bowl
                Ellipse()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green]),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .overlay(
                        Ellipse()
                            .stroke(Color.primary, lineWidth: 2)
                    )
                    .frame(width: size * 0.25, height: size * 0.15)
            }
            .offset(x: size * 0.3, y: size * 0.15)
        }
        .frame(width: size, height: size)
    }
}

struct NutritionBalanceIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            NutritionBalanceIcon(size: 60)
            NutritionBalanceIcon(size: 100)
            NutritionBalanceIcon(size: 40)
        }
        .padding()
    }
}
