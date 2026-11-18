import Testing
@testable import LearnKit

// The microphone's voiced time (speech with its small gaps), ported from Mathy Math's
// VoiceWatchdogTests; the watchdog itself stays in Mathy Math.

private let t0 = ContinuousClock.now
private let buffer: Duration = .milliseconds(20)

@Test func nothingHeardIsNoVoicedTime() {
    let voiced = VoicedTime()
    #expect(voiced.total == .zero)
    #expect(voiced.lastAt == nil)
}

@Test func aLoneVoicedBufferCountsItsOwnLength() {
    var voiced = VoicedTime()
    voiced.heard(at: t0, length: buffer)
    #expect(voiced.total == buffer)
    #expect(voiced.lastAt == t0)
}

@Test func gapsInsideSpeechCountAsVoiced() {
    var voiced = VoicedTime()
    voiced.heard(at: t0, length: buffer)
    // A consonant or a breath: the gap is shorter than `VoicedTime.gap`, so it counts.
    voiced.heard(at: t0 + .milliseconds(200), length: buffer)
    #expect(voiced.total == buffer + .milliseconds(200))
}

@Test func aPauseBetweenUtterancesDoesNotCount() {
    var voiced = VoicedTime()
    voiced.heard(at: t0, length: buffer)
    voiced.heard(at: t0 + .seconds(5), length: buffer)
    #expect(voiced.total == buffer + buffer)
    #expect(voiced.lastAt == t0 + .seconds(5))
}

@Test func theGapMatchesTheListenersQuietRule() {
    #expect(VoicedTime.gap == .milliseconds(300))
}
