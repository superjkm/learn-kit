/// How long the microphone has heard voice, counting speech with its small gaps.
///
/// Fed one voiced buffer at a time by `AudioFeed` (a buffer whose loudness passed `voicedRMS`).
/// A voiced buffer that comes within `gap` of the one before adds the whole time between them,
/// so the consonants and breaths inside a word or a phrase count as voice; after a longer pause
/// only the buffer's own length is added, so silence never counts. Steady noise therefore
/// accumulates at wall-clock speed, and a child who repeats an answer accumulates across the
/// repetitions.
public struct VoicedTime: Sendable, Equatable {
    /// The longest break that still counts as part of the same speech; also the listener's
    /// idea of "quiet", so any audio that keeps a number from settling counts here instead.
    public static let gap: Duration = .milliseconds(300)

    /// When the last voiced buffer was heard; nil until one is.
    public private(set) var lastAt: ContinuousClock.Instant?
    /// Voiced time heard so far. Only ever grows.
    public private(set) var total: Duration = .zero

    public init() {}

    /// A voiced buffer of `length` was heard at `now`.
    public mutating func heard(at now: ContinuousClock.Instant, length: Duration) {
        if let lastAt, now > lastAt, now - lastAt < Self.gap {
            total += now - lastAt
        } else {
            total += length
        }
        lastAt = now
    }
}
