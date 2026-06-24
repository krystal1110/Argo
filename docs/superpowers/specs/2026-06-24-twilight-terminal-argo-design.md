# Twilight Terminal Argo Design

## 目标

将 `twilight-terminal/设计规范.md` 中的 Twilight Terminal 视觉系统完整应用到 Argo 主工作区，同时保持现有功能不受影响。

目标效果：

- Argo 默认呈现深色、半透明、日落冷暖对比的终端工作区风格。
- UI chrome、侧栏、终端区域、Ghostty 终端 16 色都由同一个 seed 颜色生成。
- 默认 seed 为 `#ffb066`，与 `twilight-terminal/warp-themes/twilight.yaml` 的 Twilight 暮光预设一致。
- 保留规范中的三个设计签名：全局 `❯` prompt 符号、右下日落构图、单色驱动主题。
- 保留 Argo 现有工作区、侧栏、终端分屏、标签、预览、文件树、命令面板、设置和 Ghostty runtime 行为。

## 已确认方向

用户确认采用完整单色驱动方案，而不是只固定一套暮光色板，也不是只导入 Ghostty 终端配色。

本次设计以 `twilight-terminal/设计规范.md` 为权威视觉规范，并按 Argo 原生 macOS 架构落地：

- 规范中的 CSS 变量会映射为 Swift 主题 token。
- 规范中的 JavaScript `genTheme(seed)` 会移植为 Swift 纯算法。
- 规范中的 Warp YAML 色彩输出会映射为 Ghostty 配置输出。
- 规范中的 HTML 布局会映射到 Argo 已有窗口结构，不重写业务交互。

## 当前系统

Argo 当前主要视觉入口：

- `Argo/Support/ArgoTheme.swift` 定义应用级背景、文本、边框、强调色。
- `Argo/Support/ArgoChromeTint.swift` 根据当前 workspace / worktree 图标色推导动态 chrome tint。
- `Argo/UI/MainWindowView.swift` 绘制顶部 chrome、全局模式 rail、floating sidebar 外壳和主内容切换。
- `Argo/UI/Components/GlobalModeRailView.swift` 绘制左侧全局模式 rail。
- `Argo/UI/Sidebar/WorkspaceSidebarView.swift` 绘制工作区侧栏、`NSOutlineView` 桥接、搜索、footer、选择、多选、右键、拖拽。
- `Argo/UI/Workspace/WorkspaceDetailView.swift` 绘制终端标签栏、terminal workspace surface、preview tab、file tree。
- `Argo/UI/Workspace/TerminalLocalChrome.swift` 绘制终端本地标签 / 分屏 chrome。
- `Argo/UI/Workspace/TerminalPaneView.swift` 承载单个 Ghostty terminal pane、pane search 和状态条。
- `Argo/Services/Terminal/Ghostty/ArgoGhosttyConfig.swift` 写入 Argo 管理的 Ghostty config。
- `Argo/UI/Sheets/SettingsSheet.swift` 目前提供 Ghostty theme、字体、透明度和 blur 设置。

当前重要约束：

- 主窗口已经是透明窗口，窗口级 blur 被禁用。
- 终端透明度由 Ghostty `background-opacity` 负责。
- `TerminalWorkspaceSurface` 只在终端区域启用 `NSVisualEffectView` blur。
- 多个测试已经锁定 “terminal surface flush、sidebar floating shell、top chrome 不使用连续背景带” 等结构。

## 设计原则

### 1. 主题同源

Argo 不能把 Twilight 视觉拆成多套互不相干的硬编码色值。所有主题槽位都来自同一个 seed：

- UI 强调色：`amber`、`amber2`、`cyan`、`green`、`magenta`。
- 日落背景：右下太阳、冷色天空、水面、地平线暖光。
- Ghostty 终端色：foreground、background、ANSI normal 8 色、bright 8 色。
- Chrome tint：top、rail、sidebar、terminal tab bar、active selection、glow。

### 2. 功能结构不重写

本次只替换视觉系统和主题来源：

- 不替换 Ghostty runtime。
- 不重写 `WorkspaceSidebarView` 的 `NSOutlineView` 桥接。
- 不改变 pane layout、tab 数据结构、worktree switching、preview/file tree 行为。
- 不移动核心 action 的 store 调用。
- 不改变现有 keyboard shortcut、accessibility label 和 help 语义。

