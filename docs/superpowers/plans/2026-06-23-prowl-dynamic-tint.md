# Prowl Dynamic Tint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Argo 主窗口改成已确认的 A2 Prowl 动态 tint：顶栏、左侧 chrome、workspace sidebar surface 和 terminal tab bar 跟随当前 workspace / active worktree 颜色变化。

**Architecture:** 先新增一个可测试的 `ArgoChromeTint` 模型，集中负责 palette → RGB → region alpha 的解析；`WorkspaceStore` 只负责从当前 selection 解析 tint 来源；SwiftUI view 只消费 `store.chromeTint`，不在视图中散写颜色推导逻辑。

**Tech Stack:** Swift, SwiftUI, AppKit `NSColor`, XCTest, existing `ArgoTheme`, existing `SidebarIconPalette`.

## Global Constraints

- 始终使用简体中文回复；代码、标识符、命令、文件路径保持英文。
- 遵守 `docs/superpowers/specs/2026-06-23-prowl-dynamic-tint-design.md`：A2 平衡强度、动态 tint、无新设置开关。
- 不重写 `WorkspaceSidebarView` 的 `NSOutlineView` 桥接，不改 Ghostty runtime，不改 pane layout 数据结构。
- 所有 production code 必须先有失败测试；每个任务按 RED → GREEN → REFACTOR 执行。
- 提交信息使用 `feat(scope): subject` 或 `fix(scope): subject`，subject 不超过 20 个字符。

---

## File Structure

- Create: `Argo/Support/ArgoChromeTint.swift`
  - 定义 `ArgoChromeTint`、RGB components、A2 region alpha、palette 解析、灰阶 palette 降强度规则。
- Modify: `Argo/App/WorkspaceStore.swift`
  - 暴露 `chromeTint` 和 `chromeTint(for:)`，把 selected workspace / active worktree 映射到 `ArgoChromeTint`。
- Modify: `Argo/UI/MainWindowView.swift`
  - `topGlassChrome`、`GlobalModeRailView`、`FloatingWorkspaceSidebarSurface` 接入 `store.chromeTint`。
- Modify: `Argo/UI/Components/GlobalModeRailView.swift`
  - 新增 `chromeTint` 参数，用动态 tint 替代 selected rail button 的固定 accent。
- Modify: `Argo/UI/Workspace/WorkspaceDetailView.swift`
  - `TerminalWorkspaceSurface` 和 `TerminalWorkspaceSurfaceStyle` 接入 dynamic tint；terminal tab/local chrome 使用 tab-bar alpha。
- Create: `Tests/ArgoChromeTintTests.swift`
  - 测试模型、region alpha、彩色/灰阶 palette。
- Modify: `Tests/WorkspaceStoreTests.swift`
  - 测试 tint 来源优先级和 fallback。
- Modify: `Tests/QuickCommandSupportTests.swift`
  - 更新源码结构约束，锁住 top/sidebar/terminal 使用 tint helper。

## Task 1: Add `ArgoChromeTint` Model

**Files:**
- Create: `Tests/ArgoChromeTintTests.swift`
- Create: `Argo/Support/ArgoChromeTint.swift`

**Interfaces:**
- Produces: `struct ArgoChromeTint: Equatable`
- Produces: `ArgoChromeTint.Components(red:green:blue:)`
- Produces: `ArgoChromeTint.Fill(color:alpha:)`
- Produces: `ArgoChromeTint.resolved(for palette: SidebarIconPalette?) -> ArgoChromeTint`
- Produces: region fills `topFill`, `leadingFill`, `sidebarFill`, `tabBarFill`, `selectionFill`, `glowFill`

- [ ] **Step 1: Write failing tests**

Add `Tests/ArgoChromeTintTests.swift`:

