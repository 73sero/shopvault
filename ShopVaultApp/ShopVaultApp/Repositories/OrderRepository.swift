import Foundation

enum OrderError: LocalizedError {
    case insufficientStock(productId: String, requested: Int, available: Int)
    case orderNotFound
    case customerNotFound
    case emptyOrder

    var errorDescription: String? {
        switch self {
        case .insufficientStock(let productId, let requested, let available):
            return "Insufficient stock for product \(productId): requested \(requested), available \(available)"
        case .orderNotFound:
            return "Order not found"
        case .customerNotFound:
            return "Customer not found"
        case .emptyOrder:
            return "Order must contain at least one item"
        }
    }
}

final class OrderRepository: @unchecked Sendable {
    private let databaseManager: DatabaseManager

    nonisolated init(databaseManager: DatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }

    // MARK: - Create Order (Transactional)

    func createOrder(_ order: Order, salesCategoryId: String) async throws -> Order {
        // Resolve customer name for the income entry
        let customerRows = try databaseManager.queryAsJSON(
            "SELECT name FROM customers WHERE id = ?",
            parameters: [order.customerId]
        )
        guard let customerRow = customerRows.first,
              let customerName = customerRow["name"] as? String else {
            throw OrderError.customerNotFound
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let incomeEntryId = UUID().uuidString
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())

        var createdOrder = order

        try databaseManager.transaction {
            // Defer FK checks so we can insert order with income_entry_id before the income entry exists
            try databaseManager.execute("PRAGMA defer_foreign_keys = ON")

            // 1. INSERT order
            let orderSQL = """
            INSERT INTO orders (id, user_id, customer_id, status, subtotal, discount_amount, discount_note, total, income_entry_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            try databaseManager.execute(orderSQL, parameters: [
                order.id,
                order.userId,
                order.customerId,
                order.status,
                NSDecimalNumber(decimal: order.subtotal).stringValue,
                NSDecimalNumber(decimal: order.discountAmount).stringValue,
                order.discountNote ?? NSNull(),
                NSDecimalNumber(decimal: order.total).stringValue,
                incomeEntryId,
                now,
                now
            ])

            // 2. INSERT order_items and UPDATE product stock
            for item in order.items {
                let itemSQL = """
                INSERT INTO order_items (id, order_id, product_id, quantity, unit_price, line_total)
                VALUES (?, ?, ?, ?, ?, ?)
                """
                try databaseManager.execute(itemSQL, parameters: [
                    item.id,
                    order.id,
                    item.productId,
                    item.quantity,
                    NSDecimalNumber(decimal: item.unitPrice).stringValue,
                    NSDecimalNumber(decimal: item.lineTotal).stringValue
                ])

                // Decrement stock atomically with guard
                let stockSQL = """
                UPDATE products SET stock = stock - ?, updated_at = ?
                WHERE id = ? AND stock >= ?
                """
                try databaseManager.execute(stockSQL, parameters: [
                    item.quantity,
                    now,
                    item.productId,
                    item.quantity
                ])

                // Verify the UPDATE actually affected a row (stock was sufficient)
                if databaseManager.changesCount() == 0 {
                    // Look up actual current stock for the error message
                    let checkSQL = "SELECT stock FROM products WHERE id = ?"
                    let stockRows = try databaseManager.queryAsJSON(checkSQL, parameters: [item.productId])
                    let currentStock = stockRows.first.map { parseIntValue($0["stock"]) } ?? 0
                    throw OrderError.insufficientStock(
                        productId: item.productId,
                        requested: item.quantity,
                        available: currentStock
                    )
                }
            }

            // 3. Build item summary string (e.g. "2× SM10, 1× TR15")
            let summaryParts: [String] = order.items.compactMap { item in
                let code = item.productCode ?? item.productId
                return "\(item.quantity)× \(code)"
            }

            // If we don't have product codes, look them up
            var itemSummary: String
            if order.items.allSatisfy({ $0.productCode != nil }) {
                itemSummary = summaryParts.joined(separator: ", ")
            } else {
                var parts: [String] = []
                for item in order.items {
                    if let code = item.productCode {
                        parts.append("\(item.quantity)× \(code)")
                    } else {
                        let prodRows = try databaseManager.queryAsJSON(
                            "SELECT code FROM products WHERE id = ?",
                            parameters: [item.productId]
                        )
                        let code = (prodRows.first?["code"] as? String) ?? item.productId
                        parts.append("\(item.quantity)× \(code)")
                    }
                }
                itemSummary = parts.joined(separator: ", ")
            }

            // 4. INSERT income_entries (auto-income)
            let incomeSQL = """
            INSERT INTO income_entries (id, user_id, amount, source, category_id, date, notes, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            try databaseManager.execute(incomeSQL, parameters: [
                incomeEntryId,
                order.userId,
                NSDecimalNumber(decimal: order.total).stringValue,
                customerName,
                salesCategoryId,
                todayStr,
                itemSummary,
                now,
                now
            ])
        }

        createdOrder = Order(
            id: order.id,
            userId: order.userId,
            customerId: order.customerId,
            status: order.status,
            subtotal: order.subtotal,
            discountAmount: order.discountAmount,
            discountNote: order.discountNote,
            total: order.total,
            incomeEntryId: incomeEntryId,
            createdAt: order.createdAt,
            updatedAt: order.updatedAt,
            items: order.items,
            customerName: customerName
        )

        return createdOrder
    }

    // MARK: - Update Order (Transactional)

    /// Replaces an order's items and discount. Adjusts stock by delta vs the
    /// previously stored items, validates sufficient stock for any increases,
    /// and keeps the linked income_entry in sync (amount + summary).
    func updateOrder(
        orderId: String,
        items: [OrderItem],
        discountAmount: Decimal,
        discountNote: String?
    ) async throws -> Order {
        guard !items.isEmpty else {
            throw OrderError.emptyOrder
        }

        let orderRows = try databaseManager.queryAsJSON("""
            SELECT o.*, c.name AS customer_name
            FROM orders o
            JOIN customers c ON o.customer_id = c.id
            WHERE o.id = ?
            """, parameters: [orderId])
        guard let orderRow = orderRows.first,
              let existingOrder = rowToOrder(orderRow) else {
            throw OrderError.orderNotFound
        }

        let existingItems = try await getOrderItems(orderId: orderId)

        let newSubtotal = items.reduce(Decimal.zero) { $0 + ($1.unitPrice * Decimal($1.quantity)) }
        let clampedDiscount = max(min(discountAmount, newSubtotal), 0)
        let newTotal = max(newSubtotal - clampedDiscount, 0)

        var stockDelta: [String: Int] = [:]
        for item in items {
            stockDelta[item.productId, default: 0] += item.quantity
        }
        for item in existingItems {
            stockDelta[item.productId, default: 0] -= item.quantity
        }

        let now = ISO8601DateFormatter().string(from: Date())

        try databaseManager.transaction {
            for (productId, delta) in stockDelta where delta != 0 {
                if delta > 0 {
                    let stockSQL = """
                    UPDATE products SET stock = stock - ?, updated_at = ?
                    WHERE id = ? AND stock >= ?
                    """
                    try databaseManager.execute(stockSQL, parameters: [
                        delta, now, productId, delta
                    ])
                    if databaseManager.changesCount() == 0 {
                        let checkRows = try databaseManager.queryAsJSON(
                            "SELECT stock FROM products WHERE id = ?",
                            parameters: [productId]
                        )
                        let available = checkRows.first.map { parseIntValue($0["stock"]) } ?? 0
                        throw OrderError.insufficientStock(
                            productId: productId, requested: delta, available: available
                        )
                    }
                } else {
                    let stockSQL = """
                    UPDATE products SET stock = stock + ?, updated_at = ? WHERE id = ?
                    """
                    try databaseManager.execute(stockSQL, parameters: [
                        -delta, now, productId
                    ])
                }
            }

            try databaseManager.execute(
                "DELETE FROM order_items WHERE order_id = ?",
                parameters: [orderId]
            )

            for item in items {
                let lineTotal = item.unitPrice * Decimal(item.quantity)
                try databaseManager.execute("""
                    INSERT INTO order_items (id, order_id, product_id, quantity, unit_price, line_total)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """, parameters: [
                    UUID().uuidString,
                    orderId,
                    item.productId,
                    item.quantity,
                    NSDecimalNumber(decimal: item.unitPrice).stringValue,
                    NSDecimalNumber(decimal: lineTotal).stringValue
                ])
            }

            try databaseManager.execute("""
                UPDATE orders
                SET subtotal = ?, discount_amount = ?, discount_note = ?, total = ?, updated_at = ?
                WHERE id = ?
                """, parameters: [
                NSDecimalNumber(decimal: newSubtotal).stringValue,
                NSDecimalNumber(decimal: clampedDiscount).stringValue,
                discountNote ?? NSNull(),
                NSDecimalNumber(decimal: newTotal).stringValue,
                now,
                orderId
            ])

            if let incomeId = existingOrder.incomeEntryId {
                var summaryParts: [String] = []
                for item in items {
                    if let code = item.productCode, !code.isEmpty {
                        summaryParts.append("\(item.quantity)× \(code)")
                    } else {
                        let prodRows = try databaseManager.queryAsJSON(
                            "SELECT code FROM products WHERE id = ?",
                            parameters: [item.productId]
                        )
                        let code = (prodRows.first?["code"] as? String) ?? item.productId
                        summaryParts.append("\(item.quantity)× \(code)")
                    }
                }
                let itemSummary = summaryParts.joined(separator: ", ")

                try databaseManager.execute("""
                    UPDATE income_entries
                    SET amount = ?, notes = ?, updated_at = ?
                    WHERE id = ?
                    """, parameters: [
                    NSDecimalNumber(decimal: newTotal).stringValue,
                    itemSummary,
                    now,
                    incomeId
                ])
            }
        }

        let refreshedItems = try await getOrderItems(orderId: orderId)
        return Order(
            id: existingOrder.id,
            userId: existingOrder.userId,
            customerId: existingOrder.customerId,
            status: existingOrder.status,
            subtotal: newSubtotal,
            discountAmount: clampedDiscount,
            discountNote: discountNote,
            total: newTotal,
            incomeEntryId: existingOrder.incomeEntryId,
            createdAt: existingOrder.createdAt,
            updatedAt: Date(),
            items: refreshedItems,
            customerName: existingOrder.customerName
        )
    }

    // MARK: - Delete Order (Transactional)

    /// Deletes an order, restores product stock, and removes the linked income entry.
    func deleteOrder(orderId: String) async throws {
        let orderRows = try databaseManager.queryAsJSON(
            "SELECT income_entry_id FROM orders WHERE id = ?",
            parameters: [orderId]
        )
        guard let orderRow = orderRows.first else {
            throw OrderError.orderNotFound
        }
        let incomeEntryId = orderRow["income_entry_id"] as? String

        let items = try await getOrderItems(orderId: orderId)

        let now = ISO8601DateFormatter().string(from: Date())

        try databaseManager.transaction {
            for item in items {
                try databaseManager.execute("""
                    UPDATE products SET stock = stock + ?, updated_at = ? WHERE id = ?
                    """, parameters: [item.quantity, now, item.productId])
            }

            try databaseManager.execute(
                "DELETE FROM orders WHERE id = ?",
                parameters: [orderId]
            )

            if let incomeId = incomeEntryId {
                try databaseManager.execute(
                    "DELETE FROM income_entries WHERE id = ?",
                    parameters: [incomeId]
                )
            }
        }
    }

    // MARK: - Get Order by ID (with items)

    func getOrderById(_ orderId: String) async throws -> Order? {
        let sql = """
        SELECT o.*, c.name AS customer_name
        FROM orders o
        JOIN customers c ON o.customer_id = c.id
        WHERE o.id = ?
        """
        let rows = try databaseManager.queryAsJSON(sql, parameters: [orderId])
        guard let row = rows.first, var order = rowToOrder(row) else {
            return nil
        }
        order.items = try await getOrderItems(orderId: orderId)
        return order
    }

    // MARK: - Get Orders for User (with customer name)

    func getOrdersForUser(_ userId: String) async throws -> [Order] {
        let sql = """
        SELECT o.*, c.name AS customer_name
        FROM orders o
        JOIN customers c ON o.customer_id = c.id
        WHERE o.user_id = ?
        ORDER BY o.created_at DESC
        """
        let results = try databaseManager.queryAsJSON(sql, parameters: [userId])

        return results.compactMap { rowToOrder($0) }
    }

    // MARK: - Get Recent Orders (efficient LIMIT query)

    func getRecentOrders(userId: String, limit: Int = 5) async throws -> [Order] {
        let sql = """
        SELECT o.*, c.name as customer_name
        FROM orders o LEFT JOIN customers c ON o.customer_id = c.id
        WHERE o.user_id = ? ORDER BY o.created_at DESC LIMIT ?
        """
        let results = try databaseManager.queryAsJSON(sql, parameters: [userId, limit])
        return results.compactMap { rowToOrder($0) }
    }

    // MARK: - Get Orders for Customer (with items loaded)

    func getOrdersForCustomer(_ customerId: String) async throws -> [Order] {
        let sql = """
        SELECT o.*, c.name AS customer_name
        FROM orders o
        JOIN customers c ON o.customer_id = c.id
        WHERE o.customer_id = ?
        ORDER BY o.created_at DESC
        """
        let results = try databaseManager.queryAsJSON(sql, parameters: [customerId])

        var orders = results.compactMap { rowToOrder($0) }

        // Load items for each order
        for i in 0..<orders.count {
            orders[i].items = try await getOrderItems(orderId: orders[i].id)
        }

        return orders
    }

    // MARK: - Get Order Items (with product details)

    func getOrderItems(orderId: String) async throws -> [OrderItem] {
        let sql = """
        SELECT oi.*, p.code AS product_code, p.name AS product_name, p.specification AS product_spec
        FROM order_items oi
        JOIN products p ON oi.product_id = p.id
        WHERE oi.order_id = ?
        """
        let results = try databaseManager.queryAsJSON(sql, parameters: [orderId])

        return results.compactMap { rowToOrderItem($0) }
    }

    // MARK: - Monthly Revenue

    func getMonthlyRevenue(userId: String) async throws -> Decimal {
        let firstOfMonth = currentMonthFirstDay()

        let sql = """
        SELECT COALESCE(SUM(total), 0) AS revenue
        FROM orders
        WHERE user_id = ? AND created_at >= ?
        """
        let results = try databaseManager.queryAsJSON(sql, parameters: [userId, firstOfMonth])

        guard let row = results.first else { return 0 }
        return parseAmount(row["revenue"])
    }

    // MARK: - Monthly Order Count

    func getMonthlyOrderCount(userId: String) async throws -> Int {
        let firstOfMonth = currentMonthFirstDay()

        let sql = """
        SELECT COUNT(*) AS c
        FROM orders
        WHERE user_id = ? AND created_at >= ?
        """
        let results = try databaseManager.queryAsJSON(sql, parameters: [userId, firstOfMonth])
        guard let row = results.first else { return 0 }
        return parseIntValue(row["c"])
    }

    // MARK: - Monthly Cost

    func getMonthlyCost(userId: String) async throws -> Decimal {
        let firstOfMonth = currentMonthFirstDay()

        let sql = """
        SELECT COALESCE(SUM(di.unit_cost * di.quantity), 0) AS cost
        FROM delivery_items di
        JOIN supplier_deliveries sd ON di.delivery_id = sd.id
        WHERE sd.user_id = ? AND sd.created_at >= ?
        """
        let results = try databaseManager.queryAsJSON(sql, parameters: [userId, firstOfMonth])

        guard let row = results.first else { return 0 }
        return parseAmount(row["cost"])
    }

    // MARK: - Private Helpers

    private func currentMonthFirstDay() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        return String(format: "%04d-%02d-01", components.year!, components.month!)
    }

