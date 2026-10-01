import Combine
import Foundation

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

    static func cents(from frequency: Double, to reference: Double) -> Double {
        1_200 * log2(frequency / reference)
    }
}

struct TuningPreset: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let strings: [GuitarString]

    var summary: String {
        strings.map(\.name).joined(separator: " ")
    }

    func nearestString(to frequency: Double) -> GuitarString? {
        guard frequency > 0 else { return nil }
        return strings.min {
            abs(GuitarString.cents(from: frequency, to: $0.frequency))
                < abs(GuitarString.cents(from: frequency, to: $1.frequency))
        }
    }

    func targetString(for frequency: Double, selectedStringID: String?) -> GuitarString? {
        if let selectedStringID,
           let selectedString = strings.first(where: { $0.id == selectedStringID }) {
            return selectedString
        }
        return nearestString(to: frequency)
    }

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
final class CustomTuningStore: ObservableObject {
    @Published private(set) var presets: [TuningPreset]

    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = "custom-tunings-v1") {
        self.defaults = defaults
        self.storageKey = storageKey
        presets = Self.load(from: defaults, key: storageKey)
    }

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

    func delete(_ preset: TuningPreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func load(from defaults: UserDefaults, key: String) -> [TuningPreset] {
        guard let data = defaults.data(forKey: key),
              let presets = try? JSONDecoder().decode([TuningPreset].self, from: data) else {
            return []
        }
        return presets
    }
}

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

    static let notes = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]

    static let standard: [CustomStringDraft] = [
        .init(note: "E", octave: 2), .init(note: "A", octave: 2),
        .init(note: "D", octave: 3), .init(note: "G", octave: 3),
        .init(note: "B", octave: 3), .init(note: "E", octave: 4),
    ]
}
