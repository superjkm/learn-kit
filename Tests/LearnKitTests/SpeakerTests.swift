import AVFoundation
import Testing
@testable import LearnKitUI

private func voice(_ id: String, _ language: String, _ quality: Int) -> VoiceCandidate {
    VoiceCandidate(identifier: id, language: language, quality: quality)
}

@Test func premiumBeatsEnhancedBeatsDefaultForEnUS() {
    let voices = [
        voice("com.apple.voice.compact.en-US.Samantha", "en-US", 1),
        voice("com.apple.voice.premium.en-US.Zoe", "en-US", 3),
        voice("com.apple.voice.enhanced.en-US.Evan", "en-US", 2),
        voice("com.apple.voice.premium.en-GB.Serena", "en-GB", 3),
    ]
    #expect(Speaker.preferredVoice(among: voices)?.identifier == "com.apple.voice.premium.en-US.Zoe")
}

@Test func enhancedWinsWhenThereIsNoPremium() {
    let voices = [
        voice("com.apple.voice.compact.en-US.Samantha", "en-US", 1),
        voice("com.apple.voice.enhanced.en-US.Evan", "en-US", 2),
    ]
    #expect(Speaker.preferredVoice(among: voices)?.identifier == "com.apple.voice.enhanced.en-US.Evan")
}

@Test func otherLanguagesNeverWin() {
    let voices = [voice("com.apple.voice.premium.en-GB.Serena", "en-GB", 3), voice("com.apple.voice.compact.fr-FR.Thomas", "fr-FR", 1)]
    #expect(Speaker.preferredVoice(among: voices) == nil)
}

@Test func noVoicesMeansSystemDefault() {
    #expect(Speaker.preferredVoice(among: []) == nil)
}

@Test func tiesBreakByIdentifierSoTheChoiceIsStable() {
    let a = voice("com.apple.voice.enhanced.en-US.Ava", "en-US", 2)
    let b = voice("com.apple.voice.enhanced.en-US.Evan", "en-US", 2)
    #expect(Speaker.preferredVoice(among: [b, a]) == a)
    #expect(Speaker.preferredVoice(among: [a, b]) == a)
}

@Test func theDefaultRateIsSlowEnoughForAChild() {
    #expect(Speaker.defaultRate == 0.45)
}

// The old utterance's didCancel arrives after speak() has started the new one.
@MainActor @Test func aStaleCancelDoesNotClearTheNewUtterancesSpeakingState() {
    let speaker = Speaker()
    var finished = 0
    speaker.onFinished = { finished += 1 }
    let first = AVSpeechUtterance(string: "one")
    let second = AVSpeechUtterance(string: "two")

    speaker.track(first)
    speaker.track(second)
    speaker.utteranceEnded(ObjectIdentifier(first), cancelled: true)
    #expect(speaker.isSpeaking)

    speaker.utteranceEnded(ObjectIdentifier(first), cancelled: false)
    #expect(speaker.isSpeaking)
    #expect(finished == 0)

    speaker.utteranceEnded(ObjectIdentifier(second), cancelled: false)
    #expect(!speaker.isSpeaking)
    #expect(finished == 1)
}

@MainActor @Test func stopSilencesTheCurrentUtterancesLateCallbacks() {
    let speaker = Speaker()
    var finished = 0
    speaker.onFinished = { finished += 1 }
    let utterance = AVSpeechUtterance(string: "one")
    speaker.track(utterance)
    speaker.stop()
    #expect(!speaker.isSpeaking)
    speaker.utteranceEnded(ObjectIdentifier(utterance), cancelled: false)
    #expect(finished == 0)
}
