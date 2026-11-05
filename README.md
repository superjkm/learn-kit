# LearnKit

Shared Swift package for the lab's learning apps (Mathy Math, Spelly Spell): everything the
apps have in common so a fix lands once. Two library products, no dependencies.

- `LearnKit`: pure and fully tested. FSRS-5 scheduling (`Grade`, `Memory`, `FSRS`), the 03:00
  practice day (`PracticeDay`), the forgiving streak (`Streak`, `PracticeLog`), per-item
  scheduling state (`Card`, `MasteryLevel`), response-time grading with app-supplied thresholds
  (`ResponseGrading`), celebrations (`Celebration`, `Celebrations`), a versioned JSON store
  (`ProgressStore<P: Versioned>`), voice value types (`VoiceMode`, `VoiceReadiness`,
  `SpeechFailure`, `VoiceProbe`, `VoiceLogFile`), the hold-to-talk decision (`HoldTranscript`)
  and a seeded generator (`SeededRandomNumberGenerator`). Never imports AppKit, SwiftUI,
  Speech or AVFoundation.
- `LearnKitUI`: SwiftUI, AppKit, AVFoundation and Speech. Views (`FlameView`, `DayStripView`,
  `CelebrationOverlay`, `Rays`, `PillButtonStyle`, `VoiceReadinessPanel`), the `Palette`
  protocol and `.palette(_:)` environment, `SoundPlayer` with the four bundled cues,
  `SpaceKeyMonitor`, the voice pipeline (`SharedRecognizer`, `AudioFeed`,
  `HoldToTalkTranscriber`, `VoiceLog`, `VoiceTiming`) and `Speaker`.

## Requirements

macOS 14, Xcode 16 or newer (Swift 6 toolchain), swift-tools 6.0.

## Use

```swift
// Package.swift of the app
.package(url: "https://github.com/superjkm/learn-kit.git", branch: "main")
// target dependencies
.product(name: "LearnKit", package: "learn-kit"),
.product(name: "LearnKitUI", package: "learn-kit"),
```

At launch, before any voice or sound type is touched:

```swift
AppIdentity.install(AppIdentity(name: "Spelly Spell", bundleID: "com.lablabs.spellyspell", logFolder: "SpellySpell"))
```

At the root of the window, with a `Palette` built from the app's asset catalog:

```swift
RootView().palette(SpellyPalette())
```

Progress: declare the app's root type as `Versioned` (`static let currentVersion`, `init()`, and a top-level integer `version` key in its JSON),
embed a `PracticeLog` and a `[String: Card]`, and store it with
`ProgressStore<Progress>(url: ProgressStore<Progress>.defaultURL(appFolder: "SpellySpell"))`.

Voice: `SharedRecognizer.probe(reason:)` at launch and on activation, classified by
`VoiceReadiness.classify`; `HoldToTalkTranscriber(contextualStrings:)` for hold-to-talk with
`SpaceKeyMonitor` driving `beginHold()` / `endHold(keyUpAt:)`; `Speaker` to say prompts.
The voice log is opt-in (`VoiceLog.shared.setEnabled(_:mode:)`) and lands in
`~/Library/Logs/<logFolder>/voice.log`.

## Test and build

```sh
swift test
swift build
```

## Lessons carried over from Mathy Math

- Recognizer result handlers run on `SharedRecognizer.recognitionQueue`, never the main queue.
- A hold's request is closed on the next audio buffer after key-up, with no tail, and only that
  request's results decide the text.
- Every ended recognition request is logged with its error domain, code and description.
  `kAFAssistantErrorDomain 1110` ("No speech detected") means the recognizer is ready.
- The audio engine keeps running between holds; the tap fills a 0.6 s ring and a press replays
  0.15 s into the new request.
- Speech and AVFoundation callback closures are built in `nonisolated static` funcs.
