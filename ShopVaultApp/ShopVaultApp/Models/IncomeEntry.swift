import Foundation

struct IncomeEntry: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let amount: Decimal
    let source: String
    let categoryId: String
    let date: Date
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        amount: Decimal,
        source: String,
        categoryId: String,
        date: Date = Date(),
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.amount = amount
        self.source = source
        self.categoryId = categoryId
        self.date = date
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Format amount for display
    func formattedAmount(currencyCode: String, localeIdentifier: String) -> String {
        AppFormatters.currency(amount, currencyCode: currencyCode, localeIdentifier: localeIdentifier)
    }
    
    /// Format date for display
    func formattedDate(localeIdentifier: String) -> String {
        AppFormatters.mediumDate(date, localeIdentifier: localeIdentifier)
    }
}

extension IncomeEntry {
    /// Sample data for preview/testing
    static let sample = IncomeEntry(
        userId: "user-1",
        amount: 250.00,
        source: "Freelance Project",
        categoryId: "cat-1",
        date: Date(),
        notes: "Web design work"
    )
    
    static let samples = [
        IncomeEntry(
            userId: "user-1",
            amount: 250.00,
            source: "Freelance",
            categoryId: "cat-1",
            date: Date().addingTimeInterval(-86400),
            notes: "Web design"
        ),
        IncomeEntry(
            userId: "user-1",
            amount: 150.00,
            source: "Passive Income",
            categoryId: "cat-2",
            date: Date(),
            notes: "App revenue"
        ),
        IncomeEntry(
            userId: "user-1",
            amount: 500.00,
            source: "Contract Work",
            categoryId: "cat-1",
            date: Date().addingTimeInterval(86400 * 2),
            notes: "3-month engagement"
        )
    ]
}
