import Foundation

public enum MasteryLevel: Int, Codable, Sendable, Comparable {
    case new, learning, known, solid

    public static func < (lhs: MasteryLevel, rhs: MasteryLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The scheduling state of one item. The item itself (a fact, a word) is the key of the
/// owning app's progress dictionary, not part of the card.
public struct Card: Hashable, Codable, Sendable {
    public var memory: Memory?
    public var dueDay: PracticeDay?
    public var lastReviewDay: PracticeDay?
    public var reviewCount: Int
    public var correctCount: Int
    /// Total wrong answers ever.
    public var lapses: Int
    public var lastAnswerCorrect: Bool?
    /// True once an Easy grade follows the most recent lapse.
    public var easySinceLapse: Bool

    public init() {
        self.memory = nil
        self.dueDay = nil
        self.lastReviewDay = nil
        self.reviewCount = 0
        self.correctCount = 0
        self.lapses = 0
        self.lastAnswerCorrect = nil
        self.easySinceLapse = false
    }

    public var level: MasteryLevel {
        guard let memory else { return .new }
        if lastAnswerCorrect == false { return .learning }
        if memory.stability < 3 { return .learning }
        if memory.stability < 21 { return .known }
        return .solid
    }

    public func isDue(on day: PracticeDay) -> Bool {
        guard let dueDay else { return false }
        return dueDay <= day
    }

    public mutating func record(grade: Grade, on day: PracticeDay) {
        let updated: Memory
        if let memory, let lastReviewDay {
            updated = FSRS.nextMemory(memory, grade: grade, elapsedDays: day - lastReviewDay)
        } else {
            updated = FSRS.initialMemory(grade: grade)
        }
        memory = updated
        dueDay = day.advanced(by: FSRS.intervalDays(stability: updated.stability))
        // A miss always comes back tomorrow; stability keeps what FSRS computed.
        if grade == .again, let due = dueDay { dueDay = min(due, day.advanced(by: 1)) }
        lastReviewDay = day
        reviewCount += 1
        if grade == .again {
            lastAnswerCorrect = false
            lapses += 1
            easySinceLapse = false
        } else {
            correctCount += 1
            lastAnswerCorrect = true
            if grade == .easy { easySinceLapse = true }
        }
    }
}
