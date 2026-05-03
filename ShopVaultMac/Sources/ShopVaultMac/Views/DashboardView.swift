import SwiftUI
import Charts

struct DashboardView: View {
    let dataset: VaultDataset
    @Environment(HiddenItemsStore.self) private var hiddenStore

    private var visibleDeliveries: [VaultDelivery] {
        dataset.deliveries.filter { !hiddenStore.isHidden(deliveryId: $0.id) }
    }

    private var totalRevenue: Decimal {
        dataset.orders.reduce(Decimal.zero) { $0 + $1.total }
    }

    private var totalCost: Decimal {
        visibleDeliveries.reduce(Decimal.zero) { $0 + $1.totalCost }
    }

    private var totalProfit: Decimal {
        totalRevenue - totalCost
    }

    private var marginPercent: Double {
        guard totalRevenue > 0 else { return 0 }
        let p = NSDecimalNumber(decimal: totalProfit).doubleValue
        let r = NSDecimalNumber(decimal: totalRevenue).doubleValue
        return (p / r) * 100
    }

    private var avgOrderValue: Decimal {
        guard !dataset.orders.isEmpty else { return 0 }
        return totalRevenue / Decimal(dataset.orders.count)
    }

    private var lowStockCount: Int {
        dataset.products.filter { $0.isActive && $0.isLowStock }.count
    }

