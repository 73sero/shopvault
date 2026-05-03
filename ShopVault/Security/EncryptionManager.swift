import Foundation
import CryptoKit
import CommonCrypto

enum EncryptionError: LocalizedError {
    case invalidKey
    case encryptionFailed
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Invalid encryption key"
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        }
    }
}

class EncryptionManager {
    private static let pbkdf2Iterations = 100_000
    private static let saltLength = 16
    
    // MARK: - AES-256-GCM Encryption/Decryption
    
    /// Encrypt data using AES-256-GCM
    static func encrypt(data: Data, key: Data) throws -> Data {
        guard key.count == 32 else {
            throw EncryptionError.invalidKey
        }
        
        let symmetricKey = SymmetricKey(data: key)
        let nonce = AES.GCM.Nonce()
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey, nonce: nonce)
            
            // Combine nonce + ciphertext + tag
            guard let combined = sealedBox.combined else {
                throw EncryptionError.encryptionFailed
            }
            
            return combined
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }
    
    /// Decrypt data using AES-256-GCM
    static func decrypt(data: Data, key: Data) throws -> Data {
        guard key.count == 32 else {
            throw EncryptionError.invalidKey
        }
        
        let symmetricKey = SymmetricKey(data: key)
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let plaintext = try AES.GCM.open(sealedBox, using: symmetricKey)
            return plaintext
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }
    
    // MARK: - Key Derivation
    
    /// Derive encryption key from password using PBKDF2
    static func deriveKey(from password: String, salt: Data? = nil) throws -> (key: Data, salt: Data) {
        guard let passwordData = password.data(using: .utf8) else {
            throw EncryptionError.invalidKey
        }
        
        let useSalt = salt ?? Data((0..<saltLength).map { _ in UInt8.random(in: 0...UInt8.max) })
        let key = try PBKDF2(
            password: passwordData,
            salt: useSalt,
            iterations: pbkdf2Iterations,
            length: 32
        )
        
        return (key: key, salt: useSalt)
    }
    
    // MARK: - Private Helpers
    
    private static func PBKDF2(password: Data, salt: Data, iterations: Int, length: Int) throws -> Data {
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
        
        guard status == 0 else {
            throw EncryptionError.encryptionFailed
        }
        
        return Data(result)
    }
}
