import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var weeklyTotal: Decimal = 0
    @Published var monthlyTotal: Decimal = 0
    @Published var dailyAverage: Decimal = 0
    @Published var categoryBreakdown: [(name: String, amount: Decimal, percentage: Double)] = []
    @Published var recentEntries: [IncomeEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let incomeRepository: IncomeRepositoryProtocol
    
    init(incomeRepository: IncomeRepositoryProtocol) {
        self.incomeRepository = incomeRepository
    }
    
    // MARK: - Public Methods
    
    func loadDashboardData(userId: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let entries = try await incomeRepository.getEntriesForUser(userId)
                
                // Calculate totals
                weeklyTotal = calculateWeeklyTotal(entries)
                monthlyTotal = calculateMonthlyTotal(entries)
                dailyAverage = calculateDailyAverage(entries)
                
                // Calculate category breakdown
                categoryBreakdown = calculateCategoryBreakdown(entries)
                
                // Get recent entries (last 5)
                recentEntries = Array(entries.sorted { $0.date > $1.date }.prefix(5))
                
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    // MARK: - Calculations
    
    private func calculateWeeklyTotal(_ entries: [IncomeEntry]) -> Decimal {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        
        return entries
            .filter { $0.date >= startOfWeek }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func calculateMonthlyTotal(_ entries: [IncomeEntry]) -> Decimal {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        
        return entries
            .filter { $0.date >= startOfMonth }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func calculateDailyAverage(_ entries: [IncomeEntry]) -> Decimal {
        guard !entries.isEmpty else { return 0 }
        
        let total = entries.reduce(0) { $0 + $1.amount }
        let daysCount = max(1, daysDifference(from: entries.map { $0.date }.min() ?? Date(), to: Date()))
        
        return total / Decimal(daysCount)
    }
    
    private func calculateCategoryBreakdown(_ entries: [IncomeEntry]) -> [(name: String, amount: Decimal, percentage: Double)] {
        let grouped = Dictionary(grouping: entries, by: { $0.categoryId })
        let total = entries.reduce(0) { $0 + $1.amount }
        
        return grouped.map { (categoryId, categoryEntries) in
            let amount = categoryEntries.reduce(0) { $0 + $1.amount }
            let percentage = total > 0 ? Double(NSDecimalNumber(decimal: amount).doubleValue / NSDecimalNumber(decimal: total).doubleValue * 100) : 0
            
            return (
                name: categoryId,
                amount: amount,
                percentage: percentage
            )
        }.sorted { $0.amount > $1.amount }
    }
    
    private func daysDifference(from: Date, to: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: from, to: to)
        return components.day ?? 0
    }
    
    // MARK: - Formatted Output
    
    func weeklyTotalFormatted(currencyCode: String, localeIdentifier: String) -> String {
        formatCurrency(weeklyTotal, currencyCode: currencyCode, localeIdentifier: localeIdentifier)
    }
    
    func monthlyTotalFormatted(currencyCode: String, localeIdentifier: String) -> String {
        formatCurrency(monthlyTotal, currencyCode: currencyCode, localeIdentifier: localeIdentifier)
    }
    
    func dailyAverageFormatted(currencyCode: String, localeIdentifier: String) -> String {
        formatCurrency(dailyAverage, currencyCode: currencyCode, localeIdentifier: localeIdentifier)
    }
    
    private func formatCurrency(_ amount: Decimal, currencyCode: String, localeIdentifier: String) -> String {
        AppFormatters.currency(amount, currencyCode: currencyCode, localeIdentifier: localeIdentifier)
    }
}
