import Foundation
import Security
import CommonCrypto

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

class KeychainManager {
    private static let service = "com.shopvault.security"
    private static let dbEncryptionKeyTag = "com.shopvault.db.encryption.key"
    private let pinHashService = PinHashService()

    // MARK: - Key Management

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

    func hasDBEncryptionKey() -> Bool {
        let query = baseQuery(account: Self.dbEncryptionKeyTag)
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - PIN Management

    func hashPIN(_ pin: String, length: Int? = nil) -> String {
        pinHashService.hash(pin: pin, length: length ?? pin.count)
    }

    func verifyPIN(_ pin: String, matches storedHash: String) -> Bool {
        pinHashService.verify(pin: pin, storedHash: storedHash)
    }

    func pinLength(from storedHash: String?) -> Int {
        pinHashService.pinLength(from: storedHash)
    }

    func deriveAndStoreKeyFromPIN(_ pin: String) throws {
        guard let pinData = pin.data(using: .utf8) else {
            throw KeychainError.dataEncodingFailed
        }

        let salt = Data((0..<16).map { _ in UInt8.random(in: 0...UInt8.max) })
        let key = try PBKDF2(password: pinData, salt: salt, iterations: 100_000, length: 32)
        try storeDBEncryptionKey(key)
    }

    // MARK: - Private

    private func PBKDF2(password: Data, salt: Data, iterations: Int, length: Int) throws -> Data {
        var result = [UInt8](repeating: 0, count: length)

        let status = password.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.baseAddress,
                    passwordBytes.count,
                    saltBytes.baseAddress,
                    saltBytes.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    &result,
                    length
                )
            }
        }

        guard status == kCCSuccess else {
            throw KeychainError.unexpectedStatus(OSStatus(status))
        }

        return Data(result)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account
        ]
    }
}
