import AVFoundation
import LearnKit
import Observation
import os
import Speech

/// Hears what the child says while the spacebar is held, entirely on this Mac, and hands the
/// words on as the recognizer gave them. The app parses them (numbers, letters).
///
/// Recognition must run on-device: if the Mac cannot recognize English locally the transcriber
/// reports `.unavailable(.notOnDevice)` and never falls back to Apple's servers.
///
/// The microphone runs from `start()` until `stop()` (so the macOS microphone indicator stays
/// on), feeding only a short replay buffer; `beginHold()` opens a recognition request and
/// replays the last `pressReplay` into it, so the first syllable is not lost. The window is
/// strict: `endHold()` detaches the request from the microphone at once (the next buffer
/// reaches no request), ends its audio, and empties the replay buffer, so nothing said after
/// the release can reach this answer or a later one. While `.finishing`, the words the request
/// already has are decided by `HoldTranscript`: the request's final result, else its newest
/// partial after `HoldTranscript.finalWait`; results for any other request are ignored. The
/// text is delivered once through `onFinal`, empty when nothing was heard.
///
/// If the recognizer ends a result while the key is still down, a new request takes over the
/// same running engine and tap and the earlier words are kept in front of the new ones.
@MainActor @Observable public final class HoldToTalkTranscriber {
    public enum Reason: Equatable, Sendable {
        /// The input node has no usable format.
        case noMicrophone
        /// No recognizer, or it cannot work on-device, or it is not available.
        case notOnDevice
        /// `AVAudioEngine.start()` threw.
        case engineFailed
    }

    public enum State: Equatable, Sendable {
        case idle
        /// Microphone warm (or warming), waiting for the spacebar.
        case ready
        /// Spacebar held; `partialTranscript` fills as words arrive.
        case holding
        /// Released; the words of the hold are being read.
        case finishing
        case unavailable(Reason)
        case denied
    }

    public private(set) var state: State = .idle
    /// The words heard so far in the current hold, updated at most every `indicatorInterval`.
    public private(set) var partialTranscript = ""
    /// Words the recognizer should favour (letter names, "space", "apostrophe"). Read when a
    /// request is made, so a change applies from the next press.
    @ObservationIgnored public var contextualStrings: [String]

    /// Receives the hold's words once it is decided (may be empty).
    @ObservationIgnored public var onFinal: ((String) -> Void)?
    /// Receives the error of the current request when it ends with one, so readiness can name
    /// the cause. Errors of requests already superseded are logged, not reported, and the
    /// recognizer's "no speech detected" end (`kAFAssistantErrorDomain` 1110) is not an error.
    @ObservationIgnored public var onFailure: ((SpeechFailure) -> Void)?
    /// Called after a permission prompt was answered, with whether both were granted.
    @ObservationIgnored public var onPermissionAnswered: ((_ granted: Bool) -> Void)?

    /// Seconds of audio from just before the press replayed into the new request, covering the
    /// moment between pressing and the request starting. Also used when a hold rolls to a new
    /// request. Never older than the previous answer's decision (see `AudioFeed.invalidateRing`).
    public static let pressReplay: Double = 0.15
    /// Recognition requests one hold may start after the recognizer stops on its own, so a
    /// recognizer that keeps failing cannot loop.
    public static let maxHoldRestarts = 4
    /// `partialTranscript` changes at most this often while words are coming in.
    public static let indicatorInterval: Duration = .milliseconds(100)

