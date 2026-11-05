import Testing
import Foundation
@testable import LearnKit

@Test func initialStabilityUsesFirstFourWeights() {
    #expect(FSRS.initialMemory(grade: .good).stability == 3.173)
    #expect(FSRS.initialMemory(grade: .again).stability == 0.40255)
}
@Test func initialDifficultyIsClamped() { for g in Grade.allCases { let d = FSRS.initialMemory(grade: g).difficulty; #expect(d >= 1 && d <= 10) } }
@Test func intervalEqualsStabilityAtDefaultRetention() { #expect(FSRS.intervalDays(stability: 10) == 10); #expect(FSRS.intervalDays(stability: 0.3) == 1) }
@Test func retrievabilityIsNinetyPercentAfterOneStability() { #expect(abs(FSRS.retrievability(stability: 10, elapsedDays: 10) - 0.9) < 0.001) }
@Test func goodReviewGrowsStability() { let m = Memory(stability: 5, difficulty: 5); #expect(FSRS.nextMemory(m, grade: .good, elapsedDays: 5).stability > 5) }
@Test func againShrinksStability() { let m = Memory(stability: 20, difficulty: 5); #expect(FSRS.nextMemory(m, grade: .again, elapsedDays: 20).stability < 20) }
@Test func easyBeatsGoodBeatsHard() {
    let m = Memory(stability: 5, difficulty: 5)
    let h = FSRS.nextMemory(m, grade: .hard, elapsedDays: 5).stability, g = FSRS.nextMemory(m, grade: .good, elapsedDays: 5).stability, e = FSRS.nextMemory(m, grade: .easy, elapsedDays: 5).stability
    #expect(h < g && g < e)
}
@Test func sameDayReviewUsesShortTermFormula() {
    let m = Memory(stability: 5, difficulty: 5)
    #expect(abs(FSRS.nextMemory(m, grade: .good, elapsedDays: 0).stability - 5 * exp(0.51655 * 0.6621)) < 1e-9)
}
@Test func difficultyStaysInRange() { var m = Memory(stability: 1, difficulty: 9.8); for _ in 0..<20 { m = FSRS.nextMemory(m, grade: .again, elapsedDays: 1) }; #expect(m.difficulty <= 10) }
