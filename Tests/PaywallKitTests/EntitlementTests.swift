import Foundation
import Testing
@testable import PaywallKit

let referenceDate = Date(timeIntervalSince1970: 1_790_000_000) // September 2026
let day: TimeInterval = 86_400

@Suite("Entitlement state")
struct EntitlementStateTests {
    @Test func noEntitlementsIsInactive() {
        let state = EntitlementState(resolving: [])
        #expect(state == .inactive)
        #expect(!state.isActive)
        #expect(state.isKnown)
        #expect(state.entitlement == nil)
    }

    @Test func unknownIsNotKnown() {
        #expect(!EntitlementState.unknown.isKnown)
        #expect(!EntitlementState.unknown.isActive)
    }

    @Test func lifetimeWinsOverSubscriptions() {
        let subscription = Entitlement(productID: "pro.yearly", purchaseDate: referenceDate, expirationDate: referenceDate + 365 * day)
        let lifetime = Entitlement(productID: "pro.lifetime", purchaseDate: referenceDate - 30 * day)
        let state = EntitlementState(resolving: [subscription, lifetime])
        #expect(state == .active(lifetime))
        #expect(state.entitlement?.isLifetime == true)
    }

    @Test func longestSubscriptionWins() {
        let monthly = Entitlement(productID: "pro.monthly", purchaseDate: referenceDate, expirationDate: referenceDate + 30 * day)
        let yearly = Entitlement(productID: "pro.yearly", purchaseDate: referenceDate, expirationDate: referenceDate + 365 * day)
        #expect(EntitlementState(resolving: [monthly, yearly]).entitlement?.productID == "pro.yearly")
        #expect(EntitlementState(resolving: [yearly, monthly]).entitlement?.productID == "pro.yearly")
    }

    @Test func otherProductsAreIgnored() {
        let other = Entitlement(productID: "stickers.pack", purchaseDate: referenceDate)
        let state = EntitlementState(resolving: [other], productIDs: ["pro.monthly", "pro.yearly"])
        #expect(state == .inactive)
    }

    @Test func expiredEntitlementsAreIgnoredAtADate() {
        let trial = Entitlement(
            productID: "pro.yearly",
            purchaseDate: referenceDate,
            expirationDate: referenceDate + 7 * day,
            isInTrialPeriod: true
        )
        #expect(EntitlementState(resolving: [trial], at: referenceDate + 6 * day).isActive)
        #expect(EntitlementState(resolving: [trial], at: referenceDate + 7 * day) == .inactive)
        #expect(trial.isActive(at: referenceDate + 6 * day))
        #expect(!trial.isActive(at: referenceDate + 8 * day))
    }
}

@MainActor
@Suite("Entitlement transitions with the preview store")
struct EntitlementTransitionTests {
    func makeController(
        purchases: [Entitlement] = [],
        restorable: [Entitlement] = [],
        behavior: PreviewPaywallStore.PurchaseBehavior = .succeed
    ) -> (PaywallController, PreviewPaywallStore) {
        let store = PreviewPaywallStore(
            purchases: purchases,
            restorableEntitlements: restorable,
            purchaseBehavior: behavior,
            now: referenceDate
        )
        let controller = PaywallController(productIDs: store.productIDs, store: store)
        return (controller, store)
    }

    @Test func startsUnknownThenInactive() async {
        let (controller, _) = makeController()
        #expect(controller.entitlement == .unknown)
        #expect(controller.products.isEmpty)

        await controller.start()
        #expect(controller.entitlement == .inactive)
        #expect(controller.products.map(\.id) == ["pro.monthly", "pro.yearly", "pro.lifetime"])
        #expect(controller.productsError == nil)
        #expect(!controller.isEntitled)
    }

    @Test func existingPurchaseIsActiveAtStart() async {
        let lifetime = Entitlement(productID: "pro.lifetime", purchaseDate: referenceDate - 100 * day)
        let (controller, _) = makeController(purchases: [lifetime])
        await controller.start()
        #expect(controller.entitlement == .active(lifetime))
    }

    @Test func purchasingTheYearlyPlanStartsTheTrial() async throws {
        let (controller, store) = makeController()
        await controller.start()
        let product = try #require(controller.product(withID: "pro.yearly"))
        #expect(product.hasEligibleFreeTrial)

        let outcome = try await controller.purchase(product)
        let entitlement = try #require(controller.entitlement.entitlement)
        #expect(outcome == .purchased(entitlement))
        #expect(entitlement.productID == "pro.yearly")
        #expect(entitlement.isInTrialPeriod)
        #expect(entitlement.expirationDate == referenceDate + 7 * day)
        #expect(controller.isEntitled)
        #expect(controller.purchasingProductID == nil)
        #expect(store.purchaseCount == 1)

        // The trial is used up, so the products no longer offer it.
        let refreshed = try #require(controller.product(withID: "pro.yearly"))
        #expect(!refreshed.hasEligibleFreeTrial)
        let monthly = try #require(controller.product(withID: "pro.monthly"))
        #expect(!monthly.isEligibleForIntroOffer)
    }

