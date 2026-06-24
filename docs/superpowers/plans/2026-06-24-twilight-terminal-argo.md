# Twilight Terminal Argo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `twilight-terminal/设计规范.md` 的 Twilight Terminal 单色驱动视觉系统完整应用到 Argo，并保持现有工作区、侧栏、终端分屏、标签、设置和 Ghostty runtime 行为不受影响。

**Architecture:** 新增一个纯 Swift 的 `TwilightTheme` 主题引擎作为唯一颜色来源，SwiftUI chrome、wallpaper、Settings preview 与 Ghostty managed config 都从同一个 seed 生成。第一版保留 Argo 现有 AppKit + SwiftUI + Ghostty 架构，不替换 `NSOutlineView` 侧栏桥接、不改 pane layout 数据模型、不重写 terminal surface controller。

**Tech Stack:** Swift、SwiftUI、AppKit、GhosttyKit、XCTest、Xcode FileSystemSynchronizedRootGroup。

## Global Constraints

- 面向用户的协作说明和提交前总结使用简体中文；代码、标识符、命令和路径保持英文。
- 每个实现任务开始前使用 `superpowers:test-driven-development`；遇到失败或异常行为先使用 `superpowers:systematic-debugging`；完成前使用 `superpowers:verification-before-completion`。
- 提交前使用 `team-commit-convention`；commit 格式只能是 `feat(scope): subject` 或 `fix(scope): subject`，subject 英文且不超过 20 个字符。
- Twilight 默认 seed 必须是 `#ffb066`。
- 内置预设必须是 `#ffb066`、`#7af0c0`、`#5cc8ff`、`#ff9ec4`、`#ff7a59`。
- 必须保留三个设计签名：全局 `❯` prompt 符号、右下日落构图、单色驱动主题。
- `hexToHsl` 必须支持 `#RGB` 和 `#RRGGBB`；非法 seed 回退 `#ffb066`。
- 饱和度护栏必须保持 `S = clamp(s, 42, 96)`。
- UI 强调色亮度护栏必须保持规范数值：`amber` 亮度 `58...70`，`amber2` 亮度 `72...86`。
- 天空色相必须拉向 `250`，水面色相必须拉向 `218`。
- ANSI 语义色必须锚定 red `358`、green `138`、blue `210`、magenta `305`、cyan `182`，只用 seed 轻染 `12%`。
- `twilightThemeEnabled == true` 时 Ghostty managed config 使用 Twilight 颜色并忽略 `terminalTheme` 颜色输出。
- `twilightThemeEnabled == false && terminalTheme != nil` 时保留现有 Ghostty theme 查找和 inline 行为。
- `twilightThemeEnabled == false && terminalTheme == nil` 时保留 Ghostty 默认 dark 配色。
- `terminalBackgroundOpacity` 与 `terminalBackgroundBlur` 继续按现有规则输出，不由 Twilight 改写。
- `NSWindow` 只保持透明，不新增窗口级 blur；`ArgoDesktopApplication` 必须继续包含 `window.backgroundColor = .clear` 和 `updateBackgroundBlur(enabled: false)`。
- 终端正文区域不新增嵌套 blur；可读性由左浓右淡 scrim、Ghostty opacity 和轻量 overlay 负责。
- `FloatingWorkspaceSidebarSurface` 是 sidebar 唯一完整面板；`WorkspaceSidebarView` 内部不能再绘制第二层完整大面板。
- 不修改 `Argo/Vendor/GhosttyKit.xcframework`。
- 不新增 Warp YAML 导出到 Argo。
- 不引入 Google Fonts；macOS UI 使用系统字体，终端和数据文本继续使用现有 monospaced 配置。
- 新增 Swift 源文件不需要手动编辑 `Argo.xcodeproj/project.pbxproj`，因为 `Argo` 与 `Tests` targets 使用 `PBXFileSystemSynchronizedRootGroup`。

---

## File Structure

- Create `Argo/Support/TwilightTheme.swift`：纯主题算法、HSL 工具、预设、wallpaper 绘制数据、Ghostty 16 色数据。
- Create `Argo/UI/Components/TwilightWallpaperView.swift`：用 `TwilightTheme.wallpaper` 绘制右下太阳、冷色天空 / 水面和地平线高光。
- Create `Tests/TwilightThemeTests.swift`：锁定算法、默认 YAML 同源输出、预设、非法输入 fallback、ANSI 语义色范围。
- Modify `Argo/Domain/AppSettings.swift`：新增 `twilightThemeEnabled`、`twilightThemeSeedHex`，补 init、Codable 迁移和 seed 归一化。
- Modify `Argo/App/WorkspaceStore.swift`：保留 settings 更新路径，新增 `currentTwilightTheme`，确保 settings 保存和通知沿原路径触发。
- Modify `Argo/Services/Terminal/Ghostty/ArgoGhosttyConfig.swift`：Twilight enabled 时输出 `background`、`foreground`、`palette = 0...15`。
- Modify `Argo/Support/ArgoTheme.swift`：把静态 token 映射到 Twilight 默认主题，并新增 glass / scrim / text 语义 token。
- Modify `Argo/Support/ArgoChromeTint.swift`：新增 `resolved(for theme: TwilightTheme)`，让 chrome fill 从 Twilight slots 派生。
- Modify `Argo/UI/MainWindowView.swift`：接入 wallpaper、top chrome token、floating sidebar surface token、命令面板按钮 Twilight 色。
- Modify `Argo/UI/Components/GlobalModeRailView.swift`：rail 背景、active 按钮、左侧发光竖条映射 Twilight。
- Modify `Argo/UI/Sidebar/WorkspaceSidebarView.swift`：搜索框 `❯` prompt、footer、row hover / selected、badge / pin token，不改变 `NSOutlineView` delegate/data source。
- Modify `Argo/UI/Workspace/WorkspaceDetailView.swift`：terminal surface 左浓右淡 scrim、地平线 glow、单层 blur 约束。
- Modify `Argo/UI/Workspace/TerminalLocalChrome.swift`：category pill 使用 `❯` 前缀和 Twilight glass card 样式，不恢复 pane 内旧 header。
- Modify `Argo/UI/Workspace/TerminalPaneView.swift`：pane search 和 status strip 使用 Twilight token，保持 Ghostty host / search 生命周期不变。
- Modify `Argo/UI/Sheets/SettingsSheet.swift`：新增 Twilight 开关、预设 swatches、hex 输入校验、terminal sample 和 16 色 preview；关闭 Twilight 时展示现有 Ghostty theme picker。
- Modify `Argo/Support/L10n.swift`：新增 Twilight settings 文案中英文 key。
- Modify `Tests/ArgoGhosttyConfigTests.swift`、`Tests/ArgoChromeTintTests.swift`、`Tests/WorkspaceStoreTests.swift`、`Tests/WorkspaceTabsTests.swift`、`Tests/LocalizationManagerTests.swift`：覆盖配置输出、token 桥接、settings 保存、结构约束和文案。

---

### Task 1: Twilight Theme Engine

**Files:**
- Create: `Argo/Support/TwilightTheme.swift`
- Create: `Tests/TwilightThemeTests.swift`

**Interfaces:**
- Produces: `struct TwilightTheme: Equatable`
- Produces: `struct TwilightGhosttyTheme: Equatable`
- Produces: `struct TwilightWallpaper: Equatable`
- Produces: `struct TwilightHSLColor: Equatable`
- Produces: `static func TwilightTheme.generate(seed: String) -> TwilightTheme`
- Produces: `static func TwilightTheme.normalizedSeedHex(_ seed: String?) -> String`
- Produces: `static let TwilightTheme.defaultSeedHex: String`
- Produces: `static let TwilightTheme.presets: [TwilightTheme.Preset]`
- Later tasks consume `theme.ghostty.background`, `theme.ghostty.foreground`, `theme.ghostty.palette`, `theme.wallpaper`, `theme.amber`, `theme.amber2`, `theme.cyan`, `theme.green`, `theme.magenta`.

- [ ] **Step 1: Write failing tests for default Twilight output**

Add this file:

