#!/usr/bin/env swift

import AppKit
import Foundation

struct IconOutput {
    let filename: String
    let pixels: Int
}

let fileManager = FileManager.default

func findProjectRoot(startingAt start: URL) -> URL {
    var current = start.standardizedFileURL
    while true {
        let marker = current.appendingPathComponent("Argo/Assets.xcassets/AppIcon.appiconset/Contents.json")
        if fileManager.fileExists(atPath: marker.path) {
            return current
        }

        let parent = current.deletingLastPathComponent()
        if parent.path == current.path {
            fatalError("Unable to locate Argo project root from \(start.path)")
        }
        current = parent
    }
}

let scriptURL = URL(
    fileURLWithPath: CommandLine.arguments[0],
    relativeTo: URL(fileURLWithPath: fileManager.currentDirectoryPath)
).standardizedFileURL
let projectRoot = findProjectRoot(startingAt: scriptURL.deletingLastPathComponent())
let appIconDirectory = projectRoot.appendingPathComponent("Argo/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let masterURL = projectRoot.appendingPathComponent("docs/assets/argo-app-icon-terminal-constellation-1024.png")
let contentsURL = appIconDirectory.appendingPathComponent("Contents.json")

guard fileManager.fileExists(atPath: contentsURL.path) else {
    fatalError("Missing AppIcon Contents.json at \(contentsURL.path)")
}

let outputs: [IconOutput] = [
    IconOutput(filename: "appicon_16x16.png", pixels: 16),
    IconOutput(filename: "appicon_16x16@2x.png", pixels: 32),
    IconOutput(filename: "appicon_32x32.png", pixels: 32),
    IconOutput(filename: "appicon_32x32@2x.png", pixels: 64),
    IconOutput(filename: "appicon_128x128.png", pixels: 128),
    IconOutput(filename: "appicon_128x128@2x.png", pixels: 256),
    IconOutput(filename: "appicon_256x256.png", pixels: 256),
    IconOutput(filename: "appicon_256x256@2x.png", pixels: 512),
    IconOutput(filename: "appicon_512x512.png", pixels: 512),
    IconOutput(filename: "appicon_512x512@2x.png", pixels: 1024)
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawGlow(center: NSPoint, radius: CGFloat, color: NSColor, alpha: CGFloat) {
    let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    let path = NSBezierPath(ovalIn: rect)
    let gradient = NSGradient(colors: [
        color.withAlphaComponent(alpha),
        color.withAlphaComponent(alpha * 0.22),
        color.withAlphaComponent(0)
    ])!
    gradient.draw(in: path, relativeCenterPosition: .zero)
}

func drawStar(x: CGFloat, y: CGFloat, radius: CGFloat, color: NSColor) {
    let shadow = NSShadow()
    shadow.shadowColor = color.withAlphaComponent(0.72)
    shadow.shadowBlurRadius = radius * 5
    shadow.shadowOffset = .zero
    shadow.set()

    color.withAlphaComponent(0.92).setFill()
    NSBezierPath(ovalIn: NSRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)).fill()

    NSShadow().set()
}

func strokePrompt(in rect: NSRect, scale: CGFloat) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: rect.minX + 0.19 * rect.width, y: rect.minY + 0.36 * rect.height))
    path.line(to: NSPoint(x: rect.minX + 0.32 * rect.width, y: rect.minY + 0.50 * rect.height))
    path.line(to: NSPoint(x: rect.minX + 0.19 * rect.width, y: rect.minY + 0.64 * rect.height))
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.lineWidth = max(2, 30 * scale)

    color(9, 14, 24, 0.92).setStroke()
    path.stroke()

    let cursorRect = NSRect(
        x: rect.minX + 0.43 * rect.width,
        y: rect.minY + 0.32 * rect.height,
        width: 0.24 * rect.width,
        height: max(2, 28 * scale)
    )
    color(9, 14, 24, 0.88).setFill()
    roundedRect(cursorRect, radius: cursorRect.height / 2).fill()
}

