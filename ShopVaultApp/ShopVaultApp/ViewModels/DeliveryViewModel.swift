import Foundation
import Combine

struct DeliveryCartItem: Identifiable, Hashable {
    let id: String
    let product: Product
    var quantity: Int

    init(product: Product, quantity: Int = 1) {
        self.id = UUID().uuidString
        self.product = product
        self.quantity = quantity
    }
}

@MainActor
class DeliveryViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [Product] = []
    @Published var items: [DeliveryCartItem] = []
    @Published var totalCost: String = ""
    @Published var notes: String = ""
    @Published var deliveryDate = Date()
    @Published var isSaving = false
    @Published var saveError: String?
    @Published var isComplete = false

    private let productRepository: ProductRepository
    private let deliveryRepository: DeliveryRepository

    init(
        productRepository: ProductRepository = ProductRepository(),
        deliveryRepository: DeliveryRepository = DeliveryRepository()
    ) {
        self.productRepository = productRepository
        self.deliveryRepository = deliveryRepository
    }

    // MARK: - Public Methods

    func searchProducts() {
        guard searchText.count >= 1 else {
            searchResults = []
            return
        }

        Task {
            do {
                searchResults = try await productRepository.searchProducts(query: searchText)
            } catch {
                saveError = error.localizedDescription
            }
        }
    }

    func addItem(_ product: Product) {
        if let index = items.firstIndex(where: { $0.product.id == product.id }) {
            items[index].quantity += 1
        } else {
            items.append(DeliveryCartItem(product: product))
        }

        searchText = ""
        searchResults = []
    }

    func updateQuantity(for itemId: String, delta: Int) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        let newQuantity = items[index].quantity + delta
        if newQuantity <= 0 {
            items.remove(at: index)
        } else {
            items[index].quantity = newQuantity
        }
    }

    func saveDelivery(userId: String) {
        guard !items.isEmpty else {
            saveError = "Keine Artikel hinzugefügt"
            return
        }

        isSaving = true
        saveError = nil

        Task {
            do {
                let totalCostDecimal: Decimal
                if totalCost.isEmpty {
                    totalCostDecimal = 0
                } else {
                    let normalized = totalCost.replacingOccurrences(of: ",", with: ".")
                    totalCostDecimal = Decimal(string: normalized) ?? 0
                }

                let totalQuantity = items.reduce(0) { $0 + $1.quantity }
                let deliveryId = UUID().uuidString

                let deliveryItems = items.map { item in
                    let unitCost: Decimal
                    if totalQuantity > 0 && totalCostDecimal > 0 {
                        unitCost = totalCostDecimal / Decimal(totalQuantity)
                    } else {
                        unitCost = 0
                    }

                    return DeliveryItem(
                        deliveryId: deliveryId,
                        productId: item.product.id,
                        quantity: item.quantity,
                        unitCost: unitCost,
                        productCode: item.product.code,
                        productName: item.product.name,
                        productSpec: item.product.specification
                    )
                }

                let delivery = SupplierDelivery(
                    id: deliveryId,
                    userId: userId,
                    totalCost: totalCostDecimal,
                    notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces),
                    deliveredAt: deliveryDate,
                    items: deliveryItems
                )

                try await deliveryRepository.createDelivery(delivery)

                NotificationCenter.default.post(name: .deliveryDidComplete, object: nil)
                NotificationCenter.default.post(name: .stockDidChange, object: nil)

                isComplete = true
                isSaving = false
            } catch {
                saveError = error.localizedDescription
                isSaving = false
            }
        }
    }
}
