import SwiftUI

struct OrdersView: View {
    let dataset: VaultDataset

    @State private var searchText = ""
    @State private var selectedOrderId: String?

    private var filteredOrders: [VaultOrder] {
        guard !searchText.isEmpty else { return dataset.orders }
        let q = searchText.lowercased()
        return dataset.orders.filter { o in
            (o.customerName ?? "").lowercased().contains(q)
                || o.items.contains(where: { ($0.productCode ?? "").lowercased().contains(q) || ($0.productName ?? "").lowercased().contains(q) })
        }
    }

    private var summaryRevenue: Decimal {
        filteredOrders.reduce(Decimal.zero) { $0 + $1.total }
    }

    var body: some View {
        HStack(spacing: 0) {
            list
                .frame(minWidth: 360, idealWidth: 420, maxWidth: 480)

            Divider()
                .background(Color.white.opacity(0.05))

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            PageHeader(
                title: "Bestellungen",
                subtitle: "\(filteredOrders.count) · \(Format.eur(summaryRevenue))",
                trailing: AnyView(AppSearchBar(text: $searchText, placeholder: "Kunde oder Produkt…"))
            )

            if filteredOrders.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.xs) {
                        ForEach(filteredOrders) { order in
                            OrderRow(
                                order: order,
                                isSelected: selectedOrderId == order.id
                            )
                            .onTapGesture { selectedOrderId = order.id }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.lg)
                }
            }
        }
        .onAppear {
            if selectedOrderId == nil {
                selectedOrderId = dataset.orders.first?.id
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let id = selectedOrderId,
           let order = dataset.orders.first(where: { $0.id == id }) {
            OrderDetailPane(order: order, customer: dataset.customerById[order.customerId])
        } else {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "cart")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.App.textTertiary)
                Text("Wähle eine Bestellung")
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "cart")
                .font(.system(size: 36))
                .foregroundStyle(Color.App.textTertiary)
            Text(searchText.isEmpty ? "Noch keine Bestellungen" : "Keine Treffer")
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct OrderRow: View {
    let order: VaultOrder
    let isSelected: Bool

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient.appAccent)
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(order.customerName ?? "Unbekannt")
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)

                HStack(spacing: AppSpacing.xs) {
                    Text(itemSummary)
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                        .lineLimit(1)
                    Text("·")
                        .foregroundStyle(Color.App.textTertiary)
                    Text(Format.mediumDate(order.createdAt))
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.eur(order.total))
                    .font(Font.App.amountSmall)
                    .foregroundStyle(Color.App.accentPrimary)
                if order.discountAmount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 8))
                        Text("-\(Format.eur(order.discountAmount))")
                    }
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.categoryOrange)
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(
            isSelected
            ? AnyShapeStyle(Color.App.accentPrimary.opacity(0.10))
            : AnyShapeStyle(Color.App.bgSecondary)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(
                    isSelected ? Color.App.accentPrimary.opacity(0.5) : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
    }

    private var itemSummary: String {
        let parts = order.items.compactMap { item -> String? in
            let code = item.productCode ?? "?"
            return "\(item.quantity)× \(code)"
        }
        return parts.isEmpty ? "—" : parts.joined(separator: ", ")
    }
}

private struct OrderDetailPane: View {
    let order: VaultOrder
    let customer: VaultCustomer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                customerHeader
                if !order.items.isEmpty {
                    itemsCard
                }
                summaryCard
                if let customer, hasContact(customer) {
                    contactCard(customer)
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var customerHeader: some View {
        HStack(spacing: AppSpacing.sm) {
            InitialsAvatar(name: order.customerName ?? "?", size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(order.customerName ?? "Unbekannt")
                    .font(Font.App.title2)
                    .foregroundStyle(Color.App.textPrimary)
                Text("Bestellung vom \(Format.dateTime(order.createdAt))")
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.eur(order.total))
                    .font(Font.App.amountLarge)
                    .foregroundStyle(Color.App.accentPrimary)
                Text("\(order.items.count) Artikel · \(totalQuantity) Vials")
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
            }
        }
        .glassCard()
    }

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(Color.App.accentPrimary)
                Text("Positionen")
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
                Spacer()
            }

            ForEach(order.items) { item in
                HStack(spacing: AppSpacing.sm) {
                    Text(item.productCode ?? "?")
                        .font(Font.App.smallCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.App.accentPrimary)
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.App.accentPrimary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

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
                            Text("\(Format.eur(item.unitPrice))/Stk")
                                .font(Font.App.smallCaption)
                                .foregroundStyle(Color.App.textTertiary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(item.quantity)×")
                            .font(Font.App.caption)
                            .foregroundStyle(Color.App.textSecondary)
                        Text(Format.eur(item.lineTotal))
                            .font(Font.App.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.App.textPrimary)
                    }
                }
                if item.id != order.items.last?.id {
                    Divider().background(Color.white.opacity(0.05))
                }
            }
        }
        .glassCard()
    }

    private var summaryCard: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                Text("Zwischensumme")
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textSecondary)
                Spacer()
                Text(Format.eur(order.subtotal))
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textPrimary)
            }
            if order.discountAmount > 0 {
                HStack {
                    Label("Rabatt", systemImage: "tag.fill")
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.categoryOrange)
                    Spacer()
                    Text("-\(Format.eur(order.discountAmount))")
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.categoryOrange)
                }
                if let note = order.discountNote, !note.isEmpty {
                    HStack {
                        Text(note)
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.textTertiary)
                        Spacer()
                    }
                }
            }
            Divider().background(Color.white.opacity(0.1))
            HStack {
                Text("Gesamt")
                    .font(Font.App.title2)
                    .foregroundStyle(Color.App.textPrimary)
                Spacer()
                Text(Format.eur(order.total))
                    .font(Font.App.amountMedium)
                    .foregroundStyle(Color.App.accentPrimary)
            }
        }
        .glassCard()
    }

    private func contactCard(_ c: VaultCustomer) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Kundenkontakt")
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textPrimary)
            VStack(spacing: AppSpacing.xs) {
                if let phone = c.phone, !phone.isEmpty {
                    contactRow(icon: "phone.fill", text: phone)
                }
                if let email = c.email, !email.isEmpty {
                    contactRow(icon: "envelope.fill", text: email)
                }
                if let address = c.address, !address.isEmpty {
                    contactRow(icon: "mappin.and.ellipse", text: address)
                }
            }
        }
        .glassCard()
    }

    private func contactRow(icon: String, text: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(Color.App.accentPrimary)
                .frame(width: 16)
            Text(text)
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textPrimary)
                .textSelection(.enabled)
            Spacer()
        }
    }

    private func hasContact(_ c: VaultCustomer) -> Bool {
        (c.phone?.isEmpty == false) || (c.email?.isEmpty == false) || (c.address?.isEmpty == false)
    }

    private var totalQuantity: Int {
        order.items.reduce(0) { $0 + $1.quantity }
    }
}
