# Prowl Dynamic Tint Visual Refresh Design

## 目标

将 Argo 主窗口视觉调整为已确认的 **A2：Prowl 原味结构 + 平衡强度动态 tint**。

目标效果：

- 顶栏、左侧全局 rail / workspace sidebar 背后、terminal tab bar 形成连续的 Prowl 式动态 chrome。
- tint 跟随当前仓库 / 工作区颜色变化，而不是固定蓝色。
- tint 强度采用 A2 中档：颜色明确可感知，但不把终端正文区域染得过满。
- 终端主体仍保持 Argo 深色工作区的可读性和专注度。
- 保留现有 sidebar、terminal、Ghostty、pane layout 的行为，不重写核心交互。

## 已确认方向

用户先选择了视觉方向 **A：Prowl 原味移植**，随后确认 tint “像 Prowl 一样跟随当前仓库/工作区颜色变化”，最后选择强度 **A2：平衡动态 tint**。

这意味着本次不是 Graphite 系统灰，也不是只做固定品牌色，而是把当前 workspace / worktree 的颜色带入窗口 chrome。

## 当前系统

Argo 当前主要视觉入口：

- `Argo/Support/ArgoTheme.swift` 集中定义深色背景、文字、边框、强调色 token。
- `Argo/UI/MainWindowView.swift` 绘制顶部 `topGlassChrome`、`GlobalModeRailView`、`FloatingWorkspaceSidebarSurface` 和主内容切换。
- `Argo/UI/Workspace/WorkspaceDetailView.swift` 绘制 `TerminalWorkspaceSurface`、`TerminalLocalChrome` 和 terminal split tree。
- `Argo/UI/Sidebar/WorkspaceSidebarView.swift` 负责 sidebar 内容、`NSOutlineView` 桥接、行内容、选择态、hover、context menu、多选、拖拽。
- `Argo/UI/Components/GlassChromeControls.swift` 提供顶部玻璃胶囊组与图标按钮。

Argo 当前颜色来源：

- workspace 图标由 `WorkspaceStore.sidebarIcon(for workspace:)` 解析，先看 `workspace.workspaceIconOverride`，再看默认 repository/local terminal icon，最后按 repository seed 生成。
- worktree 图标由 `WorkspaceStore.sidebarIcon(for worktree:in:)` 解析，先看 `workspace.iconOverride(for:)`，再看默认 worktree icon，最后按 worktree seed 生成。
- `SidebarIconPalette` 的实际颜色由 `SidebarIconPalette.descriptor` 提供，包含 `foreground`、`solidBackground`、`gradientStart`、`gradientEnd` 和 `border`。

Prowl 参考机制：

- `WindowChromeTint` 将当前 repository color 解析成 `Fill(color, alpha)`。
- tint band 覆盖 toolbar top inset、leading sidebar inset 和 terminal tab bar 背景。
- repository color 缺失时使用中性 fallback，避免无色仓库变成随机强色。

## 设计方案

### 1. 新增动态 chrome tint 模型

新增 Argo 侧的 tint 解析模型，建议放在 `Argo/Support/ArgoChromeTint.swift`。

核心概念：

```swift
struct ArgoChromeTintFill: Equatable {
    let color: Color
    let alpha: Double
}
```

建议默认强度对应 A2：

- top chrome alpha：约 `0.20`。
- leading chrome alpha：约 `0.16`。
- sidebar panel overlay alpha：约 `0.07`。
- terminal tab bar alpha：约 `0.17`。
- selected row / active control alpha：约 `0.20-0.22`。
- ambient glow alpha：约 `0.10`。

实现时可以用一个模型表达不同 region 的 alpha，例如：

```swift
struct ArgoChromeTint {
    let baseColor: Color
    let topAlpha: Double
    let leadingAlpha: Double
    let sidebarAlpha: Double
    let tabBarAlpha: Double
    let selectionAlpha: Double
}
```

如果实现更简单，也可以保留 `Fill(color, alpha)`，在不同 view 中用固定的 region alpha。

### 2. Tint 来源优先级

在 `WorkspaceStore` 或一个轻量 helper 中解析当前 workspace tint。

优先级：

1. 如果 `selectedWorkspace` 支持 repository features，并且 `activeWorktreePath` 能匹配到一个 `WorktreeModel`，使用该 worktree 的 `SidebarItemIcon.palette`。
2. 如果没有可用 worktree icon，使用 selected workspace 的 `SidebarItemIcon.palette`。
3. 如果没有 selected workspace，使用 `ArgoTheme.accent`。
4. 对 `.slate`、`.smoke`、`.charcoal`、`.graphite`、`.mocha` 这类低彩度 palette，允许保持低饱和 tint，不强行映射成蓝色；这能让用户选择灰色图标时得到更安静的窗口。

从 `SidebarIconPaletteDescriptor` 取 tint 色时，优先使用：

- 彩色 palette：`gradientEnd` 作为 chrome base，色彩更像 Prowl 的 repository color。
- 灰阶 palette：`foreground` 或 `border` 需要降低 alpha，避免灰色 tint 变成脏白块。

最终规则在测试中固定，不依赖视图里的临时判断。

### 3. Top chrome

`MainWindowView.topGlassChrome` 继续保留当前结构和业务按钮。

视觉调整：

