import Testing
@testable import LearnKit

private func days(_ idx: Int...) -> Set<PracticeDay> { Set(idx.map { PracticeDay(index: $0) }) }

@Test func consecutiveDays() { #expect(Streak.current(practiceDays: days(1,2,3,4), today: PracticeDay(index: 4)) == 4) }
@Test func todayNotYetPracticedKeepsStreak() { #expect(Streak.current(practiceDays: days(1,2,3), today: PracticeDay(index: 4)) == 3) }
@Test func oneMissForgiven() { #expect(Streak.current(practiceDays: days(1,2,4), today: PracticeDay(index: 4)) == 3) }
@Test func twoMissesReset() { #expect(Streak.current(practiceDays: days(1,2,5), today: PracticeDay(index: 5)) == 1) }
@Test func yesterdayMissedTodayPendingStillAlive() { #expect(Streak.current(practiceDays: days(1,2,3), today: PracticeDay(index: 5)) == 3) }
@Test func twoDaysMissedTodayPendingIsZero() { #expect(Streak.current(practiceDays: days(1,2,3), today: PracticeDay(index: 6)) == 0) }
@Test func noPracticeIsZero() { #expect(Streak.current(practiceDays: [], today: PracticeDay(index: 0)) == 0) }
@Test func stripMarksForgivenDay() {
    let s = Streak.strip(practiceDays: days(10,11,13), today: PracticeDay(index: 14), length: 5)
    #expect(s == [.practiced, .practiced, .forgiven, .practiced, .today])
}
@Test func stripMarksMissedOutsideStreak() { let s = Streak.strip(practiceDays: days(13), today: PracticeDay(index: 14), length: 3); #expect(s == [.missed, .practiced, .today]) }
@Test func stripOfLengthZeroIsEmpty() { #expect(Streak.strip(practiceDays: days(13), today: PracticeDay(index: 14), length: 0) == []) }
@Test func stripMarksFlameAndDoubledDays() {
    let s = Streak.strip(practiceDays: days(11,12,13), halfDays: days(12,13), fullDays: days(13), today: PracticeDay(index: 14), length: 4)
    #expect(s == [.practiced, .flame, .doubled, .today])
}
@Test func stripMarksTodayOnceEarned() {
    #expect(Streak.strip(practiceDays: days(13,14), today: PracticeDay(index: 14), length: 2) == [.practiced, .practiced])
    #expect(Streak.strip(practiceDays: days(13,14), halfDays: days(14), today: PracticeDay(index: 14), length: 2) == [.practiced, .flame])
    #expect(Streak.strip(practiceDays: days(13,14), halfDays: days(14), fullDays: days(14), today: PracticeDay(index: 14), length: 2) == [.practiced, .doubled])
}
@Test func stripWithoutFlameSetsIsUnchanged() {
    #expect(Streak.strip(practiceDays: days(12,14), today: PracticeDay(index: 14), length: 3) == [.practiced, .forgiven, .practiced])
}
@Test func flameStages() { #expect(Streak.flameStage(streak: 0) == 0); #expect(Streak.flameStage(streak: 1) == 1); #expect(Streak.flameStage(streak: 6) == 2); #expect(Streak.flameStage(streak: 7) == 3); #expect(Streak.flameStage(streak: 100) == 7) }
