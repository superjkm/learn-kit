import Foundation
import LearnKit
import os

/// The opt-in voice log ("Save voice log" in the Sound menu), for diagnosing voice on a Mac an
/// agent cannot reach. Works in Release builds. Lines go to
/// `~/Library/Logs/<AppIdentity.logFolder>/voice.log`, rotated at 1 MB to `voice.1.log`, each
/// stamped with the local time to the millisecond. Nothing is written while it is off.
///
/// What it records: the recognizer's creation, on-device support, availability and
/// authorization; engine start and warm-up durations; and for each hold the press and release
/// (with how long the key event waited), every recognizer result, the answer's path and one
/// `timing` line (see `VoiceTiming`), including the buffers appended after the release.
///
/// Concurrency: `write` may be called from any thread except the audio tap thread (which
/// never logs). The enabled flag sits behind its own lock; file work runs on a private serial
/// queue, so callers never wait for the disk.
public final class VoiceLog: Sendable {
    /// Built from `AppIdentity.current` the first time it is touched: install the identity first.
    public static let shared = VoiceLog(identity: AppIdentity.current)
    /// UserDefaults key for the menu setting.
    public static let defaultsKey = "saveVoiceLog"

    public let file: VoiceLogFile
    private let identity: AppIdentity
    private let enabled = OSAllocatedUnfairLock(initialState: false)
    private let queue: DispatchQueue
    private static let stamp = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current)

    init(identity: AppIdentity) {
        self.identity = identity
        file = VoiceLogFile(url: URL.libraryDirectory.appending(path: "Logs/\(identity.logFolder)/voice.log"))
        queue = DispatchQueue(label: "\(identity.bundleID).voicelog", qos: .utility)
    }

    public var isEnabled: Bool { enabled.withLock { $0 } }

    /// Turns the log on or off; turning it on writes a header describing this Mac and app.
    public func setEnabled(_ on: Bool, mode: VoiceMode) {
        let was = enabled.withLock { old in
            defer { old = on }
            return old
        }
        if on, !was { write(header(mode: mode)) }
        if !on, was { append("voice log off") }
    }

    /// Writes `message` if the log is on; the message is only built when it is.
    public func write(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        append(message())
    }

    private func append(_ message: String) {
        let date = Date()
        let file = file
        queue.async {
            try? file.append("\(Self.stamp.format(date)) \(message)")
        }
    }

    private func header(mode: VoiceMode) -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        #if DEBUG
        let configuration = "Debug"
        #else
        let configuration = "Release"
        #endif
        return "voice log on: \(identity.name) \(version) (\(build), \(configuration)) macOS \(os) model \(Self.hardwareModel()) mode=\(mode.rawValue)"
    }

    /// The Mac's model identifier, such as "Mac16,12".
    private static func hardwareModel() -> String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return "?" }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &bytes, &size, nil, 0) == 0 else { return "?" }
        return String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
