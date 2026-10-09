import Combine
import Foundation

/// One physical string and the frequency it should be tuned to.
/// In a preset, `id` identifies the string position, even when notes repeat.
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

    /// Pitch deviation in cents: negative means flat, positive means sharp.
    /// One octave spans 1,200 cents.
    static func cents(from frequency: Double, to reference: Double) -> Double {
        1_200 * log2(frequency / reference)
    }
}

/// An instrument tuning, with strings ordered from lowest to highest pitch.
struct TuningPreset: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let strings: [GuitarString]

    var summary: String {
        strings.map(\.name).joined(separator: " ")
    }

    /// AUTO selects the string with the smallest musical pitch difference.
    /// Compare cents rather than hertz because the same interval spans a
    /// different number of hertz in low and high registers.
    func nearestString(to frequency: Double) -> GuitarString? {
        guard frequency > 0 else { return nil }
        return strings.min {
            abs(GuitarString.cents(from: frequency, to: $0.frequency))
                < abs(GuitarString.cents(from: frequency, to: $1.frequency))
        }
    }

    /// Manual selection locks a string; otherwise use automatic detection.
    func targetString(for frequency: Double, selectedStringID: String?) -> GuitarString? {
        if let selectedStringID,
           let selectedString = strings.first(where: { $0.id == selectedStringID }) {
            return selectedString
        }
        return nearestString(to: frequency)
    }

    // Built-in tunings specify the reference frequencies of open strings in hertz.
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
        // The index keeps two physical positions distinct even if notes repeat.
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
/// Stores custom tunings locally. `@Published` refreshes the menu after edits,
/// while UserDefaults persists the list across app launches.
final class CustomTuningStore: ObservableObject {
    @Published private(set) var presets: [TuningPreset]

    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = "custom-tunings-v1") {
        self.defaults = defaults
        self.storageKey = storageKey
        presets = Self.load(from: defaults, key: storageKey)
    }

    /// Creates a preset with a stable ID and persists the updated list.
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

    /// Removes a custom preset and persists the updated list.
    func delete(_ preset: TuningPreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    /// Encode as JSON because UserDefaults cannot store these Swift structs directly.
    private func persist() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        defaults.set(data, forKey: storageKey)
    }

    /// Start with an empty list on first launch or if stored data cannot be decoded.
    private static func load(from defaults: UserDefaults, key: String) -> [TuningPreset] {
        guard let data = defaults.data(forKey: key),
              let presets = try? JSONDecoder().decode([TuningPreset].self, from: data) else {
            return []
        }
        return presets
    }
}

/// Editable string state used by the tuning builder. It becomes a GuitarString
/// only when the user saves the tuning.
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
        // MIDI note numbers map pitch and octave to frequency: A4 is note 69
        // at 440 Hz, and each 12-semitone octave doubles the frequency.
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

    /// Order matters: each index is the note's semitone offset from C in MIDI.
    static let notes = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]

    /// Initial builder values match standard six-string tuning.
    static let standard: [CustomStringDraft] = [
        .init(note: "E", octave: 2), .init(note: "A", octave: 2),
        .init(note: "D", octave: 3), .init(note: "G", octave: 3),
        .init(note: "B", octave: 3), .init(note: "E", octave: 4),
    ]
}
