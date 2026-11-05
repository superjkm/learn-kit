/// Decides what a hold-to-talk transcript was, from the recognizer results of that hold.
///
/// The spacebar's release closes the hold's request: no audio reaches it afterwards, but the
/// recognizer may still be working through the audio it already has. After `release(segment:)`
/// the transcript is that request's final result when it has words; if no final comes within
/// `finalWait`, the newest non-empty partial heard during the hold (`timedOut()`); and if there
/// was none, the empty string. Results for any other request (`segment`) after the release are
/// ignored, so speech after the release can never become the answer. Once decided, everything
/// else is ignored. The text is passed on as the recognizer gave it; the app parses it.
public struct HoldTranscript: Sendable {
    /// How long after the release the final result is waited for.
    public static let finalWait: Duration = .milliseconds(2500)

    /// Why the transcript was decided when it was.
    public enum Path: String, Sendable {
        case final
        case waitTimeout = "best partial after wait"
        case ended = "recognizer ended"
        case pressedAgain = "pressed again"
    }

    public enum Outcome: Equatable, Sendable {
        /// Not decided yet.
        case waiting
        /// A result for a request other than the released one, one after the decision, or an
        /// ended request while the key is still down (the transcriber rolls to a new request).
        case ignored
        case decided(text: String, path: Path)
    }

    /// The request (segment) that was current at the release; nil while the key is held.
    public private(set) var releasedSegment: Int?
    /// The newest non-empty words heard in this hold.
    public private(set) var latest = ""
    private var decided = false

    public init() {}

    public mutating func release(segment: Int) {
        releasedSegment = segment
    }

    /// A recognizer result for request `segment`.
    public mutating func heard(_ text: String, isFinal: Bool, segment: Int) -> Outcome {
        guard !decided else { return .ignored }
        if let releasedSegment, segment != releasedSegment { return .ignored }
        if isFinal, releasedSegment != nil { return decide(.final, final: text) }
        note(text)
        return .waiting
    }

    /// `finalWait` passed after the release with no final result.
    public mutating func timedOut() -> Outcome {
        guard !decided else { return .ignored }
        guard releasedSegment != nil else { return .waiting }
        return decide(.waitTimeout, final: nil)
    }

    /// The recognizer stopped request `segment` without a final result (an error or no speech).
    public mutating func ended(segment: Int) -> Outcome {
        guard !decided else { return .ignored }
        guard let releasedSegment, segment == releasedSegment else { return .ignored }
        return decide(.ended, final: nil)
    }

    /// The spacebar went down again before the transcript was decided.
    public mutating func interrupted() -> Outcome {
        guard !decided else { return .ignored }
        return decide(.pressedAgain, final: nil)
    }

    private mutating func note(_ text: String) {
        if !text.isEmpty { latest = text }
    }

    private mutating func decide(_ path: Path, final: String?) -> Outcome {
        decided = true
        if let final, !final.isEmpty { return .decided(text: final, path: path) }
        return .decided(text: latest, path: path)
    }
}
