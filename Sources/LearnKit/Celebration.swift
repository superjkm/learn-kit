import Foundation

/// What to show for one answer. The strings are the app's: a burst word, a moment's text, or
/// the shown correction and its note.
public enum Celebration: Hashable, Sendable {
    case tick
    case burst(String)
    case run(Int)
    case moment(String)
    case wrong(shown: String, note: String)
}

public enum Celebrations {
    public static let burstOneIn = 4
    public static let runMilestones = [3, 5, 10]
    /// How many live moments a session may announce; the app enforces it by passing
    /// `momentText: nil` once the cap is reached.
    public static let liveMomentCap = 3

    /// The celebrations for one answer, in display order: nothing for a wrong answer (the app
    /// adds `.wrong` itself if it shows a correction); otherwise a tick, then a run milestone or
    /// (one time in four) a burst word drawn from `burstWords` with `rng`, then the moment.
    public static func forAnswer(correct: Bool, correctRun: Int, burstWords: [String], momentText: String?, rng: inout some RandomNumberGenerator) -> [Celebration] {
        guard correct else { return [] }
        var result: [Celebration] = [.tick]
        if runMilestones.contains(correctRun) {
            result.append(.run(correctRun))
        } else if Int.random(in: 0..<burstOneIn, using: &rng) == 0, !burstWords.isEmpty {
            result.append(.burst(burstWords[Int.random(in: 0..<burstWords.count, using: &rng)]))
        }
        if let momentText { result.append(.moment(momentText)) }
        return result
    }
}