    private var outOfStockCount: Int {
        dataset.products.filter { $0.isActive && $0.isOutOfStock }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                PageHeader(
                    title: "Shop-Übersicht",
                    subtitle: "Bestellungen · Inventar · Wareneinsatz · Snapshot vom \(dataset.exportedAt.map(Format.dateTime) ?? "—")"
                )

                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    statsGrid
                    chartCard
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        recentOrdersCard.frame(maxWidth: .infinity)
                        topCustomersCard.frame(maxWidth: .infinity)
                    }
                    inventoryAlertCard
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }

    private var statsGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 200), spacing: AppSpacing.md)]
        return LazyVGrid(columns: columns, spacing: AppSpacing.md) {
            StatTile(
                title: "Umsatz gesamt",
                value: Format.eur(totalRevenue),
                subtitle: "\(dataset.orders.count) Bestellungen",
                color: Color.App.accentPrimary,
                icon: "eurosign"
            )
            StatTile(
                title: "Gewinn",
                value: Format.eur(totalProfit),
                subtitle: marginPercent != 0 ? String(format: "Marge %.1f %%", marginPercent) : nil,
                color: totalProfit >= 0 ? Color.App.accentSecondary : Color.App.danger,
                icon: "chart.line.uptrend.xyaxis"
            )
            StatTile(
                title: "Ø Bestellung",
                value: Format.eur(avgOrderValue),
                color: Color.App.categoryPurple,
                icon: "cart"
            )
            StatTile(
                title: "Kunden",
                value: "\(dataset.customers.count)",
                subtitle: "\(uniqueBuyersCount) aktive Käufer",
                color: Color.App.categoryBlue,
                icon: "person.2"
            )
            StatTile(
                title: "Produkte",
                value: "\(dataset.products.filter { $0.isActive }.count)",
                subtitle: "\(dataset.products.reduce(0) { $0 + $1.stock }) Vials gesamt",
                color: Color.App.categoryOrange,
                icon: "shippingbox"
            )
            StatTile(
                title: "Wareneinsatz",
                value: Format.eur(totalCost),
                subtitle: hiddenStore.hiddenDeliveryCount > 0
                    ? "\(visibleDeliveries.count) sichtbar · \(hiddenStore.hiddenDeliveryCount) ausgeblendet"
                    : "\(visibleDeliveries.count) Lieferungen",
                color: Color.App.categoryPink,
                icon: "truck.box"
            )
        }
    }

    private var uniqueBuyersCount: Int {
        Set(dataset.orders.map { $0.customerId }).count
    }

    // MARK: - Chart

    private struct MonthlyBucket: Identifiable {
        let id = UUID()
        let month: Date
        let revenue: Decimal
        let cost: Decimal
        var profit: Decimal { revenue - cost }
    }

    private var monthlySeries: [MonthlyBucket] {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let months: [Date] = (0..<6).reversed().compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: now)
        }.compactMap { date in
            calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        }

        return months.map { monthStart in
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            let rev = dataset.orders
                .filter { $0.createdAt >= monthStart && $0.createdAt < nextMonth }
                .reduce(Decimal.zero) { $0 + $1.total }
            let cost = visibleDeliveries
                .filter { $0.deliveredAt >= monthStart && $0.deliveredAt < nextMonth }
                .reduce(Decimal.zero) { $0 + $1.totalCost }
            return MonthlyBucket(month: monthStart, revenue: rev, cost: cost)
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Umsatz vs. Wareneinsatz")
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.textPrimary)
                    Text("Letzte 6 Monate")
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                }
                Spacer()
                HStack(spacing: AppSpacing.md) {
                    legendDot(color: Color.App.accentPrimary, label: "Umsatz")
                    legendDot(color: Color.App.categoryPink, label: "Kosten")
                    legendDot(color: Color.App.accentSecondary, label: "Gewinn")
                }
            }

            Chart(monthlySeries) { bucket in
                BarMark(
                    x: .value("Monat", Format.monthShort(bucket.month)),
                    y: .value("Umsatz", NSDecimalNumber(decimal: bucket.revenue).doubleValue)
                )
                .foregroundStyle(Color.App.accentPrimary.opacity(0.85))
                .position(by: .value("series", "Umsatz"))
                .cornerRadius(4)

                BarMark(
                    x: .value("Monat", Format.monthShort(bucket.month)),
                    y: .value("Kosten", NSDecimalNumber(decimal: bucket.cost).doubleValue)
                )
                .foregroundStyle(Color.App.categoryPink.opacity(0.85))
                .position(by: .value("series", "Kosten"))
                .cornerRadius(4)

                LineMark(
                    x: .value("Monat", Format.monthShort(bucket.month)),
                    y: .value("Gewinn", NSDecimalNumber(decimal: bucket.profit).doubleValue)
                )
                .foregroundStyle(Color.App.accentSecondary)
                .interpolationMethod(.catmullRom)
                .symbol(Circle())
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .frame(height: 220)
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel().foregroundStyle(Color.App.textTertiary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(Color.App.textTertiary)
                }
            }
        }
        .glassCard()
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(Font.App.smallCaption)
                .foregroundStyle(Color.App.textSecondary)
        }
    }

    // MARK: - Recent orders

    private var recentOrdersCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Letzte Bestellungen")
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textPrimary)

            if dataset.orders.isEmpty {
                emptyHint("Noch keine Bestellungen")
            } else {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(dataset.orders.prefix(5)) { order in
                        HStack(spacing: AppSpacing.sm) {
                            InitialsAvatar(name: order.customerName ?? "?", size: 32)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(order.customerName ?? "Unbekannt")
                                    .font(Font.App.caption)
                                    .foregroundStyle(Color.App.textPrimary)
                                Text(Format.mediumDate(order.createdAt))
                                    .font(Font.App.smallCaption)
                                    .foregroundStyle(Color.App.textSecondary)
                            }
                            Spacer()
                            Text(Format.eur(order.total))
                                .font(Font.App.amountSmall)
                                .foregroundStyle(Color.App.accentPrimary)
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    // MARK: - Top customers

    private struct CustomerStat: Identifiable {
        let id: String
        let name: String
        let total: Decimal
        let count: Int
    }

    private var topCustomers: [CustomerStat] {
        let grouped = Dictionary(grouping: dataset.orders, by: \.customerId)
        let stats = grouped.compactMap { (cid, orders) -> CustomerStat? in
            let name = orders.first?.customerName ?? dataset.customerById[cid]?.name ?? "?"
            let total = orders.reduce(Decimal.zero) { $0 + $1.total }
            return CustomerStat(id: cid, name: name, total: total, count: orders.count)
        }
        return Array(stats.sorted { $0.total > $1.total }.prefix(5))
    }

    private var topCustomersCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Top Kunden")
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textPrimary)

            if topCustomers.isEmpty {
                emptyHint("Noch keine Käufer")
            } else {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(Array(topCustomers.enumerated()), id: \.element.id) { idx, stat in
                        HStack(spacing: AppSpacing.sm) {
                            Text("#\(idx + 1)")
                                .font(Font.App.monoCaption)
                                .foregroundStyle(Color.App.textTertiary)
                                .frame(width: 22, alignment: .leading)
                            InitialsAvatar(name: stat.name, size: 32, color: Color.App.categoryBlue)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(stat.name)
                                    .font(Font.App.caption)
                                    .foregroundStyle(Color.App.textPrimary)
                                Text("\(stat.count) Bestellungen")
                                    .font(Font.App.smallCaption)
                                    .foregroundStyle(Color.App.textSecondary)
                            }
                            Spacer()
                            Text(Format.eur(stat.total))
                                .font(Font.App.amountSmall)
                                .foregroundStyle(Color.App.accentPrimary)
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    // MARK: - Inventory alerts

    private var inventoryAlertCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Bestand-Alarme")
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
                Spacer()
                if outOfStockCount > 0 {
                    pill(text: "\(outOfStockCount) leer", color: Color.App.danger)
                }
                if lowStockCount > 0 {
                    pill(text: "\(lowStockCount) niedrig", color: Color.App.categoryOrange)
                }
            }

            let alerts = dataset.products
                .filter { $0.isActive && ($0.isOutOfStock || $0.isLowStock) }
                .sorted { $0.stock < $1.stock }
                .prefix(8)

            if alerts.isEmpty {
                emptyHint("Alle Bestände im grünen Bereich")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: AppSpacing.xs)], spacing: AppSpacing.xs) {
                    ForEach(Array(alerts), id: \.id) { p in
                        HStack(spacing: AppSpacing.xs) {
                            Text("\(p.stock)")
                                .font(Font.App.amountSmall)
                                .foregroundStyle(p.isOutOfStock ? Color.App.danger : Color.App.categoryOrange)
                                .frame(width: 32, height: 32)
                                .background((p.isOutOfStock ? Color.App.danger : Color.App.categoryOrange).opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(p.name)
                                    .font(Font.App.caption)
                                    .foregroundStyle(Color.App.textPrimary)
                                    .lineLimit(1)
                                Text("\(p.code) · \(p.specification)")
                                    .font(Font.App.smallCaption)
                                    .foregroundStyle(Color.App.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    private func pill(text: String, color: Color) -> some View {
        Text(text)
            .font(Font.App.smallCaption)
            .foregroundStyle(color)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func emptyHint(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textTertiary)
                .padding(.vertical, AppSpacing.md)
            Spacer()
        }
    }
}