### 3. 透明分层只保留一层

严格遵守 Twilight 规范中的透明分层纪律：

- `NSWindow` 只保持透明，不加窗口级 blur。
- 顶栏、rail、sidebar 作为直接盖在窗口背景上的 chrome 区域，可以有局部 material / blur。
- 终端正文区域不通过嵌套 blur 保证可读性，而使用左浓右淡 scrim、Ghostty 背景透明度和轻量 overlay。
- 不能在 sidebar 内外重复绘制完整大面板，避免双框和双重模糊。

## 主题模型

### 1. 新增 Swift 主题引擎

新增文件：

- `Argo/Support/TwilightTheme.swift`

核心类型：

```swift
struct TwilightTheme: Equatable {
    let seedHex: String
    let amber: Color
    let amber2: Color
    let cyan: Color
    let green: Color
    let magenta: Color
    let wallpaper: TwilightWallpaper
    let ghostty: TwilightGhosttyTheme
}
```

`TwilightTheme.generate(seed:)` 精确移植规范中的 `genTheme(seed)`：

- `hexToHsl` 支持 `#RGB` 和 `#RRGGBB`。
- `clamp`、`hsl`、`hsla`、`lerpHue`、`hslToHex` 保持同一数学规则。
- 饱和度护栏：`S = clamp(s, 42, 96)`。
- UI 强调色亮度护栏保持规范数值。
- 天空色相拉向 `250`，水面色相拉向 `218`。
- ANSI 语义色锚定标准色相，只被 seed 轻染 `12%`。

`TwilightWallpaper` 不输出 CSS 字符串，而输出 SwiftUI 可绘制数据：

```swift
struct TwilightWallpaper: Equatable {
    let sunCore: TwilightRadialStop
    let sunGlow: TwilightRadialStop
    let skyWaterStops: [TwilightLinearStop]
}
```

这样 Argo 可以用 SwiftUI `LinearGradient`、`RadialGradient` 和 overlay 组合复现右下日落构图。

### 2. AppSettings 存储

扩展 `AppSettings`：

```swift
var twilightThemeEnabled: Bool
var twilightThemeSeedHex: String
```

默认值：

- `twilightThemeEnabled = true`
- `twilightThemeSeedHex = "#ffb066"`

迁移规则：

- 老配置缺失字段时启用 Twilight 默认值。
- seed 非法时回退 `#ffb066`。
- 现有 `terminalTheme` 字段保留，用于关闭 Twilight 或用户明确选择传统 Ghostty theme 的场景。

### 3. 预设

内置五个预设，与 `twilight-terminal/设计规范.md` 保持一致：

- `#ffb066`：Twilight 暮光。
- `#7af0c0`：Aurora 极光。
- `#5cc8ff`：Abyss 深海。
- `#ff9ec4`：Sakura 樱绯。
- `#ff7a59`：Ember 余烬。

预设名称用于设置 UI 和测试，不影响算法。

## ArgoTheme 映射

`ArgoTheme` 增加 Twilight 语义 token，但保留现有 token 名称供旧代码使用：

- `accent` 映射到 `theme.amber`。
- `localAccent` 映射到 `theme.cyan` 或 `theme.green`，按现有语义区分本地 / 成功。
- `success` 保持绿色语义，优先使用 `theme.green`。
- `warning` 保持暖色语义，优先使用 `theme.amber2`。
- `danger` 不直接由 seed 完全偏移，保持红色语义并做轻度 seed tint，避免错误状态失真。
- `mutedText`、`secondaryText`、`tertiaryText` 使用规范固定中性文字：`#969db2`、`#c8cfdf`、`#f3f5fb`。
- `border`、`strongBorder` 使用规范 `hairline` / `hairline-soft` 透明白。

为减少一次性改动风险，第一版保留 `ArgoTheme` 静态访问方式，内部由 `TwilightTheme.default` 提供默认色。后续设置 seed 时，通过 `WorkspaceStore` 暴露 `currentTwilightTheme` 给需要动态更新的 view。

## Chrome 与布局映射

### 1. 主窗口背景

`MainWindowView` workspace 模式增加 `TwilightWallpaperView`：

- 位于主窗口最底层。
- 使用 `TwilightTheme.wallpaper` 绘制右下太阳和冷色天空 / 水面渐变。
- 在非 workspace 模式仍可保留当前 `ArgoTheme.appBackground`，或只在顶栏继承 Twilight chrome。

