# Single-Surface Workspace Sidebar Design

## 背景

当前 `MainWindowView` 已经用 `FloatingWorkspaceSidebarSurface` 包住 `WorkspaceSidebarView()`，左侧工作区具备了浮动外壳、圆角、描边和阴影。

用户反馈的问题是：实际视觉像“工作区套了两个框”。原因不是浮动方向错了，而是外层浮动壳和 `WorkspaceSidebarView` 内部完整 `ArgoTheme.sidebarBackground` 同时显形，搜索区顶部背景和 footer 分隔又进一步强化了盒中盒感。

本次选择视觉方向 B：保留 Argo 深色风格，做成单一浮动面板，而不是更贴边、更系统化的 Xcode source list 方向 C。

## 目标

- 左侧 workspace sidebar 看起来像一整块深色浮动面板。
- 视觉上只保留一条主外轮廓，消除“外框 + 内框”的双框感。
- 搜索区、列表区、footer 像长在同一块材质上，而不是各自装在不同容器里。
- 保留现有 `NSOutlineView` 桥接、选择、多选、右键菜单、拖拽、键盘操作和 footer actions。
- 不改变 sidebar column 宽度策略和 workspace/canvas/overview 的显示逻辑。

## 非目标

- 不把侧栏改成 Xcode C 方案那种贴左边、弱圆角的系统 source list。
- 不重做 workspace / worktree / group 行样式。
- 不修改 `SidebarOutlineContainerView` 的滚动、document sizing、footer hosting 架构。
- 不调整 terminal pane、preview、file tree、global mode rail。
- 不新增用户设置开关。

## 设计

### 1. 外层 surface 成为唯一面板

`FloatingWorkspaceSidebarSurface` 继续负责 sidebar 的面板语义：

- 圆角裁剪。
- 外轮廓描边。
- 顶部轻高光。
- 向右投射的阴影。
- 面板底色或材质。

它应是用户能感知到的唯一大轮廓。内部内容不再自己绘制另一整块面板背景。

### 2. 内部 sidebar 背景降级

`WorkspaceSidebarView` 根视图当前铺满 `ArgoTheme.sidebarBackground`。这会在外层圆角内再形成一块实心矩形，导致双框感。

调整方向：

- `WorkspaceSidebarView` 根背景改为透明，或改成只透传外层面板底色。
- 顶部搜索容器不再用一整块 `sidebarBackground` 横条强化内部盒子。
- 顶部和 footer 仍可保留轻量分隔线，但透明度应弱于外层面板描边。
- 搜索框自身继续保留局部输入背景和细描边，这是控件边界，不属于大面板边界。

### 3. 保持内容布局稳定

本次不改变以下尺寸和交互：

- 搜索框 padding、字号、prompt。
- outline row height、indentation、selection highlight。
- footer 的按钮结构和高度。
- sidebar column width：`min: 210, ideal: 260, max: 340`。
- `FloatingWorkspaceSidebarSurface` 的 `10px` inset 和现有阴影尺度。

如果实现中需要让顶部/底部区域更贴合单一面板，只做背景和分隔线层面的微调，不移动控件。

## 影响范围

预计涉及：

- `Argo/UI/MainWindowView.swift`
  - 可能给 `FloatingWorkspaceSidebarSurface` 添加真实面板底色，让它成为唯一 surface。
  - 保持 `WorkspaceSidebarView()` 的包裹关系和 column width 不变。

- `Argo/UI/Sidebar/WorkspaceSidebarView.swift`
  - 根背景从实心 sidebar background 调整为透明。
  - 搜索区横条背景调整为透明或弱化材质。
  - 必要时弱化搜索区底部分隔线，避免它像内部面板边框。

- `Tests/QuickCommandSupportTests.swift`
  - 更新源码约束测试，锁住“外层负责浮动面板、内部不拥有浮动外壳”的边界。

## 测试

新增或更新轻量结构测试：

- `MainWindowView` 仍然使用 `FloatingWorkspaceSidebarSurface { WorkspaceSidebarView() }`。
- `FloatingWorkspaceSidebarSurface` 仍保留圆角、描边、阴影和 `10px` inset。
- `WorkspaceSidebarView.swift` 不再在根视图和顶部搜索横条上重复铺完整 `ArgoTheme.sidebarBackground`。
- `SidebarOutlineContainerView` 和 `SidebarOutlineView` 的核心声明仍存在，避免误改桥接结构。

实现后至少运行：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/QuickCommandSupportTests \
  test
```

如果源码或 SwiftUI 编译层面有风险，再运行：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

## 手动验收

- Workspace mode 下左侧 sidebar 只有一层浮动面板轮廓。
- 面板右侧阴影仍让 sidebar 从主内容上浮出来。
- 搜索框看起来是面板内控件，而不是另一块卡片的开头。
- 列表区和 footer 视觉上属于同一块面板。
- 搜索、选择、右键菜单、多选、拖拽、展开/折叠、footer actions 行为不变。
- Canvas / Overview 模式下 workspace sidebar 仍按原逻辑隐藏，回到 Workspace 后状态恢复。

## 自查

- 没有未完成条目。
- 范围只覆盖左侧 workspace sidebar 的视觉层级。
- 选择 B 方案，不混入 C 方案的贴边 source list 改造。
- 测试策略覆盖结构约束和编译验证。
