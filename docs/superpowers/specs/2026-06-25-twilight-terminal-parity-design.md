# Twilight Terminal 1:1 对齐 Argo 设计

## 目标

把当前 `twilight-terminal/preview.html` 和 `twilight-terminal/设计规范.md` 中的 Twilight Terminal 视觉系统完整落到 Argo 主工作区，目标是可以通过截图对比接近 1:1 高保真还原。

本设计以当前 `twilight-terminal/设计规范.md` 为权威来源。旧的 `2026-06-24-twilight-terminal-argo-design.md` 描述的是上一版单色日落渐变方案，本次以新的“真实图片背景、透明炭黑面板、热门主题预设、无毛玻璃”方案为准。

## 已批准范围

用户已批准采用完整原生 SwiftUI 复刻方案。范围包含：

- `preview.html` 的 52px 顶栏、64px rail、280px sidebar、32px 状态栏和终端主体结构。
- 真实图片 wallpaper 系统：Desk、Mountain、Forest、Night 四个预设，本地图片上传，背景两层暗化渐变。
- 主题 seed 系统：Catppuccin Mocha、Tokyo Night、Dracula、Nord、Gruvbox、Rosé Pine 六个预设，默认 `#cba6f7`。
- 旧 seed 迁移：`#ffb066 -> #fabd2f`、`#7af0c0 -> #88c0d0`、`#5cc8ff -> #7aa2f7`、`#ff9ec4 -> #ebbcba`、`#ff7a59 -> #bd93f9`。
- 面板颜色拆分为 RGB 与 alpha，RGB 随 seed 轻微染色，alpha 完全由透明度百分比控制。
- 透明度语义：`0%` 完全透明，`100%` 达到 `OPACITY_TARGET_ALPHAS`，默认 `40%`。
- 主窗口右下角 `theme-dock` 作为真实可用原生控件：主题点、图片点、本地图片、透明度滑杆、hex 输入、导出 Warp。
- Twilight 模式不使用窗口级或终端级毛玻璃 blur。透明感来自真实图片背景、面板 alpha、scrim、text shadow、轻描边。
- Warp/Ghostty 终端颜色与 UI 主题同源，ANSI red/green/blue 继续保持语义可辨。

不在本次范围：

- 不替换 Ghostty runtime。
- 不重写 `WorkspaceSidebarView` 的 `NSOutlineView` 桥接。
- 不改变 worktree 切换、pane layout、terminal tab、preview、file tree、command palette 的业务行为。
- 不把 `preview.html` 作为 WebView 嵌入主窗口。

## 现有差距

当前 Argo 已有旧版 Twilight 对齐，但与新规范有这些差距：

- `TwilightTheme.defaultSeedHex` 仍是 `#ffb066`，预设仍是 Twilight/Aurora/Abyss/Sakura/Ember。
- `TwilightWallpaperView` 仍绘制 seed 生成的渐变壁纸，不是 `preview.html` 的真实图片背景。
- `AppSettings.defaultTerminalBackgroundOpacity` 仍是 `0.76`，且透明度被 clamp 到 `0.5...1`。
- `AppSettings.defaultTerminalBackgroundBlur` 为 `true`，终端 translucent 时仍可能创建 `TerminalBackgroundBlurView`。
- `ArgoTheme.glassSide`、`glassRail`、`glassCard` 等是旧静态色值，未按新规范做 surface RGB tint 与 alpha 分离。
- 主窗口没有右下角 `theme-dock`。
- 设置页的 Twilight 预设与新 HTML 不一致。

## 架构设计

### 1. 主题核心模型

修改 `Argo/Support/TwilightTheme.swift`，让它完整承载 `preview.html` 的主题算法。

保留现有类型：

- `TwilightTheme`
- `TwilightHSLColor`
- `TwilightGhosttyTheme`

调整内容：

