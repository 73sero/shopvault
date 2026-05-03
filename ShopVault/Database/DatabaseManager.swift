import Foundation
#if canImport(SQLCipher)
import SQLCipher
#else
import SQLite3
#endif

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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

class DatabaseManager {
    private var database: OpaquePointer?
    private let dbPath: String
    private let dbURL: URL
    private let keychainManager: KeychainManager

    static let shared = DatabaseManager(
        keychainManager: KeychainManager()
    )

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

        try applyEncryption()
        try applyDatabaseSecurityPragmas()
        try verifyEncryptionReadiness()
        try applyMigrations()
        try applyDatabaseFileProtection()
    }

    func close() {
        if let db = database {
            sqlite3_close(db)
            database = nil
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

        let keyString = encryptionKey.map { String(format: "%02x", $0) }.joined()
        let pragmaSQL = "PRAGMA key = \"x'\(keyString)'\""

        var errorMessage: UnsafeMutablePointer<Int8>?
        guard sqlite3_exec(db, pragmaSQL, nil, nil, &errorMessage) == SQLITE_OK else {
            if let errorMessage {
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
#else
        return
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
        let protectedPaths = [dbPath, "\(dbPath)-wal", "\(dbPath)-shm"]

        do {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var protectedDBURL = dbURL
            try protectedDBURL.setResourceValues(values)

            #if os(iOS)
            for path in protectedPaths where fileManager.fileExists(atPath: path) {
                try fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: path
                )
            }
            #endif
        } catch {
            throw DatabaseError.failedToSecureDatabaseFile
        }
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

    // MARK: - Migrations

    private func applyMigrations() throws {
        let currentVersion = try getCurrentSchemaVersion()
        let targetVersion = 1

        if currentVersion < targetVersion {
            try runMigration(from: currentVersion, to: targetVersion)
        }
    }

    private func getCurrentSchemaVersion() throws -> Int {
        guard let db = database else {
            throw DatabaseError.failedToOpenDatabase
        }

        let query = "SELECT MAX(version) FROM schema_version"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
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

    private func loadSchemaSQL() throws -> String? {
        guard let path = Bundle.main.path(forResource: "schema", ofType: "sql") else {
            return nil
        }

        return try String(contentsOfFile: path, encoding: .utf8)
    }

    // MARK: - Query Execution

    func execute(_ sql: String, parameters: [Any] = []) throws {
        guard let db = database else {
            throw DatabaseError.failedToOpenDatabase
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.failedToExecuteQuery("Prepare failed")
        }

        defer { sqlite3_finalize(statement) }

        try bind(parameters: parameters, to: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            let message = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.failedToExecuteQuery(message)
        }
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

    func queryAsJSON(_ sql: String, parameters: [Any] = []) throws -> [[String: Any]] {
        guard let db = database else {
            throw DatabaseError.failedToOpenDatabase
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.failedToExecuteQuery("Prepare failed")
        }

        defer { sqlite3_finalize(statement) }

        try bind(parameters: parameters, to: statement)

        var results: [[String: Any]] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let columnCount = sqlite3_column_count(statement)
            var row: [String: Any] = [:]

            for i in 0..<columnCount {
                let columnName = String(cString: sqlite3_column_name(statement, i))

                switch sqlite3_column_type(statement, i) {
                case SQLITE_TEXT:
                    row[columnName] = String(cString: sqlite3_column_text(statement, i))
                case SQLITE_INTEGER:
                    row[columnName] = sqlite3_column_int64(statement, i)
                case SQLITE_FLOAT:
                    row[columnName] = sqlite3_column_double(statement, i)
                case SQLITE_BLOB:
                    let dataSize = Int(sqlite3_column_bytes(statement, i))
                    if dataSize > 0, let dataPtr = sqlite3_column_blob(statement, i) {
                        row[columnName] = Data(bytes: dataPtr, count: dataSize)
                    } else {
                        row[columnName] = Data()
                    }
                default:
                    row[columnName] = NSNull()
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
