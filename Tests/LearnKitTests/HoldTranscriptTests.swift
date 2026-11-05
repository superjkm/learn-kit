import Testing
@testable import LearnKit

// Hold to talk: the request is closed at the release; what was said during the hold is delivered
// from that request's final result, else its newest partial after a wait, else nothing.

@Test func nothingIsDecidedWhileTheKeyIsHeld() {
    var t = HoldTranscript()
    #expect(t.heard("t h", isFinal: false, segment: 1) == .waiting)
    #expect(t.heard("t h e", isFinal: true, segment: 1) == .waiting)
    #expect(t.timedOut() == .waiting)
}

@Test func theReleasedRequestsFinalResultIsDelivered() {
    var t = HoldTranscript()
    _ = t.heard("t h", isFinal: false, segment: 1)
    t.release(segment: 1)
    #expect(t.heard("t h e", isFinal: false, segment: 1) == .waiting)
    #expect(t.heard("t h e i r", isFinal: true, segment: 1) == .decided(text: "t h e i r", path: .final))
}

@Test func resultsForALaterRequestAreIgnoredAfterTheRelease() {
    var t = HoldTranscript()
    _ = t.heard("t h e", isFinal: false, segment: 3)
    t.release(segment: 3)
    #expect(t.heard("x", isFinal: true, segment: 4) == .ignored)
    #expect(t.heard("t h e", isFinal: true, segment: 3) == .decided(text: "t h e", path: .final))
}

@Test func withNoFinalTheNewestPartialIsDeliveredAfterTheWait() {
    var t = HoldTranscript()
    _ = t.heard("t h e", isFinal: false, segment: 1)
    t.release(segment: 1)
    _ = t.heard("", isFinal: false, segment: 1)
    #expect(t.timedOut() == .decided(text: "t h e", path: .waitTimeout))
}

@Test func aLaterPartialReplacesAnEarlierOne() {
    var t = HoldTranscript()
    _ = t.heard("s", isFinal: false, segment: 1)
    _ = t.heard("s a", isFinal: false, segment: 1)
    t.release(segment: 1)
    #expect(t.timedOut() == .decided(text: "s a", path: .waitTimeout))
}

@Test func anEmptyFinalFallsBackToTheNewestPartial() {
    var t = HoldTranscript()
    _ = t.heard("w h o", isFinal: false, segment: 1)
    t.release(segment: 1)
    #expect(t.heard("", isFinal: true, segment: 1) == .decided(text: "w h o", path: .final))
}

@Test func nothingHeardIsAnEmptyDecision() {
    var t = HoldTranscript()
    t.release(segment: 1)
    #expect(t.timedOut() == .decided(text: "", path: .waitTimeout))
}

@Test func theRecognizerEndingDecidesAtOnce() {
    var t = HoldTranscript()
    _ = t.heard("n o", isFinal: false, segment: 2)
    t.release(segment: 2)
    #expect(t.ended(segment: 5) == .ignored)
    #expect(t.ended(segment: 2) == .decided(text: "n o", path: .ended))
}

@Test func pressingAgainDecidesWithWhatWasHeard() {
    var t = HoldTranscript()
    _ = t.heard("a", isFinal: false, segment: 1)
    t.release(segment: 1)
    #expect(t.interrupted() == .decided(text: "a", path: .pressedAgain))
}

@Test func aTranscriptIsDecidedOnce() {
    var t = HoldTranscript()
    t.release(segment: 1)
    #expect(t.heard("e", isFinal: true, segment: 1) == .decided(text: "e", path: .final))
    #expect(t.timedOut() == .ignored)
    #expect(t.heard("f", isFinal: true, segment: 1) == .ignored)
    #expect(t.ended(segment: 1) == .ignored)
    #expect(t.interrupted() == .ignored)
}

@Test func anEndedRequestBeforeTheReleaseIsIgnoredByTheDecision() {
    // While the key is down the transcriber rolls to a new request itself; the decision waits.
    var t = HoldTranscript()
    _ = t.heard("b", isFinal: false, segment: 1)
    #expect(t.ended(segment: 1) == .ignored)
    #expect(t.latest == "b")
}

@Test func theWaitForAFinalIsTwoAndAHalfSeconds() {
    #expect(HoldTranscript.finalWait == .milliseconds(2500))
}
