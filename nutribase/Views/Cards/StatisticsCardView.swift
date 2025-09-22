//
//  StatisticsCardView.swift
//  nutribase
//
//  Created on 03/06/2025.
//

import SwiftUI

struct StatisticsCardView: View {
    let statTitle: String
    let statValue: String
    let statChange: Double
    let systemImage: String?
    let color: Color
    var isLoading: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .foregroundColor(color)
                }
                Text(statTitle)
                    .font(.custom("Montserrat-SemiBold", size: 17))
                Spacer()
            }
            .padding(.bottom, 4)
            if isLoading {
                VStack(alignment: .center) {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(statValue)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    
                    if statChange != 0 {
                        HStack {
                            Image(systemName: statChange > 0 ? "arrow.up" : "arrow.down")
                                .foregroundColor(statChange > 0 ? .green : .red)
                            
                            Text("\(String(format: "%.1f", abs(statChange)))%")
                                .foregroundColor(statChange > 0 ? .green : .red)
                            
                            Text("from last week")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(height: 120)
    }
}

#Preview {
    Group {
        StatisticsCardView(
            statTitle: "Protein", 
            statValue: "120g", 
            statChange: 5.2, 
            systemImage: "chart.bar.fill", 
            color: .purple
        )
        
        StatisticsCardView(
            statTitle: "Activity", 
            statValue: "7,500 steps", 
            statChange: -2.3, 
            systemImage: "figure.walk", 
            color: .pink
        )
    }
    .frame(width: 180, height: 120)
    .padding()
}