`windowContentBackground` 在 workspace 模式保持 `.clear`，让壁纸和透明终端可见。

### 2. 顶栏

`topGlassChrome` 保留当前业务按钮和菜单，但视觉改为 Twilight 顶栏规范：

- 高度维持现有 `WorkspaceChromeMetrics.topHeight`，不破坏窗口布局。
- 背景使用 `topGlass` 语义：深色半透明 + 单层 material。
- 命令面板入口使用 `theme.amber` 描边和背景混合。
- 时钟使用 `theme.amber2`。
- 右侧 toolbar icons 使用 `theme.textDim`，hover 后提升到 `theme.text`。
- 外部编辑器、workflow、quick command、HAPI 等 action 不变。

`TimeCommandPaletteButtonLabel` 保留当前时段图标逻辑，但颜色并入 Twilight slots：

- sunset / default 高亮走 `amber` / `amber2`。
- 文案继续走 monospaced。

### 3. 全局 rail

`GlobalModeRailView` 视觉映射到规范 `.rail`：

- 宽度保持现有可缩放 `54 * uiScale`，不强行改到 HTML 的 `64px`。
- 背景使用 `glassRail`，只一层 material。
- active 按钮用 `theme.amber`。
- active 状态增加左侧发光竖条。
- hover 只提升弱填充和文字亮度。

### 4. Workspace sidebar

`FloatingWorkspaceSidebarSurface` 和 `WorkspaceSidebarView` 共同映射到规范 `.sidebar`：

- 外层 surface 负责唯一完整面板：`glassSide`、圆角、描边、弱阴影。
- 内部 `WorkspaceSidebarView` 不绘制第二层完整面板。
- 搜索框前缀从放大镜改为 `❯`，使用 monospaced 和 `theme.amber`。
- 搜索框保留现有 `TextField` 绑定和 query 过滤。
- footer 保留“打开文件夹”和 SSH 连接 action，视觉改为规范中的弱黑底、hairline 描边、hover amber 描边。

`SidebarOutlineRowView` / row content：

- 不改变 row 数据、选择、多选、右键、拖拽、展开/折叠。
- workspace 行 active 背景改为 `glassCardH`，hover 改为 `glassCard`。
- active 行增加左侧 amber 发光竖条。
- workspace 副标题前增加 `❯`，保留原分支 / 路径文本。
- pin、badge、status badge 使用 Twilight 语义色。

### 5. Terminal workspace surface

`TerminalWorkspaceSurface` 映射到规范 `.term`：

- 终端区背景保持极低不透明度。
- 透明终端模式不叠加 `.ultraThinMaterial`。
- 增加左浓右淡 scrim：左侧正文区较深，右侧日落区域更通透。
- 底部增加 2px 暖色地平线 glow。
- `TerminalPaneView` 的 `paneFill` 在透明时保持 `.clear`。
- pane search 和状态条使用 Twilight token，但不改变搜索生命周期或 Ghostty 调用。

### 6. Terminal local chrome

`TerminalLocalChrome` 保持现有 category / tab 行为：

- category pill 前缀使用 `❯`。
- active category 背景使用 `glassCardH`。
- inactive hover 使用 `glassCard`。
- split / plus 图标按钮保持原 action，但颜色和 hover 映射到 Twilight token。
- 不恢复每个 pane 内的旧 header，不改变 `WorkspaceDetailView` 中 terminal chrome 位于 split tree 之外的结构。

### 7. Command palette、Preview、Overview、Canvas

第一版覆盖主 workspace 视觉系统，同时保持其他模式可用：

- `CommandPaletteView` 使用 Twilight `panelBackground`、`subtleFill`、`accent`、`success`、`warning`、`danger`。
- Preview / file tree 继续使用现有结构，只替换 shared theme token。
- Overview / Canvas 继承新的 `ArgoTheme` token，但不强行应用终端壁纸构图，避免工作区外的内容卡片变得过度装饰。

## Ghostty 终端主题

### 1. 同源配置输出

`ArgoGhosttyConfigManager.managedConfigContents(settings:)` 在 Twilight enabled 时直接输出 Ghostty 颜色：

```text
background = #...
foreground = #...
palette = 0=#...
...
palette = 15=#...
```

