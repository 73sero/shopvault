import Foundation
import Combine

@MainActor
class IncomeListViewModel: ObservableObject {
    @Published var incomeEntries: [IncomeEntry] = []
    @Published var searchText = ""
    @Published var selectedCategory: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let incomeRepository: IncomeRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(incomeRepository: IncomeRepository) {
        self.incomeRepository = incomeRepository
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshEntries()
            }
            .store(in: &cancellables)
        
        $selectedCategory
            .sink { [weak self] _ in
                self?.refreshEntries()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadEntries(userId: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let entries = try await incomeRepository.getEntriesForUser(userId)
                self.incomeEntries = entries
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func deleteEntry(_ entry: IncomeEntry) {
        Task {
            do {
                try await incomeRepository.deleteEntry(entry.id)
                incomeEntries.removeAll { $0.id == entry.id }
            } catch {
                errorMessage = "Failed to delete: \(error.localizedDescription)"
            }
        }
    }
    
    func refreshEntries() {
        let filtered = filteredEntries
        incomeEntries = filtered
    }
    
    // MARK: - Computed Properties
    
    var filteredEntries: [IncomeEntry] {
        var result = incomeEntries
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.source.localizedCaseInsensitiveContains(searchText) ||
                $0.notes?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
        
        if let categoryId = selectedCategory {
            result = result.filter { $0.categoryId == categoryId }
        }
        
        return result.sorted { $0.date > $1.date }
    }
    
    var totalAmount: Decimal {
        filteredEntries.reduce(0) { $0 + $1.amount }
    }
    
    var totalFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: totalAmount)) ?? "$0.00"
    }
}
