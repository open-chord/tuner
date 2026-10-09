import SwiftUI

/// The iOS entry point. Creates a window containing the tuner screen.
@main
struct TunerApp: App {
    var body: some Scene {
        WindowGroup {
            TunerView()
        }
    }
}
