import SwiftUI

/// The streak flame: grows with `stage` (0...7), glows gold from stage 3, sparkles from stage 5.
public struct FlameView: View {
    public let stage: Int
    @Environment(\.palette) private var palette

    public init(stage: Int) {
        self.stage = stage
    }

    private var clamped: Int { min(max(stage, 0), 7) }
    private var size: CGFloat { 44 + CGFloat(clamped) * (96 - 44) / 7 }

    public var body: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: size))
            .foregroundStyle(palette.accent)
            .opacity(clamped == 0 ? 0.35 : 1)
            .shadow(color: clamped >= 3 ? palette.gold.opacity(0.9) : .clear, radius: clamped >= 3 ? 14 : 0)
            .overlay(alignment: .topTrailing) {
                if clamped >= 5 {
                    Image(systemName: "sparkles")
                        .font(.system(size: size * 0.3))
                        .foregroundStyle(palette.gold)
                        .offset(x: size * 0.2, y: -size * 0.05)
                }
            }
            .frame(width: 110, height: 110)
            .accessibilityHidden(true)
    }
}
