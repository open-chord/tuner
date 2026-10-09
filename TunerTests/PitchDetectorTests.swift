import XCTest
@testable import Tuner

/// Подставляем синтетический звук с известной частотой, чтобы проверять
/// алгоритм без зависимости от микрофона, комнаты и конкретной гитары.
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
}
