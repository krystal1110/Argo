# Argo 设计规范

> 本文档由现有 UI 代码提炼,UI 改动前必读。改动须遵守此处约定,不得引入未列出的新 token,除非有充分理由并在 SUMMARY 中说明。
>
> 权威来源:`Argo/Support/ArgoTheme.swift`(集中式 design token)。颜色优先用 `ArgoTheme.*`,不要散落写裸 RGB。

## 配色

Argo 是**深色主题** app,配色集中定义在 `Argo/Support/ArgoTheme.swift` 的 `enum ArgoTheme` 中,UI 各处通过 `ArgoTheme.xxx` 引用(全仓引用 500+ 次)。新 UI 应优先复用这些 token,而非自行编写 `Color(red:...)`。

### 背景层级(由暗到亮,营造深度)

| Token | 真实值(calibratedRGB) | 使用场景 |
| --- | --- | --- |
| `ArgoTheme.appBackground` | (0.045, 0.05, 0.062) | App 最底层窗口背景 |
| `ArgoTheme.canvasBackground` | (0.05, 0.055, 0.069) | 画布(Canvas)背景 |
| `ArgoTheme.chromeBackground` | (0.056, 0.062, 0.076, α0.96) | 工具栏/chrome 区域 |
| `ArgoTheme.sidebarBackground` | (0.058, 0.064, 0.079) | 左侧边栏背景 |
| `ArgoTheme.paneBackground` | (0.061, 0.068, 0.083) | 终端 pane 背景 |
| `ArgoTheme.panelBackground` | (0.067, 0.073, 0.089) | 面板/卡片背景(高频) |
| `ArgoTheme.paneHeaderBackground` | (0.072, 0.078, 0.094) | pane 头部条 |
| `ArgoTheme.panelRaised` | (0.074, 0.081, 0.099) | 抬升的面板(悬浮感) |
| `ArgoTheme.sidebarSearchBackground` | (0.078, 0.085, 0.102) | 侧边栏搜索框 |

### 强调色与语义色

| Token | 真实值 | 使用场景 |
| --- | --- | --- |
| `ArgoTheme.accent` | (0.25, 0.54, 0.98) 蓝 | 主强调色,选中/高亮 |
| `ArgoTheme.accentMuted` | (0.15, 0.27, 0.42) | 弱化的强调色 |
| `ArgoTheme.localAccent` | (0.2, 0.72, 0.63) 青绿 | 本地仓库/worktree 强调 |
| `ArgoTheme.success` | (0.31, 0.84, 0.52) 绿 | 成功状态 |
| `ArgoTheme.warning` | (0.94, 0.66, 0.21) 橙 | 警告状态 |
| `ArgoTheme.danger` | (0.92, 0.42, 0.34) 红 | 错误/危险状态 |
| `ArgoTheme.backdropBlue` | (0.11, 0.24, 0.47, α0.18) | 背景氛围光(蓝) |
| `ArgoTheme.backdropTeal` | (0.11, 0.39, 0.34, α0.14) | 背景氛围光(青) |

### 文字色(白色按透明度分级)

| Token | 真实值 | 使用场景 |
| --- | --- | --- |
| `ArgoTheme.tertiaryText` | white α0.9 | 接近主文字 |
| `ArgoTheme.secondaryText` | white α0.74 | 次级文字(高频) |
| `ArgoTheme.mutedText` | white α0.58 | 弱化/说明文字(最高频) |

> 说明:除上述 token 外,SwiftUI 系统语义色也大量使用,主要是 `.foregroundStyle(.secondary)`(79 次,弱化文字)、`.foregroundStyle(.white)`、`.primary`、`.tertiary`,以及状态色 `.red/.green/.orange/.cyan/.yellow/.blue`。能用 `ArgoTheme` 的优先用 token;纯系统场景才用语义色。

### 边框与填充

