import XCTest
@testable import ShopVault

class AddIncomeViewModelTests: XCTestCase {
    
    var viewModel: AddIncomeViewModel!
    var mockIncomeRepository: MockIncomeRepository!
    var mockCategoryRepository: MockCategoryRepository!
    
    override func setUp() {
        super.setUp()
        mockIncomeRepository = MockIncomeRepository()
        mockCategoryRepository = MockCategoryRepository()
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
        await viewModel.loadCategories(userId: userId)
        
        XCTAssertEqual(viewModel.categories.count, mockCategoryRepository.categories.count)
        XCTAssertNotNil(viewModel.selectedCategoryId)
    }
    
    // MARK: - Save Entry Tests
    
    func testSaveEntry_Success() async {
        viewModel.amount = "250.00"
        viewModel.source = "Freelance"
        viewModel.selectedCategoryId = "cat-1"
        
        await viewModel.saveEntry(userId: "user-1")
        
        XCTAssertTrue(viewModel.showSuccess)
        XCTAssertNil(viewModel.saveError)
    }
}

// MARK: - Mock Repositories

class MockIncomeRepository: IncomeRepository {
    var savedEntry: IncomeEntry?
    
    override func saveEntry(_ entry: IncomeEntry) async throws {
        self.savedEntry = entry
    }
}

class MockCategoryRepository: CategoryRepository {
    let categories = [
        Category(id: "cat-1", userId: "user-1", name: "Freelance"),
        Category(id: "cat-2", userId: "user-1", name: "Passive")
    ]
    
    override func getCategoriesForUser(_ userId: String) async throws -> [Category] {
        return categories
    }
}
