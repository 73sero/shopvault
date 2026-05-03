import Foundation
import Combine

enum InventoryFilter: String, CaseIterable {
    case all = "Alle"
    case favorites = "Favoriten"
    case lowStock = "Low Stock"
    case empty = "Leer"
    case hidden = "Ausgeblendet"
}

@MainActor
class InventoryViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var searchText = ""
    @Published var selectedFilter: InventoryFilter = .all
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let productRepository: ProductRepository

    init(productRepository: ProductRepository = ProductRepository()) {
        self.productRepository = productRepository
    }

    // MARK: - Computed Properties

    var filteredProducts: [Product] {
        var result = products

        switch selectedFilter {
        case .all:
            result = result.filter { $0.isActive }
        case .favorites:
            result = result.filter { $0.isActive && $0.isFavorite }
        case .lowStock:
            result = result.filter { $0.isActive && $0.isLowStock && !$0.isOutOfStock }
        case .empty:
            result = result.filter { $0.isActive && $0.isOutOfStock }
        case .hidden:
            result = result.filter { !$0.isActive }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.code.lowercased().contains(query)
            }
        }

        return result
    }

    var totalVials: Int {
        products.reduce(0) { $0 + $1.stock }
    }

    var lowStockCount: Int {
        products.filter { $0.isLowStock }.count
    }

    // MARK: - Public Methods

    func loadProducts() {
        Task {
            do {
                isLoading = true
                products = try await productRepository.getAllProductsIncludingHidden()
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func toggleFavorite(_ product: Product) {
        Task {
            do {
                let newValue = !product.isFavorite
                try productRepository.toggleFavorite(productId: product.id, isFavorite: newValue)
                if let index = products.firstIndex(where: { $0.id == product.id }) {
                    products[index] = Product(
                        id: product.id, code: product.code, name: product.name,
                        specification: product.specification, price: product.price,
                        stock: product.stock, lowStockThreshold: product.lowStockThreshold,
                        isFavorite: newValue, isActive: product.isActive,
                        createdAt: product.createdAt, updatedAt: Date()
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func toggleHidden(_ product: Product) {
        Task {
            do {
                let newValue = !product.isActive
                try productRepository.toggleActive(productId: product.id, isActive: newValue)
                if let index = products.firstIndex(where: { $0.id == product.id }) {
                    products[index] = Product(
                        id: product.id, code: product.code, name: product.name,
                        specification: product.specification, price: product.price,
                        stock: product.stock, lowStockThreshold: product.lowStockThreshold,
                        isFavorite: product.isFavorite, isActive: newValue,
                        createdAt: product.createdAt, updatedAt: Date()
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteProduct(_ product: Product) {
        Task {
            do {
                try await productRepository.deleteProduct(productId: product.id)
                products.removeAll { $0.id == product.id }
                NotificationCenter.default.post(name: .stockDidChange, object: nil)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func updateStock(_ product: Product, newStock: Int) {
        Task {
            do {
                try productRepository.updateStock(productId: product.id, newStock: newStock)
                if let index = products.firstIndex(where: { $0.id == product.id }) {
                    products[index] = Product(
                        id: product.id, code: product.code, name: product.name,
                        specification: product.specification, price: product.price,
                        stock: newStock, lowStockThreshold: product.lowStockThreshold,
                        isFavorite: product.isFavorite, isActive: product.isActive,
                        createdAt: product.createdAt, updatedAt: Date()
                    )
                }
                NotificationCenter.default.post(name: .stockDidChange, object: nil)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