func drawIcon(pixels: Int, in context: NSGraphicsContext) {
    let canvas = CGFloat(pixels)
    let scale = canvas / 1024

    context.imageInterpolation = .high
    context.shouldAntialias = true

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: canvas, height: canvas).fill()

    let iconRect = NSRect(x: 0, y: 0, width: canvas, height: canvas)
    let iconPath = roundedRect(iconRect, radius: 224 * scale)
    iconPath.addClip()

    let background = NSGradient(colors: [
        color(21, 27, 41),
        color(10, 13, 19),
        color(7, 9, 13)
    ])!
    background.draw(in: iconRect, angle: -38)

    drawGlow(center: NSPoint(x: 285 * scale, y: 815 * scale), radius: 330 * scale, color: color(64, 138, 251), alpha: 0.22)
    drawGlow(center: NSPoint(x: 760 * scale, y: 235 * scale), radius: 310 * scale, color: color(51, 184, 161), alpha: 0.18)
    drawGlow(center: NSPoint(x: 810 * scale, y: 820 * scale), radius: 230 * scale, color: color(122, 99, 255), alpha: 0.10)

    let orbitRect = NSRect(x: 196 * scale, y: 635 * scale, width: 610 * scale, height: 250 * scale)
    let orbit = NSBezierPath(ovalIn: orbitRect)
    let transform = NSAffineTransform()
    transform.translateX(by: orbitRect.midX, yBy: orbitRect.midY)
    transform.rotate(byDegrees: -15)
    transform.translateX(by: -orbitRect.midX, yBy: -orbitRect.midY)
    orbit.transform(using: transform as AffineTransform)
    orbit.lineWidth = max(1, 7 * scale)
    color(92, 230, 255, 0.58).setStroke()
    orbit.stroke()

    drawStar(x: 276 * scale, y: 778 * scale, radius: max(1.2, 9 * scale), color: color(238, 252, 255))
    drawStar(x: 430 * scale, y: 842 * scale, radius: max(1.1, 7 * scale), color: color(92, 230, 255))
    drawStar(x: 706 * scale, y: 800 * scale, radius: max(1.1, 8 * scale), color: color(84, 215, 133))
    drawStar(x: 782 * scale, y: 648 * scale, radius: max(1.0, 6 * scale), color: color(190, 204, 255))

    let terminalRect = NSRect(x: 205 * scale, y: 250 * scale, width: 614 * scale, height: 332 * scale)
    let terminalShadow = NSShadow()
    terminalShadow.shadowColor = NSColor.black.withAlphaComponent(0.38)
    terminalShadow.shadowBlurRadius = 38 * scale
    terminalShadow.shadowOffset = NSSize(width: 0, height: -16 * scale)
    terminalShadow.set()

    let terminalPath = roundedRect(terminalRect, radius: 72 * scale)
    let terminalGradient = NSGradient(colors: [
        color(244, 252, 255, 0.98),
        color(198, 228, 240, 0.92),
        color(142, 181, 204, 0.82)
    ])!
    terminalGradient.draw(in: terminalPath, angle: -34)
    NSShadow().set()

    color(255, 255, 255, 0.23).setStroke()
    terminalPath.lineWidth = max(1, 3 * scale)
    terminalPath.stroke()

    let headerRect = NSRect(
        x: terminalRect.minX + 46 * scale,
        y: terminalRect.maxY - 73 * scale,
        width: terminalRect.width - 92 * scale,
        height: 34 * scale
    )
    color(9, 14, 24, 0.34).setFill()
    roundedRect(headerRect, radius: 17 * scale).fill()

    strokePrompt(in: terminalRect, scale: scale)

    let topHighlight = NSBezierPath()
    topHighlight.move(to: NSPoint(x: 180 * scale, y: 955 * scale))
    topHighlight.curve(
        to: NSPoint(x: 844 * scale, y: 930 * scale),
        controlPoint1: NSPoint(x: 360 * scale, y: 1010 * scale),
        controlPoint2: NSPoint(x: 680 * scale, y: 1010 * scale)
    )
    topHighlight.lineWidth = max(1, 3 * scale)
    color(255, 255, 255, 0.14).setStroke()
    topHighlight.stroke()

    roundedRect(iconRect.insetBy(dx: 2 * scale, dy: 2 * scale), radius: 222 * scale)
        .setClip()
    color(255, 255, 255, 0.10).setStroke()
    let border = roundedRect(iconRect.insetBy(dx: 2 * scale, dy: 2 * scale), radius: 222 * scale)
    border.lineWidth = max(1, 2 * scale)
    border.stroke()
}

func renderIcon(pixels: Int) -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Unable to create bitmap image representation")
    }

    bitmap.size = NSSize(width: pixels, height: pixels)

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Unable to create graphics context")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }

    drawIcon(pixels: pixels, in: context)

    return bitmap
}

func pngData(from bitmap: NSBitmapImageRep) -> Data {
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to encode PNG data")
    }
    return png
}

try fileManager.createDirectory(at: appIconDirectory, withIntermediateDirectories: true)
try fileManager.createDirectory(at: masterURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let masterImage = renderIcon(pixels: 1024)
try pngData(from: masterImage).write(to: masterURL, options: .atomic)
print("Wrote \(masterURL.path)")

for output in outputs {
    let image = renderIcon(pixels: output.pixels)
    let outputURL = appIconDirectory.appendingPathComponent(output.filename)
    try pngData(from: image).write(to: outputURL, options: .atomic)
    print("Wrote \(outputURL.path)")
}
