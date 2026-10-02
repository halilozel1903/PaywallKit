import Foundation

/// An in-memory store with fake products, for SwiftUI previews, screenshots and tests.
///
/// Purchases succeed instantly (or cancel, stay pending or fail, see `purchaseBehavior`). A
/// subscription with an eligible free trial starts in its trial; subscriptions do not renew, so
/// moving the clock past `expirationDate` with `advance(by:)` ends them.
///
/// ```swift
/// let store = PreviewPaywallStore()                       // $4.99/month, $39.99/year, $79.99 lifetime
/// let controller = PaywallController(productIDs: store.productIDs, store: store)
/// ```
@MainActor
public final class PreviewPaywallStore: PaywallStore {
    public enum PurchaseBehavior: Sendable, Hashable {
        case succeed
        case cancel
        case pending
        case fail(PaywallError)
    }

    /// The products the fake App Store sells.
    public var availableProducts: [PaywallProduct]
    /// What the next purchases do.
    public var purchaseBehavior: PurchaseBehavior
    /// What "Restore Purchases" brings back, as if bought on another device.
    public var restorableEntitlements: [Entitlement]
    /// Every purchase, including expired ones.
    public private(set) var purchases: [Entitlement]
    /// The store's clock. Purchases start now and entitlements are active until it passes them.
    public private(set) var now: Date
    /// Simulated network time for products, purchases and restores. Zero by default.
    public var latency: Duration
    /// How many purchases were attempted, for tests.
    public private(set) var purchaseCount = 0

    /// One continuation per `entitlementUpdates()` stream, so several controllers can share a store.
    private var updateContinuations: [AsyncStream<Void>.Continuation] = []

    public init(
        products: [PaywallProduct] = PaywallProduct.previewProducts(),
        purchases: [Entitlement] = [],
        restorableEntitlements: [Entitlement] = [],
        purchaseBehavior: PurchaseBehavior = .succeed,
        now: Date = Date(),
        latency: Duration = .zero
    ) {
        self.availableProducts = products
        self.purchases = purchases
        self.restorableEntitlements = restorableEntitlements
        self.purchaseBehavior = purchaseBehavior
        self.now = now
        self.latency = latency
    }

    /// The identifiers of `availableProducts`, in order.
    public var productIDs: [String] {
        availableProducts.map(\.id)
    }

    // MARK: PaywallStore

    public func products(for ids: [String]) async throws -> [PaywallProduct] {
        try await simulateLatency()
        return ids.compactMap { id in availableProducts.first { $0.id == id } }
    }

    public func purchase(_ product: PaywallProduct) async throws -> PurchaseOutcome {
        purchaseCount += 1
        try await simulateLatency()
        switch purchaseBehavior {
        case .cancel:
            return .cancelled
        case .pending:
            return .pending
        case .fail(let error):
            throw error
        case .succeed:
            break
        }
        guard let stocked = availableProducts.first(where: { $0.id == product.id }) else {
            throw PaywallError.productNotFound(product.id)
        }
        let entitlement = makeEntitlement(for: stocked)
        if stocked.grantsEntitlement {
            purchases.removeAll { $0.productID == stocked.id }
            purchases.append(entitlement)
        }
        return .purchased(entitlement)
    }

    public func restorePurchases() async throws {
        try await simulateLatency()
        for entitlement in restorableEntitlements where !purchases.contains(entitlement) {
            purchases.append(entitlement)
        }
        restorableEntitlements = []
    }

    public func currentEntitlements() async -> [Entitlement] {
        purchases.filter { $0.isActive(at: now) }
    }

    public func entitlementUpdates() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        updateContinuations.append(continuation)
        return stream
    }

    // MARK: Simulation

    /// Moves the clock forward, for example past the end of a trial, and notifies the controller.
    public func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
        notifyUpdates()
    }

    /// Moves the clock to one second after `entitlement` expires.
    public func expire(_ entitlement: Entitlement) {
        guard let expirationDate = entitlement.expirationDate, expirationDate > now else { return }
        advance(by: expirationDate.timeIntervalSince(now) + 1)
    }

    /// Removes a purchase, like a refund, and notifies the controller.
    public func refund(productID: String) {
        purchases.removeAll { $0.productID == productID }
        notifyUpdates()
    }

    /// Adds a purchase made elsewhere, like an Ask to Buy approval, and notifies the controller.
    public func grant(_ entitlement: Entitlement) {
        purchases.removeAll { $0.productID == entitlement.productID }
        purchases.append(entitlement)
        notifyUpdates()
    }

    // MARK: Private

    private func notifyUpdates() {
        for continuation in updateContinuations {
            continuation.yield()
        }
    }

    private func makeEntitlement(for product: PaywallProduct) -> Entitlement {
        // One introductory offer per subscription group, as on the App Store.
        if let offer = product.eligibleIntroductoryOffer, offer.paymentMode == .freeTrial {
            markIntroOfferUsed(in: product)
            return Entitlement(
                productID: product.id,
                purchaseDate: now,
                expirationDate: offer.totalDuration.date(after: now),
                isInTrialPeriod: true
            )
        }
        if product.eligibleIntroductoryOffer != nil {
            markIntroOfferUsed(in: product)
        }
        return Entitlement(
            productID: product.id,
            purchaseDate: now,
            expirationDate: product.subscriptionPeriod.map { $0.date(after: now) },
            isInTrialPeriod: false
        )
    }

    private func markIntroOfferUsed(in product: PaywallProduct) {
        for index in availableProducts.indices {
            let sameGroup = product.subscriptionGroupID != nil
                && availableProducts[index].subscriptionGroupID == product.subscriptionGroupID
            if sameGroup || availableProducts[index].id == product.id {
                availableProducts[index].isEligibleForIntroOffer = false
            }
        }
    }

    private func simulateLatency() async throws {
        if latency > .zero {
            try await Task.sleep(for: latency)
        }
    }
}
