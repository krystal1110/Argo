# Terminal Image Paste Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add macOS image clipboard paste support for local and agent Ghostty terminal sessions so `claude` receives a usable image file path.

**Architecture:** Add a focused terminal image paste helper that extracts image file URLs or in-memory image data from `NSPasteboard`, saves in-memory images under `.argo/pasted-images/`, and builds shell-escaped bracketed paste text. Wire `ArgoGhosttySurfaceView.paste(_:)` to try the helper only for local shell and agent sessions, then fall back to Ghostty's existing text paste behavior.

**Tech Stack:** Swift, AppKit `NSPasteboard`/`NSImage`/`NSBitmapImageRep`, GhosttyKit terminal text injection, XCTest.

---

## File Structure

- Create `Argo/Services/Terminal/TerminalImagePasteSupport.swift`: helper functions for image paste detection, PNG writing, payload construction, and bracketed paste wrapping.
- Modify `Argo/Services/Terminal/Ghostty/ArgoGhosttyController.swift`: store the latest local working directory and intercept `paste(_:)` for supported backend kinds.
- Create `Tests/TerminalImagePasteSupportTests.swift`: focused tests for helper behavior.
- Modify no Xcode project files: this project uses file-system synchronized root groups, so new Swift files under `Argo/` and `Tests/` are automatically included.

## Task 1: Add Terminal Image Paste Helper Tests

**Files:**
- Create: `Tests/TerminalImagePasteSupportTests.swift`

- [ ] **Step 1: Write failing helper tests**

Create `Tests/TerminalImagePasteSupportTests.swift`:

```swift
//
//  TerminalImagePasteSupportTests.swift
//  ArgoTests
//
//  Author: krystal
//

import AppKit
import XCTest
@testable import Argo

final class TerminalImagePasteSupportTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
        try super.tearDownWithError()
    }

    func testBracketedPasteTextWrapsPayload() {
        XCTAssertEqual(
            ArgoTerminalImagePasteSupport.bracketedPasteText(for: "/tmp/a\\ b.png"),
            "\u{1B}[200~/tmp/a\\ b.png\u{1B}[201~"
        )
    }

    func testImageFileURLsProduceShellEscapedPayload() throws {
        let directory = try makeTemporaryDirectory(named: "image files")
        let imageURL = directory.appendingPathComponent("screen shot.png")
        FileManager.default.createFile(atPath: imageURL.path, contents: Data([0x89, 0x50, 0x4E, 0x47]))

        let pasteboard = makePasteboard()
        pasteboard.writeObjects([imageURL as NSURL])

        XCTAssertEqual(
            ArgoTerminalImagePasteSupport.imagePastePayload(from: pasteboard, workingDirectory: directory),
            imageURL.path.shellEscaped
        )
    }

    func testNonImageFileURLsAreIgnored() throws {
        let directory = try makeTemporaryDirectory(named: "plain files")
        let textURL = directory.appendingPathComponent("notes.txt")
        FileManager.default.createFile(atPath: textURL.path, contents: Data("hello".utf8))

        let pasteboard = makePasteboard()
        pasteboard.writeObjects([textURL as NSURL])

        XCTAssertNil(
            ArgoTerminalImagePasteSupport.imagePastePayload(from: pasteboard, workingDirectory: directory)
        )
    }

    func testPNGClipboardDataIsSavedUnderArgoPastedImages() throws {
        let workingDirectory = try makeTemporaryDirectory(named: "workspace")
        let pasteboard = makePasteboard()
        pasteboard.setData(try makePNGData(), forType: .png)

        let payload = try XCTUnwrap(
            ArgoTerminalImagePasteSupport.imagePastePayload(
                from: pasteboard,
                workingDirectory: workingDirectory,
                date: Date(timeIntervalSince1970: 1_780_444_800),
                uuid: UUID(uuidString: "12345678-90AB-CDEF-1234-567890ABCDEF")!
            )
        )

        let imagesDirectory = workingDirectory
            .appendingPathComponent(".argo", isDirectory: true)
            .appendingPathComponent("pasted-images", isDirectory: true)
        let savedFiles = try FileManager.default.contentsOfDirectory(
            at: imagesDirectory,
            includingPropertiesForKeys: nil
        )

        XCTAssertEqual(savedFiles.count, 1)
        XCTAssertEqual(savedFiles[0].lastPathComponent, "pasted-image-20260603-000000-12345678.png")
        XCTAssertEqual(payload, savedFiles[0].path.shellEscaped)
        XCTAssertGreaterThan(try Data(contentsOf: savedFiles[0]).count, 0)
    }

    func testTIFFClipboardDataIsConvertedToPNG() throws {
        let workingDirectory = try makeTemporaryDirectory(named: "workspace tiff")
        let pasteboard = makePasteboard()
        pasteboard.setData(try makeTIFFData(), forType: .tiff)

        let payload = try XCTUnwrap(
            ArgoTerminalImagePasteSupport.imagePastePayload(
                from: pasteboard,
                workingDirectory: workingDirectory,
                date: Date(timeIntervalSince1970: 1_780_444_800),
                uuid: UUID(uuidString: "ABCDEF12-3456-7890-ABCD-EF1234567890")!
            )
        )

        let savedURL = workingDirectory
            .appendingPathComponent(".argo", isDirectory: true)
            .appendingPathComponent("pasted-images", isDirectory: true)
            .appendingPathComponent("pasted-image-20260603-000000-abcdef12.png")

        XCTAssertEqual(payload, savedURL.path.shellEscaped)
        let savedData = try Data(contentsOf: savedURL)
        XCTAssertTrue(savedData.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    private func makePasteboard() -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("argo.tests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        return pasteboard
    }

    private func makeTemporaryDirectory(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-image-paste-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory.deletingLastPathComponent())
        return directory
    }

    private func makePNGData() throws -> Data {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw XCTSkip("Could not create PNG test data.")
        }
        return data
    }

    private func makeTIFFData() throws -> Data {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()

        guard let data = image.tiffRepresentation else {
            throw XCTSkip("Could not create TIFF test data.")
        }
        return data
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/TerminalImagePasteSupportTests \
  test
```