```swift
// Tests/TwilightThemeTests.swift
import XCTest
@testable import Argo

final class TwilightThemeTests: XCTestCase {
    func testDefaultSeedMatchesReferenceWarpTheme() {
        let theme = TwilightTheme.generate(seed: "#ffb066")

        XCTAssertEqual(theme.seedHex, "#ffb066")
        XCTAssertEqual(theme.ghostty.accent, "#fcb069")
        XCTAssertEqual(theme.ghostty.background, "#140d21")
        XCTAssertEqual(theme.ghostty.foreground, "#f2f0ee")
        XCTAssertEqual(theme.ghostty.palette[0], "#251c40")
        XCTAssertEqual(theme.ghostty.palette[1], "#eb605c")
        XCTAssertEqual(theme.ghostty.palette[2], "#37e646")
        XCTAssertEqual(theme.ghostty.palette[3], "#fcb069")
        XCTAssertEqual(theme.ghostty.palette[4], "#5c70eb")
        XCTAssertEqual(theme.ghostty.palette[5], "#ed6ecd")
        XCTAssertEqual(theme.ghostty.palette[6], "#53eac0")
        XCTAssertEqual(theme.ghostty.palette[7], "#d6d1cd")
        XCTAssertEqual(theme.ghostty.palette[8], "#584983")
        XCTAssertEqual(theme.ghostty.palette[9], "#f08c89")
        XCTAssertEqual(theme.ghostty.palette[10], "#69ec74")
        XCTAssertEqual(theme.ghostty.palette[11], "#f9d8b9")
        XCTAssertEqual(theme.ghostty.palette[12], "#8998f0")
        XCTAssertEqual(theme.ghostty.palette[13], "#f39bdd")
        XCTAssertEqual(theme.ghostty.palette[14], "#80efd1")
        XCTAssertEqual(theme.ghostty.palette[15], "#f6f5f4")
    }

    func testPresetsAreStableAndGenerateThemes() {
        XCTAssertEqual(TwilightTheme.presets.map(\.seedHex), [
            "#ffb066",
            "#7af0c0",
            "#5cc8ff",
            "#ff9ec4",
            "#ff7a59",
        ])

        for preset in TwilightTheme.presets {
            let theme = TwilightTheme.generate(seed: preset.seedHex)
            XCTAssertEqual(theme.seedHex, preset.seedHex)
            XCTAssertEqual(theme.ghostty.palette.count, 16)
            XCTAssertTrue(theme.ghostty.palette.allSatisfy { $0.value.hasPrefix("#") && $0.value.count == 7 })
            XCTAssertGreaterThanOrEqual(theme.amber.lightness, 58, preset.seedHex)
            XCTAssertLessThanOrEqual(theme.amber.lightness, 70, preset.seedHex)
            XCTAssertGreaterThanOrEqual(theme.amber2.lightness, 72, preset.seedHex)
            XCTAssertLessThanOrEqual(theme.amber2.lightness, 86, preset.seedHex)
        }
    }

    func testSeedNormalizationSupportsShortHexAndFallback() {
        XCTAssertEqual(TwilightTheme.normalizedSeedHex("#abc"), "#aabbcc")
        XCTAssertEqual(TwilightTheme.normalizedSeedHex("ABCDEF"), "#abcdef")
        XCTAssertEqual(TwilightTheme.normalizedSeedHex("  #5cc8ff  "), "#5cc8ff")
        XCTAssertEqual(TwilightTheme.normalizedSeedHex("not-a-color"), TwilightTheme.defaultSeedHex)
        XCTAssertEqual(TwilightTheme.generate(seed: "not-a-color").seedHex, TwilightTheme.defaultSeedHex)
    }

    func testAnsiSemanticHuesStayRecognizableAcrossExtremeSeeds() {
        for seed in ["#333333", "#ff0000", "#5cc8ff", "#7af0c0"] {
            let theme = TwilightTheme.generate(seed: seed)

            XCTAssertTrue((330...360).contains(theme.ghostty.normal.red.hue) || (0...28).contains(theme.ghostty.normal.red.hue), seed)
            XCTAssertTrue((108...166).contains(theme.ghostty.normal.green.hue), seed)
            XCTAssertTrue((188...234).contains(theme.ghostty.normal.blue.hue), seed)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/TwilightThemeTests test
```

Expected: FAIL with `cannot find 'TwilightTheme' in scope`.

- [ ] **Step 3: Add the theme engine**

Create `Argo/Support/TwilightTheme.swift` with this implementation:

