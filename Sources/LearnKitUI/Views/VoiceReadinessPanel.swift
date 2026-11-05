import AVFoundation
import AppKit
import LearnKit
import SwiftUI

/// The setup panel on the practice screen when voice cannot work on this Mac: what to turn on,
/// a button that opens the right System Settings pane, and "Check again". Typing is unaffected.
/// Shown for any readiness other than `.ready`, in both voice modes.
public struct VoiceReadinessPanel: View {
    /// The panel's strings; the defaults are Mathy Math's.
    public struct Copy: Sendable {
        public var needsDictation = "To talk your answers, turn on Dictation: System Settings > Keyboard > Dictation, choose English, let it download. Typing works meanwhile."
        public var needsPermission = "Voice is off in System Settings. Typing works!"
        public var unavailable = "Voice can't start on this Mac. Typing works!"
        public var openSystemSettings = "Open System Settings"
        public var openPrivacySettings = "Open Privacy settings"
        public var checkAgain = "Check again"
        public var checking = "Checking..."
        public init() {}
    }

    public let readiness: VoiceReadiness
    public let checking: Bool
    public let copy: Copy
    public let checkAgain: () -> Void
    @Environment(\.palette) private var palette

    public init(readiness: VoiceReadiness, checking: Bool, copy: Copy = Copy(), checkAgain: @escaping () -> Void) {
        self.readiness = readiness
        self.checking = checking
        self.copy = copy
        self.checkAgain = checkAgain
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "mic.slash")
                    .foregroundStyle(palette.accentDark)
                VStack(alignment: .leading, spacing: 4) {
                    Text(message)
                        .fixedSize(horizontal: false, vertical: true)
                    if case let .unavailable(error) = readiness {
                        Text(error)
                            .font(palette.rounded(12, weight: .regular))
                            .foregroundStyle(palette.muted)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }
            }
            .font(palette.rounded(16, weight: .medium))
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                if let settings = settingsButton {
                    Button(settings.title, action: settings.open)
                        .buttonStyle(PanelButtonStyle(prominent: true))
                }
                Button(checking ? copy.checking : copy.checkAgain, action: checkAgain)
                    .buttonStyle(PanelButtonStyle(prominent: settingsButton == nil))
                    .disabled(checking)
            }
            // The hidden answer field keeps the keyboard; space must never press these.
            .focusable(false)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 28)
        }
        .padding(16)
        .frame(width: 520)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.sand.opacity(0.6)))
        .accessibilityElement(children: .contain)
    }

    private var message: String {
        switch readiness {
        case .ready: ""
        case .needsDictation: copy.needsDictation
        case .needsPermission: copy.needsPermission
        case .unavailable: copy.unavailable
        }
    }

    private var settingsButton: (title: String, open: () -> Void)? {
        switch readiness {
        case .needsDictation: (copy.openSystemSettings, { SystemSettings.openDictation() })
        case .needsPermission: (copy.openPrivacySettings, { SystemSettings.openPrivacy() })
        case .ready, .unavailable: nil
        }
    }
}

/// Opens System Settings panes by URL. The pane identifiers change across macOS versions, so
/// each tries the specific pane, then its parent, then System Settings itself.
@MainActor public enum SystemSettings {
    public static func openDictation() {
        open([
            "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Dictation",
            "x-apple.systempreferences:com.apple.Keyboard-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.keyboard?Dictation",
        ], what: "Dictation")
    }

    /// The Microphone list when the microphone was refused, else Speech Recognition.
    public static func openPrivacy() {
        let anchor = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            ? "Privacy_SpeechRecognition" : "Privacy_Microphone"
        open([
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(anchor)",
            "x-apple.systempreferences:com.apple.preference.security?\(anchor)",
        ], what: "Privacy \(anchor)")
    }

    private static func open(_ candidates: [String], what: String) {
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                VoiceLog.shared.write("opened System Settings (\(what)): \(candidate)")
                return
            }
        }
        // None of the pane URLs opened: open System Settings at its start page.
        let app = URL(filePath: "/System/Applications/System Settings.app")
        NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
        VoiceLog.shared.write("opened System Settings (\(what)): pane URLs failed, opened the app")
    }
}

/// A small rounded button for the panel: accent fill when prominent, outlined otherwise.
private struct PanelButtonStyle: ButtonStyle {
    let prominent: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.palette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(palette.rounded(15, weight: .semibold))
            .foregroundStyle(prominent ? .white : palette.accentDark)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background {
                if prominent {
                    Capsule().fill(palette.accent)
                } else {
                    // An outline from two fills: renders the same in the window and in snapshots.
                    Capsule().fill(palette.accent)
                    Capsule().fill(palette.cream).padding(2)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.5)
            .contentShape(Capsule())
    }
}
