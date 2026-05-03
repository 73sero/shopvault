import XCTest
@testable import ShopVault

@MainActor
final class DashboardViewModelTests: XCTestCase {
    
    var sut: DashboardViewModel!
    var mockRepository: MockDashboardIncomeRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockDashboardIncomeRepository()
        sut = DashboardViewModel(incomeRepository: mockRepository)
    }
    
    override func tearDown() {
        super.tearDown()
        sut = nil
        mockRepository = nil
    }
    
    // MARK: - Tests
    
    func testLoadDashboardData_withEntries_calculatesWeeklyTotal() async {
        // Given
        let userId = "user-1"
        let entries = IncomeEntry.samples
        mockRepository.stubbedEntries = entries
        
        // When
        sut.loadDashboardData(userId: userId)
        await Task.yield()
        
        // Then
        XCTAssertFalse(sut.isLoading)
        XCTAssertGreaterThan(sut.weeklyTotal, 0)
    }
    
    func testLoadDashboardData_withEntries_calculatesMonthlyTotal() async {
        // Given
        let userId = "user-1"
        let entries = IncomeEntry.samples
        mockRepository.stubbedEntries = entries
        
        // When
        sut.loadDashboardData(userId: userId)
        await Task.yield()
        
        // Then
        XCTAssertGreaterThan(sut.monthlyTotal, 0)
    }
    
    func testLoadDashboardData_emptyEntries_totalsAreZero() async {
        // Given
        let userId = "user-1"
        mockRepository.stubbedEntries = []
        
        // When
        sut.loadDashboardData(userId: userId)
        await Task.yield()
        
        // Then
        XCTAssertEqual(sut.weeklyTotal, 0)
        XCTAssertEqual(sut.monthlyTotal, 0)
    }
    
    func testCategoryBreakdown_groupsByCategory() async {
        // Given
        let userId = "user-1"
        let entries = IncomeEntry.samples
        mockRepository.stubbedEntries = entries
        
        // When
        sut.loadDashboardData(userId: userId)
        await Task.yield()
        
        // Then
        XCTAssertGreaterThan(sut.categoryBreakdown.count, 0)
        let totalPercentage = sut.categoryBreakdown.reduce(0) { $0 + $1.percentage }
        XCTAssertEqual(totalPercentage, 100, accuracy: 1.0)
    }
    
    func testFormattedCurrency_returnsValidFormat() {
        let formatted = sut.weeklyTotalFormatted(currencyCode: "USD", localeIdentifier: "en_US")
        XCTAssertTrue(formatted.contains("$"))
    }
}

// MARK: - Mock Repository

final class MockDashboardIncomeRepository: IncomeRepositoryProtocol, @unchecked Sendable {
    var stubbedEntries: [IncomeEntry] = []
    
    func getEntriesForUser(_ userId: String) async throws -> [IncomeEntry] {
        return stubbedEntries
    }
    
    func getEntryById(_ id: String) async throws -> IncomeEntry? {
        return stubbedEntries.first(where: { $0.id == id })
    }
    
    func getEntriesByDateRange(_ userId: String, from: Date, to: Date) async throws -> [IncomeEntry] {
        return stubbedEntries.filter { $0.date >= from && $0.date <= to }
    }

    func getEntriesByCategory(_ userId: String, categoryId: String) async throws -> [IncomeEntry] {
        return stubbedEntries.filter { $0.categoryId == categoryId }
    }
    
    func saveEntry(_ entry: IncomeEntry) async throws {
        stubbedEntries.append(entry)
    }
    
    func updateEntry(_ entry: IncomeEntry) async throws {
        // Stub
    }
    
    func deleteEntry(_ id: String) async throws {
        stubbedEntries.removeAll { $0.id == id }
    }
}
