# Argo Dynamic Island Open Vibe Parity Design

## 背景

Argo 现有灵动岛 beta 已经具备基础可用能力：顶部 `NSPanel`、收起/展开视图、workspace 快切、pane 级通知身份、点击跳回 workspace/worktree/pane、`argo notify`、系统通知 fallback，以及基础 prompt 写回 pane。

但它仍更像“通知列表”，还没有达到 `open-vibe-island` 的核心产品体验：一个围绕 agent session 的实时控制面。`open-vibe-island` 的优势在于它有稳定的 session/event reducer、notification card、可操作 approval/question 状态、收起态 live agents overview、展开态 session list、清晰的完成/空闲折叠，以及围绕 agent metadata 的展示派生逻辑。

用户确认 `open-vibe-island` 也是自己的项目，允许直接复制、改名、裁剪和适配其源码。因此本阶段不再只“借鉴思想”，而是采用“选择性移植 open-vibe-island 核心 + Argo 原生适配”的方案。

## 目标

1. 把 Argo 灵动岛从 beta 通知面板升级为 Argo-native agent/session 控制面。
2. 允许 approval/question 这类“申请/提问”在灵动岛中形成稳定记录，而不是一次性通知。
3. 直接复用 `open-vibe-island` 的 session reducer、surface、presentation 和 closed-island agents grid 设计，只做 Argo 命名、依赖和架构适配。
4. 保留 Argo 的 workspace/worktree/pane 路由优势，点击任何 session 都能回到正确 pane。
5. 保留 Argo 现有 `IslandPanelController` 的 AppKit 生命周期，不整文件替换 panel controller。
6. 扩展 `argo notify` 兼容旧协议，并支持 rich session event：approval、question、running activity、completion、failure。
7. 让收起态具备 live agents overview，展开态具备按状态分组的 session list。
8. 为 reducer、presentation、协议兼容、notification card、导航和响应写回补专项测试。

## 非目标

第一阶段不做以下内容：

- 不迁移 `open-vibe-island` 的完整外部 terminal 跳转矩阵。
- 不迁移 Claude/Codex/Gemini/OpenCode/Kimi/Cursor 的 hook installer。
- 不迁移 transcript discovery、usage dashboard、Watch/iPhone relay、Sparkle 更新模块。
- 不把 Argo 的 `IslandPanelController` 整体替换成 `OverlayPanelController`。
- 不重写 Argo 的 terminal、workspace、worktree 或 sidebar 架构。

这些能力后续可以拆成独立 parity 子项目。第一阶段先让 Argo 内置 terminal/pane 的灵动岛体验接近 `open-vibe-island` 的核心体感。

## 方案选择

### 方案 A：选择性移植 open-vibe 核心并适配 Argo

直接复制 `open-vibe-island` 中可复用的纯模型、reducer 和 SwiftUI presentation 逻辑，改名为 Argo 内部类型，并用 adapter 连接 Argo 的 workspace/pane/IPC。推荐此方案，因为它最快接近目标，也避免把已经验证过的 session surface 重新设计一遍。

### 方案 B：继续在现有 beta 上小步增强

在 `IslandNotificationState` 上继续加字段、排序和 UI。短期改动小，但会越来越像补丁堆叠，难以达到 open-vibe 的 session/event 结构。

### 方案 C：全量移植 open-vibe-island

把 app/core/bridge/hook/panel 体系大范围搬进 Argo。目标最完整，但会和 Argo 自带 terminal/workspace 模型重叠，风险和范围过大。

采用方案 A。

## 迁移来源

以下模块允许直接复制后改名、裁剪和适配：

- `/Users/liaojingyu/open-vibe-island/Sources/OpenIslandCore/AgentSession.swift`
  - 迁移 `AgentTool`、`SessionPhase`、`SessionAttachmentState`、`PermissionRequest`、`QuestionPrompt`、`QuestionOption`、`QuestionPromptResponse`、`PermissionResolution`、`AgentSession` 的核心字段。
  - Argo 版本命名为 `IslandAgentTool`、`IslandSessionPhase`、`IslandSessionAttachmentState`、`IslandPermissionRequest`、`IslandQuestionPrompt`、`IslandAgentSession`。
- `/Users/liaojingyu/open-vibe-island/Sources/OpenIslandCore/AgentEvent.swift`
  - 迁移事件枚举思想，命名为 `IslandSessionEvent`。
  - 保留 `sessionStarted`、`activityUpdated`、`permissionRequested`、`questionAsked`、`sessionCompleted`、`actionableStateResolved`。
  - 将 `jumpTargetUpdated` 替换为 Argo-native identity 更新。
