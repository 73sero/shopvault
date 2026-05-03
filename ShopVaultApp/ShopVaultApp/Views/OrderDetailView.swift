import SwiftUI

struct OrderDetailView: View {
    @StateObject var viewModel: OrderDetailViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false

    var body: some View {
        ZStack {
            Color.App.bgPrimary.ignoresSafeArea()

            if viewModel.isLoading && viewModel.order == nil {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.App.accentPrimary)
            } else if let order = viewModel.order {
                content(for: order)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.danger)
                    .padding(AppSpacing.lg)
            }
        }
        .navigationTitle("Bestellung")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .orderDidChange)) { _ in
            viewModel.load()
        }
        .alert("Bestellung löschen?", isPresented: $showDeleteConfirmation) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                viewModel.delete { success in
                    if success { dismiss() }
                }
            }
        } message: {
            Text("Der Lagerbestand wird wiederhergestellt und die zugehörige Einnahme entfernt.")
        }
        .sheet(isPresented: $showEditSheet) {
            if let order = viewModel.order {
                EditOrderView(viewModel: EditOrderViewModel(order: order))
            }
        }
    }

    @ViewBuilder
    private func content(for order: Order) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                customerHeader(order)
                    .staggeredAppear(index: 0)

                if !order.items.isEmpty {
                    itemsCard(order)
                        .staggeredAppear(index: 1)
                }

                summaryCard(order)
                    .staggeredAppear(index: 2)

                actionsCard
                    .staggeredAppear(index: 3)
            }
            .padding(AppSpacing.md)
        }
    }

    private func customerHeader(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(Color.App.accentPrimary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Text(initials(for: order.customerName ?? "?"))
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.accentPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(order.customerName ?? "Unbekannt")
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.textPrimary)
                    Text(formattedDate(order.createdAt))
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                }
                Spacer()
            }
        }
        .glassCard()
    }

    private func itemsCard(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(Color.App.accentPrimary)
                Text("\(order.items.count) Artikel")
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
                Spacer()
            }

            ForEach(order.items) { item in
                itemRow(item)
                if item.id != order.items.last?.id {
                    Divider().background(Color.white.opacity(0.06))
                }
            }
        }
        .glassCard()
    }

    private func itemRow(_ item: OrderItem) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(item.productCode ?? "?")
                .font(Font.App.smallCaption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.App.accentPrimary)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, 2)
                .background(Color.App.accentPrimary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName ?? "Produkt")
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textPrimary)
                HStack(spacing: AppSpacing.xxs) {
                    if let spec = item.productSpec, !spec.isEmpty {
                        Text(spec)
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.textSecondary)
                    }
                    Text("\(formatCurrency(item.unitPrice))/Stk")
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.quantity)×")
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textSecondary)
                Text(formatCurrency(item.lineTotal))
                    .font(Font.App.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.App.textPrimary)
            }
        }
    }

    private func summaryCard(_ order: Order) -> some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                Text("Zwischensumme")
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textSecondary)
                Spacer()
                Text(formatCurrency(order.subtotal))
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textPrimary)
            }

            if order.discountAmount > 0 {
                VStack(spacing: AppSpacing.xxs) {
                    HStack {
                        Label("Rabatt", systemImage: "tag.fill")
                            .font(Font.App.caption)
                            .foregroundStyle(Color.App.danger)
                        Spacer()
                        Text("-\(formatCurrency(order.discountAmount))")
                            .font(Font.App.caption)
                            .foregroundStyle(Color.App.danger)
                    }
                    if let note = order.discountNote, !note.isEmpty {
                        HStack {
                            Text(note)
                                .font(Font.App.smallCaption)
                                .foregroundStyle(Color.App.textSecondary)
                            Spacer()
                        }
                    }
                }
            }

            Divider().background(Color.white.opacity(0.1))

            HStack {
                Text("Gesamt")
                    .font(Font.App.title2)
                    .foregroundStyle(Color.App.textPrimary)
                Spacer()
                Text(formatCurrency(order.total))
                    .font(Font.App.amountMedium)
                    .foregroundStyle(Color.App.accentPrimary)
            }
        }
        .glassCard()
    }

    private var actionsCard: some View {
        VStack(spacing: AppSpacing.sm) {
            GradientButton(
                title: "Bestellung bearbeiten",
                icon: "pencil",
                action: { showEditSheet = true },
                style: .secondary
            )

            GradientButton(
                title: viewModel.isDeleting ? "Wird gelöscht…" : "Bestellung löschen",
                icon: "trash",
                action: { showDeleteConfirmation = true },
                isDisabled: viewModel.isDeleting,
                isLoading: viewModel.isDeleting,
                style: .danger
            )
        }
    }

    // MARK: - Helpers

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: appState.localeIdentifier)
        return formatter.string(from: date)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = appState.currencyCode
        formatter.locale = Locale(identifier: appState.localeIdentifier)
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
