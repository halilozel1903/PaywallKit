import PaywallKit
import SwiftUI

/// Scenes used by CI to capture the README screenshots on iPhone and iPad.
/// Launch with `-screenshot <scene>`; normal launches are unaffected.
enum ScreenshotScene: String {
    /// The hero paywall with the yearly plan selected (two columns on iPad).
    case hero
    /// The free vs Pro comparison paywall.
    case comparison
    /// The editor with the minimal paywall sheet on top.
    case minimal

    static var current: ScreenshotScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return ScreenshotScene(rawValue: arguments[index + 1])
    }
}

/// Renders one scene with the preview store: fixed products in US dollars, no purchases, no
/// network, so every capture is the same.
struct ScreenshotView: View {
    let scene: ScreenshotScene

    @State private var controller = PaywallController.preview(
        store: PreviewPaywallStore(products: DemoContent.previewProducts)
    )

    init(scene: ScreenshotScene) {
        self.scene = scene
    }

    var body: some View {
        switch scene {
        case .hero:
            HeroPaywall(controller: controller, content: DemoContent.heroContent)
        case .comparison:
            ComparisonPaywall(controller: controller, content: DemoContent.comparisonContent)
        case .minimal:
            ContentView(controller: controller)
                .sheet(isPresented: .constant(true)) {
                    MinimalPaywall(controller: controller, content: DemoContent.minimalContent)
                        .presentationDetents([.height(640)])
                        .interactiveDismissDisabled()
                }
        }
    }
}
