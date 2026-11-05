import Testing
@testable import LearnKit

@Test func gradeThresholds() {
    #expect(ResponseGrading.grade(correct: false, responseTime: 1, easyUnder: 3, hardOver: 8) == .again)
    #expect(ResponseGrading.grade(correct: true, responseTime: 2.9, easyUnder: 3, hardOver: 8) == .easy)
    #expect(ResponseGrading.grade(correct: true, responseTime: 3.0, easyUnder: 3, hardOver: 8) == .good)
    #expect(ResponseGrading.grade(correct: true, responseTime: 8.0, easyUnder: 3, hardOver: 8) == .good)
    #expect(ResponseGrading.grade(correct: true, responseTime: 8.1, easyUnder: 3, hardOver: 8) == .hard)
    // Mathy Math's two-digit answer: both thresholds move by one second.
    #expect(ResponseGrading.grade(correct: true, responseTime: 3.5, easyUnder: 4, hardOver: 9) == .easy)
}

@Test func walkingAwayIsHardNotAgain() {
    #expect(ResponseGrading.grade(correct: true, responseTime: 600, easyUnder: 4, hardOver: 9) == .hard)
}
