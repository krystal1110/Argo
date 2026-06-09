# 终端二级分类 Rename 设计

## 目标

优化终端顶部二级分类条的重命名体验。用户点击当前分类上的 rename 入口后，应能稳定修改分类名称；如果原地编辑会引入焦点抖动或卡顿，就使用轻量弹层承载输入。

这个改动只作用于 `TerminalLocalChrome` 的分类 rename 交互，不改变分类创建、选择、关闭、pane split、tab 持久化和 `WorkspaceStore.renameTab` 的数据流。

## 选定方向

采用“分类 pill + 小型 rename popover”：

```text
[ > selected category                         ✎ ]
          └─ popover: [ category name        ✓  × ]
```

分类本身保持在顶部 chrome 中，点击 pencil 后在该分类附近弹出一个轻量输入层。输入层负责改名，顶部分类条不再被替换成 AppKit `NSTextField`，避免 SwiftUI/AppKit first-responder 交接时出现闪退、反复 refocus 或卡顿。

## 视觉细节

- 分类 pill 继续保持当前轻透明、内嵌、弱边线风格。
- Rename 输入层使用系统 material 和低透明边线，保持轻，不做厚重黑底和外投影。
- 输入框是纯 SwiftUI `TextField`，字体沿用分类标题的等宽 semibold 节奏。
- 右侧用图标按钮表达操作：
  - `checkmark`：提交 rename。
  - `xmark`：取消 rename。
- hover 状态只轻微提升图标透明度，不改变整体尺寸。

## 交互细节

- 点击选中分类上的 pencil 后打开 rename popover。
- 打开 popover 时，草稿值来自当前分类标题。
- `Return` 提交。
- 点击 `checkmark` 提交。
- 点击 `xmark` 或关闭 popover 取消。
- 提交时 trim 文本；trim 后非空才调用 `onRenameCategory`，空内容不写入 store。
- 切换 active category 时取消当前 rename，避免把旧草稿带到另一个分类。
- 不再使用 `NSViewRepresentable`、`makeFirstResponder`、`selectText(nil)` 或 `controlTextDidEndEditing` 做焦点交接。

## 实现范围

主要修改 `Argo/UI/Workspace/TerminalLocalChrome.swift`：

- `ForEach(categories)` 始终渲染 `TerminalChromeCategoryPill`。
- 选中分类的 pencil 调用 `beginRename(_:)`，设置：
  - `renameDraft = category.title`
  - `editingCategoryID = category.id`
- 每个分类 pill 接收 `renamePopoverBinding(for: category.id)`，并把 popover 锚到实际的 pencil 按钮上。
- 新增 `TerminalChromeCategoryRenamePopover`，内部使用纯 SwiftUI `TextField`、`checkmark` 和 `xmark`。
- 删除旧的 `TerminalChromeRenameTextField` AppKit bridge 以及 first-responder workaround。
- 保持 `commitRename()`、`cancelRename()` 和 `onRenameCategory` 数据流。

## 测试与验证

自动化测试以源码约束和行为约束为主：

- 覆盖 rename UI 使用 popover，而不是原地 AppKit 文本框。
- 覆盖 popover 中包含 `TextField`、`checkmark`、`xmark`。
- 覆盖不再包含 `NSViewRepresentable`、`controlTextDidEndEditing`、`makeFirstResponder`、`selectText(nil)` 和 refocus workaround。
- 覆盖 `beginRename(_:)` 只设置草稿和当前编辑分类。

手动验证：

- 打开一个有多个终端分类的 workspace。
- 点击当前分类 pencil，确认 popover 稳定打开且不会闪退。
- 输入新名称后按 Return 或点击 `checkmark`，确认分类名更新。
- 再次打开后点击 `xmark`，确认取消。
- 清空内容后提交，确认不会写入空名称。
- 切换分类时确认 popover 退出。
