import SwiftUI

struct GradientButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isDisabled: Bool = false
    var isLoading: Bool = false
    var style: GradientButtonStyle = .primary

    enum GradientButtonStyle {
        case primary
        case secondary
        case danger
    }

    var body: some View {
        Button(action: {
            HapticManager.impact(.medium)
            action()
        }) {
            HStack(spacing: AppSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.8)
                }

                if let icon = icon, !isLoading {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(title)
                    .font(Font.App.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(backgroundView)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            LinearGradient.appAccent
        case .secondary:
            Color.App.bgTertiary
        case .danger:
            Color.App.danger
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary: Color.white.opacity(0.1)
        case .secondary: Color.white.opacity(0.08)
        case .danger: Color.white.opacity(0.1)
        }
    }
}
