# Argo App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Argo's macOS app icon with the approved Terminal Constellation design and generate the complete AppIcon asset set.

**Architecture:** Use a deterministic Swift/AppKit drawing script so the icon can be regenerated from source instead of depending on a temporary design export. The script renders a 1024px master, archives it under `docs/assets/`, then writes all PNG sizes referenced by `Argo/Assets.xcassets/AppIcon.appiconset/Contents.json`.

**Tech Stack:** Swift 6 script, AppKit drawing APIs, Xcode asset catalog, `sips`, `xcodebuild`.

---

## File Structure

- Create `scripts/generate_app_icon.swift`: project-local generator for the Terminal Constellation icon. It owns all drawing constants, master export, and size-specific PNG output.
- Create `docs/assets/argo-app-icon-terminal-constellation-1024.png`: archived generated master image.
- Modify `Argo/Assets.xcassets/AppIcon.appiconset/appicon_*.png`: generated replacement icon assets for all existing macOS AppIcon slots.
- Do not modify `Argo/Assets.xcassets/AppIcon.appiconset/Contents.json`: the current manifest already references the exact filenames and sizes needed.
- Do not modify unrelated UI icon components or theme files.

## Task 1: Add the Deterministic Icon Generator

**Files:**
- Create: `scripts/generate_app_icon.swift`

- [ ] **Step 1: Create the generator script**

Create `scripts/generate_app_icon.swift` with this content:

```swift
#!/usr/bin/env swift

import AppKit
import Foundation

struct IconOutput {
    let filename: String
    let pixels: Int
}

let fileManager = FileManager.default
let projectRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let appIconDirectory = projectRoot.appendingPathComponent("Argo/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let masterURL = projectRoot.appendingPathComponent("docs/assets/argo-app-icon-terminal-constellation-1024.png")

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

func renderIcon(pixels: Int) -> NSImage {
    let canvas = CGFloat(pixels)
    let scale = canvas / 1024
    let image = NSImage(size: NSSize(width: canvas, height: canvas))

    image.lockFocus()
    guard let context = NSGraphicsContext.current else {
        fatalError("Unable to create graphics context")
    }

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

    image.unlockFocus()
    return image
}

func pngData(from image: NSImage) -> Data {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
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
```

- [ ] **Step 2: Make the script executable**

Run:

```sh
chmod +x scripts/generate_app_icon.swift
```

Expected: command exits with status 0.

- [ ] **Step 3: Commit the generator**

Run:

```sh
git add scripts/generate_app_icon.swift
git commit -m "Add Argo app icon generator"
```

Expected: a commit containing only `scripts/generate_app_icon.swift`.

## Task 2: Generate and Validate Icon Assets

**Files:**
- Create: `docs/assets/argo-app-icon-terminal-constellation-1024.png`
- Modify: `Argo/Assets.xcassets/AppIcon.appiconset/appicon_16x16.png`
- Modify: `Argo/Assets.xcassets/AppIcon.appiconset/appicon_16x16@2x.png`
- Modify: `Argo/Assets.xcassets/AppIcon.appiconset/appicon_32x32.png`
- Modify: `Argo/Assets.xcassets/AppIcon.appiconset/appicon_32x32@2x.png`
- Modify: `Argo/Assets.xcassets/AppIcon.appiconset/appicon_128x128.png`
- Modify: `Argo/Assets.xcassets/AppIcon.appiconset/appicon_128x128@2x.png`
- Modify: `Argo/Assets.xcassets/AppIcon.appiconset/appicon_256x256.png`
- Modify: `Argo/Assets.xcassets/AppIcon.appiconset/appicon_256x256@2x.png`
- Modify: `Argo/Assets.xcassets/AppIcon.appiconset/appicon_512x512.png`
- Modify: `Argo/Assets.xcassets/AppIcon.appiconset/appicon_512x512@2x.png`

- [ ] **Step 1: Generate the master and AppIcon PNG files**

Run:

```sh
swift scripts/generate_app_icon.swift
```

Expected output includes:

