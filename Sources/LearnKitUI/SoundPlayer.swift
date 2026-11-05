import AppKit
import LearnKit

/// Plays the short bundled sound cues. Silent when muted.
@MainActor public final class SoundPlayer {
    public static let shared = SoundPlayer()

    public enum Cue: String, Sendable { case tick, burst, run, finish }

    private var cache: [Cue: NSSound] = [:]

    private init() {}

    public func play(_ cue: Cue, muted: Bool) {
        guard !muted, let sound = sound(for: cue) else { return }
        sound.stop()
        sound.play()
    }

    /// The cue for an answer's celebrations: tick for a plain correct answer, burst for a
    /// burst or a real moment, run for a run milestone, nothing for a wrong answer.
    public static func cue(for celebrations: [Celebration]) -> Cue? {
        switch CelebrationOverlay.biggest(celebrations) {
        case .tick: return .tick
        case .burst, .moment: return .burst
        case .run: return .run
        case .wrong, nil: return nil
        }
    }

    private func sound(for cue: Cue) -> NSSound? {
        if let cached = cache[cue] { return cached }
        guard let url = Bundle.module.url(forResource: cue.rawValue, withExtension: "wav"),
              let sound = NSSound(contentsOf: url, byReference: true)
        else { return nil }
        cache[cue] = sound
        return sound
    }
}
