import Testing
@testable import LearnKit

@Test func onlyOffDoesNotListen() {
    #expect(!VoiceMode.off.listens); #expect(VoiceMode.automatic.listens); #expect(VoiceMode.holdToTalk.listens)
}

@Test func rawValuesAreStableForSavedFiles() {
    #expect(VoiceMode.off.rawValue == "off"); #expect(VoiceMode.automatic.rawValue == "automatic"); #expect(VoiceMode.holdToTalk.rawValue == "holdToTalk")
}
