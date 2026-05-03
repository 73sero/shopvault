import XCTest
@testable import ShopVault

@MainActor
class AddIncomeViewModelTests: XCTestCase {
    
    var viewModel: AddIncomeViewModel!
    var mockIncomeRepository: MockAddIncomeRepository!
    var mockCategoryRepository: MockAddCategoryRepository!
    
    override func setUp() {
        super.setUp()
        mockIncomeRepository = MockAddIncomeRepository()
        mockCategoryRepository = MockAddCategoryRepository()
        viewModel = AddIncomeViewModel(
            incomeRepository: mockIncomeRepository,
            categoryRepository: mockCategoryRepository
        )
    }
    
    override func tearDown() {
        super.tearDown()
        viewModel = nil
        mockIncomeRepository = nil
        mockCategoryRepository = nil
    }
    
    // MARK: - Form Validation Tests
    
    func testFormValidation_EmptyAmount() {
        viewModel.amount = ""
        viewModel.source = "Test"
        viewModel.selectedCategoryId = "cat-1"
        
        XCTAssertFalse(viewModel.isFormValid)
    }
    
    func testFormValidation_EmptySource() {
        viewModel.amount = "100"
        viewModel.source = ""
        viewModel.selectedCategoryId = "cat-1"
        
        XCTAssertFalse(viewModel.isFormValid)
    }
    
    func testFormValidation_NoCategorySelected() {
        viewModel.amount = "100"
        viewModel.source = "Test"
        viewModel.selectedCategoryId = nil
        
        XCTAssertFalse(viewModel.isFormValid)
    }
    
    func testFormValidation_AllFieldsValid() {
        viewModel.amount = "250.50"
        viewModel.source = "Freelance"
        viewModel.selectedCategoryId = "cat-1"
        
        XCTAssertTrue(viewModel.isFormValid)
    }
    
    func testValidateForm_InvalidAmount() {
        viewModel.amount = "abc"
        let isValid = viewModel.validateForm()
        
        XCTAssertFalse(isValid)
        XCTAssertEqual(viewModel.saveError, "Invalid amount format")
    }
    
    // MARK: - Load Categories Tests
    
    func testLoadCategories() async {
        let userId = "user-1"
        viewModel.loadCategories(userId: userId)
        await Task.yield()
        
        XCTAssertEqual(viewModel.categories.count, mockCategoryRepository.categories.count)
        XCTAssertNotNil(viewModel.selectedCategoryId)
    }
    
    // MARK: - Save Entry Tests
    
    func testSaveEntry_Success() async {
        viewModel.amount = "250.00"
        viewModel.source = "Freelance"
        viewModel.selectedCategoryId = "cat-1"
        
        viewModel.saveEntry(userId: "user-1")
        await Task.yield()
        
        XCTAssertNotNil(viewModel.successMessage)
        XCTAssertNil(viewModel.saveError)
    }
}

// MARK: - Mock Repositories

final class MockAddIncomeRepository: IncomeRepositoryProtocol, @unchecked Sendable {
    var savedEntry: IncomeEntry?
    var stubbedEntries: [IncomeEntry] = []

    func saveEntry(_ entry: IncomeEntry) async throws {
        savedEntry = entry
        stubbedEntries.append(entry)
    }

    func getEntriesForUser(_ userId: String) async throws -> [IncomeEntry] {
        stubbedEntries.filter { $0.userId == userId }
    }

    func getEntryById(_ id: String) async throws -> IncomeEntry? {
        stubbedEntries.first { $0.id == id }
    }

    func getEntriesByDateRange(_ userId: String, from: Date, to: Date) async throws -> [IncomeEntry] {
        stubbedEntries.filter { $0.userId == userId && $0.date >= from && $0.date <= to }
    }

    func getEntriesByCategory(_ userId: String, categoryId: String) async throws -> [IncomeEntry] {
        stubbedEntries.filter { $0.userId == userId && $0.categoryId == categoryId }
    }

    func updateEntry(_ entry: IncomeEntry) async throws {
        if let index = stubbedEntries.firstIndex(where: { $0.id == entry.id }) {
            stubbedEntries[index] = entry
        }
        savedEntry = entry
    }

    func deleteEntry(_ id: String) async throws {
        stubbedEntries.removeAll { $0.id == id }
    }
}

final class MockAddCategoryRepository: CategoryRepositoryProtocol, @unchecked Sendable {
    let categories: [ShopVault.Category] = [
        ShopVault.Category(id: "cat-1", userId: "user-1", name: "Freelance"),
        ShopVault.Category(id: "cat-2", userId: "user-1", name: "Passive")
    ]

    func createCategory(_ category: ShopVault.Category) async throws {}

    func getCategoriesForUser(_ userId: String) async throws -> [ShopVault.Category] {
        return categories
    }

    func getCategoryById(_ id: String) async throws -> ShopVault.Category? {
        categories.first { $0.id == id }
    }

    func updateCategory(_ category: ShopVault.Category) async throws {}
    func deleteCategory(_ id: String) async throws {}
    func createDefaultCategories(for userId: String) async throws {}

    func ensureSalesCategory(for userId: String) async throws -> String {
        return "cat-sales"
    }
}
