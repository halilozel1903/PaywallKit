import Foundation
import StoreKit

/// The live store: StoreKit 2 and the App Store (or an Xcode StoreKit configuration file).
///
/// - Products come from `Product.products(for:)`.
/// - Purchases use `Product.purchase()`; only verified transactions grant access, and every
///   transaction is finished.
/// - Entitlements come from `Transaction.currentEntitlements`; refunded and upgraded transactions
///   are skipped.
/// - `Transaction.updates` is observed for renewals, refunds and Ask to Buy approvals.
/// - Restore calls `AppStore.sync()`.
@MainActor
public final class StoreKitPaywallStore: PaywallStore {
    /// StoreKit products by identifier, kept to buy what the paywall shows.
    private var storeProducts: [String: Product] = [:]

    public init() {}

    public func products(for ids: [String]) async throws -> [PaywallProduct] {
        let loaded = try await Product.products(for: ids)
        var result: [PaywallProduct] = []
        for product in loaded {
            storeProducts[product.id] = product
            result.append(await Self.makePaywallProduct(product))
        }
        // Product.products(for:) does not keep the order of the identifiers.
        let order = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return result.sorted { (order[$0.id] ?? .max) < (order[$1.id] ?? .max) }
    }

    public func purchase(_ paywallProduct: PaywallProduct) async throws -> PurchaseOutcome {
        guard AppStore.canMakePayments else { throw PaywallError.purchasesNotAllowed }
        let product: Product
        if let cached = storeProducts[paywallProduct.id] {
            product = cached
        } else if let fetched = try await Product.products(for: [paywallProduct.id]).first {
            storeProducts[fetched.id] = fetched
            product = fetched
        } else {
            throw PaywallError.productNotFound(paywallProduct.id)
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw PaywallError.failedVerification
            }
            await transaction.finish()
            return .purchased(Self.makeEntitlement(transaction))
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    public func restorePurchases() async throws {
        try await AppStore.sync()
    }

    public func currentEntitlements() async -> [Entitlement] {
        var entitlements: [Entitlement] = []
        for await verification in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification,
                  transaction.revocationDate == nil,
                  !transaction.isUpgraded
            else { continue }
            entitlements.append(Self.makeEntitlement(transaction))
        }
        return entitlements
    }

    public func entitlementUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            // A child of the caller's context, not Task.detached: the loop only touches Sendable
            // values (the transaction and the continuation) and ends when the stream is dropped.
            let task = Task {
                for await verification in StoreKit.Transaction.updates {
                    if case .verified(let transaction) = verification {
                        await transaction.finish()
                    }
                    continuation.yield()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Mapping

    nonisolated static func makePaywallProduct(_ product: Product) async -> PaywallProduct {
        let kind: PaywallProduct.Kind
        switch product.type {
        case .autoRenewable: kind = .subscription
        case .nonConsumable: kind = .lifetime
        case .nonRenewable: kind = .nonRenewing
        default: kind = .consumable
        }

        var period: SubscriptionPeriod?
        var offer: IntroductoryOffer?
        var isEligible = false
        if let subscription = product.subscription {
            period = makePeriod(subscription.subscriptionPeriod)
            offer = subscription.introductoryOffer.map(makeOffer)
            isEligible = await subscription.isEligibleForIntroOffer
        }

        return PaywallProduct(
            id: product.id,
            displayName: product.displayName,
            description: product.description,
            price: product.price,
            displayPrice: product.displayPrice,
            currencyCode: product.priceFormatStyle.currencyCode,
            priceLocale: product.priceFormatStyle.locale,
            kind: kind,
            subscriptionPeriod: period,
            introductoryOffer: offer,
            isEligibleForIntroOffer: isEligible,
            subscriptionGroupID: product.subscription?.subscriptionGroupID
        )
    }

    nonisolated static func makePeriod(_ period: Product.SubscriptionPeriod) -> SubscriptionPeriod {
        let unit: SubscriptionPeriod.Unit
        switch period.unit {
        case .day: unit = .day
        case .week: unit = .week
        case .month: unit = .month
        case .year: unit = .year
        @unknown default: unit = .month
        }
        return SubscriptionPeriod(value: period.value, unit: unit)
    }

    nonisolated static func makeOffer(_ offer: Product.SubscriptionOffer) -> IntroductoryOffer {
        let mode: IntroductoryOffer.PaymentMode
        if offer.paymentMode == .freeTrial {
            mode = .freeTrial
        } else if offer.paymentMode == .payUpFront {
            mode = .payUpFront
        } else {
            mode = .payAsYouGo
        }
        return IntroductoryOffer(
            paymentMode: mode,
            price: offer.price,
            period: makePeriod(offer.period),
            periodCount: offer.periodCount
        )
    }

    nonisolated static func makeEntitlement(_ transaction: StoreKit.Transaction) -> Entitlement {
        var isTrial = false
        if #available(iOS 17.2, macOS 14.2, *) {
            isTrial = transaction.offer?.type == .introductory && transaction.offer?.paymentMode == .freeTrial
        }
        return Entitlement(
            productID: transaction.productID,
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate,
            isInTrialPeriod: isTrial
        )
    }
}
