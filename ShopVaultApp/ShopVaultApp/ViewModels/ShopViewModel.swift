import Foundation
import Combine

@MainActor
class ShopViewModel: ObservableObject {
    @Published var monthlyRevenue: Decimal = 0
    @Published var monthlyProfit: Decimal = 0
    @Published var monthlyOrderCount: Int = 0
    @Published var isLoading = false

    private let orderRepository: OrderRepository

    init(orderRepository: OrderRepository = OrderRepository()) {
        self.orderRepository = orderRepository
    }

    var marginPercent: Double {
        guard monthlyRevenue > 0 else { return 0 }
        let profit = NSDecimalNumber(decimal: monthlyProfit).doubleValue
        let revenue = NSDecimalNumber(decimal: monthlyRevenue).doubleValue
        return (profit / revenue) * 100
    }

    func load(userId: String) {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                async let revenue = orderRepository.getMonthlyRevenue(userId: userId)
                async let cost = orderRepository.getMonthlyCost(userId: userId)
                async let count = orderRepository.getMonthlyOrderCount(userId: userId)
                let (rev, c, n) = try await (revenue, cost, count)
                monthlyRevenue = rev
                monthlyProfit = rev - c
                monthlyOrderCount = n
            } catch {
                // Silent: stats are non-critical
            }
        }
    }
}
