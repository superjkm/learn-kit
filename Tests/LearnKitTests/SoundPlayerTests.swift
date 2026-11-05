import Testing
@testable import LearnKitUI

@Test func everyCueResolvesInThePackageBundle() {
    for cue in SoundPlayer.Cue.allCases {
        #expect(SoundPlayer.url(for: cue) != nil, "missing \(cue.rawValue).wav in the LearnKitUI bundle")
    }
}
