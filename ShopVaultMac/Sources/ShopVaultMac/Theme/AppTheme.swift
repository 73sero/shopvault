import SwiftUI

enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum AppRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 18
}

extension Color {
    enum App {
        // Background tiers
        static let bgPrimary = Color(red: 0.05, green: 0.07, blue: 0.10)
        static let bgSecondary = Color(red: 0.08, green: 0.10, blue: 0.14)
        static let bgTertiary = Color(red: 0.11, green: 0.13, blue: 0.18)

        // Text
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.62)
        static let textTertiary = Color.white.opacity(0.4)

        // Brand accents
        static let accentPrimary = Color(red: 0.0, green: 0.90, blue: 0.46)   // #00E676 mint
        static let accentSecondary = Color(red: 0.36, green: 0.78, blue: 1.0) // sky blue

        // Functional
        static let danger = Color(red: 1.0, green: 0.30, blue: 0.45)
        static let warning = Color(red: 1.0, green: 0.65, blue: 0.20)
        static let success = Color(red: 0.0, green: 0.90, blue: 0.46)

        // Categorical
        static let categoryGreen = Color(red: 0.30, green: 0.85, blue: 0.46)
        static let categoryBlue = Color(red: 0.36, green: 0.78, blue: 1.0)
        static let categoryOrange = Color(red: 1.0, green: 0.65, blue: 0.20)
        static let categoryPurple = Color(red: 0.65, green: 0.45, blue: 1.0)
        static let categoryPink = Color(red: 1.0, green: 0.45, blue: 0.75)
    }
}

extension Font {
    enum App {
        static let largeTitle = Font.system(size: 32, weight: .bold, design: .rounded)
        static let title = Font.system(size: 24, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 15, weight: .semibold, design: .default)
        static let body = Font.system(size: 14, weight: .regular, design: .default)
        static let caption = Font.system(size: 13, weight: .regular, design: .default)
        static let smallCaption = Font.system(size: 11, weight: .regular, design: .default)
        static let amountLarge = Font.system(size: 34, weight: .bold, design: .rounded)
        static let amountMedium = Font.system(size: 22, weight: .bold, design: .rounded)
        static let amountSmall = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let monoCaption = Font.system(size: 11, weight: .medium, design: .monospaced)
    }
}

extension LinearGradient {
    static let appAccent = LinearGradient(
        colors: [Color.App.accentPrimary, Color.App.accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let appBackground = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.06, blue: 0.10),
            Color(red: 0.07, green: 0.04, blue: 0.13)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct GlassCardModifier: ViewModifier {
    var padding: CGFloat = AppSpacing.md
    var radius: CGFloat = AppRadius.medium

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    Color.App.bgSecondary
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.04),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(padding: CGFloat = AppSpacing.md, radius: CGFloat = AppRadius.medium) -> some View {
        modifier(GlassCardModifier(padding: padding, radius: radius))
    }
}

struct AnimatedMeshBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                LinearGradient.appBackground

                Circle()
                    .fill(Color.App.accentPrimary.opacity(0.13))
                    .frame(width: 600, height: 600)
                    .blur(radius: 90)
                    .offset(x: CGFloat(cos(t * 0.18) * 280), y: CGFloat(sin(t * 0.22) * 220))

                Circle()
                    .fill(Color.App.accentSecondary.opacity(0.10))
                    .frame(width: 500, height: 500)
                    .blur(radius: 100)
                    .offset(x: CGFloat(sin(t * 0.16) * 320), y: CGFloat(cos(t * 0.14) * -180))

                Circle()
                    .fill(Color.App.categoryPurple.opacity(0.08))
                    .frame(width: 400, height: 400)
                    .blur(radius: 110)
                    .offset(x: CGFloat(cos(t * 0.20) * -240), y: CGFloat(sin(t * 0.20) * 260))
            }
            .ignoresSafeArea()
        }
    }
}
