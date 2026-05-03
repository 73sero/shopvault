import Foundation

struct User: Identifiable, Codable, Hashable {
    let id: String
    let biometricEnabled: Bool
    let pinHash: String?  // PBKDF2 hashed PIN (optional)
    let createdAt: Date
    let updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        biometricEnabled: Bool = true,
        pinHash: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.biometricEnabled = biometricEnabled
        self.pinHash = pinHash
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension User {
    static let sample = User(
        id: "user-1",
        biometricEnabled: true
    )
}
