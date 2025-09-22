import SwiftUI
import UIKit

struct FontChecker {
    static func printAvailableFonts() {
        for family in UIFont.familyNames.sorted() {
            let names = UIFont.fontNames(forFamilyName: family)
            print("Family: \(family) Font names: \(names)")
        }
    }
    
    static func checkMontserratFonts() {
        let montserratFonts = UIFont.familyNames.filter { $0.contains("Montserrat") }
        print("Available Montserrat fonts:")
        for family in montserratFonts {
            let names = UIFont.fontNames(forFamilyName: family)
            print("Family: \(family)")
            for name in names {
                print("  - \(name)")
            }
        }
    }
}

// Preview to test fonts
struct FontTestView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("NUTRIBASE - System Font")
                .font(.system(size: 20, weight: .black))
            
            Text("NUTRIBASE - Montserrat-Bold")
                .font(.custom("Montserrat-Bold", size: 20))
            
            Text("NUTRIBASE - Montserrat-ExtraBold")
                .font(.custom("Montserrat-ExtraBold", size: 20))
            
            Text("Weight - Montserrat-SemiBold")
                .font(.custom("Montserrat-SemiBold", size: 17))
            
            Text("Weight - System Headline")
                .font(.headline)
        }
        .padding()
        .onAppear {
            FontChecker.checkMontserratFonts()
        }
    }
}

#Preview {
    FontTestView()
}
