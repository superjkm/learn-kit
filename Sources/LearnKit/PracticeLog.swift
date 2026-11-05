import Foundation

/// The days practised and the best streak ever, embedded in each app's progress. This is the
/// bookkeeping Mathy Math's `Progress` and `SessionEngine.complete` did inline.
public struct PracticeLog: Codable, Equatable, Sendable {
    public var practiceDays: Set<PracticeDay>
    public var bestStreak: Int

    public init(practiceDays: Set<PracticeDay> = [], bestStreak: Int = 0) {
        self.practiceDays = practiceDays
        self.bestStreak = bestStreak
    }

    public func streak(today: PracticeDay) -> Int {
        Streak.current(practiceDays: practiceDays, today: today)
    }

    public func strip(today: PracticeDay, length: Int = 14) -> [Streak.DayMark] {
        Streak.strip(practiceDays: practiceDays, today: today, length: length)
    }

    /// Marks today as practised and raises the best streak. Returns true when today was not
    /// yet recorded (the streak changed), false when it already was.
    @discardableResult
    public mutating func recordPractice(today: PracticeDay) -> Bool {
        let changed = !practiceDays.contains(today)
        practiceDays.insert(today)
        bestStreak = max(bestStreak, streak(today: today))
        return changed
    }
}