```swift
import AppKit
import SwiftUI

struct TwilightTheme: Equatable {
    struct Preset: Identifiable, Equatable {
        let id: String
        let nameKey: String
        let seedHex: String
    }

    static let defaultSeedHex = "#ffb066"
    static let presets: [Preset] = [
        Preset(id: "twilight", nameKey: "settings.twilight.preset.twilight", seedHex: "#ffb066"),
        Preset(id: "aurora", nameKey: "settings.twilight.preset.aurora", seedHex: "#7af0c0"),
        Preset(id: "abyss", nameKey: "settings.twilight.preset.abyss", seedHex: "#5cc8ff"),
        Preset(id: "sakura", nameKey: "settings.twilight.preset.sakura", seedHex: "#ff9ec4"),
        Preset(id: "ember", nameKey: "settings.twilight.preset.ember", seedHex: "#ff7a59"),
    ]

    let seedHex: String
    let amber: TwilightHSLColor
    let amber2: TwilightHSLColor
    let cyan: TwilightHSLColor
    let green: TwilightHSLColor
    let magenta: TwilightHSLColor
    let wallpaper: TwilightWallpaper
    let ghostty: TwilightGhosttyTheme

    static var `default`: TwilightTheme {
        generate(seed: defaultSeedHex)
    }

    static func generate(seed: String) -> TwilightTheme {
        let normalizedSeed = normalizedSeedHex(seed)
        let source = TwilightHSLColor.hexToHSL(normalizedSeed)
        let h = source.hue
        let s = source.saturation
        let l = source.lightness
        let S = clamp(s, 42, 96)

        let amber = TwilightHSLColor(hue: h, saturation: S, lightness: clamp(l, 58, 70))
        let amber2 = TwilightHSLColor(hue: h, saturation: clamp(S - 12, 40, 88), lightness: clamp(l + 15, 72, 86))
        let cyan = TwilightHSLColor(hue: h + 168, saturation: clamp(S - 6, 46, 82), lightness: 70)
        let green = TwilightHSLColor(hue: h + 96, saturation: clamp(S - 12, 40, 76), lightness: 69)
        let magenta = TwilightHSLColor(hue: h - 46, saturation: clamp(S - 4, 46, 82), lightness: 72)

        let skyH = lerpHue(h, 250, 0.72)
        let waterH = lerpHue(h, 218, 0.78)
        let sunS = clamp(S + 4, 55, 98)

        let wallpaper = TwilightWallpaper(
            sunCore: TwilightRadialStop(
                widthPercent: 28,
                heightPercent: 36,
                centerXPercent: 82,
                centerYPercent: 64,
                color: TwilightHSLColor(hue: h, saturation: clamp(S - 18, 30, 70), lightness: 92),
                alpha: 0.95,
                transparentStop: 0.62
            ),
            sunGlow: TwilightRadialStop(
                widthPercent: 72,
                heightPercent: 58,
                centerXPercent: 84,
                centerYPercent: 66,
                color: TwilightHSLColor(hue: h, saturation: sunS, lightness: 62),
                alpha: 0.72,
                transparentStop: 0.68
            ),
            skyWaterStops: [
                TwilightLinearStop(color: TwilightHSLColor(hue: skyH, saturation: clamp(S * 0.5, 18, 55), lightness: 16), location: 0),
                TwilightLinearStop(color: TwilightHSLColor(hue: skyH - 12, saturation: clamp(S * 0.55, 20, 58), lightness: 24), location: 0.20),
                TwilightLinearStop(color: TwilightHSLColor(hue: lerpHue(h, skyH, 0.5), saturation: clamp(S * 0.6, 28, 66), lightness: 40), location: 0.40),
                TwilightLinearStop(color: TwilightHSLColor(hue: h, saturation: clamp(sunS * 0.82, 45, 92), lightness: 54), location: 0.56),
                TwilightLinearStop(color: TwilightHSLColor(hue: lerpHue(h, waterH, 0.5), saturation: clamp(S * 0.55, 26, 64), lightness: 38), location: 0.64),
                TwilightLinearStop(color: TwilightHSLColor(hue: waterH, saturation: clamp(S * 0.5, 24, 58), lightness: 26), location: 0.76),
                TwilightLinearStop(color: TwilightHSLColor(hue: waterH + 4, saturation: clamp(S * 0.52, 24, 60), lightness: 18), location: 0.88),
                TwilightLinearStop(color: TwilightHSLColor(hue: waterH + 6, saturation: clamp(S * 0.5, 22, 58), lightness: 12), location: 1),
            ]
        )

        let tint: (Double, Double) -> Double = { anchor, t in lerpHue(anchor, h, t) }
        let TS = clamp(S - 6, 48, 78)
        let normal = TwilightGhosttyTheme.SemanticColors(
            black: TwilightHSLColor(hue: waterH, saturation: clamp(S * 0.4, 14, 40), lightness: 18),
            red: TwilightHSLColor(hue: tint(358, 0.12), saturation: TS, lightness: 64),
            green: TwilightHSLColor(hue: tint(138, 0.12), saturation: TS, lightness: 56),
            yellow: amber,
            blue: TwilightHSLColor(hue: tint(210, 0.12), saturation: TS, lightness: 64),
            magenta: TwilightHSLColor(hue: tint(305, 0.12), saturation: TS, lightness: 68),
            cyan: TwilightHSLColor(hue: tint(182, 0.12), saturation: TS, lightness: 62),
            white: TwilightHSLColor(hue: h, saturation: 10, lightness: 82)
        )
        let bright = TwilightGhosttyTheme.SemanticColors(
            black: TwilightHSLColor(hue: waterH, saturation: clamp(S * 0.3, 10, 34), lightness: 40),
            red: TwilightHSLColor(hue: tint(358, 0.12), saturation: TS, lightness: 74),
            green: TwilightHSLColor(hue: tint(138, 0.12), saturation: TS, lightness: 67),
            yellow: amber2,
            blue: TwilightHSLColor(hue: tint(210, 0.12), saturation: TS, lightness: 74),
            magenta: TwilightHSLColor(hue: tint(305, 0.12), saturation: TS, lightness: 78),
            cyan: TwilightHSLColor(hue: tint(182, 0.12), saturation: TS, lightness: 72),
            white: TwilightHSLColor(hue: h, saturation: 8, lightness: 96)
        )

        return TwilightTheme(
            seedHex: normalizedSeed,
            amber: amber,
            amber2: amber2,
            cyan: cyan,
            green: green,
            magenta: magenta,
            wallpaper: wallpaper,
            ghostty: TwilightGhosttyTheme(
                accentColor: amber,
                backgroundColor: TwilightHSLColor(hue: waterH + 4, saturation: clamp(S * 0.45, 18, 46), lightness: 9),
                foregroundColor: TwilightHSLColor(hue: h, saturation: 12, lightness: 94),
                normal: normal,
                bright: bright
            )
        )
    }

    static func normalizedSeedHex(_ seed: String?) -> String {
        guard var hex = seed?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !hex.isEmpty else {
            return defaultSeedHex
        }
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        guard hex.count == 6, UInt64(hex, radix: 16) != nil else {
            return defaultSeedHex
        }
        return "#\(hex)"
    }

    static func isValidSeedHex(_ seed: String) -> Bool {
        normalizedSeedHex(seed) == seed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            || normalizedSeedHex(seed) != defaultSeedHex
            || seed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == defaultSeedHex
    }

    static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        max(lower, min(upper, value))
    }

    static func lerpHue(_ a: Double, _ b: Double, _ t: Double) -> Double {
        let d = (b - a + 540).truncatingRemainder(dividingBy: 360) - 180
        return a + d * t
    }
}

struct TwilightHSLColor: Equatable {
    let hue: Double
    let saturation: Double
    let lightness: Double

    var normalizedHue: Double {
        let value = hue.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    var hex: String {
        Self.hslToHex(hue: hue, saturation: saturation, lightness: lightness)
    }

    var color: Color {
        Color(nsColor: nsColor)
    }

    var nsColor: NSColor {
        let rgb = Self.hslToRGB(hue: hue, saturation: saturation, lightness: lightness)
        return NSColor(calibratedRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }

    func color(alpha: Double) -> Color {
        color.opacity(alpha)
    }

    static func hexToHSL(_ hex: String) -> TwilightHSLColor {
        let normalized = TwilightTheme.normalizedSeedHex(hex).dropFirst()
        let value = UInt64(normalized, radix: 16)!
        let r = Double((value >> 16) & 0xff) / 255
        let g = Double((value >> 8) & 0xff) / 255
        let b = Double(value & 0xff) / 255
        let maxComponent = max(r, g, b)
        let minComponent = min(r, g, b)
        let delta = maxComponent - minComponent
        var hue = 0.0
        if delta != 0 {
            if maxComponent == r {
                hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxComponent == g {
                hue = (b - r) / delta + 2
            } else {
                hue = (r - g) / delta + 4
            }
            hue *= 60
            if hue < 0 { hue += 360 }
        }
        let lightness = (maxComponent + minComponent) / 2
        let saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))
        return TwilightHSLColor(hue: hue, saturation: saturation * 100, lightness: lightness * 100)
    }

    static func hslToHex(hue: Double, saturation: Double, lightness: Double) -> String {
        let rgb = hslToRGB(hue: hue, saturation: saturation, lightness: lightness)
        let r = Int((rgb.red * 255).rounded())
        let g = Int((rgb.green * 255).rounded())
        let b = Int((rgb.blue * 255).rounded())
        return String(format: "#%02x%02x%02x", r, g, b)
    }

    static func hslToRGB(hue: Double, saturation: Double, lightness: Double) -> (red: Double, green: Double, blue: Double) {
        let h = {
            let value = hue.truncatingRemainder(dividingBy: 360)
            return value < 0 ? value + 360 : value
        }()
        let s = TwilightTheme.clamp(saturation, 0, 100) / 100
        let l = TwilightTheme.clamp(lightness, 0, 100) / 100
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        let rgb: (Double, Double, Double)
        switch h {
        case 0..<60: rgb = (c, x, 0)
        case 60..<120: rgb = (x, c, 0)
        case 120..<180: rgb = (0, c, x)
        case 180..<240: rgb = (0, x, c)
        case 240..<300: rgb = (x, 0, c)
        default: rgb = (c, 0, x)
        }
        return (rgb.0 + m, rgb.1 + m, rgb.2 + m)
    }
}

struct TwilightLinearStop: Equatable {
    let color: TwilightHSLColor
    let location: Double
}

struct TwilightRadialStop: Equatable {
    let widthPercent: Double
    let heightPercent: Double
    let centerXPercent: Double
    let centerYPercent: Double
    let color: TwilightHSLColor
    let alpha: Double
    let transparentStop: Double
}

struct TwilightWallpaper: Equatable {
    let sunCore: TwilightRadialStop
    let sunGlow: TwilightRadialStop
    let skyWaterStops: [TwilightLinearStop]
}

struct TwilightGhosttyTheme: Equatable {
    struct SemanticColors: Equatable {
        let black: TwilightHSLColor
        let red: TwilightHSLColor
        let green: TwilightHSLColor
        let yellow: TwilightHSLColor
        let blue: TwilightHSLColor
        let magenta: TwilightHSLColor
        let cyan: TwilightHSLColor
        let white: TwilightHSLColor

        var ordered: [TwilightHSLColor] {
            [black, red, green, yellow, blue, magenta, cyan, white]
        }
    }

    let accentColor: TwilightHSLColor
    let backgroundColor: TwilightHSLColor
    let foregroundColor: TwilightHSLColor
    let normal: SemanticColors
    let bright: SemanticColors

    var accent: String { accentColor.hex }
    var background: String { backgroundColor.hex }
    var foreground: String { foregroundColor.hex }
    var palette: [Int: String] {
        Dictionary(uniqueKeysWithValues: (normal.ordered + bright.ordered).enumerated().map { ($0.offset, $0.element.hex) })
    }

    var paletteLines: [String] {
        (0...15).compactMap { index in
            palette[index].map { "palette = \(index)=\($0)" }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/TwilightThemeTests test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Argo/Support/TwilightTheme.swift Tests/TwilightThemeTests.swift
git commit -m "feat(theme): add engine"
```

