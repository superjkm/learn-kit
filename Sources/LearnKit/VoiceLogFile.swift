import Foundation

/// A plain-text log file that rotates once it reaches `maxBytes`: the full file becomes
/// `rotatedURL` (replacing any older one) and a new file starts. Holds no open handle, so it can
/// be used from any one serial queue; it is not safe to append from two threads at once.
public struct VoiceLogFile: Sendable {
    public static let defaultMaxBytes = 1_000_000

    public let url: URL
    public let maxBytes: Int

    public init(url: URL, maxBytes: Int = Self.defaultMaxBytes) {
        self.url = url
        self.maxBytes = maxBytes
    }

    /// `voice.log` -> `voice.1.log`, in the same directory.
    public var rotatedURL: URL {
        let name = url.deletingPathExtension().lastPathComponent + ".1"
        let ext = url.pathExtension
        return url.deletingLastPathComponent().appendingPathComponent(ext.isEmpty ? name : "\(name).\(ext)")
    }

    /// Appends `line` and a newline, rotating first if the line would take the file past `maxBytes`.
    public func append(_ line: String) throws {
        let data = Data((line + "\n").utf8)
        let manager = FileManager.default
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let size = (try? manager.attributesOfItem(atPath: url.path)[.size] as? Int) ?? nil
        if let size, size > 0, size + data.count > maxBytes {
            try? manager.removeItem(at: rotatedURL)
            try manager.moveItem(at: url, to: rotatedURL)
        }
        if manager.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: url)
        }
    }
}
