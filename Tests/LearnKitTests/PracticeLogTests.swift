import Foundation
import Testing
@testable import LearnKit

private func day(_ i: Int) -> PracticeDay { PracticeDay(index: i) }

@Test func aFreshLogIsEmpty() {
    let log = PracticeLog()
    #expect(log.practiceDays.isEmpty); #expect(log.bestStreak == 0); #expect(log.streak(today: day(5)) == 0)
}

@Test func recordingTodayStartsTheStreak() {
    var log = PracticeLog()
    #expect(log.recordPractice(today: day(10)) == true)
    #expect(log.practiceDays == [day(10)]); #expect(log.streak(today: day(10)) == 1); #expect(log.bestStreak == 1)
}

@Test func recordingTwiceOnOneDayCountsOnce() {
    var log = PracticeLog()
    _ = log.recordPractice(today: day(10))
    #expect(log.recordPractice(today: day(10)) == false)
    #expect(log.practiceDays.count == 1); #expect(log.bestStreak == 1)
}

@Test func bestStreakNeverFalls() {
    var log = PracticeLog()
    for i in 1...3 { log.recordPractice(today: day(i)) }
    #expect(log.bestStreak == 3)
    log.recordPractice(today: day(10))
    #expect(log.streak(today: day(10)) == 1); #expect(log.bestStreak == 3)
}

@Test func stripComesFromStreak() {
    var log = PracticeLog()
    for i in [10, 11, 13] { log.recordPractice(today: day(i)) }
    #expect(log.strip(today: day(14), length: 5) == Streak.strip(practiceDays: log.practiceDays, today: day(14), length: 5))
    #expect(log.strip(today: day(14)).count == 14)
}

@Test func roundTripsAsJSON() throws {
    var log = PracticeLog(bestStreak: 2)
    log.practiceDays = [day(1), day(2)]
    let data = try JSONEncoder().encode(log)
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.contains("\"practiceDays\"")); #expect(text.contains("\"bestStreak\""))
    #expect(try JSONDecoder().decode(PracticeLog.self, from: data) == log)
}
