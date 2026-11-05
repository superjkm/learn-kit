import Foundation

/// Turns a right-or-wrong answer and how long it took into an FSRS grade. The thresholds are
/// the app's: Mathy Math passes 3 s and 8 s plus a second per extra digit; Spelly Spell passes
/// 5 s and 15 s plus half a second and a second per letter over four.
public enum ResponseGrading {
    public static func grade(correct: Bool, responseTime: TimeInterval, easyUnder: TimeInterval, hardOver: TimeInterval) -> Grade {
        guard correct else { return .again }
        if responseTime < easyUnder { return .easy }
        if responseTime <= hardOver { return .good }
        return .hard
    }
}
