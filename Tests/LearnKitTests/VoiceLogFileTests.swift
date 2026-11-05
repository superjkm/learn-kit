import Foundation
import Testing
@testable import LearnKit

// The opt-in voice log: plain text lines in one file, rotated to a single older file at a size cap.

private func scratch() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("VoiceLogFileTests-\(UUID().uuidString)")
        .appendingPathComponent("Logs/voice.log")
}

private func contents(_ url: URL) -> String? {
    try? String(contentsOf: url, encoding: .utf8)
}

@Test func theLogStartsInADirectoryThatDidNotExist() throws {
    let file = VoiceLogFile(url: scratch())
    try file.append("recognizer created")
    #expect(contents(file.url) == "recognizer created\n")
}

@Test func linesAreAppendedInOrder() throws {
    let file = VoiceLogFile(url: scratch())
    try file.append("press")
    try file.append("release")
    #expect(contents(file.url) == "press\nrelease\n")
}

@Test func aFullLogMovesAsideAndANewOneStarts() throws {
    let file = VoiceLogFile(url: scratch(), maxBytes: 20)
    try file.append("123456789")   // 10 bytes with the newline
    try file.append("abcdefghi")   // 20: at the cap, still fits
    try file.append("next line")   // would pass the cap: rotate first
    #expect(contents(file.url) == "next line\n")
    #expect(contents(file.rotatedURL) == "123456789\nabcdefghi\n")
}

@Test func onlyOneOlderLogIsKept() throws {
    let file = VoiceLogFile(url: scratch(), maxBytes: 10)
    try file.append("first one")
    try file.append("second on")
    try file.append("third one")
    #expect(contents(file.rotatedURL) == "second on\n")
    #expect(contents(file.url) == "third one\n")
}

@Test func aLineLargerThanTheCapStillLands() throws {
    let file = VoiceLogFile(url: scratch(), maxBytes: 10)
    try file.append("short")
    try file.append("this line is far longer than ten bytes")
    #expect(contents(file.url) == "this line is far longer than ten bytes\n")
    #expect(contents(file.rotatedURL) == "short\n")
}

@Test func theOlderLogSitsBesideTheLog() {
    let file = VoiceLogFile(url: URL(fileURLWithPath: "/tmp/Logs/voice.log"))
    #expect(file.rotatedURL.path == "/tmp/Logs/voice.1.log")
    #expect(VoiceLogFile.defaultMaxBytes == 1_000_000)
}
