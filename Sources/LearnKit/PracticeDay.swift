import Foundation

/// A day index for scheduling and streaks. The day rolls over at 03:00 local time.
public struct PracticeDay: Hashable, Codable, Comparable, Sendable {
    /// Whole days since 2001-01-01 local, with the day starting at 03:00.
    public let index: Int

    public static let rolloverHour = 3

    public init(index: Int) {
        self.index = index
    }

    public init(date: Date, calendar: Calendar = .current) {
        // Absolute 3h shift: on DST transition nights the boundary moves an hour (new day starts at 04:00 wall clock on spring-forward, 02:00 on fall-back). Accepted.
        let shifted = date.addingTimeInterval(-Double(Self.rolloverHour) * 3600)
        let day = calendar.startOfDay(for: shifted)
        let epoch = calendar.date(from: DateComponents(year: 2001, month: 1, day: 1))!
        self.index = calendar.dateComponents([.day], from: epoch, to: day).day ?? 0
    }

    public init(from decoder: Decoder) throws {
        index = try decoder.singleValueContainer().decode(Int.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(index)
    }

    public static func - (lhs: PracticeDay, rhs: PracticeDay) -> Int {
        lhs.index - rhs.index
    }

    public func advanced(by days: Int) -> PracticeDay {
        PracticeDay(index: index + days)
    }

    public static func < (lhs: PracticeDay, rhs: PracticeDay) -> Bool {
        lhs.index < rhs.index
    }
}
