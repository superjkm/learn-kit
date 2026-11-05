import Foundation
import Testing
@testable import LearnKit

@Test func newCardIsNew() {
    let c = Card()
    #expect(c.level == .new)
    #expect(!c.isDue(on: PracticeDay(index: 0)))
    #expect(c.reviewCount == 0); #expect(c.correctCount == 0); #expect(c.lapses == 0)
    #expect(c.lastAnswerCorrect == nil); #expect(c.easySinceLapse == false)
}

@Test func firstGoodAnswerSchedulesAndLevels() {
    var c = Card(); let d = PracticeDay(index: 100)
    c.record(grade: .good, on: d)
    #expect(c.dueDay == d.advanced(by: 3)); #expect(c.level == .known); #expect(c.correctCount == 1); #expect(c.lastAnswerCorrect == true)
}

@Test func wrongAnswerIsLearningAndCountsLapse() {
    var c = Card(); let d = PracticeDay(index: 100)
    c.record(grade: .easy, on: d); c.record(grade: .again, on: d.advanced(by: 10))
    #expect(c.level == .learning); #expect(c.lapses == 1); #expect(c.easySinceLapse == false); #expect(c.dueDay! > d.advanced(by: 10))
}

@Test func firstEverAnswerWrongIsLearningAndDueTomorrow() {
    var c = Card(); let d = PracticeDay(index: 100)
    c.record(grade: .again, on: d)
    #expect(c.level == .learning); #expect(c.lapses == 1); #expect(c.dueDay == d.advanced(by: 1))
    #expect(c.lastReviewDay == d); #expect(c.reviewCount == 1); #expect(c.correctCount == 0)
}

@Test func solidAtTwentyOneDays() {
    var c = Card(); c.memory = Memory(stability: 21, difficulty: 3); c.lastAnswerCorrect = true
    #expect(c.level == .solid)
}

@Test func masteryLevelsCompareByRank() {
    #expect(MasteryLevel.new < .learning); #expect(MasteryLevel.learning < .known); #expect(MasteryLevel.known < .solid)
}

@Test func aMissComesBackTomorrow() {
    let d0 = PracticeDay(index: 0)
    var c = Card(); c.record(grade: .easy, on: d0)
    #expect(c.memory!.stability > 15)
    var sameDay = c; let stabilityBefore = FSRS.nextMemory(c.memory!, grade: .again, elapsedDays: 0).stability
    sameDay.record(grade: .again, on: d0)
    #expect(sameDay.dueDay == d0.advanced(by: 1)); #expect(sameDay.memory!.stability == stabilityBefore)
    var later = c; later.record(grade: .again, on: d0.advanced(by: 10))
    #expect(later.dueDay == d0.advanced(by: 11))
}

@Test func cardRoundTripsThroughJSONWithoutAFactField() throws {
    var c = Card(); c.record(grade: .good, on: PracticeDay(index: 5))
    let data = try JSONEncoder().encode(c)
    #expect(!String(decoding: data, as: UTF8.self).contains("fact"))
    #expect(try JSONDecoder().decode(Card.self, from: data) == c)
}
