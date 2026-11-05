import SwiftUI

/// The big accent pill: accent fill with a darker "lip" beneath that presses down.
public struct PillButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(palette.rounded(22))
            .foregroundStyle(.white)
            .padding(.vertical, 18)
            .padding(.horizontal, 48)
            .background(Capsule().fill(palette.accent))
            .background(Capsule().fill(palette.accentDark).offset(y: pressed ? 2 : 6))
            .offset(y: pressed ? 4 : 0)
            .contentShape(Capsule())
    }
}