| Token | 真实值 | 使用场景 |
| --- | --- | --- |
| `ArgoTheme.border` | white α0.085 | 常规描边(高频) |
| `ArgoTheme.strongBorder` | white α0.16 | 强调描边 |
| `ArgoTheme.subtleFill` | white α0.05 | 轻微填充(hover/底纹) |
| `ArgoTheme.subtleRaisedFill` | white α0.08 | 抬升填充 |

### 侧边栏专用(NSColor,供 NSOutlineView 桥接)

| Token | 真实值 | 使用场景 |
| --- | --- | --- |
| `ArgoTheme.sidebarSelectionFill` | (0.11, 0.15, 0.24) | 选中行填充 |
| `ArgoTheme.sidebarSelectionStroke` | (0.26, 0.45, 0.78, α0.92) | 选中行描边 |
| `ArgoTheme.sidebarHoverFill` | (0.11, 0.12, 0.16) | hover 行填充 |
| `ArgoTheme.dividerColor` | white α0.08 | 分隔线 |

### 侧边栏图标调色板(可选标签色,非通用 token)

`Argo/UI/Sidebar/WorkspaceSidebarView.swift` 的 `SidebarIconPaletteDescriptor` 定义了一组**柔和浅色**(如 `.sand` = (1.0, 0.95, 0.86)、`.lavender`、`.mint` 等十余种),专用于用户给仓库/工作区选图标颜色。**这些是离散调色板,不是设计 token**,不要在其他 UI 复用其裸值。

### 通用基础色

`Color.white`(69 次,多配 `.opacity()`)、`Color.clear`、`Color.black`(常配 `.opacity(0.35)` 做遮罩)、`Color.accentColor`。命令面板遮罩用 `Color.black.opacity(0.35)`。

## 字体层级

全部走 `.font(.system(size:weight:))`,**无自定义字体文件**。等宽场景加 `design: .monospaced`(终端/路径/数字)。常用档位:

| 尺寸/字重 | 频次 | 典型用途 |
| --- | --- | --- |
| `size:11, .medium` | 60 | 正文/列表项(最高频) |
| `size:12, .semibold` | 30 | 小标题/强调标签 |
| `size:11, .semibold` | 23 | 强调小标签 |
| `size:12, .medium` | 22 | 正文 |
| `size:10, .semibold` | 21 | 角标/徽章文字 |
| `size:13, .semibold` | 16 | 区块标题 |
| `size:11`(常规) | 14 | 普通正文 |
| `size:10, .medium` | 12 | 辅助说明 |
| `size:12, .monospaced` | 11 | 等宽内容(路径/代码) |
| `size:13` / `size:13, .medium` | 10 / 10 | 正文/列表 |
| `size:18, .semibold` | 6 | 较大标题 |

更大字号(`20/22/24/32`)用于空状态插画标题、欢迎页等少数场景。语义字体 `.headline`(5 次)、`.title2.weight(.semibold)`(3 次)、`.system(.body, design: .monospaced)` 也有少量使用。

**归纳**:
- **说明/弱化文字**:`size:9–10`,`.medium`
- **正文/列表项**:`size:11–13`,`.regular`/`.medium`
- **标题/强调**:`size:12–18`,`.semibold`
- **等宽**(终端、路径、commit hash、数字):任意尺寸 + `design: .monospaced`,常配 `.bold`
- 部分组件按 `uiScale`(`store.appSettings.uiScale`)缩放,写法如 `size: 9 * uiScale`,新组件如需跟随用户缩放应沿用该模式。

## 间距与圆角

### 间距档位(`spacing:` 与 `.padding`)

主梯度为 **2 / 4 / 6 / 8 / 10 / 12 / 16**(8 与 12 最高频),再大用 14 / 18 / 20 / 24。

| 值 | 频次(spacing) | 说明 |
| --- | --- | --- |
| 8 | 66 | 最常用基础间距 |
| 12 | 56 | 次常用,区块内间距 |
| 0 | 42 | 紧贴布局 |
| 10 | 41 | 中等间距 |
| 6 | 36 | 紧凑间距 |
| 4 | 31 | 细间距 |
| 2 | 13 | 极细间距 |
| 16 | 13 | 区块间距 |

