import AVFoundation
import Foundation

@MainActor
/// Connects microphone input and pitch detection to the selected tuning and UI.
/// Published state changes happen on the main actor, which SwiftUI observes.
final class TunerEngine: ObservableObject {
    /// The listening lifecycle, including reasons the session could not start.
    enum State: Equatable {
        case idle
        case listening
        case permissionDenied
        case failed(String)
    }

    // `@Published` tells SwiftUI to redraw when a reading changes. Other
    // objects can read these values, but only the engine can update them.
    @Published private(set) var state: State = .idle
    @Published private(set) var frequency: Double?
    @Published private(set) var guitarString: GuitarString?
    @Published private(set) var cents: Double = 0
    @Published private(set) var selectedStringID: String?
    @Published var tuning: TuningPreset = .standard {
        didSet {
            // A string selected in the previous tuning may not exist here.
            selectedStringID = nil
            update(with: frequency)
        }
    }

    private let audioEngine = AVAudioEngine()

    /// Requests microphone access and analyzes audio in 4,096-sample buffers.
    func start() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            state = .permissionDenied
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            // Measurement mode minimizes system audio processing that could
            // interfere with measuring an open string's pitch.
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            // The tap receives each microphone buffer. Copy its samples before
            // the callback returns because AVAudioEngine owns the source buffer.
            input.installTap(onBus: 0, bufferSize: 4_096, format: format) { [weak self] buffer, _ in
                guard let channel = buffer.floatChannelData?.pointee else { return }
                let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
                let detected = PitchDetector.estimateFrequency(
                    samples: samples,
                    sampleRate: format.sampleRate
                )
                // The audio callback is not on the main actor; UI state is.
                Task { @MainActor [weak self] in
                    self?.update(with: detected)
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
            state = .listening
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Releases the microphone and clears readings while keeping the tuning.
    func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        state = .idle
        frequency = nil
        guitarString = nil
        cents = 0
    }

    /// `nil` enables AUTO; a specific string locks manual selection.
    func selectString(_ string: GuitarString?) {
        selectedStringID = string?.id
        update(with: frequency)
    }

    /// Converts a detected frequency into a target string and cents offset.
    private func update(with frequency: Double?) {
        let target = tuning.targetString(
            for: frequency ?? 0,
            selectedStringID: selectedStringID
        )

        // Keep the manually selected target visible even during silence.
        guard let frequency, let string = target else {
            self.frequency = nil
            guitarString = target
            cents = 0
            return
        }

        self.frequency = frequency
        guitarString = string
        cents = GuitarString.cents(from: frequency, to: string.frequency)
    }
}
