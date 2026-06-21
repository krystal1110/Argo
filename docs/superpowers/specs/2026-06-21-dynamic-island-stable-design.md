# Dynamic Island Stable Design

## 背景

Argo 现有灵动岛已经具备基础浮层能力：`IslandPanelController` 管理顶部 `NSPanel`，`IslandNotificationState` 存储通知列表，`IslandCollapsedView` 和 `IslandExpandedView` 渲染收起与展开状态，`WorkspaceRuntime.postAgentNotification` 与 `WorkspaceStore.receive(.statusMessage)` 能把终端通知和状态消息送入灵动岛。

当前实现仍接近 beta 状态。主要问题是它把灵动岛当成通知列表，而不是 agent/session 控制面：同一 workspace/worktree 下多个 pane 的通知会互相覆盖；item 没有 pane 级稳定身份；点击只能跳到 workspace/worktree，不能保证聚焦具体 pane；prompt 行只是跳转，没有真正把选项或回答送回 agent；通知生命周期、排序和失败反馈也不够明确。

参考项目 `Octane0411/open-vibe-island` 的核心体验是：在 Mac 刘海或顶部区域展示实时 agent session、权限请求、问题回答和一键跳回正确终端。Argo 是自带 terminal/workspace/worktree 模型的 macOS app，因此第一阶段采用 Argo-native 对齐：实现同等核心体验，但不复制 GPLv3 项目代码，也不在第一阶段引入外部终端/IDE 全矩阵。

## 目标

1. 灵动岛从“通知提示”升级为 Argo 内部 agent/session 控制面。
2. item 身份精确到 `workspaceID + worktreePath + paneID + sourceID`，多个 pane 不互相覆盖。
3. 点击 item 能切到对应 workspace、切到 worktree、聚焦 pane，并把窗口带到前台。
4. approval/question 类 item 能真正响应 agent；失败时保留可操作状态并给出明确反馈。
5. 收起态和展开态都优先展示需要用户处理的 item，其次运行中，最后最近完成。
6. 灵动岛关闭时不吞通知；继续保留系统通知与 toast 的 fallback。
7. 为 reducer、路由、响应、通知兼容路径补专项单测。

## 非目标

第一阶段不实现以下内容：

- 不直接复制或移植 `open-vibe-island` 源码。
- 不做 Claude/Codex/Cursor/Gemini/OpenCode 的 hook installer。
- 不做 Terminal.app、iTerm2、Warp、WezTerm、Zellij、JetBrains、VS Code 等外部终端/IDE 跳转矩阵。
- 不做 iPhone/Watch relay、usage dashboard、Sparkle 更新流程。
- 不重写 Argo 的 `AppKit container + SwiftUI content` 架构。

这些能力可以在 Argo-native session 控制面稳定后拆成独立 spec。

## 方案选择

### 方案 A：Argo-native 完整可用版

保留现有 `IslandPanelController` 和 SwiftUI 视图大体结构，把业务状态升级为 pane/session 级 reducer，并通过 Argo 已有 workspace、worktree、pane、IPC 能力闭环。推荐此方案，因为它最贴合 Argo 架构，也能先解决用户感受到的 beta 问题。

### 方案 B：全量 Open Island companion 对齐

实现完整 hook installer、外部终端跳转、usage dashboard 和多 agent bridge。这是多个独立子系统，范围过大，应拆成多轮 spec。

### 方案 C：只做 UI polish

调整视觉、动画和设置项，但不解决状态模型、pane 聚焦和响应闭环。此方案不能满足“完全可用”的目标。

采用方案 A。

## 架构

### `IslandSessionCenter`

替代或包裹现有 `IslandNotificationState`，成为灵动岛业务状态的唯一入口。

职责：

- 存储 `[IslandSessionItem]`。
- 根据稳定 key upsert item。
- 维护 `isExpanded`、`selectedTab`、`currentGroupID` 等 UI 状态。
- 提供 `priorityItems`、`latestItem`、`attentionCount`、`badgeCount` 等派生状态。
- 提供 `post(_:)`、`resolve(_:)`、`dismiss(_:)`、`clearCompleted()`、`clearAll()`。
- 不直接调用 AppKit、workspace store 或 terminal session。

`IslandNotificationState` 可先作为兼容 facade 保留，逐步把调用方迁到 `IslandSessionCenter`，避免一次性重命名造成大范围 churn。

### `IslandSessionItem`

表示灵动岛里的一个可渲染 session/item。

核心字段：