- `defaultSeedHex = "#cba6f7"`。
- `presets` 改为六个热门主题：
  - `catppuccinMocha`, `#cba6f7`
  - `tokyoNight`, `#7aa2f7`
  - `dracula`, `#bd93f9`
  - `nord`, `#88c0d0`
  - `gruvbox`, `#fabd2f`
  - `rosePine`, `#ebbcba`
- 增加 `oldPresetMigration`，用于解码和输入时迁移旧 seed。
- `generate(seed:)` 保留当前 UI 强调色和 Ghostty ANSI 公式，因为它已经基本等价于 `preview.html`：
  - `amber = hsl(h, S, clamp(l,58,70))`
  - `amber2 = hsl(h, clamp(S-12,40,88), clamp(l+15,72,86))`
  - `cyan = hsl(h+168, clamp(S-6,46,82), 70)`
  - `green = hsl(h+96, clamp(S-12,40,76), 69)`
  - `magenta = hsl(h-46, clamp(S-4,46,82), 72)`
  - ANSI hue anchor 使用 `lerpHue(anchor, h, 0.12)`。
- `waterH` 调整到 `lerpHue(h, 214, 0.86)`，与 `preview.html` 一致。

新增模型：

```swift
struct TwilightRGBColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double
}

struct TwilightSurfacePalette: Equatable {
    var app: TwilightRGBColor
    var glassSide: TwilightRGBColor
    var glassRail: TwilightRGBColor
    var glassCard: TwilightRGBColor
    var glassCardH: TwilightRGBColor
    var topGlass: TwilightRGBColor
    var term: TwilightRGBColor
    var scrim: TwilightRGBColor
    var dock: TwilightRGBColor
    var toast: TwilightRGBColor
}

struct TwilightOpacityModel: Equatable {
    var percent: Int
    var appAlpha: Double
    var glassSideAlpha: Double
    var glassRailAlpha: Double
    var glassCardAlpha: Double
    var glassCardHAlpha: Double
    var topGlassAlpha: Double
    var termAlpha: Double
    var scrim1Alpha: Double
    var scrim2Alpha: Double
    var softFillAlpha: Double
    var dockAlpha: Double
    var toastAlpha: Double
}
```

`TwilightSurfacePalette` 使用 `preview.html` 的 `SURFACE_TINTS`：

```text
app          base 14,15,18 amount 0.06
glassSide    base 18,19,23 amount 0.10
glassRail    base 14,15,19 amount 0.08
glassCard    base 32,33,39 amount 0.11
glassCardH   base 42,43,51 amount 0.13
topGlass     base 18,19,23 amount 0.09
term         base 9,10,13  amount 0.05
scrim        base 7,8,11   amount 0.06
dock         base 18,19,23 amount 0.10
toast        base 20,21,25 amount 0.10
```

`TwilightOpacityModel` 使用 `preview.html` 的 `OPACITY_TARGET_ALPHAS`：

```text
app 0.35
glassSide 1.0
glassRail 1.0
glassCard 1.0
glassCardH 1.0
topGlass 1.0
term 0.65
scrim1 1.0
scrim2 0.45
softFill 0.45
dock 1.0
toast 1.0
```

公式：

```swift
alpha = percent == 0 ? 0 : min(max(target * Double(percent) / 100, 0), 1)
```

### 2. 背景图片模型

新增 `TwilightWallpaperPreset`，替代旧的 seed 渐变 wallpaper 作为默认背景来源。

```swift
enum TwilightWallpaperPreset: String, Codable, CaseIterable, Identifiable {
    case desk
    case mountain
    case forest
    case night
}
```

每个 preset 保存：

- id
- label
- remote URL
- thumbnail 使用同一 URL

默认 `desk`。远程图片加载失败时，`TwilightWallpaperView` 使用当前 `preview.html` 中 `:root --wallpaper` 的三层渐变兜底：

