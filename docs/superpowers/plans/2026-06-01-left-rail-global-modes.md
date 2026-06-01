# Left Rail Global Modes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a compact left rail that switches between Workspace, Canvas, and Overview global modes, with Settings as an action entry and Command Palette kept out of the rail.

**Architecture:** Move the main-window mode into `WorkspaceStore` so command palette commands, menu actions, and rail clicks share one source of truth. Add a focused `GlobalModeRailView` component for the far-left rail. Refactor `MainWindowView` so Workspace mode renders the existing split view, while Canvas and Overview modes render their global views without the workspace sidebar.

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest, existing Argo localization and theme helpers.

---

## File Structure

- Modify `Argo/Support/UIState.swift`: add `MainWindowMode`, including stable case order, localization keys, and SF Symbol names.
- Modify `Argo/Support/L10n.swift`: add rail labels for Workspace and Settings in English and Simplified Chinese.
- Modify `Argo/App/WorkspaceStore.swift`: replace the separate overview presentation flag with `mainWindowMode`, and route existing overview commands through that mode.
- Create `Argo/UI/Components/GlobalModeRailView.swift`: render the far-left rail and expose callbacks for mode selection and Settings.
- Modify `Argo/UI/MainWindowView.swift`: render the rail beside either the workspace split view, canvas view, or overview view; remove the old top-toolbar Canvas and Overview primary buttons.
- Modify `Tests/WorkspaceStoreTests.swift`: cover mode defaults, overview toggle behavior, settings behavior, and command palette localization.
- Run existing Xcode tests and a manual UI smoke test.

---

### Task 1: Add Main Window Mode Model

**Files:**
- Modify: `Argo/Support/UIState.swift`
- Modify: `Argo/Support/L10n.swift`
- Modify: `Tests/WorkspaceStoreTests.swift`

- [ ] **Step 1: Write failing tests for mode metadata**

Add these tests to `Tests/WorkspaceStoreTests.swift` near `testModelDisplayStringsLocalizeForSimplifiedChinese`:

```swift
func testMainWindowModeMetadataIsStable() {
    XCTAssertEqual(MainWindowMode.allCases, [.workspace, .canvas, .overview])
    XCTAssertEqual(MainWindowMode.workspace.id, "workspace")
    XCTAssertEqual(MainWindowMode.canvas.id, "canvas")
    XCTAssertEqual(MainWindowMode.overview.id, "overview")
    XCTAssertEqual(MainWindowMode.workspace.titleLocalizationKey, "main.rail.workspace")
    XCTAssertEqual(MainWindowMode.canvas.titleLocalizationKey, "main.canvas.title")
    XCTAssertEqual(MainWindowMode.overview.titleLocalizationKey, "main.overview.title")
    XCTAssertEqual(MainWindowMode.workspace.iconSystemName(selected: false), "sidebar.leading")
    XCTAssertEqual(MainWindowMode.canvas.iconSystemName(selected: true), "square.grid.3x2.fill")
    XCTAssertEqual(MainWindowMode.overview.iconSystemName(selected: true), "building.2.fill")
}

func testMainRailStringsLocalizeForSimplifiedChinese() {
    LocalizationManager.shared.updateSelectedLanguage(.simplifiedChinese)

    XCTAssertEqual(L10nTable.string(for: "main.rail.workspace", language: .simplifiedChinese), "工作区")
    XCTAssertEqual(L10nTable.string(for: "main.rail.settings", language: .simplifiedChinese), "设置")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceStoreTests/testMainWindowModeMetadataIsStable -only-testing:ArgoTests/WorkspaceStoreTests/testMainRailStringsLocalizeForSimplifiedChinese test
```

Expected: compile failure because `MainWindowMode` and the new localization keys do not exist.

- [ ] **Step 3: Add `MainWindowMode`**

In `Argo/Support/UIState.swift`, add this enum after `ArgoFeatureFlags`:

```swift
enum MainWindowMode: String, CaseIterable, Identifiable {
    case workspace
    case canvas
    case overview

    var id: String { rawValue }

    var titleLocalizationKey: String {
        switch self {
        case .workspace:
            return "main.rail.workspace"
        case .canvas:
            return "main.canvas.title"
        case .overview:
            return "main.overview.title"
        }
    }

    func iconSystemName(selected: Bool) -> String {
        switch self {
        case .workspace:
            return "sidebar.leading"
        case .canvas:
            return selected ? "square.grid.3x2.fill" : "square.grid.3x2"
        case .overview:
            return selected ? "building.2.fill" : "building.2"
        }
    }
}
```

- [ ] **Step 4: Add rail localization strings**

In `Argo/Support/L10n.swift`, add these entries to the English table near the existing `main.overview` and `main.canvas` strings:

```swift
"main.rail.workspace": "Workspace",
"main.rail.settings": "Settings",
```

Add these entries to the Simplified Chinese table near the existing `main.overview` and `main.canvas` strings:

```swift
"main.rail.workspace": "工作区",
"main.rail.settings": "设置",
```

- [ ] **Step 5: Run tests to verify they pass**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceStoreTests/testMainWindowModeMetadataIsStable -only-testing:ArgoTests/WorkspaceStoreTests/testMainRailStringsLocalizeForSimplifiedChinese test
```

Expected: both tests pass.

- [ ] **Step 6: Commit**

Run:

```bash
git add Argo/Support/UIState.swift Argo/Support/L10n.swift Tests/WorkspaceStoreTests.swift
git commit -m "feat: add main window mode model"
```

---

### Task 2: Move Overview State Into Main Window Mode

**Files:**
- Modify: `Argo/App/WorkspaceStore.swift`
- Modify: `Tests/WorkspaceStoreTests.swift`

- [ ] **Step 1: Write failing tests for mode state behavior**

Add these tests to `Tests/WorkspaceStoreTests.swift` near the command palette localization test:

```swift
func testMainWindowModeDefaultsToWorkspace() {
    let store = WorkspaceStore(persistsWorkspaceState: false)

    XCTAssertEqual(store.mainWindowMode, .workspace)
}

func testOverviewCommandTogglesMainWindowMode() {
    let store = WorkspaceStore(persistsWorkspaceState: false)

    store.dispatch(.toggleOverview)
    XCTAssertEqual(store.mainWindowMode, .overview)

    store.dispatch(.toggleOverview)
    XCTAssertEqual(store.mainWindowMode, .workspace)
}

func testPresentSettingsDoesNotChangeMainWindowMode() {
    let store = WorkspaceStore(persistsWorkspaceState: false)
    store.mainWindowMode = .canvas

    store.dispatch(.presentSettings)

    XCTAssertEqual(store.mainWindowMode, .canvas)
    XCTAssertNotNil(store.settingsRequest)
}

