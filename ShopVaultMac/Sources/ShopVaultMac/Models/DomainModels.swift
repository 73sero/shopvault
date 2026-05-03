import Foundation

struct VaultProduct: Identifiable, Hashable {
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

    var isOutOfStock: Bool { stock <= 0 }
    var isLowStock: Bool { stock <= lowStockThreshold && !isOutOfStock }
}

struct VaultCustomer: Identifiable, Hashable {
    let id: String
    let userId: String
    let name: String
    let phone: String?
    let email: String?
    let address: String?
    let notes: String?
    let createdAt: Date
}

struct VaultOrderItem: Identifiable, Hashable {
    let id: String
    let orderId: String
    let productId: String
    let quantity: Int
    let unitPrice: Decimal
    let lineTotal: Decimal

    // Hydrated
    var productCode: String?
    var productName: String?
    var productSpec: String?
}

struct VaultOrder: Identifiable, Hashable {
    let id: String
    let userId: String
    let customerId: String
    let status: String
    let subtotal: Decimal
    let discountAmount: Decimal
    let discountNote: String?
    let total: Decimal
    let createdAt: Date

    // Hydrated
    var customerName: String?
    var items: [VaultOrderItem]
}

struct VaultIncomeEntry: Identifiable, Hashable {
    let id: String
    let userId: String
    let amount: Decimal
    let source: String
    let categoryId: String
    let date: Date
    let notes: String?
    let createdAt: Date

    // Hydrated
    var categoryName: String?
    var categoryColor: String?
}

struct VaultCategory: Identifiable, Hashable {
    let id: String
    let userId: String
    let name: String
    let color: String
    let isActive: Bool
}

struct VaultDelivery: Identifiable, Hashable {
    let id: String
    let userId: String
    let totalCost: Decimal
    let notes: String?
    let deliveredAt: Date

    // Hydrated
    var items: [VaultDeliveryItem]
}

struct VaultDeliveryItem: Identifiable, Hashable {
    let id: String
    let deliveryId: String
    let productId: String
    let quantity: Int
    let unitCost: Decimal

    // Hydrated
    var productCode: String?
    var productName: String?
}

// MARK: - Decoded Dataset

struct VaultDataset {
    let products: [VaultProduct]
    let customers: [VaultCustomer]
    let orders: [VaultOrder]
    let income: [VaultIncomeEntry]
    let categories: [VaultCategory]
    let deliveries: [VaultDelivery]
    let exportedAt: Date?
    let sourceFilename: String

    var productById: [String: VaultProduct] {
        Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
    }

    var customerById: [String: VaultCustomer] {
        Dictionary(uniqueKeysWithValues: customers.map { ($0.id, $0) })
    }

    var categoryById: [String: VaultCategory] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }
}

// MARK: - Decoder from raw [String: Any] rows

enum DatasetDecoder {
    static func decode(_ export: DecryptedExport) -> VaultDataset {
        let tables = export.payload.tables

        let products = (tables["products"] ?? []).compactMap(decodeProduct)
        let customers = (tables["customers"] ?? []).compactMap(decodeCustomer)
        let categories = (tables["categories"] ?? []).compactMap(decodeCategory)
        let orderItems = (tables["order_items"] ?? []).compactMap(decodeOrderItem)
        let incomes = (tables["income_entries"] ?? []).compactMap(decodeIncome)
        let deliveryItems = (tables["delivery_items"] ?? []).compactMap(decodeDeliveryItem)

        let productById = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        let customerById = Dictionary(uniqueKeysWithValues: customers.map { ($0.id, $0) })
        let categoryById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        let itemsByOrderId: [String: [VaultOrderItem]] = Dictionary(grouping: orderItems, by: \.orderId)
            .mapValues { items in
                items.map { item in
                    var hydrated = item
                    if let p = productById[item.productId] {
                        hydrated.productCode = p.code
                        hydrated.productName = p.name
                        hydrated.productSpec = p.specification
                    }
                    return hydrated
                }
            }

        let orders = (tables["orders"] ?? []).compactMap { row -> VaultOrder? in
            guard var o = decodeOrder(row) else { return nil }
            o.items = itemsByOrderId[o.id] ?? []
            o.customerName = customerById[o.customerId]?.name
            return o
        }

        let hydratedIncomes = incomes.map { entry -> VaultIncomeEntry in
            var hydrated = entry
            if let c = categoryById[entry.categoryId] {
                hydrated.categoryName = c.name
                hydrated.categoryColor = c.color
            }
            return hydrated
        }

        let deliveryItemsByDeliveryId: [String: [VaultDeliveryItem]] = Dictionary(grouping: deliveryItems, by: \.deliveryId)
            .mapValues { items in
                items.map { item in
                    var hydrated = item
                    if let p = productById[item.productId] {
                        hydrated.productCode = p.code
                        hydrated.productName = p.name
                    }
                    return hydrated
                }
            }

        let deliveries = (tables["supplier_deliveries"] ?? []).compactMap { row -> VaultDelivery? in
            guard var d = decodeDelivery(row) else { return nil }
            d.items = deliveryItemsByDeliveryId[d.id] ?? []
            return d
        }

        return VaultDataset(
            products: products,
            customers: customers,
            orders: orders.sorted { $0.createdAt > $1.createdAt },
            income: hydratedIncomes.sorted { $0.date > $1.date },
            categories: categories,
            deliveries: deliveries.sorted { $0.deliveredAt > $1.deliveredAt },
            exportedAt: parseISO(export.payload.exportedAt),
            sourceFilename: export.sourceURL.lastPathComponent
        )
    }

