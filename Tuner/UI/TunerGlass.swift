import SwiftUI

/// Shared glass styling keeps controls consistent across the tuner screens.
extension View {
    /// Uses native Liquid Glass on iOS 26+ and a translucent material on older iOS.
    @ViewBuilder
    func tunerGlass(cornerRadius: CGFloat) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            fallbackGlass(cornerRadius: cornerRadius)
        }
        #else
        fallbackGlass(cornerRadius: cornerRadius)
        #endif
    }

    private func fallbackGlass(cornerRadius: CGFloat) -> some View {
        background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    /// Adds touch-responsive glass to the primary button.
    @ViewBuilder
    func tunerInteractiveGlass(cornerRadius: CGFloat) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            fallbackGlass(cornerRadius: cornerRadius)
        }
        #else
        fallbackGlass(cornerRadius: cornerRadius)
        #endif
    }
}
