import AVFoundation
import Foundation

@MainActor
final class TunerEngine: ObservableObject {
    enum State: Equatable {
        case idle
        case listening
        case permissionDenied
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var frequency: Double?
    @Published private(set) var guitarString: GuitarString?
    @Published private(set) var cents: Double = 0
    @Published private(set) var selectedStringID: String?
    @Published var tuning: TuningPreset = .standard {
        didSet {
            selectedStringID = nil
            update(with: frequency)
        }
    }

    private let audioEngine = AVAudioEngine()

    func start() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            state = .permissionDenied
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 4_096, format: format) { [weak self] buffer, _ in
                guard let channel = buffer.floatChannelData?.pointee else { return }
                let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
                let detected = PitchDetector.estimateFrequency(
                    samples: samples,
                    sampleRate: format.sampleRate
                )
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

    func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        state = .idle
        frequency = nil
        guitarString = nil
        cents = 0
    }

    func selectString(_ string: GuitarString?) {
        selectedStringID = string?.id
        update(with: frequency)
    }

    private func update(with frequency: Double?) {
        let target = tuning.targetString(
            for: frequency ?? 0,
            selectedStringID: selectedStringID
        )

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
