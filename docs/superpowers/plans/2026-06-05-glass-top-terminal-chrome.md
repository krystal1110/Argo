# Glass Top Terminal Chrome Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the confirmed glass-style top chrome and terminal-local chrome while leaving the left workspace/sidebar exactly on its original implementation path.

**Architecture:** Keep the existing AppKit window and SwiftUI `NavigationSplitView` architecture. Add small reusable SwiftUI chrome components for glass groups and transparent icon buttons, wire them into `MainWindowView`, then replace the current `TerminalPaneView` header with a focused local chrome row that uses the existing store/session actions. Do not touch `WorkspaceSidebarView`, `GlobalModeRailView`, Ghostty runtime, or pane layout model code.

**Tech Stack:** Swift, SwiftUI, AppKit `NSView` menu anchoring, XCTest, Xcode project filesystem-synchronized groups.

---

## File Structure

- Modify `Tests/PathFormattingTests.swift`
  - Adds focused tests for the terminal chrome path display string.
- Modify `Argo/Support/PathFormatting.swift`
  - Adds `terminalChromeDisplayPath` as a tiny testable helper that preserves `~` abbreviation and never shell-escapes UI text.
- Create `Argo/UI/Components/GlassChromeControls.swift`
  - Owns reusable glass capsule groups, icon buttons, menu-anchor buttons, and split buttons used by the top toolbar.
- Create `Argo/UI/Workspace/TerminalLocalChrome.swift`
  - Owns the terminal path pill and transparent local `+ / split / split` actions.
- Modify `Argo/UI/MainWindowView.swift`
  - Replaces the dense toolbar group with project, command, utility, and editor glass groups.
  - Keeps existing menu-building methods and store actions.
  - Removes visible split/new-tab buttons from the global toolbar because those move to the terminal-local row.
- Modify `Argo/UI/Workspace/TerminalPaneView.swift`
  - Replaces the current 30px pane header with `TerminalLocalChrome`.
  - Keeps search presentation, search bar, status strip, context menu, lifecycle handling, and terminal host behavior.

Files intentionally untouched:

- `Argo/UI/Sidebar/WorkspaceSidebarView.swift`
- `Argo/UI/Components/GlobalModeRailView.swift`
- `Argo/UI/Workspace/SplitNodeView.swift`
- `Argo/Services/Terminal/Ghostty/`
- `Argo/Vendor/`

## Task 1: Add Failing Path Display Tests

**Files:**
- Modify: `Tests/PathFormattingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests inside `final class PathFormattingTests: XCTestCase`, after `testAbbreviatedPathUsesTildeInsideHomeDirectory()`:

```swift
    func testTerminalChromeDisplayPathUsesTildeForHomeDirectory() {
        let home = NSHomeDirectory()
        XCTAssertEqual(
            "\(home)/Documents/Claude 相关".terminalChromeDisplayPath,
            "~/Documents/Claude 相关"
        )
    }

    func testTerminalChromeDisplayPathKeepsAbsolutePathOutsideHomeDirectory() {
        XCTAssertEqual(
            "/tmp/Argo Scratch".terminalChromeDisplayPath,
            "/tmp/Argo Scratch"
        )
    }
```

- [ ] **Step 2: Run focused tests to verify RED**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/PathFormattingTests \
  test
```

Expected: FAIL at compile time with `Value of type 'String' has no member 'terminalChromeDisplayPath'`.

## Task 2: Implement Terminal Chrome Path Helper

**Files:**
- Modify: `Argo/Support/PathFormatting.swift`
- Test: `Tests/PathFormattingTests.swift`

- [ ] **Step 1: Add the helper**

Add this property after `lastPathComponentValue` in `extension String`:

```swift
    nonisolated var terminalChromeDisplayPath: String {
        let displayPath = abbreviatedPath
        return displayPath.isEmpty ? lastPathComponentValue : displayPath
    }
```

