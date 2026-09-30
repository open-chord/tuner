import XCTest
@testable import Tuner

final class GuitarStringTests: XCTestCase {
    func testFindsNearestStandardString() throws {
        let string = try XCTUnwrap(GuitarString.nearest(to: 112))
        XCTAssertEqual(string.name, "A")
        XCTAssertEqual(string.octave, 2)
    }

    func testReturnsZeroCentsAtReferenceFrequency() {
        XCTAssertEqual(GuitarString.cents(from: 110, to: 110), 0, accuracy: 0.001)
    }

    func testRejectsInvalidFrequency() {
        XCTAssertNil(GuitarString.nearest(to: 0))
    }
}