    private func rowToOrder(_ row: [String: Any]) -> Order? {
        guard let id = row["id"] as? String,
              let userId = row["user_id"] as? String,
              let customerId = row["customer_id"] as? String else {
            return nil
        }

        let status = row["status"] as? String ?? "completed"
        let subtotal = parseAmount(row["subtotal"])
        let discountAmount = parseAmount(row["discount_amount"])
        let discountNote = row["discount_note"] as? String
        let total = parseAmount(row["total"])
        let incomeEntryId = row["income_entry_id"] as? String
        let customerName = row["customer_name"] as? String
        let createdAt = parseDate(row["created_at"])
        let updatedAt = parseDate(row["updated_at"])

        return Order(
            id: id,
            userId: userId,
            customerId: customerId,
            status: status,
            subtotal: subtotal,
            discountAmount: discountAmount,
            discountNote: discountNote,
            total: total,
            incomeEntryId: incomeEntryId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            customerName: customerName
        )
    }

    private func rowToOrderItem(_ row: [String: Any]) -> OrderItem? {
        guard let id = row["id"] as? String,
              let orderId = row["order_id"] as? String,
              let productId = row["product_id"] as? String else {
            return nil
        }

        let quantity = parseIntValue(row["quantity"])
        let unitPrice = parseAmount(row["unit_price"])
        let lineTotal = parseAmount(row["line_total"])
        let productCode = row["product_code"] as? String
        let productName = row["product_name"] as? String
        let productSpec = row["product_spec"] as? String

        return OrderItem(
            id: id,
            orderId: orderId,
            productId: productId,
            quantity: quantity,
            unitPrice: unitPrice,
            lineTotal: lineTotal,
            productCode: productCode,
            productName: productName,
            productSpec: productSpec
        )
    }

    private func parseDate(_ value: Any?) -> Date {
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

    private func parseIntValue(_ value: Any?) -> Int {
        if let intValue = value as? Int {
            return intValue
        }
        if let int64Value = value as? Int64 {
            return Int(int64Value)
        }
        if let stringValue = value as? String {
            return Int(stringValue) ?? 0
        }
        return 0
    }
}