- [ ] **Step 2: Run focused tests to verify GREEN**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/PathFormattingTests \
  test
```

Expected: PASS for `PathFormattingTests`.

- [ ] **Step 3: Commit**

```sh
git add Argo/Support/PathFormatting.swift Tests/PathFormattingTests.swift
git commit -m "test: cover terminal chrome path display"
```

## Task 3: Add Reusable Glass Toolbar Controls

**Files:**
- Create: `Argo/UI/Components/GlassChromeControls.swift`

- [ ] **Step 1: Create the component file**

Create `Argo/UI/Components/GlassChromeControls.swift` with:

```swift
//
//  GlassChromeControls.swift
//  Argo
//
//  Author: krystal
//

import AppKit
import SwiftUI

struct GlassToolbarGroup<Content: View>: View {
    var minHeight: CGFloat = 38
    var horizontalPadding: CGFloat = 12
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: spacing) {
            content()
        }
        .padding(.horizontal, horizontalPadding)
        .frame(minHeight: minHeight)
        .background(glassFill, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }

    private var glassFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(0.155),
                Color.white.opacity(0.055)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct GlassToolbarIconButton: View {
    let systemName: String
    var tint: Color = ArgoTheme.secondaryText
    var isActive = false
    var isDisabled = false
    let accessibilityLabel: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(isActive ? Color.white : tint)
                .background(
                    Circle()
                        .fill(isActive ? ArgoTheme.accent.opacity(0.88) : Color.white.opacity(0.025))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .accessibilityLabel(accessibilityLabel)
        .help(help)
    }

}

struct GlassToolbarMenuIconButton: View {
    let systemName: String
    var tint: Color = ArgoTheme.secondaryText
    var isDisabled = false
    let accessibilityLabel: String
    let help: String
    let action: (NSView?) -> Void

    @State private var anchorView: NSView?

    var body: some View {
        Button {
            action(anchorView)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(tint)
                .contentShape(Circle())
                .background(GlassToolbarAnchorView(anchorView: $anchorView))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .accessibilityLabel(accessibilityLabel)
        .help(help)
    }
}

struct GlassToolbarSplitButton<LeadingContent: View, TrailingContent: View>: View {
    let leadingAction: (NSView?) -> Void
    let trailingAction: (NSView?) -> Void
    var isLeadingDisabled = false
    var isTrailingDisabled = false
    let leadingAccessibilityLabel: String
    let leadingHelp: String
    let trailingAccessibilityLabel: String
    let trailingHelp: String
    @ViewBuilder let leadingContent: () -> LeadingContent
    @ViewBuilder let trailingContent: () -> TrailingContent

    @State private var leadingAnchorView: NSView?
    @State private var trailingAnchorView: NSView?

    var body: some View {
        HStack(spacing: 0) {
            Button {
                leadingAction(leadingAnchorView)
            } label: {
                leadingContent()
                    .padding(.leading, 10)
                    .padding(.trailing, 9)
                    .frame(height: 28)
                    .contentShape(Rectangle())
                    .background(GlassToolbarAnchorView(anchorView: $leadingAnchorView))
            }
            .buttonStyle(.plain)
            .disabled(isLeadingDisabled)
            .accessibilityLabel(leadingAccessibilityLabel)
            .help(leadingHelp)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 16)

            Button {
                trailingAction(trailingAnchorView)
            } label: {
                trailingContent()
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .background(GlassToolbarAnchorView(anchorView: $trailingAnchorView))
            }
            .buttonStyle(.plain)
            .disabled(isTrailingDisabled)
            .accessibilityLabel(trailingAccessibilityLabel)
            .help(trailingHelp)
        }
        .frame(height: 38)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.155),
                    Color.white.opacity(0.055)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: Capsule()
        )
        .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .opacity(isLeadingDisabled && isTrailingDisabled ? 0.5 : 1)
    }
}

