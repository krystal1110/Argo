# Single-Surface Workspace Sidebar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 消除左侧 workspace sidebar 的“双框感”，让它呈现为一块单一深色浮动面板。

**Architecture:** `FloatingWorkspaceSidebarSurface` 成为唯一的大面板 surface，负责底色、圆角、描边和阴影。`WorkspaceSidebarView` 只负责内部搜索、outline 和 footer 内容，不再铺整块 sidebar 背景。

**Tech Stack:** SwiftUI、AppKit `NSViewRepresentable`、XCTest、`xcodebuild`。

---

## File Structure

- Modify: `Tests/QuickCommandSupportTests.swift`
  - 扩展 `testMainWindowWrapsWorkspaceSidebarInFloatingSurface`，先用源码结构测试锁住单一 surface 的边界。

- Modify: `Argo/UI/MainWindowView.swift`
  - 在 `FloatingWorkspaceSidebarSurface` 内添加 `ArgoTheme.sidebarBackground` 的面板填充。
  - 保持现有圆角、描边、顶部高光、阴影、`10px` inset 和 column width。

- Modify: `Argo/UI/Sidebar/WorkspaceSidebarView.swift`
  - 移除根视图和搜索横条的整块 `ArgoTheme.sidebarBackground`。
  - 保留搜索框自身背景和细描边。
  - 弱化顶部搜索区底部分隔线。

## Task 1: Add Failing Structure Test

**Files:**
- Modify: `Tests/QuickCommandSupportTests.swift:418-433`
- Test: `Tests/QuickCommandSupportTests.swift`

- [ ] **Step 1: Extend the existing sidebar surface test**

Replace the body assertions in `testMainWindowWrapsWorkspaceSidebarInFloatingSurface` after `XCTAssertTrue(mainWindowSource.contains("RoundedRectangle(cornerRadius: 8, style: .continuous)"))` with the following assertions:

```swift
        XCTAssertTrue(mainWindowSource.contains("RoundedRectangle(cornerRadius: 8, style: .continuous)"))
        XCTAssertTrue(mainWindowSource.contains(".background(ArgoTheme.sidebarBackground, in: panelShape)"))
        XCTAssertTrue(mainWindowSource.contains(".padding(.init(top: 10, leading: 10, bottom: 10, trailing: 10))"))
        XCTAssertTrue(mainWindowSource.contains(".shadow(color: .black.opacity(0.28), radius: 22, x: 14, y: 1)"))
        XCTAssertFalse(
            sidebarSource.contains("FloatingWorkspaceSidebarSurface"),
            "The existing sidebar contents should not own the floating shell."
        )

        let fullSidebarBackgroundCount = sidebarSource
            .components(separatedBy: ".background(ArgoTheme.sidebarBackground)")
            .count - 1
        XCTAssertEqual(
            fullSidebarBackgroundCount,
            0,
            "WorkspaceSidebarView should let FloatingWorkspaceSidebarSurface own the full-panel background."
        )

        XCTAssertTrue(sidebarSource.contains("let outlineView = SidebarOutlineView()"))
        XCTAssertTrue(sidebarSource.contains("private final class SidebarOutlineContainerView: NSView"))
```

- [ ] **Step 2: Run the focused test and verify it fails for the expected reason**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/QuickCommandSupportTests/testMainWindowWrapsWorkspaceSidebarInFloatingSurface \
  test
