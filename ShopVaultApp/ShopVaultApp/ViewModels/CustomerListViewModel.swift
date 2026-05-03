import Foundation
import Combine

@MainActor
class CustomerListViewModel: ObservableObject {
    @Published var customers: [Customer] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showNewCustomer = false
    @Published var newName = ""
    @Published var newPhone = ""
    @Published var newEmail = ""
    @Published var newAddress = ""
    @Published var isSaving = false

    private let customerRepository: CustomerRepository

    init(customerRepository: CustomerRepository = CustomerRepository()) {
        self.customerRepository = customerRepository
    }

    // MARK: - Computed Properties

    var filteredCustomers: [Customer] {
        if searchText.isEmpty {
            return customers
        }
        let query = searchText.lowercased()
        return customers.filter { $0.name.lowercased().contains(query) }
    }

    // MARK: - Public Methods

    func loadCustomers(userId: String) {
        Task {
            do {
                isLoading = true
                customers = try await customerRepository.getCustomersForUser(userId)
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func deleteCustomer(_ customer: Customer) {
        Task {
            do {
                try await customerRepository.deleteCustomer(customer.id)
                customers.removeAll { $0.id == customer.id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func createCustomer(userId: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Name darf nicht leer sein"
            return
        }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                let customer = Customer(
                    userId: userId,
                    name: trimmedName,
                    phone: newPhone.isEmpty ? nil : newPhone.trimmingCharacters(in: .whitespaces),
                    email: newEmail.isEmpty ? nil : newEmail.trimmingCharacters(in: .whitespaces),
                    address: newAddress.isEmpty ? nil : newAddress.trimmingCharacters(in: .whitespaces)
                )

                try await customerRepository.createCustomer(customer)
                customers.append(customer)
                customers.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                // Reset form
                newName = ""
                newPhone = ""
                newEmail = ""
                newAddress = ""
                showNewCustomer = false
                isSaving = false
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}
