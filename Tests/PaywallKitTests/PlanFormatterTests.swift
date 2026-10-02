import Foundation
import Testing
@testable import PaywallKit

/// `Decimal` from cents, so test prices never go through `Double`.
func dollars(_ cents: Int) -> Decimal {
    Decimal(cents) / 100
}

let usFormatter = PlanFormatter(locale: Locale(identifier: "en_US"))

let monthly = PaywallProduct(id: "pro.monthly", displayName: "Monthly", price: dollars(499), subscriptionPeriod: .monthly)
let yearly = PaywallProduct(
    id: "pro.yearly",
    displayName: "Yearly",
    price: dollars(3999),
    subscriptionPeriod: .yearly,
    introductoryOffer: .freeTrial(.weekly)
)
let weekly = PaywallProduct(id: "pro.weekly", displayName: "Weekly", price: dollars(299), subscriptionPeriod: .weekly)
let lifetime = PaywallProduct(id: "pro.lifetime", displayName: "Lifetime", price: dollars(7999), kind: .lifetime)

@Suite("Price math")
struct PlanMathTests {
    @Test func yearlyPricePerMonthAndWeek() {
        #expect(PlanMath.price(dollars(3999), per: .yearly, in: .month) == Decimal(string: "3.3325"))
        #expect(PlanMath.rounded(PlanMath.price(dollars(3999), per: .yearly, in: .month)) == dollars(333))
        #expect(PlanMath.rounded(PlanMath.price(dollars(3999), per: .yearly, in: .week)) == dollars(77))
    }

    @Test func monthlyPricePerWeekAndYear() {
        #expect(PlanMath.rounded(PlanMath.price(dollars(499), per: .monthly, in: .week)) == dollars(115))
        #expect(PlanMath.price(dollars(499), per: .monthly, in: .year) == dollars(5988))
    }

    @Test func multiMonthPeriods() {
        // $14.99 every 3 months is $4.996… a month.
        #expect(PlanMath.rounded(PlanMath.price(dollars(1499), per: .months(3), in: .month)) == dollars(500))
        #expect(PlanMath.price(dollars(1499), per: .months(3), in: .year) == dollars(5996))
    }

    @Test func roundingModes() {
        let value = Decimal(string: "2.345")!
        #expect(PlanMath.rounded(value) == Decimal(string: "2.35"))
        #expect(PlanMath.rounded(value, mode: .down) == Decimal(string: "2.34"))
        #expect(PlanMath.rounded(value, scale: 0) == 2)
    }

    @Test func savingsAgainstMonthly() {
        // $39.99 against $59.88 a year saves 33.2%, shown as 33%.
        #expect(PlanMath.savingsPercent(price: dollars(3999), period: .yearly, comparedTo: dollars(499), per: .monthly) == 33)
        // $29.99 against $59.88 saves 49.9%: rounded down, never up to 50%.
        #expect(PlanMath.savingsPercent(price: dollars(2999), period: .yearly, comparedTo: dollars(499), per: .monthly) == 49)
    }

    @Test func noSavingsWhenNotCheaper() {
        #expect(PlanMath.savingsPercent(price: dollars(6999), period: .yearly, comparedTo: dollars(499), per: .monthly) == nil)
        #expect(PlanMath.savingsPercent(price: dollars(5988), period: .yearly, comparedTo: dollars(499), per: .monthly) == nil)
        #expect(PlanMath.savingsPercent(price: dollars(3999), period: .yearly, comparedTo: 0, per: .monthly) == nil)
    }

    @Test func savingsReferencePrefersMonthly() {
        #expect(PlanMath.savingsReference(in: [yearly, monthly, weekly, lifetime])?.id == "pro.monthly")
        #expect(PlanMath.savingsReference(in: [yearly, weekly, lifetime])?.id == "pro.weekly")
        #expect(PlanMath.savingsReference(in: [lifetime]) == nil)
    }

    @Test func periodsPerYear() {
        #expect(SubscriptionPeriod.weekly.periodsPerYear == 52)
        #expect(SubscriptionPeriod.monthly.periodsPerYear == 12)
        #expect(SubscriptionPeriod.months(6).periodsPerYear == 2)
        #expect(SubscriptionPeriod.yearly.periodsPerYear == 1)
    }

    @Test func periodDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 31)))
        let afterWeek = SubscriptionPeriod.weekly.date(after: start, calendar: calendar)
        let afterMonth = SubscriptionPeriod.monthly.date(after: start, calendar: calendar)
        #expect(calendar.component(.month, from: afterWeek) == 2)
        #expect(calendar.component(.day, from: afterWeek) == 7)
        // Calendar months: January 31 plus one month is the last day of February.
        #expect(calendar.component(.month, from: afterMonth) == 2)
        #expect(calendar.component(.day, from: afterMonth) == 28)
    }
}

@Suite("Plan texts")
struct PlanFormatterTests {
    @Test func prices() {
        #expect(usFormatter.price(of: yearly) == "$39.99")
        #expect(usFormatter.recurringPrice(of: yearly) == "$39.99/year")
        #expect(usFormatter.recurringPrice(of: monthly) == "$4.99/month")
        #expect(usFormatter.recurringPrice(of: lifetime) == "$79.99")
    }

    @Test func multiUnitPeriods() {
        let quarterly = PaywallProduct(id: "q", displayName: "Quarterly", price: dollars(1499), subscriptionPeriod: .months(3))
        #expect(usFormatter.recurringPrice(of: quarterly) == "$14.99 every 3 months")
        #expect(usFormatter.planName(for: quarterly) == "3 Months")
    }