Expected: FAIL because `ArgoTerminalImagePasteSupport` does not exist.

- [ ] **Step 3: Commit failing tests**

```sh
git add Tests/TerminalImagePasteSupportTests.swift
git commit -m "test: cover terminal image paste helper"
```

## Task 2: Implement Terminal Image Paste Helper

**Files:**
- Create: `Argo/Services/Terminal/TerminalImagePasteSupport.swift`
- Test: `Tests/TerminalImagePasteSupportTests.swift`

- [ ] **Step 1: Add the helper implementation**

Create `Argo/Services/Terminal/TerminalImagePasteSupport.swift`:

```swift
//
//  TerminalImagePasteSupport.swift
//  Argo
//
//  Author: krystal
//

import AppKit
import Foundation

enum ArgoTerminalImagePasteSupport {
    private static let supportedImageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "heic", "tif", "tiff", "bmp",
    ]

    static func bracketedPasteText(for payload: String) -> String {
        "\u{1B}[200~\(payload)\u{1B}[201~"
    }

    static func imagePastePayload(
        from pasteboard: NSPasteboard,
        workingDirectory: URL,
        date: Date = Date(),
        uuid: UUID = UUID()
    ) -> String? {
        let fileURLs = imageFileURLs(from: pasteboard)
        if !fileURLs.isEmpty {
            return payload(forImageFileURLs: fileURLs)
        }

        guard let imageData = pngImageData(from: pasteboard) else {
            return nil
        }

        return saveImageData(
            imageData,
            workingDirectory: workingDirectory,
            date: date,
            uuid: uuid
        )?.path.shellEscaped
    }

    private static func imageFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []

        return objects.filter(isSupportedImageFile)
    }

    private static func payload(forImageFileURLs fileURLs: [URL]) -> String? {
        let paths = fileURLs
            .filter(\.isFileURL)
            .map(\.path)
            .filter { !$0.isEmpty }
            .map(\.shellEscaped)

        guard !paths.isEmpty else { return nil }
        return paths.joined(separator: " ")
    }

    private static func isSupportedImageFile(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        return supportedImageExtensions.contains(url.pathExtension.lowercased())
    }

    private static func pngImageData(from pasteboard: NSPasteboard) -> Data? {
        if let data = pasteboard.data(forType: .png), !data.isEmpty {
            return data
        }

        if let data = pasteboard.data(forType: .tiff),
           let converted = pngData(fromImageData: data) {
            return converted
        }

        guard let image = NSImage(pasteboard: pasteboard) else {
            return nil
        }
        return pngData(from: image)
    }

    private static func pngData(fromImageData data: Data) -> Data? {
        guard let bitmap = NSBitmapImageRep(data: data) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation else { return nil }
        return pngData(fromImageData: tiff)
    }

    private static func saveImageData(
        _ data: Data,
        workingDirectory: URL,
        date: Date,
        uuid: UUID
    ) -> URL? {
        let directory = workingDirectory
            .appendingPathComponent(".argo", isDirectory: true)
            .appendingPathComponent("pasted-images", isDirectory: true)
        let fileURL = directory.appendingPathComponent(filename(date: date, uuid: uuid))

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    private static func filename(date: Date, uuid: UUID) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: date)
        let suffix = uuid.uuidString.prefix(8).lowercased()
        return "pasted-image-\(timestamp)-\(suffix).png"
    }
}
```

