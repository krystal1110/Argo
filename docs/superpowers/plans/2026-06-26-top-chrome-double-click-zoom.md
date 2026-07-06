# Top Chrome Double Click Zoom Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Argo 顶部自绘 chrome 区域支持双击切换窗口 zoom，并在再次双击时还原到原窗口大小。

**Architecture:** 在 `MainWindowView` 的 `topGlassChrome` 背景层安装一个轻量 AppKit `NSViewRepresentable`。事件视图只处理左键双击并调用所在 `NSWindow.performZoom(nil)`，单击和拖拽仍交给现有窗口背景拖动能力，顶部按钮和终端区域不接收这个处理器。

**Tech Stack:** Swift、SwiftUI、AppKit、XCTest、Xcode `Argo.xcodeproj`。

## Global Constraints

- 所有面向协作的文档使用简体中文；代码和标识符保持英文。
- 保持现有 `AppKit container + SwiftUI content` 架构。
- 不改变终端栈和 Ghostty runtime。
- 先写失败测试，再写生产代码。

---

### Task 1: 顶部 chrome 双击事件层

**Files:**
- Create: `Tests/MainWindowChromeInteractionTests.swift`
- Modify: `Argo/UI/MainWindowView.swift`

**Interfaces:**
- Produces: `TopChromeDoubleClickZoomEventView(onDoubleClick:)`
- Consumes: `NSWindow.performZoom(nil)` 和现有 `topGlassChrome`

- [ ] **Step 1: Write the failing test**

```swift
@MainActor
final class MainWindowChromeInteractionTests: XCTestCase {
    func testTopChromeDoubleClickZoomEventViewOnlyZoomsOnDoubleClick() {
        var zoomCount = 0
        let view = TopChromeDoubleClickZoomEventView { _ in
            zoomCount += 1
        }

        view.mouseDown(with: mouseEvent(clickCount: 1))
        XCTAssertEqual(zoomCount, 0)

        view.mouseDown(with: mouseEvent(clickCount: 2))
        XCTAssertEqual(zoomCount, 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' test -only-testing:ArgoTests/MainWindowChromeInteractionTests
```

Expected: FAIL because `TopChromeDoubleClickZoomEventView` does not exist.

- [ ] **Step 3: Write minimal implementation**

Add `TopChromeDoubleClickZoomLayer` as a background view in `topGlassChrome`, and implement `TopChromeDoubleClickZoomEventView.mouseDown(with:)` to call the injected closure only for left-button double clicks.

- [ ] **Step 4: Run focused test to verify it passes**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' test -only-testing:ArgoTests/MainWindowChromeInteractionTests
```

Expected: PASS.

- [ ] **Step 5: Run app build verification**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -configuration Debug -destination 'platform=macOS,arch=arm64' build
```

Expected: build exits 0.
