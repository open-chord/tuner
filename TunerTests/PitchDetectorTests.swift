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

    func testDetectsSustainedClippingButNotOneTransient() {
        var samples = Array(repeating: Float(0.2), count: 4_096)
        samples[0] = 1
        XCTAssertFalse(PitchDetector.isClipping(samples: samples))

        for index in 0..<64 { samples[index] = -1 }
        XCTAssertTrue(PitchDetector.isClipping(samples: samples))
    }

    func testStabilizerRejectsAnIsolatedOctaveError() {
        var stabilizer = PitchStabilizer()
        XCTAssertNil(stabilizer.update(with: 110))
        XCTAssertNil(stabilizer.update(with: 110.2))
        XCTAssertEqual(stabilizer.update(with: 109.9), 110)
        XCTAssertEqual(stabilizer.update(with: 220), 110)
        XCTAssertEqual(stabilizer.update(with: 110.1), 110)
    }

    func testStabilizerKeepsHighEAndBThroughShortOctaveDrops() throws {
        var stabilizer = PitchStabilizer()
        for _ in 0..<4 { _ = stabilizer.update(with: 329.1) }
        for _ in 0..<5 {
            XCTAssertEqual(try XCTUnwrap(stabilizer.update(with: 163.9)), 327.8, accuracy: 1.5)
        }

        stabilizer.reset()
        for _ in 0..<4 { _ = stabilizer.update(with: 246.4) }
        XCTAssertEqual(try XCTUnwrap(stabilizer.update(with: 123.5)), 246.4, accuracy: 0.7)
        XCTAssertEqual(try XCTUnwrap(stabilizer.update(with: 246.4)), 246.4, accuracy: 0.7)
    }

    func testStabilizerStillChangesToAnotherStringAndAcceptsSustainedOctave() throws {
        var stabilizer = PitchStabilizer()
        for _ in 0..<3 { _ = stabilizer.update(with: 329.63) }
        for _ in 0..<3 { _ = stabilizer.update(with: 246.94) }
        XCTAssertEqual(try XCTUnwrap(stabilizer.update(with: 246.94)), 246.94, accuracy: 0.01)

        stabilizer.reset()
        for _ in 0..<3 { _ = stabilizer.update(with: 329.63) }
        for _ in 0..<9 { _ = stabilizer.update(with: 164.81) }
        XCTAssertEqual(try XCTUnwrap(stabilizer.update(with: 164.81)), 164.81, accuracy: 0.01)
    }

    func testStabilizerChangesStringAndClearsAfterSilence() {
        var stabilizer = PitchStabilizer()
        for _ in 0..<3 { _ = stabilizer.update(with: 110) }
        XCTAssertEqual(stabilizer.update(with: 146.83), 110)
        XCTAssertEqual(stabilizer.update(with: 146.83), 110)
        XCTAssertEqual(stabilizer.update(with: 146.83), 146.83)
        XCTAssertEqual(stabilizer.update(with: nil), 146.83)
        XCTAssertNil(stabilizer.update(with: nil))
    }
}
