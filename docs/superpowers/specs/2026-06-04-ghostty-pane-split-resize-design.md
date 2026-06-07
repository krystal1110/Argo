# Ghostty Pane Split Resize Design

## Goal

让 Argo 的 Ghostty 终端分屏支持通过拖动分割线调整占比，行为与已确认的 HTML 原型一致：例如“上方一个 pane、下方两个 pane”的嵌套布局中，拖动中间横向分割线只调整上下占比，拖动下方纵向分割线只调整下方左右占比。

## Scope

In scope:

- 支持鼠标拖动分割线调整 `PaneSplitNode.fraction`。
- 支持纵向 split 的左右占比调整和横向 split 的上下占比调整。
- 嵌套 split 每一层独立调整，拖动一个 divider 不影响兄弟层以外的 split fraction。
- 拖动时实时更新布局，释放后保持最终比例。
- 继续使用现有 workspace/tab 状态保存与恢复比例。
- 强化 divider 的 hover、drag 视觉状态和 resize cursor，让分割线更容易发现和操作。
- 保持当前最小/最大比例约束，避免 pane 被拖到不可用。

Out of scope:

- 不新增键盘快捷键。
- 不新增 command palette action。
- 不引入 `NSSplitView` 重写布局容器。
- 不修改 Ghostty vendored runtime。
- 不改变 pane 创建、关闭、聚焦、zoom、equalize 的现有语义。

## Current System

布局数据已经支持 split ratio：

- `PaneSplitNode` 持有 `id`、`axis`、`fraction`、`first`、`second`。
- `SessionLayoutNode.updateFraction(splitID:fraction:)` 会按 split id 更新比例，并 clamp 到 `0.12...0.88`。
- `WorkspaceModel.updateSplitFraction(splitID:fraction:)` 更新 layout 后调用 `saveActiveWorktreeState()`。
- `SplitNodeView` 根据 `PaneSplitNode.axis` 递归渲染 split，并在 `SplitDivider` 拖动时调用 `workspace.updateSplitFraction`。

这意味着正式实现不需要新增持久化格式。要补强的是 UI divider 的交互可靠性、视觉可发现性和 nested split 的测试覆盖。

## Proposed Approach

采用“强化现有 SwiftUI split divider”的方案。

`SplitNodeView` 继续递归渲染 `SessionLayoutNode`。每遇到一个 `PaneSplitNode`，根据 `axis` 计算当前层的 `availableLength`，并把对应的 split id、axis、当前 fraction 传给 divider。divider 使用拖拽手势把 pointer translation 转成新的 fraction，然后调用 `WorkspaceModel.updateSplitFraction(splitID:fraction:)`。

拖动语义：

- `axis == .vertical` 时，divider 是竖线，左右 pane 用 `HStack` 排列，水平拖动改变 `first` 的宽度占比。
- `axis == .horizontal` 时，divider 是横线，上下 pane 用 `VStack` 排列，垂直拖动改变 `first` 的高度占比。
- nested split 自然递归：每个 divider 只持有自己的 split id，所以只更新自己那一层。

视觉语义：

- divider 保持小厚度，避免占用终端空间。
- hover 时提高背景和 handle 对比度。
- drag 时维持高亮状态，给用户明确反馈。
- 纵向 divider 使用左右 resize cursor，横向 divider 使用上下 resize cursor。
- handle 尺寸稳定，避免 hover/drag 导致布局跳动。

## Alternatives Considered

### A. Strengthen the Existing SwiftUI Divider

推荐方案。复用已有模型、持久化和递归渲染，改动集中在 `SplitNodeView` 和少量布局测试。风险低，能直接实现确认过的原型行为。

### B. Replace the Split Container with `NSSplitView`

不推荐。`NSSplitView` 原生支持 divider resize，但会把当前 SwiftUI 递归布局、terminal host 生命周期、pane focus、zoom 和状态保存都拉进更大重写。这个需求不需要这样的成本。

### C. Only Update Model Tests Without UI Polish

不推荐。模型已经基本具备 fraction 更新能力，只补测试不能解决用户真正感知到的“分割线是否能拖、是否好发现、拖动是否顺手”的问题。

## Components

### `Argo/UI/Workspace/SplitNodeView.swift`

Primary implementation target.

Responsibilities:

- 根据 split axis 渲染 pane、divider、pane。
- 为 divider 提供当前 split id、axis、fraction、available length。
- 在 drag change 时调用 `workspace.updateSplitFraction(splitID:fraction:)`。
- 为 divider 添加 hover 和 drag state。
- 为 divider 添加 axis-specific cursor。
- 保持 min sizes 和 fraction clamp 一致。

### `Argo/Domain/PaneLayout.swift`

Likely unchanged, unless tests reveal a small helper is needed.

Responsibilities already present:

- `updateFraction(splitID:fraction:)` 定位并更新任意嵌套 split。
- clamp fraction to `0.12...0.88`。
- `equalizeSplits()` 保持现有行为。

### `Tests/PaneLayoutTests.swift`

Add focused model tests.

Responsibilities:

- 验证 `updateFraction` 会 clamp 低于 12% 和高于 88% 的输入。
- 验证 nested split 中更新 inner split 不会改变 outer split fraction。
- 验证 nested split 中更新 outer split 不会改变 inner split fraction。

## Data Flow

1. User drags a visible split divider in `SplitNodeView`.
2. Divider converts drag distance to a candidate fraction using current axis and available length.
3. `SplitNodeView` calls `workspace.updateSplitFraction(splitID:fraction:)`.
4. `WorkspaceModel` mutates the current `SessionLayoutNode`.
5. `SessionLayoutNode.updateFraction` finds the matching split id, clamps the fraction, and updates only that split.
6. `WorkspaceModel` publishes the updated layout and saves active worktree state.
7. SwiftUI re-renders the recursive split tree with the new fraction.

## Edge Cases

- If the split is too small, `availableLength` must never divide by zero.
- If a drag tries to move beyond limits, fraction clamps to `0.12...0.88`.
- If the workspace is zoomed to a single pane, split dividers are not rendered.
- If a pane closes while layout is re-rendering, missing sessions continue to render `Color.clear` as they do today.
- If there is no matching split id, `updateFraction` returns false and layout is not saved.

## Testing

Automated:

- Add `PaneLayoutTests` for fraction clamping.
- Add `PaneLayoutTests` for nested split isolation.
- Run focused tests:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/PaneLayoutTests \
  test
```

Verification:

- Run at least one app build because this touches SwiftUI workspace UI:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Manual smoke test:

- Open a workspace with one terminal.
- Split down to create top/bottom panes.
- Focus the bottom pane and split right to create the “top one, bottom two” nested layout.
- Drag the middle horizontal divider and confirm only top vs bottom changes.
- Drag the lower vertical divider and confirm only lower left vs lower right changes.
- Close and reopen or switch away/back, then confirm ratios persist.

## Acceptance Criteria

- Users can drag split dividers to resize Ghostty panes.
- The confirmed “top one, bottom two” layout behaves like the HTML prototype.
- Nested divider drag updates only the corresponding split fraction.
- Dragging respects existing min/max fraction limits.
- Divider hover and drag states make the resize affordance obvious.
- Ratios are saved through existing workspace/tab state.
- Focused `PaneLayoutTests` pass.
- App builds successfully.
