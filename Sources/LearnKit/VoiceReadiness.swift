import Foundation

/// A speech recognizer error as plain values, so it can be classified and logged off the
/// Speech framework.
public struct SpeechFailure: Equatable, Sendable {
    public var domain: String
    public var code: Int
    public var description: String

    public init(domain: String, code: Int, description: String) {
        self.domain = domain
        self.code = code
        self.description = description
    }

    /// "domain code: description", or "domain code" when there is no description.
    public var summary: String {
        description.isEmpty ? "\(domain) \(code)" : "\(domain) \(code): \(description)"
    }
}

/// Whether a permission voice needs has been given. Never asked for by the probe.
public enum VoicePermission: Sendable, Equatable {
    case granted, denied, notAsked
}

/// What the readiness probe saw: the permissions, the recognizer's own flags, and how a
/// silent on-device recognition task ended (nil when it was not run).
public struct VoiceProbe: Sendable, Equatable {
    public enum Outcome: Sendable, Equatable {
        case finished
        case failed(SpeechFailure)
        case timedOut
    }

    public var speech: VoicePermission
    public var microphone: VoicePermission
    public var recognizerExists: Bool
    public var supportsOnDevice: Bool
    public var isAvailable: Bool
    public var outcome: Outcome?

    public init(speech: VoicePermission, microphone: VoicePermission, recognizerExists: Bool,
                supportsOnDevice: Bool, isAvailable: Bool, outcome: Outcome?) {
        self.speech = speech
        self.microphone = microphone
        self.recognizerExists = recognizerExists
        self.supportsOnDevice = supportsOnDevice
        self.isAvailable = isAvailable
        self.outcome = outcome
    }
}

/// Whether voice answers can work on this Mac right now, and if not, what to do about it.
public enum VoiceReadiness: Sendable, Equatable {
    case ready
    /// On-device English recognition is missing: Dictation (which downloads it) is off or not
    /// finished downloading.
    case needsDictation
    /// Microphone or speech recognition permission was refused.
    case needsPermission
    /// Anything else, with the error text.
    case unavailable(String)

    public var isReady: Bool { self == .ready }

    /// Classifies a probe; nil when it cannot tell (permission not asked yet, the silent task
    /// did not run or timed out, or a transient error). Conservative: only known signs of a
    /// missing model become `.needsDictation`; unknown errors stay `.unavailable` with their text.
    public static func classify(_ probe: VoiceProbe) -> VoiceReadiness? {
        if probe.speech == .denied || probe.microphone == .denied { return .needsPermission }
        // The app requires on-device recognition, so a recognizer that cannot do it is the
        // missing-model case.
        if !probe.recognizerExists || !probe.supportsOnDevice || !probe.isAvailable { return .needsDictation }
        guard probe.speech == .granted else { return nil }
        switch probe.outcome {
        case nil, .timedOut: return nil
        case .finished: return .ready
        case let .failed(failure): return classify(failure)
        }
    }

    /// Classifies an error from a recognition task; nil when it says nothing about readiness.
    public static func classify(_ failure: SpeechFailure) -> VoiceReadiness? {
        switch (failure.domain, failure.code) {
        // No speech detected: the normal end of a silent request.
        case ("kAFAssistantErrorDomain", 1110): return .ready
        // Request is not authorized.
        case ("kAFAssistantErrorDomain", 1700): return .needsPermission
        // The local speech service refused the request; reported for a missing on-device model.
        case ("kAFAssistantErrorDomain", 1101): return .needsDictation
        // Another task still active, the speech process interrupted, or cancelled.
        case ("kAFAssistantErrorDomain", 1100), ("kAFAssistantErrorDomain", 1107),
             ("kAFAssistantErrorDomain", 216), ("kAFAssistantErrorDomain", 301): return nil
        // Failed to access assets, Siri and Dictation are disabled, failed to initialize recognizer.
        case ("kLSRErrorDomain", 102), ("kLSRErrorDomain", 201), ("kLSRErrorDomain", 300): return .needsDictation
        default:
            let text = failure.description.lowercased()
            if text.contains("dictation") || text.contains("asset") { return .needsDictation }
            return .unavailable(failure.summary)
        }
    }
}