```text
radial-gradient(80% 70% at 78% 22%, rgba(93,111,138,.36), transparent 62%)
radial-gradient(64% 56% at 18% 76%, rgba(78,62,108,.30), transparent 66%)
linear-gradient(135deg,#263244 0%,#1c2432 42%,#111720 100%)
```

本地图片上传由 dock 触发，文件被拷贝到 Argo state 目录下的 `twilight-wallpapers/custom.<ext>`，`AppSettings` 保存文件 URL 或相对路径。这样重启后仍可恢复本地图片背景。

### 3. AppSettings

修改 `Argo/Domain/AppSettings.swift`：

```swift
var twilightThemeEnabled: Bool
var twilightThemeSeedHex: String
var twilightWallpaperPreset: TwilightWallpaperPreset?
var twilightCustomWallpaperPath: String?
var twilightOpacityPercent: Int
```

默认值：

```text
twilightThemeEnabled = true
twilightThemeSeedHex = "#cba6f7"
twilightWallpaperPreset = .desk
twilightCustomWallpaperPath = nil
twilightOpacityPercent = 40
terminalBackgroundOpacity = 0.40
terminalBackgroundBlur = false
```

兼容规则：

- 解码旧 seed 时先执行 `TwilightTheme.migratedSeedHex(_:)`。
- 旧配置如果没有 `twilightOpacityPercent`，从 `terminalBackgroundOpacity` 迁移：`Int(round(value * 100))`，再 clamp 到 `0...100`。如果是旧默认 `0.76` 或 `0.82`，迁移为新默认 `40`。
- `terminalBackgroundOpacity` 继续保留给 Ghostty runtime，但 Twilight 模式下由 `twilightOpacityPercent / 100` 同步生成。
- `terminalBackgroundBlur` 在 Twilight 模式默认关闭。用户关闭 Twilight 后仍可使用传统 blur 设置。

### 4. WorkspaceStore 派生状态

修改 `Argo/App/WorkspaceStore.swift`：

- `currentTwilightTheme` 使用迁移后的 seed 生成。
- 增加 `currentTwilightOpacity`。
- 增加 `currentTwilightSurfacePalette`。
- 增加更新方法：
  - `setTwilightSeedHex(_:)`
  - `setTwilightWallpaperPreset(_:)`
  - `setTwilightCustomWallpaper(url:)`
  - `setTwilightOpacityPercent(_:)`
  - `exportCurrentTwilightWarpTheme() throws -> URL`

这些方法负责更新 `appSettings`、调用 `updateAppSettings` 的现有持久化路径，并触发 Ghostty runtime 刷新。

### 5. ArgoTheme 与动态 token

保留 `ArgoTheme` 里的中性文字色：

```text
text       #f3f5fb
textDim    #c8cfdf
textFaint  #969db2
hairline   white 0.08
hairlineSoft white 0.05
```

新增 helper：

```swift
extension TwilightSurfacePalette {
    func color(_ key: KeyPath<TwilightSurfacePalette, TwilightRGBColor>, alpha: Double) -> Color
}
```

大面积动态背景不再使用静态 `ArgoTheme.glassSide`、`glassRail`、`glassCard`，而由当前 theme 和 opacity 传入：

- `GlobalModeRailView`
- `MainWindowView` sidebar shell
- `TopChromeSurfaceBackground`
- `TerminalWorkspaceSurface`
- `TerminalLocalChrome`
- `TwilightThemeDockView`
- `TwilightStatusBar`

为了减少一次性风险，旧 `ArgoTheme.glass*` 保留给非 Twilight 或尚未迁移的小组件使用。

## UI 设计

### 1. 主窗口结构

`Argo/UI/MainWindowView.swift` 继续使用现有布局：

```text
ZStack
  TwilightWallpaperView
  VStack
    topGlassChrome 52
    HStack
      GlobalModeRailView 64
      WorkspaceSidebarView 280
      WorkspaceDetailView 1fr
    TwilightStatusBar 32
  TwilightThemeDockView fixed bottom trailing
  Toast
```

