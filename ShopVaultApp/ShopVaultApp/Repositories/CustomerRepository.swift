import Foundation

final class CustomerRepository: @unchecked Sendable {
    private let databaseManager: DatabaseManager

    nonisolated init(databaseManager: DatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }

    func createCustomer(_ customer: Customer) async throws {
        let sql = """
        INSERT INTO customers (id, user_id, name, phone, email, address, notes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        let formatter = ISO8601DateFormatter()

        let encPhone = try PIIEncryption.encrypt(customer.phone)
        let encEmail = try PIIEncryption.encrypt(customer.email)
        let encAddress = try PIIEncryption.encrypt(customer.address)

        try databaseManager.execute(sql, parameters: [
            customer.id,
            customer.userId,
            customer.name,
            encPhone ?? NSNull(),
            encEmail ?? NSNull(),
            encAddress ?? NSNull(),
            customer.notes ?? NSNull(),
            formatter.string(from: customer.createdAt),
            formatter.string(from: customer.updatedAt)
        ])
    }

    func getCustomersForUser(_ userId: String) async throws -> [Customer] {
        let sql = """
        SELECT * FROM customers WHERE user_id = ? ORDER BY name ASC
        """
        let results = try databaseManager.queryAsJSON(sql, parameters: [userId])

        return results.compactMap { rowToCustomer($0) }
    }

    func searchCustomers(userId: String, query: String) async throws -> [Customer] {
        // Phone, email, and address are encrypted at the application layer,
        // so LIKE queries cannot match against them. Search by name only.
        let sql = """
        SELECT * FROM customers
        WHERE user_id = ? AND name LIKE ?
        ORDER BY name ASC
        """
        let searchTerm = "%\(query)%"
        let results = try databaseManager.queryAsJSON(
            sql,
            parameters: [userId, searchTerm]
        )

        return results.compactMap { rowToCustomer($0) }
    }

    func getCustomerById(_ id: String) async throws -> Customer? {
        let sql = "SELECT * FROM customers WHERE id = ?"
        let results = try databaseManager.queryAsJSON(sql, parameters: [id])

        guard let row = results.first else {
            return nil
        }

        return rowToCustomer(row)
    }

    func updateCustomer(_ customer: Customer) async throws {
        let sql = """
        UPDATE customers
        SET name = ?, phone = ?, email = ?, address = ?, notes = ?, updated_at = ?
        WHERE id = ?
        """
        let formatter = ISO8601DateFormatter()

        let encPhone = try PIIEncryption.encrypt(customer.phone)
        let encEmail = try PIIEncryption.encrypt(customer.email)
        let encAddress = try PIIEncryption.encrypt(customer.address)

        try databaseManager.execute(sql, parameters: [
            customer.name,
            encPhone ?? NSNull(),
            encEmail ?? NSNull(),
            encAddress ?? NSNull(),
            customer.notes ?? NSNull(),
            formatter.string(from: Date()),
            customer.id
        ])
    }

    func deleteCustomer(_ id: String) async throws {
        let sql = "DELETE FROM customers WHERE id = ?"
        try databaseManager.execute(sql, parameters: [id])
    }

    func getCustomerTotalSpend(_ customerId: String) async throws -> Decimal {
        let sql = """
        SELECT COALESCE(SUM(total), 0) as total_spend
        FROM orders
        WHERE customer_id = ? AND status = 'completed'
        """
        let results = try databaseManager.queryAsJSON(sql, parameters: [customerId])

        guard let row = results.first else {
            return 0
        }

        return parseAmount(row["total_spend"])
    }

    func getCustomerOrderCount(_ customerId: String) async throws -> Int {
        let sql = """
        SELECT COUNT(*) as order_count
        FROM orders
        WHERE customer_id = ?
        """
        let results = try databaseManager.queryAsJSON(sql, parameters: [customerId])

        guard let row = results.first else {
            return 0
        }

        if let count = row["order_count"] as? Int {
            return count
        }
        if let count = row["order_count"] as? Int64 {
            return Int(count)
        }
        if let count = row["order_count"] as? Double {
            return Int(count)
        }
        return 0
    }

    // MARK: - Private Helpers

    private func rowToCustomer(_ row: [String: Any]) -> Customer? {
        guard let id = row["id"] as? String,
              let userId = row["user_id"] as? String,
              let name = row["name"] as? String else {
            return nil
        }

        let phone = try? PIIEncryption.decrypt(row["phone"] as? String)
        let email = try? PIIEncryption.decrypt(row["email"] as? String)
        let address = try? PIIEncryption.decrypt(row["address"] as? String)
        let notes = row["notes"] as? String
        let createdAt = parseDate(row["created_at"])
        let updatedAt = parseDate(row["updated_at"])

        return Customer(
            id: id,
            userId: userId,
            name: name,
            phone: phone,
            email: email,
            address: address,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
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
}
