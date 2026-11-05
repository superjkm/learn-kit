import SwiftUI
import Testing
@testable import LearnKitUI

/// `Rays` is a View, so the guard is in its body: empty colors render no capsules instead of trapping.
@Test @MainActor func raysWithNoColorsDoesNotTrap() {
    let rays = Rays(count: 8, radius: 10, length: 10, colors: [])
    _ = rays.body
}
