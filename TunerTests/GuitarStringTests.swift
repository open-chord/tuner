import XCTest
@testable import Tuner

/// Проверяем музыкальную модель отдельно от микрофона и интерфейса.
final class GuitarStringTests: XCTestCase {
    func testFindsNearestStandardString() throws {
        let string = try XCTUnwrap(TuningPreset.standard.nearestString(to: 112))
        XCTAssertEqual(string.name, "A")
        XCTAssertEqual(string.octave, 2)
    }

    func testReturnsZeroCentsAtReferenceFrequency() {
        XCTAssertEqual(GuitarString.cents(from: 110, to: 110), 0, accuracy: 0.001)
    }

    func testRejectsInvalidFrequency() {
        XCTAssertNil(TuningPreset.standard.nearestString(to: 0))
    }

    func testDropDUsesLowDInsteadOfLowE() throws {
        let string = try XCTUnwrap(TuningPreset.dropD.nearestString(to: 73.42))

        XCTAssertEqual(string.name, "D")
        XCTAssertEqual(string.octave, 2)
        XCTAssertEqual(string.frequency, 73.42, accuracy: 0.001)
    }

    func testEveryPresetContainsSixUniqueStringPositions() {
        for preset in TuningPreset.all {
            XCTAssertEqual(preset.strings.count, 6, preset.name)
            XCTAssertEqual(Set(preset.strings.map(\.id)).count, 6, preset.name)
        }
    }

    func testManualSelectionOverridesAutomaticDetection() throws {
        let highE = try XCTUnwrap(TuningPreset.dropD.strings.last)
        let target = TuningPreset.dropD.targetString(
            for: 73.42,
            selectedStringID: highE.id
        )

        XCTAssertEqual(target, highE)
    }

    func testCustomStringCalculatesConcertA() {
        let string = CustomStringDraft(note: "A", octave: 4).guitarString

        XCTAssertEqual(string.frequency, 440, accuracy: 0.001)
    }

    func testCustomStringsKeepUniquePositionsForRepeatedNotes() {
        let first = CustomStringDraft(note: "E", octave: 4).guitarString
        let second = CustomStringDraft(note: "E", octave: 4).guitarString

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.frequency, second.frequency, accuracy: 0.001)
    }

    @MainActor
    func testCustomTuningPersistsBetweenStoreInstances() throws {
        // Отдельный UserDefaults suite не затрагивает реальные строи пользователя.
        let suiteName = "CustomTuningStoreTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = CustomTuningStore(defaults: defaults, storageKey: "tunings")
        let saved = store.save(
            name: "Open C",
            strings: [CustomStringDraft(note: "C", octave: 2).guitarString]
        )
        let restored = CustomTuningStore(defaults: defaults, storageKey: "tunings")

        XCTAssertEqual(restored.presets, [saved])
    }
}
