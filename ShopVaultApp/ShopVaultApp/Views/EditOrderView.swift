import SwiftUI

struct EditOrderView: View {
    @StateObject var viewModel: EditOrderViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.App.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        if !viewModel.customerName.isEmpty {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(Color.App.accentPrimary)
                                Text(viewModel.customerName)
                                    .font(Font.App.headline)
                                    .foregroundStyle(Color.App.textPrimary)
                                Spacer()
                            }
                            .glassCard()
                        }

                        addProductSection

                        if !viewModel.items.isEmpty {
                            itemsSection
                        }

                        discountSection

                        summarySection

                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }

                        GradientButton(
                            title: "Änderungen speichern",
                            icon: "checkmark.circle.fill",
                            action: { viewModel.save() },
                            isDisabled: !viewModel.canSave,
                            isLoading: viewModel.isSaving
                        )
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle("Bestellung bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") { dismiss() }
                        .foregroundStyle(Color.App.textSecondary)
                }
            }
            .onChange(of: viewModel.didSave) { _, saved in
                if saved { dismiss() }
            }
        }
    }

    // MARK: - Add Product

    private var addProductSection: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.App.textSecondary)
                TextField("Produkt hinzufügen…", text: $viewModel.searchText)
                    .foregroundStyle(Color.App.textPrimary)
                    .onChange(of: viewModel.searchText) { _, _ in
                        viewModel.searchProducts()
                    }
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        viewModel.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.App.textSecondary)
                    }
                }
            }
            .padding(AppSpacing.sm)
            .background(Color.App.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

            if !viewModel.searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.searchResults) { product in
                        searchResultRow(product)
                        if product.id != viewModel.searchResults.last?.id {
                            Divider().background(Color.white.opacity(0.06))
                        }
                    }
                }
                .glassCard(padding: AppSpacing.xs)
            }
        }
    }

    private func searchResultRow(_ product: Product) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(product.code)
                .font(Font.App.smallCaption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.App.accentPrimary)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xxs)
                .background(Color.App.accentPrimary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textPrimary)
                Text("Bestand: \(product.stock)")
                    .font(Font.App.smallCaption)
                    .foregroundStyle(product.isLowStock ? Color.App.categoryOrange : Color.App.textSecondary)
            }

            Spacer()

            Text(formatCurrency(product.price))
                .font(Font.App.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.App.textPrimary)

            Button {
                viewModel.add(product: product)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.App.accentPrimary)
            }
        }
        .padding(AppSpacing.xs)
    }

    // MARK: - Items

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "cart.fill")
                    .foregroundStyle(Color.App.accentPrimary)
                Text("Positionen (\(viewModel.items.count))")
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
                Spacer()
            }

            ForEach(viewModel.items) { item in
                editableItemRow(item)
                if item.id != viewModel.items.last?.id {
                    Divider().background(Color.white.opacity(0.06))
                }
            }
        }
        .glassCard()
    }

    private func editableItemRow(_ item: OrderItem) -> some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
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
                    Text("\(formatCurrency(item.unitPrice))/Stk")
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                }
                Spacer()
            }

            HStack {
                HStack(spacing: 0) {
                    Button {
                        viewModel.adjustQuantity(itemId: item.id, delta: -1)
                    } label: {
                        Image(systemName: item.quantity <= 1 ? "trash" : "minus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(item.quantity <= 1 ? Color.App.danger : Color.App.textPrimary)
                            .frame(width: 32, height: 32)
                    }

                    Text("\(item.quantity)")
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.textPrimary)
                        .frame(width: 36)

                    Button {
                        viewModel.adjustQuantity(itemId: item.id, delta: 1)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.App.textPrimary)
                            .frame(width: 32, height: 32)
                    }
                }
                .background(Color.App.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

                Spacer()

                Text(formatCurrency(item.unitPrice * Decimal(item.quantity)))
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
            }
        }
    }

    // MARK: - Discount

    private var discountSection: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundStyle(Color.App.accentSecondary)
                Text("Rabatt")
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
                Spacer()
            }

            HStack(spacing: AppSpacing.xs) {
                Text(appState.currencyCode)
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textSecondary)
                TextField("0,00", text: $viewModel.discountAmount)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
            }
            .padding(AppSpacing.sm)
            .background(Color.App.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

            TextField("Notiz (z.B. Stammkunde)", text: $viewModel.discountNote)
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textPrimary)
                .padding(AppSpacing.sm)
                .background(Color.App.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
        }
        .glassCard()
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                Text("Zwischensumme")
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textSecondary)
                Spacer()
                Text(formatCurrency(viewModel.subtotal))
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textPrimary)
            }

            if viewModel.discountDecimal > 0 {
                HStack {
                    Text("Rabatt")
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.danger)
                    Spacer()
                    Text("-\(formatCurrency(viewModel.discountDecimal))")
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.danger)
                }
            }

            Divider().background(Color.white.opacity(0.1))

            HStack {
                Text("Gesamt")
                    .font(Font.App.title2)
                    .foregroundStyle(Color.App.textPrimary)
                Spacer()
                Text(formatCurrency(viewModel.total))
                    .font(Font.App.title)
                    .foregroundStyle(Color.App.accentPrimary)
            }
        }
        .glassCard()
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.App.danger)
            Text(message)
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textPrimary)
            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(Color.App.danger.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = appState.currencyCode
        formatter.locale = Locale(identifier: appState.localeIdentifier)
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
