import SwiftUI

struct HubView: View {
    @StateObject var viewModel: HubViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            AnimatedMeshGradientView()

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // MARK: - Greeting
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Welcome back")
                            .font(Font.App.title)
                            .foregroundStyle(Color.App.textPrimary)

                        Text(formattedDate)
                            .font(Font.App.caption)
                            .foregroundStyle(Color.App.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.md)
                    .staggeredAppear(index: 0)

                    // MARK: - Stat Cards
                    HStack(spacing: AppSpacing.sm) {
                        StatCard(
                            title: "Umsatz",
                            value: formatCurrency(viewModel.monthlyRevenue),
                            color: Color.App.accentPrimary
                        )

                        StatCard(
                            title: "Profit",
                            value: formatCurrency(viewModel.monthlyProfit),
                            subtitle: String(format: "%.0f%%", viewModel.marginPercent),
                            color: Color.App.accentSecondary
                        )

                        StatCard(
                            title: "Low Stock",
                            value: "\(viewModel.lowStockCount)",
                            color: Color.App.danger
                        )
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .staggeredAppear(index: 1)

                    // MARK: - Low Stock Alert (compact)
                    if !viewModel.lowStockProducts.isEmpty {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.App.danger)
                            Text("\(viewModel.lowStockProducts.count) Produkte nachbestellen")
                                .font(Font.App.caption)
                                .foregroundStyle(Color.App.danger)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.App.danger.opacity(0.5))
                        }
                        .padding(AppSpacing.sm)
                        .background(Color.App.danger.opacity(0.08))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.small)
                                .stroke(Color.App.danger.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, AppSpacing.md)
                        .staggeredAppear(index: 2)
                    }

                    // MARK: - Quick Actions
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Schnellzugriff")
                            .font(Font.App.headline)
                            .foregroundStyle(Color.App.textSecondary)
                            .padding(.horizontal, AppSpacing.md)

                        HStack(spacing: AppSpacing.xs) {
                            QuickActionTile(
                                icon: "plus.circle.fill",
                                label: "Bestellung",
                                color: Color.App.accentPrimary,
                                value: "newOrder"
                            )
                            QuickActionTile(
                                icon: "person.crop.circle.badge.plus",
                                label: "Kunde",
                                color: Color.App.categoryBlue,
                                value: "newCustomer"
                            )
                            QuickActionTile(
                                icon: "shippingbox.fill",
                                label: "Lieferung",
                                color: Color.App.categoryPurple,
                                value: "newDelivery"
                            )
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }
                    .staggeredAppear(index: 3)

                    // MARK: - Sections
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Bereiche")
                            .font(Font.App.headline)
                            .foregroundStyle(Color.App.textSecondary)
                            .padding(.horizontal, AppSpacing.md)

                        NavigationLink(value: "shop") {
                            SectionCard(
                                icon: "cube.box.fill",
                                title: "Shop",
                                description: "Bestellungen, Kunden, Inventar & Lieferungen",
                                accentColor: Color.App.accentPrimary,
                                badge: viewModel.recentOrders.count > 0 ? "\(viewModel.recentOrders.count)" : nil
                            )
                        }
                        .padding(.horizontal, AppSpacing.md)

                        NavigationLink(value: "finance") {
                            SectionCard(
                                icon: "dollarsign.circle.fill",
                                title: "Finanzen",
                                description: "Einnahmen, Kategorien & Auswertungen",
                                accentColor: Color.App.categoryBlue,
                                badge: formatCurrency(viewModel.monthlyRevenue)
                            )
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }
                    .staggeredAppear(index: 4)

                    // MARK: - Recent Activity
                    if !viewModel.recentOrders.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Letzte Aktivität")
                                .font(Font.App.headline)
                                .foregroundStyle(Color.App.textSecondary)
                                .padding(.horizontal, AppSpacing.md)

                            VStack(spacing: AppSpacing.xs) {
                                ForEach(Array(viewModel.recentOrders.prefix(3).enumerated()), id: \.element.id) { index, order in
                                    RecentOrderRow(order: order, currencyCode: appState.currencyCode, localeIdentifier: appState.localeIdentifier)
                                        .staggeredAppear(index: 5 + index)
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                        .staggeredAppear(index: 4)
                    }

                    Spacer(minLength: AppSpacing.lg)
                }
                .padding(.vertical, AppSpacing.md)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .tint(Color.App.accentPrimary)
            }
        }
        .onAppear {
            if let userId = appState.currentUser?.id {
                viewModel.loadData(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .orderDidComplete)) { _ in
            if let userId = appState.currentUser?.id {
                viewModel.loadData(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .orderDidChange)) { _ in
            if let userId = appState.currentUser?.id {
                viewModel.loadData(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deliveryDidComplete)) { _ in
            if let userId = appState.currentUser?.id {
                viewModel.loadData(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stockDidChange)) { _ in
            if let userId = appState.currentUser?.id {
                viewModel.loadData(userId: userId)
            }
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE, d. MMMM"
        return formatter.string(from: Date())
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = appState.currencyCode
        formatter.locale = Locale(identifier: appState.localeIdentifier)
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(Font.App.smallCaption)
                .foregroundStyle(Color.App.textSecondary)

            Text(value)
                .font(Font.App.amountSmall)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let subtitle {
                Text(subtitle)
                    .font(Font.App.smallCaption)
                    .foregroundStyle(color.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: AppSpacing.sm)
    }
}

// MARK: - Quick Action Tile

private struct QuickActionTile: View {
    let icon: String
    let label: String
    let color: Color
    let value: String

    var body: some View {
        NavigationLink(value: value) {
            VStack(spacing: AppSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(Font.App.smallCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.App.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.App.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(color.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { HapticManager.impact(.light) })
    }
}

// MARK: - Section Card

private struct SectionCard: View {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
    var badge: String? = nil

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(accentColor)
                .frame(width: 48, height: 48)
                .background(accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)

                Text(description)
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if let badge {
                Text(badge)
                    .font(Font.App.smallCaption)
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xxs)
                    .background(accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.App.textSecondary.opacity(0.5))
        }
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(
                    LinearGradient(
                        colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Recent Order Row

private struct RecentOrderRow: View {
    let order: Order
    let currencyCode: String
    let localeIdentifier: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Customer initials avatar
            Text(initials)
                .font(Font.App.smallCaption)
                .foregroundStyle(Color.App.textPrimary)
                .frame(width: 36, height: 36)
                .background(Color.App.accentPrimary.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(order.customerName ?? "Kunde")
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textPrimary)

                Text(itemSummary)
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(formattedTotal)
                .font(Font.App.amountSmall)
                .foregroundStyle(Color.App.accentPrimary)
        }
        .glassCard(padding: AppSpacing.sm)
    }

    private var initials: String {
        let name = order.customerName ?? ""
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var itemSummary: String {
        let items = order.items
        if items.isEmpty { return "Bestellung" }
        let codes = items.compactMap { $0.productCode ?? $0.productName }
        return codes.joined(separator: ", ")
    }

    private var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: localeIdentifier)
        return formatter.string(from: order.total as NSDecimalNumber) ?? "\(order.total)"
    }
}
