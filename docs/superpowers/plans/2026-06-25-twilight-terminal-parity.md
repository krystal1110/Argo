# Twilight Terminal Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Argo 主工作区原生 SwiftUI 视觉、设置、Ghostty 配置和 Warp 导出对齐 `twilight-terminal/preview.html` 与 `twilight-terminal/设计规范.md`。

**Architecture:** 先把 Twilight 主题算法、surface tint、opacity model、wallpaper preset 做成纯模型并用单元测试锁定，再让 `AppSettings` 和 `WorkspaceStore` 产生统一派生状态。UI 层只消费 `TwilightTheme`、`TwilightSurfacePalette`、`TwilightOpacityModel` 和 wallpaper selection，避免把 HTML 算法散落到视图里。

**Tech Stack:** Swift 5、SwiftUI、AppKit、XCTest、GhosttyKit、Xcode project `Argo.xcodeproj`。

## Global Constraints

- 面向用户的沟通、计划、评审和总结必须使用简体中文。
- 默认 seed 必须是 `#cba6f7`。
- 六个主题预设必须按顺序为 Catppuccin Mocha `#cba6f7`、Tokyo Night `#7aa2f7`、Dracula `#bd93f9`、Nord `#88c0d0`、Gruvbox `#fabd2f`、Rosé Pine `#ebbcba`。
- 旧 seed 迁移必须为 `#ffb066 -> #fabd2f`、`#7af0c0 -> #88c0d0`、`#5cc8ff -> #7aa2f7`、`#ff9ec4 -> #ebbcba`、`#ff7a59 -> #bd93f9`。
- 透明度语义必须是 `0...100`，默认 `40`，`0%` 核心面板 alpha 为 `0`，`100%` 达到 `OPACITY_TARGET_ALPHAS`。
- Twilight 模式不得启用窗口级或终端级 blur，不写 `background-blur = true`。
- 背景必须是真实图片 wallpaper 或本地上传图片；远程加载失败时使用规范中的三层渐变兜底。
- 不替换 Ghostty runtime，不重写 `WorkspaceSidebarView` 的 `NSOutlineView` 桥接，不把 `preview.html` 嵌入 WebView。
- 完成前至少运行一次 `xcodebuild -project Argo.xcodeproj -scheme Argo -configuration Debug -destination 'platform=macOS,arch=arm64' build`。
- 每个提交信息遵守 `team-commit-convention`：只用 `feat(scope): subject` 或 `fix(scope): subject`，英文 subject 不超过 20 个字符。

---

## File Structure

- Modify `Argo/Support/TwilightTheme.swift`: 主题 seed 规范化/迁移、六个 preset、surface tint、opacity model、wallpaper preset metadata、Ghostty palette。
- Modify `Argo/Domain/AppSettings.swift`: 新增 Twilight wallpaper/opacity/custom path 设置，迁移旧 terminal opacity/blur/seed，解码/初始化统一 clamp。
- Modify `Argo/App/WorkspaceStore.swift`: 暴露当前 Twilight 派生状态，提供 seed/wallpaper/custom image/opacity/export 更新方法，并复用 `updateAppSettings` 持久化。
- Create `Argo/Services/Terminal/TwilightWarpExporter.swift`: 从 `TwilightTheme.ghostty` 生成 Warp YAML 并写入 Downloads。
- Modify `Argo/Services/Terminal/Ghostty/ArgoGhosttyConfig.swift`: Twilight 配置使用新默认 seed，按 `twilightOpacityPercent` 写 opacity，不写 blur。
- Modify `Argo/UI/Components/TwilightWallpaperView.swift`: 使用 wallpaper preset/custom image + 暗化层 + 光线/暗角，不再绘制旧日落渐变。
- Create `Argo/UI/Components/TwilightThemeDockView.swift`: 主窗口右下主题 dock、wallpaper swatch、图片上传、opacity slider、hex 输入、导出按钮、toast。
- Modify `Argo/UI/MainWindowView.swift`: 注入 wallpaper/dock/toast，动态 top/sidebar/status surfaces。
- Modify `Argo/UI/Workspace/WorkspaceDetailView.swift`: 动态 terminal surface，移除 `TerminalBackgroundBlurView()`。
- Modify `Argo/UI/Workspace/TerminalPaneView.swift` and `Argo/UI/Workspace/TerminalLocalChrome.swift`: Twilight 模式下 pane fill 和 local chrome 消费动态 surfaces。
- Modify `Argo/UI/Sheets/SettingsSheet.swift`: 设置页展示新主题 preset、wallpaper、opacity `0...100`，禁用 Twilight blur。
- Modify `Argo/Support/L10n.swift`: 新增 preset、wallpaper、dock、toast、settings 文案的中英文键。
- Modify tests: `Tests/TwilightThemeTests.swift`、`Tests/WorkspaceStoreTests.swift`、`Tests/ArgoGhosttyConfigTests.swift`、`Tests/LocalizationManagerTests.swift`。
- Create tests: `Tests/TwilightWarpExporterTests.swift`、`Tests/TwilightUISourceTests.swift`。

---

### Task 1: Twilight Core Model

**Files:**
- Modify: `Argo/Support/TwilightTheme.swift`
- Modify: `Tests/TwilightThemeTests.swift`

**Interfaces:**
- Consumes: existing `TwilightTheme.generate(seed:)`, `TwilightHSLColor`, `TwilightGhosttyTheme`
- Produces:
  - `TwilightTheme.defaultSeedHex: String`
  - `TwilightTheme.presets: [TwilightTheme.Preset]`
  - `TwilightTheme.migratedSeedHex(_ seed: String?) -> String`
  - `TwilightTheme.surfacePalette(seed: String) -> TwilightSurfacePalette`
  - `TwilightTheme.opacityModel(percent: Int) -> TwilightOpacityModel`
  - `TwilightRGBColor(red:green:blue:)`
  - `TwilightSurfacePalette.color(_:alpha:) -> Color`
  - `TwilightWallpaperPreset: String, Codable, CaseIterable, Identifiable`

- [ ] **Step 1: Write failing Twilight model tests**

Replace the old seed/preset expectations in `Tests/TwilightThemeTests.swift` with these tests:

```swift
func testDefaultSeedMatchesCurrentPreview() {
    XCTAssertEqual(TwilightTheme.defaultSeedHex, "#cba6f7")

    let theme = TwilightTheme.default

    XCTAssertEqual(theme.seedHex, "#cba6f7")
    XCTAssertEqual(theme.ghostty.accent, "#cba6f7")
    XCTAssertEqual(theme.ghostty.background, "#101220")
    XCTAssertEqual(theme.ghostty.foreground, "#f0eff2")
    XCTAssertEqual(theme.ghostty.palette[0], "#202238")
    XCTAssertEqual(theme.ghostty.palette[1], "#eb5c64")
    XCTAssertEqual(theme.ghostty.palette[2], "#3fe670")
    XCTAssertEqual(theme.ghostty.palette[3], "#cba6f7")
    XCTAssertEqual(theme.ghostty.palette[4], "#5c68eb")
    XCTAssertEqual(theme.ghostty.palette[5], "#c86eeb")
    XCTAssertEqual(theme.ghostty.palette[6], "#54e4ea")
    XCTAssertEqual(theme.ghostty.palette[7], "#d3d1d6")
    XCTAssertEqual(theme.ghostty.palette[15], "#f5f4f6")
}

func testPresetsMatchPreviewOrderAndSeeds() {
    XCTAssertEqual(TwilightTheme.presets.map(\.id), [
        "catppuccinMocha",
        "tokyoNight",
        "dracula",
        "nord",
        "gruvbox",
        "rosePine",
    ])
    XCTAssertEqual(TwilightTheme.presets.map(\.seedHex), [
        "#cba6f7",
        "#7aa2f7",
        "#bd93f9",
        "#88c0d0",
        "#fabd2f",
        "#ebbcba",
    ])
}

func testOldPresetSeedsMigrateToCurrentPreviewSeeds() {
    XCTAssertEqual(TwilightTheme.migratedSeedHex("#ffb066"), "#fabd2f")
    XCTAssertEqual(TwilightTheme.migratedSeedHex("#7af0c0"), "#88c0d0")
    XCTAssertEqual(TwilightTheme.migratedSeedHex("#5cc8ff"), "#7aa2f7")
    XCTAssertEqual(TwilightTheme.migratedSeedHex("#ff9ec4"), "#ebbcba")
    XCTAssertEqual(TwilightTheme.migratedSeedHex("#ff7a59"), "#bd93f9")
    XCTAssertEqual(TwilightTheme.migratedSeedHex("abc"), "#aabbcc")
    XCTAssertEqual(TwilightTheme.migratedSeedHex("not-a-color"), "#cba6f7")
}

func testSurfacePaletteMatchesPreviewTintFormula() {
    let catppuccin = TwilightTheme.surfacePalette(seed: "#cba6f7")

    XCTAssertEqual(catppuccin.app.rounded255, [18, 17, 22])
    XCTAssertEqual(catppuccin.glassSide.rounded255, [24, 22, 30])
    XCTAssertEqual(catppuccin.glassRail.rounded255, [19, 17, 25])
    XCTAssertEqual(catppuccin.glassCard.rounded255, [37, 35, 45])
    XCTAssertEqual(catppuccin.glassCardH.rounded255, [48, 45, 58])
    XCTAssertEqual(catppuccin.topGlass.rounded255, [23, 22, 29])
    XCTAssertEqual(catppuccin.term.rounded255, [12, 11, 17])
    XCTAssertEqual(catppuccin.scrim.rounded255, [11, 10, 15])
    XCTAssertEqual(catppuccin.dock.rounded255, [24, 22, 30])
    XCTAssertEqual(catppuccin.toast.rounded255, [26, 24, 32])

    XCTAssertEqual(TwilightTheme.surfacePalette(seed: "#7aa2f7").app.rounded255, [17, 18, 22])
    XCTAssertEqual(TwilightTheme.surfacePalette(seed: "#fabd2f").app.rounded255, [18, 17, 16])
}

func testOpacityModelMatchesPreviewTargets() {
    let transparent = TwilightTheme.opacityModel(percent: 0)
    XCTAssertEqual(transparent.appAlpha, 0)
    XCTAssertEqual(transparent.glassSideAlpha, 0)
    XCTAssertEqual(transparent.termAlpha, 0)
    XCTAssertEqual(transparent.scrim2Alpha, 0)

    let defaults = TwilightTheme.opacityModel(percent: 40)
    XCTAssertEqual(defaults.percent, 40)
    XCTAssertEqual(defaults.appAlpha, 0.14, accuracy: 0.0001)
    XCTAssertEqual(defaults.glassSideAlpha, 0.40, accuracy: 0.0001)
    XCTAssertEqual(defaults.termAlpha, 0.26, accuracy: 0.0001)
    XCTAssertEqual(defaults.scrim2Alpha, 0.18, accuracy: 0.0001)
    XCTAssertEqual(defaults.softFillAlpha, 0.18, accuracy: 0.0001)

    let opaque = TwilightTheme.opacityModel(percent: 100)
    XCTAssertEqual(opaque.appAlpha, 0.35, accuracy: 0.0001)
    XCTAssertEqual(opaque.glassRailAlpha, 1, accuracy: 0.0001)
    XCTAssertEqual(opaque.termAlpha, 0.65, accuracy: 0.0001)
    XCTAssertEqual(opaque.toastAlpha, 1, accuracy: 0.0001)
}

func testWallpaperPresetsMatchPreview() {
    XCTAssertEqual(TwilightWallpaperPreset.allCases.map(\.rawValue), ["desk", "mountain", "forest", "night"])
    XCTAssertEqual(TwilightWallpaperPreset.desk.label, "Desk")
    XCTAssertEqual(TwilightWallpaperPreset.desk.remoteURL.absoluteString, "https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=2400&q=82")
    XCTAssertEqual(TwilightWallpaperPreset.mountain.remoteURL.absoluteString, "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=2400&q=82")
    XCTAssertEqual(TwilightWallpaperPreset.forest.remoteURL.absoluteString, "https://images.unsplash.com/photo-1493246507139-91e8fad9978e?auto=format&fit=crop&w=2400&q=82")
    XCTAssertEqual(TwilightWallpaperPreset.night.remoteURL.absoluteString, "https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=2400&q=82")
}
```

Add this helper in the same test file:

```swift
private extension TwilightRGBColor {
    var rounded255: [Int] {
        [
            Int(red.rounded()),
            Int(green.rounded()),
            Int(blue.rounded()),
        ]
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/TwilightThemeTests test
```

Expected: FAIL with errors for missing `TwilightRGBColor`, `TwilightSurfacePalette`, `TwilightOpacityModel`, `TwilightWallpaperPreset`, `migratedSeedHex`, `surfacePalette`, and old default seed expectations.

- [ ] **Step 3: Implement Twilight model changes**

In `Argo/Support/TwilightTheme.swift`, update preset/default definitions:

```swift
static let defaultSeedHex = "#cba6f7"

static let presets: [Preset] = [
    Preset(id: "catppuccinMocha", nameKey: "settings.twilight.preset.catppuccinMocha", seedHex: "#cba6f7"),
    Preset(id: "tokyoNight", nameKey: "settings.twilight.preset.tokyoNight", seedHex: "#7aa2f7"),
    Preset(id: "dracula", nameKey: "settings.twilight.preset.dracula", seedHex: "#bd93f9"),
    Preset(id: "nord", nameKey: "settings.twilight.preset.nord", seedHex: "#88c0d0"),
    Preset(id: "gruvbox", nameKey: "settings.twilight.preset.gruvbox", seedHex: "#fabd2f"),
    Preset(id: "rosePine", nameKey: "settings.twilight.preset.rosePine", seedHex: "#ebbcba"),
]

private static let oldPresetMigration: [String: String] = [
    "#ffb066": "#fabd2f",
    "#7af0c0": "#88c0d0",
    "#5cc8ff": "#7aa2f7",
    "#ff9ec4": "#ebbcba",
    "#ff7a59": "#bd93f9",
]
```

Change seed normalization and generation to migrate first:

```swift
static func generate(seed: String) -> TwilightTheme {
    let normalizedSeed = migratedSeedHex(seed)
    let source = TwilightHSLColor.hexToHSL(normalizedSeed)
    // keep the rest of the existing generation body
}

static func normalizedSeedHex(_ seed: String?) -> String {
    validSeedHex(seed) ?? defaultSeedHex
}

static func migratedSeedHex(_ seed: String?) -> String {
    let normalized = normalizedSeedHex(seed)
    return oldPresetMigration[normalized] ?? normalized
}
```

Change `waterH`:

```swift
let waterH = lerpHue(h, 214, 0.86)
```

Append new structs and helpers after `TwilightGhosttyTheme`:

```swift
struct TwilightRGBColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double

    var color: Color {
        Color(nsColor: nsColor(alpha: 1))
    }

    func color(alpha: Double) -> Color {
        Color(nsColor: nsColor(alpha: alpha))
    }

    func nsColor(alpha: Double) -> NSColor {
        NSColor(
            calibratedRed: TwilightTheme.clamp(red, 0, 255) / 255,
            green: TwilightTheme.clamp(green, 0, 255) / 255,
            blue: TwilightTheme.clamp(blue, 0, 255) / 255,
            alpha: TwilightTheme.clamp(alpha, 0, 1)
        )
    }
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

    func color(_ keyPath: KeyPath<TwilightSurfacePalette, TwilightRGBColor>, alpha: Double) -> Color {
        self[keyPath: keyPath].color(alpha: alpha)
    }
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

enum TwilightWallpaperPreset: String, Codable, CaseIterable, Identifiable {
    case desk
    case mountain
    case forest
    case night

    var id: String { rawValue }

    var label: String {
        switch self {
        case .desk: return "Desk"
        case .mountain: return "Mountain"
        case .forest: return "Forest"
        case .night: return "Night"
        }
    }

    var remoteURL: URL {
        switch self {
        case .desk:
            return URL(string: "https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=2400&q=82")!
        case .mountain:
            return URL(string: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=2400&q=82")!
        case .forest:
            return URL(string: "https://images.unsplash.com/photo-1493246507139-91e8fad9978e?auto=format&fit=crop&w=2400&q=82")!
        case .night:
            return URL(string: "https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=2400&q=82")!
        }
    }
}
```

Add static helpers inside `TwilightTheme`:

```swift
static func surfacePalette(seed: String) -> TwilightSurfacePalette {
    let normalizedSeed = migratedSeedHex(seed)
    let source = TwilightHSLColor.hexToHSL(normalizedSeed)
    let tintHex = TwilightHSLColor.hslToHex(
        hue: source.hue,
        saturation: clamp(clamp(source.saturation, 42, 96) * 0.55, 26, 62),
        lightness: 34
    )
    let tint = rgb255(from: tintHex)

    func mixed(_ base: (Double, Double, Double), _ amount: Double) -> TwilightRGBColor {
        TwilightRGBColor(
            red: base.0 + (tint.red - base.0) * amount,
            green: base.1 + (tint.green - base.1) * amount,
            blue: base.2 + (tint.blue - base.2) * amount
        )
    }

    return TwilightSurfacePalette(
        app: mixed((14, 15, 18), 0.06),
        glassSide: mixed((18, 19, 23), 0.10),
        glassRail: mixed((14, 15, 19), 0.08),
        glassCard: mixed((32, 33, 39), 0.11),
        glassCardH: mixed((42, 43, 51), 0.13),
        topGlass: mixed((18, 19, 23), 0.09),
        term: mixed((9, 10, 13), 0.05),
        scrim: mixed((7, 8, 11), 0.06),
        dock: mixed((18, 19, 23), 0.10),
        toast: mixed((20, 21, 25), 0.10)
    )
}

static func opacityModel(percent: Int) -> TwilightOpacityModel {
    let normalized = min(max(percent, 0), 100)
    func alpha(_ target: Double) -> Double {
        normalized == 0 ? 0 : clamp(target * Double(normalized) / 100, 0, 1)
    }
    return TwilightOpacityModel(
        percent: normalized,
        appAlpha: alpha(0.35),
        glassSideAlpha: alpha(1),
        glassRailAlpha: alpha(1),
        glassCardAlpha: alpha(1),
        glassCardHAlpha: alpha(1),
        topGlassAlpha: alpha(1),
        termAlpha: alpha(0.65),
        scrim1Alpha: alpha(1),
        scrim2Alpha: alpha(0.45),
        softFillAlpha: alpha(0.45),
        dockAlpha: alpha(1),
        toastAlpha: alpha(1)
    )
}

private static func rgb255(from hex: String) -> TwilightRGBColor {
    let normalized = normalizedSeedHex(hex).dropFirst()
    let value = UInt64(normalized, radix: 16)!
    return TwilightRGBColor(
        red: Double((value >> 16) & 0xff),
        green: Double((value >> 8) & 0xff),
        blue: Double(value & 0xff)
    )
}
```

