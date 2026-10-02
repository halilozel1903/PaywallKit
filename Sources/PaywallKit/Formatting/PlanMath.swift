import Foundation

/// Price arithmetic behind the paywall texts. Pure functions on `Decimal`, so money never goes
/// through `Double`.
public enum PlanMath {
    /// `price`, billed every `period`, spread over `unit`: $39.99 a year is $3.3325 a month.
    /// Uses 365 days, 52 weeks and 12 months a year. Not rounded.
    public static func price(_ price: Decimal, per period: SubscriptionPeriod, in unit: SubscriptionPeriod.Unit) -> Decimal {
        let yearly = price * period.periodsPerYear
        switch unit {
        case .day: return yearly / 365
        case .week: return yearly / 52
        case .month: return yearly / 12
        case .year: return yearly
        }
    }

    /// How much cheaper `price` per `period` is than `referencePrice` per `referencePeriod`, in
    /// whole percent, rounded down so the paywall never promises more than the user saves.
    /// `nil` when it is not cheaper or the reference is free.
    ///
    /// $39.99 a year against $4.99 a month ($59.88 a year) saves 33%.
    public static func savingsPercent(
        price: Decimal,
        period: SubscriptionPeriod,
        comparedTo referencePrice: Decimal,
        per referencePeriod: SubscriptionPeriod
    ) -> Int? {
        let annual = price * period.periodsPerYear
        let referenceAnnual = referencePrice * referencePeriod.periodsPerYear
        guard referenceAnnual > 0, annual < referenceAnnual else { return nil }
        let fraction = (referenceAnnual - annual) / referenceAnnual * 100
        let percent = NSDecimalNumber(decimal: rounded(fraction, scale: 0, mode: .down)).intValue
        return percent > 0 ? percent : nil
    }

    /// `value` rounded to `scale` decimal places. `.plain` rounds half away from zero.
    public static func rounded(_ value: Decimal, scale: Int = 2, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, mode)
        return result
    }

    /// The plan other plans are compared with for "Save x%": the monthly subscription if there is
    /// one, otherwise the subscription that costs the most per year.
    public static func savingsReference(in products: [PaywallProduct]) -> PaywallProduct? {
        let subscriptions = products.filter { $0.kind == .subscription && $0.subscriptionPeriod != nil }
        if let monthly = subscriptions.first(where: { $0.subscriptionPeriod == .monthly }) {
            return monthly
        }
        return subscriptions.max { ($0.annualizedPrice ?? 0) < ($1.annualizedPrice ?? 0) }
    }
}
