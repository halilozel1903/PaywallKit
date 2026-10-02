import Foundation

/// Turns products into the texts of a paywall: "$39.99/year", "$3.33/month", "Save 33%",
/// "1 week free, then $39.99/year".
///
/// The locale decides how amounts are written ("$39.99", "39,99 €"); inject it in tests. The
/// templates use the storefront's locale from the products. Words are English.
public struct PlanFormatter: Sendable {
    public var locale: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
    }

    /// A formatter with the storefront locale of `products`, or the current locale.
    public init(matching products: [PaywallProduct]) {
        self.init(locale: products.first?.priceLocale ?? .current)
    }

    // MARK: Amounts

    /// `amount` in `currencyCode`, for example "$39.99".
    public func format(_ amount: Decimal, currencyCode: String) -> String {
        amount.formatted(.currency(code: currencyCode).locale(locale))
    }

    /// The product's price, for example "$39.99".
    public func price(of product: PaywallProduct) -> String {
        format(product.price, currencyCode: product.currencyCode)
    }

    /// The price with its billing period: "$39.99/year", "$14.99 every 3 months", or "$79.99" for
    /// products without a period.
    public func recurringPrice(of product: PaywallProduct) -> String {
        let amount = self.price(of: product)
        guard let period = product.subscriptionPeriod else { return amount }
        return amount + periodSuffix(period)
    }

    /// The price spread over `unit`, rounded to cents: "$3.33" for $39.99 a year per month.
    /// `nil` for products without a period.
    public func price(of product: PaywallProduct, per unit: SubscriptionPeriod.Unit) -> String? {
        guard let period = product.subscriptionPeriod else { return nil }
        let amount = PlanMath.rounded(PlanMath.price(product.price, per: period, in: unit))
        return format(amount, currencyCode: product.currencyCode)
    }

    /// The price spread over `unit` with the unit: "$3.33/month".
    public func pricePerUnit(of product: PaywallProduct, unit: SubscriptionPeriod.Unit) -> String? {
        price(of: product, per: unit).map { $0 + "/" + unitName(unit) }
    }

    /// The most useful smaller unit for a plan: a month for yearly plans, a week for monthly plans.
    /// `nil` for weekly and daily plans and products without a period.
    public func comparisonUnit(for product: PaywallProduct) -> SubscriptionPeriod.Unit? {
        guard let period = product.subscriptionPeriod else { return nil }
        switch period.unit {
        case .year: return .month
        case .month: return .week
        case .week, .day: return nil
        }
    }

    // MARK: Savings

    /// Whole percent saved compared with `reference`, rounded down. `nil` without a saving.
    public func savingsPercent(of product: PaywallProduct, comparedTo reference: PaywallProduct) -> Int? {
        guard product.id != reference.id,
              product.currencyCode == reference.currencyCode,
              let period = product.subscriptionPeriod,
              let referencePeriod = reference.subscriptionPeriod
        else { return nil }
        return PlanMath.savingsPercent(price: product.price, period: period, comparedTo: reference.price, per: referencePeriod)
    }

    /// "Save 33%" compared with the monthly plan (or the most expensive plan) in `products`.
    public func savingsText(for product: PaywallProduct, in products: [PaywallProduct]) -> String? {
        guard let reference = PlanMath.savingsReference(in: products),
              let percent = savingsPercent(of: product, comparedTo: reference)
        else { return nil }
        return "Save \(percent)%"
    }

    // MARK: Offers

    /// The introductory offer the user can redeem, in words:
    ///
    /// - Free trial: "1 week free, then $39.99/year"
    /// - Pay as you go: "$0.99/month for 3 months, then $4.99/month"
    /// - Pay up front: "$9.99 for 6 months, then $39.99/year"
    ///
    /// `nil` when there is no offer or the user is not eligible.
    public func introOfferText(for product: PaywallProduct) -> String? {
        guard let offer = product.eligibleIntroductoryOffer, product.subscriptionPeriod != nil else { return nil }
        return introOfferText(offer, product: product)
    }

    /// Describes `offer` for `product`, ignoring eligibility.
    public func introOfferText(_ offer: IntroductoryOffer, product: PaywallProduct) -> String {
        let renewal = "then " + recurringPrice(of: product)
        let total = duration(offer.totalDuration)
        switch offer.paymentMode {
        case .freeTrial:
            return "\(total) free, \(renewal)"
        case .payAsYouGo:
            let offerPrice = format(offer.price, currencyCode: product.currencyCode) + periodSuffix(offer.period)
            return "\(offerPrice) for \(total), \(renewal)"
        case .payUpFront:
            let offerPrice = format(offer.price, currencyCode: product.currencyCode)
            return "\(offerPrice) for \(total), \(renewal)"
        }
    }

    /// A short badge for an offer: "1 week free", "3 months for $0.99/month".
    public func introOfferBadge(for product: PaywallProduct) -> String? {
        guard let offer = product.eligibleIntroductoryOffer else { return nil }
        switch offer.paymentMode {
        case .freeTrial:
            return "\(duration(offer.totalDuration)) free"
        case .payAsYouGo:
            return "\(duration(offer.totalDuration)) at " + format(offer.price, currencyCode: product.currencyCode) + periodSuffix(offer.period)
        case .payUpFront:
            return "\(duration(offer.totalDuration)) for " + format(offer.price, currencyCode: product.currencyCode)
        }
    }

    // MARK: Labels

    /// "Yearly", "Monthly", "Weekly", "Daily", "6 Months" or "Lifetime".
    public func planName(for product: PaywallProduct) -> String {
        switch product.kind {
        case .lifetime:
            return "Lifetime"
        case .consumable:
            return product.displayName
        case .subscription, .nonRenewing:
            guard let period = product.subscriptionPeriod else { return product.displayName }
            guard period.value == 1 else { return "\(period.value) \(unitName(period.unit, plural: true).capitalized)" }
            switch period.unit {
            case .day: return "Daily"
            case .week: return "Weekly"
            case .month: return "Monthly"
            case .year: return "Yearly"
            }
        }
    }

    /// The line under the purchase button: what the user agrees to pay.
    ///
    /// - "1 week free, then $39.99/year. Cancel anytime."
    /// - "$4.99/month. Cancel anytime."
    /// - "One-time purchase. No subscription."
    public func billingText(for product: PaywallProduct) -> String {
        switch product.kind {
        case .lifetime:
            return "One-time purchase. No subscription."
        case .consumable:
            return "One-time purchase."
        case .nonRenewing:
            return recurringPrice(of: product) + ". Does not renew."
        case .subscription:
            if let offer = introOfferText(for: product) {
                return offer + ". Cancel anytime."
            }
            return recurringPrice(of: product) + ". Cancel anytime."
        }
    }

    /// "Start Free Trial", "Subscribe" or "Unlock Forever".
    public func callToAction(for product: PaywallProduct) -> String {
        if product.hasEligibleFreeTrial { return "Start Free Trial" }
        switch product.kind {
        case .lifetime: return "Unlock Forever"
        case .consumable: return "Buy"
        case .subscription, .nonRenewing: return "Subscribe"
        }
    }

    /// "1 week", "3 days", "6 months".
    public func duration(_ period: SubscriptionPeriod) -> String {
        "\(period.value) \(unitName(period.unit, plural: period.value != 1))"
    }

    /// "/year" for one unit, " every 3 months" for more.
    public func periodSuffix(_ period: SubscriptionPeriod) -> String {
        period.value == 1 ? "/" + unitName(period.unit) : " every " + duration(period)
    }

    func unitName(_ unit: SubscriptionPeriod.Unit, plural: Bool = false) -> String {
        let name: String
        switch unit {
        case .day: name = "day"
        case .week: name = "week"
        case .month: name = "month"
        case .year: name = "year"
        }
        return plural ? name + "s" : name
    }
}
