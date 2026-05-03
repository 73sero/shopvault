import SwiftUI

struct GlassCardModifier: ViewModifier {
    var padding: CGFloat = AppSpacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial)
            .background(Color.App.bgSecondary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
    }
}

struct GlowCardModifier: ViewModifier {
    var glowColor: Color = Color.App.accentPrimary
    var padding: CGFloat = AppSpacing.md

    func body(content: Content) -> some View {
        content
            .modifier(GlassCardModifier(padding: padding))
            .shadow(color: glowColor.opacity(0.15), radius: 24, x: 0, y: 4)
    }
}

extension View {
    func glassCard(padding: CGFloat = AppSpacing.md) -> some View {
        modifier(GlassCardModifier(padding: padding))
    }

    func glowCard(color: Color = Color.App.accentPrimary, padding: CGFloat = AppSpacing.md) -> some View {
        modifier(GlowCardModifier(glowColor: color, padding: padding))
    }

    func appBackground() -> some View {
        self.background(Color.App.bgPrimary.ignoresSafeArea())
    }
}
