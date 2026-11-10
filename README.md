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
.package(url: "https://github.com/superjkm/learn-kit.git", from: "0.1.0")
// target dependencies
.product(name: "LearnKit", package: "learn-kit"),
.product(name: "LearnKitUI", package: "learn-kit"),
```

Apps pin a released version (`from: "0.1.0"`), not `branch: "main"`, so a change here reaches an
app only when it raises its version and re-resolves. See `CHANGELOG.md` for what each version holds.

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
Call `start()` when a prompt is up and `stop(keepingMicrophone: true)` when it is covered (sheet, summary); `stop(keepingMicrophone: false)` when leaving practice; `retry()` after `.unavailable` or `.denied`. Nothing is delivered before `start()`.
The voice log is opt-in (`VoiceLog.shared.setEnabled(_:mode:)`) and lands in
`~/Library/Logs/<logFolder>/voice.log`.

## Test and build

```sh
swift test
swift build
```

## Releasing

1. Merge the change to `main` and make sure `swift build` and `swift test` pass.
2. Add a `CHANGELOG.md` entry for the new version. Use a patch bump for fixes and a minor bump
   for new API (while the major version is 0, a minor bump may also break API).
3. Tag the merge commit and push the tag:

   ```sh
   git tag -a 0.1.1 -m 'LearnKit 0.1.1' <merge sha>
   git push origin 0.1.1
   ```

4. In each app, raise `from:` in its `Package.swift` or `project.yml`, re-resolve packages and
   commit `Package.resolved`.

## Lessons carried over from Mathy Math

- Recognizer result handlers run on `SharedRecognizer.recognitionQueue`, never the main queue.
- A hold's request is detached at key-up, so the next buffer reaches no request, with no tail, and only that
  request's results decide the text.
- Every ended recognition request is logged with its error domain, code and description.
  `kAFAssistantErrorDomain 1110` ("No speech detected") means the recognizer is ready.
- The audio engine keeps running between holds; the tap fills a 0.6 s ring and a press replays
  0.15 s into the new request.
- Speech and AVFoundation callback closures are built in `nonisolated static` funcs.
