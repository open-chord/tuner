import SwiftUI

/// Точка входа iOS-приложения: создаёт окно с главным экраном тюнера.
@main
struct TunerApp: App {
    var body: some Scene {
        WindowGroup {
            TunerView()
        }
    }
}
