import PaywallKit
import SwiftUI

@main
struct PaywallKitDemoApp: App {
    /// One controller for the whole app. Run from Xcode, it sells the products in Lumina.storekit.
    @State private var paywall = makeDemoController()

    var body: some Scene {
        WindowGroup {
            if let scene = ScreenshotScene.current {
                // Screenshot scenes use the preview store and never touch the App Store.
                ScreenshotView(scene: scene)
            } else {
                ContentView(controller: paywall)
            }
        }
    }
}
