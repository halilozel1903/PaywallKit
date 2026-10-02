import Foundation
import Observation

/// The state behind every paywall: the products, what is being bought and whether the user has Pro.
///
/// Create one for the app and pass it to the paywalls, `.paywall(isPresented:)` and
/// `EntitlementGate`. It is `@Observable`, so views update when the entitlement changes.
///
/// ```swift
/// @State private var paywall = PaywallController(productIDs: ["pro.monthly", "pro.yearly", "pro.lifetime"])
/// ```
@MainActor
@Observable
public final class PaywallController {
    /// The products to offer, in display order.
    public let productIDs: [String]

    /// The loaded products, in the order of `productIDs`.
    public private(set) var products: [PaywallProduct]
    /// Whether the user has access. `.unknown` until the store has been asked.
    public private(set) var entitlement: EntitlementState = .unknown
    /// `true` while products are loading.
    public private(set) var isLoadingProducts = false
    /// The error of the last product request, if it failed.
    public private(set) var productsError: PaywallError?
    /// The product being bought, while a purchase runs.
    public private(set) var purchasingProductID: String?
    /// `true` while purchases are being restored.
    public private(set) var isRestoring = false

    private let store: any PaywallStore
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var hasStarted = false

    /// - Parameters:
    ///   - productIDs: The products to offer, in display order.
    ///   - store: Where products and purchases come from.
    ///   - products: Products to show before the store answers, for example in previews.
    public init(productIDs: [String], store: any PaywallStore, products: [PaywallProduct] = []) {
        self.productIDs = productIDs
        self.store = store
        self.products = products
    }

    /// A controller that uses the App Store through StoreKit 2.
    public convenience init(productIDs: [String]) {
        self.init(productIDs: productIDs, store: StoreKitPaywallStore())
    }

    /// A controller backed by a `PreviewPaywallStore` with its products already loaded, for
    /// SwiftUI previews and screenshots.
    public static func preview(
        store: PreviewPaywallStore = PreviewPaywallStore(),
        entitlement: EntitlementState = .inactive
    ) -> PaywallController {
        let controller = PaywallController(productIDs: store.productIDs, store: store, products: store.availableProducts)
        controller.entitlement = entitlement
        return controller
    }

    // MARK: State

    /// `true` when the user has access.
    public var isEntitled: Bool { entitlement.isActive }

    /// `true` while a purchase or restore runs.
    public var isBusy: Bool { purchasingProductID != nil || isRestoring }

    /// The loaded product with `id`.
    public func product(withID id: String) -> PaywallProduct? {
        products.first { $0.id == id }
    }

    // MARK: Actions

    /// Loads products and entitlements and starts listening for transaction updates.
    /// Safe to call many times, for example from several `.task` modifiers; only the first call
    /// starts the listener, later calls refresh.
    public func start() async {
        if !hasStarted {
            hasStarted = true
            let updates = store.entitlementUpdates()
            updatesTask = Task { [weak self] in
                for await _ in updates {
                    guard let self else { return }
                    await self.refreshEntitlements()
                }
            }
        }
        if products.isEmpty || productsError != nil {
            await loadProducts()
        }
        await refreshEntitlements()
    }

    /// Stops listening for transaction updates.
    public func stop() {
        updatesTask?.cancel()
        updatesTask = nil
        hasStarted = false
    }

    /// Loads `productIDs` from the store.
    public func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await store.products(for: productIDs)
            products = loaded
            productsError = loaded.isEmpty && !productIDs.isEmpty ? .productsUnavailable : nil
        } catch {
            productsError = .wrapping(error)
        }
    }

    /// Asks the store for the current entitlements.
    public func refreshEntitlements() async {
        let current = await store.currentEntitlements()
        entitlement = EntitlementState(resolving: current, productIDs: Set(productIDs))
    }

    /// Buys `product` and refreshes the entitlement.
    ///
    /// - Returns: `.purchased`, `.pending` (Ask to Buy) or `.cancelled`.
    /// - Throws: `PaywallError.busy` while another purchase runs, or the store's error.
    @discardableResult
    public func purchase(_ product: PaywallProduct) async throws -> PurchaseOutcome {
        guard !isBusy else { throw PaywallError.busy }
        purchasingProductID = product.id
        defer { purchasingProductID = nil }
        let outcome: PurchaseOutcome
        do {
            outcome = try await store.purchase(product)
        } catch {
            throw PaywallError.wrapping(error)
        }
        if case .purchased = outcome {
            await refreshEntitlements()
            // Eligibility for the introductory offer may have changed.
            if let refreshed = try? await store.products(for: productIDs), !refreshed.isEmpty {
                products = refreshed
            }
        }
        return outcome
    }

    /// Restores purchases and refreshes the entitlement.
    ///
    /// - Returns: `true` when the user has access afterwards.
    @discardableResult
    public func restore() async throws -> Bool {
        guard !isBusy else { throw PaywallError.busy }
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await store.restorePurchases()
        } catch {
            throw PaywallError.wrapping(error)
        }
        await refreshEntitlements()
        return entitlement.isActive
    }
}
