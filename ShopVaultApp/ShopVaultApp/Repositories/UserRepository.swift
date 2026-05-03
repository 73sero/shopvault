import Foundation

final class UserRepository: @unchecked Sendable {
    private let databaseManager: DatabaseManager

    nonisolated init(databaseManager: DatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }
    
    func createUser(_ user: User) async throws {
        let sql = """
        INSERT INTO users (id, biometric_enabled, pin_hash, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?)
        """
        try databaseManager.execute(sql, parameters: [
            user.id,
            user.biometricEnabled ? 1 : 0,
            user.pinHash ?? NSNull(),
            user.createdAt,
            user.updatedAt
        ])
    }
    
    func getCurrentUser() async throws -> User? {
        let sql = "SELECT * FROM users LIMIT 1"
        let results = try databaseManager.queryAsJSON(sql)
        
        guard let row = results.first else {
            return nil
        }
        
        return rowToUser(row)
    }
    
    func updateUser(_ user: User) async throws {
        let sql = """
        UPDATE users SET biometric_enabled = ?, pin_hash = ?, updated_at = ? WHERE id = ?
        """
        try databaseManager.execute(sql, parameters: [
            user.biometricEnabled ? 1 : 0,
            user.pinHash ?? NSNull(),
            user.updatedAt,
            user.id
        ])
    }
    
    private func rowToUser(_ row: [String: Any]) -> User? {
        guard let id = row["id"] as? String else { return nil }
        
        let biometricEnabled = intValue(from: row["biometric_enabled"]) == 1
        let pinHash = row["pin_hash"] as? String
        let createdAt = parseDate(row["created_at"])
        let updatedAt = parseDate(row["updated_at"])
        
        return User(
            id: id,
            biometricEnabled: biometricEnabled,
            pinHash: pinHash,
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
