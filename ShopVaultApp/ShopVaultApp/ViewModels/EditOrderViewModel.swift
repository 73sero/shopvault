import Foundation
import Combine

@MainActor
class EditOrderViewModel: ObservableObject {
    @Published var items: [OrderItem]
    @Published var discountAmount: String
    @Published var discountNote: String
    @Published var searchText: String = ""
    @Published var searchResults: [Product] = []
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var didSave = false

    let orderId: String
    let customerName: String
    private let orderRepository: OrderRepository
    private let productRepository: ProductRepository

    init(
        order: Order,
        orderRepository: OrderRepository = OrderRepository(),
        productRepository: ProductRepository = ProductRepository()
    ) {
        self.orderId = order.id
        self.customerName = order.customerName ?? ""
        self.items = order.items
        let discountStr = NSDecimalNumber(decimal: order.discountAmount).stringValue
        self.discountAmount = order.discountAmount > 0 ? discountStr : ""
        self.discountNote = order.discountNote ?? ""
        self.orderRepository = orderRepository
        self.productRepository = productRepository
    }

    var subtotal: Decimal {
        items.reduce(Decimal.zero) { $0 + ($1.unitPrice * Decimal($1.quantity)) }
    }

    var discountDecimal: Decimal {
        guard !discountAmount.isEmpty else { return 0 }
        let normalized = discountAmount.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized) ?? 0
    }

    var total: Decimal {
        max(subtotal - discountDecimal, 0)
    }

    var canSave: Bool {
        !items.isEmpty && !isSaving
    }

    func adjustQuantity(itemId: String, delta: Int) {
        guard let idx = items.firstIndex(where: { $0.id == itemId }) else { return }
        let newQty = items[idx].quantity + delta
        if newQty <= 0 {
            items.remove(at: idx)
        } else {
            let item = items[idx]
            items[idx] = OrderItem(
                id: item.id,
                orderId: item.orderId,
                productId: item.productId,
                quantity: newQty,
                unitPrice: item.unitPrice,
                productCode: item.productCode,
                productName: item.productName,
                productSpec: item.productSpec
            )
        }
    }

    func remove(itemId: String) {
        items.removeAll { $0.id == itemId }
    }

    func searchProducts() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        Task {
            do {
                searchResults = try await productRepository.searchProducts(query: searchText)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func add(product: Product) {
        if let idx = items.firstIndex(where: { $0.productId == product.id }) {
            adjustQuantity(itemId: items[idx].id, delta: 1)
        } else {
            items.append(OrderItem(
                orderId: orderId,
                productId: product.id,
                quantity: 1,
                unitPrice: product.price,
                productCode: product.code,
                productName: product.name,
                productSpec: product.specification
            ))
        }
        searchText = ""
        searchResults = []
    }

    func save() {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                let trimmedNote = discountNote.trimmingCharacters(in: .whitespaces)
                _ = try await orderRepository.updateOrder(
                    orderId: orderId,
                    items: items,
                    discountAmount: discountDecimal,
                    discountNote: trimmedNote.isEmpty ? nil : trimmedNote
                )
                NotificationCenter.default.post(name: .orderDidChange, object: nil)
                NotificationCenter.default.post(name: .incomeEntriesDidChange, object: nil)
                NotificationCenter.default.post(name: .stockDidChange, object: nil)
                didSave = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
