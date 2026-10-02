import Foundation

/// Where products, purchases and entitlements come from.
///
/// `StoreKitPaywallStore` talks to the App Store with StoreKit 2. `PreviewPaywallStore` fakes
/// everything in memory for SwiftUI previews, screenshots and tests. Write your own to put a
/// server or another SDK behind the same paywalls.
///
/// Stores are used on the main actor by `PaywallController`.
@MainActor
public protocol PaywallStore: AnyObject {
    /// The products for `ids`, in the order of `ids`. Unknown identifiers are left out.
    func products(for ids: [String]) async throws -> [PaywallProduct]

    /// Buys `product`. Verifies and finishes the transaction before returning `.purchased`.
    func purchase(_ product: PaywallProduct) async throws -> PurchaseOutcome

    /// Asks the App Store for the user's purchases again, for "Restore Purchases".
    /// May show a sign-in prompt.
    func restorePurchases() async throws

    /// Every entitlement that is active now: subscriptions that have not expired and were not
    /// refunded, and lifetime unlocks.
    func currentEntitlements() async -> [Entitlement]

    /// A stream that yields whenever entitlements may have changed outside the app: a renewal,
    /// a refund, an Ask to Buy approval, a purchase on another device. Called once per controller.
    func entitlementUpdates() -> AsyncStream<Void>
}