---

### Task 2: Twilight Settings Model

**Files:**
- Modify: `Argo/Domain/AppSettings.swift`
- Modify: `Argo/App/WorkspaceStore.swift`
- Modify: `Tests/WorkspaceStoreTests.swift`

**Interfaces:**
- Consumes: `TwilightTheme.defaultSeedHex`
- Produces: `AppSettings.twilightThemeEnabled: Bool`
- Produces: `AppSettings.twilightThemeSeedHex: String`
- Produces: `WorkspaceStore.currentTwilightTheme: TwilightTheme`
- Later tasks consume `store.currentTwilightTheme` and `settings.twilightThemeEnabled`.

- [ ] **Step 1: Write failing settings tests**

Append tests to `Tests/WorkspaceStoreTests.swift`:

```swift
func testDefaultAppSettingsEnableTwilightTheme() {
    let settings = AppSettings()

    XCTAssertTrue(settings.twilightThemeEnabled)
    XCTAssertEqual(settings.twilightThemeSeedHex, "#ffb066")
}

func testAppSettingsNormalizeInvalidTwilightSeed() {
    let settings = AppSettings(twilightThemeSeedHex: "not-a-color")

    XCTAssertEqual(settings.twilightThemeSeedHex, TwilightTheme.defaultSeedHex)
}

func testDecodedLegacySettingsUseTwilightDefaults() throws {
    let json = #"{"uiScale":1.1}"#.data(using: .utf8)!

    let settings = try JSONDecoder().decode(AppSettings.self, from: json)

    XCTAssertTrue(settings.twilightThemeEnabled)
    XCTAssertEqual(settings.twilightThemeSeedHex, TwilightTheme.defaultSeedHex)
}

func testUpdateAppSettingsPreservesTwilightSettings() {
    let store = WorkspaceStore(persistsWorkspaceState: false)

    store.updateAppSettings(
        AppSettings(
            twilightThemeEnabled: false,
            twilightThemeSeedHex: "#5cc8ff"
        )
    )

    XCTAssertFalse(store.appSettings.twilightThemeEnabled)
    XCTAssertEqual(store.appSettings.twilightThemeSeedHex, "#5cc8ff")
    XCTAssertEqual(store.currentTwilightTheme.seedHex, "#5cc8ff")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceStoreTests test
```

Expected: FAIL with missing `twilightThemeEnabled`, `twilightThemeSeedHex`, or `currentTwilightTheme`.

- [ ] **Step 3: Add settings fields and migration**

In `AppSettings`, add stored properties after `terminalTheme`:

```swift
var twilightThemeEnabled: Bool
var twilightThemeSeedHex: String
```

Update the initializer signature near `terminalTheme`:

```swift
terminalTheme: String? = nil,
twilightThemeEnabled: Bool = true,
twilightThemeSeedHex: String = TwilightTheme.defaultSeedHex,
terminalScrollbackLines: Int? = nil,
```

Assign values after `terminalTheme` normalization:

```swift
self.twilightThemeEnabled = twilightThemeEnabled
self.twilightThemeSeedHex = TwilightTheme.normalizedSeedHex(twilightThemeSeedHex)
```

Add coding keys after `terminalTheme`:

```swift
case twilightThemeEnabled
case twilightThemeSeedHex
```

Decode Twilight values before `self.init(...)`:

```swift
let decodedTwilightThemeEnabled = try container.decodeIfPresent(Bool.self, forKey: .twilightThemeEnabled)
let decodedTwilightThemeSeedHex = try container.decodeIfPresent(String.self, forKey: .twilightThemeSeedHex)
```

Pass decoded values in `init(from:)` after `terminalTheme`:

```swift
twilightThemeEnabled: decodedTwilightThemeEnabled == nil ? true : decodedTwilightThemeEnabled!,
twilightThemeSeedHex: decodedTwilightThemeSeedHex == nil ? TwilightTheme.defaultSeedHex : decodedTwilightThemeSeedHex!,
```

- [ ] **Step 4: Preserve settings through WorkspaceStore**

In `WorkspaceStore.updateAppSettings(_:)`, pass the fields immediately after `terminalTheme`:

```swift
terminalTheme: settings.terminalTheme,
twilightThemeEnabled: settings.twilightThemeEnabled,
twilightThemeSeedHex: settings.twilightThemeSeedHex,
terminalScrollbackLines: settings.terminalScrollbackLines,
```

Add a computed property near other app settings helpers:

```swift
var currentTwilightTheme: TwilightTheme {
    TwilightTheme.generate(seed: appSettings.twilightThemeSeedHex)
}
```

- [ ] **Step 5: Run test to verify it passes**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceStoreTests test
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Argo/Domain/AppSettings.swift Argo/App/WorkspaceStore.swift Tests/WorkspaceStoreTests.swift
git commit -m "feat(settings): add twilight"
```

---

### Task 3: Ghostty Managed Config

**Files:**
- Modify: `Argo/Services/Terminal/Ghostty/ArgoGhosttyConfig.swift`
- Modify: `Tests/ArgoGhosttyConfigTests.swift`

**Interfaces:**
- Consumes: `AppSettings.twilightThemeEnabled`
- Consumes: `TwilightTheme.generate(seed:)`
- Produces: Ghostty config lines `background = #...`, `foreground = #...`, `palette = 0=#...` through `palette = 15=#...`.

- [ ] **Step 1: Write failing Ghostty config tests**

Add tests to `Tests/ArgoGhosttyConfigTests.swift`:

```swift
func testManagedConfigContentsUseTwilightThemeByDefault() {
    let contents = ArgoGhosttyConfigManager.managedConfigContents(settings: AppSettings())

    XCTAssertTrue(contents.contains("background = #140d21"))
    XCTAssertTrue(contents.contains("foreground = #f2f0ee"))
    XCTAssertTrue(contents.contains("palette = 0=#251c40"))
    XCTAssertTrue(contents.contains("palette = 15=#f6f5f4"))
    XCTAssertFalse(contents.contains("theme = "))
}

func testManagedConfigContentsIgnoreGhosttyThemeWhenTwilightIsEnabled() {
    let contents = ArgoGhosttyConfigManager.managedConfigContents(
        settings: AppSettings(
            terminalTheme: "Catppuccin Mocha",
            twilightThemeEnabled: true,
            twilightThemeSeedHex: "#ffb066"
        )
    )

    XCTAssertTrue(contents.contains("# theme: Twilight #ffb066"))
    XCTAssertTrue(contents.contains("background = #140d21"))
    XCTAssertFalse(contents.contains("theme = Catppuccin Mocha"))
}

func testManagedConfigContentsKeepGhosttyThemeWhenTwilightIsDisabled() {
    let contents = ArgoGhosttyConfigManager.managedConfigContents(
        settings: AppSettings(
            terminalTheme: "Catppuccin Mocha",
            twilightThemeEnabled: false
        )
    )

    XCTAssertFalse(contents.contains("# theme: Twilight"))
    XCTAssertTrue(contents.contains("Catppuccin Mocha"))
}

func testManagedConfigContentsKeepOpacityAndBlurWithTwilight() {
    let contents = ArgoGhosttyConfigManager.managedConfigContents(
        settings: AppSettings(
            twilightThemeEnabled: true,
            terminalBackgroundOpacity: 0.65,
            terminalBackgroundBlur: true
        )
    )

    XCTAssertTrue(contents.contains("background-opacity = 0.65"))
    XCTAssertTrue(contents.contains("background-blur = true"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/ArgoGhosttyConfigTests test
```

