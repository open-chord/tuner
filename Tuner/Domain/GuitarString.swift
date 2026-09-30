import Foundation

struct GuitarString: Equatable, Hashable, Identifiable, Sendable {
    let name: String
    let octave: Int
    let frequency: Double

    var id: String { "\(name)\(octave)" }

    static func cents(from frequency: Double, to reference: Double) -> Double {
        1_200 * log2(frequency / reference)
    }
}

struct TuningPreset: Equatable, Hashable, Identifiable, Sendable {
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
        values.map(GuitarString.init)
    }
}
