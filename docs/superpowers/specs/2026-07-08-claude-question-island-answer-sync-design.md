# Claude 问题回答与灵动岛状态同步设计

## 背景

Argo 的灵动岛通过 `AgentNotifyRequest(kind: .question)` 展示 Claude `AskUserQuestion` 的选项。当前进入链路已经存在：

- `ClaudeHookNotifyBridge` 将 Claude `PermissionRequest + AskUserQuestion` 转为 `AgentNotifyRequest(kind: .question)`。
- `WorkspaceRuntime.postAgentNotification(...)` 将 request 转为 `sessionStarted + questionAsked`。
- `IslandSessionState.answerQuestion(...)` 已能把 session 从 `.waitingForAnswer` 切回 `.running`，清掉 `questionPrompt`，并显示 `Answered: <选项>`。

问题是回答来源不统一：用户在灵动岛内点选项时，状态会被清理；用户在 Claude 终端内完成选项后，灵动岛仍停留在选项页。

## 目标

- 用户在 Claude 终端内选择问题选项后，灵动岛不再停留在选项页。
- 灵动岛显示 `Answered: <选项>`，并从 `.waitingForAnswer` 回到 `.running`。
- 用户在灵动岛内选择选项时仍能让 Claude hook 继续，并展示同样的回答摘要。
- 不改变 approval 权限请求的现有镜像写回行为。

## 非目标

- 不重做完整 Claude hook lifecycle。
- 不改灵动岛 UI 组件的布局或视觉样式。
- 不改变 `AgentNotifyRequest` 的 wire format。

## 方案

采用统一回答语义：任何 Claude question 的完成来源都最终进入 `IslandSessionState.answerQuestion(sessionID:response:)` 等价路径。

实现会放在 Claude hook / notification 边界附近，而不是 UI 组件里。UI 继续只读取 `IslandNotificationState`。当系统确认某个 Claude question 已被回答时，根据 session id 找到当前 session 的 `questionPrompt`，解析选中的展示文本，然后发布清理 waiting 状态的事件。

### 灵动岛内选择

`IslandResponseDispatcher.respond(toSessionID:with:)` 仍然优先调用 `ClaudeHookInteractionRegistry.resolve(...)`，让 Claude hook 获得响应。成功后不再只发布通用 `Response sent.`，而是按 question prompt 解析选项，并使用回答语义更新 session：

- 找到匹配的 `responseText`：显示 `Answered: <option.label>`。
- 找不到匹配但确认已发送：显示 `Answered the question.`。

approval session 保持现有行为，仍可镜像原生 prompt 文本到 pane。

### Claude 终端内选择

当 Claude 原生选择完成并且 Argo 能在 hook/control 边界确认该 session 的 question 已回答时，主线程向 `IslandNotificationState.shared` 投递同样的回答语义。该路径不写回 pane，只清理灵动岛状态。

Claude `AskUserQuestion` 的答案以 question text 到选项 label 的 `answers` object 表达。实现阶段的提取顺序固定为：

- 如果 hook frame 是 `PostToolUse` 且 `tool_name == "AskUserQuestion"`，优先从 `tool_input.answers` 提取 label。
- 如果 `tool_response` 中包含等价的 answers / answer / content 字段，再作为兼容来源读取。
- 如果外部事件只提供 response text，则按当前 `questionPrompt.options.responseText` 匹配。
- 如果外部事件只提供 label，则按当前 `questionPrompt.options.label` 匹配。
- 匹配失败但能确认回答完成时，使用空回答摘要，让状态显示 `Answered the question.`。

## 边界情况

- session 不存在：静默忽略，不创建新 session。
- session 当前不是 `.waitingForAnswer`：静默忽略，避免清掉新一轮问题或其他等待态。
- pane 已关闭：外部完成只更新灵动岛，不要求 pane 可用。
- 多问题 prompt：沿用现有扁平化 option label；能解析单个选项时显示该 label，否则显示通用已回答摘要。
- approval 请求：不走 question answer 语义，避免改变权限请求行为。

## 测试

- 更新 `IslandResponseDispatcherTests`：灵动岛内点击 Claude question option 后，断言 phase 为 `.running`、`questionPrompt == nil`、summary 为 `Answered: <选项>`，且 Claude hook 仍收到对应回答。
- 增加 hook/control 边界测试：模拟外部 Claude question 完成后，断言 `IslandNotificationState` 中对应 session 清掉选项页并显示 `Answered: Staging`。
- 保留或补强 `IslandSessionStateTests` 对 `answerQuestion(...)` 的核心状态机断言。

## 验收标准

- 在 Claude 终端里选择选项后，灵动岛立即离开选项页。
- 灵动岛摘要显示 `Answered: <选项>`。
- 在灵动岛里选择选项仍会让 Claude 继续执行。
- 现有 approval 权限请求测试不回归。
