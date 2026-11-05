import AVFoundation
import os
import Speech

/// Carries microphone buffers from the audio tap to the current recognition request.
///
/// All per-buffer work happens on the audio tap's thread inside `append`: the loudness check,
/// keeping a copy for replay, replaying into a newly swapped-in request, and
/// `SFSpeechAudioBufferRecognitionRequest.append` (which is designed to be called from a tap).
/// Nothing in here touches the main actor, and nothing posts to it per buffer: the main actor
/// reads `lastVoicedAt` when it needs it and changes the request with `swap` or `release`.
///
/// Locking (`@unchecked Sendable` rests on these):
/// - `lock` guards `request`, `pendingReplay`, `recent`, `recentStarts`, `recentFrames`,
///   `ringValidFrom`, `replayed`, `appended` and `appendedStarts`. It is held only for bounded work: one `request.append`, a ring update,
///   or one replay of at most `maxReplay` seconds. A replay calls `request.append` once per
///   replayed buffer under the lock, so the main actor in `swap` can wait for one bounded
///   replay running on the tap thread, and the tap thread can wait for one bounded replay that
///   `swap` runs on the main actor. Nobody waits for audio while holding it, so neither side
///   ever waits for the next buffer, and nothing is called back while it is held.
/// - `voiced` guards only the last voiced instant. It is never held while `lock` is held, or
///   while doing anything else, so reading it from the main actor cannot stall.
///
/// Invariants, under `lock`:
/// - Once `swap` or `release` returns, the request it detached never receives another buffer,
///   so the caller may call `endAudio()` on it, and is the only party that does.
/// - A request swapped in with a replay receives the replayed audio before any live buffer.
/// - `recent` holds at most `maxReplay` seconds plus one buffer, oldest first, with each
///   buffer's capture start in `recentStarts` at the same index; after `release` it holds
///   nothing from before the release.
/// - A replay never includes a buffer that began before `ringValidFrom`.
/// - `appended` and `appendedStarts` describe the live buffers of the current request only.
public final class AudioFeed: @unchecked Sendable {
    /// Seconds of recent audio kept for replay.
    public static let maxReplay: Double = 0.6
    /// Buffer RMS above this counts as voiced audio.
    public static let voicedRMS: Float = 0.01
    /// Capture start times kept for the current request, newest last; enough to cover any
    /// delay between the key coming up and the main thread handling it.
    public static let keptStarts = 64

    /// What `release` detached.
    public struct Released {
        public let request: SFSpeechAudioBufferRecognitionRequest?
        /// Live buffers the request received.
        public let appended: Int
        /// Of those, buffers whose audio began at or after the release cutoff: audio captured
        /// after the key came up that reached the request before the main thread detached it.
        public let appendedAfterCutoff: Int
        /// Seconds of ring audio replayed into this hold's requests (the pre-roll and any
        /// replay into a request rolled during the hold).
        public let replayed: Double
    }

    private let lock = NSLock()
    /// Nil while hold-to-talk waits for a press: the tap then only fills the replay ring.
    private var request: SFSpeechAudioBufferRecognitionRequest?
    /// Seconds of `recent` still to be replayed into `request` before the next live buffer.
    private var pendingReplay: Double = 0
    private var recent: [AVAudioPCMBuffer] = []
    /// System-uptime capture start of each buffer in `recent`.
    private var recentStarts: [TimeInterval] = []
    private var recentFrames: AVAudioFrameCount = 0
    /// Ring audio that began before this instant is never replayed (see `invalidateRing`).
    private var ringValidFrom: TimeInterval = 0
    /// Seconds replayed since the current chain of requests began (reset when a request is
    /// swapped in with none before it, and by `release`).
    private var replayed: Double = 0
    private var appended = 0
    /// System-uptime seconds at which each of the request's newest live buffers began.
    private var appendedStarts: [TimeInterval] = []

    private let voiced = OSAllocatedUnfairLock<ContinuousClock.Instant?>(initialState: nil)

    public init(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        self.request = request
    }

    /// When the tap last heard a voiced buffer; nil if it has not yet.
    public var lastVoicedAt: ContinuousClock.Instant? {
        voiced.withLock { $0 }
    }

    /// Audio tap thread only. `when` is the tap's time for the buffer's first sample.
    public func append(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime) {
        // Work that needs no shared state happens before taking the lock.
        if Self.rms(of: buffer) > Self.voicedRMS {
            let now = ContinuousClock.now
            voiced.withLock { $0 = now }
        }
        let start = Self.uptime(of: when, frames: buffer.frameLength, rate: buffer.format.sampleRate)
        // The tap may reuse its buffer after this callback, so the ring keeps a copy.
        let copy = Self.copy(buffer)
        lock.withLock {
            if let request {
                if pendingReplay > 0 {
                    replay(pendingReplay, into: request)
                    pendingReplay = 0
                }
                request.append(buffer)
                appended += 1
                appendedStarts.append(start)
                if appendedStarts.count > Self.keptStarts { appendedStarts.removeFirst() }
            }
            keep(copy, start: start)
        }
    }

