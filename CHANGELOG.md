# Changelog

All notable changes to LearnKit. Versions are git tags (`0.1.0`, `0.1.1`, ...) and follow
semantic versioning; while the major version is 0, a minor bump may change public API.

## 0.2.0

Brings LearnKit level with Mathy Math 0.2.6 so Mathy Math can migrate. Source-compatible
with 0.1.0 callers: Spelly Spell builds and tests unchanged.

### Added

- Flame-tier day marks: `Streak.DayMark` gains `.flame` (a day that reached the goal) and
  `.doubled` (twice the goal). `Streak.strip(practiceDays:halfDays:fullDays:today:length:)`
  takes the two flame sets as defaulted arguments, so `strip(practiceDays:today:)` is
  unchanged. `DayStripView` draws one or two flame glyphs on those days.
- `VoicedTime` in `LearnKit`: voiced time that counts speech with its small gaps and never
  counts silence.

### Changed

- `AudioFeed` tracks voiced time: `voicedTotal` sits next to `lastVoicedAt`, both read from one
  `VoicedTime` under the same lock.
- `Streak.DayMark` has two more cases, so an exhaustive `switch` over it must handle
  `.flame` and `.doubled`. Spelly Spell has none.

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

### Included fixes

- A stopped audio engine (for example after a device change) is torn down and recreated on
  warm-up instead of staying dead.
- `contextualStrings` now apply to the spare recognition request.
- `Rays` no longer traps when given no colors.
- `Speaker` stop is unconditional.
- `SoundPlayer` logs a cue that fails to load once and stops retrying.
