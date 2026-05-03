import Foundation

protocol CategoryRepositoryProtocol: AnyObject, Sendable {
    func createCategory(_ category: Category) async throws
    func getCategoriesForUser(_ userId: String) async throws -> [Category]
    func getCategoryById(_ id: String) async throws -> Category?
    func updateCategory(_ category: Category) async throws
    func deleteCategory(_ id: String) async throws
    func createDefaultCategories(for userId: String) async throws
    func ensureSalesCategory(for userId: String) async throws -> String
}

final class CategoryRepository: CategoryRepositoryProtocol, @unchecked Sendable {
    private let databaseManager: DatabaseManager

    nonisolated init(databaseManager: DatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }
    
    func createCategory(_ category: Category) async throws {
        let sql = """
        INSERT INTO categories (id, user_id, name, color, is_active, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """
        try databaseManager.execute(sql, parameters: [
            category.id,
            category.userId,
            category.name,
            category.color,
            category.isActive ? 1 : 0,
            category.createdAt
        ])
    }
    
    func getCategoriesForUser(_ userId: String) async throws -> [Category] {
        let sql = "SELECT * FROM categories WHERE user_id = ? AND is_active = 1 ORDER BY name"
        let results = try databaseManager.queryAsJSON(sql, parameters: [userId])
        
        return results.compactMap { rowToCategory($0) }
    }
    
    func getCategoryById(_ id: String) async throws -> Category? {
        let sql = "SELECT * FROM categories WHERE id = ?"
        let results = try databaseManager.queryAsJSON(sql, parameters: [id])
        
        guard let row = results.first else {
            return nil
        }
        
        return rowToCategory(row)
    }
    
    func updateCategory(_ category: Category) async throws {
        let sql = """
        UPDATE categories SET name = ?, color = ?, is_active = ? WHERE id = ?
        """
        try databaseManager.execute(sql, parameters: [
            category.name,
            category.color,
            category.isActive ? 1 : 0,
            category.id
        ])
    }
    
    func deleteCategory(_ id: String) async throws {
        let sql = "UPDATE categories SET is_active = 0 WHERE id = ?"
        try databaseManager.execute(sql, parameters: [id])
    }
    
    func createDefaultCategories(for userId: String) async throws {
        let defaults = Category.defaultCategories(userId: userId)
        for category in defaults {
            try await createCategory(category)
        }
    }
    
    func ensureSalesCategory(for userId: String) async throws -> String {
        let sql = "SELECT id FROM categories WHERE user_id = ? AND name = ? AND is_active = 1"
        let results = try databaseManager.queryAsJSON(sql, parameters: [userId, "Sales"])

        if let existingRow = results.first, let id = existingRow["id"] as? String {
            return id
        }

        let newId = UUID().uuidString
        let insertSQL = """
        INSERT INTO categories (id, user_id, name, color, is_active, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """
        try databaseManager.execute(insertSQL, parameters: [
            newId,
            userId,
            "Sales",
            "#00E676",
            1,
            ISO8601DateFormatter().string(from: Date())
        ])

        return newId
    }

    private func rowToCategory(_ row: [String: Any]) -> Category? {
        guard let id = row["id"] as? String,
              let userId = row["user_id"] as? String,
              let name = row["name"] as? String else {
            return nil
        }
        
        let color = row["color"] as? String ?? "#4CAF50"
        let isActive = intValue(from: row["is_active"]) == 1
        let createdAt = parseDate(row["created_at"])
        
        return Category(
            id: id,
            userId: userId,
            name: name,
            color: color,
            isActive: isActive,
            createdAt: createdAt
        )
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
