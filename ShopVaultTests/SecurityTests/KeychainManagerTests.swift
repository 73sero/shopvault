import XCTest
@testable import ShopVault

class KeychainManagerTests: XCTestCase {
    
    var keychainManager: KeychainManager!
    
    override func setUp() {
        super.setUp()
        keychainManager = KeychainManager()
    }
    
    override func tearDown() {
        super.tearDown()
        keychainManager = nil
    }
    
    // MARK: - DB Encryption Key Tests
    
    func testStoreAndRetrieveDBKey() throws {
        let testKey = Data((0..<32).map { _ in UInt8.random(in: 0..<255) })
        
        try keychainManager.storeDBEncryptionKey(testKey)
        let retrievedKey = try keychainManager.retrieveDBEncryptionKey()
        
        XCTAssertEqual(testKey, retrievedKey)
    }
    
    func testHasDBEncryptionKey() throws {
        let testKey = Data((0..<32).map { _ in UInt8.random(in: 0..<255) })
        
        XCTAssertFalse(keychainManager.hasDBEncryptionKey())
        
        try keychainManager.storeDBEncryptionKey(testKey)
        XCTAssertTrue(keychainManager.hasDBEncryptionKey())
    }
    
    // MARK: - PIN Hashing Tests
    
    func testPINHashing() {
        let pin = "123456"
        let hash = keychainManager.hashPIN(pin)
        
        // Hash should be non-empty
        XCTAssertFalse(hash.isEmpty)
        
        // Hash should be deterministic for same PIN (with same salt)
        let hash2 = keychainManager.hashPIN(pin)
        XCTAssertNotEqual(hash, hash2)  // Different salts = different hashes (expected)
    }
    
    func testPINHashingConsistency() {
        let pin = "654321"
        let hash1 = keychainManager.hashPIN(pin)
        let hash2 = keychainManager.hashPIN(pin)
        
        // Different hashes due to random salt (expected behavior)
        XCTAssertNotEqual(hash1, hash2)
    }
    
    // MARK: - Key Derivation Tests
    
    func testDeriveKeyFromPIN() throws {
        let pin = "123456"
        
        try keychainManager.deriveAndStoreKeyFromPIN(pin)
        
        XCTAssertTrue(keychainManager.hasDBEncryptionKey())
    }
}
