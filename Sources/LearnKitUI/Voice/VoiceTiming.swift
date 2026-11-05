import Foundation
import os

/// Timing for the hold-to-talk pipeline. One `timing` line is written per hold to the voice
/// log (`VoiceLog`, opt-in, Release too) and, in Debug builds, to the unified log:
/// `log stream --level debug --predicate 'subsystem == "<bundleID>" AND category == "Voice"'`.
///
/// The line has milliseconds from the press (or the release) to each step: the recognition
/// request starting, the first words, the release, the final result's arrival, the answer
/// decided and how (`path`), the parse, and the grade; and `afterRelease`, the microphone
/// buffers that began after the key came up yet reached the request (must be 0).
/// `latestWordsAge` is how old the newest words were at the release. The main-thread stall
/// watchdog runs in Debug builds only.
public enum VoiceTiming {
    #if DEBUG
    /// Read from `AppIdentity.current` on first use.
    public static let logger = Logger(subsystem: AppIdentity.current.bundleID, category: "Voice")
    #endif

    public static func ms(_ duration: Duration) -> String {
        let (seconds, attoseconds) = duration.components
        let value = Double(seconds) * 1000 + Double(attoseconds) / 1e15
        return String(format: "%.1f", value)
    }

    public static func ms(from start: ContinuousClock.Instant?, to end: ContinuousClock.Instant?) -> String {
        guard let start, let end else { return "-" }
        return ms(end - start)
    }
}

/// The instants of one hold, all on the main actor. Reset at each press.
public struct HoldTiming {
    public var pressedAt: ContinuousClock.Instant?
    public var requestStartedAt: ContinuousClock.Instant?
    /// When the recognizer produced its first words, on its own thread.
    public var firstWordsFiredAt: ContinuousClock.Instant?
    /// When the main actor handled those first words.
    public var firstWordsHandledAt: ContinuousClock.Instant?
    public var releasedAt: ContinuousClock.Instant?
    /// When the released request's final result reached the main actor.
    public var finalAt: ContinuousClock.Instant?
    /// Live buffers the released request received, and those that began after the key-up.
    public var buffers: Int?
    public var afterRelease: Int?
    /// Seconds of ring audio replayed into the hold (pre-roll included).
    public var replayed: Double?
    public var chosenAt: ContinuousClock.Instant?
    public var path = "-"
    public var parse: Duration?
    public var submittedAt: ContinuousClock.Instant?
    /// Longest gap between the recognizer producing a result and the main actor handling it.
    public var maxHop: Duration = .zero
    /// When the main actor handled the latest result of this hold.
    public var lastResultHandledAt: ContinuousClock.Instant?

    public init(pressedAt: ContinuousClock.Instant? = nil) {
        self.pressedAt = pressedAt
    }

    public mutating func noteResult(firedAt: ContinuousClock.Instant, hasWords: Bool) {
        let now = ContinuousClock.now
        maxHop = max(maxHop, now - firedAt)
        lastResultHandledAt = now
        if hasWords, firstWordsFiredAt == nil {
            firstWordsFiredAt = firedAt
            firstWordsHandledAt = now
        }
    }

    public func summary(maxStall: Duration?, stalls: Int?) -> String {
        let t = VoiceTiming.self
        let stallText = maxStall.map { " mainStalls>50ms=\(stalls ?? 0) maxMainStall=\(t.ms($0))" } ?? ""
        return "timing press->request=\(t.ms(from: pressedAt, to: requestStartedAt))"
            + " press->firstWords=\(t.ms(from: pressedAt, to: firstWordsFiredAt))"
            + " firstWordsHop=\(t.ms(from: firstWordsFiredAt, to: firstWordsHandledAt))"
            + " maxResultHop=\(t.ms(maxHop))"
            + " press->release=\(t.ms(from: pressedAt, to: releasedAt))"
            + " latestWordsAge=\(t.ms(from: lastResultHandledAt, to: releasedAt))"
            + " release->final=\(t.ms(from: releasedAt, to: finalAt))"
            + " release->chosen=\(t.ms(from: releasedAt, to: chosenAt)) path=\(path)"
            + " parse=\(parse.map { t.ms($0) } ?? "-")"
            + " release->grade=\(t.ms(from: releasedAt, to: submittedAt))"
            + " buffers=\(buffers.map(String.init) ?? "-") afterRelease=\(afterRelease.map(String.init) ?? "-")"
            + " replayed=\(replayed.map { String(format: "%.3f", $0) } ?? "-") s"
            + stallText
    }
}

#if DEBUG
/// Watches the main thread while a hold is in progress and logs every stall over `threshold`:
/// a task on the main actor wakes every `tick`, and any wake-up later than `tick + threshold`
/// means the main thread was busy for that long.
@MainActor public final class MainStallWatchdog {
    public static let tick: Duration = .milliseconds(10)
    public static let threshold: Duration = .milliseconds(50)

    private var task: Task<Void, Never>?
    public private(set) var maxStall: Duration = .zero
    public private(set) var stalls = 0

    public init() {}

    public var isRunning: Bool { task != nil }

    public func start() {
        stop()
        maxStall = .zero
        stalls = 0
        task = Task { @MainActor [weak self] in
            var last = ContinuousClock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tick, tolerance: .milliseconds(1))
                let now = ContinuousClock.now
                let late = now - last - Self.tick
                last = now
                guard let self, !Task.isCancelled else { return }
                if late > self.maxStall { self.maxStall = late }
                if late > Self.threshold {
                    self.stalls += 1
                    VoiceTiming.logger.debug("main stall \(VoiceTiming.ms(late), privacy: .public) ms during hold")
                }
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }
}
#endif
