# Floating Workspace Sidebar Design

## Goal

将主窗口左侧 workspace 列表做成轻微“浮出来”的面板效果，采用已确认的 B 方向：workspace 面板本身浮起，内部内容和交互保持现状。

目标效果：

- 左侧 workspace 区域像一块独立面板浮在主画布上。
- 面板右侧有柔和阴影和少量呼吸空间，形成与终端主区域的层次。
- 搜索框、仓库行、选中态、footer、右键菜单、拖拽、多选、键盘操作不改。
- 不把全局 mode rail 一起做成 dock。

## Chosen Direction

采用“workspace 面板浮起，内容不重做”的方案。

视觉参考来自 brainstorming mockup B：

- `WorkspaceSidebarView` 仍然作为完整内容单元。
- 外层增加约 `10px` 的视觉 inset。
- 面板圆角约 `8px`，符合当前 Argo 控件圆角尺度。
- 面板使用当前深色主题，增加轻描边、顶部轻高光和右侧阴影。
- 主内容在面板右侧露出一点背景，使层级更明显。

## Current System

`MainWindowView` 当前结构：

- 顶部是 `topGlassChrome`。
- 主体是 `HStack`：
  - `GlobalModeRailView`
  - `NavigationSplitView`
- `NavigationSplitView` 的 sidebar column 直接渲染 `WorkspaceSidebarView()`。
- sidebar column 当前宽度为 `min: 190, ideal: 240, max: 320`。
- workspace、canvas、overview 的显示/隐藏由 `MainWindowLayoutState` 和 `store.mainWindowMode` 控制。

`WorkspaceSidebarView` 当前结构：

- SwiftUI `VStack` 顶部搜索区。
- `WorkspaceOutlineSidebar` 使用 `NSViewRepresentable` 桥接 `SidebarOutlineContainerView`。
- `SidebarOutlineContainerView` 内部包含 `NSScrollView`、`SidebarOutlineView` 和 footer hosting view。
- `SidebarOutlineView` 背景为 clear，行选择、context menu、drag reorder、多选和键盘行为由 coordinator 管理。

## Proposed Design

### 1. Floating Surface

在 `MainWindowView` 的 workspace sidebar column 外层加一个浮动 surface，而不是重写 `WorkspaceSidebarView` 内部。

概念结构：

```swift
FloatingWorkspaceSidebarSurface {
    WorkspaceSidebarView()
}
.navigationSplitViewColumnWidth(min: 210, ideal: 260, max: 340)
```

surface 职责：

- 提供外部 inset，让面板和 rail、主内容之间有空间。
- 提供 `RoundedRectangle(cornerRadius: 8, style: .continuous)` clip。
- 提供轻描边和右侧阴影。
- 提供 column 背景，避免 sidebar 仍然贴满整列。
- 不接管任何 workspace selection、outline、footer 或搜索逻辑。

建议视觉参数：

- 外部 padding：top/bottom/right `10px`，leading `10px`。
- 圆角：`8px`。
- 描边：`Color.white.opacity(0.12)`。
- 顶部高光：`Color.white.opacity(0.05)`。
- 阴影：黑色约 `0.26-0.32` opacity，radius `18-24`，x `12-16`，y `0-2`。
- 背景继续使用 `ArgoTheme.sidebarBackground` 或非常接近的同系深色，不引入新的主色调。

### 2. Column Width

因为外层 inset 会吃掉 sidebar 内容宽度，第一版应把 `NavigationSplitView` column 宽度同步加宽约 `20px`：

- min: `210`
- ideal: `260`
- max: `340`

这样内部 `WorkspaceSidebarView` 的有效内容宽度仍然接近当前 `190/240/320`，避免中文项目名、badge、footer 按钮因为浮层 padding 被意外压窄。

### 3. Global Mode Rail

`GlobalModeRailView` 保持当前贴边 rail 风格。

不把 rail 和 workspace sidebar 合并为一个整体 dock。这样视觉焦点只落在 workspace 面板上，主窗口结构变化更小，也符合用户选择的 B 方向。

### 4. Workspace Sidebar Contents

`WorkspaceSidebarView` 内部尽量不改。

如果实现时需要让内部背景适配圆角 clip，只允许做局部视觉配合，例如确保根背景仍然使用 `ArgoTheme.sidebarBackground`，或让内部边界不溢出圆角。禁止在这次改动里重做以下内容：

- 搜索框布局、字号、prompt 文案、border。
- workspace / worktree / group 行高度、缩进、图标、badge。
- 选中态、hover、drag destination feedback。
- footer 的 “Open Folder” 和 SSH 按钮布局。
- `SidebarOutlineContainerView` 的滚动、footer、document sizing 逻辑。
- coordinator 的 selection、expansion、context menu、多选、拖拽和键盘处理。

## Behavior

功能行为保持不变：

- sidebar toggle 仍由现有 `NSSplitViewController.toggleSidebar(_:)` 路径触发。
- workspace mode 显示浮动 workspace 面板。
- canvas / overview mode 仍隐藏 workspace sidebar column。
- 搜索、选择、双击、右键菜单、多选、拖拽、展开/折叠、footer actions 全部沿用现有实现。
- 当前选中 workspace、sidebar expansion 状态和全局 mode round trip 行为不改变。

## Testing

需要增加一个轻量源码约束测试，锁住这次改动的边界：

- `MainWindowView` 使用 `FloatingWorkspaceSidebarSurface` 包裹 `WorkspaceSidebarView()`。
- `NavigationSplitView` sidebar column 宽度更新为 `210/260/340`。
- `WorkspaceSidebarView.swift` 不引入新的 toolbar/dock 级重构标记，不改变 `SidebarOutlineContainerView` 的核心结构。

同时保留并运行现有布局状态测试：

- `WorkspaceStoreTests.testMainWindowLayoutRestoresWorkspaceSidebarWhenReturningFromGlobalMode`
- `WorkspaceStoreTests.testMainWindowLayoutHidesWorkspaceSidebarWhenEnteringGlobalModes`
- `WorkspaceStoreTests.testMainWindowLayoutPreservesCollapsedWorkspaceSidebarAcrossGlobalModeRoundTrip`
- `WorkspaceStoreTests.testMainWindowLayoutPreservesExpandedWorkspaceSidebarWhenModeChangeIsObservedTwice`
- `WorkspaceStoreTests.testMainWindowLayoutKeepsWorkspaceSidebarStateWhenReselectingWorkspace`

实现完成后运行：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceStoreTests \
  test

xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

## Manual Smoke Test

实现后手动检查：

- Workspace mode 下左侧 workspace 面板呈现浮起效果。
- 面板内部搜索、选择、右键菜单、拖拽、多选和 footer actions 正常。
- 折叠/展开 sidebar 后视觉边界正常。
- 切换到 Canvas / Overview 后 workspace 面板隐藏。
- 从 Canvas / Overview 回到 Workspace 后 sidebar 展开状态恢复。
- 终端主区域没有被过度压窄，顶部 chrome 与左侧浮层视觉协调。

## Out of Scope

- 不重做 `WorkspaceSidebarView` 的内部列表视觉。
- 不修改 `SidebarOutlineView` selection、drag、context menu、keyboard 逻辑。
- 不修改 terminal pane、tab strip、file tree、preview panel。
- 不修改 Ghostty runtime、pane layout 数据结构或 workspace persistence。
- 不新增用户设置开关；第一版作为默认视觉更新。
