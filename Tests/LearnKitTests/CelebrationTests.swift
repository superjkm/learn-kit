import Testing
@testable import LearnKit

private let words = ["Yes!", "Boom.", "Nailed it.", "Zoom!", "Got it.", "Sharp.", "Nice one.", "Whoa."]

private func isBurst(_ c: Celebration) -> Bool { if case .burst = c { return true } else { return false } }

@Test func wrongAnswerGetsNoCelebration() {
    var r = SeededRandomNumberGenerator(seed: 1)
    #expect(Celebrations.forAnswer(correct: false, correctRun: 0, burstWords: words, momentText: "x", rng: &r) == [])
}

@Test func correctAnswerAlwaysTicksFirst() {
    var r = SeededRandomNumberGenerator(seed: 1)
    for _ in 0..<50 { #expect(Celebrations.forAnswer(correct: true, correctRun: 1, burstWords: words, momentText: nil, rng: &r).first == .tick) }
}

@Test func burstFiresAboutOneInFour() {
    var r = SeededRandomNumberGenerator(seed: 7); var bursts = 0
    for _ in 0..<4000 { if Celebrations.forAnswer(correct: true, correctRun: 1, burstWords: words, momentText: nil, rng: &r).contains(where: isBurst) { bursts += 1 } }
    #expect(bursts > 850 && bursts < 1150)
}

@Test func burstWordsComeFromTheGivenList() {
    var burstsSeen = 0
    for seed in 0..<64 {
        var r = SeededRandomNumberGenerator(seed: UInt64(seed))
        for case let .burst(word) in Celebrations.forAnswer(correct: true, correctRun: 1, burstWords: words, momentText: nil, rng: &r) {
            burstsSeen += 1
            #expect(words.contains(word))
        }
    }
    #expect(burstsSeen > 0)
}

@Test func runMilestoneReplacesBurst() {
    var r = SeededRandomNumberGenerator(seed: 1)
    for n in Celebrations.runMilestones {
        let c = Celebrations.forAnswer(correct: true, correctRun: n, burstWords: words, momentText: nil, rng: &r)
        #expect(c.contains(.run(n))); #expect(!c.contains(where: isBurst))
    }
}

@Test func aMomentComesLast() {
    var r = SeededRandomNumberGenerator(seed: 1)
    let c = Celebrations.forAnswer(correct: true, correctRun: 3, burstWords: words, momentText: "You got their back.", rng: &r)
    #expect(c == [.tick, .run(3), .moment("You got their back.")])
}

@Test func noBurstWordsMeansNoBurstAndNoCrash() {
    var r = SeededRandomNumberGenerator(seed: 5)
    for _ in 0..<4000 {
        let c = Celebrations.forAnswer(correct: true, correctRun: 1, burstWords: [], momentText: nil, rng: &r)
        #expect(c == [.tick])
    }
    for seed in 0..<16 {
        var s = SeededRandomNumberGenerator(seed: UInt64(seed))
        let c = Celebrations.forAnswer(correct: true, correctRun: 3, burstWords: [], momentText: nil, rng: &s)
        #expect(c == [.tick, .run(3)])
    }
}

@Test func theOddsAndMilestonesAreMathyMaths() {
    #expect(Celebrations.burstOneIn == 4); #expect(Celebrations.runMilestones == [3, 5, 10]); #expect(Celebrations.liveMomentCap == 3)
}
