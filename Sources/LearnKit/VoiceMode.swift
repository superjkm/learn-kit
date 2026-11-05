/// How the child can answer by voice.
public enum VoiceMode: String, Codable, CaseIterable, Sendable {
    /// Typing only; the microphone is never used.
    case off
    /// Always listening while a prompt is up; a number is graded once it settles.
    case automatic
    /// Listening only while the spacebar is held; releasing it grades what was said.
    case holdToTalk

    /// Whether this mode uses the microphone at all.
    public var listens: Bool { self != .off }
}
