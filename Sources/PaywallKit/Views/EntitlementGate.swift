import SwiftUI

/// Shows `unlocked` when the user has Pro and `locked` otherwise, and updates the moment a
/// purchase, restore, renewal or refund changes the entitlement.
///
/// ```swift
/// EntitlementGate(controller: paywall) {
///     ProFiltersView()
/// } locked: {
///     Button("Unlock Pro filters") { showsPaywall = true }
/// }
/// ```
///
/// While the store has not answered yet (`EntitlementState.unknown`) it shows a progress view.
public struct EntitlementGate<Unlocked: View, Locked: View>: View {
    private let controller: PaywallController
    private let unlocked: () -> Unlocked
    private let locked: () -> Locked

    public init(
        controller: PaywallController,
        @ViewBuilder unlocked: @escaping () -> Unlocked,
        @ViewBuilder locked: @escaping () -> Locked
    ) {
        self.controller = controller
        self.unlocked = unlocked
        self.locked = locked
    }

    public var body: some View {
        Group {
            switch controller.entitlement {
            case .unknown:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .inactive:
                locked()
            case .active:
                unlocked()
            }
        }
        .animation(.smooth, value: controller.entitlement)
        .task { await controller.start() }
    }
}

extension EntitlementGate where Locked == PaywallLockedView {
    /// Shows `unlocked` with Pro, and otherwise a lock with a button that presents the paywall.
    ///
    /// ```swift
    /// EntitlementGate(controller: paywall, content: content, title: "Pro filters") {
    ///     ProFiltersView()
    /// }
    /// ```
    public init(
        controller: PaywallController,
        content: PaywallContent,
        template: PaywallTemplate = .hero,
        title: LocalizedStringResource = "Pro feature",
        message: LocalizedStringResource? = nil,
        @ViewBuilder unlocked: @escaping () -> Unlocked
    ) {
        self.init(controller: controller, unlocked: unlocked) {
            PaywallLockedView(controller: controller, content: content, template: template, title: title, message: message)
        }
    }
}

/// A lock, a title and an Unlock button that presents the paywall. Used by `EntitlementGate`.
public struct PaywallLockedView: View {
    let controller: PaywallController
    let content: PaywallContent
    let template: PaywallTemplate
    let title: LocalizedStringResource
    let message: LocalizedStringResource?

    @State private var showsPaywall = false

    init(
        controller: PaywallController,
        content: PaywallContent,
        template: PaywallTemplate,
        title: LocalizedStringResource,
        message: LocalizedStringResource?
    ) {
        self.controller = controller
        self.content = content
        self.template = template
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(content.tint.gradient, in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.bold())
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button {
                showsPaywall = true
            } label: {
                Label("Unlock", systemImage: "crown.fill")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            .buttonBorderShape(.capsule)
            .paywallProminentButtonStyle()
            .tint(content.tint)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paywall(isPresented: $showsPaywall, controller: controller, content: content, template: template)
    }
}
