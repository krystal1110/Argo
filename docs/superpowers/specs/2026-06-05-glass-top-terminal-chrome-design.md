# Glass Top And Terminal Chrome Design

## Goal

将 Argo 主窗口的顶部全局操作区和终端上方局部操作区调整为已确认的玻璃胶囊风格，视觉参考当前 HTML 方案 `terminal-reference-v13.html`。

目标效果：

- 最顶上采用一块一块的玻璃胶囊分组，接近用户参考图的图标尺度、间距和分类方式。
- 终端上方新增一层轻量局部栏，路径使用浅灰玻璃底，右侧局部动作图标透明底。
- 左侧工作区保持原始样式和交互，不参与这次视觉改造。
- 不引入不存在的 `Run` 功能。

## Scope

In scope:

- 重构主窗口顶部 toolbar 的视觉分组。
- 将顶部功能按“项目身份、命令入口、窗口/工具操作、外部编辑器”分块展示。
- 将终端 pane 顶部改为局部操作层：路径胶囊、创建新 tab、左右分屏、上下分屏。
- 将终端路径展示从 last path component 改为更完整的 abbreviated path，例如 `~/Documents/Claude 相关`。
- 保留终端右侧局部图标透明底，只用图标色表达可点击状态。
- 保留当前 context menu 中的终端高级操作。
- 保留现有 accessibility label、help 文案和 disabled 状态语义。

Out of scope:

- 不修改 `WorkspaceSidebarView`、`GlobalModeRailView` 和左侧 `NavigationSplitView` 的结构、尺寸、搜索框、repo 行、上下文菜单、拖拽、多选或键盘行为。
- 不改终端运行时、Ghostty bridge、pane layout 数据结构。
- 不新增 `Run`、任务执行器或 workflow runtime。
- 不重写窗口系统为完全自绘 titlebar，除非原生 toolbar 无法达到最低视觉要求并经过单独确认。
- 不调整文件树、web preview、overview、canvas 页面本身。

## Confirmed Visual Reference

当前确认稿：

- HTML: `.superpowers/brainstorm/2391-1780649308/content/terminal-reference-v13.html`
- Browser URL: `http://localhost:57779/`

关键视觉参数：

- Top global bar height: about `62px`.
- Top glass groups: about `38px` high, full capsule radius.
- Top icon target: about `28px`.
- Terminal local row height: about `44px`.
- Path pill: about `32px` high,浅灰玻璃底。
- Local terminal action icons: about `30px`, transparent background.
- Left workspace: original/sidebar style only; do not apply glass treatment there.

## Current System

`MainWindowView` 当前使用 native SwiftUI `.toolbar`:

- `ToolbarItem(placement: .navigation)` 包含 sidebar toggle。
- `ToolbarItemGroup(placement: .primaryAction)` 包含 quick command、workflow、HAPI、external editor、sleep prevention、command palette、split right、split down、new tab、file tree、web preview。
- 顶部按钮目前集中在一组里，视觉上更像连续 toolbar，不像参考图的独立玻璃块。

`WorkspaceDetailView` 当前负责主内容：

- 左侧由 `GlobalModeRailView`、`WorkspaceSidebarView` 和 `NavigationSplitView` 管理。
- 中间工作区通过 `WorkspaceSessionDetailView` 渲染 tab strip、terminal split tree 和 preview。

`TerminalPaneView` 当前负责单个 pane：

- 顶部 header 高度约 `30px`。
- 左侧展示 active/process dot、`session.title`、last path component、active/read-only tags。
- 右侧展示 search、read-only、zoom、close 四个小按钮。
- 分屏和 new tab 主要在全局 toolbar 和 context menu。

窗口配置在 `ArgoDesktopApplication`:

- `window.styleMask.remove(.fullSizeContentView)`
- `window.titleVisibility = .visible`
- `window.titlebarAppearsTransparent = false`
- `window.toolbarStyle = .unifiedCompact`

第一版实现应优先在现有 native toolbar 体系内完成，降低窗口行为风险。

## Proposed Design

采用“保留主布局，重做顶部和终端局部 chrome”的方案。

### 1. Top Global Chrome

顶部按功能归属拆成四组，而不是把所有按钮平铺：

1. Project group
   - 显示当前 workspace 名称，例如 `Claude 相关`。
   - 使用 folder/project 图标 + 文本。
   - 不改变左侧 workspace 选择逻辑，只展示当前选择。

2. Command group
   - 显示 command palette / quick command 入口。
   - 视觉上是居中的长玻璃胶囊。
   - 文案可保持类似 `Open Command Palette (⇧⌘P)`，具体本地化沿用现有 key。

3. Utility group
   - 放置全局或 focused-pane 工具图标，例如 command/search/preview/file tree/zoom 类入口。
   - 使用 28px 左右的 icon-only buttons。
   - 图标按组放入一个玻璃胶囊，避免顶部重新变拥挤。