- `id: UUID`
- `identity: IslandSessionIdentity`
- `workspaceID: UUID`
- `worktreePath: String?`
- `paneID: UUID?`
- `sourceID: String?`
- `title: String`
- `body: String?`
- `agentName: String?`
- `terminalTag: String?`
- `status: IslandSessionStatus`
- `startedAt: Date`
- `updatedAt: Date`
- `action: IslandSessionAction?`
- `lastError: String?`

`IslandSessionIdentity` 的 equality 不依赖 `id`，而是依赖 `workspaceID`、`worktreePath`、`paneID`、`sourceID`。如果没有 `sourceID`，用 `paneID` 作为主要来源；如果也没有 `paneID`，退化为 workspace/worktree 级 identity。

`IslandSessionStatus`：

- `running`
- `waitingForApproval`
- `waitingForAnswer`
- `completed`
- `failed`
- `stale`

### `IslandSessionRouter`

把“点击 item 后导航”的细节从 UI 和 panel controller 中拆出来。

职责：

- 根据 `workspaceID` 找到对应 `ArgoDesktopApplication` window context。
- 调用 `context.present(ignoringOtherApps: true)`。
- 调用 `WorkspaceStore.selectWorkspace(_:)`。
- 如果 `worktreePath` 不同，调用 `WorkspaceModel.switchToWorktree(path:restartRunning:)`。
- 如果 `paneID` 存在且 session 仍存在，调用 `WorkspaceModel.focusPane(_:)`。
- 返回明确结果：`.focusedPane`、`.focusedWorkspace`、`.workspaceMissing`、`.paneMissing`。

现有 `ArgoDesktopApplication.navigateToWorkspace(id:worktreePath:)` 可扩展为支持 `paneID`，或由 router 复用其逻辑。

### `IslandResponseDispatcher`

处理 approval/question 行的动作。

职责：

- 接收 `IslandSessionAction` 和用户选择。
- 如果 item 有 `paneID` 且 pane 存活，通过 `ShellSession.insertText(_:)` 写入 response text。
- 对简单选项自动追加换行；对自由文本回答保持用户输入。
- 成功后把 item 状态更新为 `running` 或 `completed`，并清除 `lastError`。
- 如果 pane 不存在或发送失败，保持 item 为 waiting 状态，写入 `lastError`，并可触发跳转到 workspace。

第一阶段优先支持 Argo 内置 pane。外部 hook directive、Claude/Codex 专用 approval protocol 在后续 spec 中设计。

## 数据流

### 终端 OSC / Ghostty 通知

1. Ghostty 触发 `GHOSTTY_ACTION_DESKTOP_NOTIFICATION`。
2. `ArgoGhosttyController` 发出 `.desktopNotification(title:body:)`。
3. `WorkspaceRuntime.handleWorkspaceAction` 携带当前 `paneID` 调用 `postAgentNotification`。
4. `postAgentNotification` 构造 `IslandSessionEvent.notification`，写入 `IslandSessionCenter`。
5. 灵动岛显示或更新对应 pane 的 item。

### `argo notify`

1. CLI 通过 Unix socket 发出 `AgentNotifyRequest`。
2. `ArgoDesktopApplication.routeAgentNotification` 按显式 workspace、pane、当前 workspace 解析目标。
3. 解析结果携带 `paneID`、`workspaceID`、`agentName` 写入 `IslandSessionCenter`。
4. 若无法解析 pane，仍以 workspace 级 item 呈现。

### Workspace 状态消息

1. `WorkspaceStore.receive(.statusMessage(...))` 判断动态岛是否启用。
2. 启用时写入 ephemeral/session item；未启用时维持 toast + system notification。
3. 成功 tone 进入 `completed`，其他 tone 进入 `running` 或 `failed`。

### Approval / Question

1. 事件进入 `IslandSessionCenter` 后生成 `waitingForApproval` 或 `waitingForAnswer` item。
2. UI 展示操作按钮。
3. 用户点击操作，`IslandResponseDispatcher` 尝试把 response 写入 pane。
4. 成功时更新 item；失败时保留 item 并显示错误。

## UI

### 收起态

收起态只展示一个最高优先级 item：

1. `waitingForApproval` / `waitingForAnswer`
2. `failed`
3. `running`
4. 最近 `completed`
5. 空闲态显示 ARGO 和像素动画

有多个 item 时显示 badge。无刘海屏使用标准横向 pill；有刘海屏保留现有左右分区布局，避免内容被物理刘海遮挡。

### 展开态

保留 tab 结构：

- `Workspaces`：继续提供 workspace/group 快切。
- `Sessions`：替代 Notifications，展示所有 active/recent item。

Sessions 排序：

1. 需要处理
2. 失败
3. 运行中
4. 最近完成

每行展示：

