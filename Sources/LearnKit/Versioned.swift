import Foundation

/// An app's root progress type: versioned JSON with a fresh-install default.
///
/// The encoded form MUST carry a top-level integer `version` key. `ProgressStore` reads that key
/// before decoding the whole type, to refuse a file written by a newer build. A file with no
/// `version` key counts as the current version; a `version` that is not an integer makes the
/// file corrupt.
public protocol Versioned: Codable, Sendable {
    /// The version this build writes. A file with a greater version is left untouched.
    static var currentVersion: Int { get }
    /// The fresh-install state.
    init()
}
