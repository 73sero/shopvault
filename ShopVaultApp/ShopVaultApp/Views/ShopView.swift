import SwiftUI

enum ShopDestination: Hashable {
    case newOrder, orders, customers, inventory, delivery
}

struct ShopView: View {
    @StateObject private var viewModel = ShopViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            AnimatedMeshGradientView()

            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    statsCard
                        .padding(.horizontal, AppSpacing.md)

                    VStack(spacing: AppSpacing.sm) {
                        menuItem(
                            icon: "plus.circle.fill",
                            iconColor: Color.App.accentPrimary,
                            title: "Neue Bestellung",
                            description: "Neue Kundenbestellung erstellen",
                            destination: .newOrder
                        )

                        menuItem(
                            icon: "list.clipboard.fill",
                            iconColor: Color.App.categoryGreen,
                            title: "Bestellungen",
                            description: "Alle Bestellungen anzeigen, bearbeiten oder löschen",
                            destination: .orders
                        )

                        menuItem(
                            icon: "person.2.fill",
                            iconColor: Color.App.categoryBlue,
                            title: "Kunden",
                            description: "Kundenliste verwalten",
                            destination: .customers
                        )

                        menuItem(
                            icon: "archivebox.fill",
                            iconColor: Color.App.categoryOrange,
                            title: "Inventar",
                            description: "Produktbestand verwalten",
                            destination: .inventory
                        )

                        menuItem(
                            icon: "shippingbox.fill",
                            iconColor: Color.App.categoryPurple,
                            title: "Lieferung eintragen",
                            description: "Wareneingang erfassen",
                            destination: .delivery
                        )
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
                .padding(.vertical, AppSpacing.md)
            }
        }
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(for: ShopDestination.self) { dest in
            switch dest {
            case .newOrder: NewOrderView(viewModel: NewOrderViewModel())
            case .orders: OrdersListView(viewModel: OrderListViewModel())
            case .customers: CustomerListView(viewModel: CustomerListViewModel())
            case .inventory: InventoryView(viewModel: InventoryViewModel())
            case .delivery: DeliveryView(viewModel: DeliveryViewModel())
            }
        }
        .onAppear {
            if let userId = appState.currentUser?.id {
                viewModel.load(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .orderDidComplete)) { _ in
            if let userId = appState.currentUser?.id {
                viewModel.load(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .orderDidChange)) { _ in
            if let userId = appState.currentUser?.id {
                viewModel.load(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deliveryDidComplete)) { _ in
            if let userId = appState.currentUser?.id {
                viewModel.load(userId: userId)
            }
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: AppSpacing.sm) {
            statTile(
                title: "Umsatz (Monat)",
                value: formatCurrency(viewModel.monthlyRevenue),
                color: Color.App.accentPrimary
            )
            statTile(
                title: "Gewinn",
                value: formatCurrency(viewModel.monthlyProfit),
                subtitle: viewModel.monthlyRevenue > 0 ? String(format: "%.0f%%", viewModel.marginPercent) : nil,
                color: viewModel.monthlyProfit >= 0 ? Color.App.accentSecondary : Color.App.danger
            )
            statTile(
                title: "Bestellungen",
                value: "\(viewModel.monthlyOrderCount)",
                color: Color.App.textPrimary
            )
        }
    }

    private func statTile(title: String, value: String, subtitle: String? = nil, color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(Font.App.smallCaption)
                .foregroundStyle(Color.App.textSecondary)
            Text(value)
                .font(Font.App.amountSmall)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let subtitle {
                Text(subtitle)
                    .font(Font.App.smallCaption)
                    .foregroundStyle(color.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: AppSpacing.sm)
    }

    @ViewBuilder
    private func menuItem(icon: String, iconColor: Color, title: String, description: String, destination: ShopDestination) -> some View {
        NavigationLink(value: destination) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 44, height: 44)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.textPrimary)

                    Text(description)
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.App.textSecondary.opacity(0.5))
            }
            .glassCard()
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = appState.currencyCode
        formatter.locale = Locale(identifier: appState.localeIdentifier)
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
