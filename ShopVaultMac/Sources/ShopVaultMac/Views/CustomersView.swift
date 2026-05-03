import SwiftUI

struct CustomersView: View {
    let dataset: VaultDataset

    @State private var searchText = ""
    @State private var selectedId: String?

    fileprivate struct CustomerWithStats: Identifiable {
        let customer: VaultCustomer
        let totalSpend: Decimal
        let orderCount: Int
        let lastOrder: Date?
        var id: String { customer.id }
    }

    private var customersWithStats: [CustomerWithStats] {
        let grouped = Dictionary(grouping: dataset.orders, by: \.customerId)
        return dataset.customers.map { c in
            let orders = grouped[c.id] ?? []
            return CustomerWithStats(
                customer: c,
                totalSpend: orders.reduce(Decimal.zero) { $0 + $1.total },
                orderCount: orders.count,
                lastOrder: orders.map(\.createdAt).max()
            )
        }.sorted { $0.totalSpend > $1.totalSpend }
    }

    private var filtered: [CustomerWithStats] {
        guard !searchText.isEmpty else { return customersWithStats }
        let q = searchText.lowercased()
        return customersWithStats.filter {
            $0.customer.name.lowercased().contains(q)
                || ($0.customer.email?.lowercased().contains(q) ?? false)
                || ($0.customer.phone?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            list
                .frame(minWidth: 340, idealWidth: 380, maxWidth: 440)
            Divider().background(Color.white.opacity(0.05))
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            PageHeader(
                title: "Kunden",
                subtitle: "\(filtered.count) Kunden",
                trailing: AnyView(AppSearchBar(text: $searchText, placeholder: "Name, Mail, Telefon…"))
            )

            if filtered.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.xs) {
                        ForEach(filtered) { entry in
                            CustomerRow(entry: entry, isSelected: selectedId == entry.id)
                                .onTapGesture { selectedId = entry.id }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.lg)
                }
            }
        }
        .onAppear {
            if selectedId == nil {
                selectedId = filtered.first?.id
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let id = selectedId,
           let entry = customersWithStats.first(where: { $0.id == id }) {
            CustomerDetailPane(
                customer: entry.customer,
                orders: dataset.orders.filter { $0.customerId == id }
            )
        } else {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "person.2")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.App.textTertiary)
                Text("Wähle einen Kunden")
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var empty: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 36))
                .foregroundStyle(Color.App.textTertiary)
            Text(searchText.isEmpty ? "Keine Kunden" : "Keine Treffer")
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CustomerRow: View {
    let entry: CustomersView.CustomerWithStats
    let isSelected: Bool

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            InitialsAvatar(name: entry.customer.name, size: 40, color: Color.App.categoryBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.customer.name)
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
                Text("\(entry.orderCount) Bestellungen · \(Format.eur(entry.totalSpend))")
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
            }
            Spacer()
            if let last = entry.lastOrder {
                Text(Format.mediumDate(last))
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textTertiary)
            }
        }
        .padding(AppSpacing.sm)
        .background(
            isSelected
            ? AnyShapeStyle(Color.App.categoryBlue.opacity(0.10))
            : AnyShapeStyle(Color.App.bgSecondary)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(
                    isSelected ? Color.App.categoryBlue.opacity(0.5) : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
    }
}

private struct CustomerDetailPane: View {
    let customer: VaultCustomer
    let orders: [VaultOrder]

    private var totalSpend: Decimal {
        orders.reduce(Decimal.zero) { $0 + $1.total }
    }

    private var avgOrder: Decimal {
        guard !orders.isEmpty else { return 0 }
        return totalSpend / Decimal(orders.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                header
                stats
                if !orders.isEmpty { orderHistory }
                if let notes = customer.notes, !notes.isEmpty { notesCard(notes) }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.md) {
            InitialsAvatar(name: customer.name, size: 72, color: Color.App.categoryBlue)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(customer.name)
                    .font(Font.App.title)
                    .foregroundStyle(Color.App.textPrimary)
                Text("Kunde seit \(Format.mediumDate(customer.createdAt))")
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textSecondary)
                contactPills
            }
            Spacer()
        }
        .glassCard()
    }

    private var contactPills: some View {
        HStack(spacing: AppSpacing.xs) {
            if let p = customer.phone, !p.isEmpty {
                contactPill(icon: "phone.fill", text: p)
            }
            if let e = customer.email, !e.isEmpty {
                contactPill(icon: "envelope.fill", text: e)
            }
            if let a = customer.address, !a.isEmpty {
                contactPill(icon: "mappin", text: a)
            }
        }
        .padding(.top, 2)
    }

    private func contactPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9))
            Text(text)
                .font(Font.App.smallCaption)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .foregroundStyle(Color.App.accentPrimary)
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 3)
        .background(Color.App.accentPrimary.opacity(0.12))
        .clipShape(Capsule())
    }

    private var stats: some View {
        HStack(spacing: AppSpacing.md) {
            StatTile(title: "Gesamtumsatz", value: Format.eur(totalSpend), color: Color.App.accentPrimary)
            StatTile(title: "Bestellungen", value: "\(orders.count)", color: Color.App.categoryBlue)
            StatTile(title: "Ø Warenkorb", value: Format.eur(avgOrder), color: Color.App.categoryPurple)
        }
    }

    private var orderHistory: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Bestellverlauf")
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textPrimary)

            ForEach(orders.sorted { $0.createdAt > $1.createdAt }) { order in
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.App.accentPrimary)
                        .frame(width: 28, height: 28)
                        .background(Color.App.accentPrimary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(itemSummary(order))
                            .font(Font.App.caption)
                            .foregroundStyle(Color.App.textPrimary)
                            .lineLimit(1)
                        Text(Format.dateTime(order.createdAt))
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.textSecondary)
                    }
                    Spacer()
                    Text(Format.eur(order.total))
                        .font(Font.App.amountSmall)
                        .foregroundStyle(Color.App.accentPrimary)
                }
                if order.id != orders.sorted(by: { $0.createdAt > $1.createdAt }).last?.id {
                    Divider().background(Color.white.opacity(0.05))
                }
            }
        }
        .glassCard()
    }

    private func itemSummary(_ order: VaultOrder) -> String {
        let parts = order.items.map { "\($0.quantity)× \($0.productCode ?? "?")" }
        return parts.isEmpty ? "Bestellung" : parts.joined(separator: ", ")
    }

    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Notizen")
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textPrimary)
            Text(notes)
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textSecondary)
                .textSelection(.enabled)
        }
        .glassCard()
    }
}
