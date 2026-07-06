# Workspace Sidebar 终端对齐 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让左侧 workspace sidebar 的独立浮动卡片与右侧终端 surface 的上下边缘对齐，同时保留当前 single-surface 视觉方向。

**Architecture:** 只调整 `FloatingWorkspaceSidebarSurface` 的外层垂直 padding 和内部填充策略。终端 surface、sidebar 内部树、搜索框、footer、选择、多选、右键菜单、拖拽和键盘交互保持不变。

**Tech Stack:** SwiftUI、AppKit bridge、XCTest、Xcode `xcodebuild`。

---

## File Structure

- Modify: `Tests/QuickCommandSupportTests.swift`
  - 更新现有源码结构测试 `testMainWindowWrapsWorkspaceSidebarInFloatingSurface()`。
  - 锁定 sidebar surface 新的垂直 padding：`top: 6, bottom: 6`。
  - 增加断言，要求 `FloatingWorkspaceSidebarSurface` 内容显式撑满可用高度。

- Modify: `Argo/UI/MainWindowView.swift`
  - 在 `FloatingWorkspaceSidebarSurface.body` 的 `content()` 后增加 `.frame(maxWidth: .infinity, maxHeight: .infinity)`。
  - 将外层 padding 从 `.init(top: 10, leading: 10, bottom: 10, trailing: 10)` 改为 `.init(top: 6, leading: 10, bottom: 6, trailing: 10)`。

- Do not modify: `Argo/UI/Workspace/WorkspaceDetailView.swift`
  - 右侧终端区域已经通过 `.padding(6)` 定义垂直 inset，本次改动只让左侧跟随它。

---

### Task 1: 锁定 sidebar 与终端 surface 的垂直对齐

**Files:**
- Modify: `Tests/QuickCommandSupportTests.swift`
- Modify: `Argo/UI/MainWindowView.swift`

- [ ] **Step 1: Write the failing test**

在 `Tests/QuickCommandSupportTests.swift` 的 `testMainWindowWrapsWorkspaceSidebarInFloatingSurface()` 中，把相关断言更新为以下内容：

```swift
        XCTAssertTrue(mainWindowSource.contains("struct FloatingWorkspaceSidebarSurface<Content: View>: View"))
        XCTAssertTrue(mainWindowSource.contains("RoundedRectangle(cornerRadius: 8, style: .continuous)"))
        XCTAssertTrue(mainWindowSource.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"))
        XCTAssertTrue(mainWindowSource.contains(".background(ArgoTheme.sidebarBackground, in: panelShape)"))
        XCTAssertTrue(mainWindowSource.contains(".padding(.init(top: 6, leading: 10, bottom: 6, trailing: 10))"))
        XCTAssertTrue(mainWindowSource.contains(".shadow(color: .black.opacity(0.28), radius: 22, x: 14, y: 1)"))
```

保留同一个测试里的这些断言不变：

```swift
        XCTAssertNotNil(
            mainWindowSource.range(of: floatingSidebarPattern, options: .regularExpression),
            "WorkspaceSidebarView should be wrapped by the floating surface at the NavigationSplitView boundary."
        )
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

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/QuickCommandSupportTests/testMainWindowWrapsWorkspaceSidebarInFloatingSurface \
  test
```

Expected: FAIL，因为 `MainWindowView.swift` 还没有包含新的 `.frame(maxWidth: .infinity, maxHeight: .infinity)`，并且 padding 仍是 `top: 10, bottom: 10`。

- [ ] **Step 3: Write the minimal implementation**

在 `Argo/UI/MainWindowView.swift` 中，将 `FloatingWorkspaceSidebarSurface.body` 更新为：

```swift
    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .padding(.init(top: 6, leading: 10, bottom: 6, trailing: 10))
            .background(ArgoTheme.appBackground)
    }
```

- [ ] **Step 4: Run the focused test to verify it passes**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/QuickCommandSupportTests/testMainWindowWrapsWorkspaceSidebarInFloatingSurface \
  test
```

Expected: PASS。

- [ ] **Step 5: Run the full QuickCommandSupportTests file**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/QuickCommandSupportTests \
  test
```

Expected: PASS。

- [ ] **Step 6: Run the Debug build**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected: BUILD SUCCEEDED。

- [ ] **Step 7: Manual smoke test**

打开或保持当前 Argo Debug app，进入 workspace mode 后检查：

- 左侧 workspace 浮动卡片的上边缘与右侧终端 surface 上边缘对齐。
- 左侧 workspace 浮动卡片的下边缘与右侧终端 surface 下边缘对齐。
- 左侧仍有独立卡片感，水平 `leading/trailing` 呼吸空间没有被压掉。
- 搜索、选择、右键菜单、多选、拖拽、展开/折叠、footer actions 行为不变。
- Canvas / Overview 模式下 workspace sidebar 显隐逻辑不变。

- [ ] **Step 8: Commit**

Run:

```bash
git add Tests/QuickCommandSupportTests.swift Argo/UI/MainWindowView.swift
git commit -m "fix: align workspace sidebar with terminal surface"
```

Expected: commit succeeds with only the test and implementation files staged.

---

## Self-Review

- Spec coverage: 本计划覆盖已确认设计中的 `6px` 垂直 inset、content 撑满高度、保留水平浮动感、不修改终端 surface、不改变 sidebar 内部行为。
- Placeholder scan: 没有占位说明或未定义步骤。
- Type consistency: 使用的 SwiftUI modifier 名称与现有 `MainWindowView.swift` 和测试里的源码字符串断言一致。
