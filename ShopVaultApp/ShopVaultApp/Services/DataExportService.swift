import Foundation

struct DataExportService {
    private let databaseManager: DatabaseManager

    init(databaseManager: DatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }

    func createEncryptedExport(passphrase: String) throws -> URL {
        let exportedAt = ISO8601DateFormatter().string(from: Date())
        let payload = try exportPayload(exportedAt: exportedAt)
        let payloadData = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )

        let derived = try EncryptionManager.deriveKey(from: passphrase)
        let encryptedPayload = try EncryptionManager.encrypt(
            data: payloadData,
            key: derived.key
        )

        let envelope: [String: Any] = [
            "format": "shopvault-encrypted-export",
            "version": 1,
            "generated_at": exportedAt,
            "kdf": [
                "name": EncryptionManager.kdfAlgorithm,
                "iterations": EncryptionManager.pbkdf2Iterations,
                "salt_base64": derived.salt.base64EncodedString(),
                "key_length_bytes": EncryptionManager.derivedKeyLength
            ],
            "cipher": [
                "name": "AES-256-GCM",
                "payload_encoding": "base64",
                "payload_layout": "CryptoKit combined nonce + ciphertext + tag"
            ],
            "payload_base64": encryptedPayload.base64EncodedString()
        ]

        let envelopeData = try JSONSerialization.data(
            withJSONObject: envelope,
            options: [.prettyPrinted, .sortedKeys]
        )

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShopVault-Export-\(fileTimestamp()).shopvault")
        try envelopeData.write(to: fileURL, options: .atomic)
        try secureExportFile(fileURL)

        return fileURL
    }

    private func exportPayload(exportedAt: String) throws -> [String: Any] {
        let tableNames = [
            "users",
            "categories",
            "app_settings",
            "income_entries",
            "products",
            "customers",
            "orders",
            "order_items",
            "supplier_deliveries",
            "delivery_items",
            "schema_version"
        ]

        var tables: [String: Any] = [:]
        for tableName in tableNames {
            let rawRows = try databaseManager.queryAsJSON("SELECT * FROM \(tableName)")
            let rows = try decryptPIIIfNeeded(tableName: tableName, rows: rawRows)
            let stripped = stripSensitiveColumns(tableName: tableName, rows: rows)
            tables[tableName] = stripped.map(sanitizeForJSON)
        }

        return [
            "format": "shopvault-export-payload",
            "version": 1,
            "exported_at": exportedAt,
            "pii": "customer phone, email, and address are decrypted inside this encrypted export",
            "stripped_columns": ["users.pin_hash"],
            "tables": tables
        ]
    }

    private func stripSensitiveColumns(
        tableName: String,
        rows: [[String: Any]]
    ) -> [[String: Any]] {
        guard tableName == "users" else { return rows }
        return rows.map { row in
            var copy = row
            copy.removeValue(forKey: "pin_hash")
            return copy
        }
    }

    private func decryptPIIIfNeeded(
        tableName: String,
        rows: [[String: Any]]
    ) throws -> [[String: Any]] {
        guard tableName == "customers" else { return rows }

        return try rows.map { row in
            var decryptedRow = row
            for field in ["phone", "email", "address"] {
                guard let encrypted = row[field] as? String, !encrypted.isEmpty else {
                    continue
                }
                decryptedRow[field] = try PIIEncryption.decrypt(encrypted) ?? NSNull()
            }
            return decryptedRow
        }
    }

    private func sanitizeForJSON(_ row: [String: Any]) -> [String: Any] {
        row.reduce(into: [:]) { result, pair in
            switch pair.value {
            case let data as Data:
                result[pair.key] = data.base64EncodedString()
            case is NSNull:
                result[pair.key] = NSNull()
            case let value as String:
                result[pair.key] = value
            case let value as Int:
                result[pair.key] = value
            case let value as Int64:
                result[pair.key] = value
            case let value as Double:
                result[pair.key] = value
            case let value as Bool:
                result[pair.key] = value
            default:
                result[pair.key] = String(describing: pair.value)
            }
        }
    }

    private func secureExportFile(_ fileURL: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = fileURL
        try mutableURL.setResourceValues(values)

        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: fileURL.path
        )
    }

    private func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
