import SwiftUI
import HealthKit

struct HealthKitConnectionView: View {
    @ObservedObject private var healthKitManager = HealthKitManager.shared
    @State private var isConnecting = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.red)
                .padding()
            
            Text("Apple Health Integration")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Connect NutriBase to Apple Health to automatically import your steps data and other health metrics.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if healthKitManager.isAuthorized {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Connected to Apple Health")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
                .padding()
                
                Button(action: {
                    refreshHealthData()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Health Data")
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else {
                Button(action: {
                    connectToHealthKit()
                }) {
                    HStack {
                        Image(systemName: "link")
                        Text(isConnecting ? "Connecting..." : "Connect to Apple Health")
                    }
                    .padding()
                    .background(isConnecting ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isConnecting)
            }
            
            if healthKitManager.isAuthorized {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Today's Steps: \(healthKitManager.todaySteps)")
                        .font(.headline)
                    
                    Text("Weekly Steps")
                        .font(.headline)
                    
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(0..<7, id: \.self) { index in
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: 30, height: getBarHeight(for: healthKitManager.weeklySteps[index]))
                                
                                Text(getDayLabel(for: index))
                                    .font(.caption)
                                    .frame(width: 30)
                            }
                            .frame(height: 150)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                .padding()
            }
        }
        .padding()
        .onAppear {
            if healthKitManager.isAuthorized {
                refreshHealthData()
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationTitle("Health Connection")
    }
    
    private func connectToHealthKit() {
        isConnecting = true
        
        healthKitManager.requestAuthorization { success, error in
            isConnecting = false
            
            if success {
                alertTitle = "Success"
                alertMessage = "Successfully connected to Apple Health!"
                refreshHealthData()
            } else {
                alertTitle = "Connection Failed"
                alertMessage = error?.localizedDescription ?? "Unable to connect to Apple Health. Please try again."
            }
            
            showAlert = true
        }
    }
    
    private func refreshHealthData() {
        healthKitManager.fetchTodaySteps { _, _ in }
        healthKitManager.fetchWeeklySteps { _, _ in }
    }
    
    private func getBarHeight(for steps: Int) -> CGFloat {
        let maxHeight: CGFloat = 120
        let maxSteps = healthKitManager.weeklySteps.max() ?? 10000
        
        guard maxSteps > 0 else { return 5 }
        
        let height = CGFloat(steps) / CGFloat(maxSteps) * maxHeight
        return max(height, 5) // Minimum height of 5
    }
    
    private func getDayLabel(for index: Int) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        guard let date = calendar.date(byAdding: .day, value: index - 6, to: today) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

struct HealthKitConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HealthKitConnectionView()
        }
    }
}