```

Expected result:

```text
FAIL
XCTAssertTrue failed
```

The failure should come from missing `.background(ArgoTheme.sidebarBackground, in: panelShape)` in `MainWindowView.swift`, or from `WorkspaceSidebarView.swift` still containing `.background(ArgoTheme.sidebarBackground)`.

## Task 2: Move Full-Panel Background to the Floating Surface

**Files:**
- Modify: `Argo/UI/MainWindowView.swift:786-807`
- Test: `Tests/QuickCommandSupportTests.swift`

- [ ] **Step 1: Update `FloatingWorkspaceSidebarSurface`**

Change the start of `FloatingWorkspaceSidebarSurface.body` to this exact structure:

```swift
    var body: some View {
        content()
            .background(ArgoTheme.sidebarBackground, in: panelShape)
            .clipShape(panelShape)
            .overlay {
                panelShape
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .overlay(alignment: .top) {
                panelShape
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    .mask(
                        LinearGradient(
                            colors: [.black, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(1)
            }
            .shadow(color: .black.opacity(0.28), radius: 22, x: 14, y: 1)
            .padding(.init(top: 10, leading: 10, bottom: 10, trailing: 10))
            .background(ArgoTheme.appBackground)
    }
```

- [ ] **Step 2: Run the focused test and verify the remaining failure**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/QuickCommandSupportTests/testMainWindowWrapsWorkspaceSidebarInFloatingSurface \
  test
```

Expected result:

```text
FAIL
XCTAssertEqual failed
```

The remaining failure should report that `WorkspaceSidebarView.swift` still has one or more `.background(ArgoTheme.sidebarBackground)` occurrences.

## Task 3: Remove Inner Full-Panel Backgrounds

**Files:**
- Modify: `Argo/UI/Sidebar/WorkspaceSidebarView.swift:24-63`
- Test: `Tests/QuickCommandSupportTests.swift`

- [ ] **Step 1: Update `WorkspaceSidebarView.body`**

Replace `WorkspaceSidebarView.body` with:

```swift
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11 * uiScale, weight: .regular))
                    .foregroundStyle(ArgoTheme.mutedText.opacity(0.8))

                TextField(
                    text: $query,
                    prompt: Text(localized("sidebar.filterWorkspaces"))
                        .font(.system(size: 12 * uiScale, weight: .regular))
                        .foregroundStyle(ArgoTheme.mutedText.opacity(0.7))
                ) {
                    EmptyView()
                }
                .textFieldStyle(.plain)
                .font(.system(size: 12 * uiScale, weight: .regular))
            }
            .padding(.horizontal, 9 * uiScale)
            .padding(.vertical, 5 * uiScale)
            .background(ArgoTheme.sidebarSearchBackground, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(ArgoTheme.border, lineWidth: 1)
            )
            .padding(.horizontal, 8 * uiScale)
            .padding(.top, 7 * uiScale)
            .padding(.bottom, 6 * uiScale)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(ArgoTheme.border.opacity(0.55))
                    .frame(height: 1)
            }

            WorkspaceOutlineSidebar(query: query, onOpenRepository: store.addWorkspaceFromOpenPanel, onConnectSSH: { store.presentConnectSSH() })
                .environmentObject(store)
        }
    }
```

- [ ] **Step 2: Run the focused test and verify it passes**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/QuickCommandSupportTests/testMainWindowWrapsWorkspaceSidebarInFloatingSurface \
  test
```

Expected result:

```text
TEST SUCCEEDED
```

## Task 4: Run Targeted Verification

**Files:**
- Test: `Tests/QuickCommandSupportTests.swift`

- [ ] **Step 1: Run the full `QuickCommandSupportTests` suite**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/QuickCommandSupportTests \
  test
```

Expected result:

```text
TEST SUCCEEDED
```

- [ ] **Step 2: Run a Debug build**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected result:

```text
BUILD SUCCEEDED
```

## Task 5: Review and Commit

**Files:**
- Modify: `Argo/UI/MainWindowView.swift`
- Modify: `Argo/UI/Sidebar/WorkspaceSidebarView.swift`
- Modify: `Tests/QuickCommandSupportTests.swift`

- [ ] **Step 1: Inspect the final diff**

Run:

```sh
git diff -- Argo/UI/MainWindowView.swift Argo/UI/Sidebar/WorkspaceSidebarView.swift Tests/QuickCommandSupportTests.swift
```

Expected checks:

```text
FloatingWorkspaceSidebarSurface contains .background(ArgoTheme.sidebarBackground, in: panelShape)
WorkspaceSidebarView no longer contains .background(ArgoTheme.sidebarBackground)
QuickCommandSupportTests checks the full sidebar background count
```

- [ ] **Step 2: Confirm working tree only contains intended implementation files**

Run:

```sh
git status --short
```

Expected output includes only:

```text
 M Argo/UI/MainWindowView.swift
 M Argo/UI/Sidebar/WorkspaceSidebarView.swift
 M Tests/QuickCommandSupportTests.swift
?? docs/superpowers/plans/2026-06-10-single-surface-workspace-sidebar.md
```

The plan file may already be tracked if it was committed before execution.

- [ ] **Step 3: Commit the implementation**

Run:

```sh
git add Argo/UI/MainWindowView.swift Argo/UI/Sidebar/WorkspaceSidebarView.swift Tests/QuickCommandSupportTests.swift
git commit -m "fix: make workspace sidebar a single surface"
```

Expected result:

```text
[main <sha>] fix: make workspace sidebar a single surface
```

## Self-Review

- Spec coverage: Tasks 2 and 3 implement the single-surface visual model; Task 1 locks the structure in tests; Task 4 covers automated verification; Task 5 covers review and commit.
- No unfinished entries remain.
- Type and symbol consistency: all referenced symbols already exist in the codebase: `FloatingWorkspaceSidebarSurface`, `WorkspaceSidebarView`, `ArgoTheme.sidebarBackground`, `panelShape`, and `QuickCommandSupportTests`.
