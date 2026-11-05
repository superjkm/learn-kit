# LearnKit

Shared Swift package for Jocelyn's kids' learning apps (Mathy Math, Spelly Spell).

- `LearnKit`: pure, Sendable, tested. FSRS scheduling, cards, streak and flame, practice days, celebrations, progress store, voice readiness and log file.
- `LearnKitUI`: SwiftUI/AppKit/Speech/AVFoundation. Flame and day strip views, celebration overlay, sounds, spacebar hold-to-talk transcriber, shared speech recognizer, text-to-speech `Speaker`, voice readiness panel.

Requirements: macOS 14, Xcode 26, Swift 6.

Test: `swift test`  ·  Build the UI product: `swift build --product LearnKitUI`

Apps depend on this package by URL (`https://github.com/superjkm/learn-kit.git`, branch `main`) and pin a revision in their `Package.resolved`.

Design: see `spelly-spell/docs/superpowers/specs/2026-11-05-spelly-spell-design.md`, section 4.
