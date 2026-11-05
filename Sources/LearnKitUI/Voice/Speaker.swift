import AVFoundation
import Observation

/// An installed speech voice as plain values, so the choice can be tested without AVFoundation.
public struct VoiceCandidate: Equatable, Sendable {
    public var identifier: String
    public var language: String
    /// `AVSpeechSynthesisVoiceQuality.rawValue`: default 1, enhanced 2, premium 3.
    public var quality: Int

    public init(identifier: String, language: String, quality: Int) {
        self.identifier = identifier
        self.language = language
        self.quality = quality
    }
}

/// Says a prompt out loud through `AVSpeechSynthesizer` with the best installed en-US voice.
/// Not affected by the effects mute: the app decides whether to call it. `onFinished` runs
/// when an utterance ends on its own; `stop()` cuts it silently.
@MainActor @Observable public final class Speaker {
    nonisolated public static let defaultRate: Float = 0.45

    public private(set) var isSpeaking = false
    @ObservationIgnored public var onFinished: (() -> Void)?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var relay: SpeakerRelay?
    @ObservationIgnored private var voice: AVSpeechSynthesisVoice?
    /// Identity of the utterance whose end we are waiting for. Delegate callbacks for any
    /// other utterance (such as the one `speak()` just cut off) are stale and ignored.
    @ObservationIgnored private var currentUtterance: ObjectIdentifier?
    /// Keeps the current utterance alive so its identity cannot be reused by another object.
    @ObservationIgnored private var currentUtteranceRef: AVSpeechUtterance?

    public init() {
        let relay = SpeakerRelay(
            onFinish: { [weak self] id in Task { @MainActor in self?.utteranceEnded(id, cancelled: false) } },
            onCancel: { [weak self] id in Task { @MainActor in self?.utteranceEnded(id, cancelled: true) } })
        synthesizer.delegate = relay
        self.relay = relay
        voice = Self.installedVoice()
    }

    /// Speaks `text`, cutting off anything still being said.
    public func speak(_ text: String, rate: Float = Speaker.defaultRate) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.voice = voice
        track(utterance)
        synthesizer.speak(utterance)
    }

    public func stop() {
        currentUtterance = nil
        currentUtteranceRef = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    /// The best en-US voice: premium over enhanced over default, ties by identifier so the
    /// choice is the same on every launch. Nil when no en-US voice is installed (the system
    /// default is used).
    nonisolated public static func preferredVoice(among candidates: [VoiceCandidate]) -> VoiceCandidate? {
        candidates
            .filter { $0.language == "en-US" }
            .min { a, b in a.quality != b.quality ? a.quality > b.quality : a.identifier < b.identifier }
    }

    /// Marks `utterance` as the one being spoken. Internal so tests can drive the stale-callback guard.
    func track(_ utterance: AVSpeechUtterance) {
        currentUtterance = ObjectIdentifier(utterance)
        currentUtteranceRef = utterance
        isSpeaking = true
    }

    /// Handles a delegate callback. Internal so tests can drive it with chosen identities.
    func utteranceEnded(_ id: ObjectIdentifier, cancelled: Bool) {
        guard id == currentUtterance else { return }
        currentUtterance = nil
        currentUtteranceRef = nil
        isSpeaking = false
        if !cancelled { onFinished?() }
    }

    private static func installedVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let candidates = voices.map { VoiceCandidate(identifier: $0.identifier, language: $0.language, quality: $0.quality.rawValue) }
        guard let best = preferredVoice(among: candidates) else { return nil }
        return voices.first { $0.identifier == best.identifier }
    }
}

/// The synthesizer's delegate; its callbacks arrive on no particular thread, so they only hop
/// to the main actor, passing the utterance's identity as a plain value. At file scope, not
/// nested, so it does not inherit `Speaker`'s main-actor isolation.
private final class SpeakerRelay: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    let onFinish: @Sendable (ObjectIdentifier) -> Void
    let onCancel: @Sendable (ObjectIdentifier) -> Void

    init(onFinish: @escaping @Sendable (ObjectIdentifier) -> Void, onCancel: @escaping @Sendable (ObjectIdentifier) -> Void) {
        self.onFinish = onFinish
        self.onCancel = onCancel
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish(ObjectIdentifier(utterance))
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onCancel(ObjectIdentifier(utterance))
    }
}
