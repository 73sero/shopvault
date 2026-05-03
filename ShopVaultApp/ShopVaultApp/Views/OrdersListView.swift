import SwiftUI

struct OrdersListView: View {
    @StateObject var viewModel: OrderListViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.App.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Bestellungen")
                        .font(Font.App.title)
                        .foregroundStyle(Color.App.textPrimary)
                    Text("\(viewModel.filteredOrders.count) Bestellungen")
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.accentPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.md)

                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.App.textSecondary)
                    TextField("Kundenname suchen…", text: $viewModel.searchText)
                        .foregroundStyle(Color.App.textPrimary)
                }
                .padding(AppSpacing.sm)
                .background(Color.App.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.small).stroke(Color.white.opacity(0.05), lineWidth: 1))
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.App.accentPrimary)
                    Spacer()
                } else if viewModel.filteredOrders.isEmpty {
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "bag")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.App.textSecondary.opacity(0.5))
                        Text("Noch keine Bestellungen")
                            .font(Font.App.headline)
                            .foregroundStyle(Color.App.textSecondary)
                    }
                    .padding(AppSpacing.xxl)
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.xs) {
                            ForEach(viewModel.filteredOrders) { order in
                                NavigationLink(value: order) {
                                    OrderRowCard(
                                        order: order,
                                        currencyCode: appState.currencyCode,
                                        localeIdentifier: appState.localeIdentifier
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.lg)
                    }
                }
            }
        }
        .navigationDestination(for: Order.self) { order in
            OrderDetailView(viewModel: OrderDetailViewModel(orderId: order.id))
        }
        .onAppear {
            if let userId = appState.currentUser?.id {
                viewModel.loadOrders(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .orderDidComplete)) { _ in
            if let userId = appState.currentUser?.id {
                viewModel.loadOrders(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .orderDidChange)) { _ in
            if let userId = appState.currentUser?.id {
                viewModel.loadOrders(userId: userId)
            }
        }
    }
}

// MARK: - Order Row Card

private struct OrderRowCard: View {
    let order: Order
    let currencyCode: String
    let localeIdentifier: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient.appAccent)
                .frame(width: 3, height: 44)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(order.customerName ?? "Unbekannt")
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)

                HStack(spacing: AppSpacing.xs) {
                    Text(itemSummary)
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                        .lineLimit(1)

                    Text("\u{00B7}")
                        .foregroundStyle(Color.App.textSecondary)

                    Text(formattedDate)
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                }

                if order.discountAmount > 0 {
                    HStack(spacing: AppSpacing.xxs) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.App.categoryOrange)
                        Text("-\(formattedDiscount)")
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.categoryOrange)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedTotal)
                    .font(Font.App.amountSmall)
                    .foregroundStyle(Color.App.accentPrimary)
                if order.discountAmount > 0 {
                    Text(formattedSubtotal)
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                        .strikethrough()
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.App.textSecondary.opacity(0.7))
        }
        .glassCard(padding: AppSpacing.sm)
    }

    private var itemSummary: String {
        let grouped = Dictionary(grouping: order.items) { $0.productCode ?? $0.productId }
        let parts = grouped.values.compactMap { items -> String? in
            guard let first = items.first else { return nil }
            let totalQty = items.reduce(0) { $0 + $1.quantity }
            let code = first.productCode ?? "?"
            return "\(totalQty)× \(code)"
        }
        return parts.isEmpty ? "–" : parts.joined(separator: ", ")
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: localeIdentifier)
        return formatter.string(from: order.createdAt)
    }

    private var formattedTotal: String { formatCurrency(order.total) }
    private var formattedSubtotal: String { formatCurrency(order.subtotal) }
    private var formattedDiscount: String { formatCurrency(order.discountAmount) }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: localeIdentifier)
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}

#Preview("Order List") {
    let appState: AppState = {
        let state = AppState()
        state.isAuthenticated = true
        state.currentUser = User.sample
        return state
    }()

    return NavigationStack {
        OrdersListView(viewModel: OrderListViewModel())
    }
    .environmentObject(appState)
}