```swift
//
//  ArgoChromeTintTests.swift
//  ArgoTests
//

import XCTest
@testable import Argo

final class ArgoChromeTintTests: XCTestCase {
    func testColorfulPaletteUsesBalancedA2RegionStrengths() {
        let tint = ArgoChromeTint.resolved(for: .mint)

        XCTAssertEqual(tint.topFill.alpha, 0.20, accuracy: 0.0001)
        XCTAssertEqual(tint.leadingFill.alpha, 0.16, accuracy: 0.0001)
        XCTAssertEqual(tint.sidebarFill.alpha, 0.07, accuracy: 0.0001)
        XCTAssertEqual(tint.tabBarFill.alpha, 0.17, accuracy: 0.0001)
        XCTAssertEqual(tint.selectionFill.alpha, 0.21, accuracy: 0.0001)
        XCTAssertEqual(tint.glowFill.alpha, 0.10, accuracy: 0.0001)
        XCTAssertFalse(tint.isNeutral)
    }

    func testNeutralPaletteUsesSofterStrengths() {
        let tint = ArgoChromeTint.resolved(for: .graphite)

        XCTAssertTrue(tint.isNeutral)
        XCTAssertLessThan(tint.topFill.alpha, ArgoChromeTint.resolved(for: .mint).topFill.alpha)
        XCTAssertLessThan(tint.sidebarFill.alpha, ArgoChromeTint.resolved(for: .mint).sidebarFill.alpha)
        XCTAssertLessThan(tint.tabBarFill.alpha, ArgoChromeTint.resolved(for: .mint).tabBarFill.alpha)
    }

    func testNilPaletteFallsBackToArgoAccent() {
        let tint = ArgoChromeTint.resolved(for: nil)

        XCTAssertEqual(tint.components, ArgoChromeTint.defaultAccentComponents)
        XCTAssertFalse(tint.isNeutral)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/ArgoChromeTintTests \
  test
```

Expected: FAIL because `ArgoChromeTint` does not exist.

- [ ] **Step 3: Add minimal model implementation**

Create `Argo/Support/ArgoChromeTint.swift`:

```swift
//
//  ArgoChromeTint.swift
//  Argo
//

import AppKit
import SwiftUI

struct ArgoChromeTint: Equatable {
    struct Components: Equatable {
        var red: Double
        var green: Double
        var blue: Double

        var color: Color {
            Color(.sRGB, red: red, green: green, blue: blue)
        }

        init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        init(color: Color) {
            let resolved = NSColor(color).usingColorSpace(.sRGB)
                ?? NSColor.systemBlue.usingColorSpace(.sRGB)
                ?? NSColor(calibratedRed: 0.25, green: 0.54, blue: 0.98, alpha: 1)
            self.init(
                red: Double(resolved.redComponent),
                green: Double(resolved.greenComponent),
                blue: Double(resolved.blueComponent)
            )
        }
    }

    struct Fill: Equatable {
        var components: Components
        var alpha: Double

        var color: Color {
            components.color.opacity(alpha)
        }
    }

    struct Strength: Equatable {
        var top: Double
        var leading: Double
        var sidebar: Double
        var tabBar: Double
        var selection: Double
        var glow: Double
    }

    static let defaultAccentComponents = Components(red: 0.25, green: 0.54, blue: 0.98)

    private static let balancedStrength = Strength(
        top: 0.20,
        leading: 0.16,
        sidebar: 0.07,
        tabBar: 0.17,
        selection: 0.21,
        glow: 0.10
    )

    private static let neutralStrength = Strength(
        top: 0.11,
        leading: 0.09,
        sidebar: 0.035,
        tabBar: 0.095,
        selection: 0.13,
        glow: 0.045
    )

    var components: Components
    var strength: Strength
    var isNeutral: Bool

    var topFill: Fill { Fill(components: components, alpha: strength.top) }
    var leadingFill: Fill { Fill(components: components, alpha: strength.leading) }
    var sidebarFill: Fill { Fill(components: components, alpha: strength.sidebar) }
    var tabBarFill: Fill { Fill(components: components, alpha: strength.tabBar) }
    var selectionFill: Fill { Fill(components: components, alpha: strength.selection) }
    var glowFill: Fill { Fill(components: components, alpha: strength.glow) }

    static var fallback: ArgoChromeTint {
        ArgoChromeTint(
            components: defaultAccentComponents,
            strength: balancedStrength,
            isNeutral: false
        )
    }

    static func resolved(for palette: SidebarIconPalette?) -> ArgoChromeTint {
        guard let palette else { return fallback }
        let neutral = neutralPalettes.contains(palette)
        let descriptor = palette.descriptor
        let sourceColor = neutral ? descriptor.border : descriptor.gradientEnd
        return ArgoChromeTint(
            components: Components(color: sourceColor),
            strength: neutral ? neutralStrength : balancedStrength,
            isNeutral: neutral
        )
    }

    private static let neutralPalettes: Set<SidebarIconPalette> = [
        .slate,
        .smoke,
        .charcoal,
        .graphite,
        .mocha,
    ]
}
```