    @Test func trialEndsWhenTheClockPassesIt() async throws {
        let (controller, store) = makeController()
        await controller.start()
        let product = try #require(controller.product(withID: "pro.yearly"))
        try await controller.purchase(product)
        let entitlement = try #require(controller.entitlement.entitlement)

        store.advance(by: 6 * day)
        await controller.refreshEntitlements()
        #expect(controller.isEntitled)

        store.expire(entitlement)
        await controller.refreshEntitlements()
        #expect(controller.entitlement == .inactive)
    }

    @Test func monthlyPurchaseHasNoTrial() async throws {
        let (controller, _) = makeController()
        await controller.start()
        let product = try #require(controller.product(withID: "pro.monthly"))
        try await controller.purchase(product)
        let entitlement = try #require(controller.entitlement.entitlement)
        #expect(!entitlement.isInTrialPeriod)
        #expect(entitlement.expirationDate != nil)
    }

    @Test func lifetimePurchaseNeverExpires() async throws {
        let (controller, store) = makeController()
        await controller.start()
        let product = try #require(controller.product(withID: "pro.lifetime"))
        try await controller.purchase(product)
        store.advance(by: 3650 * day)
        await controller.refreshEntitlements()
        #expect(controller.entitlement.entitlement?.isLifetime == true)
    }

    @Test func cancelledPurchaseStaysInactive() async throws {
        let (controller, _) = makeController(behavior: .cancel)
        await controller.start()
        let product = try #require(controller.product(withID: "pro.yearly"))
        let outcome = try await controller.purchase(product)
        #expect(outcome == .cancelled)
        #expect(controller.entitlement == .inactive)
    }

    @Test func pendingPurchaseUnlocksWhenApproved() async throws {
        let (controller, store) = makeController(behavior: .pending)
        await controller.start()
        let product = try #require(controller.product(withID: "pro.monthly"))
        let outcome = try await controller.purchase(product)
        #expect(outcome == .pending)
        #expect(!controller.isEntitled)

        // Ask to Buy approved on the parent's device.
        store.grant(Entitlement(productID: "pro.monthly", purchaseDate: store.now, expirationDate: store.now + 30 * day))
        await controller.refreshEntitlements()
        #expect(controller.isEntitled)
    }

    @Test func failedPurchaseThrows() async throws {
        let (controller, _) = makeController(behavior: .fail(.failedVerification))
        await controller.start()
        let product = try #require(controller.product(withID: "pro.yearly"))
        await #expect(throws: PaywallError.failedVerification) {
            try await controller.purchase(product)
        }
        #expect(controller.entitlement == .inactive)
        #expect(controller.purchasingProductID == nil)
    }

    @Test func restoreBringsBackPurchases() async throws {
        let lifetime = Entitlement(productID: "pro.lifetime", purchaseDate: referenceDate - 400 * day)
        let (controller, _) = makeController(restorable: [lifetime])
        await controller.start()
        #expect(controller.entitlement == .inactive)

        let restored = try await controller.restore()
        #expect(restored)
        #expect(controller.entitlement == .active(lifetime))
        #expect(!controller.isRestoring)
    }

    @Test func restoreWithNothingToRestore() async throws {
        let (controller, _) = makeController()
        await controller.start()
        let restored = try await controller.restore()
        #expect(!restored)
        #expect(controller.entitlement == .inactive)
    }

    @Test func refundRevokesAccess() async throws {
        let (controller, store) = makeController()
        await controller.start()
        let product = try #require(controller.product(withID: "pro.monthly"))
        try await controller.purchase(product)
        #expect(controller.isEntitled)

        store.refund(productID: "pro.monthly")
        await controller.refreshEntitlements()
        #expect(controller.entitlement == .inactive)
    }

    @Test func unknownProductIsReported() async throws {
        let (controller, _) = makeController()
        await controller.start()
        let missing = PaywallProduct(id: "pro.missing", displayName: "Missing", price: 1, subscriptionPeriod: .monthly)
        await #expect(throws: PaywallError.productNotFound("pro.missing")) {
            try await controller.purchase(missing)
        }
    }

    @Test func missingProductsAreAnError() async {
        let store = PreviewPaywallStore(products: [])
        let controller = PaywallController(productIDs: ["pro.monthly"], store: store)
        await controller.start()
        #expect(controller.productsError == .productsUnavailable)
        #expect(controller.products.isEmpty)
    }

    @Test func previewControllerHasProductsImmediately() {
        let controller = PaywallController.preview()
        #expect(controller.products.count == 3)
        #expect(controller.entitlement == .inactive)
    }
}
