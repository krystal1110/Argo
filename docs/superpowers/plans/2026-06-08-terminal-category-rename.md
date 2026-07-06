# 终端二级分类 Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将终端顶部二级分类 rename 改为稳定的轻量 popover 输入，避免原地 AppKit 焦点桥接导致卡顿或闪退。

**Architecture:** 复用 `TerminalLocalChrome` 的 `editingCategoryID`、`renameDraft` 和 `WorkspaceDetailView.renameTerminalCategoryFromChrome` 数据流，只替换 rename 视图层。每个分类 pill 将 SwiftUI `popover` 锚到实际的 pencil 按钮上，popover 内部用纯 SwiftUI `TextField` 和图标按钮提交/取消，不再使用 `NSViewRepresentable` 或 first-responder workaround。

**Tech Stack:** SwiftUI、XCTest 源码约束、`xcodebuild`

---

### Task 1: 写失败测试约束 popover rename

**Files:**
- Modify: `Tests/WorkspaceTabsTests.swift`

- [x] **Step 1: Update rename UI source assertions**

将 `testTerminalChromeExposesInlineCategoryRename()` 改为 `testTerminalChromeExposesPopoverCategoryRename()`，要求 `TerminalLocalChrome.swift` 包含：

```swift
XCTAssertTrue(terminalChromeSource.contains("renamePopoverBinding: renamePopoverBinding(for: category.id)"))
XCTAssertTrue(terminalChromeSource.contains(".popover(isPresented: renamePopoverBinding)"))
XCTAssertTrue(terminalChromeSource.contains("private struct TerminalChromeCategoryRenamePopover"))
XCTAssertTrue(terminalChromeSource.contains("TextField(LocalizationManager.shared.string(\"main.tab.namePlaceholder\"), text: $draft)"))
XCTAssertTrue(terminalChromeSource.contains("Image(systemName: \"checkmark\")"))
XCTAssertTrue(terminalChromeSource.contains("Image(systemName: \"xmark\")"))
XCTAssertFalse(terminalChromeSource.contains("TerminalChromeRenameTextField"))
XCTAssertFalse(terminalChromeSource.contains("NSViewRepresentable"))
XCTAssertFalse(terminalChromeSource.contains("controlTextDidEndEditing"))
```

- [x] **Step 2: Run test to verify it fails**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceTabsTests/testTerminalChromeExposesPopoverCategoryRename test
```

Expected: FAIL before implementation because the old inline AppKit rename path still exists.

---

### Task 2: 写失败测试约束移除焦点交接循环

**Files:**
- Modify: `Tests/WorkspaceTabsTests.swift`

- [x] **Step 1: Add focus-loop regression assertion**

将 `testTerminalChromeRenameDoesNotCommitDuringInitialFocusHandoff()` 改为 `testTerminalChromeRenameAvoidsAppKitFocusHandoffLoop()`，要求：

```swift
XCTAssertTrue(terminalChromeSource.contains("renamePopoverBinding(for categoryID: UUID) -> Binding<Bool>"))
XCTAssertTrue(terminalChromeSource.contains("renameDraft = category.title"))
XCTAssertTrue(terminalChromeSource.contains("editingCategoryID = category.id"))
XCTAssertFalse(terminalChromeSource.contains("makeFirstResponder"))
XCTAssertFalse(terminalChromeSource.contains("selectText(nil)"))
XCTAssertFalse(terminalChromeSource.contains("refocusAfterInitialHandoffIfNeeded"))
```

- [x] **Step 2: Run focused RED tests**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceTabsTests/testTerminalChromeExposesPopoverCategoryRename -only-testing:ArgoTests/WorkspaceTabsTests/testTerminalChromeRenameAvoidsAppKitFocusHandoffLoop test
```

Expected: FAIL before implementation because the old AppKit bridge still contains first-responder logic.

---

### Task 3: 实现 SwiftUI popover rename

**Files:**
- Modify: `Argo/UI/Workspace/TerminalLocalChrome.swift`

- [x] **Step 1: Replace inline rename branch with a button-anchored popover**

在 `ForEach(categories)` 中始终渲染 `TerminalChromeCategoryPill`，并传入：

```swift
renamePopoverBinding: renamePopoverBinding(for: category.id),
renamePopover: {
    TerminalChromeCategoryRenamePopover(
        draft: $renameDraft,
        onCommit: commitRename,
        onCancel: cancelRename
    )
}
```

- [x] **Step 2: Add popover binding**

新增：

```swift
private func renamePopoverBinding(for categoryID: UUID) -> Binding<Bool> {
    Binding(
        get: {
            editingCategoryID == categoryID
        },
        set: { isPresented in
            if !isPresented, editingCategoryID == categoryID {
                cancelRename()
            }
        }
    )
}
```

- [x] **Step 3: Simplify rename state**

让 `beginRename(_:)` 只设置草稿和当前编辑分类：

```swift
private func beginRename(_ category: TerminalChromeCategoryDescriptor) {
    renameDraft = category.title
    editingCategoryID = category.id
}
```

删除 `isRenameFieldFocused`、`renameField(for:)`、`TerminalChromeCategoryRenamePill`、`TerminalChromeRenameTextField` 和所有 AppKit focus workaround。

- [x] **Step 4: Add pure SwiftUI popover view**

在 `TerminalChromeCategoryPill` 的 pencil button 上挂载：

```swift
.popover(isPresented: renamePopoverBinding) {
    renamePopover()
}
```

新增 `TerminalChromeCategoryRenamePopover`，内部包含：

```swift
TextField(LocalizationManager.shared.string("main.tab.namePlaceholder"), text: $draft)
Image(systemName: "checkmark")
Image(systemName: "xmark")
```

`TextField` 使用 `.onSubmit(onCommit)`；`checkmark` 调用 `onCommit`；`xmark` 调用 `onCancel`。

---

### Task 4: 验证

**Files:**
- Test: `Tests/WorkspaceTabsTests.swift`
- Build: `Argo.xcodeproj`

- [x] **Step 1: Run focused rename tests**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceTabsTests/testTerminalChromeExposesPopoverCategoryRename -only-testing:ArgoTests/WorkspaceTabsTests/testTerminalChromeRenameAvoidsAppKitFocusHandoffLoop test
```

Expected: PASS.

- [x] **Step 2: Run WorkspaceTabsTests**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/WorkspaceTabsTests test
```

Expected: PASS.

- [x] **Step 3: Run app build**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -configuration Debug -destination 'platform=macOS,arch=arm64' build
```

Expected: BUILD SUCCEEDED.

- [x] **Step 4: Check patch cleanliness**

Run:

```sh
git diff --check
```

Expected: no output.
