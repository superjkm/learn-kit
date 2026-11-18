import Foundation

/// Forgiving streak: a single missed day never breaks it; two in a row do.
public enum Streak {
    public static let milestones = [3, 7, 14, 30, 60, 100]
    /// Flame stage is the number of thresholds at or below the streak (0...7).
    public static let flameThresholds = [1, 3, 7, 14, 30, 60, 100]

    /// `flame` is a day in `halfDays` (the goal's answers), `doubled` one in `fullDays` (twice the goal).
    public enum DayMark: Sendable, Equatable { case practiced, flame, doubled, forgiven, missed, today }

    public static func current(practiceDays: Set<PracticeDay>, today: PracticeDay) -> Int {
        walk(practiceDays: practiceDays, today: today).count
    }

    /// `length` marks, oldest first; the last element is today, marked `.today` until it is
    /// earned and like any other day after. The flame sets outrank `practiceDays`. Omitting
    /// both flame sets gives the plain 0.1.0 strip.
    public static func strip(practiceDays: Set<PracticeDay>, halfDays: Set<PracticeDay> = [], fullDays: Set<PracticeDay> = [], today: PracticeDay, length: Int = 14) -> [DayMark] {
        let (count, oldest) = walk(practiceDays: practiceDays, today: today)
        return (0..<max(length, 0)).map { offset in
            let day = today.advanced(by: offset - (length - 1))
            if fullDays.contains(day) { return .doubled }
            if halfDays.contains(day) { return .flame }
            if practiceDays.contains(day) { return .practiced }
            if day == today { return .today }
            if count > 0, let oldest, day > oldest, day < today { return .forgiven }
            return .missed
        }
    }

    public static func flameStage(streak: Int) -> Int {
        flameThresholds.filter { $0 <= streak }.count
    }

    /// Streak length and the earliest day that contributed to it.
    private static func walk(practiceDays: Set<PracticeDay>, today: PracticeDay) -> (count: Int, oldest: PracticeDay?) {
        guard let earliest = practiceDays.min() else { return (0, nil) }
        var d = practiceDays.contains(today) ? today : today.advanced(by: -1)
        var count = 0
        var misses = 0
        var oldest: PracticeDay?
        while d >= earliest {
            if practiceDays.contains(d) {
                count += 1
                misses = 0
                oldest = d
            } else {
                misses += 1
                if misses == 2 { break }
            }
            d = d.advanced(by: -1)
        }
        return (count, oldest)
    }
}