- 状态 icon
- title/body
- agent tag
- pane tag 或短 pane ID
- elapsed time
- error text
- 操作按钮

Prompt/approval 行采用 inline 操作区。普通 completed/running 行点击跳转。

## 错误处理

- workspace 不存在：item 标记 `stale`，展示“Workspace no longer available”，允许 dismiss。
- worktree 不存在：跳 workspace，item 保留 warning。
- pane 不存在：跳 workspace/worktree，item 标记 `stale`，操作按钮禁用。
- response 写入失败：item 保留 waiting 状态，`lastError` 展示失败原因。
- 灵动岛关闭：不写入灵动岛，继续系统通知与 toast。
- 系统通知点击：继续支持 `workspaceID` 和 `worktreePath`；后续可扩展 `paneID`。

## 测试计划

### Unit tests

新增 `Tests/IslandSessionCenterTests.swift`：

- 不同 pane 的通知不互相覆盖。
- 同一 identity 的新事件更新原 item，保留稳定 `id`。
- waiting 状态优先于 running/completed。
- failed 优先于 running。
- dismiss 只删除目标 item。
- clearCompleted 不删除 waiting/running。
- pane 缺失事件退化为 workspace 级 identity。

新增 `Tests/IslandSessionRoutingTests.swift`：

- route 到 workspace + worktree + pane。
- pane 不存在时仍切 workspace/worktree，并返回 `.paneMissing`。
- workspace 不存在返回 `.workspaceMissing`。

新增 `Tests/IslandResponseDispatcherTests.swift`：

- approval allow 写入预期文本并更新状态。
- question answer 写入预期文本并更新状态。
- pane 不存在时保留 waiting 状态并记录 error。
- 发送失败不 dismiss item。

更新现有 notification/control tests：

- `WorkspaceNotificationCenter` 的 `userInfo` 继续兼容旧字段。
- `AgentNotifyRequest` 的 pane/workspace 路由覆盖 island identity。

### Build verification

实现阶段完成后运行：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  test
```

至少也要运行相关测试文件的 focused test。

### Manual smoke

实现阶段完成后手动覆盖：

1. 启用灵动岛，在两个 pane 分别触发 OSC 9/777，确认两条 item 同时存在。
2. 点击每条 item，确认跳回对应 workspace/worktree/pane。
3. 用 `argo notify --pane <id>` 触发通知，确认 pane tag 与跳转正确。
4. 模拟 prompt/approval item，确认按钮能写回 pane。
5. 切外接屏/无刘海屏，确认 fallback top-center bar 可用。
6. 关闭灵动岛，确认系统通知/ toast 不被吞。

## 分阶段实施

### Phase 1：状态模型与测试

新增 `IslandSessionIdentity`、`IslandSessionStatus`、`IslandSessionItem`、`IslandSessionCenter`，用测试锁定 identity、排序、dismiss、clear 行为。

### Phase 2：入口迁移

把 `WorkspaceRuntime.postAgentNotification`、`WorkspaceStore.receive(.statusMessage)`、`routeAgentNotification` 的输出迁到新 center，保留兼容 API。

### Phase 3：精确跳转

扩展导航路径支持 `paneID`，并接入 island row click。

### Phase 4：响应闭环

新增 `IslandResponseDispatcher`，让 approval/question 可以写回 pane，失败时保留错误状态。

### Phase 5：UI 稳定化

把 Notifications tab 升级成 Sessions tab，补充状态排序、错误展示、操作按钮和本地化。

### Phase 6：验证与文档

补测试、运行 build/test、更新 `docs/guides/agent-notifications.md` 中的灵动岛行为说明。

## 风险

- `IslandNotificationState` 被多个 UI 文件直接引用，迁移需要兼容层，避免一次性改动太大。
- SwiftUI row 操作按钮与 hover auto-expand 可能互相影响，需要手动 smoke。
- `ShellSession.insertText` 是最实用的第一阶段响应方式，但不是所有 agent 的正式 approval protocol；后续仍需按 agent hook 补专用 directive。
- 当前工作区已有未提交设置面板/本地化改动，实施时必须只改本功能相关文件，避免覆盖用户工作。

## 完成标准

- 多 pane 通知不覆盖。
- 点击 item 能聚焦到对应 pane。
- waiting item 在收起态和展开态都优先出现。
- approval/question 至少支持 Argo 内置 pane 的写回路径。
- 失败路径不静默吞掉，UI 有可见错误。
- 灵动岛关闭时系统通知 fallback 可用。
- 相关 unit tests 和一次 `xcodebuild ... test` 通过，或明确记录外部环境导致的不可运行原因。
