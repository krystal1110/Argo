# Active Pane Focus Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make split terminal panes clearly show focus by keeping the active pane normal, dimming inactive panes with a translucent overlay, and showing one top path chip per visible pane.

**Architecture:** Keep the existing shared `TerminalLocalChrome` above `SplitNodeView`. Add a small pane descriptor model that `WorkspaceSessionDetailView` builds from `workspace.paneOrder`; `TerminalLocalChrome` renders pane chips from those descriptors, while `TerminalPaneView` receives a boolean that controls inactive dimming.

**Tech Stack:** Swift, SwiftUI, AppKit-hosted terminal views, XCTest source-level checks, Xcode project `Argo.xcodeproj`.

---

## File Structure

- Modify `Argo/UI/Workspace/TerminalLocalChrome.swift`
  - Add `TerminalChromePaneDescriptor`.
  - Add `paneDescriptors` and `onSelectPane` inputs.
  - Render pane chips when the active tab has multiple visible panes.
  - Preserve existing tab buttons for single-pane multi-tab cases, and preserve the single path pill for one-pane one-tab cases.
- Modify `Argo/UI/Workspace/WorkspaceDetailView.swift`
  - Build pane descriptors from `workspace.paneOrder`.
  - Pass descriptors and chip-click focus closure into `TerminalLocalChrome`.
  - Pass inactive-dimming state into `SplitNodeView`.
- Modify `Argo/UI/Workspace/SplitNodeView.swift`
  - Add `dimsInactivePanes` input.
  - Propagate it through recursive split nodes.
  - Disable dimming for zoomed pane rendering.
- Modify `Argo/UI/Workspace/TerminalPaneView.swift`
  - Add `dimsWhenInactive` input.
  - Add a visual-only inactive overlay over the terminal host region.
- Modify `Tests/WorkspaceTabsTests.swift`
  - Add source-level checks for pane descriptors, chip focus callbacks, and inactive overlay plumbing.

---

### Task 1: Add Failing Source Tests For Pane Chips

**Files:**
- Modify: `Tests/WorkspaceTabsTests.swift`

- [ ] **Step 1: Add tests that describe pane-chip plumbing**

Append these tests inside `final class WorkspaceTabsTests: XCTestCase`, after `testTerminalTabsUseIntegratedChromeInsteadOfSeparateTopStrip()`:

```swift
    func testSplitPaneChromeUsesPaneDescriptorsAndFocusCallback() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let workspaceDetailSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"),
            encoding: .utf8
        )
        let terminalChromeSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalLocalChrome.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(terminalChromeSource.contains("struct TerminalChromePaneDescriptor"))
        XCTAssertTrue(terminalChromeSource.contains("let paneDescriptors: [TerminalChromePaneDescriptor]"))
        XCTAssertTrue(terminalChromeSource.contains("ForEach(paneDescriptors)"))
        XCTAssertTrue(terminalChromeSource.contains("onSelectPane(descriptor.paneID)"))
        XCTAssertTrue(workspaceDetailSource.contains("paneDescriptors: terminalChromePaneDescriptors"))
        XCTAssertTrue(workspaceDetailSource.contains("onSelectPane: focusTerminalPaneFromChrome"))
    }

    func testSplitPaneChromeKeepsSinglePanePathPillFallback() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let terminalChromeSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalLocalChrome.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(terminalChromeSource.contains("if paneDescriptors.count > 1"))
        XCTAssertTrue(terminalChromeSource.contains("} else if tabs.count > 1 {"))
        XCTAssertTrue(terminalChromeSource.contains("pathPill"))
    }
```

- [ ] **Step 2: Run the tests and verify they fail**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceTabsTests \
  test
