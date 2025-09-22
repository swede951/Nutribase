//
//  BMICardView.swift
//  nutribase
//
//  Created on 03/06/2025.
//

import SwiftUI

struct BMICardView: View {
    // Sample data - in a real app, this would be calculated from user data
    let bmiValue: Double = 22.5
    
    var bmiCategory: String {
        switch bmiValue {
        case ..<18.5:
            return "Underweight"
        case 18.5..<25:
            return "Normal"
        case 25..<30:
            return "Overweight"
        default:
            return "Obese"
        }
    }
    
    var bmiColor: Color {
        switch bmiValue {
        case ..<18.5:
            return .blue
        case 18.5..<25:
            return .green
        case 25..<30:
            return .orange
        default:
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with standardized top spacing
            HStack {
                Text("BMI")
                    .font(.custom("Montserrat-SemiBold", size: 17))
                Spacer()
            }
            .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: "%.1f", bmiValue))
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(bmiCategory)
                    .font(.subheadline)
                    .foregroundColor(bmiColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(bmiColor.opacity(0.2))
                    )
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .frame(height: 120)
    }
}

#Preview {
    BMICardView()
        .frame(width: 180, height: 120)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
}