func testDismissTransientUIReturnsToWorkspaceMode() {
    let store = WorkspaceStore(persistsWorkspaceState: false)
    store.mainWindowMode = .overview

    store.dispatch(.dismissTransientUI)

    XCTAssertEqual(store.mainWindowMode, .workspace)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceStoreTests/testMainWindowModeDefaultsToWorkspace -only-testing:ArgoTests/WorkspaceStoreTests/testOverviewCommandTogglesMainWindowMode -only-testing:ArgoTests/WorkspaceStoreTests/testPresentSettingsDoesNotChangeMainWindowMode -only-testing:ArgoTests/WorkspaceStoreTests/testDismissTransientUIReturnsToWorkspaceMode test
```

Expected: compile failure because `WorkspaceStore.mainWindowMode` does not exist.

- [ ] **Step 3: Add main window mode to `WorkspaceStore`**

In `Argo/App/WorkspaceStore.swift`, replace:

```swift
@Published var isOverviewPresented = false
```

with:

```swift
@Published var mainWindowMode: MainWindowMode = .workspace
```

- [ ] **Step 4: Update overview command palette item**

In `WorkspaceStore.commandPaletteItems`, replace the overview item title expression:

```swift
title: isOverviewPresented ? localized("main.commandPalette.overview.close") : localized("main.commandPalette.overview.open"),
```

with:

```swift
title: mainWindowMode == .overview ? localized("main.commandPalette.overview.close") : localized("main.commandPalette.overview.open"),
```

- [ ] **Step 5: Update command dispatch mode behavior**

In `WorkspaceStore.dispatch(_:)`, replace the `.toggleOverview` case with:

```swift
case .toggleOverview:
    dismissCommandPalette()
    mainWindowMode = mainWindowMode == .overview ? .workspace : .overview
```

In the `.dismissTransientUI` case, replace:

```swift
isOverviewPresented = false
```

with:

```swift
mainWindowMode = .workspace
```

In the `.selectWorkspace(let id)` case, after `selectWorkspace(workspace)`, add:

```swift
mainWindowMode = .workspace
```

- [ ] **Step 6: Remove remaining overview boolean references from `WorkspaceStore`**

Run:

```bash
rg -n "isOverviewPresented" Argo/App/WorkspaceStore.swift
```

Expected: no matches in `WorkspaceStore.swift`.

- [ ] **Step 7: Run tests to verify they pass**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceStoreTests/testMainWindowModeDefaultsToWorkspace -only-testing:ArgoTests/WorkspaceStoreTests/testOverviewCommandTogglesMainWindowMode -only-testing:ArgoTests/WorkspaceStoreTests/testPresentSettingsDoesNotChangeMainWindowMode -only-testing:ArgoTests/WorkspaceStoreTests/testDismissTransientUIReturnsToWorkspaceMode -only-testing:ArgoTests/WorkspaceStoreTests/testCommandPaletteItemsLocalizeForSimplifiedChinese test
```

Expected: all selected tests pass.

- [ ] **Step 8: Commit**

Run:

```bash
git add Argo/App/WorkspaceStore.swift Tests/WorkspaceStoreTests.swift
git commit -m "feat: route overview through main window mode"
```

---

### Task 3: Add the Global Mode Rail View

**Files:**
- Create: `Argo/UI/Components/GlobalModeRailView.swift`

- [ ] **Step 1: Create the rail component**

Create `Argo/UI/Components/GlobalModeRailView.swift`:

```swift
//
//  GlobalModeRailView.swift
//  Argo
//
//  Author: krystal
//

import SwiftUI

struct GlobalModeRailView: View {
    @ObservedObject private var localization = LocalizationManager.shared

    let selectedMode: MainWindowMode
    let uiScale: CGFloat
    let onSelectMode: (MainWindowMode) -> Void
    let onOpenSettings: () -> Void

    private func localized(_ key: String) -> String {
        localization.string(key)
    }

    var body: some View {
        VStack(spacing: 10 * uiScale) {
            ForEach(MainWindowMode.allCases) { mode in
                GlobalModeRailButton(
                    systemName: mode.iconSystemName(selected: selectedMode == mode),
                    title: localized(mode.titleLocalizationKey),
                    isSelected: selectedMode == mode,
                    uiScale: uiScale
                ) {
                    onSelectMode(mode)
                }
            }

            Spacer(minLength: 12 * uiScale)

            GlobalModeRailButton(
                systemName: "gearshape",
                title: localized("main.rail.settings"),
                isSelected: false,
                uiScale: uiScale,
                action: onOpenSettings
            )
        }
        .padding(.vertical, 12 * uiScale)
        .frame(width: 54 * uiScale)
        .frame(maxHeight: .infinity)
        .background(ArgoTheme.chromeBackground.opacity(0.98))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(ArgoTheme.border.opacity(0.8))
                .frame(width: 1)
        }
    }
}

private struct GlobalModeRailButton: View {
    let systemName: String
    let title: String
    let isSelected: Bool
    let uiScale: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16 * uiScale, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : ArgoTheme.secondaryText)
                .frame(width: 34 * uiScale, height: 34 * uiScale)
                .background(
                    RoundedRectangle(cornerRadius: 8 * uiScale, style: .continuous)
                        .fill(isSelected ? ArgoTheme.accent : ArgoTheme.subtleFill.opacity(0.65))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8 * uiScale, style: .continuous)
                        .stroke(isSelected ? ArgoTheme.accent.opacity(0.65) : ArgoTheme.border.opacity(0.6), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }
}
```

- [ ] **Step 2: Build to verify the new component compiles**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' build
```

Expected: build succeeds.

- [ ] **Step 3: Commit**

Run:

```bash
git add Argo/UI/Components/GlobalModeRailView.swift
git commit -m "feat: add global mode rail view"
```

---

### Task 4: Refactor Main Window Layout Around the Rail

**Files:**
- Modify: `Argo/UI/MainWindowView.swift`

- [ ] **Step 1: Replace local Canvas boolean with mode helpers**

In `Argo/UI/MainWindowView.swift`, remove:

```swift
@State private var isCanvasPresented = false
```

Add these helpers near the existing computed properties:

```swift
private var isCanvasMode: Bool {
    store.mainWindowMode == .canvas
}

private var isOverviewMode: Bool {
    store.mainWindowMode == .overview
}

private func selectMainWindowMode(_ mode: MainWindowMode, restoreFocus: Bool = true) {
    let wasCanvasMode = store.mainWindowMode == .canvas
    store.mainWindowMode = mode
    if restoreFocus, wasCanvasMode, mode == .workspace {
        restoreFocusedPane()
    }
}

private func restoreFocusedPane() {
    guard let workspace = store.selectedWorkspace,
          let focusedPaneID = workspace.sessionController.focusedPaneID else {
        return
    }
    DispatchQueue.main.async {
        workspace.sessionController.focus(focusedPaneID)
    }
}
```

Replace `dismissCanvas(restoreFocus:)` with:

```swift
private func dismissGlobalMode(restoreFocus: Bool = true) {
    selectMainWindowMode(.workspace, restoreFocus: restoreFocus)
}
```

- [ ] **Step 2: Rewrite the body shell**

In `MainWindowView.body`, replace the current top-level `NavigationSplitView` plus Canvas and Overview overlay blocks with this structure:

```swift
ZStack {
    HStack(spacing: 0) {
        GlobalModeRailView(
            selectedMode: store.mainWindowMode,
            uiScale: uiScale,
            onSelectMode: { mode in
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectMainWindowMode(mode, restoreFocus: mode == .workspace)
                }
            },
            onOpenSettings: {
                store.presentSettings(for: store.selectedWorkspace)
            }
        )

        Group {
            switch store.mainWindowMode {
            case .workspace:
                NavigationSplitView {
                    WorkspaceSidebarView()
                        .navigationSplitViewColumnWidth(min: 190, ideal: 240, max: 320)
                } detail: {
                    WorkspaceDetailView()
                }
                .navigationSplitViewStyle(.balanced)

            case .canvas:
                GlobalCanvasView {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dismissGlobalMode()
                    }
                }
                .environmentObject(store)

            case .overview:
                OverviewView {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        dismissGlobalMode(restoreFocus: false)
                    }
                }
                .environmentObject(store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    if store.isCommandPalettePresented {
        CommandPaletteView()
            .environmentObject(store)
            .transition(.opacity)
            .zIndex(3)
    }

    VStack {
        if let statusMessage = store.statusMessage {
            StatusBanner(message: statusMessage)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
        Spacer()
    }
    .zIndex(2)
}
```

- [ ] **Step 3: Remove top-toolbar Overview and Canvas primary buttons**

Delete the toolbar button blocks whose labels use:

```swift
Image(systemName: store.isOverviewPresented ? "building.2.fill" : "building.2")
```

and:

```swift
Image(systemName: isCanvasPresented ? "square.grid.3x2.fill" : "square.grid.3x2")
```

Keep the Command Palette toolbar button unchanged.

- [ ] **Step 4: Update More menu global mode actions**

In the More menu, replace the Overview button with:

```swift
Button(isOverviewMode ? localized("main.overview.close") : localized("main.overview.open")) {
    withAnimation(.easeInOut(duration: 0.2)) {
        store.dispatch(.toggleOverview)
    }
}
```

Replace the Canvas button with:

```swift
Button(isCanvasMode ? localized("main.canvas.hide") : localized("main.canvas.show")) {
    withAnimation(.easeInOut(duration: 0.2)) {
        if isCanvasMode {
            dismissGlobalMode()
        } else {
            selectMainWindowMode(.canvas, restoreFocus: false)
        }
    }
}
```

- [ ] **Step 5: Remove selected-workspace Canvas reset**

Delete the `.onChange(of: store.selectedWorkspaceID)` block that only sets Canvas presentation to false. Canvas is now a global mode and can stay open while selection changes.

- [ ] **Step 6: Remove remaining old presentation references**

Run:

```bash
rg -n "isCanvasPresented|dismissCanvas|isOverviewPresented" Argo/UI/MainWindowView.swift
```

Expected: no matches.

- [ ] **Step 7: Build to verify the layout refactor compiles**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' build
```

Expected: build succeeds.

- [ ] **Step 8: Commit**

Run:

```bash
git add Argo/UI/MainWindowView.swift
git commit -m "feat: render main window global modes from left rail"
```

---

### Task 5: Verify Commands, Localization, and Manual UI Behavior

**Files:**
- Modify only if verification exposes an issue.

- [ ] **Step 1: Run focused tests**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceStoreTests test
```

Expected: `WorkspaceStoreTests` pass.

- [ ] **Step 2: Run full tests**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' test
```

Expected: test suite succeeds.

- [ ] **Step 3: Run whitespace check**

Run:

```bash
git diff --check
```

Expected: no output and exit code 0.

- [ ] **Step 4: Manual smoke test in the app**

Launch the Debug app from Xcode or with:

```bash
open ~/Library/Developer/Xcode/DerivedData/Argo-*/Build/Products/Debug/Argo.app
```

Verify:

- Workspace rail button shows the workspace sidebar and selected workspace detail.
- Canvas rail button hides the workspace sidebar and shows Canvas.
- Overview rail button hides the workspace sidebar and shows Overview.
- Settings rail button opens Settings and does not change the active rail selection.
- Command Palette is still available through its existing toolbar button and shortcut.
- The top toolbar no longer has duplicate primary Canvas and Overview buttons.

- [ ] **Step 5: Final commit if verification required fixes**

If verification changes any files, run:

```bash
git add Argo/Support/UIState.swift Argo/Support/L10n.swift Argo/App/WorkspaceStore.swift Argo/UI/Components/GlobalModeRailView.swift Argo/UI/MainWindowView.swift Tests/WorkspaceStoreTests.swift
git commit -m "fix: polish left rail global modes"
```

If verification changes no files, skip this commit.