- [ ] **Step 4: Run model test to verify it passes**

Run the same `xcodebuild ... -only-testing:ArgoTests/ArgoChromeTintTests test`.

Expected: PASS.

- [ ] **Step 5: Commit task**

```sh
git add -f Tests/ArgoChromeTintTests.swift Argo/Support/ArgoChromeTint.swift
git commit -m "feat(ui): add tint model"
```

## Task 2: Resolve Current Workspace Tint In Store

**Files:**
- Modify: `Tests/WorkspaceStoreTests.swift`
- Modify: `Argo/App/WorkspaceStore.swift`

**Interfaces:**
- Consumes: `ArgoChromeTint.resolved(for:)`
- Produces: `WorkspaceStore.chromeTint: ArgoChromeTint`
- Produces: `WorkspaceStore.chromeTint(for workspace: WorkspaceModel?) -> ArgoChromeTint`

- [ ] **Step 1: Write failing store tests**

Add these tests near other `WorkspaceStoreTests` state tests:

```swift
func testChromeTintPrefersActiveWorktreeIconPalette() {
    let root = "/tmp/argo"
    let featurePath = "/tmp/argo/.worktrees/feature"
    let workspace = WorkspaceModel(record: WorkspaceRecord(
        id: UUID(),
        kind: .repository,
        name: "argo",
        repositoryRoot: root,
        activeWorktreePath: featurePath,
        worktreeStates: [],
        isSidebarExpanded: true,
        worktrees: [
            WorktreeModel(path: root, branch: "main", head: "abc", isMainWorktree: true, isLocked: false, lockReason: nil),
            WorktreeModel(path: featurePath, branch: "feature", head: "def", isMainWorktree: false, isLocked: false, lockReason: nil),
        ],
        settings: WorkspaceSettings(
            workspaceIcon: SidebarItemIcon(symbolName: "folder.fill", palette: .blue),
            worktreeIconOverrides: [
                featurePath: SidebarItemIcon(symbolName: "circle.fill", palette: .rose)
            ]
        ),
        activityLog: []
    ))
    let store = WorkspaceStore(persistsWorkspaceState: false)
    store.workspaces = [workspace]
    store.selectedWorkspaceID = workspace.id

    XCTAssertEqual(store.chromeTint, ArgoChromeTint.resolved(for: .rose))
}

func testChromeTintFallsBackToWorkspaceIconPalette() {
    let root = "/tmp/argo"
    let workspace = WorkspaceModel(record: WorkspaceRecord(
        id: UUID(),
        kind: .repository,
        name: "argo",
        repositoryRoot: root,
        activeWorktreePath: root,
        worktreeStates: [],
        isSidebarExpanded: true,
        worktrees: [],
        settings: WorkspaceSettings(
            workspaceIcon: SidebarItemIcon(symbolName: "folder.fill", palette: .gold)
        ),
        activityLog: []
    ))
    let store = WorkspaceStore(persistsWorkspaceState: false)
    store.workspaces = [workspace]
    store.selectedWorkspaceID = workspace.id

    XCTAssertEqual(store.chromeTint, ArgoChromeTint.resolved(for: .gold))
}

func testChromeTintUsesAccentFallbackWithoutSelection() {
    let store = WorkspaceStore(persistsWorkspaceState: false)

    XCTAssertEqual(store.chromeTint, .fallback)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceStoreTests/testChromeTintPrefersActiveWorktreeIconPalette \
  -only-testing:ArgoTests/WorkspaceStoreTests/testChromeTintFallsBackToWorkspaceIconPalette \
  -only-testing:ArgoTests/WorkspaceStoreTests/testChromeTintUsesAccentFallbackWithoutSelection \
  test
```

Expected: FAIL because `WorkspaceStore.chromeTint` does not exist.

- [ ] **Step 3: Implement store tint resolver**

Add to `WorkspaceStore` near existing sidebar icon helpers:

```swift
var chromeTint: ArgoChromeTint {
    chromeTint(for: selectedWorkspace)
}

func chromeTint(for workspace: WorkspaceModel?) -> ArgoChromeTint {
    guard let workspace else { return .fallback }
    if workspace.supportsRepositoryFeatures,
       let activeWorktree = workspace.worktrees.first(where: { $0.path == workspace.activeWorktreePath }) {
        return ArgoChromeTint.resolved(for: sidebarIcon(for: activeWorktree, in: workspace).palette)
    }
    return ArgoChromeTint.resolved(for: sidebarIcon(for: workspace).palette)
}
```

- [ ] **Step 4: Run store tint tests to verify they pass**

Run the same `xcodebuild ... -only-testing:ArgoTests/WorkspaceStoreTests/testChromeTint... test`.

Expected: PASS.

- [ ] **Step 5: Commit task**

```sh
git add Argo/App/WorkspaceStore.swift Tests/WorkspaceStoreTests.swift
git commit -m "feat(ui): resolve tint"
```

## Task 3: Apply Dynamic Tint To Top Chrome And Left Chrome

**Files:**
- Modify: `Tests/QuickCommandSupportTests.swift`
- Modify: `Argo/UI/MainWindowView.swift`
- Modify: `Argo/UI/Components/GlobalModeRailView.swift`

**Interfaces:**
- Consumes: `WorkspaceStore.chromeTint`
- Consumes: `ArgoChromeTint.topFill`, `leadingFill`, `sidebarFill`, `selectionFill`, `glowFill`
- Produces: `GlobalModeRailView(..., chromeTint: ArgoChromeTint, ...)`
- Produces: `FloatingWorkspaceSidebarSurface(chromeTint: ArgoChromeTint) { ... }`

- [ ] **Step 1: Write failing structure tests**

Update `testTopChromeUsesInsetToolbarSurfaces` in `Tests/QuickCommandSupportTests.swift`:

```swift
XCTAssertTrue(mainWindowSource.contains("let chromeTint = store.chromeTint"))
XCTAssertTrue(mainWindowSource.contains("chromeTint.topFill.color"))
XCTAssertFalse(mainWindowSource.contains("ArgoTheme.chromeBackground.opacity(0.68)"))
```

Update `testMainWindowWrapsWorkspaceSidebarInFloatingSurface`:

```swift
XCTAssertTrue(mainWindowSource.contains("FloatingWorkspaceSidebarSurface(chromeTint: store.chromeTint)"))
XCTAssertTrue(mainWindowSource.contains("chromeTint.sidebarFill.color"))
XCTAssertTrue(mainWindowSource.contains("chromeTint.leadingFill.color"))
XCTAssertFalse(mainWindowSource.contains(".background(ArgoTheme.sidebarBackground, in: panelShape)"))
```

Add a source assertion for `GlobalModeRailView`:

```swift
let railSource = try String(
    contentsOf: rootURL.appendingPathComponent("Argo/UI/Components/GlobalModeRailView.swift"),
    encoding: .utf8
)
XCTAssertTrue(railSource.contains("let chromeTint: ArgoChromeTint"))
XCTAssertTrue(railSource.contains("chromeTint.selectionFill.color"))
```

- [ ] **Step 2: Run structure tests to verify they fail**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/QuickCommandSupportTests/testTopChromeUsesInsetToolbarSurfaces \
  -only-testing:ArgoTests/QuickCommandSupportTests/testMainWindowWrapsWorkspaceSidebarInFloatingSurface \
  test
