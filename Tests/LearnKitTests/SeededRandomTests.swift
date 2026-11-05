import Testing
@testable import LearnKit

@Test func theSameSeedGivesTheSameSequence() {
    var a = SeededRandomNumberGenerator(seed: 42), b = SeededRandomNumberGenerator(seed: 42)
    for _ in 0..<100 { #expect(a.next() == b.next()) }
}

@Test func differentSeedsDiverge() {
    var a = SeededRandomNumberGenerator(seed: 1), b = SeededRandomNumberGenerator(seed: 2)
    #expect(a.next() != b.next())
}

@Test func matchesTheSplitMix64ReferenceForSeedZero() {
    // First output of SplitMix64 from state 0, per the reference implementation.
    var g = SeededRandomNumberGenerator(seed: 0)
    #expect(g.next() == 0xE220_A839_7B1D_CDAF)
}

@Test func shufflesReproducibly() {
    var a = SeededRandomNumberGenerator(seed: 7), b = SeededRandomNumberGenerator(seed: 7)
    #expect(Array(1...20).shuffled(using: &a) == Array(1...20).shuffled(using: &b))
}
