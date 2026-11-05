import Testing
@testable import LearnKit

private func probe(
    speech: VoicePermission = .granted, microphone: VoicePermission = .granted,
    recognizer: Bool = true, onDevice: Bool = true, available: Bool = true,
    outcome: VoiceProbe.Outcome? = .finished
) -> VoiceProbe {
    VoiceProbe(speech: speech, microphone: microphone, recognizerExists: recognizer,
               supportsOnDevice: onDevice, isAvailable: available, outcome: outcome)
}

private func failed(_ domain: String, _ code: Int, _ text: String = "") -> VoiceProbe.Outcome {
    .failed(SpeechFailure(domain: domain, code: code, description: text))
}

@Test func aSilentTaskThatFinishesMeansReady() {
    #expect(VoiceReadiness.classify(probe()) == .ready)
}
@Test func noSpeechDetectedIsTheHealthyEndOfASilentTask() {
    // Seen on a working Mac (macOS 26.2): an empty on-device request ends with 1110.
    #expect(VoiceReadiness.classify(probe(outcome: failed("kAFAssistantErrorDomain", 1110, "No speech detected"))) == .ready)
}
@Test func deniedSpeechOrMicrophoneNeedsPermission() {
    #expect(VoiceReadiness.classify(probe(speech: .denied, outcome: nil)) == .needsPermission)
    #expect(VoiceReadiness.classify(probe(microphone: .denied)) == .needsPermission)
}
@Test func permissionWinsOverMissingDictation() {
    #expect(VoiceReadiness.classify(probe(microphone: .denied, onDevice: false, outcome: nil)) == .needsPermission)
}
@Test func noOnDeviceSupportOrUnavailableRecognizerNeedsDictation() {
    #expect(VoiceReadiness.classify(probe(onDevice: false, outcome: nil)) == .needsDictation)
    #expect(VoiceReadiness.classify(probe(available: false, outcome: nil)) == .needsDictation)
    #expect(VoiceReadiness.classify(probe(recognizer: false, onDevice: false, available: false, outcome: nil)) == .needsDictation)
}
@Test func speechPermissionNotAskedYetIsInconclusive() {
    #expect(VoiceReadiness.classify(probe(speech: .notAsked, outcome: nil)) == nil)
}
@Test func aProbeThatDidNotRunOrTimedOutIsInconclusive() {
    #expect(VoiceReadiness.classify(probe(outcome: nil)) == nil)
    #expect(VoiceReadiness.classify(probe(outcome: .timedOut)) == nil)
}
@Test func missingAssetAndDictationOffErrorsNeedDictation() {
    #expect(VoiceReadiness.classify(probe(outcome: failed("kAFAssistantErrorDomain", 1101))) == .needsDictation)
    #expect(VoiceReadiness.classify(probe(outcome: failed("kLSRErrorDomain", 102, "Failed to access assets"))) == .needsDictation)
    #expect(VoiceReadiness.classify(probe(outcome: failed("kLSRErrorDomain", 201, "Siri and Dictation are disabled"))) == .needsDictation)
    #expect(VoiceReadiness.classify(probe(outcome: failed("kLSRErrorDomain", 300, "Failed to initialize recognizer"))) == .needsDictation)
}
@Test func anUnknownErrorThatMentionsDictationOrAssetsNeedsDictation() {
    #expect(VoiceReadiness.classify(probe(outcome: failed("SomeDomain", 9, "Dictation is turned off"))) == .needsDictation)
    #expect(VoiceReadiness.classify(probe(outcome: failed("SomeDomain", 9, "Speech assets missing"))) == .needsDictation)
}
@Test func notAuthorizedErrorNeedsPermission() {
    #expect(VoiceReadiness.classify(probe(outcome: failed("kAFAssistantErrorDomain", 1700, "Request is not authorized"))) == .needsPermission)
}
@Test func transientErrorsAreInconclusive() {
    // Another task still active, the speech process interrupted, or a cancel: try again later.
    for code in [1100, 1107, 216, 301] {
        #expect(VoiceReadiness.classify(probe(outcome: failed("kAFAssistantErrorDomain", code))) == nil)
    }
}
@Test func anyOtherErrorIsUnavailableWithItsText() {
    let readiness = VoiceReadiness.classify(probe(outcome: failed("kAFAssistantErrorDomain", 203, "Retry")))
    #expect(readiness == .unavailable("kAFAssistantErrorDomain 203: Retry"))
}
@Test func aFailureWithNoDescriptionStillNamesDomainAndCode() {
    #expect(SpeechFailure(domain: "SFSpeechErrorDomain", code: 1, description: "").summary == "SFSpeechErrorDomain 1")
}
@Test func onlyReadyIsReady() {
    #expect(VoiceReadiness.ready.isReady)
    #expect(!VoiceReadiness.needsDictation.isReady)
    #expect(!VoiceReadiness.unavailable("x").isReady)
}