```

Expected: FAIL because the new tint strings are not present.

- [ ] **Step 3: Apply top chrome tint**

In `MainWindowView.topGlassChrome`, introduce `let chromeTint = store.chromeTint` and replace the background ZStack with:

```swift
.background(
    ZStack {
        Rectangle().fill(.ultraThinMaterial)
        ArgoTheme.chromeBackground.opacity(0.54)
        chromeTint.topFill.color
        LinearGradient(
            colors: [
                Color.white.opacity(0.07),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
)
```

Update fixed accent toolbar buttons in `topGlassChrome` to use `chromeTint.components.color` where they represent feature/action tint:

```swift
tint: chromeTint.components.color
```

Keep warning, secondary, and disabled colors unchanged.

- [ ] **Step 4: Pass tint into rail and sidebar surface**

In `MainWindowView.body`:

```swift
GlobalModeRailView(
    selectedMode: store.mainWindowMode,
    chromeTint: store.chromeTint,
    uiScale: uiScale,
    onSelectMode: { mode in
        selectMainWindowMode(mode, restoreFocus: mode == .workspace)
    },
    onOpenSettings: {
        store.presentSettings(for: store.selectedWorkspace)
    }
)
```

and:

```swift
FloatingWorkspaceSidebarSurface(chromeTint: store.chromeTint) {
    WorkspaceSidebarView()
}
```

- [ ] **Step 5: Update `GlobalModeRailView`**

Modify `Argo/UI/Components/GlobalModeRailView.swift`:

```swift
struct GlobalModeRailView: View {
    let selectedMode: MainWindowMode
    let chromeTint: ArgoChromeTint
    let uiScale: CGFloat
    let onSelectMode: (MainWindowMode) -> Void
    let onOpenSettings: () -> Void
```

Use dynamic tint in selected buttons:

```swift
.fill(isSelected ? chromeTint.selectionFill.color : ArgoTheme.subtleFill.opacity(0.65))
```

and:

```swift
.stroke(isSelected ? chromeTint.components.color.opacity(0.65) : ArgoTheme.border.opacity(0.6), lineWidth: 1)
```

- [ ] **Step 6: Update `FloatingWorkspaceSidebarSurface`**

Modify the struct signature and background:

```swift
private struct FloatingWorkspaceSidebarSurface<Content: View>: View {
    let chromeTint: ArgoChromeTint
    @ViewBuilder var content: () -> Content
```

Use a tinted single surface:

```swift
.background(
    ZStack {
        ArgoTheme.sidebarBackground
        chromeTint.sidebarFill.color
        LinearGradient(
            colors: [
                Color.white.opacity(0.045),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    },
    in: panelShape
)
.background(
    chromeTint.leadingFill.color,
    in: Rectangle()
)
```

If the second background creates an extra visible frame, move the leading tint to the parent HStack background instead; keep one visible `panelShape.stroke`.

- [ ] **Step 7: Run structure tests and store tests**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/QuickCommandSupportTests/testTopChromeUsesInsetToolbarSurfaces \
  -only-testing:ArgoTests/QuickCommandSupportTests/testMainWindowWrapsWorkspaceSidebarInFloatingSurface \
  -only-testing:ArgoTests/WorkspaceStoreTests/testChromeTintPrefersActiveWorktreeIconPalette \
  -only-testing:ArgoTests/WorkspaceStoreTests/testChromeTintFallsBackToWorkspaceIconPalette \
  -only-testing:ArgoTests/WorkspaceStoreTests/testChromeTintUsesAccentFallbackWithoutSelection \
  test
```

Expected: PASS.

- [ ] **Step 8: Commit task**

```sh
git add Argo/UI/MainWindowView.swift Argo/UI/Components/GlobalModeRailView.swift Tests/QuickCommandSupportTests.swift
git commit -m "feat(ui): tint chrome"
```

## Task 4: Apply Dynamic Tint To Terminal Chrome

**Files:**
- Modify: `Tests/QuickCommandSupportTests.swift`
- Modify: `Argo/UI/Workspace/WorkspaceDetailView.swift`

**Interfaces:**
- Consumes: `WorkspaceStore.chromeTint`
- Consumes: `ArgoChromeTint.tabBarFill`
- Produces: `TerminalWorkspaceSurface(chromeTint: store.chromeTint) { ... }`
- Produces: `TerminalWorkspaceSurfaceStyle.chromeFill(for tint: ArgoChromeTint) -> some ShapeStyle`

- [ ] **Step 1: Write failing terminal chrome structure test**

Add assertions to `Tests/QuickCommandSupportTests.swift`:

```swift
func testTerminalWorkspaceChromeUsesDynamicTint() throws {
    let rootURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let workspaceDetailSource = try String(
        contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"),
        encoding: .utf8
    )

    XCTAssertTrue(workspaceDetailSource.contains("TerminalWorkspaceSurface(chromeTint: store.chromeTint)"))
    XCTAssertTrue(workspaceDetailSource.contains("TerminalWorkspaceSurfaceStyle.chromeFill(for: store.chromeTint)"))
    XCTAssertTrue(workspaceDetailSource.contains("chromeTint.tabBarFill.color"))
    XCTAssertFalse(workspaceDetailSource.contains("TerminalWorkspaceSurfaceStyle.chromeFill)"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/QuickCommandSupportTests/testTerminalWorkspaceChromeUsesDynamicTint \
  test
```

Expected: FAIL because terminal chrome is still static.

- [ ] **Step 3: Pass tint into terminal surface**

In `WorkspaceSessionDetailView.terminalContent`, change:

```swift
TerminalWorkspaceSurface {
```

to:

```swift
TerminalWorkspaceSurface(chromeTint: store.chromeTint) {
```

Change:

```swift
.background(TerminalWorkspaceSurfaceStyle.chromeFill)
```

to:

```swift
.background(TerminalWorkspaceSurfaceStyle.chromeFill(for: store.chromeTint))
```

- [ ] **Step 4: Update terminal surface style**

Change `TerminalWorkspaceSurface`:

```swift
private struct TerminalWorkspaceSurface<Content: View>: View {
    @EnvironmentObject private var store: WorkspaceStore
    let chromeTint: ArgoChromeTint
    let content: Content

    init(chromeTint: ArgoChromeTint, @ViewBuilder content: () -> Content) {
        self.chromeTint = chromeTint
        self.content = content()
    }
```

In the non-translucent background, keep the deep terminal surface and add a subtle glow only outside the text area:

```swift
if !isTranslucent {
    surfaceFill
}
chromeTint.glowFill.color
    .opacity(isTranslucent ? 0.5 : 1)
```

Change `TerminalWorkspaceSurfaceStyle`:

```swift
private enum TerminalWorkspaceSurfaceStyle {
    static func chromeFill(for chromeTint: ArgoChromeTint) -> some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(0.085),
                chromeTint.tabBarFill.color,
                Color.white.opacity(0.035)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
```

If SwiftUI rejects `Color.opacity` values inside `some ShapeStyle` mixing, use a `ZStack` background at the call site instead:

```swift
.background {
    TerminalWorkspaceSurfaceStyle.chromeFill(for: store.chromeTint)
}
```

and make `chromeFill(for:) -> some View`.

- [ ] **Step 5: Run terminal chrome test**

Run the same `xcodebuild ... -only-testing:ArgoTests/QuickCommandSupportTests/testTerminalWorkspaceChromeUsesDynamicTint test`.

Expected: PASS.

- [ ] **Step 6: Commit task**

```sh
git add Argo/UI/Workspace/WorkspaceDetailView.swift Tests/QuickCommandSupportTests.swift
git commit -m "feat(ui): tint tabs"
```

## Task 5: Final Verification And Manual Smoke

**Files:**
- No planned production file changes unless verification finds a defect.

**Interfaces:**
- Consumes: all previous tasks.
- Produces: final verified A2 dynamic tint implementation.

- [ ] **Step 1: Run focused tests**

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/ArgoChromeTintTests \
  -only-testing:ArgoTests/QuickCommandSupportTests \
  -only-testing:ArgoTests/WorkspaceStoreTests \
  test
```

Expected: PASS.

- [ ] **Step 2: Run full Debug build**

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual smoke test**

Launch the app from Xcode or the built app and cover:

- Select at least two workspaces with different sidebar icon palettes.
- Confirm top chrome, left chrome/sidebar shell, and terminal tab chrome change color.
- Select a workspace with active worktree icon override and confirm worktree tint wins.
- Switch to a gray palette workspace and confirm chrome is quieter than colorful palettes.
- Toggle terminal background opacity/blur and confirm terminal text surface remains readable.
- Use sidebar search, selection, context menu, and footer actions.
- Use terminal tab creation, split right, split down, preview, file tree, and command palette.

- [ ] **Step 4: Inspect git status**

```sh
git status --short
```

Expected: only intentional files changed, or clean after final commit.

- [ ] **Step 5: Commit verification fixes if needed**

If verification required code fixes:

```sh
git add <fixed files>
git commit -m "fix(ui): tint polish"
```

If no fixes were needed, do not create an empty commit.

## Self-Review

- Spec coverage: Tasks cover tint model, source priority, top chrome, left rail/sidebar, terminal chrome, tests, build, and manual smoke.
- Placeholder scan: no red-flag placeholder terms remain.
- Type consistency: `ArgoChromeTint`, `Components`, `Fill`, `Strength`, `chromeTint`, and `chromeFill(for:)` names are consistent across tasks.
- TDD coverage: each production change has a failing test step before implementation.
