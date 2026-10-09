import AVFoundation
import Foundation

@MainActor
/// Связывает микрофон, поиск частоты и выбранный строй с данными для экрана.
/// Изменения состояния происходят на главном потоке, который наблюдает SwiftUI.
final class TunerEngine: ObservableObject {
    /// Состояние сеанса прослушивания и причина, по которой он не запустился.
    enum State: Equatable {
        case idle
        case listening
        case permissionDenied
        case failed(String)
    }

    // `@Published` сообщает SwiftUI, что показания прибора нужно перерисовать.
    // Снаружи эти значения доступны для чтения, но меняет их только движок.
    @Published private(set) var state: State = .idle
    @Published private(set) var frequency: Double?
    @Published private(set) var guitarString: GuitarString?
    @Published private(set) var cents: Double = 0
    @Published private(set) var selectedStringID: String?
    @Published var tuning: TuningPreset = .standard {
        didSet {
            // После смены строя прежний ID струны уже может не существовать.
            selectedStringID = nil
            update(with: frequency)
        }
    }

    private let audioEngine = AVAudioEngine()

    /// Запрашивает микрофон и анализирует звук блоками по 4 096 сэмплов.
    func start() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            state = .permissionDenied
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            // Measurement снижает обработку звука системой, которая мешала бы
            // измерять высоту чистой открытой струны.
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            // Tap получает очередной фрагмент микрофона. Копируем сэмплы до
            // выхода из callback: AVAudioEngine владеет исходным буфером.
            input.installTap(onBus: 0, bufferSize: 4_096, format: format) { [weak self] buffer, _ in
                guard let channel = buffer.floatChannelData?.pointee else { return }
                let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
                let detected = PitchDetector.estimateFrequency(
                    samples: samples,
                    sampleRate: format.sampleRate
                )
                // Аудио callback не работает на главном потоке; UI обновляем там.
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

    /// Освобождает микрофон и сбрасывает показания, сохраняя выбранный строй.
    func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        state = .idle
        frequency = nil
        guitarString = nil
        cents = 0
    }

    /// `nil` включает AUTO; конкретная струна закрепляет ручной режим.
    func selectString(_ string: GuitarString?) {
        selectedStringID = string?.id
        update(with: frequency)
    }

    /// Преобразует услышанную частоту в целевую струну и отклонение в центах.
    private func update(with frequency: Double?) {
        let target = tuning.targetString(
            for: frequency ?? 0,
            selectedStringID: selectedStringID
        )

        // В ручном режиме цель остаётся видна даже в тишине.
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