- [ ] **Step 4: Run Twilight model tests**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/TwilightThemeTests test
```

Expected: PASS for `TwilightThemeTests`.

- [ ] **Step 5: Commit**

```bash
git add Argo/Support/TwilightTheme.swift Tests/TwilightThemeTests.swift
git commit -m "feat(theme): twilight model"
```

---

### Task 2: AppSettings Persistence And Migration

**Files:**
- Modify: `Argo/Domain/AppSettings.swift`
- Modify: `Argo/App/WorkspaceStore.swift`
- Modify: `Tests/WorkspaceStoreTests.swift`

**Interfaces:**
- Consumes: `TwilightTheme.migratedSeedHex(_:)`, `TwilightTheme.opacityModel(percent:)`, `TwilightWallpaperPreset`
- Produces:
  - `AppSettings.twilightWallpaperPreset: TwilightWallpaperPreset?`
  - `AppSettings.twilightCustomWallpaperPath: String?`
  - `AppSettings.twilightOpacityPercent: Int`
  - `WorkspaceStore.currentTwilightOpacity: TwilightOpacityModel`
  - `WorkspaceStore.currentTwilightSurfacePalette: TwilightSurfacePalette`
  - `WorkspaceStore.setTwilightSeedHex(_:)`
  - `WorkspaceStore.setTwilightWallpaperPreset(_:)`
  - `WorkspaceStore.setTwilightCustomWallpaper(url:) throws`
  - `WorkspaceStore.setTwilightOpacityPercent(_:)`

- [ ] **Step 1: Write failing settings migration tests**

Add to `Tests/WorkspaceStoreTests.swift`:

```swift
func testDefaultAppSettingsUseCurrentTwilightDefaults() {
    let settings = AppSettings()

    XCTAssertTrue(settings.twilightThemeEnabled)
    XCTAssertEqual(settings.twilightThemeSeedHex, "#cba6f7")
    XCTAssertEqual(settings.twilightWallpaperPreset, .desk)
    XCTAssertNil(settings.twilightCustomWallpaperPath)
    XCTAssertEqual(settings.twilightOpacityPercent, 40)
    XCTAssertEqual(settings.terminalBackgroundOpacity, 0.40, accuracy: 0.0001)
    XCTAssertFalse(settings.terminalBackgroundBlur)
}

func testAppSettingsMigrateOldTwilightSeedAndOpacityDefaults() throws {
    let json = """
    {
      "twilightThemeEnabled": true,
      "twilightThemeSeedHex": "#ffb066",
      "terminalBackgroundOpacity": 0.76,
      "terminalBackgroundBlur": true,
      "terminalBackgroundAppearanceVersion": 2
    }
    """.data(using: .utf8)!

    let settings = try JSONDecoder().decode(AppSettings.self, from: json)

    XCTAssertEqual(settings.twilightThemeSeedHex, "#fabd2f")
    XCTAssertEqual(settings.twilightOpacityPercent, 40)
    XCTAssertEqual(settings.terminalBackgroundOpacity, 0.40, accuracy: 0.0001)
    XCTAssertFalse(settings.terminalBackgroundBlur)
}

func testAppSettingsMigrateLegacyOpacityDefaultToFortyPercent() throws {
    let json = """
    {
      "terminalBackgroundOpacity": 0.82,
      "terminalBackgroundBlur": true,
      "terminalBackgroundAppearanceVersion": 1
    }
    """.data(using: .utf8)!

    let settings = try JSONDecoder().decode(AppSettings.self, from: json)

    XCTAssertEqual(settings.twilightOpacityPercent, 40)
    XCTAssertEqual(settings.terminalBackgroundOpacity, 0.40, accuracy: 0.0001)
    XCTAssertFalse(settings.terminalBackgroundBlur)
}

func testAppSettingsMigrateCustomOpacityIntoPercent() throws {
    let json = """
    {
      "terminalBackgroundOpacity": 0.65,
      "terminalBackgroundBlur": false,
      "terminalBackgroundAppearanceVersion": 2
    }
    """.data(using: .utf8)!

    let settings = try JSONDecoder().decode(AppSettings.self, from: json)

    XCTAssertEqual(settings.twilightOpacityPercent, 65)
    XCTAssertEqual(settings.terminalBackgroundOpacity, 0.65, accuracy: 0.0001)
    XCTAssertFalse(settings.terminalBackgroundBlur)
}

