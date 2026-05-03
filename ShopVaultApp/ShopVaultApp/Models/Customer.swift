import Foundation

struct Customer: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let name: String
    let phone: String?
    let email: String?
    let address: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        phone: String? = nil,
        email: String? = nil,
        address: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.phone = phone
        self.email = email
        self.address = address
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Customer {
    /// Sample data for preview/testing
    static let sample = Customer(
        userId: "user-1",
        name: "John Doe",
        phone: "+49 123 456789",
        email: "john@example.com"
    )

    static let samples = [
        Customer(
            userId: "user-1",
            name: "John Doe",
            phone: "+49 123 456789",
            email: "john@example.com"
        ),
        Customer(
            userId: "user-1",
            name: "Jane Smith",
            phone: "+49 987 654321",
            address: "Berlin, Germany"
        ),
        Customer(
            userId: "user-1",
            name: "Walk-in Customer",
            notes: "Regular weekly customer"
        )
    ]
}
