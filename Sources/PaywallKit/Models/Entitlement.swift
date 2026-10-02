import Foundation

/// Access the user has paid for: an active subscription or a lifetime unlock.
public struct Entitlement: Sendable, Hashable, Identifiable {
    public var productID: String
    public var purchaseDate: Date
    /// When a subscription ends unless it renews. `nil` for lifetime unlocks.
    public var expirationDate: Date?
    /// `true` while the user is in a free trial.
    public var isInTrialPeriod: Bool

    public init(productID: String, purchaseDate: Date, expirationDate: Date? = nil, isInTrialPeriod: Bool = false) {
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.isInTrialPeriod = isInTrialPeriod
    }

    public var id: String { productID }

    /// `true` for a purchase that never expires.
    public var isLifetime: Bool { expirationDate == nil }

    /// Whether the entitlement still grants access at `date`.
    public func isActive(at date: Date) -> Bool {
        guard let expirationDate else { return true }
        return expirationDate > date
    }
}

/// Whether the user has Pro, as far as the app knows.
public enum EntitlementState: Sendable, Hashable {
    /// Not checked yet. Show neither the paywall nor the content, or a progress view.
    case unknown
    /// No active subscription or lifetime unlock.
    case inactive
    /// The best active entitlement: a lifetime unlock, or else the subscription that runs longest.
    case active(Entitlement)

    /// Picks the state from the entitlements a store reports as current.
    ///
    /// - Parameters:
    ///   - entitlements: Current entitlements, for example from `Transaction.currentEntitlements`.
    ///   - productIDs: The products that unlock this paywall. Others are ignored. `nil` accepts all.
    ///   - date: Entitlements that expired by this date are ignored. `nil` trusts the store.
    public init(resolving entitlements: [Entitlement], productIDs: Set<String>? = nil, at date: Date? = nil) {
        let candidates = entitlements.filter { entitlement in
            if let productIDs, !productIDs.contains(entitlement.productID) { return false }
            if let date, !entitlement.isActive(at: date) { return false }
            return true
        }
        if let lifetime = candidates.first(where: \.isLifetime) {
            self = .active(lifetime)
        } else if let longest = candidates.max(by: { ($0.expirationDate ?? .distantPast) < ($1.expirationDate ?? .distantPast) }) {
            self = .active(longest)
        } else {
            self = .inactive
        }
    }

    /// `true` when the user has access.
    public var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    /// `false` until the store has been asked.
    public var isKnown: Bool {
        self != .unknown
    }

    /// The active entitlement, if any.
    public var entitlement: Entitlement? {
        if case .active(let entitlement) = self { return entitlement }
        return nil
    }
}
