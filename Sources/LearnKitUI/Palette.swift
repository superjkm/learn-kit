import SwiftUI

/// The eight colours every LearnKitUI view draws with, plus the rounded font. Each app
/// provides its own (Mathy Math orange, Spelly Spell teal) from its asset catalog and sets
/// it once with `.palette(_:)` at the root of its window.
public protocol Palette: Sendable {
    var cream: Color { get }
    var ink: Color { get }
    var accent: Color { get }
    var accentDark: Color { get }
    var gold: Color { get }
    var green: Color { get }
    var sand: Color { get }
    var muted: Color { get }
}

public extension Palette {
    func rounded(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Literal colours so the package's views render with no asset catalog (previews, snapshots
/// of the package alone). Apps always install their own.
public struct DefaultPalette: Palette {
    public init() {}
    public var cream: Color { Color(red: 0.99, green: 0.97, blue: 0.93) }
    public var ink: Color { Color(red: 0.16, green: 0.14, blue: 0.13) }
    public var accent: Color { Color(red: 0.95, green: 0.50, blue: 0.16) }
    public var accentDark: Color { Color(red: 0.72, green: 0.34, blue: 0.08) }
    public var gold: Color { Color(red: 0.98, green: 0.78, blue: 0.22) }
    public var green: Color { Color(red: 0.30, green: 0.69, blue: 0.42) }
    public var sand: Color { Color(red: 0.93, green: 0.88, blue: 0.80) }
    public var muted: Color { Color(red: 0.55, green: 0.52, blue: 0.48) }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: any Palette = DefaultPalette()
}

public extension EnvironmentValues {
    var palette: any Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

public extension View {
    /// Installs the app's palette for every LearnKitUI view below.
    func palette(_ palette: some Palette) -> some View {
        environment(\.palette, palette)
    }
}
