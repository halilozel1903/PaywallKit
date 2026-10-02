import SwiftUI

// MARK: - Liquid Glass with fallbacks

extension View {
    /// Liquid Glass on iOS 26 / macOS 26, a thin material before.
    @ViewBuilder
    func paywallGlass(in shape: some Shape) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }

    /// `.glassProminent` on iOS 26 / macOS 26, `.borderedProminent` before.
    @ViewBuilder
    func paywallProminentButtonStyle() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    /// `.glass` on iOS 26 / macOS 26, `.bordered` before.
    @ViewBuilder
    func paywallGlassButtonStyle() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// Gives sheets a sensible size on the Mac, where they otherwise shrink to fit their content.
    @ViewBuilder
    func paywallSheetFrame() -> some View {
        #if os(macOS)
        frame(minWidth: 720, idealWidth: 860, minHeight: 600, idealHeight: 680)
        #else
        self
        #endif
    }
}

// MARK: - Buttons

/// The purchase button: Liquid Glass on iOS 26 and macOS 26, a bordered prominent capsule before.
struct PaywallPrimaryButton: View {
    let title: String
    let tint: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Text(title)
                    .font(.headline)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .controlSize(.large)
        .buttonBorderShape(.capsule)
        .paywallProminentButtonStyle()
        .tint(tint)
        .keyboardShortcut(.defaultAction)
        .accessibilityLabel(Text(title))
    }
}

/// A round close button in the top corner.
struct PaywallCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .paywallGlass(in: Circle())
        .keyboardShortcut(.cancelAction)
        .accessibilityLabel(Text("Close"))
    }
}

// MARK: - Header

/// The artwork of `PaywallContent.header`.
struct PaywallHeaderArtwork: View {
    let header: PaywallHeader
    let tint: Color

    var body: some View {
        switch header {
        case .image(let name):
            Image(name)
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        case .symbol(let name):
            ZStack {
                LinearGradient(
                    colors: [tint, tint.opacity(0.65)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: name)
                    .font(.system(size: 88, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            }
            .accessibilityHidden(true)
        case .none:
            Color.clear
        }
    }
}

/// An SF Symbol on a rounded tile of the tint, used by the compact templates.
struct PaywallIconTile: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 64

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(tint.gradient)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
            }
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.35), radius: size * 0.14, y: size * 0.07)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A soft wash of the tint behind a paywall.
struct PaywallBackground: View {
    let tint: Color

