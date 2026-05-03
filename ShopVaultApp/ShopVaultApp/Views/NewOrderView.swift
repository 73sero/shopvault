import SwiftUI

struct NewOrderView: View {
    @StateObject var viewModel: NewOrderViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showCustomerPicker = false
    @State private var showDiscount = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            Color.App.bgPrimary.ignoresSafeArea()

            if viewModel.completedOrder != nil {
                OrderConfirmationView(viewModel: viewModel, dismiss: dismiss)
            } else {
                cartContent
            }
        }
        .navigationTitle("Neue Bestellung")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Schließen") { dismiss() }
                    .foregroundStyle(Color.App.textSecondary)
            }
        }
        .onAppear {
            if let userId = appState.currentUser?.id {
                viewModel.loadCustomers(userId: userId)
            }
        }
        .sheet(isPresented: $showCustomerPicker) {
            customerPickerSheet
        }
    }

    // MARK: - Cart Content

    private var cartContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                customerCard
                    .staggeredAppear(index: 0)

                productSearchSection
                    .staggeredAppear(index: 1)

                if !viewModel.cartItems.isEmpty {
                    cartSection
                        .staggeredAppear(index: 2)

                    discountSection
                        .staggeredAppear(index: 3)

                    summaryCard
                        .staggeredAppear(index: 4)

                    GradientButton(
                        title: "Bestellung abschließen",
                        icon: "checkmark.circle.fill",
                        action: {
                            if let userId = appState.currentUser?.id {
                                viewModel.checkout(userId: userId)
                            }
                        },
                        isDisabled: !viewModel.canCheckout,
                        isLoading: viewModel.isSaving
                    )
                    .staggeredAppear(index: 5)

                    Text("Bestand & Einnahmen werden automatisch aktualisiert")
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                        .multilineTextAlignment(.center)
                        .staggeredAppear(index: 6)
                }

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
                }
            }
            .padding(AppSpacing.md)
        }
    }

    // MARK: - Customer Card

    private var customerCard: some View {
        Button {
            showCustomerPicker = true
        } label: {
            HStack(spacing: AppSpacing.sm) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.App.accentPrimary.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text(customerInitials)
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.accentPrimary)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(viewModel.selectedCustomer?.name ?? "Kunde auswählen")
                        .font(Font.App.headline)
                        .foregroundStyle(viewModel.selectedCustomer != nil ? Color.App.textPrimary : Color.App.textSecondary)

                    if viewModel.selectedCustomer != nil {
                        Text("Kunde")
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.App.textSecondary)
            }
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private var customerInitials: String {
        guard let name = viewModel.selectedCustomer?.name else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
        }
        return String(name.prefix(2)).uppercased()
    }

    // MARK: - Customer Picker Sheet

    private var customerPickerSheet: some View {
        NavigationStack {
            ZStack {
                Color.App.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.xs) {
                        ForEach(viewModel.customers) { customer in
                            Button {
                                viewModel.selectedCustomer = customer
                                showCustomerPicker = false
                            } label: {
                                HStack(spacing: AppSpacing.sm) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.App.accentPrimary.opacity(0.15))
                                            .frame(width: 40, height: 40)
                                        Text(initials(for: customer.name))
                                            .font(Font.App.caption)
                                            .foregroundStyle(Color.App.accentPrimary)
                                    }

                                    Text(customer.name)
                                        .font(Font.App.body)
                                        .foregroundStyle(Color.App.textPrimary)

                                    Spacer()

                                    if viewModel.selectedCustomer?.id == customer.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.App.accentPrimary)
                                    }
                                }
                                .padding(AppSpacing.sm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle("Kunde auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") { showCustomerPicker = false }
                        .foregroundStyle(Color.App.accentPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Product Search

    private var productSearchSection: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.App.textSecondary)
                TextField("Produkt suchen...", text: $viewModel.searchText)
                    .foregroundStyle(Color.App.textPrimary)
                    .focused($isSearchFocused)
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
            // Product code badge
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
                HStack(spacing: AppSpacing.xxs) {
                    if !product.specification.isEmpty {
                        Text(product.specification)
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.textSecondary)
                    }
                    Text("Bestand: \(product.stock)")
                        .font(Font.App.smallCaption)
                        .foregroundStyle(product.isLowStock ? Color.App.categoryOrange : Color.App.textSecondary)
                }
            }

            Spacer()

            Text(product.formattedPrice)
                .font(Font.App.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.App.textPrimary)

            Button {
                viewModel.addToCart(product)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.App.accentPrimary)
            }
        }
        .padding(AppSpacing.xs)
    }

    // MARK: - Cart Section

    private var cartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "cart.fill")
                    .foregroundStyle(Color.App.accentPrimary)
                Text("Warenkorb (\(viewModel.cartItems.count) Positionen)")
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
                Spacer()
            }

            ForEach(viewModel.cartItems) { item in
                cartItemRow(item)
                if item.id != viewModel.cartItems.last?.id {
                    Divider().background(Color.white.opacity(0.06))
                }
            }
        }
        .glassCard()
    }

    private func cartItemRow(_ item: CartItem) -> some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                // Product code pill
                Text(item.product.code)
                    .font(Font.App.smallCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.App.accentPrimary)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.App.accentPrimary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.product.name)
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.textPrimary)
                    HStack(spacing: AppSpacing.xxs) {
                        if !item.product.specification.isEmpty {
                            Text(item.product.specification)
                                .font(Font.App.smallCaption)
                                .foregroundStyle(Color.App.textSecondary)
                        }
                        Text(item.product.formattedPrice + "/Stk")
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.textSecondary)
                    }
                }

                Spacer()
            }

            HStack {
                // Stepper
                HStack(spacing: 0) {
                    Button {
                        viewModel.updateQuantity(for: item.id, delta: -1)
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
                        viewModel.updateQuantity(for: item.id, delta: 1)
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

                Text(formatCurrency(item.lineTotal))
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
            }
        }
    }

    // MARK: - Discount Section

    private var discountSection: some View {
        VStack(spacing: AppSpacing.xs) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showDiscount.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(Color.App.accentSecondary)
                    Text("Rabatt")
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.textPrimary)
                    Spacer()
                    Image(systemName: showDiscount ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.App.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if showDiscount {
                VStack(spacing: AppSpacing.xs) {
                    HStack(spacing: AppSpacing.xs) {
                        Text("EUR")
                            .font(Font.App.caption)
                            .foregroundStyle(Color.App.textSecondary)
                        TextField("0,00", text: $viewModel.discountAmount)
                            .keyboardType(.decimalPad)
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassCard()
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
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

    // MARK: - Helpers

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
        }
        return String(name.prefix(2)).uppercased()
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value) \u{20AC}"
    }
}

// MARK: - Preview

#Preview("New Order") {
    let appState: AppState = {
        let state = AppState()
        state.isAuthenticated = true
        state.currentUser = User.sample
        return state
    }()

    return NewOrderView(viewModel: NewOrderViewModel())
        .environmentObject(appState)
}
