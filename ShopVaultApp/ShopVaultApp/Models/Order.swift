import Foundation

struct OrderItem: Identifiable, Codable, Hashable {
    let id: String
    let orderId: String
    let productId: String
    let quantity: Int
    let unitPrice: Decimal
    let lineTotal: Decimal

    /// Transient fields populated from joins
    var productCode: String?
    var productName: String?
    var productSpec: String?

    init(
        id: String = UUID().uuidString,
        orderId: String,
        productId: String,
        quantity: Int,
        unitPrice: Decimal,
        lineTotal: Decimal? = nil,
        productCode: String? = nil,
        productName: String? = nil,
        productSpec: String? = nil
    ) {
        self.id = id
        self.orderId = orderId
        self.productId = productId
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.lineTotal = lineTotal ?? (unitPrice * Decimal(quantity))
        self.productCode = productCode
        self.productName = productName
        self.productSpec = productSpec
    }
}

struct Order: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let customerId: String
    let status: String
    let subtotal: Decimal
    let discountAmount: Decimal
    let discountNote: String?
    let total: Decimal
    let incomeEntryId: String?
    let createdAt: Date
    let updatedAt: Date

    /// Transient fields populated from joins
    var items: [OrderItem]
    var customerName: String?

    init(
        id: String = UUID().uuidString,
        userId: String,
        customerId: String,
        status: String = "completed",
        subtotal: Decimal,
        discountAmount: Decimal = 0,
        discountNote: String? = nil,
        total: Decimal,
        incomeEntryId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        items: [OrderItem] = [],
        customerName: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.customerId = customerId
        self.status = status
        self.subtotal = subtotal
        self.discountAmount = discountAmount
        self.discountNote = discountNote
        self.total = total
        self.incomeEntryId = incomeEntryId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.items = items
        self.customerName = customerName
    }
}

extension Order {
    /// Sample data for preview/testing
    static let sample = Order(
        userId: "user-1",
        customerId: "cust-1",
        subtotal: 25.00,
        total: 25.00,
        items: OrderItem.samples,
        customerName: "John Doe"
    )

    static let samples = [
        Order(
            userId: "user-1",
            customerId: "cust-1",
            subtotal: 25.00,
            total: 25.00,
            customerName: "John Doe"
        ),
        Order(
            userId: "user-1",
            customerId: "cust-2",
            subtotal: 50.00,
            discountAmount: 5.00,
            discountNote: "Loyal customer",
            total: 45.00,
            customerName: "Jane Smith"
        )
    ]
}

extension OrderItem {
    /// Sample data for preview/testing
    static let sample = OrderItem(
        orderId: "order-1",
        productId: "prod-1",
        quantity: 2,
        unitPrice: 12.50,
        productCode: "PRD-001",
        productName: "Shampoo",
        productSpec: "500ml"
    )

    static let samples = [
        OrderItem(
            orderId: "order-1",
            productId: "prod-1",
            quantity: 2,
            unitPrice: 12.50,
            productCode: "PRD-001",
            productName: "Shampoo",
            productSpec: "500ml"
        ),
        OrderItem(
            orderId: "order-1",
            productId: "prod-2",
            quantity: 1,
            unitPrice: 8.99,
            productCode: "PRD-002",
            productName: "Conditioner",
            productSpec: "250ml"
        )
    ]
}
