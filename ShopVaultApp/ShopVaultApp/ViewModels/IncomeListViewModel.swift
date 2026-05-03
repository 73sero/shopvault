import Foundation
import Combine

@MainActor
class IncomeListViewModel: ObservableObject {
    @Published var incomeEntries: [IncomeEntry] = []
    @Published var searchText = ""
    @Published var selectedCategory: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var pendingDeletionEntry: IncomeEntry?
    
    private let incomeRepository: IncomeRepository
    private var pendingDeletionTask: Task<Void, Never>?
    
    init(incomeRepository: IncomeRepository) {
        self.incomeRepository = incomeRepository
    }
    
    // MARK: - Public Methods
    
    func loadEntries(userId: String) {
        isLoading = true
        errorMessage = nil
        pendingDeletionTask?.cancel()
        pendingDeletionTask = nil
        pendingDeletionEntry = nil
        
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
            await commitPendingDeletionIfNeeded()
            stageDeletion(entry)
        }
    }

    func undoPendingDeletion() {
        guard let pendingDeletionEntry else {
            return
        }

        pendingDeletionTask?.cancel()
        pendingDeletionTask = nil
        self.pendingDeletionEntry = nil
        restoreEntry(pendingDeletionEntry)
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

    var groupedEntriesByMonth: [(monthStart: Date, entries: [IncomeEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            let components = calendar.dateComponents([.year, .month], from: entry.date)
            return calendar.date(from: components) ?? entry.date
        }

        return grouped
            .map { (monthStart: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.monthStart > $1.monthStart }
    }
    
    func totalFormatted(currencyCode: String, localeIdentifier: String) -> String {
        AppFormatters.currency(totalAmount, currencyCode: currencyCode, localeIdentifier: localeIdentifier)
    }

    // MARK: - Private

    private func stageDeletion(_ entry: IncomeEntry) {
        incomeEntries.removeAll { $0.id == entry.id }
        pendingDeletionEntry = entry
        pendingDeletionTask?.cancel()

        pendingDeletionTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else {
                return
            }

            await commitPendingDeletionIfNeeded()
        }
    }

    private func commitPendingDeletionIfNeeded() async {
        guard let entry = pendingDeletionEntry else {
            return
        }

        pendingDeletionTask?.cancel()
        pendingDeletionTask = nil

        do {
            try await incomeRepository.deleteEntry(entry.id)
            NotificationCenter.default.post(name: .incomeEntriesDidChange, object: nil)
        } catch {
            restoreEntry(entry)
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }

        if pendingDeletionEntry?.id == entry.id {
            pendingDeletionEntry = nil
        }
    }

    private func restoreEntry(_ entry: IncomeEntry) {
        guard !incomeEntries.contains(where: { $0.id == entry.id }) else {
            return
        }

        incomeEntries.append(entry)
        incomeEntries.sort { $0.date > $1.date }
    }
}