private struct GlassToolbarAnchorView: NSViewRepresentable {
    @Binding var anchorView: NSView?

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        updateAnchorView(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        updateAnchorView(nsView)
    }

    private func updateAnchorView(_ nsView: NSView) {
        guard anchorView !== nsView else { return }
        DispatchQueue.main.async {
            guard anchorView !== nsView else { return }
            anchorView = nsView
        }
    }
}
```

- [ ] **Step 2: Run build to catch component errors**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected: PASS. If the Xcode project does not automatically pick up new synchronized files, add `Argo/UI/Components/GlassChromeControls.swift` to the Argo target in `Argo.xcodeproj` and rerun the same build.

- [ ] **Step 3: Commit**

```sh
git add Argo/UI/Components/GlassChromeControls.swift Argo.xcodeproj
git commit -m "feat: add glass toolbar controls"
```

## Task 4: Recompose The Top Toolbar Into Glass Groups

**Files:**
- Modify: `Argo/UI/MainWindowView.swift`

- [ ] **Step 1: Add display helpers**

Inside `MainWindowView`, after `private var hasSelectedSession: Bool`, add:

```swift
    private var selectedWorkspaceDisplayName: String {
        store.selectedWorkspace?.name ?? localized("main.workspace.openWorkspace")
    }

    private var effectiveExternalEditorDisplayName: String {
        effectiveExternalEditor?.editor.displayName ?? localized("main.toolbar.openCurrentWorkspaceInExternalEditor")
    }
