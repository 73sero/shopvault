import Foundation

enum PIIEncryption {
    private static let keychainManager = KeychainManager()

    /// Encrypts a string for storage. Returns base64-encoded ciphertext.
    static func encrypt(_ plaintext: String?) throws -> String? {
        guard let plaintext = plaintext, !plaintext.isEmpty else { return nil }
        let key = try keychainManager.retrieveDBEncryptionKey()
        let data = Data(plaintext.utf8)
        let encrypted = try EncryptionManager.encrypt(data: data, key: key)
        return encrypted.base64EncodedString()
    }

    /// Decrypts a base64-encoded ciphertext string. Returns nil for corrupted data.
    static func decrypt(_ ciphertext: String?) throws -> String? {
        guard let ciphertext = ciphertext, !ciphertext.isEmpty else { return nil }
        let key = try keychainManager.retrieveDBEncryptionKey()
        guard let data = Data(base64Encoded: ciphertext) else { return nil }
        let decrypted = try EncryptionManager.decrypt(data: data, key: key)
        return String(data: decrypted, encoding: .utf8)
    }
}
