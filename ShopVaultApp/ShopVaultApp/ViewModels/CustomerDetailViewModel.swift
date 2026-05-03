import Foundation
import Combine

@MainActor
class CustomerDetailViewModel: ObservableObject {
    @Published var customer: Customer
    @Published var orders: [Order] = []
    @Published var totalSpend: Decimal = 0
    @Published var orderCount: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let customerRepository: CustomerRepository
    private let orderRepository: OrderRepository

    init(
        customer: Customer,
        customerRepository: CustomerRepository,
        orderRepository: OrderRepository
    ) {
        self.customer = customer
        self.customerRepository = customerRepository
        self.orderRepository = orderRepository
    }

    // MARK: - Public Methods

    func loadData() {
        Task {
            do {
                isLoading = true
                orders = try await orderRepository.getOrdersForCustomer(customer.id)
                totalSpend = try await customerRepository.getCustomerTotalSpend(customer.id)
                orderCount = try await customerRepository.getCustomerOrderCount(customer.id)
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func updateCustomer(name: String, phone: String?, email: String?, address: String?) {
        Task {
            do {
                let updated = Customer(
                    id: customer.id,
                    userId: customer.userId,
                    name: name,
                    phone: phone,
                    email: email,
                    address: address,
                    notes: customer.notes,
                    createdAt: customer.createdAt
                )
                try await customerRepository.updateCustomer(updated)
                self.customer = updated
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteCustomer() async throws {
        try await customerRepository.deleteCustomer(customer.id)
    }
}