```

- [ ] **Step 2: Replace the `.toolbar` block**

Replace the current `.toolbar { ... }` block in `MainWindowView` with this structure. Keep the existing `.task`, `.onReceive`, and `.onChange` modifiers after it unchanged:

```swift
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(
                        #selector(NSSplitViewController.toggleSidebar(_:)), with: nil
                    )
                } label: {
                    Image(systemName: "sidebar.leading")
                        .padding(4 * uiScale)
                }
                .scaleEffect(uiScale)
                .disabled(store.mainWindowMode != .workspace)
                .accessibilityLabel(localized("menu.view.toggleSidebar"))
                .help(localized("menu.view.toggleSidebar"))

                GlassToolbarGroup(horizontalPadding: 12, spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ArgoTheme.secondaryText)
                    Text(selectedWorkspaceDisplayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ArgoTheme.tertiaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 150, alignment: .leading)
                }
                .scaleEffect(uiScale)
            }

            ToolbarItem(placement: .principal) {
                Button {
                    store.dispatch(.toggleCommandPalette)
                } label: {
                    GlassToolbarGroup(horizontalPadding: 14, spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ArgoTheme.danger.opacity(0.95))
                        Text(localized("menu.view.commandPalette"))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(ArgoTheme.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: 360)
                }
                .buttonStyle(.plain)
                .scaleEffect(uiScale)
                .accessibilityLabel(localized("menu.view.commandPalette"))
                .help(localized("menu.view.commandPalette"))
            }

            ToolbarItemGroup(placement: .primaryAction) {
                HStack(spacing: 10) {
                    GlassToolbarGroup(horizontalPadding: 5, spacing: 2) {
                        GlassToolbarMenuIconButton(
                            systemName: "chevron.left.slash.chevron.right",
                            tint: ArgoTheme.accent,
                            accessibilityLabel: localized("main.toolbar.chooseQuickCommand"),
                            help: localized("main.toolbar.chooseQuickCommand")
                        ) { anchorView in
                            present(menu: makeQuickCommandMenu(), from: anchorView)
                        }

                        GlassToolbarMenuIconButton(
                            systemName: "play.rectangle.on.rectangle",
                            tint: ArgoTheme.accent,
                            isDisabled: !hasSelectedWorkspace,
                            accessibilityLabel: localized("main.toolbar.chooseWorkflow"),
                            help: localized("main.toolbar.chooseWorkflow")
                        ) { anchorView in
                            present(menu: makeWorkflowMenu(), from: anchorView)
                        }

                        if let hapiInstallation = availableHAPIInstallation, store.appSettings.showHAPIToolbarButton {
                            GlassToolbarMenuIconButton(
                                systemName: "dot.radiowaves.left.and.right",
                                tint: ArgoTheme.accent,
                                isDisabled: !hasSelectedWorkspace,
                                accessibilityLabel: hapiInstallation.primaryActionTitle,
                                help: hapiHelpText
                            ) { anchorView in
                                present(menu: makeHAPIMenu(using: hapiInstallation), from: anchorView)
                            }
                        }

                        GlassToolbarMenuIconButton(
                            systemName: sleepPreventionIconName,
                            tint: store.sleepPreventionSession == nil ? ArgoTheme.secondaryText : ArgoTheme.warning,
                            accessibilityLabel: store.sleepPreventionPrimaryActionLabel,
                            help: store.sleepPreventionPrimaryActionHelpText
                        ) { anchorView in
                            present(menu: makeSleepPreventionMenu(), from: anchorView)
                        }

                        GlassToolbarIconButton(
                            systemName: store.selectedWorkspace?.isFileTreePresented == true ? "list.bullet.indent" : "sidebar.squares.leading",
                            tint: ArgoTheme.secondaryText,
                            isActive: store.selectedWorkspace?.isFileTreePresented == true,
                            isDisabled: !hasSelectedWorkspace,
                            accessibilityLabel: localized("main.toolbar.toggleFileTree"),
                            help: localized("main.toolbar.toggleFileTree")
                        ) {
                            store.selectedWorkspace?.toggleFileTree()
                        }

                        Menu {
                            webPreviewMenuContent
                        } label: {
                            Image(systemName: "globe")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .foregroundStyle(ArgoTheme.secondaryText)
                        }
                        .menuIndicator(.hidden)
                        .disabled(!hasSelectedWorkspace)
                        .accessibilityLabel(localized("main.toolbar.webPreview"))
                        .help(localized("main.toolbar.webPreview"))
                    }

                    GlassToolbarSplitButton(
                        leadingAction: { _ in
                            store.openSelectedWorkspaceInPreferredExternalEditor()
                        },
                        trailingAction: { anchorView in
                            present(menu: makeExternalEditorMenu(), from: anchorView)
                        },
                        isLeadingDisabled: !hasSelectedWorkspace || effectiveExternalEditor == nil,
                        isTrailingDisabled: !hasSelectedWorkspace,
                        leadingAccessibilityLabel: externalEditorHelpText,
                        leadingHelp: externalEditorHelpText,
                        trailingAccessibilityLabel: localized("main.toolbar.chooseExternalEditor"),
                        trailingHelp: localized("main.toolbar.chooseExternalEditorDefault"),
                        leadingContent: {
                            HStack(spacing: 7) {
                                Image(systemName: "arrow.up.forward.app.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(ArgoTheme.secondaryText)
                                Text(effectiveExternalEditorDisplayName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(ArgoTheme.tertiaryText)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: 94)
                            }
                        },
                        trailingContent: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(ArgoTheme.secondaryText)
                        }
                    )
                }
                .scaleEffect(uiScale)
            }
        }
```

- [ ] **Step 3: Remove unused old toolbar helpers only if the compiler reports them unused**

If `ToolbarSegmentedControl` or `ToolbarFeatureIcon` becomes unused and the project treats it as acceptable to keep private unused types, leave them. If a linter or compile warning policy requires cleanup, remove only the now-unused private toolbar structs from `MainWindowView.swift`; do not remove menu-building functions.

- [ ] **Step 4: Build**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add Argo/UI/MainWindowView.swift Argo/UI/Components/GlassChromeControls.swift Argo.xcodeproj
git commit -m "feat: group main toolbar into glass controls"
```

## Task 5: Add Terminal Local Chrome

