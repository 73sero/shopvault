import Foundation

struct Product: Identifiable, Codable, Hashable {
    let id: String
    let code: String
    let name: String
    let specification: String
    let price: Decimal
    let stock: Int
    let lowStockThreshold: Int
    let isFavorite: Bool
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    init(
        id: String = UUID().uuidString,
        code: String,
        name: String,
        specification: String = "",
        price: Decimal,
        stock: Int = 0,
        lowStockThreshold: Int = 3,
        isFavorite: Bool = false,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.specification = specification
        self.price = price
        self.stock = stock
        self.lowStockThreshold = lowStockThreshold
        self.isFavorite = isFavorite
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Whether stock is at or below the low stock threshold
    var isLowStock: Bool {
        stock <= lowStockThreshold
    }

    /// Whether the product is out of stock
    var isOutOfStock: Bool {
        stock <= 0
    }

    /// Price formatted in EUR
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: price as NSDecimalNumber) ?? "€0,00"
    }
}

extension Product {
    /// Sample data for preview/testing
    static let sample = Product(

        code: "PRD-001",
        name: "Sample Product",
        specification: "500ml",
        price: 12.50,
        stock: 10
    )

    static let samples = [
        Product(
    
            code: "PRD-001",
            name: "Shampoo",
            specification: "500ml",
            price: 12.50,
            stock: 10
        ),
        Product(
    
            code: "PRD-002",
            name: "Conditioner",
            specification: "250ml",
            price: 8.99,
            stock: 2
        ),
        Product(
    
            code: "PRD-003",
            name: "Hair Gel",
            specification: "100ml",
            price: 5.00,
            stock: 0
        )
    ]
}
