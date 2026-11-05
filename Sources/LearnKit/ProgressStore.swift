import Foundation

public enum ProgressStoreError: Error, Equatable {
    /// The file was written by a newer app version; it is left untouched.
    case newerVersion(Int)
}

/// Loads and saves one progress file: atomic writes, refusal of a newer version's file, and a
/// corrupt file moved aside (never deleted) so a fresh start never overwrites intact data.
public struct ProgressStore<P: Versioned>: Sendable {
    /// Reads only the top-level `version` key (see `Versioned`). Missing reads as nil.
    private struct VersionPeek: Decodable {
        let version: Int?
    }

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `~/Library/Application Support/<appFolder>/progress.json`.
    public static func defaultURL(appFolder: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: appFolder)
            .appending(path: "progress.json")
    }

    public func load() throws -> P {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return P() }
        let data = try Data(contentsOf: url)
        do {
            let decoder = JSONDecoder()
            if let version = try decoder.decode(VersionPeek.self, from: data).version,
               version > P.currentVersion {
                throw ProgressStoreError.newerVersion(version)
            }
            return try decoder.decode(P.self, from: data)
        } catch is DecodingError {
            let aside = url.deletingLastPathComponent()
                .appending(path: "\(url.lastPathComponent).corrupt-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString)")
            try fm.moveItem(at: url, to: aside)
            return P()
        }
    }

    public func save(_ progress: P) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(progress).write(to: url, options: .atomic)
    }
}