Expected: FAIL because Twilight colors are not emitted.

- [ ] **Step 3: Add Twilight config output**

Replace the existing `if let themeName = settings.terminalTheme { ... }` block in `managedConfigContents(settings:)` with:

```swift
if settings.twilightThemeEnabled {
    let theme = TwilightTheme.generate(seed: settings.twilightThemeSeedHex)
    lines.append("# theme: Twilight \(theme.seedHex)")
    lines.append("background = \(theme.ghostty.background)")
    lines.append("foreground = \(theme.ghostty.foreground)")
    lines.append(contentsOf: theme.ghostty.paletteLines)
} else if let themeName = settings.terminalTheme {
    if let themeContents = readThemeFileContents(named: themeName) {
        lines.append("# theme: \(themeName)")
        lines.append(themeContents)
    } else {
        lines.append("theme = \(themeName)")
    }
}
```

Keep the font, scrollback, opacity and blur block exactly after this color block.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/ArgoGhosttyConfigTests test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Argo/Services/Terminal/Ghostty/ArgoGhosttyConfig.swift Tests/ArgoGhosttyConfigTests.swift
git commit -m "feat(ghostty): use twilight"
```

---

### Task 4: Theme Token Bridge

**Files:**
- Modify: `Argo/Support/ArgoTheme.swift`
- Modify: `Argo/Support/ArgoChromeTint.swift`
- Modify: `Tests/ArgoChromeTintTests.swift`

**Interfaces:**
- Consumes: `TwilightTheme.default`
- Produces: static tokens `ArgoTheme.twilightDefault`, `topGlass`, `glassRail`, `glassSide`, `glassCard`, `glassCardH`, `scrimStrong`, `scrimSoft`, `amber`, `amber2`, `cyan`, `green`, `magenta`.
- Produces: `ArgoChromeTint.resolved(for theme: TwilightTheme) -> ArgoChromeTint`

- [ ] **Step 1: Write failing token bridge tests**

Append tests to `Tests/ArgoChromeTintTests.swift`:

```swift
func testTwilightChromeTintUsesSeedAccent() {
    let theme = TwilightTheme.generate(seed: "#ffb066")
    let tint = ArgoChromeTint.resolved(for: theme)

    XCTAssertEqual(tint.components.hexString, "#fcb069")
    XCTAssertFalse(tint.isNeutral)
    XCTAssertEqual(tint.topFill.alpha, 0.34, accuracy: 0.0001)
    XCTAssertEqual(tint.leadingFill.alpha, 0.38, accuracy: 0.0001)
    XCTAssertEqual(tint.sidebarFill.alpha, 0.42, accuracy: 0.0001)
}

func testTwilightStaticThemeTokensUseReferenceColors() {
    XCTAssertEqual(ArgoTheme.twilightDefault.seedHex, "#ffb066")
    XCTAssertEqual(ArgoTheme.accentHexForTests, "#fcb069")
    XCTAssertEqual(ArgoTheme.localAccentHexForTests, "#53eac0")
}
```

Add this helper in `ArgoChromeTint.Components` for testable comparison:

```swift
var hexString: String {
    let r = Int((red * 255).rounded())
    let g = Int((green * 255).rounded())
    let b = Int((blue * 255).rounded())
    return String(format: "#%02x%02x%02x", r, g, b)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/ArgoChromeTintTests test
```

Expected: FAIL because the Twilight token APIs do not exist yet.

- [ ] **Step 3: Map ArgoTheme to Twilight default**

At the top of `ArgoTheme`, add:

```swift
static let twilightDefault = TwilightTheme.default
static let amber = twilightDefault.amber.color
static let amber2 = twilightDefault.amber2.color
static let cyan = twilightDefault.cyan.color
static let green = twilightDefault.green.color
static let magenta = twilightDefault.magenta.color
static let text = Color(nsColor: NSColor(calibratedRed: 0.953, green: 0.961, blue: 0.984, alpha: 1))
static let textDim = Color(nsColor: NSColor(calibratedRed: 0.784, green: 0.812, blue: 0.875, alpha: 1))
static let textFaint = Color(nsColor: NSColor(calibratedRed: 0.588, green: 0.616, blue: 0.698, alpha: 1))
static let glassSide = Color(nsColor: NSColor(calibratedRed: 0.063, green: 0.086, blue: 0.133, alpha: 0.42))
static let glassRail = Color(nsColor: NSColor(calibratedRed: 0.039, green: 0.055, blue: 0.086, alpha: 0.38))
static let glassCard = Color(nsColor: NSColor(calibratedRed: 0.141, green: 0.180, blue: 0.267, alpha: 0.42))
static let glassCardH = Color(nsColor: NSColor(calibratedRed: 0.188, green: 0.243, blue: 0.353, alpha: 0.50))
static let topGlass = Color(nsColor: NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.114, alpha: 0.34))
static let hairline = Color.white.opacity(0.10)
static let hairlineSoft = Color.white.opacity(0.06)
static let scrimStrong = Color(nsColor: NSColor(calibratedRed: 0.031, green: 0.043, blue: 0.071, alpha: 0.62))
static let scrimSoft = Color(nsColor: NSColor(calibratedRed: 0.031, green: 0.043, blue: 0.071, alpha: 0.22))
```

Then update existing aliases:

```swift
static let border = hairline.opacity(0.85)
static let strongBorder = Color.white.opacity(0.16)
static let accent = amber
static let accentMuted = amber.opacity(0.24)
static let localAccent = cyan
static let success = green
static let warning = amber2
static let danger = Color(nsColor: NSColor(calibratedRed: 0.92, green: 0.38, blue: 0.36, alpha: 1))
static let mutedText = textFaint
static let secondaryText = textDim
static let tertiaryText = text
static let subtleFill = glassCard.opacity(0.75)
static let subtleRaisedFill = glassCardH.opacity(0.80)
```

Add test-only hex helpers in `ArgoTheme`:

```swift
static var accentHexForTests: String { twilightDefault.ghostty.accent }
static var localAccentHexForTests: String { twilightDefault.ghostty.palette[6]! }
```

- [ ] **Step 4: Add Twilight chrome tint resolver**

Add to `ArgoChromeTint`:

```swift
static let twilightStrength = Strength(
    top: 0.34,
    leading: 0.38,
    sidebar: 0.42,
    tabBar: 0.34,
    selection: 0.50,
    glow: 0.22
)

static func resolved(for theme: TwilightTheme) -> ArgoChromeTint {
    ArgoChromeTint(
        components: Components(color: theme.amber.color),
        strength: twilightStrength,
        isNeutral: false
    )
}
```

Keep `resolved(for palette:)` unchanged so non-Twilight paths and existing tests still pass.

- [ ] **Step 5: Run test to verify it passes**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/ArgoChromeTintTests test
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Argo/Support/ArgoTheme.swift Argo/Support/ArgoChromeTint.swift Tests/ArgoChromeTintTests.swift
git commit -m "feat(theme): bridge tokens"
```

---

### Task 5: Main Workspace Chrome And Sidebar

**Files:**
- Create: `Argo/UI/Components/TwilightWallpaperView.swift`
- Modify: `Argo/UI/MainWindowView.swift`
- Modify: `Argo/UI/Components/GlobalModeRailView.swift`
- Modify: `Argo/UI/Sidebar/WorkspaceSidebarView.swift`
- Modify: `Tests/WorkspaceTabsTests.swift`

**Interfaces:**
- Consumes: `store.currentTwilightTheme`
- Consumes: `ArgoChromeTint.resolved(for: TwilightTheme)`
- Produces: `TwilightWallpaperView(theme:)`
- Produces: sidebar search prompt `Text("❯")`

- [ ] **Step 1: Write failing structure tests**

Add tests to `Tests/WorkspaceTabsTests.swift`:

```swift
func testWorkspaceModePaintsTwilightWallpaperBehindChrome() throws {
    let rootURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let mainWindowSource = try String(contentsOf: rootURL.appendingPathComponent("Argo/UI/MainWindowView.swift"), encoding: .utf8)
    let wallpaperSource = try String(contentsOf: rootURL.appendingPathComponent("Argo/UI/Components/TwilightWallpaperView.swift"), encoding: .utf8)

    XCTAssertTrue(mainWindowSource.contains("TwilightWallpaperView(theme: store.currentTwilightTheme)"))
    XCTAssertTrue(mainWindowSource.contains("ArgoChromeTint.resolved(for: store.currentTwilightTheme)"))
    XCTAssertTrue(wallpaperSource.contains("RadialGradient"))
    XCTAssertTrue(wallpaperSource.contains("LinearGradient"))
    XCTAssertTrue(wallpaperSource.contains("center: UnitPoint(x: 0.82, y: 0.64)"))
}

func testSidebarUsesTwilightPromptAndSingleOuterSurface() throws {
    let rootURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let sidebarSource = try String(contentsOf: rootURL.appendingPathComponent("Argo/UI/Sidebar/WorkspaceSidebarView.swift"), encoding: .utf8)
    let mainWindowSource = try String(contentsOf: rootURL.appendingPathComponent("Argo/UI/MainWindowView.swift"), encoding: .utf8)

    XCTAssertTrue(sidebarSource.contains("Text(\"❯\")"))
    XCTAssertFalse(sidebarSource.contains("Image(systemName: \"magnifyingglass\")"))
    XCTAssertTrue(mainWindowSource.contains("ArgoTheme.glassSide"))
    XCTAssertFalse(sidebarSource.contains("ArgoTheme.sidebarBackground, in: RoundedRectangle"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceTabsTests test
```

Expected: FAIL because wallpaper and prompt mapping are not implemented.

- [ ] **Step 3: Add SwiftUI wallpaper view**

Create `Argo/UI/Components/TwilightWallpaperView.swift`:

```swift
import SwiftUI

struct TwilightWallpaperView: View {
    let theme: TwilightTheme

    var body: some View {
        ZStack {
            LinearGradient(
                stops: theme.wallpaper.skyWaterStops.map {
                    Gradient.Stop(color: $0.color.color, location: $0.location)
                },
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                stops: [
                    .init(color: theme.wallpaper.sunGlow.color.color(alpha: theme.wallpaper.sunGlow.alpha), location: 0),
                    .init(color: .clear, location: theme.wallpaper.sunGlow.transparentStop),
                ],
                center: UnitPoint(x: 0.84, y: 0.66),
                startRadius: 0,
                endRadius: 520
            )

            RadialGradient(
                stops: [
                    .init(color: theme.wallpaper.sunCore.color.color(alpha: theme.wallpaper.sunCore.alpha), location: 0),
                    .init(color: .clear, location: theme.wallpaper.sunCore.transparentStop),
                ],
                center: UnitPoint(x: 0.82, y: 0.64),
                startRadius: 0,
                endRadius: 210
            )

            LinearGradient(
                colors: [.clear, Color.white.opacity(0.06), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .mask(alignment: .top) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle().frame(height: 28)
                    Spacer(minLength: 0)
                }
            }
        }
        .ignoresSafeArea()
    }
}
```

- [ ] **Step 4: Wire workspace mode to Twilight theme**

In `MainWindowView`, add:

```swift
private var activeChromeTint: ArgoChromeTint {
    store.appSettings.twilightThemeEnabled
        ? ArgoChromeTint.resolved(for: store.currentTwilightTheme)
        : store.chromeTint
}
```

Use `activeChromeTint` for top chrome, rail, sidebar surface, and terminal detail calls in this file. In the root `ZStack`, place wallpaper below the existing `VStack`:

```swift
if store.mainWindowMode == .workspace, store.appSettings.twilightThemeEnabled {
    TwilightWallpaperView(theme: store.currentTwilightTheme)
        .transition(.opacity)
}
```

Keep:

```swift
.background(windowContentBackground)
```

so non-workspace modes and non-translucent states keep existing behavior.

- [ ] **Step 5: Update top chrome and rail visual tokens**

In `TopChromeSurfaceBackground`, replace `chromeTint.topChromeSurfaceComponents.color` with:

```swift
ArgoTheme.topGlass
```

In `TimeCommandPaletteButtonLabel.iconColor`, map sunset/default warmth to Twilight:

```swift
private var iconColor: Color {
    switch phase {
    case .morning, .afternoon, .sunset:
        return ArgoTheme.amber
    case .night:
        return ArgoTheme.cyan
    }
}
```

In `GlobalModeRailView`, change background and active indicator:

```swift
.background(ArgoTheme.glassRail)
.overlay(alignment: .leading) {
    if isSelected {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(ArgoTheme.amber)
            .frame(width: 3 * uiScale, height: 20 * uiScale)
            .shadow(color: ArgoTheme.amber.opacity(0.65), radius: 10 * uiScale)
    }
}
```

Keep button actions, accessibility labels and help unchanged.

- [ ] **Step 6: Update sidebar surface and search prompt**

In `FloatingWorkspaceSidebarSurface`, keep one outer panel and use:

```swift
ZStack {
    ArgoTheme.glassSide
    LinearGradient(
        colors: [Color.white.opacity(0.028), Color.clear],
        startPoint: .top,
        endPoint: .bottom
    )
}
```

In `WorkspaceSidebarView` search HStack, replace the magnifying glass with:

```swift
Text("❯")
    .font(.system(size: 14 * uiScale, weight: .semibold, design: .monospaced))
    .foregroundStyle(ArgoTheme.amber)
```

Use search background:

```swift
.background(Color.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 8 * uiScale, style: .continuous))
.overlay(
    RoundedRectangle(cornerRadius: 8 * uiScale, style: .continuous)
        .strokeBorder(ArgoTheme.hairline, lineWidth: 1)
)
```

In `SidebarOutlineRowView.drawSelection`, add the amber active bar:

```swift
let bar = NSBezierPath(roundedRect: NSRect(x: rect.minX, y: rect.minY + 3, width: 3, height: rect.height - 6), xRadius: 1.5, yRadius: 1.5)
NSColor(TwilightTheme.default.amber.color).setFill()
bar.fill()
```

