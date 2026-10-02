import SwiftUI

/// A paywall with a large image on top, the features in a grid and a card per plan.
///
/// On iPad and Mac (700 points wide or more) the image fills the left half with the title on it,
/// and the features and plans sit on the right.
///
/// ```swift
/// HeroPaywall(controller: paywall, content: content)
/// ```
public struct HeroPaywall: View {
    private let controller: PaywallController
    private let content: PaywallContent
    private let showsCloseButton: Bool

    @State private var selectedID: String?
    @Environment(\.dismiss) private var dismiss

    /// - Parameters:
    ///   - controller: Products, purchases and the entitlement.
    ///   - content: Texts, artwork, features and tint.
    ///   - showsCloseButton: Shows an × that dismisses the presentation.
    public init(controller: PaywallController, content: PaywallContent, showsCloseButton: Bool = true) {
        self.controller = controller
        self.content = content
        self.showsCloseButton = showsCloseButton
    }

    public var body: some View {
        GeometryReader { proxy in
            if proxy.size.width >= 700 {
                wideLayout(size: proxy.size)
            } else {
                compactLayout
            }
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

    // MARK: Layouts

    private var compactLayout: some View {
        ScrollView {
            VStack(spacing: 20) {
                Color.clear
                    .frame(height: 210)
                    .overlay { PaywallHeaderArtwork(header: content.header, tint: content.tint) }
                    .clipped()
                    .mask {
                        LinearGradient(
                            stops: [.init(color: .black, location: 0.6), .init(color: .clear, location: 1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                VStack(spacing: 22) {
                    titleBlock(alignment: .center)
                    featureGrid
                    plans
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .background(.bar, ignoresSafeAreaEdges: .bottom)
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    private func wideLayout(size: CGSize) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .overlay { PaywallHeaderArtwork(header: content.header, tint: content.tint) }
                .overlay(alignment: .bottomLeading) {
                    titleBlock(alignment: .leading)
                        .foregroundStyle(.white)
                        .padding(40)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                        }
                }
                .clipped()
                .frame(width: size.width * 0.46)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(content.features) { feature in
                                PaywallFeatureRow(feature: feature, tint: content.tint)
                            }
                        }
                        plans
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 72)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)

                footer
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                    .frame(maxWidth: 560)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Parts

    private func titleBlock(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(content.title)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            if let subtitle = content.subtitle {
                Text(subtitle)
                    .font(.body)
                    .opacity(0.8)
            }
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var featureGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 14) {
            ForEach(content.features) { feature in
                HStack(spacing: 10) {
                    Image(systemName: feature.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(feature.tint ?? content.tint)
                        .frame(width: 32, height: 32)
                        .background((feature.tint ?? content.tint).opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .accessibilityHidden(true)
                    Text(feature.title)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var plans: some View {
        let products = content.visibleProducts(from: controller.products)
        if products.isEmpty {
            PaywallProductsPlaceholder(controller: controller, tint: content.tint)
        } else {
            let formatter = PlanFormatter(matching: products)
            let selected = content.selectedProduct(id: selectedID, in: products)
            VStack(spacing: 14) {
                ForEach(products) { product in
                    PlanCard(
                        product: product,
                        products: products,
                        isSelected: product.id == selected?.id,
                        isHighlighted: product.id == content.highlightedProductID,
                        tint: content.tint,
                        formatter: formatter
                    ) {
                        selectedID = product.id
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private var footer: some View {
        let products = content.visibleProducts(from: controller.products)
        return PaywallPurchaseFooter(
            controller: controller,
            product: content.selectedProduct(id: selectedID, in: products),
            content: content,
            formatter: PlanFormatter(matching: products)
        )
    }
}

extension PaywallContent {
    /// The product the user picked, or the default one.
    func selectedProduct(id: String?, in products: [PaywallProduct]) -> PaywallProduct? {
        if let id, let product = products.first(where: { $0.id == id }) {
            return product
        }
        let fallback = defaultProductID(in: products)
        return products.first { $0.id == fallback }
    }
}

#Preview("Hero") {
    HeroPaywall(
        controller: .preview(),
        content: PaywallContent(
            title: "Unlock Pro",
            subtitle: "Every feature, on every device.",
            header: .symbol("sparkles"),
            features: [
                PaywallFeature(systemImage: "infinity", title: "Unlimited projects"),
                PaywallFeature(systemImage: "icloud", title: "iCloud sync"),
                PaywallFeature(systemImage: "wand.and.stars", title: "Smart tools"),
                PaywallFeature(systemImage: "heart", title: "Support an indie"),
            ],
            highlightedProductID: "pro.yearly",
            tint: .indigo
        )
    )
}
