import SwiftUI

/// Shows one of the templates.
///
/// ```swift
/// PaywallView(controller: paywall, content: content, template: .comparison)
/// ```
public struct PaywallView: View {
    private let controller: PaywallController
    private let content: PaywallContent
    private let template: PaywallTemplate
    private let showsCloseButton: Bool

    public init(
        controller: PaywallController,
        content: PaywallContent,
        template: PaywallTemplate = .hero,
        showsCloseButton: Bool = true
    ) {
        self.controller = controller
        self.content = content
        self.template = template
        self.showsCloseButton = showsCloseButton
    }

    public var body: some View {
        switch template {
        case .hero:
            HeroPaywall(controller: controller, content: content, showsCloseButton: showsCloseButton)
        case .comparison:
            ComparisonPaywall(controller: controller, content: content, showsCloseButton: showsCloseButton)
        case .minimal:
            MinimalPaywall(controller: controller, content: content, showsCloseButton: showsCloseButton)
        }
    }
}

extension View {
    /// Presents a paywall while `isPresented` is `true`.
    ///
    /// On iPhone and iPad the hero and comparison templates cover the screen and the minimal
    /// template is a sheet; on the Mac every template is a sheet. A successful purchase or
    /// restore dismisses it.
    ///
    /// ```swift
    /// ContentView()
    ///     .paywall(isPresented: $showsPaywall, controller: paywall, content: content)
    /// ```
    public func paywall(
        isPresented: Binding<Bool>,
        controller: PaywallController,
        content: PaywallContent,
        template: PaywallTemplate = .hero,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(PaywallPresentationModifier(
            isPresented: isPresented,
            controller: controller,
            paywallContent: content,
            template: template,
            onDismiss: onDismiss
        ))
    }
}

struct PaywallPresentationModifier: ViewModifier {
    @Binding var isPresented: Bool
    let controller: PaywallController
    let paywallContent: PaywallContent
    let template: PaywallTemplate
    let onDismiss: (() -> Void)?

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if template == .minimal {
            content.sheet(isPresented: $isPresented, onDismiss: onDismiss) {
                paywall
                    .presentationDetents([.height(640), .large])
                    .presentationDragIndicator(.hidden)
            }
        } else {
            content.fullScreenCover(isPresented: $isPresented, onDismiss: onDismiss) {
                paywall
            }
        }
        #else
        content.sheet(isPresented: $isPresented, onDismiss: onDismiss) {
            paywall
                .paywallSheetFrame()
        }
        #endif
    }

    private var paywall: PaywallView {
        PaywallView(controller: controller, content: paywallContent, template: template)
    }
}