4. External editor group
   - 保留 `VS Code` / preferred external editor 入口和 dropdown。
   - 保留现有 `store.openSelectedWorkspaceInPreferredExternalEditor()` 和 editor menu 行为。

视觉约束：

- 每个 group 都是独立 capsule，有轻内高光、弱描边和轻投影。
- 避免一整条重 toolbar 背景；分组之间留出明确空隙。
- 所有文字按钮都应有最大宽度和 truncation，避免中文 workspace 名称撑破布局。
- 小窗口宽度下优先压缩 project 文本和 command 文案，不压缩左侧工作区。

### 2. Terminal Local Chrome

终端 pane 顶部改为更轻的局部操作层。

左侧/中间：

- 使用 path pill 展示 `session.effectiveWorkingDirectory.abbreviatedPath`。
- 样式采用浅灰玻璃底：
  - 背景：接近 `rgba(221,227,235,0.165)` 的 material 效果。
  - 描边：接近 `rgba(255,255,255,0.235)`。
  - 文本：接近 `#f7f9fc`。
- 内容一行显示，过长时 tail truncation。

右侧：

- 三个局部动作图标透明底：
  - New tab: `plus` 或 `plus.rectangle.on.rectangle` 的轻量版本。
  - Split right: `rectangle.split.2x1` 系列。
  - Split down: `rectangle.split.1x2` 系列。
- 透明底表示“嵌在终端里”，不再像额外套了一排按钮。
- disabled 时降低 opacity，但不要加实体背景。

从终端局部栏移除的可见按钮：

- Search、read-only、zoom、close 不放在这条局部栏里。
- 这些能力保留在 context menu、快捷键或顶部 utility group 中，避免丢失功能。
- Close pane 继续作为 context menu 操作保留，不在默认局部栏显性出现，减少误触。

### 3. Left Workspace Constraint

左侧工作区完全沿用原始实现：

- 不修改 `WorkspaceSidebarView`。
- 不修改 `GlobalModeRailView`。
- 不修改 `NavigationSplitView` column width。
- 不修改 workspace 搜索、多选、context menu、drag reorder、工作区状态、repo badge。
- 不将玻璃胶囊样式应用到左栏。

这是本方案的硬边界。实现时如果需要创建 shared style，也不能让 shared style 自动影响左栏。

## Component Plan

建议新增或整理小型 chrome 组件，避免把所有样式塞进 `MainWindowView` 和 `TerminalPaneView`。

### `GlassToolbarGroup`

用途：

- 顶部 project、command、utility、editor 分组的统一 capsule。

职责：

- 提供 glass background、stroke、shadow、height。
- 支持 compact width 和 truncation。
- 不包含业务 action。

### `GlassToolbarIconButton`

用途：

- 顶部 utility group 内的 icon-only 按钮。

职责：

- 统一 28px hit target。
- 支持 active、disabled、hover 状态。
- 继续暴露 accessibility label 和 help。

### `TerminalLocalChrome`

用途：

- `TerminalPaneView` 中替代当前 pane header 的局部 chrome。

职责：

- 渲染浅灰 path pill。
- 渲染透明底 new tab / split right / split down actions。
- 根据 focused pane 状态决定可用性和轻量高亮。
- 不承载 search、close、read-only 等高级操作。

### `TransparentPaneActionButton`

用途：

- 终端局部栏右侧透明图标按钮。

职责：

- 统一 30px frame。
- 背景透明。
- hover 时只允许轻微 tint/opacity 变化，不能出现实心胶囊。

## Behavior

顶部行为保持现有 store action：

- Command palette: `store.dispatch(.toggleCommandPalette)`。
- External editor: `store.openSelectedWorkspaceInPreferredExternalEditor()` 和 `makeExternalEditorMenu()`。
- File tree: `store.selectedWorkspace?.toggleFileTree()`。
- Web preview: 保留现有 `webPreviewMenuContent`。
- Quick command / workflow / HAPI / sleep prevention 保留现有 menus 和 disabled state。

终端局部行为：

- New tab: `store.createTab(in: workspace)`。
- Split right: `store.splitFocusedPane(in: workspace, axis: .vertical)`。
- Split down: `store.splitFocusedPane(in: workspace, axis: .horizontal)`。
- 点击局部栏动作前应聚焦当前 `paneID`，避免 action 落到错误 pane。
- 无 focused pane 时 split actions disabled。

路径展示：

- 使用 `session.effectiveWorkingDirectory.abbreviatedPath`。
- 如果路径为空或不可用，fallback 到 `session.title` 或 existing `directoryLabel`。
- 中文和空格路径必须正确显示，不做 shell escaping。

## Layout And Responsive Rules

顶部：

