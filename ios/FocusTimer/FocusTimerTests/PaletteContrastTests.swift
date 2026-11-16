import Testing
import UIKit
@testable import FocusTimer

/// Every text and symbol colour against the background it is drawn on, in both themes, at WCAG AA:
/// 4.5:1 for small text and 3:1 for large text and symbols.
@MainActor
struct PaletteContrastTests {
    enum Theme: CaseIterable, Sendable {
        case light
        case dark
    }

    static let smallText = 4.5
    static let largeText = 3.0

    func value(_ pair: Palette.Pair, _ theme: Theme) -> Palette.RGB {
        theme == .light ? pair.light : pair.dark
    }

    /// The card, plain or tinted with an accent as the status card draws it.
    func cards(_ theme: Theme) -> [Palette.RGB] {
        let card = value(Palette.card, theme)
        let accents = [Palette.focus, Palette.breakTime, Palette.focusComplete, Palette.breakComplete]
        let tints = [Palette.runningTint, Palette.pausedTint, Palette.endTint]
        return [card] + accents.flatMap { accent in tints.map { value(accent, theme).over(card, opacity: $0) } }
    }

    @Test(arguments: Theme.allCases)
    func smallTextMeetsAAOnEveryCard(theme: Theme) {
        // Captions, the status line, the row titles, and durations: small text on any card.
        let small = [Palette.primaryText, Palette.secondaryText, Palette.message, Palette.focus, Palette.breakTime]
        for text in small {
            for card in cards(theme) {
                #expect(value(text, theme).contrast(with: card) >= Self.smallText, "\(text) on \(card)")
            }
        }
    }

    @Test(arguments: Theme.allCases)
    func accentsMeetLargeTextOnEveryCard(theme: Theme) {
        // Phase names, the time, and the end symbols and headlines.
        let large = [Palette.focus, Palette.breakTime, Palette.focusComplete, Palette.breakComplete]
        for accent in large {
            for card in cards(theme) {
                #expect(value(accent, theme).contrast(with: card) >= Self.largeText, "\(accent) on \(card)")
            }
        }
    }

    @Test(arguments: Theme.allCases)
    func durationTextMeetsAAOnTheFadedWaitingCard(theme: Theme) {
        // While waiting for Break the duration card fades over the gradient; its labels and durations do not.
        for background in [Palette.backgroundTop, Palette.backgroundBottom] {
            let faded = value(Palette.card, theme).over(value(background, theme), opacity: Palette.waitingCardOpacity)
            for text in [Palette.primaryText, Palette.secondaryText] {
                #expect(value(text, theme).contrast(with: faded) >= Self.smallText, "\(text) on \(faded)")
            }
        }
    }

    @Test(arguments: Theme.allCases)
    func textOutsideCardsMeetsAAOnTheBackground(theme: Theme) {
        // The title, subtitle, and alerts hint sit on the gradient.
        for background in [Palette.backgroundTop, Palette.backgroundBottom] {
            for text in [Palette.primaryText, Palette.secondaryText] {
                #expect(value(text, theme).contrast(with: value(background, theme)) >= Self.smallText)
            }
        }
    }

    @Test func filledButtonsKeepWhiteLabelsReadable() {
        let white = Palette.RGB(red: 1, green: 1, blue: 1)
        for accent in [Palette.focus, Palette.focusComplete, Palette.breakComplete] {
            #expect(white.contrast(with: accent.light) >= Self.smallText)
        }
    }

    @Test func contrastMatchesKnownValues() {
        let black = Palette.RGB(red: 0, green: 0, blue: 0)
        let white = Palette.RGB(red: 1, green: 1, blue: 1)
        #expect(abs(black.contrast(with: white) - 21) < 0.001)
        #expect(white.contrast(with: white) == 1)
    }
}

/// SwiftUI resolves dynamic colours on its background render thread. A provider tied to the main actor
/// traps there; this crashed the app on Pause during I19.
@MainActor
struct PaletteThreadingTests {
    @Test func dynamicColorsResolveOffTheMainThread() async {
        let pair = Palette.focus
        let resolved = await Task.detached {
            let color = pair.uiColor
            var light: (CGFloat, CGFloat) = (0, 0)
            var dark: (CGFloat, CGFloat) = (0, 0)
            color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).getRed(&light.0, green: &light.1, blue: nil, alpha: nil)
            color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).getRed(&dark.0, green: &dark.1, blue: nil, alpha: nil)
            return (light, dark)
        }.value

        #expect(abs(resolved.0.0 - pair.light.red) < 0.01)
        #expect(abs(resolved.1.0 - pair.dark.red) < 0.01)
    }
}
