import Foundation

final class ProductRepository: @unchecked Sendable {
    private let databaseManager: DatabaseManager

    nonisolated init(databaseManager: DatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }

    func getAllProducts() async throws -> [Product] {
        let sql = "SELECT * FROM products WHERE is_active = 1 ORDER BY name"
        let results = try databaseManager.queryAsJSON(sql, parameters: [])
        return results.compactMap { rowToProduct($0) }
    }

    func searchProducts(query: String) async throws -> [Product] {
        let sql = """
        SELECT * FROM products
        WHERE is_active = 1 AND (name LIKE ? OR code LIKE ?)
        ORDER BY name
        """
        let pattern = "%\(query)%"
        let results = try databaseManager.queryAsJSON(sql, parameters: [pattern, pattern])
        return results.compactMap { rowToProduct($0) }
    }

    func getProductById(_ id: String) async throws -> Product? {
        let sql = "SELECT * FROM products WHERE id = ?"
        let results = try databaseManager.queryAsJSON(sql, parameters: [id])
        guard let row = results.first else { return nil }
        return rowToProduct(row)
    }

    func getProductByCode(_ code: String) async throws -> Product? {
        let sql = "SELECT * FROM products WHERE code = ?"
        let results = try databaseManager.queryAsJSON(sql, parameters: [code])
        guard let row = results.first else { return nil }
        return rowToProduct(row)
    }

    func getLowStockProducts() async throws -> [Product] {
        let sql = """
        SELECT * FROM products
        WHERE is_active = 1 AND stock <= low_stock_threshold
        ORDER BY stock ASC
        """
        let results = try databaseManager.queryAsJSON(sql, parameters: [])
        return results.compactMap { rowToProduct($0) }
    }

    func getLowStockCount() async throws -> Int {
        let sql = """
        SELECT COUNT(*) as count FROM products
        WHERE is_active = 1 AND stock <= low_stock_threshold
        """
        let results = try databaseManager.queryAsJSON(sql, parameters: [])
        guard let row = results.first else { return 0 }
        return intValue(from: row["count"])
    }

    func updateStock(productId: String, newStock: Int) throws {
        let sql = """
        UPDATE products SET stock = ?, updated_at = ? WHERE id = ?
        """
        try databaseManager.execute(sql, parameters: [
            newStock,
            ISO8601DateFormatter().string(from: Date()),
            productId
        ])
    }

    func decrementStock(productId: String, by quantity: Int) throws {
        let sql = """
        UPDATE products SET stock = stock - ?, updated_at = ?
        WHERE id = ? AND stock >= ?
        """
        try databaseManager.execute(sql, parameters: [
            quantity,
            ISO8601DateFormatter().string(from: Date()),
            productId,
            quantity
        ])
    }

    func incrementStock(productId: String, by quantity: Int) throws {
        let sql = """
        UPDATE products SET stock = stock + ?, updated_at = ? WHERE id = ?
        """
        try databaseManager.execute(sql, parameters: [
            quantity,
            ISO8601DateFormatter().string(from: Date()),
            productId
        ])
    }

    func updateProduct(_ product: Product) async throws {
        let sql = """
        UPDATE products
        SET code = ?, name = ?, specification = ?, price = ?, stock = ?,
            low_stock_threshold = ?, is_favorite = ?, is_active = ?, updated_at = ?
        WHERE id = ?
        """
        try databaseManager.execute(sql, parameters: [
            product.code,
            product.name,
            product.specification,
            NSDecimalNumber(decimal: product.price).stringValue,
            product.stock,
            product.lowStockThreshold,
            product.isFavorite ? 1 : 0,
            product.isActive ? 1 : 0,
            ISO8601DateFormatter().string(from: Date()),
            product.id
        ])
    }

    func toggleFavorite(productId: String, isFavorite: Bool) throws {
        let sql = "UPDATE products SET is_favorite = ?, updated_at = ? WHERE id = ?"
        try databaseManager.execute(sql, parameters: [
            isFavorite ? 1 : 0,
            ISO8601DateFormatter().string(from: Date()),
            productId
        ])
    }

    func toggleActive(productId: String, isActive: Bool) throws {
        let sql = "UPDATE products SET is_active = ?, updated_at = ? WHERE id = ?"
        try databaseManager.execute(sql, parameters: [
            isActive ? 1 : 0,
            ISO8601DateFormatter().string(from: Date()),
            productId
        ])
    }

    func getAllProductsIncludingHidden() async throws -> [Product] {
        let sql = "SELECT * FROM products ORDER BY is_active DESC, is_favorite DESC, name"
        let results = try databaseManager.queryAsJSON(sql, parameters: [])
        return results.compactMap { rowToProduct($0) }
    }

    // MARK: - Private Helpers

    private func rowToProduct(_ row: [String: Any]) -> Product? {
        guard let id = row["id"] as? String,
              let code = row["code"] as? String,
              let name = row["name"] as? String else {
            return nil
        }

        let specification = row["specification"] as? String ?? ""
        let price = parseDecimal(row["price"])
        let stock = intValue(from: row["stock"])
        let lowStockThreshold = intValue(from: row["low_stock_threshold"])
        let isFavorite = intValue(from: row["is_favorite"]) == 1
        let isActive = intValue(from: row["is_active"]) == 1
        let createdAt = parseDate(row["created_at"])
        let updatedAt = parseDate(row["updated_at"])

        return Product(
            id: id,
            code: code,
            name: name,
            specification: specification,
            price: price,
            stock: stock,
            lowStockThreshold: lowStockThreshold,
            isFavorite: isFavorite,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func parseDecimal(_ value: Any?) -> Decimal {
        if let stringValue = value as? String {
            return Decimal(string: stringValue.replacingOccurrences(of: ",", with: ".")) ?? 0
        }
        if let doubleValue = value as? Double {
            return Decimal(string: "\(doubleValue)") ?? Decimal(doubleValue)
        }
        if let intValue = value as? Int64 {
            return Decimal(Int(intValue))
        }
        return 0
    }

    private func parseDate(_ value: Any?) -> Date {
        if let dateString = value as? String {
            return ISO8601DateFormatter().date(from: dateString) ?? Date()
        }
        return Date()
    }

    private func intValue(from value: Any?) -> Int {
        if let intValue = value as? Int {
            return intValue
        }
        if let int64Value = value as? Int64 {
            return Int(int64Value)
        }
        return 0
    }
}
