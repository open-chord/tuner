import SwiftUI

struct TunerView: View {
    @StateObject private var engine = TunerEngine()

    private var isListening: Bool { engine.state == .listening }
    private var isInTune: Bool { abs(engine.cents) <= 5 && engine.frequency != nil }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                Spacer(minLength: 8)
                tunerCard
                Spacer(minLength: 10)
                stringStrip
                Spacer(minLength: 16)
                primaryAction
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .preferredColorScheme(.dark)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.075), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [.white.opacity(0.055), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("OpenTuner", systemImage: "waveform")
                .font(.headline.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)

            Spacer()
            tuningMenu
        }
        .frame(height: 44)
    }

    private var tuningMenu: some View {
        Menu {
            Picker("Строй", selection: $engine.tuning) {
                ForEach(TuningPreset.all) { tuning in
                    Label(tuning.name, systemImage: tuning.id == engine.tuning.id ? "checkmark" : "guitars")
                        .tag(tuning)
                }
            }
        } label: {
            HStack(spacing: 7) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(engine.tuning.name)
                        .font(.subheadline.weight(.semibold))
                    Text(engine.tuning.summary)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .tunerGlass(cornerRadius: 22)
        .accessibilityLabel("Строй: \(engine.tuning.name)")
    }

    private var tunerCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(engine.guitarString?.name ?? "—")
                        .font(.system(size: 110, weight: .light, design: .default))
                        .contentTransition(.numericText())

                    if let octave = engine.guitarString?.octave {
                        Text("\(octave)")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 108)
            }

            tuningMeter

            HStack(spacing: 8) {
                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor)

                if engine.frequency != nil {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(centsText) ¢")
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            .frame(height: 22)

            if case .permissionDenied = engine.state {
                Label("Разреши микрофон в Настройках", systemImage: "mic.slash.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.09))
                .frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.09))
                .frame(height: 0.5)
        }
        .animation(.smooth, value: isInTune)
    }

    private var tuningMeter: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack {
                Capsule()
                    .fill(.white.opacity(0.09))
                    .frame(height: 7)

                HStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { index in
                        Rectangle()
                            .fill(.white.opacity(index == 4 ? 0.62 : 0.18))
                            .frame(width: index == 4 ? 2 : 1, height: index == 4 ? 20 : 10)
                        if index < 8 { Spacer() }
                    }
                }

                Circle()
                    .fill(statusColor)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1))
                    .shadow(color: statusColor.opacity(0.8), radius: 12)
                    .offset(x: meterOffset(width: width))
                    .animation(.snappy(duration: 0.25), value: engine.cents)
            }
        }
        .frame(height: 24)
        .padding(.horizontal, 4)
    }

    private var stringStrip: some View {
        HStack(spacing: 8) {
            stringButton(title: "AUTO", string: nil)

            ForEach(engine.tuning.strings) { string in
                stringButton(title: string.name, string: string)
            }
        }
        .padding(.horizontal, 6)
        .sensoryFeedback(.selection, trigger: engine.selectedStringID)
    }

    private func stringButton(title: String, string: GuitarString?) -> some View {
        let isSelected = string?.id == engine.selectedStringID
        let isDetected = engine.selectedStringID == nil && engine.guitarString?.id == string?.id
        let isActive = isSelected || isDetected || (string == nil && engine.selectedStringID == nil)

        return Button {
            engine.selectString(string)
        } label: {
            Text(title)
                .font(
                    string == nil
                        ? .system(size: 8, weight: .bold)
                        : .headline.weight(.semibold)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .foregroundStyle(isActive ? statusColor : .white.opacity(0.4))
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(isActive ? statusColor : .clear)
                        .frame(width: string == nil ? 24 : 18, height: 2)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isActive)
        .accessibilityLabel(string == nil ? "Автоматический выбор струны" : "Струна \(title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var primaryAction: some View {
        Button {
            if isListening {
                engine.stop()
            } else {
                Task { await engine.start() }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isListening ? "stop.fill" : "mic.fill")
                    .contentTransition(.symbolEffect(.replace))
                Text(isListening ? "Остановить" : "Начать настройку")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .tunerProminentGlassButton()
        .tint(isListening ? .white.opacity(0.2) : .white)
        .foregroundStyle(isListening ? .white : .black)
        .sensoryFeedback(.impact(weight: .medium), trigger: isListening)
    }

    private var statusText: String {
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

    private var statusColor: Color {
        if isInTune { return .green }
        return .white
    }

    private func meterOffset(width: CGFloat) -> CGFloat {
        guard engine.frequency != nil else { return 0 }
        let clamped = min(max(engine.cents, -50), 50)
        return CGFloat(clamped / 50) * ((width - 22) / 2)
    }
}

private extension View {
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

    func fallbackGlass(cornerRadius: CGFloat) -> some View {
        background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    @ViewBuilder
    func tunerProminentGlassButton() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
        #else
        buttonStyle(.borderedProminent)
        #endif
    }
}
