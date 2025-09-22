import Foundation

class NetworkTest {
    static func testBasicRequest() {
        print("🧪 Testing basic network request...")
        
        // Try the simplest possible request first
        guard let url = URL(string: "https://httpbin.org/post") else {
            print("❌ Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["test": "data"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Basic test failed: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Basic test success: \(httpResponse.statusCode)")
            }
            
            // Now try Supabase
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NetworkTest.testSupabaseRequest()
            }
        }
        
        task.resume()
    }
    
    static func testSupabaseRequest() {
        print("🧪 Testing Supabase request...")
        
        guard let url = URL(string: "https://owmwxzkzqrbhhiofzgmm.supabase.co/auth/v1/token") else {
            print("❌ Invalid Supabase URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93bXd4emt6cXJiaGhpb2Z6Z21tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDcyNDIxMDIsImV4cCI6MjA2MjgxODEwMn0.NkZ7ffPEG6BT_xNEsWsbDc0BoOQrpYUDDLJ0hwDX5-0", forHTTPHeaderField: "apikey")
        
        let body = [
            "email": "test@example.com",
            "password": "testpassword",
            "grant_type": "password"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Supabase test failed: \(error.localizedDescription)")
                print("❌ Error domain: \(error._domain)")
                print("❌ Error code: \(error._code)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Supabase test response: \(httpResponse.statusCode)")
                
                if let data = data {
                    let responseString = String(data: data, encoding: .utf8) ?? "No response"
                    print("📦 Supabase response: \(responseString)")
                }
            }
        }
        
        task.resume()
    }
}
