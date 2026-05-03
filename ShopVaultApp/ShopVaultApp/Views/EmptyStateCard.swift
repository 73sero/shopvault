import SwiftUI

/// Reusable empty-state with icon, title, subtitle and optional CTA.
/// Use across all list views (orders, customers, products, deliveries, income).
struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var actionIcon: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(LinearGradient.appAccent.opacity(0.10))
                    .frame(width: 96, height: 96)
                    .blur(radius: 14)
                Circle()
                    .stroke(LinearGradient.appAccent.opacity(0.5), lineWidth: 1)
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(LinearGradient.appAccent)
            }

            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            if let actionTitle, let action {
                Button(action: {
                    HapticManager.impact(.light)
                    action()
                }) {
                    HStack(spacing: AppSpacing.xs) {
                        if let actionIcon {
                            Image(systemName: actionIcon)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text(actionTitle)
                            .font(Font.App.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.App.bgPrimary)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(LinearGradient.appAccent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity)
        .glassCard(padding: AppSpacing.lg)
    }
}
