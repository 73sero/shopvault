import Foundation
#if canImport(SQLCipher)
import SQLCipher
#else
import SQLite3
#endif

// SQLITE_TRANSIENT constant for Swift
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Database Error

enum DatabaseError: LocalizedError {

    case failedToOpenDatabase
    case failedToEncryptDatabase
    case sqlcipherUnavailable
    case invalidEncryptionKey
    case failedToSecureDatabaseFile
    case failedToExecuteQuery(String)
    case failedToBindParameters
    case noResults
    case migrationFailed

    var errorDescription: String? {
        switch self {
        case .failedToOpenDatabase:
            return "Failed to open database"

        case .failedToEncryptDatabase:
            return "Failed to encrypt database"

        case .sqlcipherUnavailable:
            return "SQLCipher is not available. Link SQLCipher instead of system SQLite."

        case .invalidEncryptionKey:
            return "Invalid encryption key"

        case .failedToSecureDatabaseFile:
            return "Failed to apply secure database file attributes"

        case .failedToExecuteQuery(let message):
            return "Query failed: \(message)"

        case .failedToBindParameters:
            return "Failed to bind parameters"

        case .noResults:
            return "No results found"

        case .migrationFailed:
            return "Database migration failed"
        }
    }
}

// MARK: - Database Manager

final class DatabaseManager: @unchecked Sendable {

    nonisolated static let shared = DatabaseManager(keychainManager: KeychainManager())

    private var database: OpaquePointer?
    private let dbPath: String
    private let dbURL: URL
    private let keychainManager: KeychainManager

    // MARK: - Initialization

    init(keychainManager: KeychainManager) {

        self.keychainManager = keychainManager

        let fileManager = FileManager.default
        let fallbackDirectory = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let baseDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fallbackDirectory

        let databaseDirectory = baseDirectory
            .appendingPathComponent("ShopVault", isDirectory: true)

        self.dbURL = databaseDirectory.appendingPathComponent("shop_vault.db")
        self.dbPath = dbURL.path
    }

    // MARK: - Database Lifecycle

    func open() throws {

        try ensureDatabaseDirectoryExists()

        var db: OpaquePointer?

        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

        guard sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK else {
            throw DatabaseError.failedToOpenDatabase
        }

        self.database = db

        do {
            log("sqlite3_open OK, applying encryption...")
            try applyEncryption()
            log("Encryption applied, setting pragmas...")
            try applyDatabaseSecurityPragmas()
            log("Pragmas set, verifying encryption...")
            try verifyEncryptionReadiness()
            log("Encryption verified, running migrations...")
            try applyMigrations()
            log("Migrations done, applying file protection...")
            try applyDatabaseFileProtection()
            log("Database fully open")
        } catch {
            close()
            throw error
        }
    }

    func close() {

        if let db = database {
            sqlite3_close(db)
            database = nil
        }
    }

    func moveUnreadableStoreAsideForRecovery() throws {
        close()

        let timestamp = Self.recoveryTimestamp()
        let fileManager = FileManager.default

        for suffix in ["", "-wal", "-shm", "-journal"] {
            let sourceURL = URL(fileURLWithPath: "\(dbPath)\(suffix)")
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                continue
            }

            let destinationURL = sourceURL
                .deletingLastPathComponent()
                .appendingPathComponent("\(sourceURL.lastPathComponent).unreadable-\(timestamp)")

            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        }
    }

    // MARK: - Encryption

    private func applyEncryption() throws {

        guard let db = database else {
            throw DatabaseError.failedToOpenDatabase
        }

        let encryptionKey: Data

        if keychainManager.hasDBEncryptionKey() {

            encryptionKey = try keychainManager.retrieveDBEncryptionKey()

            guard encryptionKey.count == 32 else {
                throw DatabaseError.invalidEncryptionKey
            }

        } else {

            encryptionKey = Data(
                (0..<32).map { _ in UInt8.random(in: 0...UInt8.max) }
            )

            try keychainManager.storeDBEncryptionKey(encryptionKey)
        }

        let keyString = encryptionKey
            .map { String(format: "%02x", $0) }
            .joined()

        let pragmaSQL = "PRAGMA key = \"x'\(keyString)'\""

        var errorMessage: UnsafeMutablePointer<Int8>?

        guard sqlite3_exec(db, pragmaSQL, nil, nil, &errorMessage) == SQLITE_OK else {

            if let errorMessage = errorMessage {
                sqlite3_free(errorMessage)
            }

            throw DatabaseError.failedToEncryptDatabase
        }
    }

    private func applyDatabaseSecurityPragmas() throws {
        try executePragma("PRAGMA foreign_keys = ON;")
        try executePragma("PRAGMA secure_delete = ON;")
        try executePragma("PRAGMA journal_mode = WAL;")
        try executePragma("PRAGMA temp_store = MEMORY;")
        try executePragma("PRAGMA trusted_schema = OFF;")
    }

    private func verifyEncryptionReadiness() throws {
#if canImport(SQLCipher)
        guard let db = database else {
            throw DatabaseError.failedToOpenDatabase
        }

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, "PRAGMA cipher_version;", -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.sqlcipherUnavailable
        }

        guard sqlite3_step(statement) == SQLITE_ROW,
              let versionCString = sqlite3_column_text(statement, 0),
              !String(cString: versionCString).isEmpty else {
            throw DatabaseError.sqlcipherUnavailable
        }

        try executePragma("SELECT count(*) FROM sqlite_master;")
        verifyCipherIntegrityIfPossible()
