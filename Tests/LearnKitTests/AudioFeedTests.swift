import AVFoundation
import Speech
import Testing
@testable import LearnKitUI

/// In-process tests: real PCM buffers and capture times, and an un-started recognition request,
/// which only buffers what is appended. 0.1 s buffers at 10 kHz, so 1 000 frames each.
private enum Fixture {
    static let format = AVAudioFormat(standardFormatWithSampleRate: 10_000, channels: 1)!
    static let step = 0.1
    /// Capture start of buffer 0, in system-uptime seconds.
    static let base = 1_000.0

    static func start(_ index: Int) -> Double { base + Double(index) * step }

    static func buffer(amplitude: Float = 0.5) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1_000)!
        buffer.frameLength = 1_000
        for frame in 0..<1_000 { buffer.floatChannelData![0][frame] = amplitude }
        return buffer
    }

    static func time(_ index: Int) -> AVAudioTime {
        AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: start(index)))
    }

    /// Feeds buffers `range` through the tap.
    static func feed(_ feed: AudioFeed, _ range: Range<Int>, amplitude: Float = 0.5) {
        for index in range { feed.append(buffer(amplitude: amplitude), at: time(index)) }
    }

    static func request() -> SFSpeechAudioBufferRecognitionRequest { SFSpeechAudioBufferRecognitionRequest() }
}

@Test func releaseCountsLiveBuffersAndThoseAfterTheCutoff() {
    let feed = AudioFeed(nil)
    feed.swap(to: Fixture.request(), replay: 0)
    Fixture.feed(feed, 0..<5)
    let released = feed.release(cutoff: Fixture.start(3) - 0.05)
    #expect(released.request != nil)
    #expect(released.appended == 5)
    #expect(released.appendedAfterCutoff == 2)
    #expect(released.replayed == 0)
}

@Test func releaseReplaysPendingPreRollWhenNoLiveBufferArrived() {
    let feed = AudioFeed(nil)
    Fixture.feed(feed, 0..<8)
    feed.swap(to: Fixture.request(), replay: 0.3)
    let released = feed.release(cutoff: 0)
    #expect(released.appended == 0)
    #expect(abs(released.replayed - 0.3) < 1e-9)
}

@Test func swapAwayFlushesPendingReplayIntoTheOldRequest() {
    let feed = AudioFeed(nil)
    Fixture.feed(feed, 0..<8)
    feed.swap(to: Fixture.request(), replay: 0.3)
    #expect(feed.swap(to: Fixture.request(), replay: 0) != nil)
    let released = feed.release(cutoff: 0)
    #expect(abs(released.replayed - 0.3) < 1e-9)
}

@Test func releaseEmptiesTheRingSoALaterRequestReplaysNothing() {
    // Control: without a release the ring replays.
    let control = AudioFeed(nil)
    Fixture.feed(control, 0..<8)
    control.swap(to: Fixture.request(), replay: 0.6)
    Fixture.feed(control, 8..<9)
    #expect(abs(control.release(cutoff: 0).replayed - 0.6) < 1e-9)

    let feed = AudioFeed(nil)
    feed.swap(to: Fixture.request(), replay: 0)
    Fixture.feed(feed, 0..<8)
    _ = feed.release(cutoff: 0)
    feed.swap(to: Fixture.request(), replay: 0.6)
    Fixture.feed(feed, 8..<9)
    let second = feed.release(cutoff: 0)
    #expect(second.appended == 1)
    #expect(second.replayed == 0)
}

@Test func clearReplayDropsTheRingAndAnyPendingReplay() {
    let feed = AudioFeed(nil)
    Fixture.feed(feed, 0..<8)
    feed.clearReplay()
    feed.swap(to: Fixture.request(), replay: 0.6)
    Fixture.feed(feed, 8..<9)
    #expect(feed.release(cutoff: 0).replayed == 0)

    let pending = AudioFeed(nil)
    Fixture.feed(pending, 0..<8)
    pending.swap(to: Fixture.request(), replay: 0.6)
    pending.clearReplay()
    Fixture.feed(pending, 8..<9)
    #expect(pending.release(cutoff: 0).replayed == 0)
}

@Test func invalidateRingExcludesOlderBuffersFromReplay() {
    let feed = AudioFeed(nil)
    Fixture.feed(feed, 0..<5)
    feed.invalidateRing(before: Fixture.start(3) - 0.05)
    feed.swap(to: Fixture.request(), replay: 0.6)
    Fixture.feed(feed, 5..<6)
    // Only buffers 3 and 4 began after the cutoff.
    #expect(abs(feed.release(cutoff: 0).replayed - 0.2) < 1e-9)
}

@Test func lastVoicedAtIsSetOnlyByAudioAboveTheThreshold() {
    let feed = AudioFeed(nil)
    Fixture.feed(feed, 0..<1, amplitude: 0)
    #expect(feed.lastVoicedAt == nil)
    Fixture.feed(feed, 1..<2, amplitude: 0.005)
    #expect(feed.lastVoicedAt == nil)
    Fixture.feed(feed, 2..<3, amplitude: 0.5)
    #expect(feed.lastVoicedAt != nil)
}

@Test func theRingKeepsAtMostMaxReplaySeconds() {
    let feed = AudioFeed(nil)
    Fixture.feed(feed, 0..<30)
    feed.swap(to: Fixture.request(), replay: 5)
    Fixture.feed(feed, 30..<31)
    let replayed = feed.release(cutoff: 0).replayed
    #expect(abs(replayed - AudioFeed.maxReplay) < 1e-9)
}
