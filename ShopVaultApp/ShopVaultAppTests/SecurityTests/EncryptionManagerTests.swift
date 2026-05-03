import XCTest
@testable import ShopVault

class EncryptionManagerTests: XCTestCase {
    
    var encryptionKey: Data!
    
    override func setUp() {
        super.setUp()
        // Generate 32-byte key for AES-256
        encryptionKey = Data((0..<32).map { _ in UInt8.random(in: 0..<255) })
    }
    
    // MARK: - AES-256-GCM Tests
    
    func testEncryptionAndDecryption() throws {
        let plaintext = "This is sensitive financial data".data(using: .utf8)!
        
        let encrypted = try EncryptionManager.encrypt(data: plaintext, key: encryptionKey)
        let decrypted = try EncryptionManager.decrypt(data: encrypted, key: encryptionKey)
        
        XCTAssertEqual(plaintext, decrypted)
    }
    
    func testEncryptionProducesDifferentOutput() throws {
        let plaintext = "Same data".data(using: .utf8)!
        
        let encrypted1 = try EncryptionManager.encrypt(data: plaintext, key: encryptionKey)
        let encrypted2 = try EncryptionManager.encrypt(data: plaintext, key: encryptionKey)
        
        // Different nonces = different ciphertext (expected)
        XCTAssertNotEqual(encrypted1, encrypted2)
    }
    
    func testDecryptionWithWrongKey() throws {
        let plaintext = "Secret".data(using: .utf8)!
        let encrypted = try EncryptionManager.encrypt(data: plaintext, key: encryptionKey)
        
        let wrongKey = Data((0..<32).map { _ in UInt8.random(in: 0..<255) })
        
        XCTAssertThrowsError(try EncryptionManager.decrypt(data: encrypted, key: wrongKey))
    }
    
    func testInvalidKeySize() throws {
        let plaintext = "Data".data(using: .utf8)!
        let invalidKey = Data((0..<16).map { _ in UInt8(1) })  // 16 bytes instead of 32
        
        XCTAssertThrowsError(try EncryptionManager.encrypt(data: plaintext, key: invalidKey))
    }
    
    // MARK: - Key Derivation Tests
    
    func testKeyDerivation() throws {
        let password = "MySecurePassword123"
        
        let (key1, salt1) = try EncryptionManager.deriveKey(from: password)
        let (key2, salt2) = try EncryptionManager.deriveKey(from: password)
        
        // Different salts = different keys
        XCTAssertNotEqual(salt1, salt2)
        XCTAssertNotEqual(key1, key2)
        
        // Keys should be 32 bytes
        XCTAssertEqual(key1.count, 32)
        XCTAssertEqual(key2.count, 32)
    }
    
    func testKeyDerivationWithSameSalt() throws {
        let password = "TestPassword"
        let salt = Data((0..<16).map { _ in UInt8(42) })
        
        let (key1, _) = try EncryptionManager.deriveKey(from: password, salt: salt)
        let (key2, _) = try EncryptionManager.deriveKey(from: password, salt: salt)
        
        // Same password + same salt = same key
        XCTAssertEqual(key1, key2)
    }
}
