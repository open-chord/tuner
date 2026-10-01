import SwiftUI

struct TunerView: View {
    @StateObject private var engine = TunerEngine()

    private var isListening: Bool { engine.state == .listening }
    private var isInTune: Bool { abs(engine.cents) <= 5 && engine.frequency != nil }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Menu {
                Picker("Строй", selection: $engine.tuning) {
                    ForEach(TuningPreset.all) { tuning in
                        VStack(alignment: .leading) {
                            Text(tuning.name)
                            Text(tuning.summary)
                        }
                        .tag(tuning)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(engine.tuning.name.uppercased())
                    Image(systemName: "chevron.down")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1.5)
            }

            Text(engine.tuning.summary)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)

            Text(engine.guitarString?.name ?? "—")
                .font(.system(size: 124, weight: .medium, design: .rounded))
                .contentTransition(.numericText())

            Text(engine.guitarString.map { "\($0.name)\($0.octave)" } ?? "Сыграй открытую струну")
                .font(.title3)
                .foregroundStyle(.secondary)

            tuningMeter

            Text(statusText)
                .font(.headline)
                .foregroundStyle(isInTune ? .green : .primary)
                .frame(height: 24)

            if case .permissionDenied = engine.state {
                Text("Разреши доступ к микрофону в Настройках, чтобы тюнер мог услышать гитару.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(isListening ? "Остановить" : "Начать настройку") {
                if isListening {
                    engine.stop()
                } else {
                    Task { await engine.start() }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .background(Color(.systemBackground))
    }

    private var tuningMeter: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                ZStack {
                    Capsule().fill(.quaternary)
                    Rectangle()
                        .fill(isInTune ? Color.green : Color.accentColor)
                        .frame(width: 3)
                        .offset(x: meterOffset(width: geometry.size.width))
                }
            }
            .frame(height: 12)

            HStack {
                Text("НИЖЕ")
                Spacer()
                Text("ВЫШЕ")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        guard engine.frequency != nil else { return isListening ? "Слушаю…" : "" }
        if isInTune { return "Настроено" }
        return engine.cents < 0 ? "Подтяни струну" : "Ослабь струну"
    }

    private func meterOffset(width: CGFloat) -> CGFloat {
        let clamped = min(max(engine.cents, -50), 50)
        return CGFloat(clamped / 50) * (width / 2)
    }
}
