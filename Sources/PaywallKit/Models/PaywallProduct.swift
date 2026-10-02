import Foundation

/// A product shown on a paywall: a subscription, a lifetime unlock or a consumable.
///
/// The live store builds these from StoreKit's `Product`; `PreviewPaywallStore` and your tests
/// create them directly, so nothing on screen depends on the App Store.
public struct PaywallProduct: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable {
        /// An auto-renewable subscription.
        case subscription
        /// A non-consumable in-app purchase that unlocks Pro forever.
        case lifetime
        /// A non-renewing subscription with a fixed duration.
        case nonRenewing
        /// A consumable, such as credits. Never grants an entitlement.
        case consumable
    }

    /// The App Store product identifier.
    public var id: String
    public var displayName: String
    public var description: String
    /// The price in the storefront's currency, for example `39.99`.
    public var price: Decimal
    /// The price as the App Store formats it, for example "$39.99".
    public var displayPrice: String
    /// ISO 4217 currency code of `price`, for example "USD".
    public var currencyCode: String
    /// The locale the App Store uses to format prices for this storefront.
    public var priceLocale: Locale
    public var kind: Kind
    /// How often a subscription renews. `nil` for lifetime unlocks and consumables.
    public var subscriptionPeriod: SubscriptionPeriod?
    /// The introductory offer of a subscription (free trial, pay as you go or pay up front).
    public var introductoryOffer: IntroductoryOffer?
    /// Whether the user can still redeem `introductoryOffer`. The App Store allows one per subscription group.
    public var isEligibleForIntroOffer: Bool
    /// The subscription group, for subscriptions.
    public var subscriptionGroupID: String?

    public init(
        id: String,
        displayName: String,
        description: String = "",
        price: Decimal,
        displayPrice: String? = nil,
        currencyCode: String = "USD",
        priceLocale: Locale = Locale(identifier: "en_US"),
        kind: Kind = .subscription,
        subscriptionPeriod: SubscriptionPeriod? = nil,
        introductoryOffer: IntroductoryOffer? = nil,
        isEligibleForIntroOffer: Bool = true,
        subscriptionGroupID: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.price = price
        self.displayPrice = displayPrice ?? price.formatted(.currency(code: currencyCode).locale(priceLocale))
        self.currencyCode = currencyCode
        self.priceLocale = priceLocale
        self.kind = kind
        self.subscriptionPeriod = subscriptionPeriod
        self.introductoryOffer = introductoryOffer
        self.isEligibleForIntroOffer = isEligibleForIntroOffer
        self.subscriptionGroupID = subscriptionGroupID
    }

    /// The introductory offer, only when the user can still redeem it.
    public var eligibleIntroductoryOffer: IntroductoryOffer? {
        isEligibleForIntroOffer ? introductoryOffer : nil
    }

    /// `true` when the user would start with a free trial.
    public var hasEligibleFreeTrial: Bool {
        eligibleIntroductoryOffer?.paymentMode == .freeTrial
    }

    /// `true` for products that grant access: subscriptions and lifetime unlocks.
    public var grantsEntitlement: Bool {
        kind != .consumable
    }

    /// The price for a whole year of access, used to compare plans. `nil` without a period.
    public var annualizedPrice: Decimal? {
        guard let subscriptionPeriod else { return nil }
        return price * subscriptionPeriod.periodsPerYear
    }
}

/// An introductory offer of a subscription, as configured in App Store Connect.
public struct IntroductoryOffer: Sendable, Hashable {
    public enum PaymentMode: Sendable, Hashable {
        /// Free for `period × periodCount`.
        case freeTrial
        /// `price` every `period`, for `periodCount` periods.
        case payAsYouGo
        /// `price` once, for `period × periodCount`.
        case payUpFront
    }

    public var paymentMode: PaymentMode
    /// The offer price per period (pay as you go) or in total (pay up front). Zero for free trials.
    public var price: Decimal
    public var period: SubscriptionPeriod
    public var periodCount: Int

    public init(paymentMode: PaymentMode, price: Decimal = 0, period: SubscriptionPeriod, periodCount: Int = 1) {
        self.paymentMode = paymentMode
        self.price = paymentMode == .freeTrial ? 0 : price
        self.period = period
        self.periodCount = max(1, periodCount)
    }

    /// A free trial, for example `.freeTrial(.weekly)` for one free week.
    public static func freeTrial(_ period: SubscriptionPeriod) -> IntroductoryOffer {
        IntroductoryOffer(paymentMode: .freeTrial, period: period)
    }

    /// How long the offer lasts in total.
    public var totalDuration: SubscriptionPeriod {
        period.multiplied(by: periodCount)
    }
}

// MARK: - Sample products

extension PaywallProduct {
    /// Three products for previews, screenshots and tests, priced in US dollars:
    ///
    /// | ID | Price | Offer |
    /// | --- | --- | --- |
    /// | `<prefix>.monthly` | $4.99 a month | |
    /// | `<prefix>.yearly` | $39.99 a year | 1 week free |
    /// | `<prefix>.lifetime` | $79.99 once | |
    public static func previewProducts(idPrefix: String = "pro", name: String = "Pro") -> [PaywallProduct] {
        [
            PaywallProduct(
                id: "\(idPrefix).monthly",
                displayName: "\(name) Monthly",
                description: "Every \(name) feature, billed monthly.",
                price: Decimal(499) / 100,
                kind: .subscription,
                subscriptionPeriod: .monthly,
                subscriptionGroupID: "\(idPrefix).group"
            ),
            PaywallProduct(
                id: "\(idPrefix).yearly",
                displayName: "\(name) Yearly",
                description: "Every \(name) feature, billed yearly.",
                price: Decimal(3999) / 100,
                kind: .subscription,
                subscriptionPeriod: .yearly,
                introductoryOffer: .freeTrial(.weekly),
                subscriptionGroupID: "\(idPrefix).group"
            ),
            PaywallProduct(
                id: "\(idPrefix).lifetime",
                displayName: "\(name) Lifetime",
                description: "Every \(name) feature, forever.",
                price: Decimal(7999) / 100,
                kind: .lifetime
            ),
        ]
    }
}
