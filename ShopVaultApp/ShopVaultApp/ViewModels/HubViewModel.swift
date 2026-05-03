import Foundation
import Combine

@MainActor
class HubViewModel: ObservableObject {
    @Published var monthlyRevenue: Decimal = 0
    @Published var monthlyProfit: Decimal = 0
    @Published var lowStockCount: Int = 0
    @Published var lowStockProducts: [Product] = []
    @Published var recentOrders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let orderRepository: OrderRepository
    private let productRepository: ProductRepository

    init(
        orderRepository: OrderRepository = OrderRepository(),
        productRepository: ProductRepository = ProductRepository()
    ) {
        self.orderRepository = orderRepository
        self.productRepository = productRepository
    }

    // MARK: - Computed Properties

    var marginPercent: Double {
        guard monthlyRevenue > 0 else { return 0 }
        let profit = NSDecimalNumber(decimal: monthlyProfit).doubleValue
        let revenue = NSDecimalNumber(decimal: monthlyRevenue).doubleValue
        return (profit / revenue) * 100
    }

    // MARK: - Public Methods

    func loadData(userId: String) {
        Task {
            do {
                isLoading = true

                monthlyRevenue = try await orderRepository.getMonthlyRevenue(userId: userId)
                let monthlyCost = try await orderRepository.getMonthlyCost(userId: userId)
                monthlyProfit = monthlyRevenue - monthlyCost

                lowStockProducts = try await productRepository.getLowStockProducts()
                lowStockCount = lowStockProducts.count

                recentOrders = try await orderRepository.getRecentOrders(userId: userId, limit: 3)

                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
