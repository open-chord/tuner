import Foundation

enum PitchDetector {
    static func estimateFrequency(
        samples: [Float],
        sampleRate: Double,
        minimumFrequency: Double = 55,
        maximumFrequency: Double = 400
    ) -> Double? {
        guard samples.count >= 512, sampleRate > 0 else { return nil }

        let mean = samples.reduce(0, +) / Float(samples.count)
        let centered = samples.map { $0 - mean }
        let energy = centered.reduce(0) { $0 + $1 * $1 } / Float(centered.count)
        guard energy > 0.000_01 else { return nil }

        let minimumLag = max(2, Int(sampleRate / maximumFrequency))
        let maximumLag = min(centered.count / 2, Int(sampleRate / minimumFrequency))
        guard minimumLag < maximumLag else { return nil }

        var bestLag = minimumLag
        var bestCorrelation: Float = -.infinity

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

            let denominator = sqrt(leftEnergy * rightEnergy)
            let normalized = denominator > 0 ? correlation / denominator : 0
            if normalized > bestCorrelation {
                bestCorrelation = normalized
                bestLag = lag
            }
        }

        guard bestCorrelation > 0.75 else { return nil }
        return sampleRate / Double(bestLag)
    }
}