**Files:**
- Create: `Argo/UI/Workspace/TerminalLocalChrome.swift`
- Modify: `Argo/UI/Workspace/TerminalPaneView.swift`

- [ ] **Step 1: Create terminal-local chrome component**

Create `Argo/UI/Workspace/TerminalLocalChrome.swift` with:

```swift
//
//  TerminalLocalChrome.swift
//  Argo
//
//  Author: krystal
//

import AppKit
import SwiftUI

struct TerminalLocalChrome: View {
    let path: String
    let isFocused: Bool
    let canCreateTab: Bool
    let canSplit: Bool
    let onCreateTab: () -> Void
    let onSplitRight: () -> Void
    let onSplitDown: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.72))
                Text(path)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(nsColor: NSColor(calibratedRed: 0.968, green: 0.976, blue: 0.988, alpha: 1)))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .padding(.horizontal, 12)
            .background(pathFill, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.235), lineWidth: 1))
            .shadow(color: .black.opacity(0.07), radius: 8, y: 3)

            HStack(spacing: 5) {
                TransparentPaneActionButton(
                    systemName: "plus",
                    isDisabled: !canCreateTab,
                    accessibilityLabel: LocalizationManager.shared.string("menu.file.newTab"),
                    help: LocalizationManager.shared.string("menu.file.newTab"),
                    action: onCreateTab
                )
                TransparentPaneActionButton(
                    systemName: "rectangle.split.2x1",
                    isDisabled: !canSplit,
                    accessibilityLabel: LocalizationManager.shared.string("menu.file.splitRight"),
                    help: LocalizationManager.shared.string("menu.file.splitRight"),
                    action: onSplitRight
                )
                TransparentPaneActionButton(
                    systemName: "rectangle.split.1x2",
                    isDisabled: !canSplit,
                    accessibilityLabel: LocalizationManager.shared.string("menu.file.splitDown"),
                    help: LocalizationManager.shared.string("menu.file.splitDown"),
                    action: onSplitDown
                )
            }
            .fixedSize()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pathFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(isFocused ? 0.255 : 0.205),
                Color.white.opacity(isFocused ? 0.145 : 0.105)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct TransparentPaneActionButton: View {
    let systemName: String
    var isDisabled = false
    let accessibilityLabel: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 30, height: 30)
                .foregroundStyle(Color.white.opacity(isDisabled ? 0.32 : 0.88))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
        .help(help)
    }
}
```

- [ ] **Step 2: Replace the existing pane header in `TerminalPaneView`**

In `TerminalPaneView.body`, replace this block:

```swift
            GeometryReader { proxy in
                paneHeaderContent(for: proxy.size.width)
            }
            .frame(height: 30)
            .padding(.horizontal, 10)
            .background(isFocused ? ArgoTheme.panelRaised : ArgoTheme.paneHeaderBackground)
```

with:

```swift
            TerminalLocalChrome(
                path: session.effectiveWorkingDirectory.terminalChromeDisplayPath,
                isFocused: isFocused,
                canCreateTab: true,
                canSplit: sessionController.session(for: paneID) != nil,
                onCreateTab: {
                    workspace.focusPane(paneID)
                    store.createTab(in: workspace)
                },
                onSplitRight: {
                    workspace.focusPane(paneID)
                    store.splitFocusedPane(in: workspace, axis: .vertical)
                },
                onSplitDown: {
                    workspace.focusPane(paneID)
                    store.splitFocusedPane(in: workspace, axis: .horizontal)
                }
            )
            .frame(height: 44)
            .padding(.horizontal, 8)
            .background(isFocused ? ArgoTheme.panelRaised.opacity(0.72) : ArgoTheme.paneHeaderBackground.opacity(0.66))
```

- [ ] **Step 3: Keep search support intact**

Do not delete these members from `TerminalPaneView` because context menu and search notifications still use them:

```swift
    @FocusState private var searchFieldFocused: Bool
    @State private var isSearchPresented = false
    @State private var searchDraft = ""
    @State private var searchTask: Task<Void, Never>?
```

