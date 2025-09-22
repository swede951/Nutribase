import SwiftUI

struct CircularProgressBar: View {
    var progress: Double
    var total: Int
    var current: Int
    var color: Color = .blue
    var lineWidth: CGFloat = 10
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(lineWidth: lineWidth)
                .opacity(0.3)
                .foregroundColor(color)
            
            // Progress circle
            Circle()
                .trim(from: 0.0, to: CGFloat(min(self.progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .foregroundColor(color)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)
            
            // Center text
            VStack(spacing: 0) {
                HStack(spacing: 2) {
                    Text("\(current)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("/")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] - 2 }
                }
                
                Text("\(total)")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    CircularProgressBar(progress: 0.7, total: 2100, current: 1450)
        .frame(width: 120, height: 120)
}
