import XCTest
@testable import Tuner

/// Synthetic tones with known frequencies test the algorithm without relying
/// on a microphone, room acoustics, or a particular guitar.
final class PitchDetectorTests: XCTestCase {
    func testDetectsLowE() throws {
        let sampleRate = 44_100.0
        let frequency = 82.41
        let samples = (0..<8_192).map { index in
            Float(sin(2 * Double.pi * frequency * Double(index) / sampleRate))
        }

        let result = try XCTUnwrap(
            PitchDetector.estimateFrequency(samples: samples, sampleRate: sampleRate)
        )

        XCTAssertEqual(result, frequency, accuracy: 0.5)
    }

    func testIgnoresSilence() {
        let result = PitchDetector.estimateFrequency(
            samples: Array(repeating: 0, count: 4_096),
            sampleRate: 44_100
        )

        XCTAssertNil(result)
    }

    func testDetectsLowCForDropCTuning() throws {
        let sampleRate = 44_100.0
        let frequency = 65.41
        let samples = (0..<8_192).map { index in
            Float(sin(2 * Double.pi * frequency * Double(index) / sampleRate))
        }

        let result = try XCTUnwrap(
            PitchDetector.estimateFrequency(samples: samples, sampleRate: sampleRate)
        )

        XCTAssertEqual(result, frequency, accuracy: 0.5)
    }

    func testDetectsMinimumSupportedFrequency() throws {
        let sampleRate = 44_100.0
        let samples = (0..<4_096).map { index in
            Float(sin(2 * Double.pi * 55 * Double(index) / sampleRate))
        }
        let result = try XCTUnwrap(
            PitchDetector.estimateFrequency(samples: samples, sampleRate: sampleRate)
        )
        XCTAssertEqual(result, 55, accuracy: 0.5)
    }

    func testFadingAStringDoesNotBecomeHalfItsFrequency() throws {
        let sampleRate = 48_000.0
        let samples = (0..<4_096).map { index -> Float in
            let time = Double(index) / sampleRate
            let fadingA = 0.03 * exp(-5 * time) * sin(2 * .pi * 110 * time)
            let quietSubharmonic = 0.001 * sin(2 * .pi * 55 * time)
            return Float(fadingA + quietSubharmonic)
        }

        let result = try XCTUnwrap(
            PitchDetector.estimateFrequency(samples: samples, sampleRate: sampleRate)
        )
        XCTAssertEqual(result, 110, accuracy: 0.5)
    }

    func testLoudSecondHarmonicDoesNotDoubleDetectedPitch() throws {
        let sampleRate = 48_000.0
        let samples = (0..<4_096).map { index -> Float in
            let phase = 2 * Double.pi * 110 * Double(index) / sampleRate
            return Float(0.1 * sin(phase) + sin(2 * phase))
        }

        let result = try XCTUnwrap(
            PitchDetector.estimateFrequency(samples: samples, sampleRate: sampleRate)
        )
        XCTAssertEqual(result, 110, accuracy: 0.5)
    }

    func testTracksEveryOpenStringAcrossTimbresAndInputLevels() throws {
        let frequencies = [65.41, 82.41, 110.0, 146.83, 196.0, 246.94, 329.63]
        for sampleRate in [44_100.0, 48_000.0] {
            for frequency in frequencies {
                for fundamentalWeight in [0.25, 0.7] {
                    for level in [0.03, 0.2] {
                        var tracker = PitchTracker()
                        var output: Double?
                        for frame in 0..<6 {
                            let samples = (0..<4_096).map { index -> Float in
                                let time = Double(frame * 4_096 + index) / sampleRate
                                let phase = 2 * Double.pi * frequency * time
                                let string = fundamentalWeight * sin(phase)
                                    + sin(2 * phase) + 0.4 * sin(3 * phase)
                                let background = 0.001 * sin(2 * Double.pi * 60 * time)
                                return Float(level * exp(-1.5 * time) * string + background)
                            }
                            output = tracker.update(with: PitchDetector.candidates(
                                samples: samples, sampleRate: sampleRate
                            ))
                        }
                        XCTAssertEqual(
                            try XCTUnwrap(output), frequency, accuracy: 1.5,
                            "\(frequency) Hz at \(sampleRate) Hz, level \(level), fundamental \(fundamentalWeight)"
                        )
                    }
                }
            }
        }
    }

    func testDetectsSustainedClippingButNotOneTransient() {
        var samples = Array(repeating: Float(0.2), count: 4_096)
        samples[0] = 1
        XCTAssertFalse(PitchDetector.isClipping(samples: samples))

        for index in 0..<64 { samples[index] = -1 }
        XCTAssertTrue(PitchDetector.isClipping(samples: samples))
    }

    func testTrackerPrefersEstablishedPitchWhenAnotherCandidateBarelyWins() {
        var stabilizer = PitchTracker()
        for _ in 0..<3 { _ = stabilizer.update(with: [candidate(110)]) }
        let ambiguous = [candidate(55, error: 0.01), candidate(110, error: 0.02)]
        for _ in 0..<5 {
            XCTAssertEqual(stabilizer.update(with: ambiguous), 110)
        }
    }

    func testTrackerKeepsHighEAndBThroughOctaveAmbiguity() throws {
        var stabilizer = PitchTracker()
        for _ in 0..<4 { _ = stabilizer.update(with: [candidate(329.1)]) }
        for _ in 0..<5 {
            let ambiguous = [candidate(163.9, error: 0.01), candidate(329.1, error: 0.02)]
            XCTAssertEqual(try XCTUnwrap(stabilizer.update(with: ambiguous)), 329.1, accuracy: 0.1)
        }

        stabilizer.reset()
        for _ in 0..<4 { _ = stabilizer.update(with: [candidate(246.4)]) }
        let ambiguous = [candidate(123.5, error: 0.01), candidate(246.4, error: 0.02)]
        XCTAssertEqual(try XCTUnwrap(stabilizer.update(with: ambiguous)), 246.4, accuracy: 0.1)
    }

    func testTrackerStillChangesToAnotherStringAndOctave() throws {
        var stabilizer = PitchTracker()
        for _ in 0..<3 { _ = stabilizer.update(with: [candidate(329.63)]) }
        for _ in 0..<3 { _ = stabilizer.update(with: [candidate(246.94)]) }
        XCTAssertEqual(try XCTUnwrap(stabilizer.update(with: [candidate(246.94)])), 246.94, accuracy: 0.01)

        stabilizer.reset()
        for _ in 0..<3 { _ = stabilizer.update(with: [candidate(329.63)]) }
        for _ in 0..<3 { _ = stabilizer.update(with: [candidate(164.81)]) }
        XCTAssertEqual(try XCTUnwrap(stabilizer.update(with: [candidate(164.81)])), 164.81, accuracy: 0.01)
    }

    func testTrackerChangesStringAndClearsAfterSilence() {
        var stabilizer = PitchTracker()
        for _ in 0..<3 { _ = stabilizer.update(with: [candidate(110)]) }
        XCTAssertEqual(stabilizer.update(with: [candidate(146.83)]), 110)
        XCTAssertEqual(stabilizer.update(with: [candidate(146.83)]), 110)
        XCTAssertEqual(stabilizer.update(with: [candidate(146.83)]), 146.83)
        XCTAssertEqual(stabilizer.update(with: []), 146.83)
        XCTAssertNil(stabilizer.update(with: []))
    }

    private func candidate(_ frequency: Double, error: Float = 0.01) -> PitchCandidate {
        PitchCandidate(frequency: frequency, error: error)
    }
}
