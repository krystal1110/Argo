# Ghostty Pane Split Resize Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build draggable Ghostty pane split dividers so users can resize nested terminal panes, including the confirmed “top one, bottom two” layout.

**Architecture:** Reuse the existing recursive `SessionLayoutNode.split` tree and persisted `PaneSplitNode.fraction`. Add a small testable sizing helper for clamp, drag translation, and size allocation, then wire `SplitNodeView` divider dragging to update the matching split id only. Keep the feature mouse-driven only; no new shortcuts or command palette actions.

**Tech Stack:** Swift, SwiftUI, AppKit cursor APIs, XCTest, Xcode project filesystem-synchronized groups.

---

## File Structure

- Create `Argo/Domain/PaneSplitSizing.swift`
  - Owns split fraction constants, clamp behavior, drag translation math, and min-size-aware pane length allocation.
- Modify `Argo/Domain/PaneLayout.swift`
  - Reuse `PaneSplitSizing.clampedFraction(_:)` in existing fraction mutation paths.
- Modify `Tests/PaneLayoutTests.swift`
  - Adds focused tests for clamp, drag translation, size allocation, and nested split isolation.
- Modify `Argo/UI/Workspace/SplitNodeView.swift`
  - Uses `PaneSplitSizing` for size calculation and fraction updates.
  - Adds hover/drag styling and axis-specific resize cursor handling.

## Task 1: Add Failing Split Sizing And Nested Fraction Tests

**Files:**
- Modify: `Tests/PaneLayoutTests.swift:11-85`

- [ ] **Step 1: Write the failing tests**

Add these methods inside `final class PaneLayoutTests: XCTestCase`, after `testDirectionalFocusUsesSplitAxes()`:

```swift
    func testSplitSizingClampsFractionsAndDragTranslation() {
        XCTAssertEqual(PaneSplitSizing.clampedFraction(-0.5), 0.12, accuracy: 0.0001)
        XCTAssertEqual(PaneSplitSizing.clampedFraction(0.5), 0.5, accuracy: 0.0001)
        XCTAssertEqual(PaneSplitSizing.clampedFraction(1.5), 0.88, accuracy: 0.0001)

        XCTAssertEqual(
            PaneSplitSizing.fraction(startingAt: 0.4, translation: 50, availableLength: 200),
            0.65,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            PaneSplitSizing.fraction(startingAt: 0.4, translation: -500, availableLength: 200),
            0.12,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            PaneSplitSizing.fraction(startingAt: 0.4, translation: 500, availableLength: 200),
            0.88,
            accuracy: 0.0001
        )
    }

    func testSplitSizingAllocatesLengthsWithoutOverflowingContainer() {
        let balanced = PaneSplitSizing.lengths(
            totalLength: 500,
            dividerThickness: 6,
            fraction: 0.5,
            minimumFirst: 120,
            minimumSecond: 120
        )

        XCTAssertEqual(balanced.available, 494, accuracy: 0.0001)
        XCTAssertEqual(balanced.first, 247, accuracy: 0.0001)
        XCTAssertEqual(balanced.second, 247, accuracy: 0.0001)

        let constrained = PaneSplitSizing.lengths(
            totalLength: 220,
            dividerThickness: 6,
            fraction: 0.8,
            minimumFirst: 120,
            minimumSecond: 120
        )

        XCTAssertEqual(constrained.available, 214, accuracy: 0.0001)
        XCTAssertEqual(constrained.first + constrained.second, constrained.available, accuracy: 0.0001)
        XCTAssertGreaterThan(constrained.first, 0)
        XCTAssertGreaterThan(constrained.second, 0)
    }

    func testUpdateFractionClampsAtBounds() {
        let splitID = UUID()
        let first = UUID()
        let second = UUID()
        var layout: SessionLayoutNode = .split(
            PaneSplitNode(
                id: splitID,
                axis: .vertical,
                fraction: 0.5,
                first: .pane(PaneLeaf(paneID: first)),
                second: .pane(PaneLeaf(paneID: second))
            )
        )

        XCTAssertTrue(layout.updateFraction(splitID: splitID, fraction: -1))
        guard case .split(let lowClampedSplit) = layout else {
            return XCTFail("Expected split root")
        }
        XCTAssertEqual(lowClampedSplit.fraction, 0.12, accuracy: 0.0001)

        XCTAssertTrue(layout.updateFraction(splitID: splitID, fraction: 2))
        guard case .split(let highClampedSplit) = layout else {
            return XCTFail("Expected split root")
        }
        XCTAssertEqual(highClampedSplit.fraction, 0.88, accuracy: 0.0001)
    }

    func testNestedUpdateFractionOnlyMutatesTargetSplit() {
        let outerID = UUID()
        let innerID = UUID()
        let top = UUID()
        let bottomLeft = UUID()
        let bottomRight = UUID()

        var layout: SessionLayoutNode = .split(
            PaneSplitNode(
                id: outerID,
                axis: .horizontal,
                fraction: 0.42,
                first: .pane(PaneLeaf(paneID: top)),
                second: .split(
                    PaneSplitNode(
                        id: innerID,
                        axis: .vertical,
                        fraction: 0.5,
                        first: .pane(PaneLeaf(paneID: bottomLeft)),
                        second: .pane(PaneLeaf(paneID: bottomRight))
                    )
                )
            )
        )

        XCTAssertTrue(layout.updateFraction(splitID: innerID, fraction: 0.7))

        guard case .split(let outerAfterInnerUpdate) = layout else {
            return XCTFail("Expected outer split")
        }
        XCTAssertEqual(outerAfterInnerUpdate.fraction, 0.42, accuracy: 0.0001)
        guard case .split(let innerAfterInnerUpdate) = outerAfterInnerUpdate.second else {
            return XCTFail("Expected nested split")
        }
        XCTAssertEqual(innerAfterInnerUpdate.fraction, 0.7, accuracy: 0.0001)

        XCTAssertTrue(layout.updateFraction(splitID: outerID, fraction: 0.3))

        guard case .split(let outerAfterOuterUpdate) = layout else {
            return XCTFail("Expected outer split")
        }
        XCTAssertEqual(outerAfterOuterUpdate.fraction, 0.3, accuracy: 0.0001)
        guard case .split(let innerAfterOuterUpdate) = outerAfterOuterUpdate.second else {
            return XCTFail("Expected nested split")
        }
        XCTAssertEqual(innerAfterOuterUpdate.fraction, 0.7, accuracy: 0.0001)
    }
```

