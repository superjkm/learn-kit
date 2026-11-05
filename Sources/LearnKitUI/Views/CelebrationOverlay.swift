import LearnKit
import SwiftUI

/// Draws one celebration over the practice area. The practice view decides when it appears
/// and removes it after `duration(of:)`. `runLine` turns a run milestone into its line;
/// `skipHint` is the quiet line at the foot of a correction (nil for none).
public struct CelebrationOverlay: View {
    public let celebration: Celebration
    public let runLine: (Int) -> String
    public let skipHint: String?
    @Environment(\.palette) private var palette

    public init(celebration: Celebration, runLine: @escaping (Int) -> String = { "\($0) in a row!" }, skipHint: String? = nil) {
        self.celebration = celebration
        self.runLine = runLine
        self.skipHint = skipHint
    }

    /// The single celebration to show for an answer: wrong > moment > run > burst > tick.
    public static func biggest(_ celebrations: [Celebration]) -> Celebration? {
        func rank(_ c: Celebration) -> Int {
            switch c {
            case .tick: return 0
            case .burst: return 1
            case .run: return 2
            case .moment: return 3
            case .wrong: return 4
            }
        }
        // Highest rank wins; among equals (several moments) the first, which carries the most weight.
        return celebrations.enumerated().max { lhs, rhs in
            rank(lhs.element) == rank(rhs.element) ? lhs.offset > rhs.offset : rank(lhs.element) < rank(rhs.element)
        }?.element
    }

    public static func duration(of celebration: Celebration) -> Duration {
        switch celebration {
        case .tick: return .milliseconds(250)
        case .burst: return .milliseconds(700)
        case .run: return .milliseconds(900)
        case .moment: return .milliseconds(1400)
        case .wrong: return .milliseconds(2000)
        }
    }

    public var body: some View {
        Group {
            switch celebration {
            case .tick:
                Circle()
                    .stroke(palette.green.opacity(0.35), lineWidth: 8)
                    .frame(width: 300, height: 300)
            case let .burst(word):
                ZStack {
                    Rays(count: 12, radius: 210, length: 26, colors: [palette.accent, palette.gold])
                    Headline(text: word, color: palette.accent)
                }
            case let .run(n):
                ZStack {
                    Rays(count: 18, radius: 230, length: 38, colors: [palette.gold, palette.accent, palette.green])
                    Headline(text: runLine(n), color: palette.accentDark)
                }
            case let .moment(text):
                ZStack {
                    Rays(count: 24, radius: 240, length: 30, colors: [palette.gold])
                    Text(text)
                        .font(palette.rounded(30, weight: .heavy))
                        .padding(.vertical, 14)
                        .padding(.horizontal, 28)
                        .background(Capsule().fill(palette.gold.opacity(0.35)))
                        .offset(y: -170)
                }
            case let .wrong(shown, note):
                // The problem completes to its answer in calm type, covering the next prompt.
                ZStack {
                    palette.cream
                    VStack(spacing: 28) {
                        Text(shown)
                            .font(palette.rounded(72, weight: .bold))
                        Text(note)
                            .font(palette.rounded(20, weight: .medium))
                            .foregroundStyle(palette.muted)
                    }
                }
                .overlay(alignment: .bottom) {
                    // Understated: the child can learn it, but it never competes with the answer.
                    if let skipHint {
                        Text(skipHint)
                            .font(palette.rounded(15, weight: .medium))
                            .foregroundStyle(palette.muted.opacity(0.7))
                            .padding(.bottom, 28)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

private struct Headline: View {
    let text: String
    let color: Color
    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .font(palette.rounded(44, weight: .heavy))
            .foregroundStyle(color)
            .offset(y: -170)
    }
}

/// Short capsules radiating around the prompt on an ellipse wider than it is tall,
/// like a little firework.
public struct Rays: View {
    public let count: Int
    public let radius: CGFloat
    public let length: CGFloat
    public let colors: [Color]
    /// Horizontal stretch of the ellipse relative to its height.
    public var aspect: CGFloat

    public init(count: Int, radius: CGFloat, length: CGFloat, colors: [Color], aspect: CGFloat = 1.45) {
        self.count = count
        self.radius = radius
        self.length = length
        self.colors = colors
        self.aspect = aspect
    }

    public var body: some View {
        ZStack {
            ForEach(0..<(colors.isEmpty ? 0 : max(count, 0)), id: \.self) { i in
                let degrees = Double(i) * 360 / Double(count) + 8
                let angle = degrees * .pi / 180
                Capsule()
                    .fill(colors[i % colors.count])
                    .frame(width: 8, height: length)
                    .rotationEffect(.degrees(degrees))
                    .offset(x: sin(angle) * radius * aspect, y: -cos(angle) * radius)
            }
        }
    }
}
