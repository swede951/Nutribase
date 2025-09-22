import SwiftUI

struct QuickAddView: View {
    @Binding var isPresented: Bool
    @State private var offset: CGFloat = 1000
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    dismissView()
                }
            
            VStack(spacing: 20) {
                // Title
                Text("Quick Add")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Cards container
                HStack(spacing: 20) {
                    // Food Card
                    QuickAddCard(
                        title: "Food",
                        icon: "fork.knife",
                        color: .blue,
                        action: {
                            // Navigate to food entry
                            dismissView()
                        }
                    )
                    
                    // Weight Card
                    QuickAddCard(
                        title: "Weight",
                        icon: "scalemass",
                        color: .orange,
                        action: {
                            // Navigate to weight entry
                            dismissView()
                        }
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 10)
            )
            .offset(y: offset)
            .onAppear {
                withAnimation(.spring()) {
                    offset = 0
                }
            }
        }
    }
    
    private func dismissView() {
        withAnimation(.spring()) {
            offset = 1000
        }
        
        // Delay to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

struct QuickAddCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .frame(width: 130, height: 130)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white)
                    .shadow(color: color.opacity(0.2), radius: 5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    QuickAddView(isPresented: .constant(true))
}