- [ ] **Step 2: Run focused tests to verify RED**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/PaneLayoutTests \
  test
```

Expected: FAIL at compile time with an error like `Cannot find 'PaneSplitSizing' in scope`.

## Task 2: Implement Testable Split Sizing Helper

**Files:**
- Create: `Argo/Domain/PaneSplitSizing.swift`
- Modify: `Argo/Domain/PaneLayout.swift:172-190`
- Modify: `Argo/Domain/PaneLayout.swift:312-330`
- Test: `Tests/PaneLayoutTests.swift`

- [ ] **Step 1: Create the sizing helper**

Create `Argo/Domain/PaneSplitSizing.swift` with:

```swift
//
//  PaneSplitSizing.swift
//  Argo
//
//  Author: krystal
//

import CoreGraphics
import Foundation

enum PaneSplitSizing {
    static let minimumFraction = 0.12
    static let maximumFraction = 0.88

    struct Lengths: Equatable {
        var first: CGFloat
        var second: CGFloat
        var available: CGFloat
    }

    static func clampedFraction(_ fraction: Double) -> Double {
        min(max(fraction, minimumFraction), maximumFraction)
    }

    static func fraction(
        startingAt startFraction: Double,
        translation: CGFloat,
        availableLength: CGFloat
    ) -> Double {
        let delta = Double(translation / max(availableLength, 1))
        return clampedFraction(startFraction + delta)
    }