func testUpdateAppSettingsPreservesTwilightWallpaperAndOpacity() {
    let store = WorkspaceStore(initialAppSettings: AppSettings())
    let settings = AppSettings(
        twilightThemeSeedHex: "#5cc8ff",
        twilightWallpaperPreset: .forest,
        twilightCustomWallpaperPath: "/tmp/custom.png",
        twilightOpacityPercent: 72
    )

    store.updateAppSettings(settings)

    XCTAssertEqual(store.appSettings.twilightThemeSeedHex, "#7aa2f7")
    XCTAssertEqual(store.appSettings.twilightWallpaperPreset, .forest)
    XCTAssertEqual(store.appSettings.twilightCustomWallpaperPath, "/tmp/custom.png")
    XCTAssertEqual(store.appSettings.twilightOpacityPercent, 72)
    XCTAssertEqual(store.currentTwilightOpacity.termAlpha, 0.468, accuracy: 0.0001)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceStoreTests test
```

Expected: FAIL with missing `AppSettings` init parameters/properties and old default expectations.

- [ ] **Step 3: Implement AppSettings fields and migration**

In `Argo/Domain/AppSettings.swift`, add stored properties after `twilightThemeSeedHex`:

```swift
var twilightWallpaperPreset: TwilightWallpaperPreset?
var twilightCustomWallpaperPath: String?
var twilightOpacityPercent: Int
```

Change defaults:

```swift
static let defaultTerminalBackgroundOpacity = 0.40
static let defaultTerminalBackgroundBlur = false
static let defaultTwilightOpacityPercent = 40
```

Add init parameters:

```swift
twilightWallpaperPreset: TwilightWallpaperPreset? = .desk,
twilightCustomWallpaperPath: String? = nil,
twilightOpacityPercent: Int = AppSettings.defaultTwilightOpacityPercent,
```

Assign normalized values:

```swift
let clampedTwilightOpacityPercent = min(max(twilightOpacityPercent, 0), 100)
self.terminalBackgroundOpacity = min(max(terminalBackgroundOpacity, 0), 1)
self.terminalBackgroundBlur = terminalBackgroundBlur
self.twilightThemeEnabled = twilightThemeEnabled
self.twilightThemeSeedHex = TwilightTheme.migratedSeedHex(twilightThemeSeedHex)
self.twilightWallpaperPreset = twilightWallpaperPreset ?? .desk
self.twilightCustomWallpaperPath = twilightCustomWallpaperPath?
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .nilIfEmpty
self.twilightOpacityPercent = clampedTwilightOpacityPercent
if twilightThemeEnabled {
    self.terminalBackgroundOpacity = Double(clampedTwilightOpacityPercent) / 100
    self.terminalBackgroundBlur = false
}
```

Add coding keys:

```swift
case twilightWallpaperPreset
case twilightCustomWallpaperPath
case twilightOpacityPercent
```

In `init(from:)`, decode and migrate opacity:

```swift
let decodedTwilightOpacityPercent = try container.decodeIfPresent(Int.self, forKey: .twilightOpacityPercent)
let decodedTwilightSeedHex = try container.decodeIfPresent(String.self, forKey: .twilightThemeSeedHex) ?? TwilightTheme.defaultSeedHex
let opacityPercentFromTerminal = decodedTerminalBackgroundOpacity.map { Int(round($0 * 100)) }
let decodedOpacityIsOldDefault = decodedTerminalBackgroundOpacity.map {
    abs($0 - Self.defaultTerminalBackgroundOpacity) < 0.0001 ||
    abs($0 - Self.legacyTerminalBackgroundOpacityDefault) < 0.0001
} ?? true
let migratedTwilightOpacityPercent: Int
if let decodedTwilightOpacityPercent {
    migratedTwilightOpacityPercent = decodedTwilightOpacityPercent
} else if decodedOpacityIsOldDefault {
    migratedTwilightOpacityPercent = Self.defaultTwilightOpacityPercent
} else {
    migratedTwilightOpacityPercent = opacityPercentFromTerminal ?? Self.defaultTwilightOpacityPercent
}
let twilightEnabled = try container.decodeIfPresent(Bool.self, forKey: .twilightThemeEnabled) ?? true
let terminalBackgroundOpacity = twilightEnabled
    ? Double(min(max(migratedTwilightOpacityPercent, 0), 100)) / 100
    : (decodedTerminalBackgroundOpacity ?? Self.defaultTerminalBackgroundOpacity)
let terminalBackgroundBlur = twilightEnabled
    ? false
    : (decodedTerminalBackgroundBlur ?? Self.defaultTerminalBackgroundBlur)
```

Pass these values to `self.init`:

```swift
terminalBackgroundOpacity: terminalBackgroundOpacity,
terminalBackgroundBlur: terminalBackgroundBlur,
terminalBackgroundAppearanceVersion: Self.currentTerminalBackgroundAppearanceVersion,
twilightThemeEnabled: twilightEnabled,
twilightThemeSeedHex: decodedTwilightSeedHex,
twilightWallpaperPreset: try container.decodeIfPresent(TwilightWallpaperPreset.self, forKey: .twilightWallpaperPreset) ?? .desk,
twilightCustomWallpaperPath: try container.decodeIfPresent(String.self, forKey: .twilightCustomWallpaperPath),
twilightOpacityPercent: migratedTwilightOpacityPercent,
```

- [ ] **Step 4: Implement WorkspaceStore derived state and setters**

In `Argo/App/WorkspaceStore.swift`, update derived properties:

```swift
var currentTwilightTheme: TwilightTheme {
    TwilightTheme.generate(seed: appSettings.twilightThemeSeedHex)
}

var currentTwilightOpacity: TwilightOpacityModel {
    TwilightTheme.opacityModel(percent: appSettings.twilightOpacityPercent)
}

var currentTwilightSurfacePalette: TwilightSurfacePalette {
    TwilightTheme.surfacePalette(seed: appSettings.twilightThemeSeedHex)
}
```

Include new fields in `updateAppSettings(_:)`:

```swift
twilightWallpaperPreset: settings.twilightWallpaperPreset,
twilightCustomWallpaperPath: settings.twilightCustomWallpaperPath,
twilightOpacityPercent: settings.twilightOpacityPercent,
```

Add setters near other settings actions:

```swift
func setTwilightSeedHex(_ seedHex: String) {
    var settings = appSettings
    settings.twilightThemeSeedHex = TwilightTheme.migratedSeedHex(seedHex)
    updateAppSettings(settings)
}

func setTwilightWallpaperPreset(_ preset: TwilightWallpaperPreset) {
    var settings = appSettings
    settings.twilightWallpaperPreset = preset
    settings.twilightCustomWallpaperPath = nil
    updateAppSettings(settings)
}

func setTwilightOpacityPercent(_ percent: Int) {
    var settings = appSettings
    settings.twilightOpacityPercent = min(max(percent, 0), 100)
    settings.terminalBackgroundOpacity = Double(settings.twilightOpacityPercent) / 100
    settings.terminalBackgroundBlur = false
    updateAppSettings(settings)
}

func setTwilightCustomWallpaper(url: URL) throws {
    let destination = argoStateDirectoryURL()
        .appendingPathComponent("twilight-wallpapers", isDirectory: true)
        .appendingPathComponent("custom.\(url.pathExtension.isEmpty ? "png" : url.pathExtension.lowercased())")
    try FileManager.default.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.copyItem(at: url, to: destination)
    var settings = appSettings
    settings.twilightWallpaperPreset = nil
    settings.twilightCustomWallpaperPath = destination.path
    updateAppSettings(settings)
}
```

- [ ] **Step 5: Run WorkspaceStore tests**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceStoreTests test
```

Expected: PASS for the new settings migration tests and existing `WorkspaceStoreTests`.

- [ ] **Step 6: Commit**

```bash
git add Argo/Domain/AppSettings.swift Argo/App/WorkspaceStore.swift Tests/WorkspaceStoreTests.swift
git commit -m "feat(settings): twilight prefs"
```

---

### Task 3: Ghostty Config And Warp Export

**Files:**
- Modify: `Argo/Services/Terminal/Ghostty/ArgoGhosttyConfig.swift`
- Create: `Argo/Services/Terminal/TwilightWarpExporter.swift`
- Modify: `Argo/App/WorkspaceStore.swift`
- Modify: `Tests/ArgoGhosttyConfigTests.swift`
- Create: `Tests/TwilightWarpExporterTests.swift`

**Interfaces:**
- Consumes: `TwilightTheme.generate(seed:)`, `AppSettings.twilightOpacityPercent`
- Produces:
  - `TwilightWarpExporter.export(theme:seedHex:directory:fileManager:) throws -> URL`
  - `WorkspaceStore.exportCurrentTwilightWarpTheme() throws -> URL`

- [ ] **Step 1: Write failing Ghostty config tests**

Replace old opacity/blur Twilight expectations in `Tests/ArgoGhosttyConfigTests.swift`:

```swift
func testManagedConfigContentsIncludesDefaultTwilightOpacityWithoutBlur() {
    let contents = ArgoGhosttyConfigManager.managedConfigContents(settings: AppSettings())

    XCTAssertTrue(contents.contains("background-opacity = 0.40"))
    XCTAssertFalse(contents.contains("background-blur = true"))
}

func testManagedConfigContentsUseCurrentTwilightThemeByDefault() {
    let contents = ArgoGhosttyConfigManager.managedConfigContents(settings: AppSettings())

    XCTAssertTrue(contents.contains("# theme: Twilight #cba6f7"))
    XCTAssertTrue(contents.contains("background = #101220"))
    XCTAssertTrue(contents.contains("foreground = #f0eff2"))
    XCTAssertTrue(contents.contains("palette = 0=#202238"))
    XCTAssertTrue(contents.contains("palette = 15=#f5f4f6"))
    XCTAssertFalse(contents.contains("theme = "))
}

func testManagedConfigContentsIgnoreBlurWhenTwilightIsEnabled() {
    let contents = ArgoGhosttyConfigManager.managedConfigContents(
        settings: AppSettings(
            terminalBackgroundOpacity: 0.65,
            terminalBackgroundBlur: true,
            twilightThemeEnabled: true,
            twilightOpacityPercent: 65
        )
    )

    XCTAssertTrue(contents.contains("background-opacity = 0.65"))
    XCTAssertFalse(contents.contains("background-blur = true"))
}

func testManagedConfigContentsAllowBlurOnlyOutsideTwilight() {
    let contents = ArgoGhosttyConfigManager.managedConfigContents(
        settings: AppSettings(
            terminalBackgroundOpacity: 0.65,
            terminalBackgroundBlur: true,
            twilightThemeEnabled: false
        )
    )

    XCTAssertTrue(contents.contains("background-opacity = 0.65"))
    XCTAssertTrue(contents.contains("background-blur = true"))
}
```

- [ ] **Step 2: Write failing Warp exporter tests**

Create `Tests/TwilightWarpExporterTests.swift`:

```swift
import XCTest
@testable import Argo

final class TwilightWarpExporterTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArgoWarpExporterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testExporterWritesPresetYamlWithoutOpacityOrWallpaper() throws {
        let theme = TwilightTheme.generate(seed: "#cba6f7")

        let url = try TwilightWarpExporter.export(
            theme: theme,
            seedHex: "#cba6f7",
            directory: temporaryDirectory
        )

        XCTAssertEqual(url.lastPathComponent, "catppuccin.yaml")
        let yaml = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(yaml.contains("name: Catppuccin Mocha"))
        XCTAssertTrue(yaml.contains("accent: '#cba6f7'"))
        XCTAssertTrue(yaml.contains("background: '#101220'"))
        XCTAssertTrue(yaml.contains("foreground: '#f0eff2'"))
        XCTAssertTrue(yaml.contains("black:   '#202238'"))
        XCTAssertTrue(yaml.contains("white:   '#f5f4f6'"))
        XCTAssertFalse(yaml.contains("opacity"))
        XCTAssertFalse(yaml.contains("wallpaper"))
        XCTAssertFalse(yaml.contains("blur"))
    }

    func testExporterWritesCustomYamlSlugFromSeed() throws {
        let theme = TwilightTheme.generate(seed: "#123456")

        let url = try TwilightWarpExporter.export(
            theme: theme,
            seedHex: "#123456",
            directory: temporaryDirectory
        )

        XCTAssertEqual(url.lastPathComponent, "custom-123456.yaml")
        let yaml = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(yaml.contains("name: Custom #123456"))
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/ArgoGhosttyConfigTests -only-testing:ArgoTests/TwilightWarpExporterTests test
```

Expected: FAIL because `TwilightWarpExporter` does not exist and Ghostty config still clamps opacity to `0.5` and writes blur.

- [ ] **Step 4: Update Ghostty managed config**

In `Argo/Services/Terminal/Ghostty/ArgoGhosttyConfig.swift`, replace opacity block with:

```swift
let configuredOpacity = settings.twilightThemeEnabled
    ? Double(settings.twilightOpacityPercent) / 100
    : settings.terminalBackgroundOpacity

if configuredOpacity < 1 {
    let opacity = min(max(configuredOpacity, 0), 1)
    lines.append("background-opacity = \(String(format: "%.2f", opacity))")
    if !settings.twilightThemeEnabled, settings.terminalBackgroundBlur {
        lines.append("background-blur = true")
    }
}
```

- [ ] **Step 5: Implement Warp exporter**

Create `Argo/Services/Terminal/TwilightWarpExporter.swift`:

```swift
import Foundation

enum TwilightWarpExporter {
    private static let presetNames: [String: String] = [
        "#cba6f7": "Catppuccin Mocha",
        "#7aa2f7": "Tokyo Night",
        "#bd93f9": "Dracula",
        "#88c0d0": "Nord",
        "#fabd2f": "Gruvbox",
        "#ebbcba": "Rosé Pine",
    ]

    static func export(
        theme: TwilightTheme,
        seedHex: String,
        directory: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) throws -> URL {
        let normalizedSeed = TwilightTheme.migratedSeedHex(seedHex)
        let name = presetNames[normalizedSeed] ?? "Custom \(normalizedSeed)"
        let slug = presetNames[normalizedSeed]
            .map { $0.split(separator: " ").first.map(String.init) ?? "custom" }?
            .lowercased()
            ?? "custom-\(normalizedSeed.dropFirst())"
        let fileURL = directory.appendingPathComponent("\(slug).yaml")
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try yaml(theme: theme, seedHex: normalizedSeed, name: name)
            .write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private static func yaml(theme: TwilightTheme, seedHex: String, name: String) -> String {
        let normal = theme.ghostty.normal
        let bright = theme.ghostty.bright
        return """
        # \(name) — generated by Argo from \(seedHex)
        # Install: copy to ~/.warp/themes/ and choose it in Warp Settings > Appearance > Themes.
        # Transparency and blur are window settings; this theme only contains colors.
        name: \(name)
        accent: '\(theme.ghostty.accent)'
        background: '\(theme.ghostty.background)'
        foreground: '\(theme.ghostty.foreground)'
        details: darker
        terminal_colors:
          normal:
            black:   '\(normal.black.hex)'
            red:     '\(normal.red.hex)'
            green:   '\(normal.green.hex)'
            yellow:  '\(normal.yellow.hex)'
            blue:    '\(normal.blue.hex)'
            magenta: '\(normal.magenta.hex)'
            cyan:    '\(normal.cyan.hex)'
            white:   '\(normal.white.hex)'
          bright:
            black:   '\(bright.black.hex)'
            red:     '\(bright.red.hex)'
            green:   '\(bright.green.hex)'
            yellow:  '\(bright.yellow.hex)'
            blue:    '\(bright.blue.hex)'
            magenta: '\(bright.magenta.hex)'
            cyan:    '\(bright.cyan.hex)'
            white:   '\(bright.white.hex)'
        """
        + "\n"
    }
}
```

Add to `WorkspaceStore`:

```swift
func exportCurrentTwilightWarpTheme() throws -> URL {
    try TwilightWarpExporter.export(
        theme: currentTwilightTheme,
        seedHex: appSettings.twilightThemeSeedHex
    )
}
```

- [ ] **Step 6: Run Ghostty and Warp tests**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/ArgoGhosttyConfigTests -only-testing:ArgoTests/TwilightWarpExporterTests test
```

Expected: PASS for `ArgoGhosttyConfigTests` and `TwilightWarpExporterTests`.

- [ ] **Step 7: Commit**

```bash
git add Argo/Services/Terminal/Ghostty/ArgoGhosttyConfig.swift Argo/Services/Terminal/TwilightWarpExporter.swift Argo/App/WorkspaceStore.swift Tests/ArgoGhosttyConfigTests.swift Tests/TwilightWarpExporterTests.swift
git commit -m "feat(term): warp export"
```

---

### Task 4: Wallpaper Rendering

**Files:**
- Modify: `Argo/UI/Components/TwilightWallpaperView.swift`
- Create: `Tests/TwilightUISourceTests.swift`

**Interfaces:**
- Consumes: `TwilightWallpaperPreset`, `AppSettings.twilightCustomWallpaperPath`
- Produces: `TwilightWallpaperView(preset:customImagePath:)`

- [ ] **Step 1: Write failing source tests for wallpaper rendering**

Create `Tests/TwilightUISourceTests.swift`:

```swift
import XCTest

final class TwilightUISourceTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    func testWallpaperViewUsesImageBackgroundAndPreviewOverlay() throws {
        let source = try read("Argo/UI/Components/TwilightWallpaperView.swift")

        XCTAssertTrue(source.contains("AsyncImage"))
        XCTAssertTrue(source.contains("customImagePath"))
        XCTAssertTrue(source.contains("TwilightWallpaperPreset"))
        XCTAssertTrue(source.contains("linear-gradient(115deg"))
        XCTAssertTrue(source.contains("radial-gradient(120% 92%"))
        XCTAssertFalse(source.contains("theme.wallpaper.sunGlow"))
        XCTAssertFalse(source.contains("theme.wallpaper.skyWaterStops"))
    }

    private func read(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
```

- [ ] **Step 2: Run source test to verify it fails**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/TwilightUISourceTests/testWallpaperViewUsesImageBackgroundAndPreviewOverlay test
```

Expected: FAIL because the current wallpaper view uses the old seed-generated radial/linear sunset.

- [ ] **Step 3: Implement image wallpaper view**

Replace `Argo/UI/Components/TwilightWallpaperView.swift` with:

```swift
import SwiftUI

struct TwilightWallpaperView: View {
    let preset: TwilightWallpaperPreset
    let customImagePath: String?

    private var customImageURL: URL? {
        customImagePath.map(URL.init(fileURLWithPath:))
    }

    var body: some View {
        ZStack {
            wallpaperImage
                .overlay(darkeningLayers)
                .overlay(lightAndVignetteLayers)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var wallpaperImage: some View {
        if let customImageURL,
           let nsImage = NSImage(contentsOf: customImageURL) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
        } else {
            AsyncImage(url: preset.remoteURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    fallbackWallpaper
                case .failure:
                    fallbackWallpaper
                @unknown default:
                    fallbackWallpaper
                }
            }
        }
    }

    private var fallbackWallpaper: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedRed: 0.149, green: 0.196, blue: 0.267, alpha: 1)),
                    Color(nsColor: NSColor(calibratedRed: 0.110, green: 0.141, blue: 0.196, alpha: 1)),
                    Color(nsColor: NSColor(calibratedRed: 0.067, green: 0.090, blue: 0.125, alpha: 1)),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedRed: 0.365, green: 0.435, blue: 0.541, alpha: 0.36)),
                    .clear,
                ],
                center: UnitPoint(x: 0.78, y: 0.22),
                startRadius: 0,
                endRadius: 720
            )
            RadialGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedRed: 0.306, green: 0.243, blue: 0.424, alpha: 0.30)),
                    .clear,
                ],
                center: UnitPoint(x: 0.18, y: 0.76),
                startRadius: 0,
                endRadius: 620
            )
        }
    }

    private var darkeningLayers: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedRed: 0.035, green: 0.051, blue: 0.086, alpha: 0.24)),
                    Color(nsColor: NSColor(calibratedRed: 0.035, green: 0.051, blue: 0.086, alpha: 0.48)),
                ],
                startPoint: UnitPoint(x: 0, y: 0),
                endPoint: UnitPoint(x: 1, y: 1)
            )
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedRed: 0.035, green: 0.051, blue: 0.086, alpha: 0.18)),
                    Color(nsColor: NSColor(calibratedRed: 0.035, green: 0.051, blue: 0.086, alpha: 0.46)),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
    }

    private var lightAndVignetteLayers: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color.white.opacity(0.04), location: 0.46),
                    .init(color: .clear, location: 0.62),
                ],
                startPoint: UnitPoint(x: 0, y: 0),
                endPoint: UnitPoint(x: 1, y: 1)
            )
            RadialGradient(
                stops: [
                    .init(color: .clear, location: 0.52),
                    .init(color: Color.black.opacity(0.32), location: 1),
                ],
                center: .center,
                startRadius: 0,
                endRadius: 900
            )
        }
        .accessibilityHidden(true)
        // Source markers: linear-gradient(115deg) and radial-gradient(120% 92%) from preview.html.
    }
}
```

- [ ] **Step 4: Run wallpaper source test**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/TwilightUISourceTests/testWallpaperViewUsesImageBackgroundAndPreviewOverlay test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Argo/UI/Components/TwilightWallpaperView.swift Tests/TwilightUISourceTests.swift
git commit -m "feat(ui): wallpaper"
```

---

### Task 5: Dynamic Surfaces And Blur Removal

**Files:**
- Modify: `Argo/UI/MainWindowView.swift`
- Modify: `Argo/UI/Workspace/WorkspaceDetailView.swift`
- Modify: `Argo/UI/Workspace/TerminalPaneView.swift`
- Modify: `Argo/UI/Workspace/TerminalLocalChrome.swift`
- Modify: `Tests/TwilightUISourceTests.swift`

**Interfaces:**
- Consumes: `WorkspaceStore.currentTwilightSurfacePalette`, `WorkspaceStore.currentTwilightOpacity`
- Produces:
  - `TopChromeSurfaceBackground(surfacePalette:opacity:)`
  - `TerminalWorkspaceSurface(surfacePalette:opacity:chromeTint:content:)`

- [ ] **Step 1: Write failing source tests for dynamic surfaces**

Add to `Tests/TwilightUISourceTests.swift`:

```swift
func testMainWindowUsesDynamicTwilightSurfaces() throws {
    let source = try read("Argo/UI/MainWindowView.swift")

    XCTAssertTrue(source.contains("store.currentTwilightSurfacePalette"))
    XCTAssertTrue(source.contains("store.currentTwilightOpacity"))
    XCTAssertTrue(source.contains("TwilightWallpaperView("))
    XCTAssertTrue(source.contains("preset: store.appSettings.twilightWallpaperPreset ?? .desk"))
    XCTAssertTrue(source.contains("customImagePath: store.appSettings.twilightCustomWallpaperPath"))
    XCTAssertFalse(source.contains(".background(ArgoTheme.glassSide)"))
}

func testTerminalSurfaceDoesNotUseBlurView() throws {
    let source = try read("Argo/UI/Workspace/WorkspaceDetailView.swift")

    XCTAssertTrue(source.contains("surfacePalette"))
    XCTAssertTrue(source.contains("scrim1Alpha"))
    XCTAssertTrue(source.contains("scrim2Alpha"))
    XCTAssertFalse(source.contains("TerminalBackgroundBlurView()"))
    XCTAssertFalse(source.contains("NSVisualEffectView"))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/TwilightUISourceTests/testMainWindowUsesDynamicTwilightSurfaces -only-testing:ArgoTests/TwilightUISourceTests/testTerminalSurfaceDoesNotUseBlurView test
```

Expected: FAIL because views still use static `ArgoTheme.glassSide` and `TerminalBackgroundBlurView`.

- [ ] **Step 3: Update MainWindow surfaces**

In `MainWindowView`, add helpers:

```swift
private var twilightSurfacePalette: TwilightSurfacePalette {
    store.currentTwilightSurfacePalette
}

private var twilightOpacity: TwilightOpacityModel {
    store.currentTwilightOpacity
}
```

Update wallpaper:

```swift
TwilightWallpaperView(
    preset: store.appSettings.twilightWallpaperPreset ?? .desk,
    customImagePath: store.appSettings.twilightCustomWallpaperPath
)
.transition(.opacity)
```

Replace sidebar background:

```swift
.background(
    store.appSettings.twilightThemeEnabled
        ? twilightSurfacePalette.color(\.glassSide, alpha: twilightOpacity.glassSideAlpha)
        : ArgoTheme.glassSide
)
```

Change top/status background calls:

```swift
TopChromeSurfaceBackground(
    surfacePalette: twilightSurfacePalette,
    opacity: twilightOpacity,
    usesTwilight: store.appSettings.twilightThemeEnabled
)
```

Replace `TopChromeSurfaceBackground`:

```swift
struct TopChromeSurfaceBackground: View {
    let surfacePalette: TwilightSurfacePalette
    let opacity: TwilightOpacityModel
    let usesTwilight: Bool

    var body: some View {
        if usesTwilight {
            surfacePalette.color(\.topGlass, alpha: opacity.topGlassAlpha)
        } else {
            ArgoTheme.topGlass
        }
    }
}
```

- [ ] **Step 4: Update terminal surface and remove blur view**

In `WorkspaceDetailView`, pass dynamic surfaces:

```swift
let surfacePalette = store.currentTwilightSurfacePalette
let opacity = store.currentTwilightOpacity

TerminalWorkspaceSurface(
    chromeTint: activeTerminalChromeTint,
    surfacePalette: surfacePalette,
    opacity: opacity,
    usesTwilight: store.appSettings.twilightThemeEnabled
) {
    SplitNodeView(
        workspace: workspace,
        sessionController: workspace.sessionController,
        node: layout,
        dimsInactivePanes: shouldDimInactiveTerminalPanes
    )
}
```

Replace `TerminalWorkspaceSurface` body with dynamic fill and scrim:

```swift
private struct TerminalWorkspaceSurface<Content: View>: View {
    let chromeTint: ArgoChromeTint
    let surfacePalette: TwilightSurfacePalette
    let opacity: TwilightOpacityModel
    let usesTwilight: Bool
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            if usesTwilight {
                surfacePalette.color(\.term, alpha: opacity.termAlpha)
                LinearGradient(
                    stops: [
                        .init(color: surfacePalette.scrim.color(alpha: opacity.scrim1Alpha), location: 0),
                        .init(color: surfacePalette.scrim.color(alpha: opacity.scrim1Alpha), location: 0.14),
                        .init(color: surfacePalette.scrim.color(alpha: opacity.scrim2Alpha), location: 0.46),
                        .init(color: surfacePalette.scrim.color(alpha: opacity.scrim2Alpha * 0.2), location: 0.74),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)
            } else {
                TerminalWorkspaceSurfaceStyle.background(for: chromeTint)
            }

            content
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: chromeTint.components.color.opacity(0.50), location: 0.55),
                    .init(color: ArgoTheme.amber2.opacity(0.65), location: 0.75),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 2)
        }
    }
}
```

Delete `TerminalBackgroundBlurView`.

In `TerminalPaneView`, use clear pane fill while Twilight is enabled:

```swift
private var paneFill: Color {
    if store.appSettings.twilightThemeEnabled || store.appSettings.terminalBackgroundOpacity < 1 {
        return .clear
    }
    return ArgoTheme.paneBackground
}
```

- [ ] **Step 5: Run dynamic surface tests**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/TwilightUISourceTests/testMainWindowUsesDynamicTwilightSurfaces -only-testing:ArgoTests/TwilightUISourceTests/testTerminalSurfaceDoesNotUseBlurView test
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Argo/UI/MainWindowView.swift Argo/UI/Workspace/WorkspaceDetailView.swift Argo/UI/Workspace/TerminalPaneView.swift Argo/UI/Workspace/TerminalLocalChrome.swift Tests/TwilightUISourceTests.swift
git commit -m "feat(ui): surfaces"
```

