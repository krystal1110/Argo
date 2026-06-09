# 顶部内嵌 Chrome Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将主窗口顶部所有凸起式胶囊块改成统一的内嵌槽效果。

**Architecture:** 复用现有顶部控件边界，不重写主窗口布局。新增一个共享的内嵌胶囊背景 modifier，让 `GlassToolbarGroup`、`GlassToolbarSplitButton` 和时间命令入口使用同一套凹陷视觉语言。

**Tech Stack:** SwiftUI、AppKit menu anchor、XCTest 源码约束测试、`xcodebuild`

---

### Task 1: 顶部共享控件内嵌化

**Files:**
- Modify: `Argo/UI/Components/GlassChromeControls.swift`
- Modify: `Argo/UI/MainWindowView.swift`
- Test: `Tests/QuickCommandSupportTests.swift`

- [x] **Step 1: Write the failing test**

在 `Tests/QuickCommandSupportTests.swift` 增加源码约束测试，读取 `Argo/UI/Components/GlassChromeControls.swift` 和 `Argo/UI/MainWindowView.swift`，确认顶部共享控件使用 `InsetToolbarCapsuleSurface`，并且 `GlassToolbarGroup` / `GlassToolbarSplitButton` 不再出现外投影 `.shadow(color: .black.opacity(0.18), radius: 12, y: 6)`。

- [x] **Step 2: Run test to verify it fails**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/QuickCommandSupportTests/testTopChromeUsesInsetToolbarSurfaces test
```

Expected: FAIL，因为 `InsetToolbarCapsuleSurface` 尚不存在，顶部共享控件仍使用凸起投影。

- [x] **Step 3: Write minimal implementation**

在 `GlassChromeControls.swift` 增加 `InsetToolbarCapsuleSurface`，用低透明材质、弱描边和顶部内阴影表达轻玻璃内嵌槽；将 `GlassToolbarGroup` 和 `GlassToolbarSplitButton` 的亮色渐变、外投影替换为该 modifier。在 `MainWindowView.swift` 中让 `TimeCommandPaletteButtonLabel` 复用同一个 modifier，并让顶部栏背景使用低透明材质而不是厚重黑色底。

- [x] **Step 4: Run test to verify it passes**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/QuickCommandSupportTests/testTopChromeUsesInsetToolbarSurfaces test
```

Expected: PASS。

- [x] **Step 5: Run focused regression tests and build**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/QuickCommandSupportTests -only-testing:ArgoTests/TimeCommandPaletteSupportTests test
xcodebuild -project Argo.xcodeproj -scheme Argo -configuration Debug -destination 'platform=macOS,arch=arm64' build
git diff --check
```

Expected: tests pass, build succeeds, diff check clean.
