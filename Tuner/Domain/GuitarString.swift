import Foundation

struct GuitarString: Equatable, Identifiable, Sendable {
    let name: String
    let octave: Int
    let frequency: Double

    var id: String { "\(name)\(octave)" }

    static let standardTuning: [GuitarString] = [
        .init(name: "E", octave: 2, frequency: 82.41),
        .init(name: "A", octave: 2, frequency: 110.00),
        .init(name: "D", octave: 3, frequency: 146.83),
        .init(name: "G", octave: 3, frequency: 196.00),
        .init(name: "B", octave: 3, frequency: 246.94),
        .init(name: "E", octave: 4, frequency: 329.63),
    ]

    static func nearest(to frequency: Double) -> GuitarString? {
        guard frequency > 0 else { return nil }
        return standardTuning.min {
            abs(cents(from: frequency, to: $0.frequency))
                < abs(cents(from: frequency, to: $1.frequency))
        }
    }

    static func cents(from frequency: Double, to reference: Double) -> Double {
        1_200 * log2(frequency / reference)
    }
}

