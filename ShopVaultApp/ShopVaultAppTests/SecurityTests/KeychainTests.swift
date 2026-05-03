import XCTest
@testable import ShopVault

final class KeychainTests: XCTestCase {
    
    var sut: KeychainManager!
    
    override func setUp() {
        super.setUp()
        sut = KeychainManager()
        try? sut.deleteDBEncryptionKey()
    }
    
    override func tearDown() {
        try? sut.deleteDBEncryptionKey()
        super.tearDown()
        sut = nil
    }
    
    // MARK: - Key Storage Tests
    
    func testStoreAndRetrieveKey_roundTrip_succeeds() throws {
        // Given
        let originalKey = Data((0..<32).map { _ in UInt8.random(in: 0..<255) })
        
        // When
        try sut.storeDBEncryptionKey(originalKey)
        let retrievedKey = try sut.retrieveDBEncryptionKey()
        
        // Then
        XCTAssertEqual(retrievedKey, originalKey)
    }
    
    func testHasDBEncryptionKey_afterStore_returnsTrue() throws {
        // Given
        let key = Data((0..<32).map { _ in UInt8.random(in: 0..<255) })
        
        // When
        try sut.storeDBEncryptionKey(key)
        let hasKey = sut.hasDBEncryptionKey()
        
        // Then
        XCTAssertTrue(hasKey)
    }
    
    func testRetrieveKey_notFound_throwsError() throws {
        // Given
        let hasKey = sut.hasDBEncryptionKey()
        
        // If key doesn't exist, retrieval should fail
        if !hasKey {
            // Then
            XCTAssertThrowsError(try sut.retrieveDBEncryptionKey())
        }
    }
    
    // MARK: - PIN Hash Tests
    
    func testHashPIN_nonempty_returnsHash() {
        // Given
        let pin = "123456"
        
        // When
        let hash = sut.hashPIN(pin)
        
        // Then
        XCTAssertFalse(hash.isEmpty)
        XCTAssertNotEqual(hash, pin) // Hash ≠ plaintext
    }
    
    func testHashPIN_samePINdifferentResults_uniqueSalts() {
        // Given
        let pin = "123456"
        
        // When
        let hash1 = sut.hashPIN(pin)
        let hash2 = sut.hashPIN(pin)
        
        // Then
        XCTAssertNotEqual(hash1, hash2) // Different salts
    }
    
}