- 背景从单纯 `ArgoTheme.chromeBackground.opacity(0.68)` 改为 material + dynamic tint。
- top band 使用 selected tint，类似 Prowl 的 toolbar chrome。
- 保留现有顶部高光、底部分隔线和 glass capsule controls。
- capsule 控件背景继续用玻璃质感，但可让 active / accent 图标使用动态 tint，而不是全部固定 `ArgoTheme.accent`。

不改变：

- toolbar 高度。
- command palette、quick command、workflow、HAPI、sleep prevention、file tree、web preview、external editor 的行为。
- accessibility label、help、disabled 状态语义。

### 4. Left rail 与 floating sidebar

`GlobalModeRailView` 和 `FloatingWorkspaceSidebarSurface` 背后形成 Prowl 式 leading chrome。

视觉调整：

- 左侧 leading 区域加入同源 tint band。
- `FloatingWorkspaceSidebarSurface` 保持浮动面板，但面板背景叠加少量 tint overlay。
- sidebar panel 内部仍是一块独立深色玻璃面板，A2 中不让它变成强彩色。
- rail active button 使用动态 tint，inactive 仍保持 Argo 现有深色填充。

不改变：

- `WorkspaceSidebarView` 的 `NSOutlineView` 桥接。
- 搜索、选择、右键、多选、拖拽、展开/折叠、footer actions。
- sidebar 宽度和 resize 行为。

### 5. Terminal chrome 与 tab bar

`TerminalWorkspaceSurface` 继续是主工作区容器。

视觉调整：

- `TerminalWorkspaceSurfaceStyle.chromeFill` / `TerminalLocalChrome` 背景接入同源 tint，形成 terminal 上方局部 chrome。
- terminal tab bar 背后使用动态 tint，强度接近 Prowl 的 tab row，但维持 A2 中档。
- active tab 胶囊仍以亮度层级表达，不直接填满强色，避免文字可读性下降。
- terminal 正文背景不被 tint 覆盖；Ghostty surface 的背景透明/模糊设置继续按现有 app settings 生效。

不改变：

- Ghostty runtime。
- `SplitNodeView` 和 pane layout。
- terminal session lifecycle。
- preview / file tree 的行为。

### 6. Canvas / Overview

本次优先覆盖主 workspace 模式。

Canvas 和 Overview 采用保守策略：

- 可以继承顶栏动态 tint，保持窗口一致性。
- 不在 canvas card 或 overview card 内部额外套用强 tint。
- 如果实现中发现 Canvas / Overview 背景被过度染色，第一版允许只让 top chrome 跟随 tint，内容区域保持现有 `ArgoTheme.appBackground` / `canvasBackground`。

## 行为

- 切换 workspace 后，top chrome、leading chrome、sidebar surface 和 terminal tab bar 使用新 workspace 的 tint。
- 切换 active worktree 后，若 active worktree 有可解析图标色，chrome tint 随 worktree 更新。
- 用户自定义 workspace / worktree 图标 palette 后，下一次相关状态刷新或界面重绘应反映新 tint。
- 未选择 workspace 时显示默认 accent tint 或现有 neutral chrome，不出现空白或透明异常。
- 终端背景透明设置小于 `1` 时，动态 tint 只作用在 chrome 区域，不破坏背景 blur。

## 测试

需要增加或更新 focused tests：

- `ArgoChromeTint` 从 workspace icon palette 解析出正确 base color。
- active worktree palette 优先于 workspace palette。
- local terminal / 无 worktree 的 workspace 使用 workspace palette。
- 无 selected workspace 时 fallback 到默认 accent。
- 灰阶 palette 使用低强度 tint，不产生比彩色 palette 更亮的 chrome。
- 源码约束测试确认 `MainWindowView`、`FloatingWorkspaceSidebarSurface`、`TerminalWorkspaceSurfaceStyle` 使用动态 tint helper，而不是散写裸 RGB。

实现后至少运行：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/QuickCommandSupportTests \
  -only-testing:ArgoTests/WorkspaceStoreTests \
  test
```

并运行一次 Debug build：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

## 手动验收

- 打开 Argo 后，窗口顶栏、左侧 chrome、terminal tab bar 呈现同源动态 tint。
- 切换不同 workspace / worktree，chrome 色彩跟随变化。
- A2 强度下，颜色可感知但不抢终端正文注意力。
- 蓝、青绿、橙 / 金、粉 / 紫、灰阶 palette 都可读、不过曝、不显脏。
- sidebar 搜索、选择、右键、多选、拖拽、footer actions 正常。
- terminal tab、split、preview、file tree、command palette 行为不变。
- terminal background opacity / blur 设置仍按现有逻辑工作。

## 非目标

- 不新增用户设置开关；第一版作为默认视觉更新。
- 不实现 Prowl 的完整 settings 模型或 window tint mode picker。
- 不改 Ghostty runtime 或 terminal rendering。
- 不重写 `WorkspaceSidebarView` 的 `NSOutlineView` 桥接。
- 不把 Canvas / Overview 的内容卡片改成强 tint 主题。

## 自查

- 没有待补内容。
- 方案明确选择 A2，不混入 B / C 方向。
- tint 来源、fallback、作用区域、非目标和测试均已写明。
- 实现范围集中在 chrome tint、top/leading/sidebar/tab bar 视觉，不扩大到 terminal runtime 或 sidebar 交互重构。
