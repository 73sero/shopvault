import Foundation
import Combine

@MainActor
class AddIncomeViewModel: ObservableObject {
    @Published var amount = ""
    @Published var source = ""
    @Published var selectedCategoryId: String?
    @Published var selectedDate = Date()
    @Published var notes = ""
    @Published var isSaving = false
    @Published var saveError: String?
    @Published var showSuccess = false
    
    private let incomeRepository: IncomeRepository
    private let categoryRepository: CategoryRepository
    
    var categories: [Category] = []
    
    init(
        incomeRepository: IncomeRepository,
        categoryRepository: CategoryRepository
    ) {
        self.incomeRepository = incomeRepository
        self.categoryRepository = categoryRepository
    }
    
    // MARK: - Public Methods
    
    func loadCategories(userId: String) {
        Task {
            do {
                categories = try await categoryRepository.getCategoriesForUser(userId)
                if selectedCategoryId == nil {
                    selectedCategoryId = categories.first?.id
                }
            } catch {
                saveError = "Failed to load categories"
            }
        }
    }
    
    func saveEntry(userId: String) {
        guard validateForm() else { return }
        
        isSaving = true
        saveError = nil
        
        Task {
            do {
                guard let categoryId = selectedCategoryId,
                      let decimalAmount = Decimal(string: amount) else {
                    saveError = "Invalid input"
                    isSaving = false
                    return
                }
                
                let entry = IncomeEntry(
                    userId: userId,
                    amount: decimalAmount,
                    source: source.trimmingCharacters(in: .whitespaces),
                    categoryId: categoryId,
                    date: selectedDate,
                    notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
                )
                
                try await incomeRepository.saveEntry(entry)
                showSuccess = true
                resetForm()
                isSaving = false
            } catch {
                saveError = error.localizedDescription
                isSaving = false
            }
        }
    }
    
    // MARK: - Validation
    
    func validateForm() -> Bool {
        guard !amount.isEmpty else {
            saveError = "Amount required"
            return false
        }
        
        guard Decimal(string: amount) != nil else {
            saveError = "Invalid amount format"
            return false
        }
        
        guard !source.isEmpty else {
            saveError = "Source required"
            return false
        }
        
        guard selectedCategoryId != nil else {
            saveError = "Category required"
            return false
        }
        
        return true
    }
    
    var isFormValid: Bool {
        !amount.isEmpty && !source.isEmpty && selectedCategoryId != nil
    }
    
    // MARK: - Private
    
    private func resetForm() {
        amount = ""
        source = ""
        notes = ""
        selectedDate = Date()
        selectedCategoryId = categories.first?.id
    }
}
