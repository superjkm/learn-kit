import AppKit

/// Reports the spacebar going down and coming up while installed, for hold-to-talk.
///
/// SwiftUI's key handling does not reliably deliver key-up on macOS 14, so this uses an AppKit
/// local event monitor. Every plain space press is swallowed so it never reaches the hidden
/// answer field (where it would count as typing). Key repeat is ignored: only the first
/// key-down counts. If the app loses focus while the key is down, the key-up never arrives, so
/// losing focus counts as releasing it. A space key-up always ends a press, whatever modifier
/// keys are down by then, so a hold can never outlive the key.
///
/// A press is remembered even when `canBegin` refuses it (feedback still up, the next prompt
/// not ready): call `beginIfHeld()` when the prompt becomes ready and, if the key is still
/// down, `onDown` runs then. A release always runs `onUp` with the instant the key came up
/// (system uptime, the clock of `NSEvent.timestamp`); the listener ignores one that ends nothing.
///
/// `onPress` runs on every first key-down, after the hold check, whether or not a hold began;
/// the practice screen uses it to skip a wrong answer's correction.
@MainActor public final class SpaceKeyMonitor {
    /// Asked on each first key-down and by `beginIfHeld()`; `onDown` runs only when it is true.
    public var canBegin: () -> Bool = { false }
    public var onDown: () -> Void = {}
    public var onUp: (_ releasedAt: TimeInterval) -> Void = { _ in }
    /// Every first key-down, after `canBegin`/`onDown` have had their turn.
    public var onPress: () -> Void = {}

    private var monitor: Any?
    private var resignObserver: NSObjectProtocol?
    /// The spacebar is down, whether or not a hold has begun.
    public private(set) var isDown = false

    private static let spaceKeyCode: UInt16 = 49

    public init() {}

    public func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard event.keyCode == Self.spaceKeyCode else { return event }
            let down = event.type == .keyDown
            let modified = !event.modifierFlags.intersection([.command, .control, .option]).isEmpty
            let held = MainActor.assumeIsolated { self?.isDown ?? false }
            // A modified space press is not ours; its key-up still ends a press already begun.
            if modified, down || !held { return event }
            let timestamp = event.timestamp
            let isRepeat = down && event.isARepeat
            if !isRepeat {
                // How long the key event waited before the main thread got to it.
                let waited = (ProcessInfo.processInfo.systemUptime - timestamp) * 1000
                let line = "space \(down ? "down" : "up") event delay=\(String(format: "%.1f", waited)) ms"
                #if DEBUG
                VoiceTiming.logger.debug("\(line, privacy: .public)")
                #endif
                VoiceLog.shared.write(line)
            }
            // Local monitors run on the main thread; hop onto the main actor synchronously,
            // since swallowing the event has to be decided before returning.
            MainActor.assumeIsolated { self?.handle(down: down, isRepeat: isRepeat, at: timestamp) }
            return nil
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // Delivered on the main queue: release now, so the cutoff is when the app resigned.
            MainActor.assumeIsolated { self?.release() }
        }
    }

    /// Removes the monitor, releasing the key first if it is down.
    public func remove() {
        release()
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
    }

    /// The prompt just became ready: if the key went down earlier and is still down, begin now.
    public func beginIfHeld() {
        guard isDown, canBegin() else { return }
        onDown()
    }

    private func handle(down: Bool, isRepeat: Bool, at timestamp: TimeInterval) {
        if down {
            guard !isRepeat, !isDown else { return }
            isDown = true
            if canBegin() { onDown() }
            onPress()
        } else {
            release(at: timestamp)
        }
    }

    private func release(at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard isDown else { return }
        isDown = false
        onUp(timestamp)
    }
}
