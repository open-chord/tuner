import SwiftUI

/// Lets the player switch between automatic detection and a specific string.
struct StringSelectionView: View {
    @ObservedObject var engine: TunerEngine

    private var isInTune: Bool { abs(engine.cents) <= 5 && engine.frequency != nil }
    private var statusColor: Color { isInTune ? .green : .white }

    var body: some View {
        // Horizontal scrolling supports tunings with up to 12 strings.
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                autoModeButton

                ForEach(engine.tuning.strings) { string in
                    stringButton(string)
                }
            }
            .padding(.horizontal, 6)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .sensoryFeedback(.selection, trigger: engine.selectedStringID)
    }

    private var autoModeButton: some View {
        let isSelected = engine.selectedStringID == nil

        return Button {
            engine.selectString(nil)
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(isSelected ? Color.red : .white.opacity(0.16))
                    .frame(width: 6, height: 6)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(isSelected ? 0.72 : 0.12), lineWidth: 0.5)
                    }
                    .shadow(color: .red.opacity(isSelected ? 0.65 : 0), radius: 5)

                Text("AUTO")
                    .font(.system(size: 7, weight: .bold, design: .default))
                    .tracking(0.7)
                    .foregroundStyle(isSelected ? .white.opacity(0.92) : .white.opacity(0.38))
            }
            .frame(width: 42, height: 38)
            .tunerGlass(cornerRadius: 12)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? Color.red.opacity(0.2) : .white.opacity(0.06),
                        lineWidth: 0.6
                    )
            }
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(isSelected ? Color.red.opacity(0.55) : .clear)
                    .frame(width: 15, height: 1.5)
                    .padding(.bottom, 3)
            }
            .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 0.98 : 1)
        .animation(.snappy(duration: 0.24), value: isSelected)
        .accessibilityLabel("Автоматический выбор струны")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func stringButton(_ string: GuitarString) -> some View {
        let isSelected = string.id == engine.selectedStringID
        // In AUTO, highlight the detected string without entering manual mode.
        let isDetected = engine.selectedStringID == nil && engine.guitarString?.id == string.id
        let isActive = isSelected || isDetected

        return Button {
            engine.selectString(string)
        } label: {
            Text(string.name)
                .font(.headline.weight(.semibold))
                .frame(width: 42)
                .frame(height: 38)
                .foregroundStyle(isActive ? statusColor : .white.opacity(0.4))
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(isActive ? statusColor : .clear)
                        .frame(width: 18, height: 2)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isActive)
        .accessibilityLabel("Струна \(string.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
