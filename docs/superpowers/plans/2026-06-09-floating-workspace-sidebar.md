# Floating Workspace Sidebar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 workspace sidebar 做成已确认的 B 方向浮动面板，同时保持内部列表和交互不变。

**Architecture:** 在 `MainWindowView` 的 `NavigationSplitView` sidebar column 外层新增一个小型 SwiftUI surface 组件，包裹现有 `WorkspaceSidebarView()`。用源码约束测试确保浮层只发生在外层，`WorkspaceSidebarView.swift` 的 `NSOutlineView` 桥接结构不被重做。

**Tech Stack:** SwiftUI、AppKit `NavigationSplitView` / `NSOutlineView` bridge、XCTest 源码约束测试、`xcodebuild`

---

### Task 1: 外层浮动 Sidebar Surface

**Files:**
- Modify: `Tests/QuickCommandSupportTests.swift`
- Modify: `Argo/UI/MainWindowView.swift`

- [ ] **Step 1: Write the failing test**

在 `Tests/QuickCommandSupportTests.swift` 的 `testTopChromeUsesInsetToolbarSurfaces()` 后面增加测试方法：

```swift
    func testMainWindowWrapsWorkspaceSidebarInFloatingSurface() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let mainWindowSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/MainWindowView.swift"),
            encoding: .utf8
        )
        let sidebarSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Sidebar/WorkspaceSidebarView.swift"),
            encoding: .utf8
        )
        let floatingSidebarPattern = #"FloatingWorkspaceSidebarSurface\s*\{\s*WorkspaceSidebarView\(\)\s*\}\s*\.navigationSplitViewColumnWidth\(min: 210, ideal: 260, max: 340\)"#

        XCTAssertNotNil(
            mainWindowSource.range(of: floatingSidebarPattern, options: .regularExpression),
            "WorkspaceSidebarView should be wrapped by the floating surface at the NavigationSplitView boundary."
        )
        XCTAssertTrue(mainWindowSource.contains("struct FloatingWorkspaceSidebarSurface<Content: View>: View"))
        XCTAssertTrue(mainWindowSource.contains("RoundedRectangle(cornerRadius: 8, style: .continuous)"))
        XCTAssertTrue(mainWindowSource.contains(".padding(.init(top: 10, leading: 10, bottom: 10, trailing: 10))"))
        XCTAssertTrue(mainWindowSource.contains(".shadow(color: .black.opacity(0.28), radius: 22, x: 14, y: 1)"))
        XCTAssertFalse(
            sidebarSource.contains("FloatingWorkspaceSidebarSurface"),
            "The existing sidebar contents should not own the floating shell."
        )
        XCTAssertTrue(sidebarSource.contains("let outlineView = SidebarOutlineView()"))
        XCTAssertTrue(sidebarSource.contains("private final class SidebarOutlineContainerView: NSView"))
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/QuickCommandSupportTests/testMainWindowWrapsWorkspaceSidebarInFloatingSurface \
  test
```

Expected: FAIL，因为 `FloatingWorkspaceSidebarSurface` 尚不存在，`WorkspaceSidebarView()` 仍直接设置 `navigationSplitViewColumnWidth(min: 190, ideal: 240, max: 320)`。

- [ ] **Step 3: Write minimal implementation**

在 `Argo/UI/MainWindowView.swift` 中，将 `NavigationSplitView` 的 sidebar closure 从：

```swift
                    NavigationSplitView(columnVisibility: $layoutState.workspaceColumnVisibility) {
                        WorkspaceSidebarView()
                            .navigationSplitViewColumnWidth(min: 190, ideal: 240, max: 320)
                    } detail: {
```

改为：

```swift
                    NavigationSplitView(columnVisibility: $layoutState.workspaceColumnVisibility) {
                        FloatingWorkspaceSidebarSurface {
                            WorkspaceSidebarView()
                        }
                        .navigationSplitViewColumnWidth(min: 210, ideal: 260, max: 340)
                    } detail: {
```

在 `Argo/UI/MainWindowView.swift` 中、`MainWindowView` 之后且 `TimeCommandPaletteButtonLabel` 之前增加组件：

```swift
private struct FloatingWorkspaceSidebarSurface<Content: View>: View {
    @ViewBuilder var content: () -> Content

    private var panelShape: some Shape {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }

    var body: some View {
        content()
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
}
```

不要修改 `Argo/UI/Sidebar/WorkspaceSidebarView.swift`。

- [ ] **Step 4: Run test to verify it passes**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/QuickCommandSupportTests/testMainWindowWrapsWorkspaceSidebarInFloatingSurface \
  test
```

Expected: PASS。

- [ ] **Step 5: Commit**

```sh
git add Tests/QuickCommandSupportTests.swift Argo/UI/MainWindowView.swift
git commit -m "style: float workspace sidebar"
```

### Task 2: 回归验证

**Files:**
- No production edits expected.

- [ ] **Step 1: Run sidebar/layout regression tests**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceStoreTests/testMainWindowLayoutRestoresWorkspaceSidebarWhenReturningFromGlobalMode \
  -only-testing:ArgoTests/WorkspaceStoreTests/testMainWindowLayoutHidesWorkspaceSidebarWhenEnteringGlobalModes \
  -only-testing:ArgoTests/WorkspaceStoreTests/testMainWindowLayoutPreservesCollapsedWorkspaceSidebarAcrossGlobalModeRoundTrip \
  -only-testing:ArgoTests/WorkspaceStoreTests/testMainWindowLayoutPreservesExpandedWorkspaceSidebarWhenModeChangeIsObservedTwice \
  -only-testing:ArgoTests/WorkspaceStoreTests/testMainWindowLayoutKeepsWorkspaceSidebarStateWhenReselectingWorkspace \
  test
```

Expected: PASS。

- [ ] **Step 2: Run focused source-constraint suite**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/QuickCommandSupportTests \
  test
```

Expected: PASS。

- [ ] **Step 3: Run app build**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected: BUILD SUCCEEDED。

- [ ] **Step 4: Run diff hygiene check**

Run:

```sh
git diff --check
```

Expected: no output。

- [ ] **Step 5: Manual smoke test**

启动 Debug app 后手动确认：

- Workspace mode 下左侧 workspace 面板呈现浮起效果。
- `GlobalModeRailView` 仍贴边，不和 workspace sidebar 合成 dock。
- 搜索框可输入，workspace/worktree/group 行可选择。
- 右键菜单、多选、拖拽、展开/折叠、footer actions 正常。
- Toggle Sidebar 后折叠/展开正常。
- Canvas / Overview 隐藏 workspace sidebar，回到 Workspace 后 sidebar 状态恢复。
- 终端主区域没有被明显压窄，顶部 chrome 与左侧浮层视觉协调。

- [ ] **Step 6: Commit verification note if needed**

如果 Task 2 发现并修正了实现细节，提交修正：

```sh
git add Argo/UI/MainWindowView.swift Tests/QuickCommandSupportTests.swift
git commit -m "fix: refine floating sidebar surface"
```

如果没有代码变化，不提交。

---

## Self-Review

- Spec coverage: plan 覆盖了 B 方向、外层 surface、column width、保持 `WorkspaceSidebarView` 内部不动、layout 回归和手动 smoke test。
- Placeholder scan: 没有占位条目、延后实现条目或未定义步骤。
- Type consistency: `FloatingWorkspaceSidebarSurface<Content: View>`、`WorkspaceSidebarView()`、`navigationSplitViewColumnWidth(min: 210, ideal: 260, max: 340)` 在测试与实现步骤中一致。
