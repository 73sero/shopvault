import Foundation
import Security

enum KeychainError: LocalizedError {
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
    case dataEncodingFailed
    case invalidKey
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in Keychain"
        case .duplicateItem:
            return "Item already exists in Keychain"
        case .unexpectedStatus(let status):
            return "Keychain error: \(status)"
        case .dataEncodingFailed:
            return "Failed to encode data for Keychain"
        case .invalidKey:
            return "Invalid encryption key"
        }
    }
}

final class KeychainManager: @unchecked Sendable {
    private static let service = "com.shopvault.security"
    private static let dbEncryptionKeyTag = "com.shopvault.db.encryption.key"
    private let pinHashService = PinHashService()
    
    // MARK: - Key Management
    
    /// Store database encryption key in Keychain
    func storeDBEncryptionKey(_ key: Data) throws {
        guard key.count == 32 else {
            throw KeychainError.invalidKey
        }

        var query = baseQuery(account: Self.dbEncryptionKeyTag)
        query[kSecValueData as String] = key
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let addStatus = SecItemAdd(query as CFDictionary, nil)

        if addStatus == errSecDuplicateItem {
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: key,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]

            let updateStatus = SecItemUpdate(
                baseQuery(account: Self.dbEncryptionKeyTag) as CFDictionary,
                attributesToUpdate as CFDictionary
            )

            guard updateStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(updateStatus)
            }
            return
        }

        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }
    
    /// Retrieve database encryption key from Keychain
    func retrieveDBEncryptionKey() throws -> Data {
        var query = baseQuery(account: Self.dbEncryptionKeyTag)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }
        
        guard let data = result as? Data else {
            throw KeychainError.dataEncodingFailed
        }

        guard data.count == 32 else {
            throw KeychainError.invalidKey
        }
        
        return data
    }
    
    /// Check if encryption key exists
    func hasDBEncryptionKey() -> Bool {
        let query = baseQuery(account: Self.dbEncryptionKeyTag)
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

#if DEBUG
    /// Test-only helper. Deleting the DB key in production renders the SQLCipher database
    /// permanently unreadable, so this is gated behind DEBUG builds.
    func deleteDBEncryptionKey() throws {
        let status = SecItemDelete(baseQuery(account: Self.dbEncryptionKeyTag) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
#endif
    
    // MARK: - PIN Management
    
    /// Hash PIN with versioned format
    func hashPIN(_ pin: String, length: Int? = nil) -> String {
        pinHashService.hash(pin: pin, length: length ?? pin.count)
    }

    /// Verify PIN against stored hash (legacy compatible)
    func verifyPIN(_ pin: String, matches storedHash: String) -> Bool {
        pinHashService.verify(pin: pin, storedHash: storedHash)
    }

    func pinLength(from storedHash: String?) -> Int {
        pinHashService.pinLength(from: storedHash)
    }
    // MARK: - Private Helpers

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account
        ]
    }
}