```text
Wrote /Users/liaojingyu/.codex/worktrees/c574/argo/docs/assets/argo-app-icon-terminal-constellation-1024.png
Wrote /Users/liaojingyu/.codex/worktrees/c574/argo/Argo/Assets.xcassets/AppIcon.appiconset/appicon_16x16.png
Wrote /Users/liaojingyu/.codex/worktrees/c574/argo/Argo/Assets.xcassets/AppIcon.appiconset/appicon_512x512@2x.png
```

- [ ] **Step 2: Verify every generated AppIcon slot has the expected pixel size**

Run:

```sh
for f in Argo/Assets.xcassets/AppIcon.appiconset/appicon_*.png; do
  printf '%s ' "$f"
  sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | awk '/pixelWidth|pixelHeight/{printf "%s ", $2} END{print ""}'
done | sort
```

Expected output:

```text
Argo/Assets.xcassets/AppIcon.appiconset/appicon_128x128.png 128 128 
Argo/Assets.xcassets/AppIcon.appiconset/appicon_128x128@2x.png 256 256 
Argo/Assets.xcassets/AppIcon.appiconset/appicon_16x16.png 16 16 
Argo/Assets.xcassets/AppIcon.appiconset/appicon_16x16@2x.png 32 32 
Argo/Assets.xcassets/AppIcon.appiconset/appicon_256x256.png 256 256 
Argo/Assets.xcassets/AppIcon.appiconset/appicon_256x256@2x.png 512 512 
Argo/Assets.xcassets/AppIcon.appiconset/appicon_32x32.png 32 32 
Argo/Assets.xcassets/AppIcon.appiconset/appicon_32x32@2x.png 64 64 
Argo/Assets.xcassets/AppIcon.appiconset/appicon_512x512.png 512 512 
Argo/Assets.xcassets/AppIcon.appiconset/appicon_512x512@2x.png 1024 1024 
```

- [ ] **Step 3: Visually inspect the master icon**

Use the local image viewer tool on:

```text
/Users/liaojingyu/.codex/worktrees/c574/argo/docs/assets/argo-app-icon-terminal-constellation-1024.png
```

Expected visual result:

- Dark macOS rounded icon base.
- Bright terminal panel in the lower-middle area.
- Prompt chevron and cursor are clearly visible.
- Constellation/orbit details are visible but secondary.
- Palette balances dark neutral, blue, cyan, and teal.

- [ ] **Step 4: Visually inspect small icon sizes**

Use the local image viewer tool on:

```text
/Users/liaojingyu/.codex/worktrees/c574/argo/Argo/Assets.xcassets/AppIcon.appiconset/appicon_32x32.png
/Users/liaojingyu/.codex/worktrees/c574/argo/Argo/Assets.xcassets/AppIcon.appiconset/appicon_16x16.png
```

Expected visual result:

- At 32px, the icon still reads as a terminal/prompt on a dark base.
- At 16px, constellation details may collapse, but the dark base plus bright terminal signal remains recognizable.

- [ ] **Step 5: Commit generated assets**

Run:

```sh
git add docs/assets/argo-app-icon-terminal-constellation-1024.png Argo/Assets.xcassets/AppIcon.appiconset/appicon_*.png
git commit -m "Replace Argo app icon assets"
```

Expected: a commit containing only the master PNG and AppIcon PNG replacements.

## Task 3: Build Verification

**Files:**
- No source files should change in this task.

- [ ] **Step 1: Confirm the asset catalog manifest is unchanged**

Run:

```sh
git diff -- Argo/Assets.xcassets/AppIcon.appiconset/Contents.json
```

Expected: no output.

- [ ] **Step 2: Build Argo with the updated AppIcon assets**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Confirm only app-icon-related files are changed after commits**

Run:

```sh
git status --short
```

Expected: no app-icon files remain unstaged or uncommitted. Pre-existing unrelated files may still appear, such as UI component edits that were present before this plan began.

- [ ] **Step 4: Commit verification notes if any documentation was adjusted**

If implementation required updating this plan or the design spec, commit only those documentation changes:

```sh
git add docs/superpowers/specs/2026-06-03-argo-app-icon-design.md docs/superpowers/plans/2026-06-03-argo-app-icon-implementation.md
git commit -m "Update Argo app icon implementation notes"
```

Expected: skip this step when there are no documentation changes.
