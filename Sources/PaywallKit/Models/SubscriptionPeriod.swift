import Foundation

/// The length of a subscription period or an introductory offer, such as "1 year" or "3 days".
///
/// Mirrors `Product.SubscriptionPeriod` from StoreKit, but is a plain value you can create in
/// tests and previews.
public struct SubscriptionPeriod: Sendable, Hashable, Codable {
    public enum Unit: String, Sendable, Hashable, Codable, CaseIterable {
        case day
        case week
        case month
        case year
    }

    /// The number of units, at least 1.
    public var value: Int
    public var unit: Unit

    public init(value: Int, unit: Unit) {
        self.value = max(1, value)
        self.unit = unit
    }

    public static let weekly = SubscriptionPeriod(value: 1, unit: .week)
    public static let monthly = SubscriptionPeriod(value: 1, unit: .month)
    public static let yearly = SubscriptionPeriod(value: 1, unit: .year)

    public static func days(_ value: Int) -> SubscriptionPeriod { SubscriptionPeriod(value: value, unit: .day) }
    public static func weeks(_ value: Int) -> SubscriptionPeriod { SubscriptionPeriod(value: value, unit: .week) }
    public static func months(_ value: Int) -> SubscriptionPeriod { SubscriptionPeriod(value: value, unit: .month) }
    public static func years(_ value: Int) -> SubscriptionPeriod { SubscriptionPeriod(value: value, unit: .year) }

    /// The period repeated `count` times: 1 month × 3 is 3 months.
    public func multiplied(by count: Int) -> SubscriptionPeriod {
        SubscriptionPeriod(value: value * max(1, count), unit: unit)
    }

    /// How many of these periods fit in a year, using 365 days, 52 weeks and 12 months a year.
    /// Used to compare plans that bill at different intervals.
    public var periodsPerYear: Decimal {
        let count = Decimal(value)
        switch unit {
        case .day: return 365 / count
        case .week: return 52 / count
        case .month: return 12 / count
        case .year: return 1 / count
        }
    }

    /// The date one period after `date`, in calendar days, months and years. Uses the Gregorian
    /// calendar in UTC unless you pass another calendar.
    public func date(after date: Date, calendar: Calendar = SubscriptionPeriod.utcCalendar) -> Date {
        let component: Calendar.Component
        let amount: Int
        switch unit {
        case .day: component = .day; amount = value
        case .week: component = .day; amount = value * 7
        case .month: component = .month; amount = value
        case .year: component = .year; amount = value
        }
        return calendar.date(byAdding: component, value: amount, to: date) ?? date
    }

    /// The Gregorian calendar in UTC, so a period never gains or loses an hour to daylight saving time.
    public static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar
    }
}