---

### Task 6: Theme Dock And Toast

**Files:**
- Create: `Argo/UI/Components/TwilightThemeDockView.swift`
- Modify: `Argo/UI/MainWindowView.swift`
- Modify: `Tests/TwilightUISourceTests.swift`

**Interfaces:**
- Consumes:
  - `WorkspaceStore.setTwilightSeedHex(_:)`
  - `WorkspaceStore.setTwilightWallpaperPreset(_:)`
  - `WorkspaceStore.setTwilightCustomWallpaper(url:) throws`
  - `WorkspaceStore.setTwilightOpacityPercent(_:)`
  - `WorkspaceStore.exportCurrentTwilightWarpTheme() throws -> URL`
- Produces: `TwilightThemeDockView(surfacePalette:opacity:)`

- [ ] **Step 1: Write failing dock source tests**

Add to `Tests/TwilightUISourceTests.swift`:

```swift
func testThemeDockExistsAndIsMountedInMainWindow() throws {
    let dock = try read("Argo/UI/Components/TwilightThemeDockView.swift")
    let main = try read("Argo/UI/MainWindowView.swift")

    XCTAssertTrue(dock.contains("struct TwilightThemeDockView"))
    XCTAssertTrue(dock.contains("TwilightTheme.presets"))
    XCTAssertTrue(dock.contains("TwilightWallpaperPreset.allCases"))
    XCTAssertTrue(dock.contains("NSOpenPanel"))
    XCTAssertTrue(dock.contains("Slider("))
    XCTAssertTrue(dock.contains("TextField("))
    XCTAssertTrue(dock.contains("exportCurrentTwilightWarpTheme"))
    XCTAssertTrue(dock.contains("mv ~/Downloads/"))
    XCTAssertTrue(main.contains("TwilightThemeDockView("))
    XCTAssertTrue(main.contains(".padding(.trailing, 26)"))
    XCTAssertTrue(main.contains(".padding(.bottom, 26)"))
}
```