Workspace 模式下 `windowContentBackground = .clear`。非 workspace 模式可以保留现有背景，避免 overview/canvas 被强行透明化。

`TwilightWallpaperView` 改为真实图片背景：

- 最底层加载当前 preset 或 custom 图片，`scaledToFill`，center crop。
- 图片上叠加两层暗化：
  - 斜向 `linear-gradient(115deg, rgba(9,13,22,.24), rgba(9,13,22,.48))`
  - 垂直 `linear-gradient(180deg, rgba(9,13,22,.18), rgba(9,13,22,.46))`
- 再叠加 `body::before` 的光线和暗角：
  - `linear-gradient(115deg, transparent 0%, rgba(255,255,255,.04) 46%, transparent 62%)`
  - `radial-gradient(120% 92% at 50% 50%, transparent 52%, rgba(0,0,0,.32) 100%)`

### 2. 顶栏

`topGlassChrome` 保持现有功能按钮，但视觉对齐 `.titlebar`：

- 高 `52`。
- 横向 padding `16`，gap `16`。
- 背景 `topGlass`，alpha 来自 `TwilightOpacityModel.topGlassAlpha`。
- 下边框 `hairlineSoft`。
- 左侧 traffic lights 保留 `TrafficLightAnchor()`。
- Terminal pill 高 `34`，圆角 `9`，背景 `glassCard`。
- 命令面板入口高 `34`，min `340`，max `430`，圆角 `9`，背景为 seed 12% 混合透明，hover 18%。
- 右侧四个 top action button 保持 `32 x 32`，hover 使用 `softFillAlpha * 0.5`。
- Profile pill 高 `34`，背景 `glassCard`，在线点 green。

### 3. Rail

`GlobalModeRailView` 对齐 `.rail`：

- 宽 `64 * uiScale`。
- 背景 `glassRail`。
- padding vertical `14 * uiScale`。
- gap `6 * uiScale`。
- active 图标颜色为 theme amber。
- active 左侧竖条 `3 x 20`，offset `-14`，glow radius `10`。
- hover 背景 `white 0.05`。

### 4. Sidebar

`WorkspaceSidebarView` 维持数据和 `NSOutlineView` 行为，对齐 `.sidebar`：

- 外层宽 `280`，可保留现有 resize clamp `210...340`。
- 背景 `glassSide`。
- 搜索框高 `38`，padding `0 12`，gap `9`，前缀 `❯`。
- section title 使用 `11`、semibold、uppercase、letter spacing `0.09em`。
- row padding `9 x 11`，gap `11`，row height 与当前 `52` 保持一致。
- hover 背景改为 `white * softFillAlpha * 0.08`，极轻。
- active 背景改为左到右 amber 5% 轻渐变，不能整块卡片化。
- active 左线宽 `2`，上下留 `10`，glow radius `6`。
- 图标盒 `34 x 34`，圆角 `9`。

### 5. Terminal surface

`TerminalWorkspaceSurface` 对齐 `.term`：

- 背景 `term` RGB + `termAlpha`。
- 不再创建 `TerminalBackgroundBlurView`。
- scrim 使用当前 surface `scrim` RGB：
  - location `0`, alpha `scrim1Alpha`
  - location `0.14`, alpha `scrim1Alpha`
  - location `0.46`, alpha `scrim2Alpha`
  - location `0.74`, alpha `scrim2Alpha * 0.2`
  - location `1`, clear
- 底部 horizon glow 高 `2`，amber 50% at 55%，amber2 65% at 75%。
- Terminal chrome 高保持当前 `36`，内部 tab pill 高 `30`，圆角 `8`。
- `TerminalPaneView` 的 pane fill 在 Twilight 模式保持 clear，让 terminal surface 统一控底。