- `/Users/liaojingyu/open-vibe-island/Sources/OpenIslandCore/SessionState.swift`
  - 迁移 pure reducer：`apply(_:)`、`resolvePermission`、`answerQuestion`、visibility、count、sorting。
  - 命名为 `IslandSessionState`。
- `/Users/liaojingyu/open-vibe-island/Sources/OpenIslandApp/IslandSurface.swift`
  - 迁移 notification card eligibility：approval/question/completed 触发单卡展示，状态不匹配时自动退出 notification card。
  - 命名为 `IslandSurface`，落在 `Argo/UI/Island/IslandSurface.swift`，避免后续实现出现双命名。
- `/Users/liaojingyu/open-vibe-island/Sources/OpenIslandApp/AgentSession+Presentation.swift`
  - 迁移 headline、prompt line、activity line、age badge、presence、stale completed 折叠、current tool display name。
  - 删除外部 terminal 专用逻辑，改用 Argo workspace/worktree/pane 元数据。
- `/Users/liaojingyu/open-vibe-island/Sources/OpenIslandApp/Views/V6NotchContent.swift`
  - 迁移 `AgentGridCell`、`IslandRightSlotContent`、agents grid balanced layout、waiting tile pulse、center label。
  - 融入 `IslandCollapsedView`。
- `/Users/liaojingyu/open-vibe-island/Sources/OpenIslandApp/Views/IslandPanelView.swift`
  - 迁移 session row 的信息架构和 action body 思路。
  - 不整文件复制，只提取 `IslandSessionRow`、approval/question/completion body 的结构，改造成 Argo 组件。

## Argo 适配边界

### `IslandSessionIdentity`

Argo 的 session identity 以现有字段为基础：

- `workspaceID: UUID`
- `worktreePath: String?`
- `paneID: UUID?`
- `sourceID: String?`
- `sessionID: String`

`sessionID` 由 `sourceID` 优先生成；没有 `sourceID` 时使用 `paneID`；没有 `paneID` 时退化到 workspace/worktree。这样旧 `argo notify` 仍能工作，新 rich event 可以精确表达同一 pane 中的多个 agent/task。

### `IslandAgentSession`

Argo session 是 presentation model，不拥有 `ShellSession`。它只保存：

- identity 与路由字段
- title、summary、initialPrompt、latestPrompt、lastAssistantMessage
- agent/tool 信息
- currentTool、commandPreview
- permissionRequest、questionPrompt
- phase、attachmentState、timestamps、lastError
- UI 可见性与 dismiss 状态

真正的输入写回仍由 `IslandResponseDispatcher` 经 `WorkspaceStore` 查找 pane 后调用 `ShellSession.insertText(_:)`。

### `IslandSessionState`

新增纯 reducer，负责：

- `sessionsByID`
- `apply(_ event:)`
- `resolvePermission(sessionID:resolution:)`
- `answerQuestion(sessionID:response:)`
- `dismissSession(id:)`
- `removeInvisibleSessions(referenceDate:)`
- `attentionCount`、`runningCount`、`liveSessionCount`
- `spotlightSession`
- `sessionSections`

`IslandNotificationState` 第一阶段保留类名作为 SwiftUI/Controller facade，内部持有 `IslandSessionState`。旧的 `items` 可以短期保留为 computed compatibility，逐步迁移 UI 到 sessions。

### `IslandSurface`

新增 surface 状态：

- `.sessionList(actionableSessionID: String? = nil)`

当 `permissionRequested`、`questionAsked`、非 interrupt 的 `sessionCompleted` 进入 reducer 时，panel 切到 notification card mode。若用户展开全部或状态已 resolved，回到 session list。

### `IslandPanelController`

保留现有 panel 创建、屏幕定位、刘海检测、mouse tracking、keyboard shortcut 和 `WorkspaceStore` 连接。吸收 open-vibe 的行为，但不替换控制器：

- 增加 `surface`、`openReason`、`measuredNotificationContentHeight`
- notification card 使用更贴内容的高度
- 用户 hover 时保留 notification card，离开后按规则折叠
- `navigateToSession(_:)` 走现有 `IslandWorkspaceNavigator`
- `respondToSession(_:)` 走现有 `IslandResponseDispatcher`

## 协议与数据流

### 旧 `argo notify`

旧字段保持兼容：

- `title`
- `body`
- `pane`
- `workspace`
- `agent`

旧请求会映射为 `.activityUpdated` 或 `.sessionStarted`，默认 phase 为 `.running`。

### Rich notify

扩展 `AgentNotifyRequest`，新增可选字段：

- `kind`: `activity | approval | question | completed | failed`
- `session`: stable session id
- `source`: source id
- `status`: running/completed/failed/waiting
- `tool`: agent tool name
- `currentTool`
- `commandPreview`
- `initialPrompt`
- `latestPrompt`
- `assistantMessage`
- `options`
- `responseText`

