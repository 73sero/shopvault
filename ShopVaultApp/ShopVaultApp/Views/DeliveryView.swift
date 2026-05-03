import SwiftUI

struct DeliveryView: View {
    @StateObject var viewModel: DeliveryViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @FocusState private var focusedField: DeliveryField?

    private enum DeliveryField {
        case search, cost, notes
    }

    var body: some View {
        ZStack {
            Color.App.bgPrimary.ignoresSafeArea()

            if viewModel.isComplete {
                successView
            } else {
                formView
            }
        }
        .navigationTitle("Lieferung erfassen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Fertig") { dismiss() }
                    .foregroundStyle(Color.App.textSecondary)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { focusedField = nil }
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                // Product search
                productSearchSection
                    .staggeredAppear(index: 0)

                // Added items
                if !viewModel.items.isEmpty {
                    addedItemsSection
                        .staggeredAppear(index: 1)
                }

                // Cost, date, notes
                deliveryDetailsSection
                    .staggeredAppear(index: 2)

                // Summary
                if !viewModel.items.isEmpty {
                    summarySection
                        .staggeredAppear(index: 3)
                }

                // Save button
                GradientButton(
                    title: "Lieferung erfassen",
                    icon: "shippingbox.fill",
                    action: {
                        if let userId = appState.currentUser?.id {
                            viewModel.saveDelivery(userId: userId)
                        }
                    },
                    isDisabled: viewModel.items.isEmpty,
                    isLoading: viewModel.isSaving
                )
                .staggeredAppear(index: 4)
            }
            .padding(AppSpacing.md)
        }
        .safeAreaInset(edge: .bottom) {
            if let error = viewModel.saveError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.App.danger)
                    Text(error)
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.textPrimary)
                    Spacer()
                }
                .padding(AppSpacing.sm)
                .background(Color.App.danger.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.xs)
            }
        }
    }

    // MARK: - Product Search Section

    private var productSearchSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Produkt suchen")
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textSecondary)

            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.App.textSecondary)
                TextField("Code oder Name…", text: $viewModel.searchText)
                    .foregroundStyle(Color.App.textPrimary)
                    .focused($focusedField, equals: .search)
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

            // Search results dropdown
            if !viewModel.searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.searchResults) { product in
                        HStack(spacing: AppSpacing.sm) {
                            Text(product.code)
                                .font(Font.App.smallCaption)
                                .foregroundStyle(Color.App.accentPrimary)
                                .padding(.horizontal, AppSpacing.xs)
                                .padding(.vertical, 2)
                                .background(Color.App.accentPrimary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(product.name)
                                    .font(Font.App.caption)
                                    .foregroundStyle(Color.App.textPrimary)

                                if !product.specification.isEmpty {
                                    Text(product.specification)
                                        .font(Font.App.smallCaption)
                                        .foregroundStyle(Color.App.textSecondary)
                                }
                            }

                            Spacer()

                            Button {
                                viewModel.addItem(product)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.App.accentPrimary)
                            }
                        }
                        .padding(.vertical, AppSpacing.xs)
                        .padding(.horizontal, AppSpacing.sm)

                        if product.id != viewModel.searchResults.last?.id {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
                .background(Color.App.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.small)
                        .stroke(Color.App.accentPrimary.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .glassCard()
    }

    // MARK: - Added Items Section

    private var addedItemsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Artikel")
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textSecondary)

            ForEach(viewModel.items) { item in
                HStack(spacing: AppSpacing.sm) {
                    Text(item.product.code)
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.accentPrimary)
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.App.accentPrimary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text(item.product.name)
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    // Quantity stepper
                    HStack(spacing: AppSpacing.xs) {
                        Button {
                            viewModel.updateQuantity(for: item.id, delta: -1)
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.App.textSecondary)
                        }

                        Text("\(item.quantity)")
                            .font(Font.App.headline)
                            .foregroundStyle(Color.App.textPrimary)
                            .frame(minWidth: 24, alignment: .center)

                        Button {
                            viewModel.updateQuantity(for: item.id, delta: 1)
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.App.accentPrimary)
                        }
                    }
                }
                .padding(.vertical, AppSpacing.xxs)
            }
        }
        .glassCard()
    }

    // MARK: - Delivery Details Section

    private var deliveryDetailsSection: some View {
        VStack(spacing: AppSpacing.md) {
            // Total cost
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Gesamtkosten der Lieferung")
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textSecondary)

                HStack(spacing: AppSpacing.xs) {
                    Text("€")
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.textSecondary)
                    TextField("0,00", text: $viewModel.totalCost)
                        .keyboardType(.decimalPad)
                        .font(Font.App.amountMedium)
                        .foregroundStyle(Color.App.accentPrimary)
                        .focused($focusedField, equals: .cost)
                }
                .padding(AppSpacing.sm)
                .background(Color.App.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
            }

            // Delivery date
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Lieferdatum")
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textSecondary)

                DatePicker("Datum wählen", selection: $viewModel.deliveryDate, displayedComponents: .date)
                    .tint(Color.App.accentPrimary)
                    .foregroundStyle(Color.App.textPrimary)
            }

            // Notes
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Notizen (optional)")
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textSecondary)

                TextEditor(text: $viewModel.notes)
                    .frame(height: 80)
                    .padding(AppSpacing.xs)
                    .background(Color.App.bgTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                    .foregroundStyle(Color.App.textPrimary)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .notes)
            }
        }
        .glassCard()
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        HStack(spacing: AppSpacing.md) {
            SummaryPill(icon: "shippingbox", label: "Produkte", value: "\(viewModel.items.count)")
            SummaryPill(icon: "testtube.2", label: "Vials", value: "\(totalVials)")
            SummaryPill(icon: "eurosign", label: "EK", value: formattedCost)
        }
        .glassCard()
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.App.accentPrimary)

            Text("Lieferung erfasst!")
                .font(Font.App.title2)
                .foregroundStyle(Color.App.textPrimary)

            Text("\(viewModel.items.count) Produkte, \(totalVials) Vials")
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textSecondary)

            Spacer()

            GradientButton(
                title: "Fertig",
                icon: "checkmark",
                action: { dismiss() }
            )
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.lg)
        }
    }

    // MARK: - Helpers

    private var totalVials: Int {
        viewModel.items.reduce(0) { $0 + $1.quantity }
    }

    private var formattedCost: String {
        let normalized = viewModel.totalCost.replacingOccurrences(of: ",", with: ".")
        guard let value = Decimal(string: normalized), value > 0 else { return "–" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: value as NSDecimalNumber) ?? "–"
    }
}

// MARK: - Summary Pill

private struct SummaryPill: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: AppSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.App.accentPrimary)
            Text(value)
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textPrimary)
            Text(label)
                .font(Font.App.smallCaption)
                .foregroundStyle(Color.App.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Delivery") {
    let appState: AppState = {
        let state = AppState()
        state.isAuthenticated = true
        state.currentUser = User.sample
        return state
    }()

    return DeliveryView(viewModel: DeliveryViewModel())
        .environmentObject(appState)
}
