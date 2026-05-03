import SwiftUI

// Data loaded on background thread, applied on MainActor
private struct AppInitData: Sendable {
    let user: User
    let categories: [Category]
    let settings: AppSettings
    let salesCategoryId: String
}

@main
struct ShopVaultApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environment(\.locale, Locale(identifier: appState.localeIdentifier))
                .preferredColorScheme(.dark)
                .onAppear {
                    appState.retryInitialization = {
                        Task { await Self.initializeApp(appState: appState) }
                    }
                    appState.resetLocalStoreForRecovery = {
                        Task { await Self.resetLocalStoreForRecovery(appState: appState) }
                    }
                }
                .task {
                    await Self.initializeApp(appState: appState)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    appState.handleScenePhaseChange(newPhase)
                }
        }
    }

    @MainActor
    private static func initializeApp(appState: AppState) async {
        do {
            // Run ALL synchronous DB work on background thread via continuation
            let initData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppInitData, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let data = try Self.openAndLoadData()
                        continuation.resume(returning: data)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            // Back on MainActor — update UI state
            appState.applySettings(initData.settings)
            appState.initializeSession(user: initData.user, categories: initData.categories)
            appState.salesCategoryId = initData.salesCategoryId
            appState.refreshLowStockCount()
            appState.clearAuthenticationError()

            // Note: products are seeded by the onboarding wizard (OnboardingView)
            // when the user picks an IndustryTemplate.
        } catch {
            #if DEBUG
            print("Initialization error: \(error)")
            appState.setAuthenticationError(
                "Init failed: \(error.localizedDescription)",
                canResetLocalStore: isRecoverableLocalStoreError(error)
            )
            #else
            if let dbError = error as? DatabaseError, case .sqlcipherUnavailable = dbError {
                appState.setAuthenticationError("SQLCipher missing.")
            } else {
                appState.setAuthenticationError(
                    "Failed to initialize app securely",
                    canResetLocalStore: isRecoverableLocalStoreError(error)
                )
            }
            #endif
        }
    }

    @MainActor
    private static func resetLocalStoreForRecovery(appState: AppState) async {
        appState.isResettingLocalStore = true
        appState.clearAuthenticationError()

        do {
            try DatabaseManager.shared.moveUnreadableStoreAsideForRecovery()
            appState.isResettingLocalStore = false
            await initializeApp(appState: appState)
        } catch {
            appState.isResettingLocalStore = false
            appState.setAuthenticationError("Reset failed: \(error.localizedDescription)")
        }
    }

    private static func isRecoverableLocalStoreError(_ error: Error) -> Bool {
        guard let dbError = error as? DatabaseError else {
            return false
        }

        switch dbError {
        case .failedToEncryptDatabase:
            return true
        case .failedToExecuteQuery(let message):
            return message.localizedCaseInsensitiveContains("file is not a database")
                || message.localizedCaseInsensitiveContains("database disk image is malformed")
        default:
            return false
        }
    }

    /// Runs entirely on a background thread — no MainActor, no async
    private static func openAndLoadData() throws -> AppInitData {
        let db = DatabaseManager.shared
        try db.open()

        let iso = ISO8601DateFormatter()
        let now = iso.string(from: Date())

        // Check for existing user
        let userRows = try db.queryAsJSON("SELECT * FROM users LIMIT 1")

        let user: User
        if let row = userRows.first, let id = row["id"] as? String {
            user = User(
                id: id,
                biometricEnabled: (row["biometric_enabled"] as? Int64 ?? 1) == 1,
                pinHash: row["pin_hash"] as? String,
                createdAt: (row["created_at"] as? String).flatMap { iso.date(from: $0) } ?? Date(),
                updatedAt: (row["updated_at"] as? String).flatMap { iso.date(from: $0) } ?? Date()
            )
        } else {
            // Bootstrap new user
            user = User()
            let categoryDefaults = Category.defaultCategories(userId: user.id)
            let settings = AppSettings(userId: user.id)

            try db.transaction {
                try db.execute(
                    "INSERT INTO users (id, biometric_enabled, pin_hash, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
                    parameters: [user.id, user.biometricEnabled ? 1 : 0, user.pinHash ?? NSNull(), user.createdAt, user.updatedAt]
                )
                for cat in categoryDefaults {
                    try db.execute(
                        "INSERT INTO categories (id, user_id, name, color, is_active, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                        parameters: [cat.id, cat.userId, cat.name, cat.color, cat.isActive ? 1 : 0, cat.createdAt]
                    )
                }
                try db.execute(
                    "INSERT INTO app_settings (user_id, auto_lock_timeout_seconds, currency, locale, updated_at) VALUES (?, ?, ?, ?, ?)",
                    parameters: [settings.userId, settings.autoLockTimeoutSeconds, settings.currency, settings.locale, settings.updatedAt]
                )
            }
        }

        // Load categories
        let catRows = try db.queryAsJSON("SELECT * FROM categories WHERE user_id = ? AND is_active = 1", parameters: [user.id])
        let categories = catRows.compactMap { row -> Category? in
            guard let id = row["id"] as? String,
                  let uid = row["user_id"] as? String,
                  let name = row["name"] as? String else { return nil }
            return Category(id: id, userId: uid, name: name, color: row["color"] as? String ?? "#4CAF50",
                            createdAt: (row["created_at"] as? String).flatMap { iso.date(from: $0) } ?? Date())
        }

        // Load or create settings
        let settingsRows = try db.queryAsJSON("SELECT * FROM app_settings WHERE user_id = ?", parameters: [user.id])
        let settings: AppSettings
        if let sRow = settingsRows.first {
            settings = AppSettings(
                userId: user.id,
                autoLockTimeoutSeconds: (sRow["auto_lock_timeout_seconds"] as? Int64).map { Int($0) } ?? 300,
                currency: sRow["currency"] as? String ?? "EUR",
                locale: sRow["locale"] as? String ?? "de_DE"
            )
        } else {
            settings = AppSettings(userId: user.id)
            try db.execute(
                "INSERT INTO app_settings (user_id, auto_lock_timeout_seconds, currency, locale, updated_at) VALUES (?, ?, ?, ?, ?)",
                parameters: [user.id, 300, "EUR", "de_DE", now]
            )
        }

        // Ensure Sales category
        let pepRows = try db.queryAsJSON(
            "SELECT id FROM categories WHERE user_id = ? AND name = ? AND is_active = 1",
            parameters: [user.id, "Sales"]
        )
        let salesCategoryId: String
        if let existing = pepRows.first?["id"] as? String {
            salesCategoryId = existing
        } else {
            let newId = UUID().uuidString
            try db.execute(
                "INSERT INTO categories (id, user_id, name, color, is_active, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                parameters: [newId, user.id, "Sales", "#00E676", 1, now]
            )
            salesCategoryId = newId
        }

        return AppInitData(user: user, categories: categories, settings: settings, salesCategoryId: salesCategoryId)
    }
}
