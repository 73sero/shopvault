import Foundation

struct Category: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let name: String
    let color: String  // Hex color, e.g. "#4CAF50"
    let isActive: Bool
    let createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        color: String = "#4CAF50",
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.color = color
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

extension Category {
    /// Default categories for new users
    static func defaultCategories(userId: String) -> [Category] {
        [
            Category(userId: userId, name: "Freelance", color: "#2196F3"),
            Category(userId: userId, name: "Passive Income", color: "#4CAF50"),
            Category(userId: userId, name: "Salary", color: "#FF9800"),
            Category(userId: userId, name: "Other", color: "#9C27B0")
        ]
    }
    
    static let sample = Category(
        userId: "user-1",
        name: "Freelance",
        color: "#2196F3"
    )
}