- 保持 native toolbar 的最小窗口宽度约束。
- workspace 名称、command 文案、editor 名称都必须 lineLimit(1) + truncationMode(.tail)。
- 当宽度不足时，优先保留图标和 action 可点击区域，压缩文字。
- 不让 toolbar 内容侵入左侧 sidebar 或造成窗口标题栏控件重叠。

终端局部栏：

- 高度目标约 `44px`。
- Path pill 高度约 `32px`。
- 右侧透明 icon actions 固定宽高约 `30px`。
- Path pill 占剩余宽度，过窄时文字截断。
- 局部栏与 terminal surface 一体化，不额外加外层边框。

## Accessibility And Localization

- 所有 icon-only actions 必须保留 `.accessibilityLabel` 和 `.help`。
- 复用现有 localization keys；新增文案才新增 `L10n` key。
- 透明按钮 hover/disabled 状态不能只靠颜色表达，至少要有 opacity 或 symbol weight 差异。
- hit target 不小于当前 toolbar/pane header 的实际可点区域。

## Implementation Targets

Primary files:

- `Argo/UI/MainWindowView.swift`
  - 重组 toolbar 内容。
  - 引入 glass group 组件。
  - 将 split/new tab 从顶部主按钮组中移出或降级，避免和终端局部栏重复抢层级。

- `Argo/UI/Workspace/TerminalPaneView.swift`
  - 将 pane header 改为 `TerminalLocalChrome`。
  - 使用完整 abbreviated path。
  - 将右侧局部 actions 改为 new tab / split right / split down。
  - 保留 context menu 中的 search/read-only/zoom/close。

Likely supporting files:

- `Argo/UI/Components/` 或 `Argo/UI/Workspace/`
  - 新增小型 chrome component 文件，避免 `TerminalPaneView.swift` 继续膨胀。

- `Argo/Support/PathFormatting.swift`
  - 已有 `abbreviatedPath`，预期无需修改。

Files intentionally untouched:

- `Argo/UI/Sidebar/WorkspaceSidebarView.swift`
- `Argo/UI/Components/GlobalModeRailView` 所在文件
- `Argo/Services/Terminal/Ghostty/`
- `Argo/Vendor/`

## Alternatives Considered

### A. Keep Native Toolbar, Restyle Items

推荐第一版。风险最低，保留窗口系统行为、toolbar placement、menu、accessibility 和 localization。视觉可能无法做到完全自绘 titlebar 的透明融合，但足够接近已确认方向。

### B. Full Custom Titlebar With `fullSizeContentView`

视觉自由度最高，但会牵涉 window dragging、traffic lights、toolbar hosting、titlebar layout、safe area 和多窗口行为。当前需求只确认顶部和终端局部样式，不值得第一版承担这个风险。

### C. Only Change Terminal Header

不推荐。用户明确确认“最顶上和终端上面”的统一玻璃风格，只改终端会让整体语言断裂。

## Risks

- Native toolbar material 可能限制玻璃背景的真实透明感。
  - Mitigation: 先使用 capsule material/stroke/shadow 接近视觉；如果不够，再单独讨论 custom titlebar。

- 顶部按钮过多导致拥挤。
  - Mitigation: 按 group 合并，隐藏文字，优先保留图标和 dropdown。

- 从 pane header 移除 search/close 可见按钮后，老用户可能找不到。
  - Mitigation: 保留 context menu；把 search/zoom 类入口放顶部 utility group；help 文案和 command palette 入口继续可用。

- 终端局部 split action 可能误作用到上一个 focused pane。
  - Mitigation: 每个局部 action 先 focus 当前 `paneID` 再调用 store action。

- 左侧样式被 shared component 误影响。
  - Mitigation: glass component 只在 top toolbar 和 terminal local chrome 中使用，不修改 sidebar theme tokens。

## Testing

Automated:

- 如果只改 SwiftUI view composition，不一定需要新增 model tests。
- 如果新增 path formatting helper，补充 `PathFormattingTests`。

Build:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Manual smoke test:

- 打开 app，确认左侧 workspace 搜索、repo 列表、工作区切换仍是原始样式。
- 打开一个 workspace，确认顶部按 project / command / utility / editor 分组。
- 窄窗口下确认顶部文字截断但按钮不重叠。
- 在单 pane 下确认终端局部栏显示浅灰路径胶囊和透明 `+ / split / split`。
- 点击 `+` 创建新 tab。
- 点击 split right / split down，确认作用于当前 pane。
- 打开 terminal context menu，确认 search、read-only、zoom、close 等高级操作仍存在。
- 开启 terminal transparency 设置，确认局部栏和 terminal surface 仍保持一体感。

## Approval State

用户已确认 HTML 视觉方向进入方案编写阶段。当前方案冻结的关键约束是：

- 顶部和终端上方按参考图玻璃风格继续。
- 路径胶囊采用浅灰底方案。
- 右侧局部 terminal actions 背景透明。
- 左边工作区不修改，按照原始样式。
