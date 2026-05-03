import SwiftUI

struct CustomerDetailView: View {
    @StateObject var viewModel: CustomerDetailViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showNewOrder = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var editName = ""
    @State private var editPhone = ""
    @State private var editEmail = ""
    @State private var editAddress = ""

    var body: some View {
        ZStack {
            Color.App.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    // Avatar + Name
                    VStack(spacing: AppSpacing.sm) {
                        CustomerInitialsAvatar(name: viewModel.customer.name, size: 80)
                            .shadow(color: Color.App.accentPrimary.opacity(0.3), radius: 16, y: 4)

                        Text(viewModel.customer.name)
                            .font(Font.App.title2)
                            .foregroundStyle(Color.App.textPrimary)

                        Text("Kunde seit \(AppFormatters.mediumDate(viewModel.customer.createdAt, localeIdentifier: appState.localeIdentifier))")
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.md)
                    .staggeredAppear(index: 0)

                    // Contact info
                    if viewModel.customer.phone != nil || viewModel.customer.address != nil || viewModel.customer.email != nil {
                        VStack(spacing: AppSpacing.sm) {
                            if let phone = viewModel.customer.phone {
                                ContactInfoRow(icon: "phone.fill", text: phone)
                            }
                            if let email = viewModel.customer.email {
                                ContactInfoRow(icon: "envelope.fill", text: email)
                            }
                            if let address = viewModel.customer.address {
                                ContactInfoRow(icon: "mappin.and.ellipse", text: address)
                            }
                        }
                        .glassCard()
                        .staggeredAppear(index: 1)
                    }

                    // Stat cards
                    HStack(spacing: AppSpacing.sm) {
                        StatCard(
                            title: "Gesamtumsatz",
                            value: AppFormatters.currency(viewModel.totalSpend, currencyCode: appState.currencyCode, localeIdentifier: appState.localeIdentifier),
                            valueColor: Color.App.accentPrimary
                        )

                        StatCard(
                            title: "Bestellungen",
                            value: "\(viewModel.orderCount)",
                            valueColor: Color.App.textPrimary
                        )
                    }
                    .staggeredAppear(index: 2)

                    // Order history
                    if !viewModel.orders.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Bestellverlauf")
                                .font(Font.App.headline)
                                .foregroundStyle(Color.App.textPrimary)
                                .padding(.horizontal, AppSpacing.xxs)

                            ForEach(viewModel.orders) { order in
                                OrderHistoryRow(
                                    order: order,
                                    currencyCode: appState.currencyCode,
                                    localeIdentifier: appState.localeIdentifier
                                )
                            }
                        }
                        .staggeredAppear(index: 3)
                    }

                    // New order button
                    GradientButton(
                        title: "Neue Bestellung für \(viewModel.customer.name)",
                        icon: "plus.circle.fill",
                        action: { showNewOrder = true }
                    )
                    .staggeredAppear(index: 4)

                    // Delete customer button
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "trash.fill")
                            Text("Kunde löschen")
                        }
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.danger)
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.md)
                        .background(Color.App.danger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(Color.App.danger.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .staggeredAppear(index: 5)
                }
                .padding(AppSpacing.md)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editName = viewModel.customer.name
                    editPhone = viewModel.customer.phone ?? ""
                    editEmail = viewModel.customer.email ?? ""
                    editAddress = viewModel.customer.address ?? ""
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(Color.App.accentPrimary)
                }
            }
        }
        .sheet(isPresented: $showNewOrder) {
            NavigationStack {
                NewOrderView(viewModel: {
                    let vm = NewOrderViewModel()
                    vm.selectedCustomer = viewModel.customer
                    return vm
                }())
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditCustomerSheet(
                name: $editName,
                phone: $editPhone,
                email: $editEmail,
                address: $editAddress,
                onSave: {
                    viewModel.updateCustomer(
                        name: editName.trimmingCharacters(in: .whitespaces),
                        phone: editPhone.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editPhone.trimmingCharacters(in: .whitespaces),
                        email: editEmail.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editEmail.trimmingCharacters(in: .whitespaces),
                        address: editAddress.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editAddress.trimmingCharacters(in: .whitespaces)
                    )
                    showEditSheet = false
                }
            )
        }
        .confirmationDialog(
            "Kunde löschen",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                Task {
                    do {
                        try await viewModel.deleteCustomer()
                        dismiss()
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Möchtest du \(viewModel.customer.name) wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.")
        }
        .onAppear {
            viewModel.loadData()
        }
    }
}

// MARK: - Edit Customer Sheet

private struct EditCustomerSheet: View {
    @Binding var name: String
    @Binding var phone: String
    @Binding var email: String
    @Binding var address: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.App.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        VStack(spacing: AppSpacing.md) {
                            FormField(label: "Name *", placeholder: "Kundenname", text: $name)
                            FormField(label: "Telefon", placeholder: "Telefonnummer", text: $phone)
                            FormField(label: "E-Mail", placeholder: "E-Mail-Adresse", text: $email)
                            FormField(label: "Adresse", placeholder: "Adresse", text: $address)
                        }
                        .glassCard()

                        GradientButton(
                            title: "Speichern",
                            icon: "checkmark.circle.fill",
                            action: onSave,
                            isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty
                        )
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle("Kunde bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Color.App.textSecondary)
                }
            }
        }
    }
}

// MARK: - Contact Info Row

private struct ContactInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.App.accentPrimary)
                .frame(width: 24)

            Text(text)
                .font(Font.App.body)
                .foregroundStyle(Color.App.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Text(title)
                .font(Font.App.smallCaption)
                .foregroundStyle(Color.App.textSecondary)

            Text(value)
                .font(Font.App.amountMedium)
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }
}

// MARK: - Order History Row

private struct OrderHistoryRow: View {
    let order: Order
    let currencyCode: String
    let localeIdentifier: String

    private var itemSummary: String {
        if order.items.isEmpty {
            return "Bestellung"
        }
        let names = order.items.compactMap { $0.productName }
        if names.isEmpty {
            return "\(order.items.count) Artikel"
        }
        return names.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(Color.App.accentPrimary)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(itemSummary)
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
                    .lineLimit(1)

                Text(AppFormatters.mediumDate(order.createdAt, localeIdentifier: localeIdentifier))
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
            }

            Spacer()

            Text(AppFormatters.currency(order.total, currencyCode: currencyCode, localeIdentifier: localeIdentifier))
                .font(Font.App.amountSmall)
                .foregroundStyle(Color.App.accentPrimary)
        }
        .glassCard(padding: AppSpacing.sm)
    }
}

#Preview("Customer Detail") {
    NavigationStack {
        CustomerDetailView(
            viewModel: CustomerDetailViewModel(
                customer: Customer.sample,
                customerRepository: CustomerRepository(),
                orderRepository: OrderRepository()
            )
        )
    }
    .environmentObject({
        let state = AppState()
        state.currencyCode = "EUR"
        state.localeIdentifier = "de_DE"
        return state
    }())
}
