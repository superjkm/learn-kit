import AVFoundation
import Foundation
import LearnKit
import os
import Speech

/// The app's one speech recognizer, made on first use and kept for the life of the app, so the
/// on-device model is loaded once per launch rather than once per listener or prompt.
///
/// `probe(reason:)` runs a silent recognition task (an empty request whose audio ends at
/// once) so the model is resident before the first press, and reports how it ended so
/// `VoiceReadiness` can say whether voice works; the app runs it at launch, on app activation,
/// when the practice screen appears, and on "Check again". It never asks for permission, and
/// logs its outcome and timing to the voice log. Result handlers run on `recognitionQueue`,
/// never on the main queue.
@MainActor public enum SharedRecognizer {
    /// Serial queue for recognition result handlers, which read the words there and send only
    /// plain values to the main actor (the recognizer's default would be the main queue).
    nonisolated public static let recognitionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "\(AppIdentity.current.bundleID).recognition"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    /// How long the probe waits for the silent task before calling it inconclusive.
    public static let warmUpLimit: Duration = .seconds(30)

    public static let recognizer: SFSpeechRecognizer? = {
        let started = ContinuousClock.now
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        recognizer?.queue = recognitionQueue
        log("recognizer created in \(VoiceTiming.ms(.now - started)) ms: exists=\(recognizer != nil)"
            + " onDevice=\(recognizer?.supportsOnDeviceRecognition ?? false)"
            + " available=\(recognizer?.isAvailable ?? false)"
            + " speechAuthorization=\(SFSpeechRecognizer.authorizationStatus().rawValue)")
        return recognizer
    }()

    /// Runs the readiness probe, which is also the warm-up: reads the permissions and the
    /// recognizer's flags without asking for anything, and when speech is authorized and
    /// on-device recognition is offered, runs a silent recognition task (an empty on-device
    /// request whose audio ends at once) so the model is loaded, and reports how it ended.
    /// Gives up waiting after `warmUpLimit`. Logs the raw outcome to the voice log.
    public static func probe(reason: String) async -> VoiceProbe {
        var probe = VoiceProbe(
            speech: permission(SFSpeechRecognizer.authorizationStatus()),
            microphone: permission(AVCaptureDevice.authorizationStatus(for: .audio)),
            recognizerExists: recognizer != nil,
            supportsOnDevice: recognizer?.supportsOnDeviceRecognition ?? false,
            isAvailable: recognizer?.isAvailable ?? false,
            outcome: nil)
        let flags = "speech=\(probe.speech) microphone=\(probe.microphone) recognizer=\(probe.recognizerExists)"
            + " onDevice=\(probe.supportsOnDevice) available=\(probe.isAvailable)"
        guard probe.speech == .granted, let recognizer, probe.supportsOnDevice, probe.isAvailable else {
            log("warm-up (\(reason)) skipped: \(flags)")
            return probe
        }
        log("warm-up (\(reason)) started: \(flags)")
        let started = ContinuousClock.now
        let outcome = await withCheckedContinuation { (continuation: CheckedContinuation<VoiceProbe.Outcome, Never>) in
            silentTask(recognizer, limit: warmUpLimit) { continuation.resume(returning: $0) }
        }
        probe.outcome = outcome
        log("warm-up (\(reason)) done in \(VoiceTiming.ms(.now - started)) ms: \(describe(outcome))")
        return probe
    }

    /// The outcome as logged: "final", "timed out", or the raw error domain, code and text.
    nonisolated public static func describe(_ outcome: VoiceProbe.Outcome?) -> String {
        switch outcome {
        case nil: return "not run"
        case .finished: return "final"
        case .timedOut: return "timed out"
        case let .failed(failure): return "error domain=\(failure.domain) code=\(failure.code) description=\"\(failure.description)\""
        }
    }

    /// An NSError as plain values.
    nonisolated public static func failure(_ error: any Error) -> SpeechFailure {
        let error = error as NSError
        return SpeechFailure(domain: error.domain, code: error.code, description: error.localizedDescription)
    }

    private static func permission(_ status: SFSpeechRecognizerAuthorizationStatus) -> VoicePermission {
        switch status {
        case .authorized: .granted
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    private static func permission(_ status: AVAuthorizationStatus) -> VoicePermission {
        switch status {
        case .authorized: .granted
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    /// Built outside the main actor: the handler runs on `recognitionQueue`, so it must not be
    /// a main-actor closure. The first final result or error ends the warm-up; if neither comes
    /// within `limit`, the task is cancelled and the outcome is `.timedOut`. `done` runs once.
    nonisolated private static func silentTask(
        _ recognizer: SFSpeechRecognizer, limit: Duration, done: @escaping @Sendable (VoiceProbe.Outcome) -> Void
    ) {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        let reported = OSAllocatedUnfairLock(initialState: false)
        let report: @Sendable (VoiceProbe.Outcome) -> Bool = { outcome in
            let first = reported.withLock { finished in
                defer { finished = true }
                return !finished
            }
            if first { done(outcome) }
            return first
        }
        let task = recognizer.recognitionTask(with: request) { result, error in
            if let error {
                _ = report(.failed(failure(error)))
            } else if result?.isFinal == true {
                _ = report(.finished)
            }
        }
        request.endAudio()
        let seconds = Double(limit.components.seconds) + Double(limit.components.attoseconds) / 1e18
        let box = UncheckedTask(task)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + seconds) {
            if report(.timedOut) { box.task.cancel() }
        }
    }

    /// Lets the timeout cancel the task from another queue; `cancel()` is safe from any thread.
    private struct UncheckedTask: @unchecked Sendable {
        let task: SFSpeechRecognitionTask
        init(_ task: SFSpeechRecognitionTask) { self.task = task }
    }

    nonisolated private static func log(_ line: String) {
        #if DEBUG
        VoiceTiming.logger.debug("\(line, privacy: .public)")
        #endif
        VoiceLog.shared.write(line)
    }
}
