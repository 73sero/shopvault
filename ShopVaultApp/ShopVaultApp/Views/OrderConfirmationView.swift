import SwiftUI

struct OrderConfirmationView: View {
    @ObservedObject var viewModel: NewOrderViewModel
    let dismiss: DismissAction
    @State private var showCheckmark = false
    @State private var showContent = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer(minLength: AppSpacing.xl)

                // Checkmark circle with glow
                ZStack {
                    Circle()
                        .fill(Color.App.accentPrimary.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.App.accentPrimary.opacity(0.4), radius: 30)

                    Circle()
                        .fill(Color.App.accentPrimary.opacity(0.2))
                        .frame(width: 90, height: 90)

                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color.App.accentPrimary)
                        .scaleEffect(showCheckmark ? 1 : 0.3)
                        .opacity(showCheckmark ? 1 : 0)
                }
                .scaleEffect(showCheckmark ? 1 : 0.5)

                // Title
                VStack(spacing: AppSpacing.xs) {
                    Text("Bestellung erfasst")
                        .font(Font.App.title)
                        .foregroundStyle(Color.App.textPrimary)

                    if let name = viewModel.completedOrder?.customerName {
                        Text("für \(name)")
                            .font(Font.App.body)
                            .foregroundStyle(Color.App.textSecondary)
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)

                // Total card
                if let order = viewModel.completedOrder {
                    VStack(spacing: AppSpacing.sm) {
                        Text(formatCurrency(order.total))
                            .font(Font.App.amountLarge)
                            .foregroundStyle(Color.App.accentPrimary)

                        HStack(spacing: AppSpacing.md) {
                            Label("\(order.items.count) Artikel", systemImage: "shippingbox")
                                .font(Font.App.caption)
                                .foregroundStyle(Color.App.textSecondary)

                            if order.discountAmount > 0 {
                                Label("-\(formatCurrency(order.discountAmount))", systemImage: "tag")
                                    .font(Font.App.caption)
                                    .foregroundStyle(Color.App.danger)
                            }
                        }
                    }
                    .glowCard()
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 10)

                    // Auto-actions checklist
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        actionRow(
                            icon: "checkmark.circle.fill",
                            color: Color.App.accentPrimary,
                            text: "Bestand aktualisiert (-\(totalItemCount(order)))"
                        )
                        actionRow(
                            icon: "checkmark.circle.fill",
                            color: Color.App.accentPrimary,
                            text: "Einnahme verbucht (\(formatCurrency(order.total)))"
                        )
                    }
                    .glassCard()
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 10)

                    // Low stock warnings
                    if !viewModel.lowStockWarnings.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            ForEach(viewModel.lowStockWarnings) { product in
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(Color.App.categoryOrange)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(product.name)
                                            .font(Font.App.caption)
                                            .foregroundStyle(Color.App.textPrimary)
                                        Text("Niedriger Bestand: \(product.stock) verbleibend")
                                            .font(Font.App.smallCaption)
                                            .foregroundStyle(Color.App.categoryOrange)
                                    }

                                    Spacer()
                                }
                            }
                        }
                        .glassCard()
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                    }
                }

                Spacer(minLength: AppSpacing.md)

                // Buttons
                VStack(spacing: AppSpacing.sm) {
                    GradientButton(
                        title: "Neue Bestellung",
                        icon: "plus.circle.fill",
                        action: {
                            viewModel.reset()
                        }
                    )

                    Button {
                        dismiss()
                    } label: {
                        Text("Zurück zum Hub")
                            .font(Font.App.headline)
                            .foregroundStyle(Color.App.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)
            }
            .padding(AppSpacing.md)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showCheckmark = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                showContent = true
            }
        }
    }

    // MARK: - Subviews

    private func actionRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textPrimary)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func totalItemCount(_ order: Order) -> Int {
        order.items.reduce(0) { $0 + $1.quantity }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value) \u{20AC}"
    }
}

// MARK: - Preview

// Preview is available through NewOrderView with completedOrder set
