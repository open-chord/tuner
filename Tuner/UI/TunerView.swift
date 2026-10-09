import SwiftUI

/// Composes the tuner screen and routes user actions to the engine and preset store.
/// Microphone processing and the dial's presentation live outside this view.
struct TunerView: View {
    @StateObject private var engine = TunerEngine()
    @StateObject private var customTunings = CustomTuningStore()
    @State private var isShowingTuningBuilder = false

    private var isListening: Bool { engine.state == .listening }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                Spacer(minLength: 8)
                TuningCardView(engine: engine)
                Spacer(minLength: 10)
                StringSelectionView(engine: engine)
                Spacer(minLength: 16)
                primaryAction
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isShowingTuningBuilder) {
            // Activate the newly saved tuning immediately.
            CustomTuningBuilder { name, strings in
                engine.tuning = customTunings.save(name: name, strings: strings)
            }
            .preferredColorScheme(.dark)
        }
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

    // MARK: - Tuning selection

    private var tuningMenu: some View {
        Menu {
            Picker("Строй", selection: $engine.tuning) {
                ForEach(TuningPreset.all + customTunings.presets) { tuning in
                    Label(tuning.name, systemImage: tuning.id == engine.tuning.id ? "checkmark" : "guitars")
                        .tag(tuning)
                }
            }

            Divider()

            Button {
                isShowingTuningBuilder = true
            } label: {
                Label("Создать свой строй", systemImage: "slider.horizontal.3")
            }

            if !customTunings.presets.isEmpty {
                Menu("Удалить свой строй", systemImage: "trash") {
                    ForEach(customTunings.presets) { preset in
                        Button(preset.name, role: .destructive) {
                            // Do not leave a deleted preset active.
                            if engine.tuning.id == preset.id {
                                engine.tuning = .standard
                            }
                            customTunings.delete(preset)
                        }
                    }
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

    // MARK: - Listening control

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
                    .foregroundStyle(isListening ? .red : .white)
                Text(isListening ? "Остановить" : "Начать настройку")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .tunerInteractiveGlass(cornerRadius: 18)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(isListening ? 0.13 : 0.2), lineWidth: 0.6)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .sensoryFeedback(.impact(weight: .medium), trigger: isListening)
    }
}
