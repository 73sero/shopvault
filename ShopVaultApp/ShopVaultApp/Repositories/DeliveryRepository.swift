import Foundation

final class DeliveryRepository: @unchecked Sendable {
    private let databaseManager: DatabaseManager

    nonisolated init(databaseManager: DatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }

    func createDelivery(_ delivery: SupplierDelivery) async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let iso8601 = ISO8601DateFormatter()

        try databaseManager.transaction {
            // 1. INSERT supplier_deliveries
            let insertDeliverySQL = """
            INSERT INTO supplier_deliveries (id, user_id, total_cost, notes, delivered_at, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """
            try self.databaseManager.execute(insertDeliverySQL, parameters: [
                delivery.id,
                delivery.userId,
                NSDecimalNumber(decimal: delivery.totalCost).stringValue,
                delivery.notes ?? NSNull(),
                dateFormatter.string(from: delivery.deliveredAt),
                iso8601.string(from: delivery.createdAt)
            ])

            // 2. For each item: INSERT delivery_items, UPDATE products SET stock = stock + quantity
            let insertItemSQL = """
            INSERT INTO delivery_items (id, delivery_id, product_id, quantity, unit_cost)
            VALUES (?, ?, ?, ?, ?)
            """
            let updateStockSQL = """
            UPDATE products SET stock = stock + ?, updated_at = ? WHERE id = ?
            """

            for item in delivery.items {
                try self.databaseManager.execute(insertItemSQL, parameters: [
                    item.id,
                    item.deliveryId,
                    item.productId,
                    item.quantity,
                    NSDecimalNumber(decimal: item.unitCost).stringValue
                ])

                try self.databaseManager.execute(updateStockSQL, parameters: [
                    item.quantity,
                    iso8601.string(from: Date()),
                    item.productId
                ])

                #if DEBUG
                if self.databaseManager.changesCount() == 0 {
                    print("⚠️ DeliveryRepository: Stock UPDATE affected 0 rows for productId=\(item.productId)")
                }
                #endif
            }
        }
    }

    func getDeliveriesForUser(_ userId: String) async throws -> [SupplierDelivery] {
        let sql = """
        SELECT * FROM supplier_deliveries WHERE user_id = ? ORDER BY delivered_at DESC
        """
        let results = try databaseManager.queryAsJSON(sql, parameters: [userId])

        return results.compactMap { rowToDelivery($0) }
    }

    func getDeliveryItems(deliveryId: String) async throws -> [DeliveryItem] {
        let sql = """
        SELECT di.*, p.code AS product_code, p.name AS product_name, p.specification AS product_spec
        FROM delivery_items di
        LEFT JOIN products p ON di.product_id = p.id
        WHERE di.delivery_id = ?
        """
        let results = try databaseManager.queryAsJSON(sql, parameters: [deliveryId])

        return results.compactMap { rowToDeliveryItem($0) }
    }

    // MARK: - Private Helpers

    private func rowToDelivery(_ row: [String: Any]) -> SupplierDelivery? {
        guard let id = row["id"] as? String,
              let userId = row["user_id"] as? String else {
            return nil
        }

        let totalCost = parseAmount(row["total_cost"])
        let notes = row["notes"] as? String
        let deliveredAt = parseDate(row["delivered_at"], format: "yyyy-MM-dd")
        let createdAt = parseISO8601Date(row["created_at"])

        return SupplierDelivery(
            id: id,
            userId: userId,
            totalCost: totalCost,
            notes: notes,
            deliveredAt: deliveredAt,
            createdAt: createdAt,
            items: []
        )
    }

    private func rowToDeliveryItem(_ row: [String: Any]) -> DeliveryItem? {
        guard let id = row["id"] as? String,
              let deliveryId = row["delivery_id"] as? String,
              let productId = row["product_id"] as? String else {
            return nil
        }

        let quantity = parseQuantity(row["quantity"])
        let unitCost = parseAmount(row["unit_cost"])
        let productCode = row["product_code"] as? String
        let productName = row["product_name"] as? String
        let productSpec = row["product_spec"] as? String

        return DeliveryItem(
            id: id,
            deliveryId: deliveryId,
            productId: productId,
            quantity: quantity,
            unitCost: unitCost,
            productCode: productCode,
            productName: productName,
            productSpec: productSpec
        )
    }

    private func parseDate(_ value: Any?, format: String) -> Date {
        if let dateString = value as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            return formatter.date(from: dateString) ?? Date()
        }
        return Date()
    }

    private func parseISO8601Date(_ value: Any?) -> Date {
        if let dateString = value as? String {
            return ISO8601DateFormatter().date(from: dateString) ?? Date()
        }
        return Date()
    }

    private func parseAmount(_ value: Any?) -> Decimal {
        if let stringValue = value as? String {
            return Decimal(string: stringValue.replacingOccurrences(of: ",", with: ".")) ?? 0
        }
        if let doubleValue = value as? Double {
            return Decimal(string: "\(doubleValue)") ?? Decimal(doubleValue)
        }
        if let intValue = value as? Int {
            return Decimal(intValue)
        }
        if let int64Value = value as? Int64 {
            return Decimal(Int(int64Value))
        }
        return 0
    }

    private func parseQuantity(_ value: Any?) -> Int {
        if let intValue = value as? Int {
            return intValue
        }
        if let int64Value = value as? Int64 {
            return Int(int64Value)
        }
        if let doubleValue = value as? Double {
            return Int(doubleValue)
        }
        if let stringValue = value as? String {
            return Int(stringValue) ?? 0
        }
        return 0
    }
}
