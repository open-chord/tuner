import Accelerate
import Foundation

/// One plausible fundamental period in an audio frame. Lower error means the
/// waveform repeats more consistently at this frequency.
struct PitchCandidate {
    let frequency: Double
    let error: Float
}

/// Finds plausible fundamental frequencies with YIN's cumulative mean
/// normalized difference function. It is independent of the microphone/UI.
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

    /// Returns several plausible pitches, ordered by periodicity. Keeping
    /// alternatives lets the tracker resolve octave ambiguity across frames.
    static func candidates(
        samples: [Float],
        sampleRate: Double,
        minimumFrequency: Double = 55,
        maximumFrequency: Double = 400
    ) -> [PitchCandidate] {
        guard samples.count >= 512, sampleRate > 0,
              minimumFrequency > 0, maximumFrequency > minimumFrequency else { return [] }

        let mean = samples.reduce(0, +) / Float(samples.count)
        let centered = samples.map { $0 - mean }
        let energy = centered.reduce(0) { $0 + $1 * $1 } / Float(centered.count)
        guard energy > 0.000_01 else { return [] }

        let minimumLag = max(2, Int(sampleRate / maximumFrequency))
        let maximumLag = min(centered.count / 2, Int(sampleRate / minimumFrequency))
        guard minimumLag + 1 < maximumLag else { return [] }

        // Every lag uses the same half-frame, so longer periods do not win
        // merely because fewer samples were compared.
        let windowSize = centered.count / 2
        var normalizedDifference = [Float](repeating: 1, count: maximumLag + 1)
        var runningDifference: Float = 0
        var squaredPrefix = [Float](repeating: 0, count: centered.count + 1)
        for index in centered.indices {
            squaredPrefix[index + 1] = squaredPrefix[index] + centered[index] * centered[index]
        }
        let leftEnergy = squaredPrefix[windowSize]
        centered.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            for lag in 1...maximumLag {
                var correlation: Float = 0
                vDSP_dotpr(base, 1, base.advanced(by: lag), 1, &correlation,
                           vDSP_Length(windowSize))
                let rightEnergy = squaredPrefix[lag + windowSize] - squaredPrefix[lag]
                let difference = max(0, leftEnergy + rightEnergy - 2 * correlation)
                runningDifference += difference
                normalizedDifference[lag] = runningDifference > 0
                    ? difference * Float(lag) / runningDifference : 1
            }
        }

        var result: [PitchCandidate] = []
        for lag in minimumLag...maximumLag {
            let error = normalizedDifference[lag]
            guard error < 0.15,
                  (lag == minimumLag || error <= normalizedDifference[lag - 1]),
                  (lag == maximumLag || error < normalizedDifference[lag + 1]) else { continue }

            // Parabolic interpolation removes integer-lag quantization from
            // the cents display.
            let offset: Float
            if lag > minimumLag && lag < maximumLag {
                let before = normalizedDifference[lag - 1]
                let after = normalizedDifference[lag + 1]
                let curvature = before - 2 * error + after
                offset = abs(curvature) > 0.000_001
                    ? min(0.5, max(-0.5, 0.5 * (before - after) / curvature)) : 0
            } else {
                offset = 0
            }
            result.append(PitchCandidate(
                frequency: sampleRate / (Double(lag) + Double(offset)),
                error: error
            ))
        }
        guard !result.isEmpty else { return [] }

        // Difference functions can give a low-error result at a divisor of
        // the real period. Require each candidate to have some energy at its
        // own frequency, not only at a louder harmonic above it.
        let strengths = result.map {
            spectralMagnitude(samples: centered, frequency: $0.frequency, sampleRate: sampleRate)
        }
        let strongest = strengths.max() ?? 0
        // An almost perfectly repeating fundamental remains credible even
        // when its second harmonic dominates the spectrum.
        return result.enumerated().compactMap { index, candidate in
            strengths[index] >= strongest * 0.2 || candidate.error < 0.000_1
                ? candidate : nil
        }.sorted { $0.error < $1.error }
    }

    /// Goertzel evaluates one spectral frequency without building an FFT.
    private static func spectralMagnitude(
        samples: [Float], frequency: Double, sampleRate: Double
    ) -> Double {
        let coefficient = 2 * cos(2 * Double.pi * frequency / sampleRate)
        var previous = 0.0
        var beforePrevious = 0.0
        for sample in samples {
            let current = Double(sample) + coefficient * previous - beforePrevious
            beforePrevious = previous
            previous = current
        }
        return sqrt(max(0, previous * previous + beforePrevious * beforePrevious
                        - coefficient * previous * beforePrevious))
    }

    /// The best single-frame estimate remains useful for isolated core tests.
    /// Live tuning uses all candidates through `PitchTracker` instead.
    static func estimateFrequency(
        samples: [Float],
        sampleRate: Double,
        minimumFrequency: Double = 55,
        maximumFrequency: Double = 400
    ) -> Double? {
        candidates(
            samples: samples,
            sampleRate: sampleRate,
            minimumFrequency: minimumFrequency,
            maximumFrequency: maximumFrequency
        ).first?.frequency
    }
}

/// Tracks a pitch through time rather than treating every buffer as a new
/// string. Continuity only breaks ties among good candidates; a clearly
/// better new pitch can still take over without a note-specific exception.
struct PitchTracker {
    private var recent: [Double] = []
    private var missedFrames = 0
    private let windowSize = 5

    mutating func update(with candidates: [PitchCandidate]) -> Double? {
        guard let best = candidates.first else {
            missedFrames += 1
            if missedFrames >= 2 { reset() }
            return recent.count >= 3 ? median : nil
        }

        missedFrames = 0
        let chosen: PitchCandidate
        if recent.count >= 3 {
            chosen = candidates.first(where: { candidate in
                let cents = 1200 * log2(candidate.frequency / median)
                return abs(cents) < 70 && candidate.error <= best.error + 0.04
            }) ?? best
        } else {
            chosen = best
        }

        recent.append(chosen.frequency)
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