Ghostty 的 `background-opacity` 与 Twilight opacity 同步，但不低于 Ghostty 可接受的安全值时需要测试确认。如果 Ghostty 不接受 `0.00`，终端 host 自身透明由 SwiftUI surface 接管，Ghostty config 最低写入其可接受下限，并由 host view 清背景补齐视觉。

### 6. Status bar

`TwilightStatusBar` 对齐 `.statusbar`：

- 高 `32`。
- padding horizontal `16`。
- gap `18`。
- 背景 `topGlass`。
- 上边框 `hairlineSoft`。
- 字体 monospaced `11.5`。

### 7. Theme dock

新增 `Argo/UI/Components/TwilightThemeDockView.swift`。

位置：

- `ZStack` overlay alignment bottomTrailing。
- trailing `26`，bottom `26`。
- padding `9 x 13`。
- gap `10`。
- background `dock` RGB + `dockAlpha`。
- border `hairline`。
- corner radius `40`。
- shadow `0 16 40 -12 black 0.5` 的 SwiftUI 近似：`shadow(color: .black.opacity(0.50), radius: 20, y: 12)`。

控件顺序与 HTML 一致：

1. `预设` 标签，mono `11`。
2. 6 个 `24 x 24` 主题 swatch。
3. 分隔线。
4. `图片` 标签，mono `11`。
5. 4 个 `34 x 24` wallpaper swatch。
6. 本地图片按钮 `26 x 26`。
7. 分隔线。
8. 透明度控制，高 `28`，slider 宽 `92`，output 宽 `34`。
9. 分隔线。
10. Color picker 圆形 `26 x 26`。
11. Hex 输入框宽 `72`。
12. 导出 Warp 按钮，高 `30`，圆角 `18`。

macOS 原生实现：

- 主题 swatch 使用 `Circle` + `LinearGradient`。
- Wallpaper swatch 使用 `AsyncImage` 或 `NSImageView` wrapper，失败时显示渐变 fallback。
- 本地图片按钮使用 `NSOpenPanel`，限制 image 类型。
- Color picker 使用 `ColorPicker`，外层用圆形彩虹背景模拟 HTML。
- Hex 输入使用 `TextField`，合法 hex 即应用，不合法时显示当前值和轻微错误描边。
- 导出按钮调用 `WorkspaceStore.exportCurrentTwilightWarpTheme()`，成功后显示 toast。

### 8. Toast

新增 `TwilightToastView` 或复用现有 status banner，但视觉对齐 HTML toast：

- 位置 bottom center，bottom `84`。
- background `toast` RGB + `toastAlpha`。
- border `hairline`。
- corner radius `10`。
- padding `11 x 16`。
- max width `380`。
- 显示 4.2 秒。
- 文案包含导出文件名和移动命令：
  - `mv ~/Downloads/<file> ~/.warp/themes/`

## Ghostty 和 Warp 导出

`Argo/Services/Terminal/Ghostty/ArgoGhosttyConfig.swift`：

- Twilight 开启时继续内联 `background`、`foreground`、`palette = 0...15`。
- 默认 Twilight seed 变为 `#cba6f7`。
- Twilight 模式下不写 `background-blur = true`。
- `background-opacity` 根据 `twilightOpacityPercent / 100` 写入。若 Ghostty 对低值有限制，运行验证后在实现计划里锁定下限，并通过 SwiftUI host clear background 补足视觉透明度。

Warp 导出：

- 新增 `TwilightWarpExporter`，与 `TwilightTheme.ghostty` 同源。
- 文件名规则：
  - preset 使用主题名第一个词小写，如 `catppuccin.yaml`、`tokyo.yaml`。
  - custom 使用 `custom-<hex>.yaml`。
- YAML 不包含透明度和 wallpaper，只包含颜色。
- 导出目录默认使用用户 Downloads。

## 测试策略

按 TDD 执行，先写 failing tests。

单元测试：

