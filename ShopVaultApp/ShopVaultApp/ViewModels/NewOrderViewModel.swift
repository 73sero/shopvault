import Foundation
import Combine

struct CartItem: Identifiable, Hashable {
    let id: String
    let product: Product
    var quantity: Int

    init(product: Product, quantity: Int = 1) {
        self.id = UUID().uuidString
        self.product = product
        self.quantity = quantity
    }

    var lineTotal: Decimal {
        product.price * Decimal(quantity)
    }
}

@MainActor
class NewOrderViewModel: ObservableObject {
    @Published var selectedCustomer: Customer?
    @Published var customers: [Customer] = []
    @Published var searchText = ""
    @Published var searchResults: [Product] = []
    @Published var cartItems: [CartItem] = []
    @Published var discountAmount: String = ""
    @Published var discountNote: String = ""
    @Published var isSaving = false
    @Published var saveError: String?
    @Published var completedOrder: Order?
    @Published var lowStockWarnings: [Product] = []

    private let customerRepository: CustomerRepository
    private let productRepository: ProductRepository
    private let orderRepository: OrderRepository
    private let categoryRepository: CategoryRepository

    init(
        customerRepository: CustomerRepository = CustomerRepository(),
        productRepository: ProductRepository = ProductRepository(),
        orderRepository: OrderRepository = OrderRepository(),
        categoryRepository: CategoryRepository = CategoryRepository()
    ) {
        self.customerRepository = customerRepository
        self.productRepository = productRepository
        self.orderRepository = orderRepository
        self.categoryRepository = categoryRepository
    }

    // MARK: - Computed Properties

    var subtotal: Decimal {
        cartItems.reduce(Decimal.zero) { $0 + $1.lineTotal }
    }

    var discountDecimal: Decimal {
        guard !discountAmount.isEmpty else { return 0 }
        let normalized = discountAmount.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized) ?? 0
    }

    var total: Decimal {
        max(subtotal - discountDecimal, 0)
    }

    var totalItems: Int {
        cartItems.reduce(0) { $0 + $1.quantity }
    }

    var canCheckout: Bool {
        selectedCustomer != nil && !cartItems.isEmpty && !isSaving
    }

    // MARK: - Public Methods

    func loadCustomers(userId: String) {
        Task {
            do {
                customers = try await customerRepository.getCustomersForUser(userId)
            } catch {
                saveError = error.localizedDescription
            }
        }
    }

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

    func addToCart(_ product: Product) {
        if let index = cartItems.firstIndex(where: { $0.product.id == product.id }) {
            cartItems[index].quantity += 1
        } else {
            cartItems.append(CartItem(product: product))
        }

        // Check low stock warning
        let totalInCart = cartItems.first(where: { $0.product.id == product.id })?.quantity ?? 0
        if totalInCart >= product.stock {
            if !lowStockWarnings.contains(where: { $0.id == product.id }) {
                lowStockWarnings.append(product)
            }
        }

        searchText = ""
        searchResults = []
    }

    func updateQuantity(for itemId: String, delta: Int) {
        guard let index = cartItems.firstIndex(where: { $0.id == itemId }) else { return }
        let newQuantity = cartItems[index].quantity + delta
        if newQuantity <= 0 {
            cartItems.remove(at: index)
        } else {
            cartItems[index].quantity = newQuantity
        }
    }

    func removeItem(_ itemId: String) {
        cartItems.removeAll { $0.id == itemId }
    }

    func checkout(userId: String) {
        guard let customer = selectedCustomer else {
            saveError = "Bitte wähle einen Kunden"
            return
        }
        guard !cartItems.isEmpty else {
            saveError = "Warenkorb ist leer"
            return
        }

        isSaving = true
        saveError = nil

        Task {
            do {
                let salesCategoryId = try await categoryRepository.ensureSalesCategory(for: userId)

                let orderId = UUID().uuidString
                let orderItems = cartItems.map { cartItem in
                    OrderItem(
                        orderId: orderId,
                        productId: cartItem.product.id,
                        quantity: cartItem.quantity,
                        unitPrice: cartItem.product.price,
                        productCode: cartItem.product.code,
                        productName: cartItem.product.name,
                        productSpec: cartItem.product.specification
                    )
                }

                let order = Order(
                    id: orderId,
                    userId: userId,
                    customerId: customer.id,
                    subtotal: subtotal,
                    discountAmount: discountDecimal,
                    discountNote: discountNote.isEmpty ? nil : discountNote.trimmingCharacters(in: .whitespaces),
                    total: total,
                    items: orderItems,
                    customerName: customer.name
                )

                let created = try await orderRepository.createOrder(order, salesCategoryId: salesCategoryId)
                completedOrder = created

                NotificationCenter.default.post(name: .orderDidComplete, object: nil)
                NotificationCenter.default.post(name: .incomeEntriesDidChange, object: nil)
                NotificationCenter.default.post(name: .stockDidChange, object: nil)

                isSaving = false
            } catch {
                saveError = error.localizedDescription
                isSaving = false
            }
        }
    }

    func reset() {
        selectedCustomer = nil
        searchText = ""
        searchResults = []
        cartItems = []
        discountAmount = ""
        discountNote = ""
        isSaving = false
        saveError = nil
        completedOrder = nil
        lowStockWarnings = []
    }
}