    /// The app's one recognizer (see `SharedRecognizer`), so a new transcriber never reloads the model.
    private var recognizer: SFSpeechRecognizer? { SharedRecognizer.recognizer }
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    /// A request made while idle, so a press only has to swap it in.
    @ObservationIgnored private var spareRequest: SFSpeechAudioBufferRecognitionRequest?
    /// Hands microphone buffers to the current request.
    @ObservationIgnored private var feed: AudioFeed?
    /// True between `start()` and `stop()`.
    @ObservationIgnored private var wanted = false
    /// Bumped whenever recognition is torn down, so callbacks from an older session are dropped.
    @ObservationIgnored private var session = 0
    /// Bumped whenever a new recognition request starts, so results from an older request are dropped.
    @ObservationIgnored private var segment = 0
    /// True from `beginHold()` until `endHold()` or until typing cancels the hold.
    @ObservationIgnored private var holdActive = false
    /// The spacebar is up and the last words are being collected.
    @ObservationIgnored private var releasing = false
    @ObservationIgnored private var releaseTimer: Task<Void, Never>?
    /// Set when `onFinal` has run for this hold, so a press that interrupts a release does not
    /// also start a new hold for a prompt the app has just moved past.
    @ObservationIgnored private var delivered = false
    /// Finished segments of this hold, oldest first, and the current partial.
    @ObservationIgnored private var holdSegments: [String] = []
    @ObservationIgnored private var holdPartial = ""
    /// Decides the text once the key is up, from the released request only.
    @ObservationIgnored private var transcript = HoldTranscript()
    @ObservationIgnored private var holdRestarts = 0
    /// When `partialTranscript` last changed, and newer words waiting for `indicatorInterval`.
    @ObservationIgnored private var shownAt: ContinuousClock.Instant?
    @ObservationIgnored private var pendingShown: String?
    @ObservationIgnored private var showFlush: Task<Void, Never>?
    /// Instants of the current hold, logged as one `timing` line when it is decided or dropped.
    @ObservationIgnored private var timing = HoldTiming()
    #if DEBUG
    /// Logs main-thread stalls over 50 ms from the press until the hold is decided or dropped.
    @ObservationIgnored private let watchdog = MainStallWatchdog()
    #endif

    public init(contextualStrings: [String] = []) {
        self.contextualStrings = contextualStrings
    }

    /// Begins a prompt: asks for permission the first time and warms the microphone so a press
    /// can listen at once. A key already down begins a hold through `beginHold()`.
    public func start() {
        wanted = true
        let id = resetSession()
        trace("prompt start")
        holdActive = false
        // Nothing heard before this prompt was up can be replayed into its answer.
        feed?.clearReplay()
        partialTranscript = ""
        state = .ready
        if engine?.isRunning != true {
            Task { await warmUp(id) }
        }
    }

    /// Stops listening. Releases the microphone unless `keepingMicrophone` is true, which the
    /// app uses while feedback briefly covers the prompt, so the next press is not slowed by
    /// starting the engine again.
    public func stop(keepingMicrophone: Bool = false) {
        wanted = false
        holdActive = false
        logHoldTiming()
        resetSession()
        if !keepingMicrophone { shutDownAudio() }
        switch state {
        case .ready, .holding, .finishing: state = .idle
        case .idle, .unavailable, .denied: break
        }
    }

    /// True while recognition is running or about to: a readiness probe must not start then,
    /// since it would share the recognizer with a live request.
    public var isBusy: Bool { holdActive || releasing || task != nil }

    /// True from `beginHold()` until `endHold()` or `cancelHold()`.
    public var isHolding: Bool { holdActive }

    /// Starts again after voice could not start (`.unavailable` or `.denied`), for example once
    /// Dictation has been turned on. Does nothing while voice is working or not wanted.
    public func retry() {
        guard wanted, !Self.canListen(state) else { return }
        trace("retry after \(state)")
        stop()
        state = .idle
        start()
    }

    // MARK: - Spacebar

    /// The spacebar went down while a prompt is up.
    public func beginHold() {
        guard wanted, !holdActive, Self.canListen(state) else { return }
        if releasing {
            // Pressed again before the last release finished: decide that one first.
            apply(transcript.interrupted())
            if delivered { return }
        }
        let id = resetSession()
        holdActive = true
        timing = HoldTiming(pressedAt: .now)
        #if DEBUG
        watchdog.start()
        #endif
        partialTranscript = ""
        state = .holding
        if engine?.isRunning == true {
            trace("hold begin")
            openHoldRequest(session: id)
        } else {
            // The microphone is not running yet (first prompt, or it failed): start it,
            // then open the request if the key is still down.
            trace("hold begin: microphone not ready")
            Task { await warmUp(id) }
        }
    }

