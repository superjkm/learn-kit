import Testing
@testable import LearnKitUI

@Test func installReplacesThePlaceholder() {
    #expect(AppIdentity.placeholder.logFolder == "LearnKit")
    AppIdentity.install(AppIdentity(name: "Spelly Spell", bundleID: "com.lablabs.spellyspell", logFolder: "SpellySpell"))
    #expect(AppIdentity.current == AppIdentity(name: "Spelly Spell", bundleID: "com.lablabs.spellyspell", logFolder: "SpellySpell"))
}
