import Foundation

final class AppSettingsRepository: @unchecked Sendable {
    private let databaseManager: DatabaseManager

    nonisolated init(databaseManager: DatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }

    func getSettings(for userId: String) async throws -> AppSettings? {
        let sql = "SELECT * FROM app_settings WHERE user_id = ? LIMIT 1"
        let results = try databaseManager.queryAsJSON(sql, parameters: [userId])
        guard let row = results.first else { return nil }
        return rowToSettings(row)
    }

    func upsertSettings(_ settings: AppSettings) async throws {
        let sql = """
        INSERT INTO app_settings (user_id, auto_lock_timeout_seconds, currency, locale, onboarding_completed, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET
            auto_lock_timeout_seconds = excluded.auto_lock_timeout_seconds,
            currency = excluded.currency,
            locale = excluded.locale,
            onboarding_completed = excluded.onboarding_completed,
            updated_at = excluded.updated_at
        """

        try databaseManager.execute(sql, parameters: [
            settings.userId,
            settings.autoLockTimeoutSeconds,
            settings.currency,
            settings.locale,
            settings.onboardingCompleted ? 1 : 0,
            settings.updatedAt
        ])
    }

    func markOnboardingComplete(userId: String) async throws {
        let current = try await getOrCreateSettings(for: userId)
        let updated = AppSettings(
            userId: current.userId,
            autoLockTimeoutSeconds: current.autoLockTimeoutSeconds,
            currency: current.currency,
            locale: current.locale,
            onboardingCompleted: true,
            updatedAt: Date()
        )
        try await upsertSettings(updated)
    }

    func getOrCreateSettings(for userId: String) async throws -> AppSettings {
        if let settings = try await getSettings(for: userId) {
            return settings
        }

        let defaultSettings = AppSettings(userId: userId)
        try await upsertSettings(defaultSettings)
        return defaultSettings
    }

    private func rowToSettings(_ row: [String: Any]) -> AppSettings? {
        guard let userId = row["user_id"] as? String else { return nil }

        let timeout = intValue(from: row["auto_lock_timeout_seconds"]) ?? 300
        let currency = row["currency"] as? String ?? "USD"
        let locale = row["locale"] as? String ?? "en_US"
        let onboardingCompleted = (intValue(from: row["onboarding_completed"]) ?? 0) == 1
        let updatedAt = parseDate(row["updated_at"])

        return AppSettings(
            userId: userId,
            autoLockTimeoutSeconds: timeout,
            currency: currency,
            locale: locale,
            onboardingCompleted: onboardingCompleted,
            updatedAt: updatedAt
        )
    }

    private func parseDate(_ value: Any?) -> Date {
        if let dateString = value as? String {
            return ISO8601DateFormatter().date(from: dateString) ?? Date()
        }
        return Date()
    }

    private func intValue(from value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let int64Value = value as? Int64 {
            return Int(int64Value)
        }
        return nil
    }
}