    /// The spacebar came up at `keyUpAt` (system uptime, the clock of `NSEvent.timestamp`).
    public func endHold(keyUpAt: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard holdActive else { return }
        holdActive = false
        timing.releasedAt = .now
        guard request != nil else {
            // Released before recognition started: nothing can have been heard.
            finishHold(text: "", path: "no request")
            return
        }
        // Strict window: the request leaves the microphone now, with no tail, and its audio
        // ends; the replay buffer is emptied. The engine keeps running for the next press.
        let released = feed?.release(cutoff: keyUpAt)
        (released?.request ?? (feed == nil ? request : nil))?.endAudio()
        request = nil
        timing.buffers = released?.appended
        timing.afterRelease = released?.appendedAfterCutoff
        timing.replayed = released?.replayed
        trace("release: request closed, buffers=\(released?.appended ?? 0) afterRelease=\(released?.appendedAfterCutoff ?? 0) replayed=\(String(format: "%.3f", released?.replayed ?? 0)) s")
        releasing = true
        transcript.release(segment: segment)
        state = .finishing
        armReleaseTimer()
    }

    /// The child typed: drop the hold in progress (or the release being decided) and ignore
    /// its words. Nothing is delivered.
    public func cancelHold() {
        guard holdActive || releasing else { return }
        trace("hold cancelled by typing")
        logHoldTiming()
        holdActive = false
        resetSession()
        prepareSpareRequest()
        partialTranscript = ""
        if Self.canListen(state) { state = .ready }
    }

    /// Decides the release on the newest partial `HoldTranscript.finalWait` after it, unless
    /// the released request's final result does it sooner.
    private func armReleaseTimer() {
        releaseTimer?.cancel()
        let id = session
        releaseTimer = Task { [weak self] in
            try? await Task.sleep(for: HoldTranscript.finalWait)
            guard !Task.isCancelled, let self, id == self.session, self.releasing else { return }
            self.apply(self.transcript.timedOut())
        }
    }

    /// Whether the indicator shows a working microphone, so a press means something.
    private static func canListen(_ state: State) -> Bool {
        switch state {
        case .unavailable, .denied: return false
        default: return true
        }
    }

    /// Acts on a decided hold; nothing to do while it is still waiting.
    private func apply(_ outcome: HoldTranscript.Outcome) {
        switch outcome {
        case .waiting, .ignored: return
        case let .decided(text, path): finishHold(text: text, path: path.rawValue)
        }
    }

    /// Delivers the hold's words. `path` says how they were decided, for the timing line.
    private func finishHold(text: String, path: String) {
        timing.chosenAt = .now
        timing.path = path
        // Audio from before this decision is never pre-rolled into the next press.
        feed?.invalidateRing()
        trace("hold end (\(path)): transcript=\"\(text)\"")
        resetSession()
        defer {
            logHoldTiming()
            // Off the critical path: the words are already delivered.
            prepareSpareRequest()
        }
        partialTranscript = ""
        if Self.canListen(state) { state = .ready }
        delivered = true
        onFinal?(text)
        timing.submittedAt = .now
    }

    /// Writes the hold's `timing` line and stops the stall watchdog.
    private func logHoldTiming() {
        guard timing.pressedAt != nil else { return }
        #if DEBUG
        watchdog.stop()
        let line = timing.summary(maxStall: watchdog.maxStall, stalls: watchdog.stalls)
        #else
        let line = timing.summary(maxStall: nil, stalls: nil)
        #endif
        // Logged once per hold.
        timing = HoldTiming()
        trace(line)
    }

