import SwiftUI

// MARK: - Color Tokens

extension Color {
    enum App {
        static let bgPrimary = Color(hex: "0A1118")
        static let bgSecondary = Color(hex: "121D28")
        static let bgTertiary = Color(hex: "1A2836")

        static let accentPrimary = Color(hex: "00E676")
        static let accentSecondary = Color(hex: "00BFA5")
        static let accentGlow = Color(hex: "00E676").opacity(0.3)

        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "8899AA")

        static let danger = Color(hex: "FF5252")

        static let categoryBlue = Color(hex: "2196F3")
        static let categoryGreen = Color(hex: "4CAF50")
        static let categoryOrange = Color(hex: "FF9800")
        static let categoryPurple = Color(hex: "9C27B0")
        static let categoryPink = Color(hex: "EC407A")
    }
}

// MARK: - Gradient Tokens

extension LinearGradient {
    static let appAccent = LinearGradient(
        colors: [Color.App.accentPrimary, Color.App.accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let appBackground = LinearGradient(
        colors: [Color.App.bgPrimary, Color.App.bgSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Typography

extension Font {
    enum App {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 16, weight: .semibold, design: .default)
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        static let caption = Font.system(size: 14, weight: .regular, design: .default)
        static let smallCaption = Font.system(size: 12, weight: .regular, design: .default)

        static let amountLarge = Font.system(size: 34, weight: .bold, design: .rounded)
        static let amountMedium = Font.system(size: 20, weight: .bold, design: .rounded)
        static let amountSmall = Font.system(size: 16, weight: .semibold, design: .rounded)
    }
}

// MARK: - Spacing

enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

enum AppRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}

// MARK: - Hex Color Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    init(categoryHex: String) {
        self.init(hex: categoryHex.replacingOccurrences(of: "#", with: ""))
    }
}
