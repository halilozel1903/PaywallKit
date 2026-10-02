import Foundation

/// The result of a purchase that did not throw.
public enum PurchaseOutcome: Sendable, Hashable {
    /// The purchase went through and the transaction was verified and finished.
    case purchased(Entitlement)
    /// Waiting for approval, for example Ask to Buy. The entitlement arrives later as an update.
    case pending
    /// The user closed the payment sheet.
    case cancelled
}

/// Errors thrown by PaywallKit stores and `PaywallController`.
public enum PaywallError: Error, Sendable, Hashable, LocalizedError {
    /// The product was not returned by the App Store. Check the identifier and your StoreKit configuration.
    case productNotFound(String)
    /// The App Store returned none of the requested products.
    case productsUnavailable
    /// StoreKit could not verify the transaction's signature.
    case failedVerification
    /// Another purchase or restore is still running.
    case busy
    /// The device does not allow purchases, for example because of Screen Time.
    case purchasesNotAllowed
    /// Any other store error, with its description.
    case store(String)

    public var errorDescription: String? {
        switch self {
        case .productNotFound(let id):
            return "The product \(id) is not available right now."
        case .productsUnavailable:
            return "Plans could not be loaded. Check your connection and try again."
        case .failedVerification:
            return "The App Store could not verify this purchase."
        case .busy:
            return "Please wait for the current purchase to finish."
        case .purchasesNotAllowed:
            return "Purchases are not allowed on this device."
        case .store(let message):
            return message
        }
    }

    /// Wraps any error, keeping `PaywallError`s as they are.
    static func wrapping(_ error: any Error) -> PaywallError {
        (error as? PaywallError) ?? .store(error.localizedDescription)
    }
}