    static func lengths(
        totalLength: CGFloat,
        dividerThickness: CGFloat,
        fraction: Double,
        minimumFirst: CGFloat,
        minimumSecond: CGFloat
    ) -> Lengths {
        let available = max(totalLength - dividerThickness, 1)
        let clamped = CGFloat(clampedFraction(fraction))

        guard available >= minimumFirst + minimumSecond else {
            let first = available * clamped
            return Lengths(
                first: first,
                second: max(available - first, 0),
                available: available
            )
        }

        let desiredFirst = available * clamped
        let first = min(max(desiredFirst, minimumFirst), available - minimumSecond)
        return Lengths(
            first: first,
            second: max(available - first, 0),
            available: available
        )
    }
}
```

- [ ] **Step 2: Reuse the helper in `updateFraction`**

In `Argo/Domain/PaneLayout.swift`, replace:

```swift
                split.fraction = min(max(fraction, 0.12), 0.88)
```

with:

```swift
                split.fraction = PaneSplitSizing.clampedFraction(fraction)
```

- [ ] **Step 3: Reuse the helper in `adjustFraction`**

In `Argo/Domain/PaneLayout.swift`, replace:

```swift
                split.fraction = min(max(split.fraction + delta, 0.12), 0.88)
```

with:

```swift
                split.fraction = PaneSplitSizing.clampedFraction(split.fraction + delta)
```

- [ ] **Step 4: Run focused tests to verify GREEN**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/PaneLayoutTests \
  test
```

Expected: PASS for `PaneLayoutTests`.

- [ ] **Step 5: Commit helper and model tests**

Run:

```sh
git add Argo/Domain/PaneSplitSizing.swift Argo/Domain/PaneLayout.swift Tests/PaneLayoutTests.swift
git commit -m "test: cover pane split sizing"
```

Expected: commit succeeds.

## Task 3: Wire Draggable Divider UI

**Files:**
- Modify: `Argo/UI/Workspace/SplitNodeView.swift:8-126`
- Test: `Tests/PaneLayoutTests.swift`

- [ ] **Step 1: Replace `SplitNodeView.swift` with the draggable divider implementation**

Replace the contents of `Argo/UI/Workspace/SplitNodeView.swift` with:

