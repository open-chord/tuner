import SwiftUI

/// The tuning dial and its textual readouts. It observes the engine but does
/// not change the listening session or the selected tuning.
struct TuningCardView: View {
    @ObservedObject var engine: TunerEngine

    private var isListening: Bool { engine.state == .listening }
    // Show green within ±5 cents, but only when an actual frequency is present.
    private var isInTune: Bool { abs(engine.cents) <= 5 && engine.frequency != nil }

    var body: some View {
        VStack(spacing: 8) {
            tuningDial

            Text(statusText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(statusColor)
                .frame(height: 22)

            if case .permissionDenied = engine.state {
                Label("Разреши микрофон в Настройках", systemImage: "mic.slash.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .tunerGlass(cornerRadius: 28)
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 0.6)
        }
        .animation(.smooth, value: isInTune)
    }

    // MARK: - Dial

    private var tuningDial: some View {
        GeometryReader { geometry in
            // Place the pivot below the card's center so the arc has room above
            // and the note and readouts fit below it.
            let width = geometry.size.width
            let height = geometry.size.height
            let center = CGPoint(x: width / 2, y: height * 0.73)
            let radius = min(width * 0.42, height * 0.68)

            ZStack {
                TunerDialArc()
                    .stroke(.white.opacity(0.11), style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                    .padding(.horizontal, width * 0.08)

                ForEach(-5...5, id: \.self) { step in
                    // Eleven ticks cover −50 to +50 cents at 12° per step.
                    let angle = Double(step) * 12
                    let radians = angle * .pi / 180
                    let isMajor = step == 0 || abs(step) == 5

                    Capsule()
                        .fill(step == 0 ? .white.opacity(0.72) : .white.opacity(0.2))
                        .frame(width: isMajor ? 2 : 1, height: isMajor ? 16 : 11)
                        .rotationEffect(.degrees(angle))
                        .position(
                            x: center.x + CGFloat(sin(radians)) * radius,
                            y: center.y - CGFloat(cos(radians)) * radius
                        )

                    if step.isMultiple(of: 5) || step == 0 {
                        Text("\(step * 10)")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(step == 0 ? 0.72 : 0.34))
                            .position(
                                x: center.x + CGFloat(sin(radians)) * (radius + 27),
                                y: center.y - CGFloat(cos(radians)) * (radius + 27)
                            )
                    }
                }

                // Rotate the needle around its bottom point using `cents`.
                // The center circle conceals the needle's pivot.
                Capsule()
                    .fill(needleColor)
                    .frame(width: 2.5, height: radius - 8)
                    .shadow(color: needleColor.opacity(0.7), radius: 5)
                    .offset(y: -(radius - 8) / 2)
                    .rotationEffect(.degrees(needleAngle), anchor: .bottom)
                    .position(center)
                    .animation(.snappy(duration: 0.25), value: engine.cents)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().fill(needleColor).frame(width: 6, height: 6))
                    .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 0.5))
                    .position(center)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(engine.guitarString?.name ?? "—")
                        .font(.system(size: 74, weight: .light))
                        .contentTransition(.numericText())

                    if let octave = engine.guitarString?.octave {
                        Text("\(octave)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .position(x: center.x, y: center.y + 42)

                dialReadout(frequencyText, unit: "Hz")
                    .position(x: width * 0.23, y: center.y + 26)

                dialReadout(centsText, unit: "cents")
                    .position(x: width * 0.77, y: center.y + 26)
            }
        }
        .frame(height: 230)
    }

    private func dialReadout(_ value: String, unit: String) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .contentTransition(.numericText())
            Text(unit)
                .foregroundStyle(.tertiary)
        }
        .font(.caption.weight(.semibold).monospacedDigit())
        .foregroundStyle(.secondary)
    }

    // MARK: - Readouts

    private var statusText: String {
        // Before the microphone detects a frequency, prompt the next action.
        guard engine.frequency != nil else {
            if let selectedStringID = engine.selectedStringID,
               let string = engine.tuning.strings.first(where: { $0.id == selectedStringID }) {
                return isListening ? "Сыграй струну \(string.name)" : "Выбрана струна \(string.name)"
            }
            return isListening ? "Сыграй открытую струну" : "Готов к настройке"
        }
        if isInTune { return "Настроено" }
        return engine.cents < 0 ? "Подтяни струну" : "Ослабь струну"
    }

    private var centsText: String {
        guard engine.frequency != nil else { return "—" }
        let cents = Int(engine.cents.rounded())
        return cents > 0 ? "+\(cents)" : "\(cents)"
    }

    private var frequencyText: String {
        guard let frequency = engine.frequency else { return "—" }
        return frequency.formatted(.number.precision(.fractionLength(1)))
    }

    private var needleAngle: Double {
        guard engine.frequency != nil else { return 0 }
        // Clamp the needle to the dial: 50 cents corresponds to 60°.
        return min(max(engine.cents, -50), 50) * 1.2
    }

    private var needleColor: Color {
        isInTune ? .green : .orange
    }

    private var statusColor: Color {
        if isInTune { return .green }
        return .white
    }
}

/// Draws the dial arc from −60° to +60° as short line segments.
private struct TunerDialArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.height * 0.73)
        let radius = min(rect.width * 0.42, rect.height * 0.68)

        for index in 0...60 {
            let angle = -60.0 + Double(index) * 2
            let radians = angle * .pi / 180
            let point = CGPoint(
                x: center.x + CGFloat(sin(radians)) * radius,
                y: center.y - CGFloat(cos(radians)) * radius
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}
