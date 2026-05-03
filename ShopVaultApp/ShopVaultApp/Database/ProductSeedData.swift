import Foundation

/// Seeds the products table from a chosen IndustryTemplate.
/// Called from the onboarding flow once the user picks a template (or skips with `.empty`).
/// Safe to call multiple times — INSERT OR IGNORE prevents duplicates.
enum ProductSeedData {

    /// Seed all products from the given template using parameterized queries.
    /// Each product gets a deterministic UUID derived from its code so that
    /// repeated seeds are idempotent.
    static func seed(template: IndustryTemplate, using databaseManager: DatabaseManager) throws {
        guard !template.products.isEmpty else { return }

        let now = ISO8601DateFormatter().string(from: Date())

        let sql = """
        INSERT OR IGNORE INTO products
            (id, code, name, specification, price, stock, low_stock_threshold, is_active, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, 0, 3, 1, ?, ?)
        """

        for product in template.products {
            let id = deterministicUUID(for: product.code)
            try databaseManager.execute(sql, parameters: [
                id,
                product.code,
                product.name,
                product.specification,
                NSDecimalNumber(decimal: product.price).stringValue,
                now,
                now
            ])
        }
    }

    /// Generates a deterministic UUID-shaped identifier from a product code so
    /// the same seed input always produces the same row id.
    private static func deterministicUUID(for code: String) -> String {
        let namespace = "ShopVault.Product."
        let input = namespace + code
        var hash = [UInt8](repeating: 0, count: 16)

        let data = Array(input.utf8)
        for (i, byte) in data.enumerated() {
            let idx = i % 16
            hash[idx] = hash[idx] &+ byte
            hash[idx] = hash[idx] ^ UInt8(truncatingIfNeeded: i &* 31)
        }

        let hex = hash.map { String(format: "%02x", $0) }.joined()
        return "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
    }
}
