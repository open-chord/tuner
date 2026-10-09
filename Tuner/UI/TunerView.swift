import SwiftUI

/// Главный экран. Он только показывает состояние `TunerEngine` и передаёт
/// действия пользователя движку; обработка микрофона остаётся вне SwiftUI.
struct TunerView: View {
    // `@StateObject` сохраняет эти объекты при повторной отрисовке View.
    @StateObject private var engine = TunerEngine()
    @StateObject private var customTunings = CustomTuningStore()
    @State private var isShowingTuningBuilder = false

    private var isListening: Bool { engine.state == .listening }
    // Попадание в диапазон ±5 центов показываем зелёным только при живом сигнале.
    private var isInTune: Bool { abs(engine.cents) <= 5 && engine.frequency != nil }

    // MARK: - Компоновка экрана

    /// SwiftUI заново вычисляет описание экрана при смене `@Published`/`@State`.
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
        .sheet(isPresented: $isShowingTuningBuilder) {
            // После сохранения новый строй сразу становится активным.
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

    // MARK: - Выбор строя

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
                            // Нельзя оставить активным пресет, которого уже нет в меню.
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

    // MARK: - Прибор настройки

    private var tunerCard: some View {
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

    private var tuningDial: some View {
        GeometryReader { geometry in
            // Центр стрелки расположен ниже центра карточки: сверху остаётся
            // место для полукруглой шкалы, снизу — для ноты и показаний.
            let width = geometry.size.width
            let height = geometry.size.height
            let center = CGPoint(x: width / 2, y: height * 0.73)
            let radius = min(width * 0.42, height * 0.68)

            ZStack {
                TunerDialArc()
                    .stroke(.white.opacity(0.11), style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                    .padding(.horizontal, width * 0.08)

                ForEach(-5...5, id: \.self) { step in
                    // 11 делений покрывают от −50 до +50 центов; 12° на шаг.
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

                // Стрелка поворачивается вокруг нижней точки и следует за
                // значением `cents`; центральный кружок скрывает её ось.
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

    // MARK: - Автоопределение и ручной выбор струны

    private var stringStrip: some View {
        // Горизонтальная прокрутка оставляет место для строев до 12 струн.
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
        // В AUTO подсвечиваем услышанную струну, не переключая режим вручную.
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

    // MARK: - Запуск и текстовые показания

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

    private var statusText: String {
        // Пока микрофон не дал частоту, текст объясняет следующий шаг.
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
        // Ограничиваем стрелку краями шкалы; 50 центов соответствуют 60°.
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

/// Форма конструктора собственного строя. Здесь живёт только черновик;
/// сохранение выполняет `CustomTuningStore` через замыкание `onSave`.
private struct CustomTuningBuilder: View {
    // MARK: - Черновик строя

    // `dismiss` закрывает модальный экран после сохранения или отмены.
    @Environment(\.dismiss) private var dismiss

    @State private var name = "Мой строй"
    @State private var strings = CustomStringDraft.standard

    let onSave: (String, [GuitarString]) -> Void

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !strings.isEmpty
    }

    // MARK: - Форма редактирования

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Например, Open C", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    ForEach($strings) { $string in
                        HStack(spacing: 10) {
                            Text("\((strings.firstIndex { $0.id == string.id } ?? 0) + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .frame(width: 18)

                            Picker("Нота", selection: $string.note) {
                                ForEach(CustomStringDraft.notes, id: \.self) { note in
                                    Text(note).tag(note)
                                }
                            }
                            .labelsHidden()

                            Picker("Октава", selection: $string.octave) {
                                ForEach(0...7, id: \.self) { octave in
                                    Text("\(octave)").tag(octave)
                                }
                            }
                            .labelsHidden()

                            Spacer()

                            Text(string.guitarString.frequency, format: .number.precision(.fractionLength(1)))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text("Hz")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .onDelete { offsets in
                        // В строе должна остаться хотя бы одна струна.
                        guard strings.count - offsets.count >= 1 else { return }
                        strings.remove(atOffsets: offsets)
                    }

                    Button {
                        // Новая струна копирует ноту предыдущей как удобный старт.
                        guard strings.count < 12 else { return }
                        let previous = strings.last ?? .init(note: "E", octave: 2)
                        strings.append(.init(note: previous.note, octave: previous.octave))
                    } label: {
                        Label("Добавить струну", systemImage: "plus.circle.fill")
                    }
                    .disabled(strings.count >= 12)
                } header: {
                    Text("Струны · \(strings.count)")
                } footer: {
                    Text("Расположи струны от самой толстой к самой тонкой. Свайп влево удаляет струну.")
                }
            }
            .navigationTitle("Свой строй")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(name, strings.map(\.guitarString))
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

/// Рисует дугу шкалы от −60° до +60° короткими отрезками.
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

// MARK: - Материал кнопок и карточек

private extension View {
    /// Использует нативное Liquid Glass на iOS 26+, а на старых системах —
    /// близкий по виду полупрозрачный материал.
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

    /// Интерактивная версия стекла для главной кнопки с реакцией на касание.
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