    /// The recognizer ended a segment while the spacebar is still down. Keep its words and
    /// roll a new request onto the same running engine and tap.
    private func continueHold(session id: Int) {
        guard holdRestarts < Self.maxHoldRestarts, let recognizer, let feed, engine?.isRunning == true else { return }
        holdRestarts += 1
        task?.cancel()
        task = nil
        let next = takeRequest()
        // Just the press window, to cover the swap: a longer replay would re-hear the end of
        // the last segment, and letters have no parser to drop a repeat.
        feed.swap(to: next, replay: Self.pressReplay)?.endAudio()
        startRecognition(recognizer, request: next, session: id)
    }

    // MARK: - Session lifecycle

    @discardableResult
    private func resetSession() -> Int {
        session += 1
        segment += 1
        delivered = false
        releasing = false
        releaseTimer?.cancel()
        releaseTimer = nil
        holdSegments = []
        holdPartial = ""
        transcript = HoldTranscript()
        holdRestarts = 0
        // A new hold's first words show at once, not held back by the last hold's throttle.
        shownAt = nil
        pendingShown = nil
        showFlush?.cancel()
        showFlush = nil
        task?.cancel()
        task = nil
        // The microphone stays warm between holds and prompts; only the request goes. The
        // feed hands back the request only if it still had it; if a release already ended it,
        // it must not be ended again here.
        if let feed {
            feed.swap(to: nil, replay: 0)?.endAudio()
        } else {
            request?.endAudio()
        }
        request = nil
        return session
    }

    /// Stops the engine and removes the tap. The tap closure is the feed's last owner.
    private func shutDownAudio() {
        spareRequest = nil
        feed?.clearReplay()
        feed = nil
        if let engine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        engine = nil
    }