颜色来自 `TwilightTheme.generate(seed: settings.twilightThemeSeedHex).ghostty`。

这与规范中的 Warp YAML 同源，但转换为 Ghostty config 格式。

### 2. 与现有 terminalTheme 的关系

优先级：

1. `twilightThemeEnabled == true`：使用 Twilight 生成色，并忽略 `terminalTheme` 的颜色输出。
2. `twilightThemeEnabled == false && terminalTheme != nil`：保持现有 Ghostty theme 查找和 inline 逻辑。
3. `twilightThemeEnabled == false && terminalTheme == nil`：保持 Ghostty 默认 dark 配色。

透明度与 blur 仍由现有字段控制：

- `terminalBackgroundOpacity`
- `terminalBackgroundBlur`

Twilight 只负责颜色，不改变 `background-opacity` 的生效规则。

## 设置 UI

`SettingsSheet.themeSettingsView` 从“只选择 Ghostty theme”扩展为 Twilight 主题控制：

- 主开关：`Use Twilight theme`。
- 预设 swatches：五个 seed。
- 自定义 seed hex 输入框，支持 `#RGB` 和 `#RRGGBB`。
- 预览卡展示当前 seed 生成的 terminal sample 和 16 色 palette。
- 关闭 Twilight 后，展示现有 Ghostty theme picker。

输入行为：

- 合法 seed 输入立即更新 `appSettings.twilightThemeSeedHex` 并应用到 active terminals。
- 非法 seed 不写入 settings，输入框显示校验错误并保留上一个有效 seed。
- 预设点击会同步 seed 输入框和预览。

本次不实现 HTML 规范中的“导出 Warp”按钮，因为 Argo 使用 Ghostty 作为内置 runtime；Warp 导出不是 Argo 主功能的一部分。Ghostty 同源输出已经覆盖 Argo 内部终端落地需求。

## 文件影响

预计创建：

- `Argo/Support/TwilightTheme.swift`：主题算法、HSL 工具、wallpaper 数据、Ghostty 色表。
- `Tests/TwilightThemeTests.swift`：算法和默认输出测试。

预计修改：

- `Argo/Support/ArgoTheme.swift`：新增 / 映射 Twilight token。
- `Argo/Support/ArgoChromeTint.swift`：从 Twilight slots 派生 chrome region fill。
- `Argo/Domain/AppSettings.swift`：新增 Twilight settings 字段和解码迁移。
- `Argo/App/WorkspaceStore.swift`：保留 settings 更新路径，暴露当前 Twilight theme。
- `Argo/Services/Terminal/Ghostty/ArgoGhosttyConfig.swift`：输出同源 Ghostty 颜色。
- `Argo/UI/MainWindowView.swift`：加入 wallpaper、顶栏 token、floating sidebar surface token。
- `Argo/UI/Components/GlobalModeRailView.swift`：rail 视觉映射。
- `Argo/UI/Sidebar/WorkspaceSidebarView.swift`：搜索 prompt、row hover / selected、footer、badge token。
- `Argo/UI/Workspace/WorkspaceDetailView.swift`：terminal scrim、horizon glow、surface token。
- `Argo/UI/Workspace/TerminalLocalChrome.swift`：`❯` category 和 Twilight pill 样式。
- `Argo/UI/Workspace/TerminalPaneView.swift`：pane search / status strip token。
- `Argo/UI/Sheets/SettingsSheet.swift`：Twilight 设置与预览。
- `Argo/Support/L10n.swift`：新增中英文设置文案。
- 相关现有测试：更新结构约束测试，使它们锁定 Twilight 分层而不是旧动态 tint 细节。

## 测试策略

### 算法测试

新增 `TwilightThemeTests`：

- `#ffb066` 生成的 Ghostty `accent/background/foreground/ANSI 16 色` 与 `twilight-terminal/warp-themes/twilight.yaml` 中对应值一致，格式转换到 Ghostty config 后仍同源。
- `#7af0c0`、`#5cc8ff`、`#ff9ec4`、`#ff7a59` 可生成非空主题，并满足 UI 亮度护栏。
- `#333`、`#ff0000`、非法字符串分别验证灰暗输入、极端红色和 fallback。
- ANSI red / green / blue 在任意 seed 下仍保持语义色相范围，验证“红是红、绿是绿”的底线。

### 设置与配置测试

更新或新增：

