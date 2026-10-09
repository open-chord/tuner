import Combine
import Foundation

/// Одна физическая струна и частота, к которой её нужно настроить.
/// В пресетах `id` обозначает место струны: одинаковые ноты могут встречаться дважды.
struct GuitarString: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let octave: Int
    let frequency: Double

    init(id: String? = nil, name: String, octave: Int, frequency: Double) {
        self.id = id ?? "\(name)\(octave)-\(frequency)"
        self.name = name
        self.octave = octave
        self.frequency = frequency
    }

    /// Отклонение от эталона в центах: минус означает ниже ноты, плюс — выше.
    /// В музыкальном строе одна октава равна 1 200 центам.
    static func cents(from frequency: Double, to reference: Double) -> Double {
        1_200 * log2(frequency / reference)
    }
}

/// Строй инструмента: упорядоченные струны от самой низкой к самой высокой.
struct TuningPreset: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let strings: [GuitarString]

    var summary: String {
        strings.map(\.name).joined(separator: " ")
    }

    /// Автоматический режим выбирает струну с минимальным музыкальным отклонением.
    /// Сравниваем центы, а не разницу в герцах: одинаковый интервал звучит
    /// по-разному в герцах в низком и высоком регистрах.
    func nearestString(to frequency: Double) -> GuitarString? {
        guard frequency > 0 else { return nil }
        return strings.min {
            abs(GuitarString.cents(from: frequency, to: $0.frequency))
                < abs(GuitarString.cents(from: frequency, to: $1.frequency))
        }
    }

    /// Ручной выбор закрепляет конкретную струну; без него работает автоопределение.
    func targetString(for frequency: Double, selectedStringID: String?) -> GuitarString? {
        if let selectedStringID,
           let selectedString = strings.first(where: { $0.id == selectedStringID }) {
            return selectedString
        }
        return nearestString(to: frequency)
    }

    // Встроенные строи хранят эталонные частоты открытых струн в герцах.
    static let standard = TuningPreset(
        id: "standard",
        name: "Standard",
        strings: makeStrings([
            ("E", 2, 82.41), ("A", 2, 110.00), ("D", 3, 146.83),
            ("G", 3, 196.00), ("B", 3, 246.94), ("E", 4, 329.63),
        ])
    )

    static let dropD = TuningPreset(
        id: "drop-d",
        name: "Drop D",
        strings: makeStrings([
            ("D", 2, 73.42), ("A", 2, 110.00), ("D", 3, 146.83),
            ("G", 3, 196.00), ("B", 3, 246.94), ("E", 4, 329.63),
        ])
    )

    static let halfStepDown = TuningPreset(
        id: "half-step-down",
        name: "Half Step Down",
        strings: makeStrings([
            ("E♭", 2, 77.78), ("A♭", 2, 103.83), ("D♭", 3, 138.59),
            ("G♭", 3, 185.00), ("B♭", 3, 233.08), ("E♭", 4, 311.13),
        ])
    )

    static let dStandard = TuningPreset(
        id: "d-standard",
        name: "D Standard",
        strings: makeStrings([
            ("D", 2, 73.42), ("G", 2, 98.00), ("C", 3, 130.81),
            ("F", 3, 174.61), ("A", 3, 220.00), ("D", 4, 293.66),
        ])
    )

    static let dropC = TuningPreset(
        id: "drop-c",
        name: "Drop C",
        strings: makeStrings([
            ("C", 2, 65.41), ("G", 2, 98.00), ("C", 3, 130.81),
            ("F", 3, 174.61), ("A", 3, 220.00), ("D", 4, 293.66),
        ])
    )

    static let cStandard = TuningPreset(
        id: "c-standard",
        name: "C Standard",
        strings: makeStrings([
            ("C", 2, 65.41), ("F", 2, 87.31), ("B♭", 2, 116.54),
            ("E♭", 3, 155.56), ("G", 3, 196.00), ("C", 4, 261.63),
        ])
    )

    static let all: [TuningPreset] = [
        .standard, .dropD, .halfStepDown, .dStandard, .dropC, .cStandard,
    ]

    private static func makeStrings(
        _ values: [(name: String, octave: Int, frequency: Double)]
    ) -> [GuitarString] {
        // Индекс сохраняет разные позиции даже там, где две струны дают одну ноту.
        values.enumerated().map { index, value in
            GuitarString(
                id: "preset-\(index)-\(value.name)-\(value.octave)",
                name: value.name,
                octave: value.octave,
                frequency: value.frequency
            )
        }
    }
}

@MainActor
/// Локальное хранилище пользовательских строев. `@Published` обновляет меню
/// сразу после сохранения или удаления, а UserDefaults переживает перезапуск.
final class CustomTuningStore: ObservableObject {
    @Published private(set) var presets: [TuningPreset]

    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = "custom-tunings-v1") {
        self.defaults = defaults
        self.storageKey = storageKey
        presets = Self.load(from: defaults, key: storageKey)
    }

    /// Создаёт новый пресет с постоянным ID и сохраняет весь список на устройстве.
    func save(name: String, strings: [GuitarString]) -> TuningPreset {
        let preset = TuningPreset(
            id: "custom-\(UUID().uuidString)",
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            strings: strings
        )
        presets.append(preset)
        persist()
        return preset
    }

    /// Удаляет только пользовательский пресет и обновляет сохранённый список.
    func delete(_ preset: TuningPreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    /// Кодируем массив в JSON, потому что UserDefaults не хранит Swift-структуры напрямую.
    private func persist() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        defaults.set(data, forKey: storageKey)
    }

    /// При первом запуске или нечитаемых данных начинаем с пустого списка.
    private static func load(from defaults: UserDefaults, key: String) -> [TuningPreset] {
        guard let data = defaults.data(forKey: key),
              let presets = try? JSONDecoder().decode([TuningPreset].self, from: data) else {
            return []
        }
        return presets
    }
}

/// Временное состояние строки конструктора: пользователь меняет ноту и октаву,
/// а готовая `GuitarString` создаётся только при сохранении строя.
struct CustomStringDraft: Identifiable, Equatable {
    let id: UUID
    var note: String
    var octave: Int

    init(id: UUID = UUID(), note: String, octave: Int) {
        self.id = id
        self.note = note
        self.octave = octave
    }

    var guitarString: GuitarString {
        // MIDI-нумерация даёт простой мост от ноты и октавы к частоте:
        // A4 = нота 69 = 440 Гц; каждые 12 полутонов удваивают частоту.
        let pitchClass = Self.notes.firstIndex(of: note) ?? 0
        let midiNote = (octave + 1) * 12 + pitchClass
        let frequency = 440 * pow(2, Double(midiNote - 69) / 12)
        return GuitarString(
            id: "custom-string-\(id.uuidString)",
            name: note,
            octave: octave,
            frequency: frequency
        )
    }

    /// Порядок здесь важен: индекс ноты соответствует её номеру в октаве MIDI.
    static let notes = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]

    /// Начальные значения формы повторяют обычный шестиструнный строй.
    static let standard: [CustomStringDraft] = [
        .init(note: "E", octave: 2), .init(note: "A", octave: 2),
        .init(note: "D", octave: 3), .init(note: "G", octave: 3),
        .init(note: "B", octave: 3), .init(note: "E", octave: 4),
    ]
}
