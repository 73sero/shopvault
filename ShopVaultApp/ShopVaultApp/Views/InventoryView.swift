import SwiftUI

struct InventoryView: View {
    @StateObject var viewModel: InventoryViewModel
    @EnvironmentObject var appState: AppState
    @State private var editingProduct: Product?
    @State private var stockInput = ""

    var body: some View {
        ZStack {
            AnimatedMeshGradientView()

            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    // MARK: - Filter Tabs
                    filterTabs
                        .staggeredAppear(index: 0)

                    // MARK: - Search Bar
                    searchBar
                        .staggeredAppear(index: 1)

                    // MARK: - Low Stock Alert
                    if viewModel.lowStockCount > 0 {
                        lowStockBanner
                            .staggeredAppear(index: 2)
                    }

                    // MARK: - Product List
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(Color.App.accentPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(AppSpacing.xxl)
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.App.danger.opacity(0.5))
                            Text(error)
                                .font(Font.App.caption)
                                .foregroundStyle(Color.App.textSecondary)
                        }
                        .padding(AppSpacing.xxl)
                        .frame(maxWidth: .infinity)
                    } else if viewModel.filteredProducts.isEmpty {
                        emptyState
                            .staggeredAppear(index: 3)
                    } else {
                        LazyVStack(spacing: AppSpacing.xs) {
                            ForEach(Array(viewModel.filteredProducts.enumerated()), id: \.element.id) { index, product in
                                ProductRow(product: product)
                                    .opacity(product.isActive ? 1.0 : 0.5)
                                    .contextMenu {
                                        Button {
                                            editingProduct = product
                                            stockInput = "\(product.stock)"
                                        } label: {
                                            Label("Bestand anpassen", systemImage: "number.square")
                                        }

                                        Button {
                                            viewModel.toggleFavorite(product)
                                        } label: {
                                            Label(
                                                product.isFavorite ? "Nicht mehr hervorheben" : "Hervorheben",
                                                systemImage: product.isFavorite ? "star.slash" : "star.fill"
                                            )
                                        }

                                        Divider()

                                        Button(role: product.isActive ? .destructive : nil) {
                                            viewModel.toggleHidden(product)
                                        } label: {
                                            Label(
                                                product.isActive ? "Ausblenden" : "Einblenden",
                                                systemImage: product.isActive ? "eye.slash" : "eye"
                                            )
                                        }
                                    }
                                    .staggeredAppear(index: index + 3)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }

                    // MARK: - Footer Stats
                    footerStats
                        .staggeredAppear(index: 4)

                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(.top, AppSpacing.sm)
            }
        }
        .navigationTitle("Inventar")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { viewModel.loadProducts() }
        .onReceive(NotificationCenter.default.publisher(for: .stockDidChange)) { _ in
            viewModel.loadProducts()
        }
        .sheet(item: $editingProduct) { product in
            NavigationStack {
                VStack(spacing: AppSpacing.lg) {
                    VStack(spacing: AppSpacing.xs) {
                        Text(product.name)
                            .font(Font.App.headline)
                            .foregroundStyle(Color.App.textPrimary)
                        Text("\(product.code) · \(product.specification)")
                            .font(Font.App.caption)
                            .foregroundStyle(Color.App.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Aktueller Bestand: \(product.stock)")
                            .font(Font.App.caption)
                            .foregroundStyle(Color.App.textSecondary)

                        TextField("Neuer Bestand", text: $stockInput)
                            .keyboardType(.numberPad)
                            .font(Font.App.amountLarge)
                            .foregroundStyle(Color.App.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(AppSpacing.md)
                            .background(Color.App.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                    }

                    GradientButton(title: "Bestand speichern", icon: "checkmark.circle.fill") {
                        if let newStock = Int(stockInput), newStock >= 0 {
                            viewModel.updateStock(product, newStock: newStock)
                            editingProduct = nil
                        }
                    }

                    Spacer()
                }
                .padding(AppSpacing.lg)
                .background(Color.App.bgPrimary.ignoresSafeArea())
                .navigationTitle("Bestand anpassen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { editingProduct = nil }
                            .foregroundStyle(Color.App.textSecondary)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(InventoryFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(Font.App.caption)
                        .foregroundStyle(
                            viewModel.selectedFilter == filter
                                ? Color.App.bgPrimary
                                : Color.App.textSecondary
                        )
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(
                            viewModel.selectedFilter == filter
                                ? Color.App.accentPrimary
                                : Color.App.bgSecondary
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                viewModel.selectedFilter == filter
                                    ? Color.clear
                                    : Color.white.opacity(0.05),
                                lineWidth: 1
                            )
                        )
                }
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.App.textSecondary)
            TextField("Produkt suchen...", text: $viewModel.searchText)
                .foregroundStyle(Color.App.textPrimary)
        }
        .padding(AppSpacing.sm)
        .background(Color.App.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.small)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Low Stock Banner

    private var lowStockBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.App.danger)
                .font(.system(size: 18))
            Text("\(viewModel.lowStockCount) Produkte unter Mindestbestand")
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textPrimary)
            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(Color.App.danger.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.small)
                .stroke(Color.App.danger.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundStyle(Color.App.textSecondary.opacity(0.5))
            Text("Keine Produkte gefunden")
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textSecondary)
            Text("Passe deine Filter oder Suche an")
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textSecondary.opacity(0.7))
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer Stats

    private var footerStats: some View {
        Text("\(viewModel.products.count) Produkte \u{00B7} \(viewModel.totalVials) Vials gesamt")
            .font(Font.App.smallCaption)
            .foregroundStyle(Color.App.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.top, AppSpacing.sm)
    }
}

// MARK: - Product Row

struct ProductRow: View {
    let product: Product

    private var stockColor: Color {
        if product.isOutOfStock {
            return Color.App.danger
        } else if product.isLowStock {
            return Color.App.categoryOrange
        } else {
            return Color.App.accentPrimary
        }
    }

    private var stockFillRatio: CGFloat {
        guard product.lowStockThreshold > 0 else { return 1.0 }
        let maxDisplay = max(product.lowStockThreshold * 3, product.stock)
        guard maxDisplay > 0 else { return 0 }
        return min(CGFloat(product.stock) / CGFloat(maxDisplay), 1.0)
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Stock count badge
            Text("\(product.stock)")
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textPrimary)
                .frame(width: 44, height: 44)
                .background(stockColor.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.small)
                        .stroke(stockColor.opacity(0.4), lineWidth: 1)
                )

            // Product info
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(spacing: AppSpacing.xs) {
                    Text(product.name)
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.textPrimary)
                        .lineLimit(1)
                    if !product.specification.isEmpty {
                        Text(product.specification)
                            .font(Font.App.smallCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.App.accentPrimary)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, 1)
                            .background(Color.App.accentPrimary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Spacer()
                    if product.isLowStock && !product.isOutOfStock {
                        Text("Nachbestellen")
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.danger)
                    } else if product.isOutOfStock {
                        Text("Leer")
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.danger)
                    }
                }

                HStack(spacing: AppSpacing.xxs) {
                    Text(product.code)
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                    if product.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.App.categoryOrange)
                    }
                }

                // Stock fill bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.App.bgTertiary)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(stockColor)
                            .frame(width: geometry.size.width * stockFillRatio, height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .glassCard(padding: AppSpacing.sm)
    }
}

// MARK: - Preview

#Preview("Inventory") {
    NavigationStack {
        InventoryView(viewModel: InventoryViewModel())
            .environmentObject(AppState())
    }
}