- `ArgoGhosttyConfigTests`：Twilight enabled 时输出 `background`、`foreground`、`palette = 0...15`，同时仍输出透明度和 blur。
- `QuickCommandSupportTests` / `WorkspaceTabsTests`：结构测试更新为检查 terminal surface 使用 scrim、horizon glow、单层 blur 约束。
- `WorkspaceStoreTests` 或 `QuickCommandSupportTests`：settings 更新后 seed 保留并触发 app settings change path。
- `LocalizationManagerTests`：新增文案中英文 key 覆盖。

### 验证命令

实现后至少运行：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/TwilightThemeTests \
  -only-testing:ArgoTests/ArgoGhosttyConfigTests \
  -only-testing:ArgoTests/QuickCommandSupportTests \
  -only-testing:ArgoTests/WorkspaceTabsTests \
  test
```

再运行 Debug build：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

如果设置迁移或 workspace settings 受影响，再补跑完整 `xcodebuild ... test`。

## 手动验收

- 首次启动 Argo 后，主 workspace 呈现 Twilight 暮光：右下暖色日落、冷色天空 / 水面、左侧终端正文区压暗。
- 顶栏、rail、sidebar、terminal chrome 使用同源 `amber/cyan/green/magenta` 语义色。
- 搜索框、workspace 副标题、terminal tab / category 前缀出现 `❯`。
- 设置里切换五个 seed，Argo chrome、wallpaper、terminal preview、Ghostty 终端颜色同步变化。
- 输入自定义合法 hex，界面实时生成协调主题。
- 输入非法 hex，不破坏当前主题，不写入非法 settings。
- `git diff` / `ls` 等终端语义色保持 red / green / blue 的含义。
- 终端透明度小于 `1` 时，terminal surface 能透出壁纸，但正文仍清晰。
- 关闭终端 blur 时，只有 blur 行为变化，Twilight 色彩仍生效。
- sidebar 搜索、选择、多选、右键菜单、拖拽、展开/折叠和 footer actions 正常。
- terminal tab、split right、split down、new tab、pane search、状态条、preview、file tree 行为不变。
- Canvas / Overview 可正常打开，不出现过度染色或文字不可读。

## 非目标

- 不新增 Warp YAML 导出功能到 Argo。
- 不改变 Ghostty runtime、surface controller 或 vendored `GhosttyKit.xcframework`。
- 不把 `WorkspaceSidebarView` 改成纯 SwiftUI list。
- 不改变 pane layout 数据模型、session restore、worktree switching 或 preview tab 行为。
- 不引入 Google Fonts；macOS 原生 UI 使用系统字体，终端和数据文本继续使用现有 monospaced 配置。`Space Grotesk` / `JetBrains Mono` 的视觉角色通过 SwiftUI font weight、monospaced text 和 Ghostty font setting 近似落地。
- 不把 HTML 预览器的 theme dock 直接搬到主窗口右下角；Argo 的主题控制放在 Settings，避免遮挡终端工作流。

## 风险与缓解

- 风险：一次性把静态 `ArgoTheme` 改成动态主题会影响大量 view。
  - 缓解：第一版保持静态默认 token，同时通过 store 向主 workspace 关键 surface 传入当前 theme。
- 风险：Ghostty 和 SwiftUI 预览色不一致。
  - 缓解：SwiftUI 主题和 Ghostty config 都从 `TwilightTheme.generate(seed:)` 获取颜色，不复制算法。
- 风险：透明层叠造成双重模糊或发灰。
  - 缓解：结构测试锁定窗口级 blur 禁用、terminal blur 只在 terminal surface、sidebar 内部不绘制完整二级面板。
- 风险：视觉改动破坏 sidebar / terminal 行为。
  - 缓解：不替换桥接层和 store action；测试覆盖现有结构；手动验收覆盖关键交互。

## 自查

- 本设计覆盖 `twilight-terminal/设计规范.md` 的核心要求：单色驱动、右下日落、`❯` prompt、透明分层、终端语义色不失真。
- 设计明确了与 Argo 现有 AppKit + SwiftUI + Ghostty 架构的映射。
- 范围聚焦在主题和视觉系统，不重写业务功能。
- Ghostty 颜色输出与 SwiftUI 视觉共用一个算法，避免双轨漂移。
- 预设、默认 seed、设置迁移、非法输入、测试和手动验收均有明确规则。
