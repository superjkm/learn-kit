import os

/// Who the host app is, for the parts of LearnKitUI that name the app: the voice log folder
/// under `~/Library/Logs`, the unified-log subsystem and the private queue names. Install it
/// once at launch, before any voice or sound type is touched; those read `current` on first
/// use and keep what they read.
public struct AppIdentity: Sendable, Equatable {
    public var name: String
    public var bundleID: String
    /// Folder under `~/Library/Logs` for `voice.log`.
    public var logFolder: String

    public init(name: String, bundleID: String, logFolder: String) {
        self.name = name
        self.bundleID = bundleID
        self.logFolder = logFolder
    }

    /// What `current` is until an app installs its own.
    public static let placeholder = AppIdentity(name: "LearnKit", bundleID: "com.lablabs.learnkit", logFolder: "LearnKit")

    private static let installed = OSAllocatedUnfairLock(initialState: AppIdentity.placeholder)

    public static var current: AppIdentity { installed.withLock { $0 } }

    public static func install(_ identity: AppIdentity) {
        installed.withLock { $0 = identity }
    }
}
