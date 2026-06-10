# Workspace Sidebar Terminal Alignment Design

## 背景

上一轮改动已经把左侧 workspace sidebar 调整为单一浮动面板，解决了“两个框”的问题。

新的视觉反馈是：左侧工作区卡片仍然应该保持独立浮动卡片感，但它和右侧终端 surface 的上下边缘没有对齐，左侧明显比终端矮一截。

当前结构中：

- 右侧终端 surface 位于 `WorkspaceDetailView` 的内容区域内，外层有 `.padding(6)`。
- 左侧 sidebar surface 位于 `MainWindowView` 的 `FloatingWorkspaceSidebarSurface` 中，外层 padding 为 `top: 10, bottom: 10`。
- 左侧 surface 没有显式声明要撑满可用高度。

这会让左侧浮动卡片的 top/bottom inset 比右侧终端多 `4px`，视觉上形成上下不齐。

## 目标

- 保留左侧 workspace sidebar 的独立浮动卡片感。
- 让左侧卡片的上边缘和下边缘与右侧终端 surface 对齐。
- 不改变 sidebar 的宽度策略、内部列表、搜索框、footer、选择、多选、右键菜单、拖拽、键盘操作。
- 不修改终端布局或 `TerminalWorkspaceSurface`。

## 设计

### 1. 统一垂直 inset

将 `FloatingWorkspaceSidebarSurface` 的垂直 padding 从 `10` 调整为 `6`：

```swift
.padding(.init(top: 6, leading: 10, bottom: 6, trailing: 10))
```

这样左侧卡片的 top/bottom inset 与 `WorkspaceDetailView` 内终端区域的 `.padding(6)` 保持一致。

### 2. 保留水平浮动感

`leading` 和 `trailing` 继续保留 `10`。

原因：

- 左侧仍需要和 global mode rail、右侧内容之间保持呼吸空间。
- 用户明确希望保留独立浮动卡片感。
- 问题只在上下对齐，不在水平距离。

### 3. 明确 surface 撑满高度

给 `FloatingWorkspaceSidebarSurface` 内部 content 增加：

```swift
.frame(maxWidth: .infinity, maxHeight: .infinity)
```

让 sidebar surface 和终端 surface 一样明确占满可用高度，再由外层 padding 决定最终外边缘。

### 4. 不改内部视觉层级

保持上一轮 single-surface 设计：

- `FloatingWorkspaceSidebarSurface` 继续拥有完整背景、圆角、描边和阴影。
- `WorkspaceSidebarView` 不重新铺整块 `ArgoTheme.sidebarBackground`。
- 搜索框自身背景保留。
- 顶部分隔线保持弱化状态。

## 影响范围

预计只涉及：

- `Argo/UI/MainWindowView.swift`
  - 修改 `FloatingWorkspaceSidebarSurface` 的 content frame。
  - 修改 surface padding 的 top/bottom 数值。

- `Tests/QuickCommandSupportTests.swift`
  - 更新 sidebar floating surface 结构测试，锁住新的 `top: 6, bottom: 6`。
  - 可补充检查 content frame，使 surface 高度意图明确。

## 测试

更新结构测试：

- `MainWindowView.swift` 包含 `.frame(maxWidth: .infinity, maxHeight: .infinity)`。
- `FloatingWorkspaceSidebarSurface` padding 为 `.init(top: 6, leading: 10, bottom: 6, trailing: 10)`。
- 继续保留 single-surface 断言：外层拥有 `ArgoTheme.sidebarBackground`，内部 `WorkspaceSidebarView` 不拥有完整背景。

实现后运行：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/QuickCommandSupportTests \
  test
```

再运行：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

## 手动验收

- Workspace mode 下，左侧 workspace 卡片和右侧终端 surface 的 top/bottom 外边缘对齐。
- 左侧仍保留独立浮动卡片感和水平呼吸空间。
- 搜索、选择、右键菜单、多选、拖拽、展开/折叠、footer actions 行为不变。
- Canvas / Overview 模式下 workspace sidebar 显隐逻辑不变。

## 自查

- 范围只覆盖左侧 surface 与终端 surface 的垂直对齐。
- 不改变终端 surface。
- 不引入新的视觉方向。
- 没有未完成条目。