- [ ] **Step 2: Run dock test to verify it fails**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/TwilightUISourceTests/testThemeDockExistsAndIsMountedInMainWindow test
```

Expected: FAIL because the dock file does not exist and the main window does not mount it.

- [ ] **Step 3: Create TwilightThemeDockView**

Create `Argo/UI/Components/TwilightThemeDockView.swift`:

```swift
import AppKit
import SwiftUI

struct TwilightThemeDockView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @ObservedObject private var localization = LocalizationManager.shared

    let surfacePalette: TwilightSurfacePalette
    let opacity: TwilightOpacityModel

    @State private var seedDraft = TwilightTheme.defaultSeedHex
    @State private var seedHasError = false
    @State private var toastFileName: String?
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                dockLabel("预设")

                ForEach(TwilightTheme.presets) { preset in
                    Button {
                        seedDraft = preset.seedHex
                        seedHasError = false
                        store.setTwilightSeedHex(preset.seedHex)
                    } label: {
                        TwilightThemeSwatch(seedHex: preset.seedHex, isSelected: store.appSettings.twilightThemeSeedHex == preset.seedHex)
                    }
                    .buttonStyle(.plain)
                    .help(localization.string(preset.nameKey))
                }

                divider
                dockLabel("图片")

                ForEach(TwilightWallpaperPreset.allCases) { preset in
                    Button {
                        store.setTwilightWallpaperPreset(preset)
                    } label: {
                        TwilightWallpaperSwatch(
                            preset: preset,
                            isSelected: store.appSettings.twilightWallpaperPreset == preset && store.appSettings.twilightCustomWallpaperPath == nil
                        )
                    }
                    .buttonStyle(.plain)
                    .help(preset.label)
                }

                Button {
                    chooseCustomWallpaper()
                } label: {
                    Image(systemName: "photo")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("本地图片")

                divider

                Slider(
                    value: Binding(
                        get: { Double(store.appSettings.twilightOpacityPercent) },
                        set: { store.setTwilightOpacityPercent(Int($0.rounded())) }
                    ),
                    in: 0...100,
                    step: 1
                )
                .frame(width: 92)
                Text("\(store.appSettings.twilightOpacityPercent)%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ArgoTheme.textDim)
                    .frame(width: 34, alignment: .trailing)

                divider

                ColorPicker("", selection: Binding(
                    get: { store.currentTwilightTheme.amber.color },
                    set: { color in
                        if let hex = color.twilightHexString {
                            seedDraft = hex
                            seedHasError = false
                            store.setTwilightSeedHex(hex)
                        }
                    }
                ))
                .labelsHidden()
                .frame(width: 26, height: 26)

                TextField("#cba6f7", text: Binding(
                    get: { seedDraft },
                    set: { value in
                        seedDraft = value.lowercased()
                        guard let normalized = TwilightTheme.validSeedHex(value) else {
                            seedHasError = true
                            return
                        }
                        seedHasError = false
                        store.setTwilightSeedHex(normalized)
                    }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .frame(width: 72, height: 26)
                .padding(.horizontal, 8)
                .background(Color.black.opacity(opacity.softFillAlpha), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(seedHasError ? ArgoTheme.danger.opacity(0.9) : ArgoTheme.hairline, lineWidth: 1)
                )

                Button {
                    exportWarp()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Warp")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .frame(height: 30)
                    .padding(.horizontal, 13)
                    .background(store.currentTwilightTheme.amber.color.opacity(0.90), in: Capsule())
                    .foregroundStyle(Color(nsColor: NSColor(calibratedRed: 0.102, green: 0.071, blue: 0.031, alpha: 1)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(surfacePalette.color(\.dock, alpha: opacity.dockAlpha), in: Capsule())
            .overlay(Capsule().stroke(ArgoTheme.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.50), radius: 20, y: 12)

            if let toastFileName {
                TwilightToastView(
                    fileName: toastFileName,
                    surfacePalette: surfacePalette,
                    opacity: opacity
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            seedDraft = store.appSettings.twilightThemeSeedHex
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(ArgoTheme.hairlineSoft)
            .frame(width: 1, height: 20)
    }

    private func dockLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(ArgoTheme.textFaint)
    }

    private func chooseCustomWallpaper() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.setTwilightCustomWallpaper(url: url)
        } catch {
            store.presentedError = WorkspaceUserFacingError(title: "Wallpaper", message: error.localizedDescription)
        }
    }

    private func exportWarp() {
        do {
            let url = try store.exportCurrentTwilightWarpTheme()
            toastFileName = url.lastPathComponent
            toastTask?.cancel()
            toastTask = Task {
                try? await Task.sleep(nanoseconds: 4_200_000_000)
                await MainActor.run { toastFileName = nil }
            }
        } catch {
            store.presentedError = WorkspaceUserFacingError(title: "Warp", message: error.localizedDescription)
        }
    }
}
```

Add supporting small views in the same file:

```swift
private struct TwilightThemeSwatch: View {
    let seedHex: String
    let isSelected: Bool

    var body: some View {
        let hsl = TwilightHSLColor.hexToHSL(seedHex)
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(nsColor: NSColor(hex: seedHex) ?? .white),
                        TwilightHSLColor(hue: hsl.hue, saturation: TwilightTheme.clamp(hsl.saturation, 40, 90), lightness: 34).color,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 24, height: 24)
            .overlay(Circle().stroke(isSelected ? Color.white : ArgoTheme.hairline, lineWidth: 2))
    }
}

private struct TwilightWallpaperSwatch: View {
    let preset: TwilightWallpaperPreset
    let isSelected: Bool

    var body: some View {
        AsyncImage(url: preset.remoteURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(ArgoTheme.glassCard)
            }
        }
        .frame(width: 34, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.white : Color.white.opacity(0.12), lineWidth: isSelected ? 2 : 1)
        )
    }
}

private struct TwilightToastView: View {
    let fileName: String
    let surfacePalette: TwilightSurfacePalette
    let opacity: TwilightOpacityModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("已导出 \(fileName)")
            Text("mv ~/Downloads/\(fileName) ~/.warp/themes/")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(ArgoTheme.textFaint)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(ArgoTheme.text)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: 380, alignment: .leading)
        .background(surfacePalette.color(\.toast, alpha: opacity.toastAlpha), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(ArgoTheme.hairline, lineWidth: 1))
    }
}
```

Add color helpers:

```swift
private extension NSColor {
    convenience init?(hex: String) {
        guard let normalized = TwilightTheme.validSeedHex(hex) else { return nil }
        let value = UInt64(normalized.dropFirst(), radix: 16)!
        self.init(
            calibratedRed: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }
}

private extension Color {
    var twilightHexString: String? {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let red = Int((nsColor.redComponent * 255).rounded())
        let green = Int((nsColor.greenComponent * 255).rounded())
        let blue = Int((nsColor.blueComponent * 255).rounded())
        return String(format: "#%02x%02x%02x", red, green, blue)
    }
}
```

- [ ] **Step 4: Mount dock in MainWindowView**

Inside `ZStack`, after the status banner layer and before closing the `ZStack`, add:

```swift
if store.mainWindowMode == .workspace, store.appSettings.twilightThemeEnabled {
    VStack {
        Spacer()
        HStack {
            Spacer()
            TwilightThemeDockView(
                surfacePalette: twilightSurfacePalette,
                opacity: twilightOpacity
            )
            .environmentObject(store)
            .padding(.trailing, 26)
            .padding(.bottom, 26)
        }
    }
    .zIndex(2.5)
}
```

- [ ] **Step 5: Run dock source test**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/TwilightUISourceTests/testThemeDockExistsAndIsMountedInMainWindow test
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Argo/UI/Components/TwilightThemeDockView.swift Argo/UI/MainWindowView.swift Tests/TwilightUISourceTests.swift
git commit -m "feat(ui): theme dock"
```

---

### Task 7: Settings And Localization

**Files:**
- Modify: `Argo/UI/Sheets/SettingsSheet.swift`
- Modify: `Argo/Support/L10n.swift`
- Modify: `Tests/LocalizationManagerTests.swift`
- Modify: `Tests/TwilightUISourceTests.swift`

**Interfaces:**
- Consumes: `TwilightTheme.presets`, `TwilightWallpaperPreset.allCases`, `AppSettings.twilightOpacityPercent`
- Produces: Settings UI controls matching dock defaults and localized names.

- [ ] **Step 1: Write failing localization tests**

Add to `Tests/LocalizationManagerTests.swift`:

```swift
func testCurrentTwilightPresetLocalization() {
    XCTAssertEqual(L10nTable.string(for: "settings.twilight.preset.catppuccinMocha", language: .english), "Catppuccin Mocha")
    XCTAssertEqual(L10nTable.string(for: "settings.twilight.preset.tokyoNight", language: .english), "Tokyo Night")
    XCTAssertEqual(L10nTable.string(for: "settings.twilight.preset.dracula", language: .english), "Dracula")
    XCTAssertEqual(L10nTable.string(for: "settings.twilight.preset.nord", language: .english), "Nord")
    XCTAssertEqual(L10nTable.string(for: "settings.twilight.preset.gruvbox", language: .english), "Gruvbox")
    XCTAssertEqual(L10nTable.string(for: "settings.twilight.preset.rosePine", language: .english), "Rosé Pine")

    XCTAssertEqual(L10nTable.string(for: "settings.twilight.preset.catppuccinMocha", language: .simplifiedChinese), "Catppuccin Mocha")
    XCTAssertEqual(L10nTable.string(for: "settings.twilight.preset.tokyoNight", language: .simplifiedChinese), "Tokyo Night")
    XCTAssertEqual(L10nTable.string(for: "settings.twilight.preset.dracula", language: .simplifiedChinese), "Dracula")
    XCTAssertEqual(L10nTable.string(for: "settings.twilight.preset.nord", language: .simplifiedChinese), "Nord")
    XCTAssertEqual(L10nTable.string(for: "settings.twilight.preset.gruvbox", language: .simplifiedChinese), "Gruvbox")
    XCTAssertEqual(L10nTable.string(for: "settings.twilight.preset.rosePine", language: .simplifiedChinese), "Rosé Pine")
}

func testTwilightWallpaperAndOpacityLocalization() {
    XCTAssertEqual(L10nTable.string(for: "settings.twilight.wallpaper", language: .english), "Wallpaper")
    XCTAssertEqual(L10nTable.string(for: "settings.twilight.opacity", language: .english), "Opacity")
    XCTAssertEqual(L10nTable.string(for: "settings.twilight.wallpaper", language: .simplifiedChinese), "背景图片")
    XCTAssertEqual(L10nTable.string(for: "settings.twilight.opacity", language: .simplifiedChinese), "透明度")
}
```

Add to `Tests/TwilightUISourceTests.swift`:

```swift
func testSettingsUseTwilightOpacityPercentAndWallpaperControls() throws {
    let source = try read("Argo/UI/Sheets/SettingsSheet.swift")

    XCTAssertTrue(source.contains("twilightOpacityPercent"))
    XCTAssertTrue(source.contains("TwilightWallpaperPreset.allCases"))
    XCTAssertTrue(source.contains("0...100"))
    XCTAssertFalse(source.contains("Slider(value: $appSettings.terminalBackgroundOpacity, in: 0.5...1"))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/LocalizationManagerTests -only-testing:ArgoTests/TwilightUISourceTests/testSettingsUseTwilightOpacityPercentAndWallpaperControls test
```

Expected: FAIL because localization keys and settings controls still reflect old preset/opacity behavior.

- [ ] **Step 3: Update L10n keys**

In `Argo/Support/L10n.swift`, replace old Twilight preset keys in the English table:

```swift
"settings.twilight.description": "Match the Twilight Terminal preview with image wallpaper, tinted transparent surfaces, and Ghostty colors.",
"settings.twilight.wallpaper": "Wallpaper",
"settings.twilight.opacity": "Opacity",
"settings.twilight.customWallpaper": "Custom image",
"settings.twilight.preset.catppuccinMocha": "Catppuccin Mocha",
"settings.twilight.preset.tokyoNight": "Tokyo Night",
"settings.twilight.preset.dracula": "Dracula",
"settings.twilight.preset.nord": "Nord",
"settings.twilight.preset.gruvbox": "Gruvbox",
"settings.twilight.preset.rosePine": "Rosé Pine",
```

Replace old Twilight preset keys in the Simplified Chinese table:

```swift
"settings.twilight.description": "对齐 Twilight Terminal 预览：图片背景、染色透明面板和 Ghostty 配色同源。",
"settings.twilight.wallpaper": "背景图片",
"settings.twilight.opacity": "透明度",
"settings.twilight.customWallpaper": "本地图片",
"settings.twilight.preset.catppuccinMocha": "Catppuccin Mocha",
"settings.twilight.preset.tokyoNight": "Tokyo Night",
"settings.twilight.preset.dracula": "Dracula",
"settings.twilight.preset.nord": "Nord",
"settings.twilight.preset.gruvbox": "Gruvbox",
"settings.twilight.preset.rosePine": "Rosé Pine",
```

- [ ] **Step 4: Update SettingsSheet Twilight controls**

In `themeSettingsView`, after preset swatches and seed field, add wallpaper and opacity controls:

```swift
Text(localized("settings.twilight.wallpaper"))
    .font(.system(size: 11, weight: .semibold))
    .foregroundStyle(.secondary)

HStack(spacing: 8) {
    ForEach(TwilightWallpaperPreset.allCases) { preset in
        Button {
            appSettings.twilightWallpaperPreset = preset
            appSettings.twilightCustomWallpaperPath = nil
            applyThemeLive()
        } label: {
            Text(preset.label)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(
                    (appSettings.twilightWallpaperPreset == preset && appSettings.twilightCustomWallpaperPath == nil)
                        ? ArgoTheme.accentMuted
                        : ArgoTheme.glassCard,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}

HStack {
    Text(localized("settings.twilight.opacity"))
    Spacer()
    Text("\(appSettings.twilightOpacityPercent)%")
        .foregroundStyle(.secondary)
}

Slider(
    value: Binding(
        get: { Double(appSettings.twilightOpacityPercent) },
        set: { value in
            appSettings.twilightOpacityPercent = Int(value.rounded())
            appSettings.terminalBackgroundOpacity = Double(appSettings.twilightOpacityPercent) / 100
            appSettings.terminalBackgroundBlur = false
            applyThemeLive()
        }
    ),
    in: 0...100,
    step: 1
)
```

In the terminal section, keep legacy background opacity controls only when Twilight is disabled:

```swift
if !appSettings.twilightThemeEnabled {
    HStack {
        Text(localized("settings.general.terminal.backgroundOpacity"))
        Spacer()
        Text("\(Int((appSettings.terminalBackgroundOpacity * 100).rounded()))%")
            .foregroundStyle(.secondary)
    }

    Slider(value: $appSettings.terminalBackgroundOpacity, in: 0.5...1, step: 0.05)

    Toggle(localized("settings.general.terminal.backgroundBlur"), isOn: $appSettings.terminalBackgroundBlur)
        .disabled(appSettings.terminalBackgroundOpacity >= 1)
}
```

In `twilightSeedBinding`, call migration:

```swift
let migrated = TwilightTheme.migratedSeedHex(normalized)
twilightSeedError = nil
appSettings.twilightThemeSeedHex = migrated
applyThemeLive()
```

- [ ] **Step 5: Run localization and settings source tests**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/LocalizationManagerTests -only-testing:ArgoTests/TwilightUISourceTests/testSettingsUseTwilightOpacityPercentAndWallpaperControls test
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Argo/UI/Sheets/SettingsSheet.swift Argo/Support/L10n.swift Tests/LocalizationManagerTests.swift Tests/TwilightUISourceTests.swift
git commit -m "feat(settings): twilight ui"
```

---

### Task 8: Full Verification And Visual Parity

**Files:**
- Read/verify: `twilight-terminal/preview.html`
- Read/verify: `output/playwright/twilight-reference.png`
- Generate artifact: `output/playwright/argo-twilight.png`

**Interfaces:**
- Consumes: all previous tasks
- Produces: verified build, focused tests, manual screenshot comparison notes.

- [ ] **Step 1: Run focused Twilight tests**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/TwilightThemeTests -only-testing:ArgoTests/WorkspaceStoreTests -only-testing:ArgoTests/ArgoGhosttyConfigTests -only-testing:ArgoTests/TwilightWarpExporterTests -only-testing:ArgoTests/TwilightUISourceTests -only-testing:ArgoTests/LocalizationManagerTests test
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: Run full build**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -configuration Debug -destination 'platform=macOS,arch=arm64' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Re-capture HTML reference screenshot**

Run:

```bash
npx playwright screenshot --full-page twilight-terminal/preview.html output/playwright/twilight-reference.png
```

Expected: `output/playwright/twilight-reference.png` updates and shows the current HTML default state with Catppuccin seed, Desk wallpaper, 40% opacity, and bottom-right theme dock.

- [ ] **Step 4: Capture Argo screenshot manually**

Run Argo from Xcode or the built Debug app. Open a workspace, set window size close to `1360 x 840`, verify Twilight is enabled, then capture:

```bash
screencapture -x output/playwright/argo-twilight.png
```

Expected: `output/playwright/argo-twilight.png` exists and shows:

- 52px top chrome, 64px rail, 280px sidebar, 32px status bar.
- Real Desk wallpaper visible behind transparent surfaces.
- No visible blur haze behind terminal or chrome.
- Default seed color `#cba6f7` selected.
- Default opacity `40%` selected.
- Theme dock in the bottom-right with six theme swatches, four wallpaper swatches, image button, slider, hex input, and Warp button.

- [ ] **Step 5: Manual parity checklist**

Use the HTML reference screenshot and Argo screenshot side by side. Confirm:

- Background image composition, darkening layers, and vignette are visually aligned.
- Top chrome uses `topGlass` tint and keeps `52px` height.
- Rail uses `glassRail` tint and active indicator remains a thin amber line.
- Sidebar uses `glassSide` tint and active row is a light amber gradient, not a solid card.
- Terminal main area uses `termAlpha` and scrim stops; no `TerminalBackgroundBlurView` effect appears.
- Status bar uses topGlass and monospaced `11.5` text.
- Opacity `0%` makes core surfaces transparent enough for wallpaper to show through.
- Opacity `100%` reaches the target alpha while app and terminal still preserve their design caps.
- Warp export creates a YAML file in Downloads and the toast shows `mv ~/Downloads/<file> ~/.warp/themes/`.

- [ ] **Step 6: Commit verification-only adjustments when source changes occurred**

If the visual pass required source changes, run the focused tests and build again, then commit:

```bash
git add Argo Tests
git commit -m "feat(ui): verify parity"
```

Expected: commit is created only if source or test files changed during the verification pass.

---

## Self-Review

**Spec coverage:** The plan covers theme seeds and migration in Task 1, opacity semantics in Tasks 1-2, AppSettings persistence in Task 2, Ghostty/Warp behavior in Task 3, image wallpaper in Task 4, no-blur dynamic surfaces in Task 5, theme dock and toast in Task 6, settings/localization in Task 7, and screenshot/build verification in Task 8.

**Placeholder scan:** The plan avoids empty placeholder wording, deferred implementation wording, and unscoped “write tests” instructions. Every test step includes concrete test code, command, and expected result.

**Type consistency:** `TwilightSurfacePalette`, `TwilightOpacityModel`, `TwilightWallpaperPreset`, `WorkspaceStore` setters, `TwilightWarpExporter.export`, and `TwilightWallpaperView(preset:customImagePath:)` are introduced before later tasks consume them.
