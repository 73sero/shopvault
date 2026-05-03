import Foundation
import Combine

@MainActor
class OrderDetailViewModel: ObservableObject {
    @Published var order: Order?
    @Published var isLoading = false
    @Published var isDeleting = false
    @Published var errorMessage: String?

    let orderId: String
    private let orderRepository: OrderRepository

    init(orderId: String, orderRepository: OrderRepository = OrderRepository()) {
        self.orderId = orderId
        self.orderRepository = orderRepository
    }

    func load() {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                order = try await orderRepository.getOrderById(orderId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func delete(completion: @escaping (Bool) -> Void) {
        isDeleting = true
        Task {
            defer { isDeleting = false }
            do {
                try await orderRepository.deleteOrder(orderId: orderId)
                NotificationCenter.default.post(name: .orderDidChange, object: nil)
                NotificationCenter.default.post(name: .incomeEntriesDidChange, object: nil)
                NotificationCenter.default.post(name: .stockDidChange, object: nil)
                completion(true)
            } catch {
                errorMessage = error.localizedDescription
                completion(false)
            }
        }
    }
}
