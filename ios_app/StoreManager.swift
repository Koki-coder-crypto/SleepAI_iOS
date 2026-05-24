import StoreKit
import Foundation

@MainActor
class StoreManager: ObservableObject {
    @Published var isPro = false
    @Published var products: [Product] = []
    static let freeUsesPerMonth = 5
    private let productIDs = ["com.kokicoder.sleepai.pro.monthly", "com.kokicoder.sleepai.pro.annual"]

    init() {
        Task {
            await loadProducts(); await updatePurchasedStatus()
            for await result in Transaction.updates { if case .verified(let tx) = result { await handle(tx) } }
        }
    }
    func loadProducts() async { products = (try? await Product.products(for: productIDs)) ?? [] }
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        if case .success(let v) = result, case .verified(let tx) = v { await handle(tx) }
    }
    func restorePurchases() async { try? await AppStore.sync(); await updatePurchasedStatus() }
    private func updatePurchasedStatus() async { for await result in Transaction.currentEntitlements { if case .verified(let tx) = result { await handle(tx) } } }
    private func handle(_ transaction: Transaction) async { if transaction.revocationDate == nil { isPro = true }; await transaction.finish() }
    var proMonthly: Product? { products.first { $0.id.contains("monthly") } }
    var proAnnual:  Product? { products.first { $0.id.contains("annual") } }
}
