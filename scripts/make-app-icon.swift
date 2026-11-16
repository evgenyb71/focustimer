// Draws the FocusTimer app icon: two overlapping timer rings, Focus (teal, behind) then Break (sage, in front).
// Writes the light, dark, and tinted 1024×1024 PNGs into the app's icon set. The PNGs are committed, so a
// build never needs this script; rerun it only to change the artwork.
// Usage, from the repository root: swift scripts/make-app-icon.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let outputDirectory = "ios/FocusTimer/FocusTimer/Assets.xcassets/AppIcon.appiconset"

struct RGB {
    var r: CGFloat, g: CGFloat, b: CGFloat
    func color(alpha: CGFloat = 1) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: alpha) }
}

struct Look {
    var fileName: String
    /// Top and bottom of the background gradient; nil leaves the background transparent for iOS to fill.
    var background: (RGB, RGB)?
    /// Fills each dial, so the front ring hides the part of the back ring it overlaps.
    var dialFill: RGB
    var focus: RGB
    var breakTime: RGB
}

// Colours match the app: the cream gradient, Focus teal, and Break sage (see the I23 and I20 specs).
let looks = [
    Look(
        fileName: "AppIcon-Light.png",
        background: (RGB(r: 0.99, g: 0.96, b: 0.91), RGB(r: 0.93, g: 0.87, b: 0.80)),
        dialFill: RGB(r: 1.0, g: 0.99, b: 0.97),
        focus: RGB(r: 0.16, g: 0.44, b: 0.42),
        breakTime: RGB(r: 0.28, g: 0.44, b: 0.26)
    ),
    Look(
        fileName: "AppIcon-Dark.png",
        background: nil,
        dialFill: RGB(r: 0.11, g: 0.11, b: 0.12),
        focus: RGB(r: 0.42, g: 0.76, b: 0.73),
        breakTime: RGB(r: 0.58, g: 0.78, b: 0.52)
    ),
    // Greyscale: iOS tints by brightness, so the front ring is the brightest and the dial fill is black.
    Look(
        fileName: "AppIcon-Tinted.png",
        background: nil,
        dialFill: RGB(r: 0, g: 0, b: 0),
        focus: RGB(r: 0.62, g: 0.62, b: 0.62),
        breakTime: RGB(r: 1, g: 1, b: 1)
    ),
]

/// One dial: a filled disc, its ring, and a short hand pointing towards one o'clock. CoreGraphics puts the
/// origin at the bottom left, so the Focus dial is up and to the left of the Break dial.
func drawDial(in context: CGContext, center: CGPoint, look: Look, ring: RGB) {
    let radius: CGFloat = 245
    let ringWidth: CGFloat = 70
    let disc = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

    context.setFillColor(look.dialFill.color())
    context.fillEllipse(in: disc.insetBy(dx: -ringWidth / 2, dy: -ringWidth / 2))
    context.setStrokeColor(ring.color())
    context.setLineWidth(ringWidth)
    context.strokeEllipse(in: disc)

    let angle = CGFloat.pi / 3  // 60° above the horizontal: about one o'clock.
    let length: CGFloat = 150
    context.setLineCap(.round)
    context.setLineWidth(56)
    context.move(to: center)
    context.addLine(to: CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length))
    context.strokePath()
}

func render(_ look: Look) -> CGImage {
    let opaque = look.background != nil
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        // The light icon has no alpha channel at all, as the App Store requires.
        bitmapInfo: opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)

    if let (top, bottom) = look.background {
        let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: [top.color(), bottom.color()] as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: bounds.maxY), end: .zero, options: [])
    } else {
        context.clear(bounds)
    }

    drawDial(in: context, center: CGPoint(x: 405, y: 619), look: look, ring: look.focus)
    drawDial(in: context, center: CGPoint(x: 619, y: 405), look: look, ring: look.breakTime)
    return context.makeImage()!
}

for look in looks {
    let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent(look.fileName)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Cannot write \(url.path)")
    }
    CGImageDestinationAddImage(destination, render(look), nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Cannot finish \(url.path)") }
    print("Wrote \(url.path)")
}