    @Test func pricePerUnit() {
        #expect(usFormatter.pricePerUnit(of: yearly, unit: .month) == "$3.33/month")
        #expect(usFormatter.pricePerUnit(of: yearly, unit: .week) == "$0.77/week")
        #expect(usFormatter.pricePerUnit(of: monthly, unit: .week) == "$1.15/week")
        #expect(usFormatter.pricePerUnit(of: lifetime, unit: .month) == nil)
    }

    @Test func comparisonUnits() {
        #expect(usFormatter.comparisonUnit(for: yearly) == .month)
        #expect(usFormatter.comparisonUnit(for: monthly) == .week)
        #expect(usFormatter.comparisonUnit(for: weekly) == nil)
        #expect(usFormatter.comparisonUnit(for: lifetime) == nil)
    }

    @Test func savingsText() {
        let products = [monthly, yearly, lifetime]
        #expect(usFormatter.savingsText(for: yearly, in: products) == "Save 33%")
        #expect(usFormatter.savingsText(for: monthly, in: products) == nil)
        #expect(usFormatter.savingsText(for: lifetime, in: products) == nil)
        #expect(usFormatter.savingsPercent(of: yearly, comparedTo: weekly) == 74)
    }

    @Test func savingsNeedTheSameCurrency() {
        var euroMonthly = monthly
        euroMonthly.currencyCode = "EUR"
        #expect(usFormatter.savingsPercent(of: yearly, comparedTo: euroMonthly) == nil)
    }

    @Test func freeTrialText() {
        #expect(usFormatter.introOfferText(for: yearly) == "1 week free, then $39.99/year")
        #expect(usFormatter.introOfferBadge(for: yearly) == "1 week free")
        #expect(usFormatter.billingText(for: yearly) == "1 week free, then $39.99/year. Cancel anytime.")
        #expect(usFormatter.callToAction(for: yearly) == "Start Free Trial")
    }

    @Test func multiDayTrialText() {
        let product = PaywallProduct(
            id: "trial",
            displayName: "Monthly",
            price: dollars(999),
            subscriptionPeriod: .monthly,
            introductoryOffer: .freeTrial(.days(3))
        )
        #expect(usFormatter.introOfferText(for: product) == "3 days free, then $9.99/month")
    }

    @Test func payAsYouGoText() {
        let product = PaywallProduct(
            id: "intro",
            displayName: "Monthly",
            price: dollars(499),
            subscriptionPeriod: .monthly,
            introductoryOffer: IntroductoryOffer(paymentMode: .payAsYouGo, price: dollars(99), period: .monthly, periodCount: 3)
        )
        #expect(usFormatter.introOfferText(for: product) == "$0.99/month for 3 months, then $4.99/month")
        #expect(usFormatter.introOfferBadge(for: product) == "3 months at $0.99/month")
        #expect(usFormatter.callToAction(for: product) == "Subscribe")
    }

    @Test func payUpFrontText() {
        let product = PaywallProduct(
            id: "upfront",
            displayName: "Yearly",
            price: dollars(3999),
            subscriptionPeriod: .yearly,
            introductoryOffer: IntroductoryOffer(paymentMode: .payUpFront, price: dollars(999), period: .months(6))
        )
        #expect(usFormatter.introOfferText(for: product) == "$9.99 for 6 months, then $39.99/year")
    }

    @Test func ineligibleOfferIsHidden() {
        var product = yearly
        product.isEligibleForIntroOffer = false
        #expect(usFormatter.introOfferText(for: product) == nil)
        #expect(usFormatter.introOfferBadge(for: product) == nil)
        #expect(usFormatter.billingText(for: product) == "$39.99/year. Cancel anytime.")
        #expect(usFormatter.callToAction(for: product) == "Subscribe")
    }

    @Test func lifetimeTexts() {
        #expect(usFormatter.planName(for: lifetime) == "Lifetime")
        #expect(usFormatter.billingText(for: lifetime) == "One-time purchase. No subscription.")
        #expect(usFormatter.callToAction(for: lifetime) == "Unlock Forever")
    }

    @Test func planNames() {
        #expect(usFormatter.planName(for: weekly) == "Weekly")
        #expect(usFormatter.planName(for: monthly) == "Monthly")
        #expect(usFormatter.planName(for: yearly) == "Yearly")
    }

    @Test func durations() {
        #expect(usFormatter.duration(.weekly) == "1 week")
        #expect(usFormatter.duration(.days(3)) == "3 days")
        #expect(usFormatter.duration(.months(6)) == "6 months")
        #expect(usFormatter.duration(.weekly.multiplied(by: 2)) == "2 weeks")
    }

    @Test func injectedLocaleFormatsAmounts() {
        let german = PlanFormatter(locale: Locale(identifier: "de_DE"))
        let euro = PaywallProduct(id: "eur", displayName: "Yearly", price: dollars(3999), currencyCode: "EUR", subscriptionPeriod: .yearly)
        let text = german.recurringPrice(of: euro)
        #expect(text.contains("39,99"))
        #expect(text.contains("€"))
        #expect(text.hasSuffix("/year"))
    }

    @Test func formatterMatchesTheStorefront() {
        let japan = Locale(identifier: "ja_JP")
        let yen = PaywallProduct(id: "jpy", displayName: "Yearly", price: 4800, currencyCode: "JPY", priceLocale: japan, subscriptionPeriod: .yearly)
        let formatter = PlanFormatter(matching: [yen])
        #expect(formatter.locale == japan)
        #expect(formatter.price(of: yen).contains("4,800"))
    }
}
