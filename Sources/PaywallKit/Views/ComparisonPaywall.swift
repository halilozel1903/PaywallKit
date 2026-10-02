import SwiftUI

/// A paywall that compares the free version with Pro in a table, above side-by-side plan tiles.
///
/// Each `PaywallFeature` is a row; its `free` and `pro` values fill the two columns.
///
/// ```swift
/// ComparisonPaywall(controller: paywall, content: content)
/// ```
public struct ComparisonPaywall: View {
    private let controller: PaywallController
    private let content: PaywallContent
    private let showsCloseButton: Bool

    @State private var selectedID: String?
    @Environment(\.dismiss) private var dismiss

    public init(controller: PaywallController, content: PaywallContent, showsCloseButton: Bool = true) {
        self.controller = controller
        self.content = content
        self.showsCloseButton = showsCloseButton
    }

    public var body: some View {
        let products = content.visibleProducts(from: controller.products)
        let formatter = PlanFormatter(matching: products)
        let selected = content.selectedProduct(id: selectedID, in: products)

        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 12) {
                    PaywallIconTile(systemImage: content.iconSystemImage, tint: content.tint, size: 68)
                    Text(content.title)
                        .font(.title.bold())
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle = content.subtitle {
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                ComparisonTable(content: content)

                if products.isEmpty {
                    PaywallProductsPlaceholder(controller: controller, tint: content.tint)
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(products) { product in
                            PlanTile(
                                product: product,
                                products: products,
                                isSelected: product.id == selected?.id,
                                tint: content.tint,
                                formatter: formatter
                            ) {
                                selectedID = product.id
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PaywallPurchaseFooter(controller: controller, product: selected, content: content, formatter: formatter)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
                .background(.bar, ignoresSafeAreaEdges: .bottom)
        }
        .background { PaywallBackground(tint: content.tint) }
        .overlay(alignment: .topTrailing) {
            if showsCloseButton {
                PaywallCloseButton { dismiss() }
                    .padding(16)
            }
        }
        .tint(content.tint)
        .task { await controller.start() }
    }
}

/// The free vs Pro table, with the Pro column on a tinted strip.
struct ComparisonTable: View {
    let content: PaywallContent
    @ScaledMetric(relativeTo: .subheadline) private var columnWidth: CGFloat = 64

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Features")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(content.freeColumnTitle)
                    .foregroundStyle(.secondary)
                    .frame(width: columnWidth)
                HStack(spacing: 3) {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                    Text(content.proColumnTitle)
                }
                .foregroundStyle(content.tint)
                .frame(width: columnWidth)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 12)

            ForEach(content.features) { feature in
                Divider()
                HStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: feature.systemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(feature.tint ?? content.tint)
                            .frame(width: 22)
                            .accessibilityHidden(true)
                        Text(feature.title)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    AvailabilityCell(availability: feature.free, tint: Color.secondary, isPro: false)
                        .frame(width: columnWidth)
                    AvailabilityCell(availability: feature.pro, tint: content.tint, isPro: true)
                        .frame(width: columnWidth)
                }
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .background(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(content.tint.opacity(0.12))
                .frame(width: columnWidth)
                .padding(.trailing, 16)
                .padding(.vertical, 6)
        }
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.secondary.opacity(0.07))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        }
    }
}

/// One cell of the table: a checkmark, a dash or a short text.
struct AvailabilityCell: View {
    let availability: FeatureAvailability
    let tint: Color
    let isPro: Bool

    var body: some View {
        switch availability {
        case .included:
            Image(systemName: "checkmark.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityLabel(Text(isPro ? "Included in Pro" : "Included for free"))
        case .excluded:
            Image(systemName: "minus")
                .font(.body.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityLabel(Text(isPro ? "Not in Pro" : "Not included for free"))
        case .limited(let text):
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isPro ? tint : Color.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
}

#Preview("Comparison") {
    ComparisonPaywall(
        controller: .preview(),
        content: PaywallContent(
            title: "Free vs Pro",
            subtitle: "See what you get.",
            iconSystemImage: "sparkles",
            features: [
                PaywallFeature(systemImage: "folder", title: "Projects", free: .limited("3"), pro: .limited("Unlimited")),
                PaywallFeature(systemImage: "icloud", title: "iCloud sync"),
                PaywallFeature(systemImage: "square.and.arrow.up", title: "Export", free: .included),
            ],
            highlightedProductID: "pro.yearly",
            tint: .indigo
        )
    )
}
