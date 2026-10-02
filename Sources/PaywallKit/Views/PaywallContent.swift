import SwiftUI

/// What a paywall says and how it looks. The same content works with every template.
///
/// ```swift
/// let content = PaywallContent(
///     title: "Unlock Lumina Pro",
///     subtitle: "Every filter, every tool, no watermark.",
///     header: .image("PaywallHero"),
///     iconSystemImage: "camera.aperture",
///     features: [
///         PaywallFeature(systemImage: "camera.filters", title: "120 film filters", free: .limited("12")),
///         PaywallFeature(systemImage: "wand.and.stars", title: "AI retouch"),
///     ],
///     highlightedProductID: "pro.yearly",
///     tint: .purple
/// )
/// ```
public struct PaywallContent: Sendable {
    public var title: LocalizedStringResource
    public var subtitle: LocalizedStringResource?
    /// The artwork at the top: an image from your asset catalog or an SF Symbol on the tint.
    public var header: PaywallHeader
    /// The SF Symbol on the icon tile of the comparison and minimal templates.
    public var iconSystemImage: String
    public var features: [PaywallFeature]
    /// The plan selected at first and marked "Best value" (or "Save x%"). Defaults to the first product.
    public var highlightedProductID: String?
    /// Products to leave off this paywall, for example a lifetime unlock on a compact sheet.
    public var hiddenProductIDs: Set<String>
    public var tint: Color
    /// Replaces "Start Free Trial", "Subscribe" or "Unlock Forever".
    public var callToAction: LocalizedStringResource?
    public var termsOfServiceURL: URL?
    public var privacyPolicyURL: URL?
    /// Names of the two columns of `ComparisonPaywall`.
    public var freeColumnTitle: LocalizedStringResource
    public var proColumnTitle: LocalizedStringResource

    public init(
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource? = nil,
        header: PaywallHeader = .symbol("crown.fill"),
        iconSystemImage: String = "crown.fill",
        features: [PaywallFeature] = [],
        highlightedProductID: String? = nil,
        hiddenProductIDs: Set<String> = [],
        tint: Color = .accentColor,
        callToAction: LocalizedStringResource? = nil,
        termsOfServiceURL: URL? = nil,
        privacyPolicyURL: URL? = nil,
        freeColumnTitle: LocalizedStringResource = "Free",
        proColumnTitle: LocalizedStringResource = "Pro"
    ) {
        self.title = title
        self.subtitle = subtitle
        self.header = header
        self.iconSystemImage = iconSystemImage
        self.features = features
        self.highlightedProductID = highlightedProductID
        self.hiddenProductIDs = hiddenProductIDs
        self.tint = tint
        self.callToAction = callToAction
        self.termsOfServiceURL = termsOfServiceURL
        self.privacyPolicyURL = privacyPolicyURL
        self.freeColumnTitle = freeColumnTitle
        self.proColumnTitle = proColumnTitle
    }

    /// The products this paywall shows, in order.
    func visibleProducts(from products: [PaywallProduct]) -> [PaywallProduct] {
        products.filter { !hiddenProductIDs.contains($0.id) && $0.grantsEntitlement }
    }

    /// The product selected before the user taps one.
    func defaultProductID(in products: [PaywallProduct]) -> String? {
        if let highlightedProductID, products.contains(where: { $0.id == highlightedProductID }) {
            return highlightedProductID
        }
        return products.first?.id
    }
}

/// The artwork at the top of a paywall.
public enum PaywallHeader: Sendable, Hashable {
    /// An image from the app's asset catalog, drawn edge to edge.
    case image(String)
    /// An SF Symbol, white on a tile of the tint.
    case symbol(String)
    /// No artwork.
    case none
}

/// One thing Pro gives the user.
public struct PaywallFeature: Identifiable, Sendable {
    public let id: UUID
    public var systemImage: String
    public var title: LocalizedStringResource
    public var subtitle: LocalizedStringResource?
    /// What the free version offers, for `ComparisonPaywall`.
    public var free: FeatureAvailability
    /// What Pro offers, for `ComparisonPaywall`.
    public var pro: FeatureAvailability
    /// Overrides the paywall's tint for this icon.
    public var tint: Color?

    public init(
        systemImage: String,
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource? = nil,
        free: FeatureAvailability = .excluded,
        pro: FeatureAvailability = .included,
        tint: Color? = nil
    ) {
        self.id = UUID()
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.free = free
        self.pro = pro
        self.tint = tint
    }
}

/// A cell of the free vs Pro table.
public enum FeatureAvailability: Sendable {
    /// A checkmark.
    case included
    /// A dash.
    case excluded
    /// A short text, such as "3 a day" or "720p".
    case limited(LocalizedStringResource)
}

/// The paywall layouts.
public enum PaywallTemplate: String, Sendable, Hashable, CaseIterable, Identifiable {
    /// A large image, the feature list and plan cards. Two columns on iPad and Mac.
    case hero
    /// A free vs Pro table above compact plan tiles.
    case comparison
    /// A compact sheet with three features and plan rows.
    case minimal

    public var id: String { rawValue }
}