- `Tests/TwilightThemeTests.swift`
  - 默认 seed 是 `#cba6f7`。
  - 六个 preset 顺序和 seed 与 HTML 一致。
  - 旧 seed 迁移正确。
  - `surfacePalette(seed:)` 对 Catppuccin/Tokyo/Gruvbox 输出可预测 RGB。
  - `opacityModel(percent:)` 在 `0`、`40`、`100` 输出 HTML 目标 alpha。
  - Warp/Ghostty palette 对默认 seed 与 `preview.html` 公式一致。
- `Tests/WorkspaceStoreTests.swift`
  - 默认 AppSettings 使用 Twilight、desk wallpaper、40 opacity、blur false。
  - 旧配置的 `0.76` 和 `0.82` 迁移为 40。
  - 非法 seed 回退并迁移旧 seed。
- `Tests/ArgoGhosttyConfigTests.swift`
  - 默认 Twilight config 使用 Catppuccin seed 输出。
  - Twilight config 不写 `background-blur = true`。
  - opacity 写入与 `twilightOpacityPercent` 同步。
- 源码结构测试：
  - `MainWindowView` 包含 `TwilightThemeDockView`。
  - `TerminalWorkspaceSurface` 不再包含 `TerminalBackgroundBlurView()`。
  - `TwilightWallpaperView` 支持 image wallpaper 而不是只含 RadialGradient/LinearGradient 旧日落。

手动和视觉验证：

- 用 Playwright 重新截 `twilight-terminal/preview.html`，保存到 `output/playwright/twilight-reference.png`。
- 构建并运行 Argo，截同尺寸主窗口图，保存到 `output/playwright/argo-twilight.png` 或同级 artifact。
- 对照检查：
  - 背景图、暗化层、顶栏、rail、sidebar、terminal scrim、statusbar、dock 位置和尺寸。
  - 默认 seed、默认 opacity、无 blur。
  - 切换 6 个 seed 时 UI 色和 Ghostty 色联动。
  - 切换 4 个 wallpaper 时背景变化。
  - `0%` 时核心面板 alpha 归零。
  - `100%` 时侧栏、rail、card、top、dock、toast 达到目标 alpha。

## 验收标准

完成时必须满足：

- Argo 默认 workspace 截图与 `twilight-terminal/preview.html` 默认状态在布局、背景、颜色、透明度和 dock 结构上高保真一致。
- 主窗口 Twilight 模式无毛玻璃 blur。
- 默认 seed 是 `#cba6f7`，默认 wallpaper 是 `desk`，默认 opacity 是 `40%`。
- 透明度范围是 `0...100`，`0%` 核心面板 alpha 为 0。
- 六个热门主题和四个 wallpaper preset 均可用。
- 本地图片可以替换 wallpaper，并能重启后恢复。
- Warp 导出与 Ghostty palette 同源。
- 现有 workspace、sidebar、terminal pane、tab、preview、file tree 功能保持可用。
- Focused tests 通过，至少一次 `xcodebuild -project Argo.xcodeproj -scheme Argo -configuration Debug -destination 'platform=macOS,arch=arm64' build` 通过。

## 风险与处理

- Ghostty 可能不接受极低 `background-opacity`。实现时先用测试和运行验证确认，必要时把 Ghostty config opacity 与 SwiftUI surface alpha 分层处理，视觉仍保持 HTML 的 `0...100` 语义。
- 远程 wallpaper 图片依赖网络。需要本地 fallback 渐变，且 UI 不因加载失败空白。
- `WorkspaceSidebarView.swift` 文件较大。实现时只做必要局部改动，不重写 outline bridge。
- Dock 会占用右下角空间。它应作为 overlay，不改变 workspace layout；在窄窗口下允许横向压缩或滚动，避免遮挡主流程。
- 旧设置迁移要小心，不能让用户已有非 Twilight 主题配置丢失。
