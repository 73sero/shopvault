import Foundation

struct DeliveryItem: Identifiable, Codable, Hashable {
    let id: String
    let deliveryId: String
    let productId: String
    let quantity: Int
    let unitCost: Decimal

    /// Transient fields populated from joins
    var productCode: String?
    var productName: String?
    var productSpec: String?

    init(
        id: String = UUID().uuidString,
        deliveryId: String,
        productId: String,
        quantity: Int,
        unitCost: Decimal,
        productCode: String? = nil,
        productName: String? = nil,
        productSpec: String? = nil
    ) {
        self.id = id
        self.deliveryId = deliveryId
        self.productId = productId
        self.quantity = quantity
        self.unitCost = unitCost
        self.productCode = productCode
        self.productName = productName
        self.productSpec = productSpec
    }
}

struct SupplierDelivery: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let totalCost: Decimal
    let notes: String?
    let deliveredAt: Date
    let createdAt: Date

    /// Transient fields populated from joins
    var items: [DeliveryItem]

    init(
        id: String = UUID().uuidString,
        userId: String,
        totalCost: Decimal,
        notes: String? = nil,
        deliveredAt: Date = Date(),
        createdAt: Date = Date(),
        items: [DeliveryItem] = []
    ) {
        self.id = id
        self.userId = userId
        self.totalCost = totalCost
        self.notes = notes
        self.deliveredAt = deliveredAt
        self.createdAt = createdAt
        self.items = items
    }
}

extension SupplierDelivery {
    /// Sample data for preview/testing
    static let sample = SupplierDelivery(
        userId: "user-1",
        totalCost: 150.00,
        notes: "Weekly restock",
        items: DeliveryItem.samples
    )

    static let samples = [
        SupplierDelivery(
            userId: "user-1",
            totalCost: 150.00,
            notes: "Weekly restock"
        ),
        SupplierDelivery(
            userId: "user-1",
            totalCost: 75.50,
            notes: "Emergency order",
            deliveredAt: Date().addingTimeInterval(-86400)
        )
    ]
}

extension DeliveryItem {
    /// Sample data for preview/testing
    static let sample = DeliveryItem(
        deliveryId: "del-1",
        productId: "prod-1",
        quantity: 20,
        unitCost: 5.00,
        productCode: "PRD-001",
        productName: "Shampoo",
        productSpec: "500ml"
    )

    static let samples = [
        DeliveryItem(
            deliveryId: "del-1",
            productId: "prod-1",
            quantity: 20,
            unitCost: 5.00,
            productCode: "PRD-001",
            productName: "Shampoo",
            productSpec: "500ml"
        ),
        DeliveryItem(
            deliveryId: "del-1",
            productId: "prod-2",
            quantity: 15,
            unitCost: 3.50,
            productCode: "PRD-002",
            productName: "Conditioner",
            productSpec: "250ml"
        )
    ]
}