- [ ] **Step 7: Run test to verify it passes**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceTabsTests test
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Argo/UI/Components/TwilightWallpaperView.swift Argo/UI/MainWindowView.swift Argo/UI/Components/GlobalModeRailView.swift Argo/UI/Sidebar/WorkspaceSidebarView.swift Tests/WorkspaceTabsTests.swift
git commit -m "feat(ui): add wallpaper"
```

---

### Task 6: Terminal Surface And Local Chrome

**Files:**
- Modify: `Argo/UI/Workspace/WorkspaceDetailView.swift`
- Modify: `Argo/UI/Workspace/TerminalLocalChrome.swift`
- Modify: `Argo/UI/Workspace/TerminalPaneView.swift`
- Modify: `Tests/WorkspaceTabsTests.swift`

**Interfaces:**
- Consumes: `ArgoTheme.scrimStrong`, `ArgoTheme.scrimSoft`, `ArgoTheme.amber`, `ArgoTheme.amber2`, `ArgoTheme.glassCard`, `ArgoTheme.glassCardH`.
- Preserves: `TerminalLocalChrome` outside each pane, `TerminalHostView`, pane search lifecycle, context menu actions, split actions.

- [ ] **Step 1: Write failing terminal structure tests**

Add tests to `Tests/WorkspaceTabsTests.swift`:

```swift
func testTerminalSurfaceUsesTwilightScrimAndHorizonGlow() throws {
    let rootURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let workspaceDetailSource = try String(contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"), encoding: .utf8)

    XCTAssertTrue(workspaceDetailSource.contains("TwilightTerminalScrim()"))
    XCTAssertTrue(workspaceDetailSource.contains("TwilightHorizonGlow()"))
    XCTAssertTrue(workspaceDetailSource.contains("LinearGradient("))
    XCTAssertTrue(workspaceDetailSource.contains("ArgoTheme.scrimStrong"))
    XCTAssertTrue(workspaceDetailSource.contains("ArgoTheme.scrimSoft"))
    XCTAssertFalse(workspaceDetailSource.contains("Rectangle().fill(.ultraThinMaterial)\n                    Color.black.opacity(opaqueSurfaceScrimOpacity)"))
}

func testTerminalLocalChromeUsesPromptGlyph() throws {
    let rootURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let terminalChromeSource = try String(contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalLocalChrome.swift"), encoding: .utf8)

    XCTAssertTrue(terminalChromeSource.contains("Text(\"❯\")"))
    XCTAssertFalse(terminalChromeSource.contains("Image(systemName: \"chevron.right\")"))
    XCTAssertTrue(terminalChromeSource.contains("ArgoTheme.glassCardH"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceTabsTests test
```

Expected: FAIL because scrim/glow and `❯` terminal chrome are not implemented.

- [ ] **Step 3: Replace terminal surface readability layer**

In `TerminalWorkspaceSurface.body`, keep `TerminalBackgroundBlurView()` only under `if usesBackgroundBlur`. Replace the translucent/opaque overlay section with:

```swift
if !isTranslucent {
    Color.black.opacity(opaqueSurfaceScrimOpacity)
    surfaceFill
}
TwilightTerminalScrim()
chromeTint.glowFill.color
    .opacity(isTranslucent ? translucentGlowOpacity : opaqueGlowOpacity)
TwilightHorizonGlow()
```

Add private views below `TerminalWorkspaceSurface`:

```swift
private struct TwilightTerminalScrim: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: ArgoTheme.scrimStrong, location: 0),
                .init(color: ArgoTheme.scrimStrong, location: 0.14),
                .init(color: ArgoTheme.scrimSoft, location: 0.46),
                .init(color: Color(nsColor: NSColor(calibratedRed: 0.031, green: 0.043, blue: 0.071, alpha: 0.04)), location: 0.74),
                .init(color: .clear, location: 1),
            ],
            startPoint: UnitPoint(x: 0, y: 0.45),
            endPoint: UnitPoint(x: 1, y: 0.55)
        )
        .allowsHitTesting(false)
    }
}

private struct TwilightHorizonGlow: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: ArgoTheme.amber.opacity(0.50), location: 0.55),
                    .init(color: ArgoTheme.amber2.opacity(0.65), location: 0.75),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 2)
        }
        .allowsHitTesting(false)
    }
}
```

- [ ] **Step 4: Update local chrome prompt and pills**

In `TerminalLocalChrome.fallbackCategoryPill` and `TerminalChromeCategoryPill`, replace `Image(systemName: "chevron.right")` with:

```swift
Text("❯")
    .font(.system(size: 12, weight: .semibold, design: .monospaced))
    .foregroundStyle(category.isSelected ? ArgoTheme.amber : ArgoTheme.amber.opacity(0.62))
```

For fallback use:

```swift
Text("❯")
    .font(.system(size: 12, weight: .semibold, design: .monospaced))
    .foregroundStyle(ArgoTheme.amber)
```

Update pill fill helpers:

```swift
private var backgroundFill: Color {
    if category.isSelected {
        return ArgoTheme.glassCardH.opacity(isFocused ? 1 : 0.86)
    }
    return isHovered ? ArgoTheme.glassCard : .clear
}

