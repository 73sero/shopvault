import SwiftUI

struct CustomerListView: View {
    @StateObject var viewModel: CustomerListViewModel
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false
    @State private var customerToDelete: Customer?

    var body: some View {
        ZStack {
            Color.App.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Kunden")
                        .font(Font.App.title)
                        .foregroundStyle(Color.App.textPrimary)
                    Text("\(viewModel.filteredCustomers.count) Kunden")
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.accentPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.md)

                // Search bar
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.App.textSecondary)
                    TextField("Kunden suchen", text: $viewModel.searchText)
                        .foregroundStyle(Color.App.textPrimary)
                }
                .padding(AppSpacing.sm)
                .background(Color.App.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.small).stroke(Color.white.opacity(0.05), lineWidth: 1))
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(Color.App.accentPrimary)
                    Spacer()
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
                    .frame(maxHeight: .infinity)
                } else if viewModel.filteredCustomers.isEmpty {
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "person.2")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.App.textSecondary.opacity(0.5))
                        Text("Keine Kunden")
                            .font(Font.App.headline)
                            .foregroundStyle(Color.App.textSecondary)
                        Text("Erstelle deinen ersten Kunden")
                            .font(Font.App.caption)
                            .foregroundStyle(Color.App.textSecondary.opacity(0.7))
                    }
                    .padding(AppSpacing.xxl)
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.filteredCustomers) { customer in
                            NavigationLink(value: customer) {
                                CustomerRow(customer: customer)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    customerToDelete = customer
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationDestination(for: Customer.self) { customer in
            CustomerDetailView(
                viewModel: CustomerDetailViewModel(
                    customer: customer,
                    customerRepository: CustomerRepository(),
                    orderRepository: OrderRepository()
                )
            )
            .environmentObject(appState)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                viewModel.showNewCustomer = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(LinearGradient.appAccent)
                    .clipShape(Circle())
                    .shadow(color: Color.App.accentPrimary.opacity(0.4), radius: 12, y: 4)
            }
            .padding(AppSpacing.lg)
        }
        .sheet(isPresented: $viewModel.showNewCustomer) {
            NewCustomerSheet(viewModel: viewModel)
                .environmentObject(appState)
        }
        .confirmationDialog(
            "Kunde löschen",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                if let customer = customerToDelete {
                    viewModel.deleteCustomer(customer)
                    customerToDelete = nil
                }
            }
            Button("Abbrechen", role: .cancel) {
                customerToDelete = nil
            }
        } message: {
            if let customer = customerToDelete {
                Text("Möchtest du \(customer.name) wirklich löschen?")
            }
        }
        .onAppear {
            if let userId = appState.currentUser?.id {
                viewModel.loadCustomers(userId: userId)
            }
        }
    }
}

// MARK: - Customer Row

struct CustomerRow: View {
    let customer: Customer

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            CustomerInitialsAvatar(name: customer.name, size: 44)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(customer.name)
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
                if let phone = customer.phone {
                    Text(phone)
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.App.textSecondary.opacity(0.5))
        }
        .glassCard(padding: AppSpacing.sm)
    }
}

// MARK: - Initials Avatar

struct CustomerInitialsAvatar: View {
    let name: String
    let size: CGFloat

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var backgroundColor: Color {
        let hash = abs(name.hashValue)
        let colors: [Color] = [
            Color.App.accentPrimary,
            Color.App.accentSecondary,
            Color.App.categoryBlue,
            Color.App.categoryPurple,
            Color.App.categoryOrange
        ]
        return colors[hash % colors.count]
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(backgroundColor.gradient)
            .clipShape(Circle())
    }
}

// MARK: - New Customer Sheet

struct NewCustomerSheet: View {
    @ObservedObject var viewModel: CustomerListViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.App.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        VStack(spacing: AppSpacing.md) {
                            FormField(label: "Name *", placeholder: "Kundenname", text: $viewModel.newName)
                            FormField(label: "Telefon", placeholder: "Telefonnummer", text: $viewModel.newPhone)
                            FormField(label: "E-Mail", placeholder: "E-Mail-Adresse", text: $viewModel.newEmail)
                            FormField(label: "Adresse", placeholder: "Adresse", text: $viewModel.newAddress)
                        }
                        .glassCard()

                        if let error = viewModel.errorMessage {
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

                        GradientButton(
                            title: "Kunde erstellen",
                            icon: "checkmark.circle.fill",
                            action: {
                                if let userId = appState.currentUser?.id {
                                    viewModel.createCustomer(userId: userId)
                                }
                            },
                            isDisabled: viewModel.newName.trimmingCharacters(in: .whitespaces).isEmpty,
                            isLoading: viewModel.isSaving
                        )
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle("Neuer Kunde")
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

#Preview("Customer List") {
    let appState: AppState = {
        let state = AppState()
        state.isAuthenticated = true
        state.currentUser = User.sample
        state.currencyCode = "EUR"
        state.localeIdentifier = "de_DE"
        return state
    }()

    return CustomerListView(viewModel: CustomerListViewModel())
        .environmentObject(appState)
}