- [ ] **Step 2: Run helper tests**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/TerminalImagePasteSupportTests \
  test
```

Expected: PASS for all `TerminalImagePasteSupportTests`.

- [ ] **Step 3: Commit helper implementation**

```sh
git add Argo/Services/Terminal/TerminalImagePasteSupport.swift Tests/TerminalImagePasteSupportTests.swift
git commit -m "feat: add terminal image paste helper"
```

## Task 3: Wire Image Paste Into Ghostty Terminal Paste

**Files:**
- Modify: `Argo/Services/Terminal/Ghostty/ArgoGhosttyController.swift`
- Test: `Tests/TerminalImagePasteSupportTests.swift`

- [ ] **Step 1: Track local working directory on the Ghostty surface view**

In `Argo/Services/Terminal/Ghostty/ArgoGhosttyController.swift`, add a property near `backendConfiguration` inside `ArgoGhosttySurfaceView`:

```swift
private var backendConfiguration: SessionBackendConfiguration = .local()
private var localWorkingDirectory: String?
private var handledTextInputCommand = false
```

In `handleGhosttyAction(_:on:)`, update the `GHOSTTY_ACTION_PWD` case:

```swift
case GHOSTTY_ACTION_PWD:
    let workingDirectory = action.action.pwd.pwd.map(String.init(cString:))
    terminalView.updateLocalWorkingDirectory(workingDirectory)
    DispatchQueue.main.async { [weak self] in
        self?.onWorkingDirectoryChange?(workingDirectory)
    }
    return true
```

Add this method inside `ArgoGhosttySurfaceView`, near `insertTerminalText(_:)`:

```swift
func updateLocalWorkingDirectory(_ workingDirectory: String?) {
    localWorkingDirectory = workingDirectory
}
```

In `createSurface(runtime:launchConfiguration:)`, set the initial fallback working directory immediately after `backendConfiguration`:

```swift
backendConfiguration = launchConfiguration.backendConfiguration
localWorkingDirectory = launchConfiguration.workingDirectory
```

- [ ] **Step 2: Add image paste interception**

Replace `paste(_:)` in `ArgoGhosttySurfaceView`:

```swift
@IBAction func paste(_ sender: Any?) {
    if let imagePasteText = imagePasteTextFromClipboard() {
        sendText(imagePasteText)
        return
    }

    _ = performBindingAction("paste_from_clipboard")
}
```

Add the helper methods near `paste(_:)`:

```swift
private func imagePasteTextFromClipboard() -> String? {
    guard supportsLocalImagePaste,
          let workingDirectory = imagePasteWorkingDirectory else {
        return nil
    }

    guard let payload = ArgoTerminalImagePasteSupport.imagePastePayload(
        from: .general,
        workingDirectory: workingDirectory
    ) else {
        return nil
    }

    return ArgoTerminalImagePasteSupport.bracketedPasteText(for: payload)
}