    /// Adds `copy` to the replay ring and trims it to `maxReplay`. Caller holds `lock`.
    private func keep(_ copy: AVAudioPCMBuffer?, start: TimeInterval) {
        guard let copy else { return }
        recent.append(copy)
        recentStarts.append(start)
        recentFrames += copy.frameLength
        let window = AVAudioFrameCount(copy.format.sampleRate * Self.maxReplay)
        while let first = recent.first, recentFrames - first.frameLength >= window {
            recentFrames -= first.frameLength
            recent.removeFirst()
            recentStarts.removeFirst()
        }
    }

    /// Points the tap at `request` (nil: no request) and returns the request it replaced. The
    /// most recent `seconds` of audio (at most `maxReplay`) are replayed into the new request on
    /// the audio thread, just before the next live buffer.
    @discardableResult
    public func swap(to request: SFSpeechAudioBufferRecognitionRequest?, replay seconds: Double) -> SFSpeechAudioBufferRecognitionRequest? {
        lock.withLock {
            let old = self.request
            // Swapped away before a single live buffer arrived: the old request still gets
            // its replay, so a very short hold is not left with no audio at all.
            flushPendingReplay(into: old)
            if old == nil { replayed = 0 }
            self.request = request
            pendingReplay = request == nil ? 0 : min(max(seconds, 0), Self.maxReplay)
            appended = 0
            appendedStarts = []
            return old
        }
    }

    /// Hold-to-talk release: detaches the current request at once, with no tail, and empties
    /// the replay ring so nothing heard up to now can be replayed into a later request. The
    /// next buffer reaches no request. `cutoff` is the system-uptime instant the key came up;
    /// the result counts the buffers that began after it yet reached the request.
    public func release(cutoff: TimeInterval) -> Released {
        lock.withLock {
            let old = request
            // Released before a single live buffer arrived: the replay is from before the
            // press, so it still belongs to this hold.
            flushPendingReplay(into: old)
            let late = appendedStarts.reduce(0) { $1 >= cutoff ? $0 + 1 : $0 }
            let released = Released(request: old, appended: appended, appendedAfterCutoff: late, replayed: replayed)
            request = nil
            pendingReplay = 0
            replayed = 0
            appended = 0
            appendedStarts = []
            dropReplay()
            return released
        }
    }

    public func clearReplay() {
        lock.withLock {
            dropReplay()
            pendingReplay = 0
        }
    }

    /// No ring audio that began before `instant` (system uptime) will be replayed. Called when
    /// a hold's answer is decided, so speech after a release cannot be pre-rolled into a quick
    /// re-press; a buffer still in flight on the tap thread is excluded by its capture time.
    public func invalidateRing(before instant: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        lock.withLock { ringValidFrom = max(ringValidFrom, instant) }
    }

    /// Empties the replay ring. Caller holds `lock`.
    private func dropReplay() {
        recent.removeAll()
        recentStarts.removeAll()
        recentFrames = 0
    }

    /// Replays the audio still owed to `old` (the request being detached), if any. Caller holds `lock`.
    private func flushPendingReplay(into old: SFSpeechAudioBufferRecognitionRequest?) {
        if let old, pendingReplay > 0 { replay(pendingReplay, into: old) }
    }

    /// Appends the newest buffers covering `seconds` to `request`, oldest first. Caller holds `lock`.
    /// Buffers that began before `ringValidFrom` are left out. Caller holds `lock`.
    private func replay(_ seconds: Double, into request: SFSpeechAudioBufferRecognitionRequest) {
        guard let format = recent.last?.format else { return }
        let wanted = AVAudioFrameCount(format.sampleRate * seconds)
        var frames: AVAudioFrameCount = 0
        var start = recent.endIndex
        while start > recent.startIndex, frames < wanted, recentStarts[start - 1] >= ringValidFrom {
            start -= 1
            frames += recent[start].frameLength
        }
        for buffer in recent[start...] { request.append(buffer) }
        replayed += Double(frames) / format.sampleRate
    }

    /// The system-uptime second (the clock of `NSEvent.timestamp`) at which the buffer's audio
    /// began: from the host time when the tap provides one, else from now less its length.
    private static func uptime(of when: AVAudioTime, frames: AVAudioFrameCount, rate: Double) -> TimeInterval {
        if when.isHostTimeValid { return AVAudioTime.seconds(forHostTime: when.hostTime) }
        let length = rate > 0 ? Double(frames) / rate : 0
        return ProcessInfo.processInfo.systemUptime - length
    }

    /// Root mean square of the first channel, 0 when the buffer has no float samples.
    private static func rms(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let samples = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return (sumOfSquares / Float(samples.count)).squareRoot()
    }

    private static func copy(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard buffer.frameLength > 0,
              let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { return nil }
        copy.frameLength = buffer.frameLength
        let source = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: buffer.audioBufferList))
        let target = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for (from, to) in zip(source, target) {
            guard let bytes = from.mData, let into = to.mData else { continue }
            memcpy(into, bytes, Int(min(from.mDataByteSize, to.mDataByteSize)))
        }
        return copy
    }
}
