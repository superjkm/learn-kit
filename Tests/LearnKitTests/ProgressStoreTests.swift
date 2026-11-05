import Foundation
import Testing
@testable import LearnKit

/// A stand-in for an app's root progress type.
private struct TestProgress: Versioned, Equatable {
    static let currentVersion = 1
    var version = TestProgress.currentVersion
    var name: String?
    var practice = PracticeLog()
    var cards: [String: Card] = [:]
    init() {}

    private enum CodingKeys: String, CodingKey { case version, name, practice, cards }

    /// Tolerant like the apps' real progress types: a missing field takes its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        name = try c.decodeIfPresent(String.self, forKey: .name)
        practice = try c.decodeIfPresent(PracticeLog.self, forKey: .practice) ?? PracticeLog()
        cards = try c.decodeIfPresent([String: Card].self, forKey: .cards) ?? [:]
    }
}

private func tmp() -> URL {
    FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "progress.json")
}

private func write(_ json: String) throws -> URL {
    let url = tmp(); try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(json.utf8).write(to: url); return url
}

@Test func missingFileLoadsDefault() throws {
    let s = ProgressStore<TestProgress>(url: tmp())
    #expect(try s.load() == TestProgress())
}

@Test func roundTrip() throws {
    let s = ProgressStore<TestProgress>(url: tmp())
    var p = TestProgress(); p.name = "Sam"
    var card = Card(); card.record(grade: .good, on: PracticeDay(index: 5)); p.cards["their"] = card
    p.practice.recordPractice(today: PracticeDay(index: 5))
    try s.save(p)
    #expect(try s.load() == p)
}

@Test func savedFileIsSortedPrettyJSON() throws {
    let url = tmp(); var p = TestProgress(); p.name = "Sam"
    try ProgressStore<TestProgress>(url: url).save(p)
    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(text.contains("\n")); #expect(text.range(of: "\"cards\"")!.lowerBound < text.range(of: "\"name\"")!.lowerBound)
}

@Test func corruptFileIsMovedAsideNotCrashed() throws {
    let url = try write("not json")
    let p = try ProgressStore<TestProgress>(url: url).load()
    #expect(p == TestProgress())
    let siblings = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
    #expect(siblings.contains { $0.hasPrefix("progress.json.corrupt-") })
    #expect(!FileManager.default.fileExists(atPath: url.path))
}

@Test func corruptFilesGetDistinctAsideNames() throws {
    let url = tmp(); try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    for _ in 0..<2 { try Data("not json".utf8).write(to: url); _ = try ProgressStore<TestProgress>(url: url).load() }
    let siblings = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
    #expect(siblings.filter { $0.hasPrefix("progress.json.corrupt-") }.count == 2)
}

@Test func savedVersionOneFileStillLoads() throws {
    let fixture = try #require(Bundle.module.url(forResource: "progress-v1", withExtension: "json"))
    let p = try ProgressStore<TestProgress>(url: fixture).load()
    #expect(p.name == "Sam"); #expect(p.practice.practiceDays.count == 2); #expect(p.practice.bestStreak == 2)
    #expect(p.cards.count == 2); #expect(p.cards["their"]?.level == .known); #expect(p.cards["there"]?.level == .new)
    #expect(p.cards["their"]?.dueDay == PracticeDay(index: 9105))
}

@Test func newerVersionThrowsAndLeavesTheFileAlone() throws {
    let url = try write(#"{"version": 99, "name": "Sam"}"#)
    #expect(throws: ProgressStoreError.newerVersion(99)) { try ProgressStore<TestProgress>(url: url).load() }
    #expect(FileManager.default.fileExists(atPath: url.path))
    let siblings = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
    #expect(siblings == ["progress.json"])
}

@Test func missingOrOddVersionKeyIsNotANewerVersion() throws {
    // No version key: decoded as the app's type sees fit (here the default version), never refused.
    let noKey = try ProgressStore<TestProgress>(url: try write(#"{"name": "Sam"}"#)).load()
    #expect(noKey.name == "Sam"); #expect(noKey.version == 1)
    // A non-integer version is a corrupt file for TestProgress (its `version` is an Int): moved aside, default returned.
    let url = try write(#"{"version": "two", "name": "Sam"}"#)
    #expect(try ProgressStore<TestProgress>(url: url).load() == TestProgress())
    #expect(!FileManager.default.fileExists(atPath: url.path))
}

@Test func defaultURLLivesInApplicationSupportUnderTheAppFolder() {
    let url = ProgressStore<TestProgress>.defaultURL(appFolder: "SpellySpell")
    #expect(url.lastPathComponent == "progress.json")
    #expect(url.deletingLastPathComponent().lastPathComponent == "SpellySpell")
    #expect(url.path.contains("/Library/Application Support/"))
}
