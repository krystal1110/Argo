# 顶部时间命令入口设计

## 目标

把顶部玻璃栏中现有的宽版“命令面板”入口替换成一个更精细的紧凑胶囊控件。新控件同时承担两个作用：展示当前时段和时间，并保留打开命令面板的主入口。

命令面板弹层和命令列表不改动：点击入口仍然走现有 `store.dispatch(.toggleCommandPalette)`，弹出的 `CommandPaletteView` 保持现状。默认快捷键改为 `⇧⌘P`，避免 `⌘P` 和“快速打开/搜索”语义混淆。

## 选定方向

采用视觉伴随稿中的“时段图标 + 时间 + Open Command Palette + 快捷键”方向。控件位于当前宽版命令面板按钮所在的顶部中间位置，内容顺序为：

```text
时段图标  当前时间  –  Open Command Palette (当前快捷键)
```

时段图标根据当前本地时间切换：

- 早上：使用日出图标，颜色偏暖橙。
- 下午：使用日间太阳图标，颜色偏亮黄。
- 日落：使用太阳落下图标，颜色偏红，贴近用户参考图。
- 夜间：使用月亮星星图标，颜色偏蓝紫。

## 交互与视觉

新入口应保持一个可点击的整体按钮，而不是把时间和命令入口拆成多个交互目标。用户点击胶囊中的任意位置都会打开或关闭命令面板。

视觉要求：

- 胶囊使用轻透明的内嵌玻璃槽效果，不再使用突出的玻璃浮层或厚重黑色底。
- 图标不使用圆形或图片背景，只保留 SF Symbol 本身和对应时段颜色。
- 时间使用等宽数字效果，避免分钟变化时造成明显宽度跳动。
- 命令文案使用 `Open Command Palette`，后面用括号显示当前真实快捷键。
- 快捷键文本必须从 `ArgoKeyboardShortcuts.effectiveShortcut(for: .toggleCommandPalette, in:)` 或等价逻辑读取，不能硬编码 `P`。
- 默认快捷键显示为 `⇧⌘P`；`⌘P` 不再作为命令面板默认入口。
- 当命令面板快捷键被用户禁用时，只显示 `Open Command Palette`，不显示空括号或 `Not Set`。
- 不再显示原来的长条 `Command Palette` 文案。

可访问性要求：

- 保留 localized `accessibilityLabel` 和 `help`，仍指向命令面板。
- 时间展示只作为视觉辅助，不改变命令面板入口的语义。

## 实现范围

实现应优先限制在 `Argo/UI/MainWindowView.swift` 附近。

建议拆分：

- 在 `MainWindowView` 中替换现有宽版命令面板 `Button` 的 label。
- 新增一个小型私有 SwiftUI view，例如 `TimeCommandPaletteButtonLabel`，负责渲染胶囊内容。
- 使用 `Date` 和 `Timer.publish` 或类似轻量机制刷新分钟级时间。
- 时段判断先使用本地小时区间，避免引入定位、日出日落 API 或额外权限。

建议时段区间：

- 早上：`5..<12`
- 下午：`12..<17`
- 日落：`17..<20`
- 夜间：其他时间

## 测试与验证

这是 SwiftUI 顶部 chrome 的视觉和状态展示变更，核心命令行为不变。验证重点：

- 用单元测试覆盖默认 `⇧⌘P`、用户自定义快捷键、禁用快捷键时的命令文案。
- 用单元测试覆盖 `⌘P` 默认不匹配命令面板、`⇧⌘P` 默认匹配命令面板。
- 运行 macOS Debug 构建：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

- 手动确认顶部栏不再显示宽版 `Command Palette` 文案。
- 手动确认新胶囊显示无背景图标、当前时间、`Open Command Palette (⇧⌘P)` 或用户设置后的真实快捷键。
- 手动确认点击胶囊可以打开现有命令面板。
- 手动确认默认 UI 缩放下顶部栏左右控件没有重叠。