private var borderColor: Color {
    if category.isSelected {
        return ArgoTheme.hairline
    }
    return isHovered ? ArgoTheme.hairlineSoft : .clear
}
```

Keep rename popover, close button, category selection, split and plus button actions unchanged.

- [ ] **Step 5: Update pane search and status strip token usage**

In `TerminalPaneView`, keep `paneFill` behavior. Change search background from focused pane header colors to:

```swift
.background(ArgoTheme.topGlass)
```

In `PaneSearchBar`, use:

```swift
.background(Color.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
.overlay(
    RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(ArgoTheme.hairline, lineWidth: 1)
)
```

In `PaneStatusStrip` and `PaneTag` tone colors, use `ArgoTheme.cyan`, `ArgoTheme.amber`, `ArgoTheme.green`, and `ArgoTheme.textFaint` while preserving labels and health logic.

- [ ] **Step 6: Run test to verify it passes**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceTabsTests test
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Argo/UI/Workspace/WorkspaceDetailView.swift Argo/UI/Workspace/TerminalLocalChrome.swift Argo/UI/Workspace/TerminalPaneView.swift Tests/WorkspaceTabsTests.swift
git commit -m "feat(ui): style terminal"
```

---

### Task 7: Settings UI And Localization

**Files:**
- Modify: `Argo/UI/Sheets/SettingsSheet.swift`
- Modify: `Argo/Support/L10n.swift`
- Modify: `Tests/LocalizationManagerTests.swift`
- Modify: `Tests/WorkspaceTabsTests.swift`

**Interfaces:**
- Consumes: `TwilightTheme.presets`
- Consumes: `TwilightTheme.generate(seed:)`
- Produces: `TwilightThemePreviewCard`
- Produces: `twilightThemeEnabledBinding`
- Produces: `twilightSeedBinding`

- [ ] **Step 1: Write failing localization and source tests**

Add assertions in `Tests/LocalizationManagerTests.swift`:

```swift
XCTAssertEqual(L10nTable.string(for: "settings.twilight.enabled", language: .english), "Use Twilight theme")
XCTAssertEqual(L10nTable.string(for: "settings.twilight.seed", language: .english), "Seed color")
XCTAssertEqual(L10nTable.string(for: "settings.twilight.enabled", language: .simplifiedChinese), "使用 Twilight 主题")
XCTAssertEqual(L10nTable.string(for: "settings.twilight.seed", language: .simplifiedChinese), "种子颜色")
```

Add a source structure test to `Tests/WorkspaceTabsTests.swift`:

```swift
func testSettingsExposeTwilightControlsBeforeGhosttyThemePicker() throws {
    let rootURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let settingsSource = try String(contentsOf: rootURL.appendingPathComponent("Argo/UI/Sheets/SettingsSheet.swift"), encoding: .utf8)

    XCTAssertTrue(settingsSource.contains("Toggle(localized(\"settings.twilight.enabled\")"))
    XCTAssertTrue(settingsSource.contains("ForEach(TwilightTheme.presets)"))
    XCTAssertTrue(settingsSource.contains("TwilightThemePreviewCard("))
    XCTAssertTrue(settingsSource.contains("if !appSettings.twilightThemeEnabled"))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/LocalizationManagerTests -only-testing:ArgoTests/WorkspaceTabsTests test
```

Expected: FAIL because keys and Settings UI are missing.

- [ ] **Step 3: Add localization keys**

In the English table in `Argo/Support/L10n.swift`, add:

```swift
"settings.twilight.enabled": "Use Twilight theme",
"settings.twilight.description": "Generate Argo chrome, wallpaper, and Ghostty colors from one seed color.",
"settings.twilight.presets": "Presets",
"settings.twilight.seed": "Seed color",
"settings.twilight.invalidSeed": "Use #RGB or #RRGGBB.",
"settings.twilight.preview": "Twilight preview",
"settings.twilight.preset.twilight": "Twilight",
"settings.twilight.preset.aurora": "Aurora",
"settings.twilight.preset.abyss": "Abyss",
"settings.twilight.preset.sakura": "Sakura",
"settings.twilight.preset.ember": "Ember",
```

In the Simplified Chinese table, add:

```swift
"settings.twilight.enabled": "使用 Twilight 主题",
"settings.twilight.description": "用一个种子颜色生成 Argo chrome、壁纸和 Ghostty 配色。",
"settings.twilight.presets": "预设",
"settings.twilight.seed": "种子颜色",
"settings.twilight.invalidSeed": "请输入 #RGB 或 #RRGGBB。",
"settings.twilight.preview": "Twilight 预览",
"settings.twilight.preset.twilight": "暮光",
"settings.twilight.preset.aurora": "极光",
"settings.twilight.preset.abyss": "深海",
"settings.twilight.preset.sakura": "樱绯",
"settings.twilight.preset.ember": "余烬",
```

- [ ] **Step 4: Add Settings state and bindings**

In `SettingsSheet`, add state:

```swift
@State private var twilightSeedDraft = TwilightTheme.defaultSeedHex
@State private var twilightSeedError: String?
```

When loading settings from the store in the sheet lifecycle, set:

```swift
twilightSeedDraft = appSettings.twilightThemeSeedHex
twilightSeedError = nil
```

Add bindings:

```swift
private var twilightThemeEnabledBinding: Binding<Bool> {
    Binding(
        get: { appSettings.twilightThemeEnabled },
        set: { enabled in
            appSettings.twilightThemeEnabled = enabled
            if enabled {
                appSettings.twilightThemeSeedHex = TwilightTheme.normalizedSeedHex(appSettings.twilightThemeSeedHex)
                twilightSeedDraft = appSettings.twilightThemeSeedHex
                twilightSeedError = nil
            }
            applyThemeLive()
        }
    )
}

private var twilightSeedBinding: Binding<String> {
    Binding(
        get: { twilightSeedDraft },
        set: { value in
            twilightSeedDraft = value.lowercased()
            let normalized = TwilightTheme.normalizedSeedHex(value)
            if normalized == TwilightTheme.defaultSeedHex,
               value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != TwilightTheme.defaultSeedHex {
                twilightSeedError = localized("settings.twilight.invalidSeed")
                return
            }
            twilightSeedError = nil
            appSettings.twilightThemeSeedHex = normalized
            applyThemeLive()
        }
    )
}
```

- [ ] **Step 5: Replace theme settings view with Twilight-first controls**

At the top of `themeSettingsView`, add:

```swift
Toggle(localized("settings.twilight.enabled"), isOn: twilightThemeEnabledBinding)

Text(localized("settings.twilight.description"))
    .font(.system(size: 11, weight: .medium))
    .foregroundStyle(.secondary)

if appSettings.twilightThemeEnabled {
    Text(localized("settings.twilight.presets"))
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)

    HStack(spacing: 8) {
        ForEach(TwilightTheme.presets) { preset in
            Button {
                appSettings.twilightThemeSeedHex = preset.seedHex
                twilightSeedDraft = preset.seedHex
                twilightSeedError = nil
                applyThemeLive()
            } label: {
                Circle()
                    .fill(TwilightTheme.generate(seed: preset.seedHex).amber.color)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(appSettings.twilightThemeSeedHex == preset.seedHex ? Color.white : ArgoTheme.hairline, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .help(localized(preset.nameKey))
        }
    }

    TextField(localized("settings.twilight.seed"), text: twilightSeedBinding)
        .textFieldStyle(.roundedBorder)
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .frame(width: 110)

    if let twilightSeedError {
        Text(twilightSeedError)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(ArgoTheme.danger)
    }
}

if !appSettings.twilightThemeEnabled {
    Toggle(localized("settings.general.terminal.useCustomTheme"), isOn: terminalThemeEnabledBinding)
    // Keep the existing Ghostty theme picker block inside this branch.
}
```

Add `TwilightThemePreviewCard` near `TerminalThemePreviewCard`:

```swift
private struct TwilightThemePreviewCard: View {
    let theme: TwilightTheme
    let localized: (String) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("settings.twilight.preview"))
                .font(.system(size: 12, weight: .semibold))
            HStack(spacing: 8) {
                Text("❯")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.amber.color)
                Text("git status")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(ArgoTheme.text)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(18), spacing: 5), count: 8), spacing: 5) {
                ForEach(0..<16, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(nsColor: NSColor(hexString: theme.ghostty.palette[index]!)!))
                        .frame(width: 18, height: 18)
                        .help("\(index): \(theme.ghostty.palette[index]!)")
                }
            }
        }
        .padding(14)
        .background(ArgoTheme.glassCard, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(ArgoTheme.hairline, lineWidth: 1))
    }
}
```

If no `NSColor(hexString:)` helper exists, add a private helper in `SettingsSheet.swift`:

```swift
private extension NSColor {
    convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        self.init(
            calibratedRed: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255,
            alpha: 1
        )
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run:

```bash
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/LocalizationManagerTests -only-testing:ArgoTests/WorkspaceTabsTests test
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Argo/UI/Sheets/SettingsSheet.swift Argo/Support/L10n.swift Tests/LocalizationManagerTests.swift Tests/WorkspaceTabsTests.swift
git commit -m "feat(settings): theme controls"
```

---

### Task 8: Integration Verification And Manual Smoke

**Files:**
- Modify only if a verification failure exposes a focused defect in files changed by Tasks 1-7.

**Interfaces:**
- Consumes: all prior tasks.
- Produces: a verified build and smoke checklist result.

- [ ] **Step 1: Run focused test suite**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/TwilightThemeTests \
  -only-testing:ArgoTests/ArgoGhosttyConfigTests \
  -only-testing:ArgoTests/ArgoChromeTintTests \
  -only-testing:ArgoTests/WorkspaceStoreTests \
  -only-testing:ArgoTests/WorkspaceTabsTests \
  -only-testing:ArgoTests/LocalizationManagerTests \
  test
```

Expected: PASS.

- [ ] **Step 2: Run Debug build**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected: PASS.

- [ ] **Step 3: Run full test suite if settings migration or UI source tests changed unexpectedly**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  test
```

Expected: PASS.

- [ ] **Step 4: Manual smoke test**

Launch the Debug app and verify:

```text
1. 首次启动 workspace 模式显示 Twilight 暮光：右下暖色日落、冷色天空 / 水面、左侧终端正文区压暗。
2. 顶栏、rail、sidebar、terminal chrome 使用同源 amber/cyan/green/magenta。
3. 搜索框、workspace 副标题或 terminal category 前缀出现 ❯。
4. Settings 中切换五个 seed，chrome、wallpaper、terminal preview 和新建 Ghostty 终端颜色同步变化。
5. 输入合法 #RGB 与 #RRGGBB 会更新主题；输入非法 seed 不写入 settings，不破坏当前主题。
6. terminalBackgroundOpacity 小于 1 时终端透出壁纸，文字仍清晰。
7. terminalBackgroundBlur 开关只影响 blur，不改变 Twilight 色彩。
8. sidebar 搜索、选择、多选、右键菜单、拖拽、展开/折叠和 footer actions 正常。
9. terminal tab、split right、split down、new tab、pane search、状态条、preview、file tree 行为不变。
10. Canvas / Overview 可打开，文字可读，没有过度染色。
```

- [ ] **Step 5: Inspect diff hygiene**

Run:

```bash
git diff --check
git status --short
```

Expected: `git diff --check` prints no output; `git status --short` shows only intended modified files before final commit.

- [ ] **Step 6: Commit final verification fixes if any**

If Step 1-5 required small fixes, commit them:

```bash
git add Argo Tests
git commit -m "fix(theme): polish twilight"
```

If no fixes were needed, do not create an empty commit.

---

## Spec Coverage Self-Review

- 单色驱动算法：Task 1 implements `hexToHsl`、`hslToHex`、`lerpHue`、UI slots、wallpaper stops、ANSI semantic palette and preset tests.
- 默认 seed 与五个预设：Task 1 locks `#ffb066` and all five preset hex values.
- Ghostty 同源输出：Task 3 writes `background`、`foreground`、`palette = 0...15` from `TwilightTheme`.
- Settings persistence and migration：Task 2 adds defaults, Codable fallback, invalid seed normalization and store preservation.
- 主窗口右下日落构图：Task 5 adds `TwilightWallpaperView` behind workspace mode.
- `❯` prompt：Task 5 maps sidebar search; Task 6 maps terminal category pills.
- 透明分层纪律：Task 5 keeps one sidebar outer surface; Task 6 keeps terminal blur scoped and adds scrim / horizon glow.
- 功能不受影响：Tasks 5-7 explicitly preserve `NSOutlineView` bridge, store actions, terminal split / tab actions, pane search lifecycle and Ghostty host.
- 非目标：No task adds Warp export, replaces Ghostty runtime, changes vendored dependencies, or imports Google Fonts.

## Placeholder Scan

The plan contains no unresolved placeholder markers and no undefined task interfaces.
