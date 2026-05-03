import Foundation
import Combine

@MainActor
class DeliveryListViewModel: ObservableObject {
    @Published var deliveries: [SupplierDelivery] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let deliveryRepository: DeliveryRepository

    init(deliveryRepository: DeliveryRepository = DeliveryRepository()) {
        self.deliveryRepository = deliveryRepository
    }

    var totalCost: Decimal {
        deliveries.reduce(Decimal.zero) { $0 + $1.totalCost }
    }

    func load(userId: String) {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                var loaded = try await deliveryRepository.getDeliveriesForUser(userId)
                for i in 0..<loaded.count {
                    loaded[i].items = try await deliveryRepository.getDeliveryItems(deliveryId: loaded[i].id)
                }
                deliveries = loaded
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func delete(deliveryId: String) {
        Task {
            do {
                try await deliveryRepository.deleteDelivery(deliveryId: deliveryId)
                deliveries.removeAll { $0.id == deliveryId }
                NotificationCenter.default.post(name: .deliveryDidChange, object: nil)
                NotificationCenter.default.post(name: .stockDidChange, object: nil)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
