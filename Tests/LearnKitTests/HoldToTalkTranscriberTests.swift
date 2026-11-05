import LearnKit
import Testing
@testable import LearnKitUI

// The transcriber needs a microphone and the on-device recognizer for a real hold; these cover
// what it does with no hardware at all: its resting state, and that nothing is delivered for a
// press, release or cancel while it is not listening.

/// A transcriber with both callbacks recording what they receive.
@MainActor
private final class Harness {
    let transcriber: HoldToTalkTranscriber
    private(set) var finals: [String] = []
    private(set) var failures: [SpeechFailure] = []

    init(contextualStrings: [String] = []) {
        transcriber = HoldToTalkTranscriber(contextualStrings: contextualStrings)
        transcriber.onFinal = { [unowned self] in finals.append($0) }
        transcriber.onFailure = { [unowned self] in failures.append($0) }
    }
}

@MainActor @Test func aFreshTranscriberIsIdleAndNotBusy() {
    let transcriber = HoldToTalkTranscriber()
    #expect(transcriber.state == .idle)
    #expect(transcriber.partialTranscript == "")
    #expect(!transcriber.isBusy)
    #expect(!transcriber.isHolding)
}

@MainActor @Test func aPressBeforeStartIsIgnored() {
    let harness = Harness()
    harness.transcriber.beginHold()
    #expect(harness.transcriber.state == .idle)
    #expect(!harness.transcriber.isHolding)
    #expect(!harness.transcriber.isBusy)
    harness.transcriber.endHold(keyUpAt: 0)
    #expect(harness.transcriber.state == .idle)
    #expect(harness.finals.isEmpty)
    #expect(harness.failures.isEmpty)
}

@MainActor @Test func cancellingWhileIdleDoesNothing() {
    let harness = Harness()
    harness.transcriber.cancelHold()
    #expect(harness.transcriber.state == .idle)
    #expect(harness.transcriber.partialTranscript == "")
    #expect(!harness.transcriber.isBusy)
    #expect(harness.finals.isEmpty)
    #expect(harness.failures.isEmpty)
}

@MainActor @Test func contextualStringsRoundTrip() {
    let transcriber = HoldToTalkTranscriber(contextualStrings: ["space", "apostrophe"])
    #expect(transcriber.contextualStrings == ["space", "apostrophe"])
    transcriber.contextualStrings = ["a", "b", "c"]
    #expect(transcriber.contextualStrings == ["a", "b", "c"])
    #expect(HoldToTalkTranscriber().contextualStrings.isEmpty)
}
