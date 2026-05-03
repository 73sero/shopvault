import SwiftUI

private enum ProductFilter: String, CaseIterable, Identifiable {
    case all, low, empty, favorites, hidden
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "Alle"
        case .low: return "Niedrig"
        case .empty: return "Leer"
        case .favorites: return "Favoriten"
        case .hidden: return "Versteckt"
        }
    }
}

struct ProductsView: View {
    let dataset: VaultDataset

    @State private var searchText = ""
    @State private var filter: ProductFilter = .all

    private var filtered: [VaultProduct] {
        var result = dataset.products
        switch filter {
        case .all: result = result.filter { $0.isActive }
        case .low: result = result.filter { $0.isActive && $0.isLowStock && !$0.isOutOfStock }
        case .empty: result = result.filter { $0.isActive && $0.isOutOfStock }
        case .favorites: result = result.filter { $0.isActive && $0.isFavorite }
        case .hidden: result = result.filter { !$0.isActive }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(q)
                    || $0.code.lowercased().contains(q)
                    || $0.specification.lowercased().contains(q)
            }
        }
        return result.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                title: "Produkte",
                subtitle: "\(dataset.products.filter { $0.isActive }.count) aktiv · \(dataset.products.reduce(0) { $0 + $1.stock }) Vials gesamt",
                trailing: AnyView(AppSearchBar(text: $searchText, placeholder: "Code, Name, Stärke…"))
            )

            HStack(spacing: AppSpacing.xs) {
                ForEach(ProductFilter.allCases) { f in
                    filterChip(f)
                }
                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.sm)

            if filtered.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 280), spacing: AppSpacing.sm)],
                        spacing: AppSpacing.sm
                    ) {
                        ForEach(filtered) { product in
                            ProductCard(product: product)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.lg)
                }
            }
        }
    }

    private func filterChip(_ f: ProductFilter) -> some View {
        Button { filter = f } label: {
            Text(f.label)
                .font(Font.App.caption)
                .foregroundStyle(filter == f ? Color.App.bgPrimary : Color.App.textSecondary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 4)
                .background(filter == f ? Color.App.accentPrimary : Color.App.bgSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        filter == f ? Color.clear : Color.white.opacity(0.06),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private var empty: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "shippingbox")
                .font(.system(size: 36))
                .foregroundStyle(Color.App.textTertiary)
            Text("Keine Produkte")
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ProductCard: View {
    let product: VaultProduct

    private var stockColor: Color {
        if product.isOutOfStock { return Color.App.danger }
        if product.isLowStock { return Color.App.categoryOrange }
        return Color.App.accentPrimary
    }

    private var stockFillRatio: CGFloat {
        guard product.lowStockThreshold > 0 else { return 1.0 }
        let maxDisplay = max(product.lowStockThreshold * 3, product.stock)
        guard maxDisplay > 0 else { return 0 }
        return min(CGFloat(product.stock) / CGFloat(maxDisplay), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(product.code)
                    .font(Font.App.smallCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.App.accentPrimary)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.App.accentPrimary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(product.name)
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
                    .lineLimit(1)

                Spacer()

                if product.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.App.categoryOrange)
                }
            }

            HStack(spacing: AppSpacing.xs) {
                if !product.specification.isEmpty {
                    Text(product.specification)
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Capsule())
                }
                Text(Format.eur(product.price))
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textTertiary)
                Spacer()
            }

            HStack(spacing: AppSpacing.sm) {
                Text("\(product.stock)")
                    .font(Font.App.amountSmall)
                    .foregroundStyle(stockColor)
                    .frame(width: 36, height: 36)
                    .background(stockColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(stockColor.opacity(0.3), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Bestand")
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.textTertiary)
                        Spacer()
                        if product.isOutOfStock {
                            Text("Leer")
                                .font(Font.App.smallCaption)
                                .foregroundStyle(Color.App.danger)
                        } else if product.isLowStock {
                            Text("Nachbestellen")
                                .font(Font.App.smallCaption)
                                .foregroundStyle(Color.App.categoryOrange)
                        }
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.05))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2).fill(stockColor)
                                .frame(width: geo.size.width * stockFillRatio, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
        .glassCard(padding: AppSpacing.sm)
        .opacity(product.isActive ? 1.0 : 0.55)
    }
}