    /// Checks permissions and starts the microphone with no request, filling only the replay
    /// buffer. If the key went down meanwhile, opens the hold's request.
    ///
    /// An engine that exists but is no longer running (AVAudioEngine stops itself on an audio
    /// device change such as a headset connecting) is torn down and recreated rather than
    /// restarted with `start()`, because the input format may have changed and the tap must be
    /// installed in the current one. This path is not unit-testable without audio hardware.
    private func warmUp(_ id: Int) async {
        // Not tied to the session: a hold that ends meanwhile should still leave the
        // microphone warm for the next press.
        guard let recognizer = await prepare() else { return }
        if let engine, !engine.isRunning {
            trace("engine stopped: restarting")
            shutDownAudio()
        }
        if engine == nil {
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                state = .unavailable(.noMicrophone)
                return
            }
            let feed = AudioFeed(nil)
            Self.installTap(on: input, format: format, feeding: feed)
            let starting = ContinuousClock.now
            engine.prepare()
            do {
                try engine.start()
            } catch {
                input.removeTap(onBus: 0)
                trace("engine start failed: \(error.localizedDescription)")
                state = .unavailable(.engineFailed)
                return
            }
            self.engine = engine
            self.feed = feed
            trace("microphone warm: engine start=\(VoiceTiming.ms(.now - starting)) ms format=\(format.sampleRate) Hz x\(format.channelCount)")
        }
        prepareSpareRequest()
        guard id == session, holdActive, request == nil, recognizer.isAvailable else { return }
        openHoldRequest(session: id)
    }

    /// Starts recognition for a press on the running engine, replaying the audio from just
    /// before the press so its first syllable is heard.
    private func openHoldRequest(session id: Int) {
        guard let recognizer, let feed, engine?.isRunning == true else { return }
        let next = takeRequest()
        feed.swap(to: next, replay: Self.pressReplay)
        startRecognition(recognizer, request: next, session: id)
    }

    /// The spare request if there is one, else a new one.
    private func takeRequest() -> SFSpeechAudioBufferRecognitionRequest {
        defer { spareRequest = nil }
        if let spare = spareRequest {
            // Still settable: the task has not started, so a change since it was prepared lands now.
            spare.contextualStrings = contextualStrings
            return spare
        }
        return Self.makeRequest(contextualStrings: contextualStrings)
    }

    /// Makes the next press's request now, while nothing is waiting on it.
    private func prepareSpareRequest() {
        guard spareRequest == nil, engine != nil else { return }
        spareRequest = Self.makeRequest(contextualStrings: contextualStrings)
    }

    /// Checks permissions and on-device recognition; nil (with the reason in `state`) when
    /// voice cannot work or is no longer wanted.
    private func prepare() async -> SFSpeechRecognizer? {
        guard await authorize() else { return nil }
        guard wanted else { return nil }
        trace("prepare: recognizer=\(recognizer != nil) onDevice=\(recognizer?.supportsOnDeviceRecognition ?? false) available=\(recognizer?.isAvailable ?? false)")
        // A Mac without the on-device English model, or whose recognizer is not available,
        // says where to get it instead of a bare "stopped".
        guard let recognizer, recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else {
            trace("voice unavailable: on-device recognition missing")
            state = .unavailable(.notOnDevice)
            return nil
        }
        return recognizer
    }

    /// Checks both permissions, asking for any not yet decided. Sets `.denied` on refusal.
    private func authorize() async -> Bool {
        var speech = SFSpeechRecognizer.authorizationStatus()
        var asked = false
        var granted = false
        defer { if asked { onPermissionAnswered?(granted) } }
        if speech == .notDetermined {
            asked = true
            speech = await Self.requestSpeechAuthorization()
        }
        guard speech == .authorized else {
            trace("authorization: speech=\(speech.rawValue) (denied)")
            state = .denied
            return false
        }
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let mic: Bool
        switch micStatus {
        case .authorized: mic = true
        case .notDetermined:
            asked = true
            mic = await AVCaptureDevice.requestAccess(for: .audio)
        default: mic = false
        }
        guard mic else {
            trace("authorization: speech=authorized microphone=\(micStatus.rawValue) (denied)")
            state = .denied
            return false
        }
        granted = true
        return true
    }

    /// Runs `request` through the recognizer as the current segment of session `id`.
    private func startRecognition(_ recognizer: SFSpeechRecognizer, request: SFSpeechAudioBufferRecognitionRequest, session id: Int) {
        segment += 1
        let seg = segment
        self.request = request
        // The words of this hold's earlier segments; fixed while this request runs.
        let prior = holdSegments
        task = Self.recognize(with: recognizer, request: request, prior: prior) { [weak self] event, firedAt in
            // The main queue runs these in the order the recognition queue sent them.
            DispatchQueue.main.async { self?.handle(event, firedAt: firedAt, session: id, segment: seg) }
        }
        if timing.requestStartedAt == nil { timing.requestStartedAt = .now }
    }

    // MARK: - Results

    private enum Event: Sendable {
        /// `words` is this request's transcript; `joined` is the whole hold so far (earlier
        /// segments, then these words), joined on the recognition queue.
        case transcript(words: String, joined: String, isFinal: Bool)
        /// The request stopped on its own with the recognizer's error.
        case ended(SpeechFailure)
    }

    /// The recognizer's normal end for a request that heard no speech; not a failure.
    private static func isNoSpeech(_ failure: SpeechFailure) -> Bool {
        failure.domain == "kAFAssistantErrorDomain" && failure.code == 1110
    }

    private func handle(_ event: Event, firedAt: ContinuousClock.Instant, session id: Int, segment seg: Int) {
        let current = id == session && seg == segment && wanted && !delivered
        if case let .ended(failure) = event {
            // Every ended request is logged, including stale ones the guard below drops.
            trace("request \(seg) ended\(current ? "" : " (stale)"): error domain=\(failure.domain) code=\(failure.code) description=\"\(failure.description)\"")
        }
        guard current else {
            if releasing { trace("ignored a result for request \(seg) (released request \(segment))") }
            return
        }
        guard holdActive || releasing else { return }
        switch event {
        case let .transcript(words, joined, isFinal):
            timing.noteResult(firedAt: firedAt, hasWords: !words.isEmpty)
            if isFinal, releasing { timing.finalAt = .now }
            trace("hold result request=\(seg) isFinal=\(isFinal) transcript=\"\(words)\" releasing=\(releasing)")
            holdPartial = words
            let outcome = transcript.heard(joined, isFinal: isFinal, segment: seg)
            if releasing {
                // The indicator shows the words so far until the text is decided.
                apply(outcome)
                return
            }
            if !joined.isEmpty { show(joined, now: isFinal) }
            guard isFinal else { return }
            holdSegments.append(words)
            holdPartial = ""
            continueHold(session: id)
        case let .ended(failure):
            if !Self.isNoSpeech(failure) { onFailure?(failure) }
            if releasing {
                apply(transcript.ended(segment: seg))
                return
            }
            if !holdPartial.isEmpty {
                holdSegments.append(holdPartial)
                holdPartial = ""
            }
            continueHold(session: id)
        }
    }

    /// Shows the words heard so far, at most once per `indicatorInterval`: words arriving
    /// sooner wait for the next slot, and only the newest are shown. `now` skips the wait (a
    /// final result). A reset drops the waiting words.
    private func show(_ text: String, now immediate: Bool) {
        let now = ContinuousClock.now
        if !immediate, let last = shownAt, now - last < Self.indicatorInterval {
            pendingShown = text
            guard showFlush == nil else { return }
            let id = session
            showFlush = Task { [weak self] in
                try? await Task.sleep(until: last + Self.indicatorInterval, clock: .continuous)
                guard !Task.isCancelled, let self, id == self.session else { return }
                self.showFlush = nil
                if let text = self.pendingShown { self.setShown(text) }
            }
            return
        }
        showFlush?.cancel()
        showFlush = nil
        setShown(text)
    }

    private func setShown(_ text: String) {
        pendingShown = nil
        shownAt = .now
        // Assigning an equal value would still notify observers.
        if partialTranscript != text { partialTranscript = text }
    }

    /// Writes to the voice log when it is on and, in Debug builds, to the unified log. The
    /// message is only built when one of them will take it.
    private func trace(_ message: @autoclosure () -> String) {
        #if DEBUG
        let text = message()
        VoiceTiming.logger.debug("\(text, privacy: .public)")
        VoiceLog.shared.write(text)
        #else
        VoiceLog.shared.write(message())
        #endif
    }

    // MARK: - Off-main callbacks
    //
    // These run on the audio and recognition threads, so they are built outside the main
    // actor and only send plain values back to it.

    nonisolated private static func makeRequest(contextualStrings: [String]) -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = false
        request.contextualStrings = contextualStrings
        return request
    }

    /// Feeds the microphone to `feed`. The tap closure runs on the audio thread and does all
    /// its work there (see `AudioFeed`); it never hops to the main actor.
    nonisolated private static func installTap(on input: AVAudioInputNode, format: AVAudioFormat, feeding feed: AudioFeed) {
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, when in
            feed.append(buffer, at: when)
        }
    }

    /// Runs on `SharedRecognizer.recognitionQueue`: joins each result there and passes only plain values on.
    nonisolated private static func recognize(
        with recognizer: SFSpeechRecognizer, request: SFSpeechAudioBufferRecognitionRequest, prior: [String],
        onEvent: @escaping @Sendable (Event, ContinuousClock.Instant) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            if let result {
                let firedAt = ContinuousClock.now
                let words = result.bestTranscription.formattedString
                let joined = (prior + [words]).filter { !$0.isEmpty }.joined(separator: " ")
                onEvent(.transcript(words: words, joined: joined, isFinal: result.isFinal), firedAt)
                if result.isFinal { return }
            }
            if let error { onEvent(.ended(SharedRecognizer.failure(error)), .now) }
        }
    }

    nonisolated private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }
}
