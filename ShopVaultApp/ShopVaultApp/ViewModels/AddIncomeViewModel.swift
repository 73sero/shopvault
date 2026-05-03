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
    @Published var successMessage: String?
    @Published var currentEntryId: String?
    
    private let incomeRepository: IncomeRepositoryProtocol
    private let categoryRepository: CategoryRepositoryProtocol
    private var localeIdentifier = "en_US"

    @Published var categories: [Category] = []

    init(
        incomeRepository: IncomeRepositoryProtocol,
        categoryRepository: CategoryRepositoryProtocol
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
                saveError = t("failed_to_load_categories")
            }
        }
    }

    func setLocale(_ localeIdentifier: String) {
        self.localeIdentifier = localeIdentifier
        normalizeAmountInput()
    }

    func normalizeAmountInput() {
        amount = AppFormatters.normalizeDecimalInput(amount, localeIdentifier: localeIdentifier)
    }
    
    func saveEntry(userId: String) {
        guard validateForm() else { return }
        
        isSaving = true
        saveError = nil
        successMessage = nil
        
        Task {
            do {
                guard let categoryId = selectedCategoryId,
                      let decimalAmount = amountDecimal else {
                    saveError = t("invalid_input")
                    isSaving = false
                    return
                }
                
                let entry = IncomeEntry(
                    id: currentEntryId ?? UUID().uuidString,
                    userId: userId,
                    amount: decimalAmount,
                    source: source.trimmingCharacters(in: .whitespaces),
                    categoryId: categoryId,
                    date: selectedDate,
                    notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces),
                    createdAt: Date(),
                    updatedAt: Date()
                )

                if currentEntryId == nil {
                    try await incomeRepository.saveEntry(entry)
                    currentEntryId = entry.id
                    successMessage = t("entry_saved_continue_editing")
                } else {
                    try await incomeRepository.updateEntry(entry)
                    successMessage = t("changes_saved")
                }

                NotificationCenter.default.post(name: .incomeEntriesDidChange, object: nil)
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
            saveError = t("amount_required")
            return false
        }
        
        guard amountDecimal != nil else {
            saveError = t("invalid_amount_format")
            return false
        }
        
        guard !source.isEmpty else {
            saveError = t("source_required")
            return false
        }
        
        guard selectedCategoryId != nil else {
            saveError = t("category_required")
            return false
        }
        
        return true
    }
    
    var isFormValid: Bool {
        amountDecimal != nil && !source.isEmpty && selectedCategoryId != nil
    }

    var amountDecimalSeparator: String {
        AppFormatters.decimalSeparator(localeIdentifier: localeIdentifier)
    }

    var saveButtonTitle: String {
        currentEntryId == nil ? t("save") : t("update")
    }
    
    // MARK: - Private
    
    private func resetForm() {
        amount = ""
        source = ""
        notes = ""
        selectedDate = Date()
        selectedCategoryId = categories.first?.id
        currentEntryId = nil
        successMessage = nil
    }

    func startNewEntry() {
        resetForm()
        saveError = nil
    }

    private func t(_ key: String) -> String {
        L10n.tr(key, localeIdentifier: localeIdentifier)
    }

    private var amountDecimal: Decimal? {
        AppFormatters.decimal(from: amount, localeIdentifier: localeIdentifier)
    }
}