#else
        throw DatabaseError.sqlcipherUnavailable
#endif
    }

    /// Runs `PRAGMA cipher_integrity_check` as a soft diagnostic. It logs whatever
    /// SQLCipher returns (drains all result rows) but never throws. The hard
    /// readiness signal is the prior `SELECT count(*) FROM sqlite_master` — if
    /// that succeeds, the database key is correct and the DB is readable. We do
    /// not gate app launch on the integrity check because real-device databases
    /// created under older SQLCipher cipher_compatibility settings can return
    /// non-"ok" rows even when the data is fully intact.
    private func verifyCipherIntegrityIfPossible() {
#if canImport(SQLCipher)
        guard let db = database else { return }

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, "PRAGMA cipher_integrity_check;", -1, &statement, nil) == SQLITE_OK else {
            log("cipher_integrity_check prepare failed (skipping, DB still considered open)")
            return
        }

        var rows: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                rows.append(String(cString: cString))
            }
        }

        if rows.isEmpty {
            log("cipher_integrity_check returned no rows")
        } else if rows.count == 1, rows[0].lowercased() == "ok" {
            log("cipher_integrity_check: ok")
        } else {
            log("cipher_integrity_check reported issues (non-fatal): \(rows.joined(separator: "; "))")
        }
#endif
    }

    private func ensureDatabaseDirectoryExists() throws {
        let directoryURL = dbURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    private func applyDatabaseFileProtection() throws {
        let fileManager = FileManager.default
        let directoryURL = dbURL.deletingLastPathComponent()
        let protectedPaths = [dbPath, "\(dbPath)-wal", "\(dbPath)-shm"]

        do {
            try excludeFromBackup(directoryURL)

            for path in protectedPaths where fileManager.fileExists(atPath: path) {
                try excludeFromBackup(URL(fileURLWithPath: path))
                try fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.complete],
                    ofItemAtPath: path
                )
            }
        } catch {
            throw DatabaseError.failedToSecureDatabaseFile
        }
    }

    private func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }

    private func executePragma(_ sql: String) throws {
        guard let db = database else {
            throw DatabaseError.failedToOpenDatabase
        }

        var errorMessage: UnsafeMutablePointer<Int8>?
        guard sqlite3_exec(db, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw DatabaseError.failedToExecuteQuery(message)
        }
    }

    // MARK: - Migration

    private func applyMigrations() throws {

        let currentVersion = try getCurrentSchemaVersion()

        log("Current schema version: \(currentVersion)")
        if currentVersion < 1 {
            log("Running migration v0 to v1...")
            try runMigration(from: 0, to: 1)
            log("Migration v1 complete")
        }

        if currentVersion < 2 {
            log("Running migration v1 to v2")
            try migrateToV2()
            log("Migration v2 complete")
        }

        if currentVersion < 3 {
            log("Running migration v2 to v3")
            try migrateToV3()
            log("Migration v3 complete")
        }

        if currentVersion < 4 {
            log("Running migration v3 to v4")
            try migrateToV4()
            log("Migration v4 complete")
        }
        log("All migrations done")
    }

    /// Seeds products from a chosen IndustryTemplate. Called from the onboarding flow.
    /// Safe to call multiple times — INSERT OR IGNORE prevents duplicates.
    func seedProducts(template: IndustryTemplate) throws {
        try transaction {
            try ProductSeedData.seed(template: template, using: self)
        }
    }

    private func log(_ message: String) {
#if DEBUG
        print("[DB] \(message)")
#endif
    }

    private static func recoveryTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func migrateToV4() throws {
        // Add onboarding_completed flag to app_settings; tolerated if column already exists.
        do {
            try execute("ALTER TABLE app_settings ADD COLUMN onboarding_completed INTEGER NOT NULL DEFAULT 0")
        } catch DatabaseError.failedToExecuteQuery(let message)
            where message.lowercased().contains("duplicate column name") {
            // Already exists — fresh install or re-run; ignore.
        }
        try execute("INSERT OR REPLACE INTO schema_version (version, description) VALUES (4, 'Add onboarding_completed flag')")
    }

    private func migrateToV3() throws {
        // ALTER TABLE may fail if column already exists (e.g. fresh install with v2 schema that includes is_favorite)
        do {
            try execute("ALTER TABLE products ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0")
        } catch DatabaseError.failedToExecuteQuery(let message)
            where message.lowercased().contains("duplicate column name") {
            // Fresh v2 installs already include this column; other migration failures must still abort.
        }
        try execute("INSERT OR REPLACE INTO schema_version (version, description) VALUES (3, 'Add is_favorite to products')")
    }

    private func getCurrentSchemaVersion() throws -> Int {

        guard let db = database else {
            throw DatabaseError.failedToOpenDatabase
        }

        let query = "SELECT MAX(version) FROM schema_version"

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            log("getCurrentSchemaVersion prepare failed (treating as v0): \(message)")
            return 0
        }

        defer { sqlite3_finalize(statement) }

        if sqlite3_step(statement) == SQLITE_ROW {

            let version = sqlite3_column_int(statement, 0)

            return version > 0 ? Int(version) : 0
        }

        return 0
    }

    private func runMigration(from: Int, to: Int) throws {

        guard from < to else { return }

        if let schemaSQL = try loadSchemaSQL() {
            try executeScript(schemaSQL)
        }
    }

    private func migrateToV2() throws {

        let v2Schema = """
        -- Products catalog
        CREATE TABLE IF NOT EXISTS products (
            id TEXT PRIMARY KEY NOT NULL,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            specification TEXT NOT NULL,
            price DECIMAL(10, 2) NOT NULL CHECK(price > 0),
            stock INTEGER NOT NULL DEFAULT 0,
            low_stock_threshold INTEGER NOT NULL DEFAULT 3,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        CREATE INDEX IF NOT EXISTS idx_products_code ON products(code);
        CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(is_active);

        -- Customers
        CREATE TABLE IF NOT EXISTS customers (
            id TEXT PRIMARY KEY NOT NULL,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            phone TEXT,
            email TEXT,
            address TEXT,
            notes TEXT,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_customers_user_id ON customers(user_id);

        -- Orders
        CREATE TABLE IF NOT EXISTS orders (
            id TEXT PRIMARY KEY NOT NULL,
            user_id TEXT NOT NULL,
            customer_id TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'completed',
            subtotal DECIMAL(12, 2) NOT NULL,
            discount_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
            discount_note TEXT,
            total DECIMAL(12, 2) NOT NULL,
            income_entry_id TEXT,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY(income_entry_id) REFERENCES income_entries(id) ON DELETE SET NULL
        );
        CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
        CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
        CREATE INDEX IF NOT EXISTS idx_orders_user_created ON orders(user_id, created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_orders_income_entry ON orders(income_entry_id);

        -- Order items
        CREATE TABLE IF NOT EXISTS order_items (
            id TEXT PRIMARY KEY NOT NULL,
            order_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            quantity INTEGER NOT NULL CHECK(quantity > 0),
            unit_price DECIMAL(10, 2) NOT NULL,
            line_total DECIMAL(12, 2) NOT NULL,
            FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE,
            FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE RESTRICT
        );
        CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
        CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);

        -- Supplier deliveries
        CREATE TABLE IF NOT EXISTS supplier_deliveries (
            id TEXT PRIMARY KEY NOT NULL,
            user_id TEXT NOT NULL,
            total_cost DECIMAL(12, 2) NOT NULL,
            notes TEXT,
            delivered_at DATE NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_supplier_deliveries_user_id ON supplier_deliveries(user_id);

        -- Delivery items
        CREATE TABLE IF NOT EXISTS delivery_items (
            id TEXT PRIMARY KEY NOT NULL,
            delivery_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            quantity INTEGER NOT NULL CHECK(quantity > 0),
            unit_cost DECIMAL(10, 2) NOT NULL,
            FOREIGN KEY(delivery_id) REFERENCES supplier_deliveries(id) ON DELETE CASCADE,
            FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE RESTRICT
        );
        CREATE INDEX IF NOT EXISTS idx_delivery_items_delivery_id ON delivery_items(delivery_id);
        CREATE INDEX IF NOT EXISTS idx_delivery_items_product_id ON delivery_items(product_id);
        """

        try executeScript(v2Schema)

        // Record migration version (product seeding happens separately to avoid blocking app launch)
        try execute(
            "INSERT OR IGNORE INTO schema_version (version, description) VALUES (?, ?)",
            parameters: [2, "Add products, customers, orders, order_items, supplier_deliveries, delivery_items tables"]
        )
    }

    private func loadSchemaSQL() throws -> String? {

        guard let path = Bundle.main.path(
            forResource: "schema",
            ofType: "sql"
        ) else {
            return nil
        }

        return try String(
            contentsOfFile: path,
            encoding: .utf8
        )
    }

    // MARK: - Execute Query

    func execute(_ sql: String, parameters: [Any] = []) throws {

        guard let db = database else {
            throw DatabaseError.failedToOpenDatabase
        }

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.failedToExecuteQuery("prepare: \(message) [sql: \(Self.sqlPreview(sql))]")
        }

        defer { sqlite3_finalize(statement) }

        try bind(parameters: parameters, to: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            let message = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.failedToExecuteQuery("step: \(message) [sql: \(Self.sqlPreview(sql))]")
        }
    }

    private static func sqlPreview(_ sql: String) -> String {
        let collapsed = sql
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if collapsed.count <= 120 {
            return collapsed
        }
        return String(collapsed.prefix(120)) + "..."
    }

    func changesCount() -> Int {
        guard let db = database else { return 0 }
        return Int(sqlite3_changes(db))
    }

    func executeScript(_ sql: String) throws {
        guard let db = database else {
            throw DatabaseError.failedToOpenDatabase
        }

        var errorMessage: UnsafeMutablePointer<Int8>?
        guard sqlite3_exec(db, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw DatabaseError.failedToExecuteQuery(message)
        }
    }

    func transaction<T>(_ block: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE TRANSACTION")

        do {
            let result = try block()
            try execute("COMMIT")
            return result
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    // MARK: - Query JSON

    func queryAsJSON(
        _ sql: String,
        parameters: [Any] = []
    ) throws -> [[String: Any]] {

        guard let db = database else {
            throw DatabaseError.failedToOpenDatabase
        }

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(
            db,
            sql,
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {

            let message = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.failedToExecuteQuery(
                "prepare: \(message) [sql: \(Self.sqlPreview(sql))]"
            )
        }

        defer { sqlite3_finalize(statement) }

        try bind(parameters: parameters, to: statement)

        var results: [[String: Any]] = []

        while sqlite3_step(statement) == SQLITE_ROW {

            var row: [String: Any] = [:]

            let columnCount = sqlite3_column_count(statement)

            for i in 0..<columnCount {

                let name = String(
                    cString: sqlite3_column_name(statement, i)
                )

                switch sqlite3_column_type(statement, i) {

                case SQLITE_TEXT:

                    row[name] = String(
                        cString: sqlite3_column_text(statement, i)
                    )

                case SQLITE_INTEGER:

                    row[name] = sqlite3_column_int64(statement, i)

                case SQLITE_FLOAT:

                    row[name] = sqlite3_column_double(statement, i)

                case SQLITE_BLOB:

                    let size = Int(sqlite3_column_bytes(statement, i))

                    if size > 0, let ptr = sqlite3_column_blob(statement, i) {
                        row[name] = Data(
                            bytes: ptr,
                            count: size
                        )
                    } else {
                        row[name] = Data()
                    }

                default:

                    row[name] = NSNull()
                }
            }

            results.append(row)
        }

        return results
    }

    private func bind(parameters: [Any], to statement: OpaquePointer?) throws {
        for (index, param) in parameters.enumerated() {
            let paramIndex = Int32(index + 1)

            switch param {
            case let value as String:
                sqlite3_bind_text(statement, paramIndex, value, -1, SQLITE_TRANSIENT)
            case let value as Int:
                sqlite3_bind_int64(statement, paramIndex, sqlite3_int64(value))
            case let value as Int64:
                sqlite3_bind_int64(statement, paramIndex, sqlite3_int64(value))
            case let value as Double:
                sqlite3_bind_double(statement, paramIndex, value)
            case let value as Bool:
                sqlite3_bind_int(statement, paramIndex, value ? 1 : 0)
            case let value as Date:
                let dateString = ISO8601DateFormatter().string(from: value)
                sqlite3_bind_text(statement, paramIndex, dateString, -1, SQLITE_TRANSIENT)
            case let value as Data:
                _ = value.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(
                        statement,
                        paramIndex,
                        buffer.baseAddress,
                        Int32(value.count),
                        SQLITE_TRANSIENT
                    )
                }
            case _ as NSNull:
                sqlite3_bind_null(statement, paramIndex)
            case Optional<Any>.none:
                sqlite3_bind_null(statement, paramIndex)
            default:
                throw DatabaseError.failedToBindParameters
            }
        }
    }
}
