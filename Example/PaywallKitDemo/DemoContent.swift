import PaywallKit
import SwiftUI

/// Sample content for Lumina, a made-up photo editor.
enum DemoContent {
    static let violet = Color(red: 0.49, green: 0.27, blue: 0.93)

    /// The products in `Lumina.storekit`, in display order.
    static let productIDs = ["lumina.pro.monthly", "lumina.pro.yearly", "lumina.pro.lifetime"]
    static let yearlyID = "lumina.pro.yearly"
    static let lifetimeID = "lumina.pro.lifetime"

    /// The same three products as `Lumina.storekit`, for the preview store.
    static let previewProducts = PaywallProduct.previewProducts(idPrefix: "lumina.pro", name: "Lumina Pro")

    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    static let privacyURL = URL(string: "https://example.com/lumina/privacy")

    static let features: [PaywallFeature] = [
        PaywallFeature(
            systemImage: "camera.filters",
            title: "120 film filters",
            subtitle: "Portra, Velvia, Tri-X and more, matched to your camera.",
            free: .limited("12"),
            pro: .limited("All 120")
        ),
        PaywallFeature(
            systemImage: "wand.and.stars",
            title: "AI retouch",
            subtitle: "Remove people, wires and blemishes with one tap."
        ),
        PaywallFeature(
            systemImage: "camera.aperture",
            title: "RAW editing",
            subtitle: "ProRAW and DNG with a 16-bit pipeline."
        ),
        PaywallFeature(
            systemImage: "square.stack.3d.up.fill",
            title: "Batch export",
            subtitle: "Apply a look to 500 photos at once.",
            free: .limited("5"),
            pro: .limited("500")
        ),
        PaywallFeature(
            systemImage: "drop.fill",
            title: "No watermark",
            subtitle: "Your photos, without our logo."
        ),
        PaywallFeature(
            systemImage: "icloud.fill",
            title: "Presets on every device",
            subtitle: "Your looks sync through iCloud.",
            free: .included
        ),
    ]

    /// The hero paywall: the photo header and the first four features.
    static let heroContent = PaywallContent(
        title: "Lumina Pro",
        subtitle: "Every filter, every tool, no watermark.",
        header: .image("LuminaHero"),
        iconSystemImage: "camera.aperture",
        features: Array(features.prefix(4)),
        highlightedProductID: yearlyID,
        tint: violet,
        termsOfServiceURL: termsURL,
        privacyPolicyURL: privacyURL
    )

    /// The comparison paywall: every feature, free vs Pro.
    static let comparisonContent = PaywallContent(
        title: "Lumina Free vs Pro",
        subtitle: "Everything in Free, plus the tools pros use.",
        header: .image("LuminaHero"),
        iconSystemImage: "camera.aperture",
        features: features,
        highlightedProductID: yearlyID,
        tint: violet,
        termsOfServiceURL: termsURL,
        privacyPolicyURL: privacyURL
    )

    /// The minimal sheet: three features, subscriptions only.
    static let minimalContent = PaywallContent(
        title: "Unlock this filter",
        subtitle: "Get all 120 filters with Lumina Pro.",
        iconSystemImage: "camera.filters",
        features: Array(features.prefix(3)),
        highlightedProductID: yearlyID,
        hiddenProductIDs: [lifetimeID],
        tint: violet,
        termsOfServiceURL: termsURL,
        privacyPolicyURL: privacyURL
    )

    static func content(for template: PaywallTemplate) -> PaywallContent {
        switch template {
        case .hero: heroContent
        case .comparison: comparisonContent
        case .minimal: minimalContent
        }
    }

    /// Lumina's looks. The free ones come first.
    static let filters: [LuminaFilter] = [
        LuminaFilter(name: "Original", hue: 0, saturation: 1, contrast: 1, isPro: false),
        LuminaFilter(name: "Vivid", hue: 0, saturation: 1.45, contrast: 1.1, isPro: false),
        LuminaFilter(name: "Mono", hue: 0, saturation: 0, contrast: 1.2, isPro: false),
        LuminaFilter(name: "Portra", hue: -12, saturation: 0.85, contrast: 0.95, isPro: true),
        LuminaFilter(name: "Velvia", hue: 18, saturation: 1.6, contrast: 1.15, isPro: true),
        LuminaFilter(name: "Tri-X", hue: 0, saturation: 0, contrast: 1.5, isPro: true),
        LuminaFilter(name: "Teal", hue: 140, saturation: 1.1, contrast: 1.05, isPro: true),
    ]
}

/// A color look applied with SwiftUI modifiers.
struct LuminaFilter: Identifiable, Hashable {
    let name: String
    let hue: Double
    let saturation: Double
    let contrast: Double
    let isPro: Bool

    var id: String { name }
}

extension View {
    func luminaFilter(_ filter: LuminaFilter) -> some View {
        hueRotation(.degrees(filter.hue))
            .saturation(filter.saturation)
            .contrast(filter.contrast)
    }
}

/// Where the example gets its products: the App Store (or `Lumina.storekit` when run from Xcode),
/// or the in-memory preview store with `-previewStore`.
@MainActor
func makeDemoController() -> PaywallController {
    if ProcessInfo.processInfo.arguments.contains("-previewStore") {
        return PaywallController(productIDs: DemoContent.productIDs, store: PreviewPaywallStore(products: DemoContent.previewProducts))
    }
    return PaywallController(productIDs: DemoContent.productIDs)
}