```swift
//
//  SplitNodeView.swift
//  Argo
//
//  Author: krystal
//

import AppKit
import SwiftUI

struct SplitNodeView: View {
    @ObservedObject var workspace: WorkspaceModel
    @ObservedObject var sessionController: WorkspaceSessionController
    let node: SessionLayoutNode

    var body: some View {
        Group {
            if let zoomedPaneID = workspace.zoomedPaneID {
                if let session = sessionController.session(for: zoomedPaneID) {
                    TerminalPaneView(workspace: workspace, sessionController: sessionController, session: session, paneID: zoomedPaneID)
                        .id(zoomedPaneID)
                } else {
                    Color.clear
                }
            } else {
                switch node {
                case .pane(let leaf):
                    if let session = sessionController.session(for: leaf.paneID) {
                        TerminalPaneView(workspace: workspace, sessionController: sessionController, session: session, paneID: leaf.paneID)
                            .id(leaf.paneID)
                    } else {
                        Color.clear
                    }
                case .split(let split):
                    GeometryReader { geometry in
                        splitBody(split, in: geometry.size)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func splitBody(_ split: PaneSplitNode, in size: CGSize) -> some View {
        let dividerThickness: CGFloat = 6
        let clampedFraction = PaneSplitSizing.clampedFraction(split.fraction)

        if split.axis == .vertical {
            let lengths = PaneSplitSizing.lengths(
                totalLength: size.width,
                dividerThickness: dividerThickness,
                fraction: clampedFraction,
                minimumFirst: 120,
                minimumSecond: 120
            )

            HStack(spacing: 0) {
                SplitNodeView(workspace: workspace, sessionController: sessionController, node: split.first)
                    .frame(width: lengths.first)
                SplitDivider(
                    axis: .vertical,
                    fraction: clampedFraction,
                    availableLength: lengths.available
                ) { fraction in
                    workspace.updateSplitFraction(splitID: split.id, fraction: fraction)
                }
                    .frame(width: dividerThickness)
                SplitNodeView(workspace: workspace, sessionController: sessionController, node: split.second)
                    .frame(width: lengths.second)
            }
        } else {
            let lengths = PaneSplitSizing.lengths(
                totalLength: size.height,
                dividerThickness: dividerThickness,
                fraction: clampedFraction,
                minimumFirst: 90,
                minimumSecond: 90
            )

            VStack(spacing: 0) {
                SplitNodeView(workspace: workspace, sessionController: sessionController, node: split.first)
                    .frame(height: lengths.first)
                SplitDivider(
                    axis: .horizontal,
                    fraction: clampedFraction,
                    availableLength: lengths.available
                ) { fraction in
                    workspace.updateSplitFraction(splitID: split.id, fraction: fraction)
                }
                    .frame(height: dividerThickness)
                SplitNodeView(workspace: workspace, sessionController: sessionController, node: split.second)
                    .frame(height: lengths.second)
            }
        }
    }
}

private struct SplitDivider: View {
    let axis: PaneSplitAxis
    let fraction: Double
    let availableLength: CGFloat
    let onUpdate: (Double) -> Void

    @State private var dragStartFraction: Double?
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var didPushCursor = false

    private var isActive: Bool {
        isHovering || isDragging
    }

    private var resizeCursor: NSCursor {
        axis == .vertical ? .resizeLeftRight : .resizeUpDown
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isActive ? Color.white.opacity(0.06) : Color.clear)
            Capsule(style: .continuous)
                .fill(Color.white.opacity(isActive ? 0.18 : 0.08))
                .frame(width: axis == .vertical ? 4 : 44, height: axis == .horizontal ? 4 : 44)
            Capsule(style: .continuous)
                .fill(isActive ? Color.white.opacity(0.72) : ArgoTheme.strongBorder)
                .frame(width: axis == .vertical ? 2 : 16, height: axis == .horizontal ? 2 : 16)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            setCursorVisible(hovering || isDragging)
        }
        .onDisappear {
            setCursorVisible(false)
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let startFraction = dragStartFraction ?? fraction
                    if dragStartFraction == nil {
                        dragStartFraction = fraction
                        isDragging = true
                        setCursorVisible(true)
                    }
                    let translation = axis == .vertical
                        ? value.translation.width
                        : value.translation.height
                    onUpdate(
                        PaneSplitSizing.fraction(
                            startingAt: startFraction,
                            translation: translation,
                            availableLength: availableLength
                        )
                    )
                }
                .onEnded { _ in
                    dragStartFraction = nil
                    isDragging = false
                    setCursorVisible(isHovering)
                }
        )
    }

    private func setCursorVisible(_ visible: Bool) {
        if visible, !didPushCursor {
            resizeCursor.push()
            didPushCursor = true
        } else if !visible, didPushCursor {
            NSCursor.pop()
            didPushCursor = false
        }
    }
}
```

- [ ] **Step 2: Run focused tests after UI wiring**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/PaneLayoutTests \
  test
```

Expected: PASS for `PaneLayoutTests`.

- [ ] **Step 3: Build the app to catch SwiftUI/AppKit compile issues**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit UI wiring**

Run:

```sh
git add Argo/UI/Workspace/SplitNodeView.swift
git commit -m "feat: resize terminal panes by dragging dividers"
```

Expected: commit succeeds.

## Task 4: Final Verification And Manual Smoke

**Files:**
- Verify: `Argo/UI/Workspace/SplitNodeView.swift`
- Verify: `Argo/Domain/PaneSplitSizing.swift`
- Verify: `Tests/PaneLayoutTests.swift`

- [ ] **Step 1: Run focused layout tests**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/PaneLayoutTests \
  test
```

Expected: PASS for `PaneLayoutTests`.

- [ ] **Step 2: Run app build**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual smoke test the confirmed nested layout**

Run the app, then perform this smoke test:

```text
1. Open a workspace with one terminal pane.
2. Split down so the layout has top and bottom panes.
3. Focus the bottom pane and split right so the layout is top one, bottom two.
4. Drag the middle horizontal divider.
5. Confirm only top vs bottom changes.
6. Drag the lower vertical divider.
7. Confirm only lower left vs lower right changes.
8. Move the pointer over each divider and confirm the cursor changes to row-resize or column-resize.
9. Switch away and back, or close and reopen the workspace.
10. Confirm the adjusted ratios persist.
```

Expected: behavior matches the approved HTML prototype.

- [ ] **Step 4: Inspect git status**

Run:

```sh
git status --short
```

Expected: clean working tree, or only intentionally uncommitted verification artifacts.
