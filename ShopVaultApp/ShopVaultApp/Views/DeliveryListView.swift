import SwiftUI

struct DeliveryListView: View {
    @StateObject var viewModel: DeliveryListViewModel
    @EnvironmentObject var appState: AppState
    @State private var showCreate = false
    @State private var deleteCandidateId: String?

    var body: some View {
        ZStack {
            Color.App.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                summaryHeader
                contentList
            }
        }
        .navigationTitle("Lieferungen")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    HapticManager.impact(.light)
                    showCreate = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(LinearGradient.appAccent)
                }
                .accessibilityLabel("Neue Lieferung")
            }
        }
        .refreshable {
            if let userId = appState.currentUser?.id {
                viewModel.load(userId: userId)
            }
        }
        .onAppear {
            if let userId = appState.currentUser?.id {
                viewModel.load(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deliveryDidComplete)) { _ in
            if let userId = appState.currentUser?.id {
                viewModel.load(userId: userId)
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                DeliveryView(viewModel: DeliveryViewModel())
            }
        }
        .alert("Lieferung löschen?", isPresented: Binding(
            get: { deleteCandidateId != nil },
            set: { if !$0 { deleteCandidateId = nil } }
        )) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                if let id = deleteCandidateId {
                    viewModel.delete(deliveryId: id)
                    HapticManager.notification(.warning)
                }
                deleteCandidateId = nil
            }
        } message: {
            Text("Der eingegangene Bestand wird automatisch wieder vom aktuellen Inventar abgezogen (mind. 0). Diese Aktion kann nicht rückgängig gemacht werden.")
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: AppSpacing.sm) {
            statTile(
                icon: "shippingbox.fill",
                title: "Lieferungen",
                value: "\(viewModel.deliveries.count)",
                color: Color.App.categoryPurple
            )
            statTile(
                icon: "eurosign.circle.fill",
                title: "Wareneinsatz",
                value: formatPrice(viewModel.totalCost),
                color: Color.App.categoryPink
            )
        }
        .padding(AppSpacing.md)
    }

    private func statTile(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
                Text(value)
                    .font(Font.App.amountSmall)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .glassCard(padding: AppSpacing.xs)
    }

    @ViewBuilder
    private var contentList: some View {
        if viewModel.isLoading && viewModel.deliveries.isEmpty {
            VStack {
                Spacer()
                ProgressView().tint(Color.App.accentPrimary)
                Spacer()
            }
        } else if viewModel.deliveries.isEmpty {
            EmptyStateCard(
                icon: "shippingbox",
                title: "Noch keine Lieferungen",
                subtitle: "Erfasse Wareneingänge, um deinen Bestand und Wareneinsatz zu tracken.",
                actionTitle: "Erste Lieferung erfassen",
                actionIcon: "plus.circle.fill"
            ) {
                showCreate = true
            }
            .padding(AppSpacing.lg)
        } else {
            ScrollView {
                LazyVStack(spacing: AppSpacing.xs) {
                    ForEach(viewModel.deliveries) { delivery in
                        DeliveryRow(delivery: delivery, currencyCode: appState.currencyCode)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteCandidateId = delivery.id
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteCandidateId = delivery.id
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }

    private func formatPrice(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = appState.currencyCode
        f.locale = Locale(identifier: appState.localeIdentifier)
        return f.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}

private struct DeliveryRow: View {
    let delivery: SupplierDelivery
    let currencyCode: String

    private var totalQuantity: Int {
        delivery.items.reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .fill(Color.App.categoryPurple.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(Color.App.categoryPurple)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(formattedDate)
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
                Text("\(delivery.items.count) Positionen · \(totalQuantity) Vials")
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
                if let notes = delivery.notes, !notes.isEmpty {
                    Text(notes)
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(formattedTotal)
                .font(Font.App.amountSmall)
                .foregroundStyle(Color.App.categoryPink)
        }
        .glassCard(padding: AppSpacing.sm)
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: delivery.deliveredAt)
    }

    private var formattedTotal: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: delivery.totalCost as NSDecimalNumber) ?? "\(delivery.totalCost)"
    }
}
