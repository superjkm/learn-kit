import Testing
import Foundation
@testable import LearnKit

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return c
}()

private func dt(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
    cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
}

private func day(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> PracticeDay {
    PracticeDay(date: dt(y, mo, d, h, mi), calendar: cal)
}

@Test func twoFiftyNineAmIsStillYesterday() {
    #expect(day(2026, 10, 25, 2, 59) == day(2026, 10, 24, 12, 0))
}

@Test func threeAmIsANewDay() {
    #expect(day(2026, 10, 25, 3, 0) - day(2026, 10, 24, 12, 0) == 1)
}

@Test func epochIsLocalJanFirst2001() {
    #expect(day(2001, 1, 1, 12, 0).index == 0)
}

@Test func arithmetic() {
    let d = PracticeDay(index: 100)
    #expect(d.advanced(by: 5) - d == 5)
    #expect(d < d.advanced(by: 1))
}

@Test func encodesAsBareInteger() throws {
    let data = try JSONEncoder().encode(PracticeDay(index: 42))
    #expect(String(decoding: data, as: UTF8.self) == "42")
    #expect(try JSONDecoder().decode(PracticeDay.self, from: data) == PracticeDay(index: 42))
}

@Test func springForwardNight() {
    // 2026-03-08: 02:00 -> 03:00. 02:59 does not exist, so use 01:59 (still the prior practice day).
    let before = day(2026, 3, 7, 12, 0)
    #expect(day(2026, 3, 8, 1, 59) == before)
    #expect(day(2026, 3, 8, 4, 0) - before == 1)
    #expect(day(2026, 3, 9, 12, 0) - before == 2)
}

@Test func fallBackNight() {
    // 2026-11-01: 02:00 -> 01:00. The 3-absolute-hour shift moves the boundary to 02:00 wall clock,
    // so 01:59 (first pass) is the prior day and 04:00 is the new day.
    let before = day(2026, 10, 31, 12, 0)
    #expect(day(2026, 11, 1, 1, 59) == before)
    #expect(day(2026, 11, 1, 4, 0) - before == 1)
    #expect(day(2026, 11, 2, 12, 0) - before == 2)
}