    // MARK: - Row decoders

    private static func decodeProduct(_ row: [String: Any]) -> VaultProduct? {
        guard let id = row["id"] as? String,
              let code = row["code"] as? String,
              let name = row["name"] as? String else { return nil }
        return VaultProduct(
            id: id,
            code: code,
            name: name,
            specification: (row["specification"] as? String) ?? "",
            price: parseDecimal(row["price"]),
            stock: parseInt(row["stock"]),
            lowStockThreshold: parseInt(row["low_stock_threshold"]),
            isFavorite: parseInt(row["is_favorite"]) == 1,
            isActive: parseInt(row["is_active"]) == 1,
            createdAt: parseISO(row["created_at"]) ?? Date()
        )
    }

    private static func decodeCustomer(_ row: [String: Any]) -> VaultCustomer? {
        guard let id = row["id"] as? String,
              let userId = row["user_id"] as? String,
              let name = row["name"] as? String else { return nil }
        return VaultCustomer(
            id: id, userId: userId, name: name,
            phone: row["phone"] as? String,
            email: row["email"] as? String,
            address: row["address"] as? String,
            notes: row["notes"] as? String,
            createdAt: parseISO(row["created_at"]) ?? Date()
        )
    }

    private static func decodeCategory(_ row: [String: Any]) -> VaultCategory? {
        guard let id = row["id"] as? String,
              let userId = row["user_id"] as? String,
              let name = row["name"] as? String else { return nil }
        return VaultCategory(
            id: id, userId: userId, name: name,
            color: (row["color"] as? String) ?? "#4CAF50",
            isActive: parseInt(row["is_active"]) == 1
        )
    }

    private static func decodeOrder(_ row: [String: Any]) -> VaultOrder? {
        guard let id = row["id"] as? String,
              let userId = row["user_id"] as? String,
              let customerId = row["customer_id"] as? String else { return nil }
        return VaultOrder(
            id: id, userId: userId, customerId: customerId,
            status: (row["status"] as? String) ?? "completed",
            subtotal: parseDecimal(row["subtotal"]),
            discountAmount: parseDecimal(row["discount_amount"]),
            discountNote: row["discount_note"] as? String,
            total: parseDecimal(row["total"]),
            createdAt: parseISO(row["created_at"]) ?? Date(),
            customerName: nil,
            items: []
        )
    }

    private static func decodeOrderItem(_ row: [String: Any]) -> VaultOrderItem? {
        guard let id = row["id"] as? String,
              let orderId = row["order_id"] as? String,
              let productId = row["product_id"] as? String else { return nil }
        return VaultOrderItem(
            id: id, orderId: orderId, productId: productId,
            quantity: parseInt(row["quantity"]),
            unitPrice: parseDecimal(row["unit_price"]),
            lineTotal: parseDecimal(row["line_total"])
        )
    }

    private static func decodeIncome(_ row: [String: Any]) -> VaultIncomeEntry? {
        guard let id = row["id"] as? String,
              let userId = row["user_id"] as? String,
              let source = row["source"] as? String,
              let categoryId = row["category_id"] as? String else { return nil }
        let dateStr = (row["date"] as? String) ?? ""
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return VaultIncomeEntry(
            id: id, userId: userId,
            amount: parseDecimal(row["amount"]),
            source: source,
            categoryId: categoryId,
            date: formatter.date(from: dateStr) ?? Date(),
            notes: row["notes"] as? String,
            createdAt: parseISO(row["created_at"]) ?? Date(),
            categoryName: nil, categoryColor: nil
        )
    }

    private static func decodeDelivery(_ row: [String: Any]) -> VaultDelivery? {
        guard let id = row["id"] as? String,
              let userId = row["user_id"] as? String else { return nil }
        let dateStr = (row["delivered_at"] as? String) ?? ""
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return VaultDelivery(
            id: id, userId: userId,
            totalCost: parseDecimal(row["total_cost"]),
            notes: row["notes"] as? String,
            deliveredAt: formatter.date(from: dateStr) ?? Date(),
            items: []
        )
    }

    private static func decodeDeliveryItem(_ row: [String: Any]) -> VaultDeliveryItem? {
        guard let id = row["id"] as? String,
              let deliveryId = row["delivery_id"] as? String,
              let productId = row["product_id"] as? String else { return nil }
        return VaultDeliveryItem(
            id: id, deliveryId: deliveryId, productId: productId,
            quantity: parseInt(row["quantity"]),
            unitCost: parseDecimal(row["unit_cost"])
        )
    }

    // MARK: - Primitive decoders

    private static func parseDecimal(_ value: Any?) -> Decimal {
        if let s = value as? String {
            return Decimal(string: s.replacingOccurrences(of: ",", with: ".")) ?? 0
        }
        if let n = value as? NSNumber { return Decimal(n.doubleValue) }
        if let d = value as? Double { return Decimal(d) }
        if let i = value as? Int { return Decimal(i) }
        return 0
    }

    private static func parseInt(_ value: Any?) -> Int {
        if let i = value as? Int { return i }
        if let i = value as? Int64 { return Int(i) }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String { return Int(s) ?? 0 }
        if let d = value as? Double { return Int(d) }
        return 0
    }

    private static func parseISO(_ value: Any?) -> Date? {
        guard let s = value as? String else { return nil }
        if let d = ISO8601DateFormatter().date(from: s) { return d }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: s)
    }
}
