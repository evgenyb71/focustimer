import SwiftUI
import UIKit

/// The app's colours, each with a light and a dark value. Unit tests check the text and background pairs
/// against WCAG AA in both themes, so change values here and rerun the tests.
enum Palette {
    struct RGB: Equatable, Sendable {
        var red: Double
        var green: Double
        var blue: Double

        /// WCAG relative luminance.
        nonisolated var luminance: Double {
            func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }

        /// This colour laid over `base` at the given opacity, as the card tints are drawn.
        nonisolated func over(_ base: RGB, opacity: Double) -> RGB {
            RGB(
                red: base.red + (red - base.red) * opacity,
                green: base.green + (green - base.green) * opacity,
                blue: base.blue + (blue - base.blue) * opacity
            )
        }

        nonisolated func contrast(with other: RGB) -> Double {
            let (high, low) = (max(luminance, other.luminance), min(luminance, other.luminance))
            return (high + 0.05) / (low + 0.05)
        }

        nonisolated var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: 1) }
    }

    struct Pair: Sendable {
        var light: RGB
        var dark: RGB

        /// Follows the light or dark appearance.
        var color: Color { Color(uiColor: uiColor) }

        /// A dynamic colour. SwiftUI resolves it on its background render thread too, so the provider must
        /// not be tied to the main actor: an isolated closure traps there (I19, the crash on Pause).
        nonisolated var uiColor: UIColor {
            let light = light
            let dark = dark
            return UIColor { @Sendable traits in
                (traits.userInterfaceStyle == .dark ? dark : light).uiColor
            }
        }
    }

    // Background gradient and cards.
    static let backgroundTop = Pair(light: RGB(red: 0.99, green: 0.96, blue: 0.91), dark: RGB(red: 0.15, green: 0.13, blue: 0.12))
    static let backgroundBottom = Pair(light: RGB(red: 0.93, green: 0.87, blue: 0.80), dark: RGB(red: 0.10, green: 0.09, blue: 0.08))
    static let card = Pair(light: RGB(red: 0.99, green: 0.975, blue: 0.95), dark: RGB(red: 0.19, green: 0.17, blue: 0.155))
    static let cardBorder = Pair(light: RGB(red: 0.85, green: 0.80, blue: 0.74), dark: RGB(red: 0.30, green: 0.27, blue: 0.25))

    // Text. Primary text uses the system `.primary` style, so buttons keep their own label colours; this pair
    // mirrors it (black in light, white in dark) for the contrast tests.
    static let primaryText = Pair(light: RGB(red: 0, green: 0, blue: 0), dark: RGB(red: 1, green: 1, blue: 1))
    static let secondaryText = Pair(light: RGB(red: 0.38, green: 0.35, blue: 0.32), dark: RGB(red: 0.72, green: 0.69, blue: 0.65))
    /// The status line under the time.
    static let message = Pair(light: RGB(red: 0.12, green: 0.33, blue: 0.31), dark: RGB(red: 0.62, green: 0.84, blue: 0.80))

    // Phase accents: text, symbols, borders, and tints. Darker in light mode, lighter in dark mode.
    static let focus = Pair(light: RGB(red: 0.12, green: 0.39, blue: 0.37), dark: RGB(red: 0.45, green: 0.78, blue: 0.75))
    static let breakTime = Pair(light: RGB(red: 0.23, green: 0.39, blue: 0.21), dark: RGB(red: 0.60, green: 0.80, blue: 0.54))
    static let focusComplete = Pair(light: RGB(red: 0.58, green: 0.32, blue: 0.04), dark: RGB(red: 0.95, green: 0.68, blue: 0.33))
    static let breakComplete = Pair(light: RGB(red: 0.16, green: 0.44, blue: 0.24), dark: RGB(red: 0.48, green: 0.82, blue: 0.55))

    /// Filled buttons keep the light accent in both themes, so their white label stays readable.
    static func buttonFill(_ accent: Pair) -> Color {
        Color(uiColor: accent.light.uiColor)
    }

    // Tint opacities over the card, shared by the view and the contrast tests.
    static let runningTint = 0.14
    static let pausedTint = 0.07
    static let endTint = 0.12
}
