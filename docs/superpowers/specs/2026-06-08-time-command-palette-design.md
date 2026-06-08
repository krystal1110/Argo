# 顶部时间命令入口设计

## 目标

把顶部玻璃栏中现有的宽版“命令面板”入口替换成一个更精细的紧凑胶囊控件。新控件同时承担两个作用：展示当前时段和时间，并保留打开命令面板的主入口。

命令面板自身不改动：点击入口仍然走现有 `store.dispatch(.toggleCommandPalette)`，快捷键和命令列表逻辑保持不变，弹出的 `CommandPaletteView` 也保持现状。

## 选定方向

采用视觉伴随稿中的“时段图标 + 时间 + Open command + P”方向。控件位于当前宽版命令面板按钮所在的顶部中间位置，内容顺序为：

```text
时段图标  当前时间  Open command  P
```

时段图标根据当前本地时间切换：

- 早上：使用明亮太阳图标，表达一天开始。
- 下午：使用日间太阳图标，颜色更偏清爽。
- 日落：使用太阳落下或暮色图标，表达傍晚过渡。

## 交互与视觉

新入口应保持一个可点击的整体按钮，而不是把时间和命令入口拆成多个交互目标。用户点击胶囊中的任意位置都会打开或关闭命令面板。

视觉要求：

- 保留现有顶部栏的玻璃质感、描边和轻阴影。
- 胶囊高度跟现有 `GlassToolbarGroup` 保持一致，避免打破顶部栏节奏。
- 时间使用等宽数字效果，避免分钟变化时造成明显宽度跳动。
- `Open command` 和 `P` 在胶囊后半段展示，`P` 用键帽样式。
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
- 其他时间可以复用日落或补充夜间图标；本次实现优先满足用户明确提到的早上、下午、太阳落下三种状态。

## 测试与验证

这是 SwiftUI 顶部 chrome 的视觉和状态展示变更，核心命令行为不变。验证重点：

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
- 手动确认新胶囊显示时段图标、当前时间、`Open command` 和 `P` 键帽。
- 手动确认点击胶囊可以打开并关闭现有命令面板。
- 手动确认默认 UI 缩放下顶部栏左右控件没有重叠。