CLI 可增加语义化参数：

- `argo notify --approval --title ... --body ... --option "Allow=1\n" --option "Deny=2\n"`
- `argo notify --question --prompt ... --option Production --option Staging`
- `argo notify --completed --summary ...`
- `argo notify --failed --summary ...`

第一阶段不要求 hook 阻塞等待 response。approval/question 的 UI 操作通过写回 pane 来完成，符合 Argo 内置 terminal 的工作方式。

### OSC / Ghostty 通知

`WorkspaceRuntime.postAgentNotification` 从直接构造 item 改为构造 `IslandSessionEvent`：

- title/body 进入 summary
- paneID 进入 identity
- agentName 映射 tool/name
- 默认 phase 为 running

### Workspace status message

`WorkspaceStore.receive(.statusMessage)` 继续支持 dynamic island enabled 时写入灵动岛，但改成 ephemeral session event：

- success -> completed
- warning/error -> failed
- neutral -> running/activity

### Approval / Question 写回

`IslandResponseDispatcher` 接收 sessionID 和 action：

- approval allow/deny：写入配置好的 response text，默认追加换行。
- question answer：写入选项 label 或 responseText。
- 成功后发 `.actionableStateResolved`。
- 失败时保留 waiting 状态，写 `lastError`，并允许用户点击跳回 pane。

## UI 设计

### 收起态

`IslandCollapsedView` 迁移 open-vibe 的 closed pill 思路：

- 左侧或中心显示 spotlight label：workspace、agent action 或 session title。
- 右侧显示 `IslandRightSlotContent`：
  - `count(Int)`：session 数量。
  - `agents([AgentGridCell])`：每个 live session 一个小方块，running 全亮，idle 低透明度，waiting 呼吸闪烁，超过数量显示 overflow。
- 刘海屏保留物理 notch gap；外接屏使用完整 pill。

spotlight 优先级：

1. waitingForApproval / waitingForAnswer
2. failed
3. running
4. 最近 completed
5. idle

### 展开态

`IslandExpandedView` 保留 `Workspaces` tab，重做 `Sessions` tab：

- 顶部展示 sessions 标题、attention/running/live count。
- 支持分组：
  - Needs Approval
  - Needs Answer
  - Running
  - Just Done
  - Idle
- 每行展示：
  - status indicator
  - headline：workspace + branch + prompt
  - prompt line：`You: ...`
  - activity line：当前 tool/command/summary
  - agent badge
  - pane/workspace badge
  - age badge
  - 展开/折叠 control

### Notification Card

approval/question/completed 事件触发 card mode：

- 只显示当前 actionable session。
- 有多个 session 时显示 `Show All`。
- approval card 展示 command preview、affected path、Allow/Deny/Allow once 等操作。
- question card 展示问题和 options。
- completion card 展示完成摘要和可选 reply 输入。

### 错误和 stale

- pane 缺失：session 标记 stale，保留错误 “Pane is no longer available.”。
- workspace 缺失：session 标记 stale，允许 dismiss。
- response 写入失败：保持 waiting，显示 “Could not send response to the pane.”。
- navigation 成功可按状态决定是否自动 dismiss；waiting 不自动消失，completed 可进入 Just Done。

## 文件结构

新增或重写：

- `Argo/Domain/IslandAgentModels.swift`
- `Argo/Domain/IslandSessionEvent.swift`
- `Argo/Support/IslandSessionState.swift`
- `Argo/Support/IslandSessionPresentation.swift`
- `Argo/UI/Island/IslandSurface.swift`
- `Argo/UI/Island/IslandClosedAgentsGrid.swift`
- `Argo/UI/Island/IslandSessionRow.swift`
- `Argo/UI/Island/IslandSessionSections.swift`

修改：

- `Argo/Domain/IslandNotificationModels.swift`
- `Argo/Support/IslandNotificationState.swift`
- `Argo/Support/IslandResponseDispatcher.swift`
- `Argo/Support/IslandWorkspaceNavigator.swift`
- `Argo/Support/WorkspaceNotificationCenter.swift`
- `Argo/App/ArgoDesktopApplication.swift`
- `Argo/App/WorkspaceStore.swift`
- `Argo/Domain/WorkspaceRuntime.swift`
- `Argo/Services/AgentNotify/AgentNotifyProtocol.swift`
- `Argo/Services/AgentNotify/AgentNotifyCLI.swift`
- `Argo/Services/AgentNotify/ArgoControlProtocol.swift`
- `Argo/UI/Island/IslandPanelController.swift`
- `Argo/UI/Island/IslandContentView.swift`
- `Argo/UI/Island/IslandCollapsedView.swift`
- `Argo/UI/Island/IslandExpandedView.swift`
- `Argo/Support/L10n.swift`

