import Foundation

struct AppSettings: Codable, Hashable {
    let userId: String
    let autoLockTimeoutSeconds: Int
    let currency: String
    let locale: String
    let onboardingCompleted: Bool
    let updatedAt: Date

    init(
        userId: String,
        autoLockTimeoutSeconds: Int = 300,
        currency: String = "USD",
        locale: String = "en_US",
        onboardingCompleted: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.autoLockTimeoutSeconds = autoLockTimeoutSeconds
        self.currency = currency
        self.locale = locale
        self.onboardingCompleted = onboardingCompleted
        self.updatedAt = updatedAt
    }
}
