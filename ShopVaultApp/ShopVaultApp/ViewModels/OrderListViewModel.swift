import Foundation
import Combine

@MainActor
class OrderListViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let orderRepository: OrderRepository

    init(orderRepository: OrderRepository = OrderRepository()) {
        self.orderRepository = orderRepository
    }

    // MARK: - Computed Properties

    var filteredOrders: [Order] {
        if searchText.isEmpty {
            return orders
        }
        let query = searchText.lowercased()
        return orders.filter {
            ($0.customerName ?? "").lowercased().contains(query)
        }
    }

    // MARK: - Public Methods

    func loadOrders(userId: String) {
        Task {
            do {
                isLoading = true
                var loadedOrders = try await orderRepository.getOrdersForUser(userId)

                // Load items for each order
                for i in 0..<loadedOrders.count {
                    loadedOrders[i].items = try await orderRepository.getOrderItems(orderId: loadedOrders[i].id)
                }

                orders = loadedOrders
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
