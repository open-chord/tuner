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
        XCTAssertEqual(stabilizer.update(with: 220), 110.2)
        XCTAssertEqual(stabilizer.update(with: 110.1), 110.1)
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
