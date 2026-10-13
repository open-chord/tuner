import Foundation

/// Estimates the fundamental frequency of a short audio sample buffer.
/// This algorithm is independent of the microphone and the UI.
enum PitchDetector {
    /// A saturated input cannot provide a trustworthy pitch reading. Ignore
    /// a single clipped attack, but reject sustained clipping in a buffer.
    static func isClipping(samples: [Float]) -> Bool {
        guard !samples.isEmpty else { return false }
        let clippedCount = samples.reduce(into: 0) { count, sample in
            if abs(sample) >= 0.98 { count += 1 }
        }
        return clippedCount * 100 >= samples.count
    }

    /// Returns a frequency in hertz, or `nil` for silence or an unreliable signal.
    static func estimateFrequency(
        samples: [Float],
        sampleRate: Double,
        minimumFrequency: Double = 55,
        maximumFrequency: Double = 400
    ) -> Double? {
        guard samples.count >= 512, sampleRate > 0 else { return nil }

        // Remove the DC offset, then reject silence using the signal's energy.
        let mean = samples.reduce(0, +) / Float(samples.count)
        let centered = samples.map { $0 - mean }
        let energy = centered.reduce(0) { $0 + $1 * $1 } / Float(centered.count)
        guard energy > 0.000_01 else { return nil }

        // Period length = sample rate / frequency. Search only the tuner's
        // supported frequency range instead of every possible period.
        let minimumLag = max(2, Int(sampleRate / maximumFrequency))
        let maximumLag = min(centered.count / 2, Int(sampleRate / minimumFrequency))
        guard minimumLag < maximumLag else { return nil }

        var bestLag = minimumLag
        var bestCorrelation: Float = -.infinity

        // Autocorrelation compares the signal with a copy shifted by `lag`.
        // The strongest match estimates the repeating waveform's period.
        for lag in minimumLag...maximumLag {
            var correlation: Float = 0
            var leftEnergy: Float = 0
            var rightEnergy: Float = 0

            for index in 0..<(centered.count - lag) {
                let left = centered[index]
                let right = centered[index + lag]
                correlation += left * right
                leftEnergy += left * left
                rightEnergy += right * right
            }

            // Normalize so a louder segment cannot win solely because of its
            // amplitude; we want to compare waveform shape.
            let denominator = sqrt(leftEnergy * rightEnergy)
            let normalized = denominator > 0 ? correlation / denominator : 0
            if normalized > bestCorrelation {
                bestCorrelation = normalized
                bestLag = lag
            }
        }

        // Treat a weak match as noise rather than a stable musical pitch.
        guard bestCorrelation > 0.75 else { return nil }
        return sampleRate / Double(bestLag)
    }
}

/// Keeps one transient frequency error from changing the displayed string.
/// Three readings are enough to show a pitch; two missed buffers clear it.
struct PitchStabilizer {
    private var recent: [Double] = []
    private var missedFrames = 0
    private let windowSize = 5

    mutating func update(with frequency: Double?) -> Double? {
        guard let frequency, frequency.isFinite, frequency > 0 else {
            missedFrames += 1
            if missedFrames >= 2 { reset() }
            return recent.count >= 3 ? median : nil
        }

        missedFrames = 0
        recent.append(frequency)
        if recent.count > windowSize { recent.removeFirst() }
        return recent.count >= 3 ? median : nil
    }

    mutating func reset() {
        recent.removeAll(keepingCapacity: true)
        missedFrames = 0
    }

    private var median: Double {
        let sorted = recent.sorted()
        return sorted[sorted.count / 2]
    }
}
