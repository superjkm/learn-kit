import LearnKit
import SwiftUI

/// The last 14 days, oldest first; the final square is today.
public struct DayStripView: View {
    public let marks: [Streak.DayMark]
    @Environment(\.palette) private var palette

    public init(marks: [Streak.DayMark]) {
        self.marks = marks
    }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                square(for: mark)
                    .frame(width: 30, height: 30)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func square(for mark: Streak.DayMark) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        switch mark {
        case .practiced:
            shape.fill(palette.accent)
        case .forgiven:
            shape.fill(palette.accent.opacity(0.35))
        case .missed:
            shape.fill(palette.sand)
        case .today:
            shape.fill(palette.sand)
                .overlay(shape.strokeBorder(palette.accent, style: StrokeStyle(lineWidth: 2.5, dash: [4, 3])))
        }
    }
}
