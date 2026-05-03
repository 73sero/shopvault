import Foundation

class IncomeRepository {
    private let databaseManager: DatabaseManager
    
    init(databaseManager: DatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }
    
    func saveEntry(_ entry: IncomeEntry) async throws {
        let sql = """
        INSERT INTO income_entries (id, user_id, amount, source, category_id, date, notes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        try databaseManager.execute(sql, parameters: [
            entry.id,
            entry.userId,
            NSDecimalNumber(decimal: entry.amount).stringValue,
            entry.source,
            entry.categoryId,
            formatter.string(from: entry.date),
            entry.notes ?? NSNull(),
            entry.createdAt,
            entry.updatedAt
        ])
    }
    
    func getEntriesForUser(_ userId: String) async throws -> [IncomeEntry] {
        let sql = """
        SELECT * FROM income_entries WHERE user_id = ? ORDER BY date DESC
        """
        let results = try databaseManager.queryAsJSON(sql, parameters: [userId])
        
        return results.compactMap { rowToEntry($0) }
    }
    
    func getEntryById(_ id: String) async throws -> IncomeEntry? {
        let sql = "SELECT * FROM income_entries WHERE id = ?"
        let results = try databaseManager.queryAsJSON(sql, parameters: [id])
        
        guard let row = results.first else {
            return nil
        }
        
        return rowToEntry(row)
    }
    
    func getEntriesByDateRange(_ userId: String, from: Date, to: Date) async throws -> [IncomeEntry] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let fromStr = formatter.string(from: from)
        let toStr = formatter.string(from: to)
        
        let sql = """
        SELECT * FROM income_entries 
        WHERE user_id = ? AND date >= ? AND date <= ? 
        ORDER BY date DESC
        """
        let results = try databaseManager.queryAsJSON(
            sql,
            parameters: [userId, fromStr, toStr]
        )
        
        return results.compactMap { rowToEntry($0) }
    }
    
    func getEntriesByCategory(_ userId: String, categoryId: String) async throws -> [IncomeEntry] {
        let sql = """
        SELECT * FROM income_entries 
        WHERE user_id = ? AND category_id = ? 
        ORDER BY date DESC
        """
        let results = try databaseManager.queryAsJSON(
            sql,
            parameters: [userId, categoryId]
        )
        
        return results.compactMap { rowToEntry($0) }
    }
    
    func updateEntry(_ entry: IncomeEntry) async throws {
        let sql = """
        UPDATE income_entries 
        SET amount = ?, source = ?, category_id = ?, date = ?, notes = ?, updated_at = ?
        WHERE id = ?
        """
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        try databaseManager.execute(sql, parameters: [
            NSDecimalNumber(decimal: entry.amount).stringValue,
            entry.source,
            entry.categoryId,
            formatter.string(from: entry.date),
            entry.notes ?? NSNull(),
            entry.updatedAt,
            entry.id
        ])
    }
    
    func deleteEntry(_ id: String) async throws {
        let sql = "DELETE FROM income_entries WHERE id = ?"
        try databaseManager.execute(sql, parameters: [id])
    }
    
    private func rowToEntry(_ row: [String: Any]) -> IncomeEntry? {
        guard let id = row["id"] as? String,
              let userId = row["user_id"] as? String,
              let source = row["source"] as? String,
              let categoryId = row["category_id"] as? String else {
            return nil
        }
        
        let amount = Decimal(string: row["amount"] as? String ?? "0") ?? 0
        let dateStr = row["date"] as? String ?? ""
        let notes = row["notes"] as? String
        let createdAt = parseDate(row["created_at"])
        let updatedAt = parseDate(row["updated_at"])
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: dateStr) ?? Date()
        
        return IncomeEntry(
            id: id,
            userId: userId,
            amount: amount,
            source: source,
            categoryId: categoryId,
            date: date,
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
}
