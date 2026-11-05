import Foundation

public enum Grade: Int, Codable, Sendable, CaseIterable { case again = 1, hard, good, easy }

public struct Memory: Hashable, Codable, Sendable {
    public var stability: Double
    public var difficulty: Double
    public init(stability: Double, difficulty: Double) {
        self.stability = stability
        self.difficulty = difficulty
    }
}

public enum FSRS {
    public static let defaultWeights: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575,
        0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621,
    ]
    public static let targetRetention = 0.9
    public static let decay = -0.5
    public static let factor = 19.0 / 81.0

    private static let minStability = 0.01

    private static func clampDifficulty(_ d: Double) -> Double { min(10, max(1, d)) }

    private static func initialDifficulty(_ grade: Grade, _ w: [Double]) -> Double {
        clampDifficulty(w[4] - exp(w[5] * Double(grade.rawValue - 1)) + 1)
    }

    public static func initialMemory(grade: Grade, w: [Double] = defaultWeights) -> Memory {
        Memory(stability: max(minStability, w[grade.rawValue - 1]),
               difficulty: initialDifficulty(grade, w))
    }

    public static func retrievability(stability: Double, elapsedDays: Int) -> Double {
        if elapsedDays <= 0 { return 1.0 }
        return pow(1 + factor * Double(elapsedDays) / stability, decay)
    }

    public static func nextMemory(_ m: Memory, grade: Grade, elapsedDays: Int, w: [Double] = defaultWeights) -> Memory {
        let g = Double(grade.rawValue)
        let s = m.stability
        let d = clampDifficulty(m.difficulty)

        let deltaD = -w[6] * (g - 3)
        let dPrime = d + deltaD * (10 - d) / 9
        let newD = clampDifficulty(w[7] * initialDifficulty(.easy, w) + (1 - w[7]) * dPrime)

        let newS: Double
        if elapsedDays <= 0 {
            newS = s * exp(w[17] * (g - 3 + w[18]))
        } else {
            let r = retrievability(stability: s, elapsedDays: elapsedDays)
            if grade == .again {
                let sf = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp(w[14] * (1 - r))
                newS = min(sf, s)
            } else {
                let hardPenalty = grade == .hard ? w[15] : 1
                let easyBonus = grade == .easy ? w[16] : 1
                newS = s * (exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp(w[10] * (1 - r)) - 1) * hardPenalty * easyBonus + 1)
            }
        }
        return Memory(stability: max(minStability, newS), difficulty: newD)
    }

    public static func intervalDays(stability: Double, retention: Double = targetRetention) -> Int {
        let raw = stability / factor * (pow(retention, 1 / decay) - 1)
        let rounded = raw.rounded()
        guard rounded.isFinite else { return rounded > 0 ? 36500 : 1 }
        return Int(min(36500, max(1, rounded)))
    }
}