```

Expected: the new tests fail because `TerminalChromePaneDescriptor`, `paneDescriptors`, and `focusTerminalPaneFromChrome` do not exist yet.

---

### Task 2: Implement Pane Descriptors And Top Pane Chips

**Files:**
- Modify: `Argo/UI/Workspace/TerminalLocalChrome.swift`
- Modify: `Argo/UI/Workspace/WorkspaceDetailView.swift`
- Test: `Tests/WorkspaceTabsTests.swift`

- [ ] **Step 1: Add the descriptor and new inputs**

In `Argo/UI/Workspace/TerminalLocalChrome.swift`, insert this descriptor above `struct TerminalLocalChrome`:

```swift
struct TerminalChromePaneDescriptor: Identifiable, Equatable {
    let paneID: UUID
    let path: String
    let isFocused: Bool

    var id: UUID { paneID }
}
```

Then update the stored properties in `TerminalLocalChrome` to include:

```swift
    let paneDescriptors: [TerminalChromePaneDescriptor]
    let onSelectPane: (UUID) -> Void
```

- [ ] **Step 2: Add pane-chip rendering**

Replace the current `tabArea` computed property in `TerminalLocalChrome` with:

```swift
    @ViewBuilder
    private var tabArea: some View {
        if paneDescriptors.count > 1 {
            paneChipStrip
        } else if tabs.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tabs) { tab in
                        TerminalChromeTabButton(
                            title: tab.title,
                            paneCount: paneCountForTab(tab.id),
                            isSelected: tab.id == activeTabID,
                            canClose: tabs.count > 1,
                            onSelect: {
                                onSelectTab(tab.id)
                            },
                            onClose: {
                                onCloseTab(tab.id)
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        } else {
            pathPill
        }
    }
```

Add these views below `tabArea`:

```swift
    private var paneChipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(paneDescriptors) { descriptor in
                    TerminalChromePaneChip(
                        descriptor: descriptor,
                        onSelect: {
                            onSelectPane(descriptor.paneID)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }
```

Add this chip view below `TerminalChromeTabButton`:

```swift
private struct TerminalChromePaneChip: View {
    let descriptor: TerminalChromePaneDescriptor
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(foreground.opacity(descriptor.isFocused ? 0.92 : 0.62))

                Text(descriptor.path)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .frame(width: 190, height: 32)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
        .background(backgroundFill, in: Capsule())
        .overlay(Capsule().stroke(borderColor, lineWidth: descriptor.isFocused ? 1 : 0.8))
        .shadow(color: .black.opacity(descriptor.isFocused ? 0.16 : 0), radius: 8, y: 3)
        .accessibilityLabel("Focus pane \(descriptor.path)")
        .help(descriptor.path)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var foreground: Color {
        descriptor.isFocused ? Color.white.opacity(0.94) : Color.white.opacity(isHovered ? 0.70 : 0.44)
    }

    private var backgroundFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(descriptor.isFocused ? 0.28 : (isHovered ? 0.09 : 0.0)),
                Color.white.opacity(descriptor.isFocused ? 0.18 : (isHovered ? 0.045 : 0.0))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var borderColor: Color {
        if descriptor.isFocused {
            return Color.white.opacity(0.22)
        }
        return Color.white.opacity(isHovered ? 0.10 : 0.0)
    }
}
```

- [ ] **Step 3: Build descriptors in `WorkspaceSessionDetailView`**

In `Argo/UI/Workspace/WorkspaceDetailView.swift`, update the `TerminalLocalChrome` call to include the new inputs:

```swift
                    TerminalLocalChrome(
                        path: terminalChromePath,
                        paneDescriptors: terminalChromePaneDescriptors,
                        tabs: workspace.tabs,
                        activeTabID: workspace.activeTabID,
                        isFocused: terminalChromeTargetPaneID == workspace.sessionController.focusedPaneID,
                        canCreateTab: true,
                        canSplit: terminalChromeTargetPaneID != nil,
                        paneCountForTab: { tabID in
                            workspace.paneCount(for: tabID)
                        },
                        onSelectTab: selectTerminalTabFromChrome,
                        onCloseTab: closeTerminalTabFromChrome,
                        onSelectPane: focusTerminalPaneFromChrome,
                        onCreateTab: createTerminalTabFromChrome,
                        onSplitRight: {
                            splitTerminalFromChrome(axis: .vertical)
                        },
                        onSplitDown: {
                            splitTerminalFromChrome(axis: .horizontal)
                        }
                    )
```

Add this computed property near `terminalChromePath`:

```swift
    private var terminalChromePaneDescriptors: [TerminalChromePaneDescriptor] {
        if let zoomedPaneID = workspace.zoomedPaneID,
           let session = workspace.sessionController.session(for: zoomedPaneID) {
            return [
                TerminalChromePaneDescriptor(
                    paneID: zoomedPaneID,
                    path: session.effectiveWorkingDirectory.terminalChromeDisplayPath,
                    isFocused: true
                )
            ]
        }

        let focusedPaneID = workspace.sessionController.focusedPaneID
        return workspace.paneOrder.compactMap { paneID in
            guard let session = workspace.sessionController.session(for: paneID) else { return nil }
            return TerminalChromePaneDescriptor(
                paneID: paneID,
                path: session.effectiveWorkingDirectory.terminalChromeDisplayPath,
                isFocused: paneID == focusedPaneID
            )
        }
    }
```

Add this method near `selectTerminalTabFromChrome(_:)`:

```swift
    private func focusTerminalPaneFromChrome(_ paneID: UUID) {
        workspace.focusPane(paneID)
    }
```

- [ ] **Step 4: Run the focused tests and verify they pass**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceTabsTests \
  test
```

Expected: `WorkspaceTabsTests` passes, including the two new source-level pane-chip tests. In split tabs, pane chips take precedence over terminal tab buttons; in single-pane multi-tab cases, terminal tab buttons remain the chrome content.

- [ ] **Step 5: Commit pane-chip work**

Review first:

```bash
git diff -- Argo/UI/Workspace/TerminalLocalChrome.swift Argo/UI/Workspace/WorkspaceDetailView.swift Tests/WorkspaceTabsTests.swift
```

Commit only these files:

```bash
git add Argo/UI/Workspace/TerminalLocalChrome.swift Argo/UI/Workspace/WorkspaceDetailView.swift Tests/WorkspaceTabsTests.swift
git commit -m "feat: show focused split pane chip"
```

---

### Task 3: Add Failing Source Tests For Inactive Overlay

**Files:**
- Modify: `Tests/WorkspaceTabsTests.swift`

- [ ] **Step 1: Add tests for inactive-pane dimming**

Append these tests inside `WorkspaceTabsTests` after the pane-chip tests:

```swift
    func testInactiveSplitPanesUseVisualOverlayWithoutBlockingInput() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let terminalPaneSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalPaneView.swift"),
            encoding: .utf8
        )
        let splitNodeSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/SplitNodeView.swift"),
            encoding: .utf8
        )
        let workspaceDetailSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(terminalPaneSource.contains("let dimsWhenInactive: Bool"))
        XCTAssertTrue(terminalPaneSource.contains("private var shouldDimInactivePane: Bool"))
        XCTAssertTrue(terminalPaneSource.contains("TerminalInactivePaneOverlay()"))
        XCTAssertTrue(terminalPaneSource.contains(".allowsHitTesting(false)"))
        XCTAssertTrue(splitNodeSource.contains("let dimsInactivePanes: Bool"))
        XCTAssertTrue(workspaceDetailSource.contains("dimsInactivePanes: shouldDimInactiveTerminalPanes"))
    }

    func testZoomedPaneDisablesInactiveDimming() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let workspaceDetailSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"),
            encoding: .utf8
        )
        let splitNodeSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/SplitNodeView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(workspaceDetailSource.contains("workspace.zoomedPaneID == nil && workspace.paneOrder.count > 1"))
        XCTAssertTrue(splitNodeSource.contains("dimsWhenInactive: false"))
    }
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceTabsTests \
  test
```

Expected: the new overlay tests fail because dimming inputs and `TerminalInactivePaneOverlay` do not exist yet.

---

### Task 4: Implement Inactive Pane Overlay

**Files:**
- Modify: `Argo/UI/Workspace/WorkspaceDetailView.swift`
- Modify: `Argo/UI/Workspace/SplitNodeView.swift`
- Modify: `Argo/UI/Workspace/TerminalPaneView.swift`
- Test: `Tests/WorkspaceTabsTests.swift`

- [ ] **Step 1: Pass dimming state from workspace detail**

In `WorkspaceSessionDetailView`, replace the `SplitNodeView` call with:

```swift
                    SplitNodeView(
                        workspace: workspace,
                        sessionController: workspace.sessionController,
                        node: layout,
                        dimsInactivePanes: shouldDimInactiveTerminalPanes
                    )
```

Add this computed property near `terminalChromePaneDescriptors`:

```swift
    private var shouldDimInactiveTerminalPanes: Bool {
        workspace.zoomedPaneID == nil && workspace.paneOrder.count > 1
    }
```

- [ ] **Step 2: Propagate dimming through split nodes**

In `Argo/UI/Workspace/SplitNodeView.swift`, add the new stored property:

```swift
    let dimsInactivePanes: Bool
```

Update each `TerminalPaneView` call.

For zoomed panes, use:

```swift
                    TerminalPaneView(
                        workspace: workspace,
                        sessionController: sessionController,
                        session: session,
                        paneID: zoomedPaneID,
                        dimsWhenInactive: false
                    )
                    .id(zoomedPaneID)
```

For normal pane leaves, use:

```swift
                        TerminalPaneView(
                            workspace: workspace,
                            sessionController: sessionController,
                            session: session,
                            paneID: leaf.paneID,
                            dimsWhenInactive: dimsInactivePanes
                        )
                        .id(leaf.paneID)
```

For recursive split calls, pass `dimsInactivePanes`:

```swift
                SplitNodeView(
                    workspace: workspace,
                    sessionController: sessionController,
                    node: split.first,
                    dimsInactivePanes: dimsInactivePanes
                )
                .frame(width: lengths.first)
```

```swift
                SplitNodeView(
                    workspace: workspace,
                    sessionController: sessionController,
                    node: split.second,
                    dimsInactivePanes: dimsInactivePanes
                )
                .frame(width: lengths.second)
```

```swift
                SplitNodeView(
                    workspace: workspace,
                    sessionController: sessionController,
                    node: split.first,
                    dimsInactivePanes: dimsInactivePanes
                )
                .frame(height: lengths.first)
```

```swift
                SplitNodeView(
                    workspace: workspace,
                    sessionController: sessionController,
                    node: split.second,
                    dimsInactivePanes: dimsInactivePanes
                )
                .frame(height: lengths.second)
```

- [ ] **Step 3: Add overlay support to terminal panes**

In `Argo/UI/Workspace/TerminalPaneView.swift`, add the new property after `paneID`:

```swift
    let dimsWhenInactive: Bool
```

Add this computed property near `isFocused`:

```swift
    private var shouldDimInactivePane: Bool {
        dimsWhenInactive && !isFocused
    }
```

Replace the `TerminalHostView` block with:

```swift
            ZStack {
                TerminalHostView(session: session, shouldRestoreFocus: isFocused)
                    .background(paneFill)
                    .onTapGesture {
                        workspace.focusPane(paneID)
                    }
                    .overlay(alignment: .trailing) {
                        TerminalScrollbarOverlay(session: session)
                            .padding(.trailing, 2)
                            .padding(.vertical, 2)
                    }

                if shouldDimInactivePane {
                    TerminalInactivePaneOverlay()
                        .allowsHitTesting(false)
                }
            }
```

Add this overlay view below `TerminalPaneView`:

```swift
private struct TerminalInactivePaneOverlay: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(nsColor: NSColor(calibratedRed: 0.027, green: 0.035, blue: 0.059, alpha: 0.42)),
                Color(nsColor: NSColor(calibratedRed: 0.027, green: 0.035, blue: 0.059, alpha: 0.50))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

Because `TerminalInactivePaneOverlay` uses `NSColor`, add `import AppKit` above `import SwiftUI`:

```swift
import AppKit
import SwiftUI
```

- [ ] **Step 4: Run focused tests and verify they pass**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceTabsTests \
  test
```

Expected: `WorkspaceTabsTests` passes, including pane-chip and inactive-overlay checks.

- [ ] **Step 5: Commit overlay work**

Review first:

```bash
git diff -- Argo/UI/Workspace/WorkspaceDetailView.swift Argo/UI/Workspace/SplitNodeView.swift Argo/UI/Workspace/TerminalPaneView.swift Tests/WorkspaceTabsTests.swift
```

Commit only these files:

```bash
git add Argo/UI/Workspace/WorkspaceDetailView.swift Argo/UI/Workspace/SplitNodeView.swift Argo/UI/Workspace/TerminalPaneView.swift Tests/WorkspaceTabsTests.swift
git commit -m "feat: dim inactive split panes"
```

---

### Task 5: Focused Regression And Build Verification

**Files:**
- Verify: `Argo/UI/Workspace/TerminalLocalChrome.swift`
- Verify: `Argo/UI/Workspace/WorkspaceDetailView.swift`
- Verify: `Argo/UI/Workspace/SplitNodeView.swift`
- Verify: `Argo/UI/Workspace/TerminalPaneView.swift`
- Verify: `Tests/WorkspaceTabsTests.swift`

- [ ] **Step 1: Run focused workspace tab tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceTabsTests \
  test
```

Expected: all `WorkspaceTabsTests` pass.

- [ ] **Step 2: Run pane layout tests because split rendering was touched**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/PaneLayoutTests \
  test
```

Expected: all `PaneLayoutTests` pass.

- [ ] **Step 3: Run a Debug build**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected: build exits with status 0.

- [ ] **Step 4: Review final diff**

Run:

```bash
git diff --stat
git diff -- Argo/UI/Workspace/TerminalLocalChrome.swift Argo/UI/Workspace/WorkspaceDetailView.swift Argo/UI/Workspace/SplitNodeView.swift Argo/UI/Workspace/TerminalPaneView.swift Tests/WorkspaceTabsTests.swift
```

Expected: only the planned implementation files and test file contain changes from this feature. Existing unrelated dirty files in the worktree remain unstaged.

---

### Task 6: Manual Smoke Test

**Files:**
- Manual verification only.

- [ ] **Step 1: Launch the app from Xcode or the built Debug app**

Use the existing app launch workflow for this repository.

- [ ] **Step 2: Verify single-pane behavior**

Open a workspace with one terminal pane.

Expected:

- Top chrome still shows one clean path pill.
- Terminal body has no dim overlay.
- Typing works in the single pane.

- [ ] **Step 3: Verify split-pane focus behavior**

Create at least three panes using the existing split or duplicate shortcuts.

Expected:

- Top chrome shows one path chip per visible pane.
- The focused pane's chip is a brighter gray capsule.
- Inactive panes have a translucent dark overlay.
- The active pane is not dimmed and terminal colors stay normal.

- [ ] **Step 4: Verify chip click focus**

Click each path chip.

Expected:

- Focus moves to the corresponding pane.
- The clicked pane's overlay disappears.
- All other panes receive the overlay.
- Keyboard input goes to the selected pane.

- [ ] **Step 5: Verify split actions still target focus**

Click the shared split-right and split-down actions after focusing different panes.

Expected:

- New panes are created from the currently focused pane.
- The new pane becomes active.
- Previously active panes become dimmed.

- [ ] **Step 6: Verify zoom behavior**

Zoom a pane with the existing zoom command.

Expected:

- The zoomed pane is not dimmed.
- The top chrome behaves as a single visible pane.
- Unzoom restores multi-pane chips and inactive overlays.

---

## Notes For Execution

- The current worktree already contains unrelated modified files. Before each commit, run `git status --short` and stage only the paths named in that task.
- Do not modify `Argo/Vendor/`.
- Do not change Ghostty adapter behavior for this feature.
- Do not run destructive git commands.