private var supportsLocalImagePaste: Bool {
    switch backendConfiguration.kind {
    case .localShell, .agent:
        return true
    case .ssh, .tmuxAttach:
        return false
    }
}

private var imagePasteWorkingDirectory: URL? {
    guard let localWorkingDirectory, !localWorkingDirectory.isEmpty else {
        return nil
    }
    return URL(fileURLWithPath: localWorkingDirectory, isDirectory: true)
}
```

- [ ] **Step 3: Add unit coverage for backend gating logic as a pure helper**

To keep view-private behavior testable without constructing Ghostty surfaces, extend `Argo/Services/Terminal/TerminalImagePasteSupport.swift`:

```swift
static func supportsImagePaste(backendKind: SessionBackendKind) -> Bool {
    switch backendKind {
    case .localShell, .agent:
        return true
    case .ssh, .tmuxAttach:
        return false
    }
}
```

Then update `supportsLocalImagePaste` in `ArgoGhosttyController.swift`:

```swift
private var supportsLocalImagePaste: Bool {
    ArgoTerminalImagePasteSupport.supportsImagePaste(backendKind: backendConfiguration.kind)
}
```

Add tests to `Tests/TerminalImagePasteSupportTests.swift`:

```swift
func testImagePasteIsSupportedForLocalAndAgentBackends() {
    XCTAssertTrue(ArgoTerminalImagePasteSupport.supportsImagePaste(backendKind: .localShell))
    XCTAssertTrue(ArgoTerminalImagePasteSupport.supportsImagePaste(backendKind: .agent))
}

func testImagePasteIsNotSupportedForRemoteBackends() {
    XCTAssertFalse(ArgoTerminalImagePasteSupport.supportsImagePaste(backendKind: .ssh))
    XCTAssertFalse(ArgoTerminalImagePasteSupport.supportsImagePaste(backendKind: .tmuxAttach))
}
```

- [ ] **Step 4: Run focused tests**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/TerminalImagePasteSupportTests \
  test
```

Expected: PASS for all `TerminalImagePasteSupportTests`.

- [ ] **Step 5: Commit Ghostty paste integration**

```sh
git add Argo/Services/Terminal/Ghostty/ArgoGhosttyController.swift Argo/Services/Terminal/TerminalImagePasteSupport.swift Tests/TerminalImagePasteSupportTests.swift
git commit -m "feat: paste clipboard images into terminal"
```

## Task 4: Full Verification

**Files:**
- Verify: `Argo/Services/Terminal/TerminalImagePasteSupport.swift`
- Verify: `Argo/Services/Terminal/Ghostty/ArgoGhosttyController.swift`
- Verify: `Tests/TerminalImagePasteSupportTests.swift`

- [ ] **Step 1: Run the full test suite**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  test
```

Expected: PASS.

- [ ] **Step 2: Run a manual smoke test**

Manual steps:

```text
1. Launch Argo.
2. Open a local workspace terminal or agent session running `claude`.
3. Copy a screenshot to the clipboard with macOS screenshot tools.
4. Focus the terminal pane and press Cmd+V.
5. Confirm a .png file appears under .argo/pasted-images/ in the terminal working directory.
6. Confirm the terminal input receives the shell-escaped image path as pasted input.
7. Press Enter in Claude and confirm Claude accepts the image path.
8. Open an SSH or tmux-backed pane and press Cmd+V with the same clipboard; confirm Argo preserves the existing Ghostty paste behavior instead of inserting a local image path.
```

- [ ] **Step 3: Check final git diff**

Run:

```sh
git status --short
git diff --stat HEAD
```

Expected: only the intended implementation files changed after the last commit, or a clean working tree if every task commit was made.
