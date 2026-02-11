import SwiftUI

extension Color {
    // Custom color palette from https://coolors.co/palette/ccd5ae-e9edc9-fefae0-faedcd-d4a373
    static let lightSage = Color(hex: "CCD5AE")
    static let paleGreen = Color(hex: "E9EDC9")
    static let cream = Color(hex: "FEFAE0")
    static let lightPeach = Color(hex: "FAEDCD")
    static let tan = Color(hex: "D4A373")
    
    // Additional colors
    static let headerGray = Color(hex: "B7B7A4")
    
    // MARK: - App adaptive backgrounds (elevated dark mode)
    // Dark mode is shifted one tier up from pure black to dark gray for contrast.
    // Light mode values are unchanged from the original design.
    
    /// View / scroll background. Light: #F2F2F7  Dark: #1C1C1E
    /// Uses fixed hex in dark mode so sheets/elevated contexts don't shift the color.
    static let appBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)   // #1C1C1E
            : .systemGroupedBackground                                      // #F2F2F7
    })
    
    /// Card / section background. Light: white  Dark: #2C2C2E
    /// Uses fixed hex in dark mode so sheets/elevated contexts don't shift the color.
    static let appCardBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 44/255, green: 44/255, blue: 46/255, alpha: 1)   // #2C2C2E
            : .secondarySystemGroupedBackground                             // #FFFFFF
    })
    
    /// Inset elements inside cards (text fields, dropdowns). Light: #F2F2F7  Dark: #3A3A3C
    /// Uses fixed hex in dark mode so sheets/elevated contexts don't shift the color.
    static let appInsetBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 58/255, green: 58/255, blue: 60/255, alpha: 1)   // #3A3A3C
            : .tertiarySystemGroupedBackground                              // #F2F2F7
    })
    
    // Helper initializer to create colors from hex strings
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