`.padding` 常用:`.horizontal, 10/12/16`、`.vertical, 6/8`、整体 `.padding(12/14/10/16/20)`。缩放场景如 `.padding(.trailing, 8 * uiScale)`。

### 圆角档位(`RoundedRectangle(cornerRadius:)`)

主梯度 **2 / 3 / 4 / 5 / 6 / 7 / 8 / 9 / 10 / 11**(4 / 7 / 6 / 5 最高频),个别 12;**胶囊**用 `cornerRadius: 999`。统一用 `style: .continuous`(平滑圆角)的居多。

| 值 | 频次 | 说明 |
| --- | --- | --- |
| 4 | 34 | 小元素(图标底、徽章) |
| 7 | 29 | 卡片/按钮 |
| 6 | 26 | 卡片/输入框 |
| 5 | 26 | 中小元素 |
| 2 / 3 | 15 / 14 | 极小元素(如 `ToolbarFeatureIcon` 用 2) |
| 8–11 | 各约 10 | 较大面板/容器 |
| 999 | 2 | 胶囊(toolbar 分组等) |

## 可复用组件

位于 `Argo/UI/Components/`,新 UI 应优先复用:

| 组件 | 文件 | 用途 |
| --- | --- | --- |
| `CommandPaletteView` | `CommandPaletteView.swift` | 命令面板(⌘K 风格),含搜索框、遮罩、列表,接 `WorkspaceStore` |
| `GlassToolbarGroup` / `GlassToolbarIconButton` 等 | `GlassChromeControls.swift` | 玻璃质感工具栏控件:胶囊分组容器、图标按钮,配套 `.insetToolbarCapsuleSurface()` 修饰符 |
| `GlobalModeRailView` / `GlobalModeRailButton` | `GlobalModeRailView.swift` | 最左侧全局模式切换竖向导航栏(按 `MainWindowMode` 渲染),支持 `uiScale` |
| `PreviewWebView` / `PreviewWebEngine` | `PreviewWebView.swift` | 复用单个 `WKWebView` 的网页/Markdown/HTML 预览,发布导航状态 |
| `TerminalHostView` | `TerminalHostView.swift` | `NSViewRepresentable`,把 Ghostty 终端 `nsView` 桥接进 SwiftUI,管理 surface 附着与焦点 |
| `ToolbarFeatureIcon` | `ToolbarFeatureIcon.swift` | 带圆角底色(`cornerRadius: 2`、`tint.opacity(0.18)`)的小号 SF Symbol 图标(16×16) |

> 全局主题入口:`Argo/Support/ArgoTheme.swift`(所有颜色 token)。
> 工具栏玻璃表面等自定义 ViewModifier 定义在 `GlassChromeControls.swift` 附近,如 `.insetToolbarCapsuleSurface()`。

## 该做 / 不该做

- ✅ 复用上述组件与 `ArgoTheme.*` token;新 UI 跟随现有 AppKit 容器 + SwiftUI 内容架构
- ✅ 颜色一律走 `ArgoTheme.xxx`,需要新色先考虑现有 token 是否够用;文字色用 `mutedText/secondaryText/tertiaryText` 三级
- ✅ 间距从 2/4/6/8/10/12/16 取值,圆角从 2–11(+ 999 胶囊)取值,跟随用户缩放时用 `* uiScale`
- ✅ 字体走 `.system(size:weight:)`;等宽内容加 `design: .monospaced`
- ❌ 不引入与现有深色风格冲突的新配色,不在 UI 里散写裸 `Color(red:...)`(侧边栏图标调色板除外,且仅限其原用途)
- ❌ 不绕过 `ArgoTheme` 自定义一套并行色板
- ❌ 不为小改动重写大段 UI,不破坏侧边栏 `NSOutlineView` 桥接与终端 Ghostty 集成(遵守 CLAUDE.md 修改约定)