Do not delete `presentSearch()`, `closeSearch()`, `syncSearchState(with:)`, `requestSearchFieldFocus()`, or `scheduleSearchUpdate(_:)`.

- [ ] **Step 4: Keep `PaneHeaderButton` if `PaneSearchBar` still uses it**

`PaneSearchBar` uses `PaneHeaderButton` for next/previous/close. Keep `PaneHeaderButton` unless you also refactor the search bar in the same task. The expected first implementation keeps it.

- [ ] **Step 5: Build**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected: PASS. If the Xcode project does not automatically pick up `TerminalLocalChrome.swift`, add it to the Argo target and rerun the build.

- [ ] **Step 6: Commit**

```sh
git add Argo/UI/Workspace/TerminalLocalChrome.swift Argo/UI/Workspace/TerminalPaneView.swift Argo.xcodeproj
git commit -m "feat: add terminal local chrome"
```

## Task 6: Verify Left Workspace Is Untouched And Run Final Checks

**Files:**
- Inspect only: `Argo/UI/Sidebar/WorkspaceSidebarView.swift`
- Inspect only: `Argo/UI/Components/GlobalModeRailView.swift`
- Verify: `Argo/UI/MainWindowView.swift`
- Verify: `Argo/UI/Workspace/TerminalPaneView.swift`

- [ ] **Step 1: Confirm forbidden files have no diff**

Run:

```sh
git diff -- Argo/UI/Sidebar/WorkspaceSidebarView.swift Argo/UI/Components/GlobalModeRailView.swift
```

Expected: no output.

- [ ] **Step 2: Run focused path tests**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/PathFormattingTests \
  test
```

Expected: PASS.

- [ ] **Step 3: Run full build**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected: PASS.

- [ ] **Step 4: Manual smoke test**

Launch the app from Xcode or the built app, then verify:

- Left workspace rail/sidebar still uses original layout, search, repo rows, context menus, and workspace switching.
- Top chrome shows separate project, command, utility, and editor glass groups.
- No visible `Run` control appears.
- Terminal pane header shows a浅灰 path pill with an abbreviated path like `~/Documents/Claude 相关`.
- Terminal-local `+` creates a new tab.
- Terminal-local split right/down act on the pane whose header was clicked.
- Right-side terminal-local icons have transparent backgrounds.
- Terminal context menu still includes split, duplicate, zoom, restart, find, read-only, clear, and close.
- Narrowing the window truncates project/path text rather than overlapping controls.

- [ ] **Step 5: Commit verification cleanup if needed**

If manual testing required tiny polish fixes, commit them:

```sh
git add Argo/UI/MainWindowView.swift Argo/UI/Components/GlassChromeControls.swift Argo/UI/Workspace/TerminalLocalChrome.swift Argo/UI/Workspace/TerminalPaneView.swift Tests/PathFormattingTests.swift Argo/Support/PathFormatting.swift Argo.xcodeproj
git commit -m "polish: refine glass terminal chrome"
```

If there were no changes after verification, skip this commit.

## Self-Review

Spec coverage:

- Top glass groups are covered by Tasks 3 and 4.
- Terminal local path pill and transparent local actions are covered by Tasks 2 and 5.
- Left workspace untouched constraint is covered by Task 6.
- No `Run` control is preserved by Task 4 and verified in Task 6.
- Existing context menu and advanced terminal operations are preserved by Task 5.

Placeholder scan:

- The plan contains no placeholder markers or unspecified implementation steps.

Type consistency:

- Path helper name is consistently `terminalChromeDisplayPath`.
- Reusable toolbar component names are consistently `GlassToolbarGroup`, `GlassToolbarIconButton`, `GlassToolbarMenuIconButton`, and `GlassToolbarSplitButton`.
- Terminal component name is consistently `TerminalLocalChrome`.
