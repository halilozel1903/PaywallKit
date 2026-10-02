import SwiftUI

/// A compact paywall for a sheet: an icon, the title, the first three features and a row per plan.
///
/// `.paywall(isPresented:controller:content:template: .minimal)` presents it as a sheet that
/// leaves the app visible above it.
///
/// ```swift
/// .sheet(isPresented: $showsPaywall) {
///     MinimalPaywall(controller: paywall, content: content)
///         .presentationDetents([.height(640), .large])
/// }
/// ```
public struct MinimalPaywall: View {
    private let controller: PaywallController
    private let content: PaywallContent
    private let showsCloseButton: Bool
    private let featureLimit: Int

    @State private var selectedID: String?
    @Environment(\.dismiss) private var dismiss

    /// - Parameters:
    ///   - featureLimit: How many features to list. Three by default.
    public init(controller: PaywallController, content: PaywallContent, showsCloseButton: Bool = true, featureLimit: Int = 3) {
        self.controller = controller
        self.content = content
        self.showsCloseButton = showsCloseButton
        self.featureLimit = max(0, featureLimit)
    }

    public var body: some View {
        let products = content.visibleProducts(from: controller.products)
        let formatter = PlanFormatter(matching: products)
        let selected = content.selectedProduct(id: selectedID, in: products)

        ScrollView {
            VStack(spacing: 20) {
                HStack(alignment: .center, spacing: 14) {
                    PaywallIconTile(systemImage: content.iconSystemImage, tint: content.tint, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(content.title)
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        if let subtitle = content.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.trailing, showsCloseButton ? 36 : 0)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(content.features.prefix(featureLimit)) { feature in
                        Label {
                            Text(feature.title)
                                .font(.callout.weight(.medium))
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(content.tint)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if products.isEmpty {
                    PaywallProductsPlaceholder(controller: controller, tint: content.tint)
                } else {
                    VStack(spacing: 10) {
                        ForEach(products) { product in
                            PlanCard(
                                product: product,
                                products: products,
                                isSelected: product.id == selected?.id,
                                isHighlighted: product.id == content.highlightedProductID,
                                tint: content.tint,
                                formatter: formatter,
                                isCompact: true
                            ) {
                                selectedID = product.id
                            }
                        }
                    }
                    .padding(.top, 6)
                }

                PaywallPurchaseFooter(controller: controller, product: selected, content: content, formatter: formatter)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
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

#Preview("Minimal") {
    Color.gray.opacity(0.2)
        .sheet(isPresented: .constant(true)) {
            MinimalPaywall(
                controller: .preview(),
                content: PaywallContent(
                    title: "Go Pro",
                    subtitle: "Everything, unlocked.",
                    iconSystemImage: "bolt.fill",
                    features: [
                        PaywallFeature(systemImage: "infinity", title: "Unlimited projects"),
                        PaywallFeature(systemImage: "icloud", title: "iCloud sync"),
                        PaywallFeature(systemImage: "wand.and.stars", title: "Smart tools"),
                    ],
                    highlightedProductID: "pro.yearly",
                    tint: .orange
                )
            )
            .presentationDetents([.height(640), .large])
        }
}