    var body: some View {
        ZStack {
            Rectangle().fill(.background)
            LinearGradient(
                colors: [tint.opacity(0.20), tint.opacity(0.05), .clear],
                startPoint: .top,
                endPoint: .center
            )
            RadialGradient(
                colors: [tint.opacity(0.16), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Features

/// One row of the feature list: tinted icon, bold title, optional description.
struct PaywallFeatureRow: View {
    let feature: PaywallFeature
    let tint: Color
    @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 22

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: feature.systemImage)
                .font(.system(size: iconSize, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(feature.tint ?? tint)
                .frame(width: iconSize * 1.7, height: iconSize * 1.7)
                .background((feature.tint ?? tint).opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.headline)
                if let subtitle = feature.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Plans

/// A full-width plan card: radio button, name and offer on the left, price on the right.
struct PlanCard: View {
    let product: PaywallProduct
    let products: [PaywallProduct]
    let isSelected: Bool
    let isHighlighted: Bool
    let tint: Color
    let formatter: PlanFormatter
    var isCompact = false
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? tint : Color.secondary.opacity(0.6))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(formatter.planName(for: product))
                            .font(.headline)
                        if let badge = formatter.introOfferBadge(for: product) {
                            Text(badge)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(tint)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(tint.opacity(0.14), in: Capsule())
                        }
                    }
                    if !isCompact {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatter.price(of: product))
                        .font(.headline)
                        .monospacedDigit()
                    Text(periodLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, isCompact ? 12 : 14)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.10) : Color.secondary.opacity(0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? tint : Color.secondary.opacity(0.18), lineWidth: isSelected ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if let badge = highlightBadge {
                    Text(badge)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(tint, in: Capsule())
                        .offset(x: -14, y: -11)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// "$3.33/month", "$1.15/week" or "One-time purchase".
    private var detail: String {
        if product.kind == .lifetime { return "One-time purchase" }
        if let unit = formatter.comparisonUnit(for: product), let perUnit = formatter.pricePerUnit(of: product, unit: unit) {
            return "Just \(perUnit)"
        }
        return product.description
    }

    private var periodLabel: String {
        guard let period = product.subscriptionPeriod else {
            return product.kind == .lifetime ? "once" : ""
        }
        return period.value == 1 ? "per \(formatter.unitName(period.unit))" : "every \(formatter.duration(period))"
    }

    private var highlightBadge: String? {
        if let savings = formatter.savingsText(for: product, in: products) {
            return isHighlighted ? savings : nil
        }
        return isHighlighted ? "Best value" : nil
    }
}

/// A narrow plan tile for side-by-side layouts.
struct PlanTile: View {
    let product: PaywallProduct
    let products: [PaywallProduct]
    let isSelected: Bool
    let tint: Color
    let formatter: PlanFormatter
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 6) {
                Text(formatter.planName(for: product))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? tint : .primary)
                Text(formatter.price(of: product))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.top, 18)
            .padding(.bottom, 14)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.10) : Color.secondary.opacity(0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? tint : Color.secondary.opacity(0.18), lineWidth: isSelected ? 2 : 1)
            }
            .overlay(alignment: .top) {
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(tint, in: Capsule())
                        .offset(y: -9)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var caption: String {
        if product.kind == .lifetime { return "one time" }
        if let unit = formatter.comparisonUnit(for: product), let perUnit = formatter.pricePerUnit(of: product, unit: unit) {
            return perUnit
        }
        return product.subscriptionPeriod.map { "per " + formatter.unitName($0.unit) } ?? ""
    }

    private var badge: String? {
        formatter.savingsText(for: product, in: products) ?? formatter.introOfferBadge(for: product)
    }
}

// MARK: - Purchase footer

/// The purchase button, what the user agrees to pay, Restore Purchases and the legal links.
/// Buys the selected product and dismisses the paywall when the purchase or restore succeeds.
struct PaywallPurchaseFooter: View {
    let controller: PaywallController
    let product: PaywallProduct?
    let content: PaywallContent
    let formatter: PlanFormatter

    @Environment(\.dismiss) private var dismiss
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showsAlert = false

    init(controller: PaywallController, product: PaywallProduct?, content: PaywallContent, formatter: PlanFormatter) {
        self.controller = controller
        self.product = product
        self.content = content
        self.formatter = formatter
    }

    var body: some View {
        VStack(spacing: 10) {
            PaywallPrimaryButton(
                title: buttonTitle,
                tint: content.tint,
                isLoading: controller.purchasingProductID != nil
            ) {
                Task { await purchase() }
            }
            .disabled(product == nil || controller.isBusy)

            Text(product.map(formatter.billingText(for:)) ?? " ")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                Button {
                    Task { await restore() }
                } label: {
                    if controller.isRestoring {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Restore Purchases")
                    }
                }
                .disabled(controller.isBusy)
                if let url = content.termsOfServiceURL {
                    Link("Terms", destination: url)
                }
                if let url = content.privacyPolicyURL {
                    Link("Privacy", destination: url)
                }
            }
            .buttonStyle(.plain)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .alert(alertTitle, isPresented: $showsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var buttonTitle: String {
        if let callToAction = content.callToAction {
            return String(localized: callToAction)
        }
        return product.map(formatter.callToAction(for:)) ?? "Continue"
    }

    private func purchase() async {
        guard let product else { return }
        do {
            let outcome = try await controller.purchase(product)
            switch outcome {
            case .purchased:
                dismiss()
            case .pending:
                showAlert("Purchase pending", "The purchase needs approval. Pro unlocks as soon as it is approved.")
            case .cancelled:
                break
            }
        } catch {
            showAlert("Purchase failed", error.localizedDescription)
        }
    }

    private func restore() async {
        do {
            if try await controller.restore() {
                dismiss()
            } else {
                showAlert("Nothing to restore", "No active purchase was found for this Apple Account.")
            }
        } catch {
            showAlert("Restore failed", error.localizedDescription)
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showsAlert = true
    }
}

/// Plan loading and failure states shared by the templates.
struct PaywallProductsPlaceholder: View {
    let controller: PaywallController
    let tint: Color

    var body: some View {
        VStack(spacing: 12) {
            if let error = controller.productsError, !controller.isLoadingProducts {
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task { await controller.loadProducts() }
                }
                .paywallGlassButtonStyle()
                .tint(tint)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}