测试：

- `Tests/IslandSessionStateTests.swift`
- `Tests/IslandSessionPresentationTests.swift`
- `Tests/IslandSurfaceTests.swift`
- `Tests/IslandClosedAgentsGridTests.swift`
- `Tests/IslandRichNotifyProtocolTests.swift`
- 更新 `Tests/IslandResponseDispatcherTests.swift`
- 更新 `Tests/IslandWorkspaceNavigatorTests.swift`
- 更新 `Tests/IslandSessionCenterTests.swift`
- 更新 `Tests/AgentNotifyCLITests.swift`
- 更新 `Tests/AgentNotifyProtocolTests.swift`

## 测试计划

### Reducer

- `sessionStarted` 创建 session。
- 同 identity 的 activity 更新同一 session。
- `permissionRequested` 进入 waitingForApproval 并保留 request。
- `questionAsked` 进入 waitingForAnswer 并保留 prompt。
- running activity 不覆盖 pending approval/question。
- `actionableStateResolved` 清除 pending 并回 running。
- completed 进入 Just Done。
- failed 保留错误并排在 running 前。
- stale completed 超过阈值折叠为 idle。

### Presentation

- headline 使用 workspace + branch + prompt。
- current tool 显示 humanized name。
- age badge 覆盖秒/分/时/天。
- presence 覆盖 running/active/inactive。
- closed agents grid 1 到 9 个 session 的 balanced rows 正确。
- waiting tile 状态映射为 waiting。
- overflow 显示正确数量。

### Protocol

- 旧 `AgentNotifyRequest` decode/encode 不变。
- rich fields round trip。
- CLI `--approval` 生成 approval kind。
- CLI `--question --option` 生成 question prompt。
- pane/workspace/env fallback 不变。

### UI / Controller

- notification card 只显示 actionable session。
- `Show All` 回到 session list。
- clear completed 不删除 waiting/running。
- screen cycle、notch gap、persistent setting 不回退。

### Navigation / Response

- session 点击聚焦 workspace/worktree/pane。
- pane missing 标记 stale。
- approval option 写回 pane 并 resolved。
- question option 写回 pane 并 resolved。
- send failure 保留 waiting 和 lastError。

### Verification

实现完成后运行：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionStateTests \
  -only-testing:ArgoTests/IslandSessionPresentationTests \
  -only-testing:ArgoTests/IslandSurfaceTests \
  -only-testing:ArgoTests/IslandClosedAgentsGridTests \
  -only-testing:ArgoTests/IslandRichNotifyProtocolTests \
  test
```

最后运行：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  test
```

手动 smoke：

1. 启用灵动岛，两个 pane 同时触发 running notify，确认收起态 agents grid 和展开态分组正确。
2. 触发 approval rich notify，确认 notification card 出现，Sessions 中保留记录。
3. 点击 Allow/Deny，确认文本写回正确 pane，session 变 running 或 completed。
4. 触发 question rich notify，确认 options 可点击并写回 pane。
5. 触发 completed/failed，确认排序、Just Done、错误展示和 stale 折叠正确。
6. 点击任意 session，确认回到对应 workspace/worktree/pane。

## 风险与缓解

- 风险：直接迁移 open-vibe UI 类型导致 Argo UI 文件过大。
  - 缓解：只复制需要的子组件，拆成 `IslandSessionRow`、`IslandClosedAgentsGrid`、`IslandSessionPresentation`。
- 风险：旧 `IslandNotificationItem` 与新 session model 并存造成双状态。
  - 缓解：第一阶段让 `IslandNotificationState` 成为 facade，内部只以 `IslandSessionState` 为真源；旧 `items` 仅作兼容 derived view。
- 风险：rich notify 未接入真实 hook 阻塞，approval 体验不如 open-vibe 完整。
  - 缓解：本阶段通过 Argo pane 写回实现闭环；hook installer/阻塞响应作为后续 parity 子项目。
- 风险：open-vibe 的外部 terminal label 与 Argo pane label 概念不同。
  - 缓解：所有 presentation 派生优先使用 Argo workspace/worktree/pane metadata。
- 风险：notification card auto-height 与现有 panel 动画冲突。
  - 缓解：不替换 panel controller，只局部增加 measured height 和 surface mode。

## 后续子项目

第一阶段完成后，再拆以下 spec：

1. `open-vibe` hook installer parity：Codex/Claude/Gemini/OpenCode hooks。
2. 外部 terminal jump parity：Terminal/iTerm/WezTerm/tmux/Warp。
3. session discovery parity：transcript/process discovery。
4. usage dashboard parity。
5. Watch/iPhone relay parity。
