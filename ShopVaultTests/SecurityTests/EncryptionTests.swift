import XCTest
@testable import ShopVault

final class EncryptionTests: XCTestCase {
    
    var sut: EncryptionManager!
    
    override func setUp() {
        super.setUp()
        sut = EncryptionManager()
    }
    
    override func tearDown() {
        super.tearDown()
        sut = nil
    }
    
    // MARK: - Encryption / Decryption Tests
    
    func testEncryptDecrypt_roundTrip_producesOriginalData() throws {
        // Given
        let originalData = "Sensitive financial data".data(using: .utf8)!
        let key = Data((0..<32).map { _ in UInt8.random(in: 0..<255) })
        
        // When
        let encrypted = try EncryptionManager.encrypt(data: originalData, key: key)
        let decrypted = try EncryptionManager.decrypt(data: encrypted, key: key)
        
        // Then
        XCTAssertEqual(decrypted, originalData)
    }
    
    func testEncrypt_differentKeys_producesDifferentCiphertexts() throws {
        // Given
        let data = "Test data".data(using: .utf8)!
        let key1 = Data((0..<32).map { _ in UInt8.random(in: 0..<255) })
        let key2 = Data((0..<32).map { _ in UInt8.random(in: 0..<255) })
        
        // When
        let encrypted1 = try EncryptionManager.encrypt(data: data, key: key1)
        let encrypted2 = try EncryptionManager.encrypt(data: data, key: key2)
        
        // Then
        XCTAssertNotEqual(encrypted1, encrypted2)
    }
    
    func testDecrypt_wrongKey_throwsError() throws {
        // Given
        let data = "Test data".data(using: .utf8)!
        let correctKey = Data((0..<32).map { _ in UInt8.random(in: 0..<255) })
        let wrongKey = Data((0..<32).map { _ in UInt8.random(in: 0..<255) })
        let encrypted = try EncryptionManager.encrypt(data: data, key: correctKey)
        
        // Then
        XCTAssertThrowsError(try EncryptionManager.decrypt(data: encrypted, key: wrongKey))
    }
    
    func testEncrypt_invalidKeyLength_throwsError() throws {
        // Given
        let data = "Test".data(using: .utf8)!
        let invalidKey = Data((0..<16).map { _ in UInt8.random(in: 0..<255) }) // 16 bytes, not 32
        
        // Then
        XCTAssertThrowsError(try EncryptionManager.encrypt(data: data, key: invalidKey))
    }
    
    // MARK: - Key Derivation Tests
    
    func testDeriveKey_samePassword_producesSameKey() throws {
        // Given
        let password = "MySecurePassword123"
        let salt = Data((0..<16).map { _ in UInt8.random(in: 0..<255) })
        
        // When
        let (key1, _) = try EncryptionManager.deriveKey(from: password, salt: salt)
        let (key2, _) = try EncryptionManager.deriveKey(from: password, salt: salt)
        
        // Then
        XCTAssertEqual(key1, key2)
    }
    
    func testDeriveKey_producesValidLength() throws {
        // Given
        let password = "TestPassword"
        
        // When
        let (key, _) = try EncryptionManager.deriveKey(from: password)
        
        // Then
        XCTAssertEqual(key.count, 32) // 32 bytes for AES-256
    }
    
    func testDeriveKey_generatesSalt() throws {
        // Given
        let password = "TestPassword"
        
        // When
        let (_, salt1) = try EncryptionManager.deriveKey(from: password)
        let (_, salt2) = try EncryptionManager.deriveKey(from: password)
        
        // Then
        XCTAssertEqual(salt1.count, 16)
        XCTAssertNotEqual(salt1, salt2) // Different salts
    }
}
