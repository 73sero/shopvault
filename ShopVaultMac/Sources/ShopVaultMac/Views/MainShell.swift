import SwiftUI

enum VaultSection: String, CaseIterable, Identifiable {
    case dashboard, orders, customers, products, income, deliveries

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: return "Shop-Übersicht"
        case .orders: return "Bestellungen"
        case .customers: return "Kunden"
        case .products: return "Produkte"
        case .income: return "Einnahmen-Übersicht"
        case .deliveries: return "Lieferungen"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "chart.bar.fill"
        case .orders: return "cart.fill"
        case .customers: return "person.2.fill"
        case .products: return "shippingbox.fill"
        case .income: return "eurosign.circle.fill"
        case .deliveries: return "truck.box.fill"
        }
    }

    var color: Color {
        switch self {
        case .dashboard: return Color.App.accentPrimary
        case .orders: return Color.App.categoryGreen
        case .customers: return Color.App.categoryBlue
        case .products: return Color.App.categoryOrange
        case .income: return Color.App.accentPrimary
        case .deliveries: return Color.App.categoryPurple
        }
    }
}

struct MainShell: View {
    let dataset: VaultDataset
    let onLock: () -> Void

    @Environment(HiddenItemsStore.self) private var hiddenStore
    @State private var selection: VaultSection = .dashboard

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 240)

            Divider()
                .background(Color.white.opacity(0.05))

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.clear)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(spacing: AppSpacing.xs) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.appAccent.opacity(0.18))
                            .frame(width: 32, height: 32)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LinearGradient.appAccent)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("ShopVault")
                            .font(Font.App.headline)
                            .foregroundStyle(Color.App.textPrimary)
                        Text("Snapshot")
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
            }

            VStack(spacing: 2) {
                ForEach(VaultSection.allCases) { section in
                    sidebarRow(section)
                }
            }
            .padding(.horizontal, AppSpacing.xs)

            Spacer()

            VStack(spacing: AppSpacing.xs) {
                if let exportedAt = dataset.exportedAt {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.App.textTertiary)
                        Text("Snapshot: \(formattedExport(exportedAt))")
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.textTertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: onLock) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                        Text("Sperren")
                            .font(Font.App.caption)
                        Spacer()
                    }
                    .foregroundStyle(Color.App.textSecondary)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                }
                .buttonStyle(.plain)
            }
            .padding(AppSpacing.md)
        }
        .background(Color.App.bgPrimary.opacity(0.55))
    }

    private func sidebarRow(_ section: VaultSection) -> some View {
        Button {
            selection = section
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: section.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selection == section ? section.color : Color.App.textSecondary)
                    .frame(width: 22)
                Text(section.label)
                    .font(Font.App.caption)
                    .foregroundStyle(selection == section ? Color.App.textPrimary : Color.App.textSecondary)
                Spacer()
                Text(badge(for: section))
                    .font(Font.App.monoCaption)
                    .foregroundStyle(Color.App.textTertiary)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(
                selection == section
                ? AnyShapeStyle(section.color.opacity(0.12))
                : AnyShapeStyle(Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .stroke(
                        selection == section ? section.color.opacity(0.25) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func badge(for section: VaultSection) -> String {
        switch section {
        case .dashboard: return ""
        case .orders: return "\(dataset.orders.count)"
        case .customers: return "\(dataset.customers.count)"
        case .products: return "\(dataset.products.filter { $0.isActive }.count)"
        case .income: return "\(dataset.income.count)"
        case .deliveries:
            let visible = dataset.deliveries.filter { !hiddenStore.isHidden(deliveryId: $0.id) }.count
            return "\(visible)"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .dashboard: DashboardView(dataset: dataset)
        case .orders: OrdersView(dataset: dataset)
        case .customers: CustomersView(dataset: dataset)
        case .products: ProductsView(dataset: dataset)
        case .income: IncomeView(dataset: dataset)
        case .deliveries: DeliveriesView(dataset: dataset)
        }
    }

    private func formattedExport(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
}

// MARK: - Reusable: page header

struct PageHeader: View {
    let title: String
    let subtitle: String?
    var trailing: AnyView? = nil

    init(title: String, subtitle: String? = nil, trailing: AnyView? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(Font.App.title)
                    .foregroundStyle(Color.App.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.textSecondary)
                }
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.md)
    }
}

// MARK: - Reusable: search bar

struct AppSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Suchen…"

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Color.App.textSecondary)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Color.App.textTertiary))
                .textFieldStyle(.plain)
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textPrimary)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.App.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(Color.App.bgTertiary.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.small)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .frame(maxWidth: 260)
    }
}

// MARK: - Reusable: stat tile

struct StatTile: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let color: Color
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(title)
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
                    .textCase(.uppercase)
                Spacer()
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(color.opacity(0.8))
                        .frame(width: 24, height: 24)
                        .background(color.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            Text(value)
                .font(Font.App.amountMedium)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let subtitle {
                Text(subtitle)
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: AppSpacing.md)
    }
}

// MARK: - Currency / date helpers

enum Format {
    static func eur(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value) €"
    }

    static func eurCompact(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value) €"
    }

    static func mediumDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: date)
    }

    static func dateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: date)
    }

    static func monthShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: date)
    }
}

// MARK: - Initials avatar

struct InitialsAvatar: View {
    let name: String
    var size: CGFloat = 36
    var color: Color = Color.App.accentPrimary

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.18))
            Circle()
                .stroke(color.opacity(0.35), lineWidth: 1)
            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
