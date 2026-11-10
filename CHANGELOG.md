# Changelog

All notable changes to LearnKit. Versions are git tags (`0.1.0`, `0.1.1`, ...) and follow
semantic versioning; while the major version is 0, a minor bump may change public API.

## 0.1.0

First tagged release.

### Extracted from Mathy Math

- `LearnKit`: FSRS-5 scheduling, the 03:00 practice day, the forgiving streak and `PracticeLog`,
  `Card` and `MasteryLevel`, `ResponseGrading` with app-supplied thresholds, `Celebration`,
  the generic versioned `ProgressStore`, voice value types, `HoldTranscript`, and the seeded
  random generator.
- `LearnKitUI`: flame, day strip, celebration overlay, pill button, `Palette` environment,
  `SoundPlayer` with four bundled cues, `SpaceKeyMonitor`, the voice pipeline
  (`SharedRecognizer`, `AudioFeed`, `HoldToTalkTranscriber`, `VoiceLog`, `VoiceTiming`,
  `VoiceReadinessPanel`) and `Speaker`.

### Speech

- `Speaker` adds a 0.3 s lead-in so short opening words are not clipped.

### Fixed

- A stopped audio engine (for example after a device change) is torn down and recreated on
  warm-up instead of staying dead.
- `contextualStrings` now apply to the spare recognition request.
- `Rays` no longer traps when given no colors.
- `Speaker` stop is unconditional.
- `SoundPlayer` logs a cue that fails to load once and stops retrying.
