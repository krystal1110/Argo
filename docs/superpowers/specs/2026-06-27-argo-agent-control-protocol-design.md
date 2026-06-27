# Argo Agent 控制协议设计

## 背景

用户希望先补齐 `argo status`、`argo read`、`argo agents` 控制协议，再继续考虑借用 HAPI 的手机远端入口。调研 `everettjf/liney` 后确认：Argo 已经具备 HAPI 检测、HAPI 菜单、`hapi hub` / `hapi hub --relay` / `cloudflared` 启动入口，以及基础控制命令 `argo open`、`argo split`、`argo send-keys`、`argo session list`、`argo ping`。缺口主要在 agent host 控制面：agent 状态上报、终端读屏、agent 发现和状态聚合。

本设计采用 Liney 的成熟边界，但按 Argo 已有的 `ArgoControlProtocol`、Dynamic Island、Ghostty surface、`ARGO_PANE_ID`、`ARGO_CONTROL_TOKEN` 结构落地。

## 目标

- 增加 `argo status <running|waiting|done|error>`，允许 pane 内 agent 上报持久状态。
- 增加 `argo read`，允许读取某个 pane 的 Ghostty 渲染文本，支持当前 viewport、scrollback、保留最后 N 行和等待稳定输出。
- 增加 `argo agents`，列出当前正在运行或曾主动上报状态的 agent panes。
- 扩展 `argo session list`，在响应中携带 pane 的最近 agent 状态。
- 保持 mutating 命令的 token 鉴权：`open`、`split`、`send-keys` 仍需要 `ARGO_CONTROL_TOKEN`。
- 让 self-report 与 read-only 命令低摩擦：`notify`、`status`、`session-list`、`read`、`agents` 不要求 token。
- 关闭 pane 时清理对应 agent 状态，避免 stale rows。

## 非目标

- 不实现手机端 Web UI，不替代 HAPI 的 relay / PWA / tunnel。
- 不把 HAPI 源码 vendoring 进 Argo。
- 不在本轮实现跨 worktree agent orchestration 面板。
- 不改变现有 URL scheme 设置 UI。
- 不为非 Ghostty backend 强行模拟 read；不可读时返回明确错误。

## 用户可见命令

### `argo status`

用法：

```sh
argo status <running|waiting|done|error> [--pane <uuid>] [--title <text>] [--agent <name>]
```

行为：

- `<state>` 支持同义词归一化：`busy` / `working` -> `running`，`blocked` / `needs-input` -> `waiting`，`complete` / `success` -> `done`，`failed` / `fail` -> `error`。
- `--pane` 省略时读取 `$ARGO_PANE_ID`。
- 命令不需要 token，因为它是 pane 对自身状态的 self-report。
- 若能定位 pane，写入 `AgentStatusStore` 并同步 Dynamic Island。
- `running` 只更新状态，不主动展开 Island。
- `waiting`、`done`、`error` 打开 Island 提醒用户。

### `argo read`

用法：

```sh
argo read [--pane <uuid>] [--last <n>] [--scrollback] [--wait-stable] [--json]
```

行为：

- `--pane` 省略时读取 `$ARGO_PANE_ID`，若仍缺失则由 app 侧退回 focused pane。
- 默认读取当前 viewport；`--scrollback` 读取包含 scrollback 的 screen buffer。
- `--last <n>` 在 app 侧裁剪尾部非空行。
- `--wait-stable` 在 CLI 侧每 200ms 重读，直到连续两次文本一致，最多 25 次。
- `--json` 输出完整 `ArgoControlResponse`，普通模式只输出文本。
- Ghostty 不可读或 pane 不存在时返回错误，例如 `read-unavailable`、`pane-not-found`。

### `argo agents`

用法：

```sh
argo agents [--json] [--no-color]
```

行为：

- 合并两个信号：
  - `AgentStatusStore`：主动上报过状态的 pane。
  - `AgentProcessDetector`：从 pane 根进程和子进程的 argv 判断 agent 类型。
- 输出字段包括 workspace、workspaceName、pane、type、name、status、reported、cwd、branch、focused。
- `reported == true` 表示状态来自 `argo status`；否则是进程探测推断。
- 没有上报也没有探测命中的 pane 不出现在 `agents` 列表中。

### `argo session list`

现有命令保留，扩展响应：

- 每个 `ArgoControlSession` 增加可选 `status`。
- human 输出在 branch 之后显示 `<status>`。
- `--json` 里增加 `"status"` 字段。
- 命令改为 read-only，无需 token；如果环境里带了 token，也继续透传但不要求。

## 协议与鉴权

`ArgoControlCommand` 新增：

- `status`
- `read`
- `agents`

新增 `requiresControlToken` 规则：

- 不需要 token：`notify`、`ping`、`status`、`sessionList`、`read`、`agents`。
- 需要 token：`open`、`split`、`sendKeys`。
- `claudeHook` 保持现有专用处理。

这个边界基于两个前提：

- control socket 是 per-user Unix domain socket。
- read-only 命令不改变 app 状态；`status` 和 `notify` 属于 pane 自己的 out-of-band self-report。

## 组件设计

### 协议层

修改 `Argo/Services/AgentNotify/ArgoControlProtocol.swift`：

- 增加 `AgentReportedState`，负责状态枚举、CLI 同义词解析、映射到 `IslandSessionStatus`。
- 增加 `ArgoStatusRequest`、`ArgoReadRequest`、`ArgoAgentsRequest`。
- 增加 `ArgoAgentInfo`。
- 给 `ArgoControlSession` 增加 `status: String?`。
- 给 `ArgoControlResponse` 增加 `text: String?`、`lineCount: Int?`、`agents: [ArgoAgentInfo]?`。

### CLI 层

修改 `Argo/Services/AgentNotify/ArgoControlCLI.swift` 和 `Argo/main.swift`：

- 新增 `runStatus`、`runRead`、`runAgents`。
- `main.swift` 路由新增 `status`、`read`、`agents`。
- `runSessionList` 不再强制要求 token。
- `runRead --wait-stable` 在 CLI 层轮询，app handler 保持快速快照。

### Dispatcher 层

修改 `Argo/Services/AgentNotify/ArgoControlDispatcher.swift`：

- `ArgoControlHost` 增加 `handleStatus`、`handleRead`、`handleAgents`。
- `dispatch` 对 `status` 做 fire-and-forget，类似 `notify`。
- read-only 命令跳过 token gate。
- mutating 命令继续走原 token gate。

### App Host 层

修改 `Argo/App/ArgoDesktopApplication+ControlHost.swift` 和 `Argo/App/ArgoDesktopApplication.swift`：

- `handleStatus` 解析状态并调用 `routeAgentStatus`。
- `handleRead` 定位 pane，调用 `ShellSession.readScreenText(scrollback:)`，裁剪尾部空白行和 `lastLines`。
- `handleAgents` 遍历 active workspaces 的 sessions，合并 `AgentStatusStore` 与 `AgentProcessDetector`。
- `handleSessionList` 在每个 session 中带上 `AgentStatusStore.shared.state(for:)`。

### Terminal 层

修改 `Argo/Services/Terminal/TerminalSurface.swift`：

- 在 `TerminalSurfaceController` 上增加默认实现 `readScreenText(scrollback:) -> String?`，默认返回 nil。

修改 `Argo/Services/Terminal/ShellSession.swift`：

- 暴露 `readScreenText(scrollback:)` 转发到 surface controller。

修改 `Argo/Services/Terminal/Ghostty/ArgoGhosttyController.swift`：

- 实现 `readScreenText(scrollback:)`。
- 使用 `ghostty_surface_read_text`：
  - `scrollback == false`：`GHOSTTY_POINT_VIEWPORT`。
  - `scrollback == true`：`GHOSTTY_POINT_SCREEN`。
- 按 `text_len` 解码，避免依赖 NUL 结尾。

### Agent 状态与探测

新增 `Argo/Services/AgentNotify/AgentStatusStore.swift`：

- `@MainActor final class AgentStatusStore`。
- 以 pane UUID 为 key 存储 `state`、`title`、`agentName`、`updatedAt`。
- 提供 `update`、`state(for:)`、`clear(pane:)`、`clearAll()`。

新增 `Argo/Services/Process/AgentProcessDetector.swift`：

- 复用 Liney 的 argv-based 检测策略。
- 从 root pid 和 descendants 广度优先扫描。
- 匹配 executable path 和第一个脚本参数的路径组件，避免 cwd 或普通参数误报。
- 初始支持：Claude Code、Codex、Aider、Gemini CLI、OpenCode、Cursor Agent、Qwen Code、Goose、Crush、Cline、Amp。

修改 `WorkspaceRuntime.closePane`：

- 关闭 pane 前调用 `AgentStatusStore.shared.clear(pane:)`。

## 数据流

`argo status waiting`：

```text
CLI -> AgentNotify socket -> ArgoControlDispatcher -> ArgoDesktopApplication.handleStatus
    -> routeAgentStatus -> WorkspaceModel.postAgentStatus
    -> AgentStatusStore + IslandPanelController
```

`argo read --pane P --last 80`：

```text
CLI -> socket -> dispatcher -> handleRead
    -> workspace/session lookup -> ShellSession.readScreenText
    -> Ghostty surface read_text -> trim/crop -> JSON/text response
```

`argo agents --json`：

```text
CLI -> socket -> dispatcher -> handleAgents
    -> active workspaces -> sessions
    -> AgentStatusStore + AgentProcessDetector(pid)
    -> ArgoAgentInfo[]
```

## 错误处理

- `status` 缺少 state：CLI 返回 usage。
- `status` state 无法识别：CLI 返回 usage，并提示允许值。
- `read` 找不到 pane：`pane-not-found`。
- `read` 没有 pane 且没有 focused pane：`no-pane`。
- `read` surface 不支持读屏：`read-unavailable`。
- `agents` 没有匹配项：返回空数组，不报错。
- `open/split/send-keys` 缺 token 或 token 不匹配：沿用 `control-disabled` / `token-mismatch`。

## 测试策略

新增或更新 focused unit tests：

- `ArgoControlCLITests`
  - `status` 编码 frame，不携带 token。
  - state 同义词归一化。
  - `read` 编码 `pane`、`lines`、`scrollback`，不要求 token。
  - `read --wait-stable` 轮询到两次文本一致。
  - `agents --json` 输出数组。
  - `session list` 无 token 可运行，并打印 `<status>`。

- `ArgoControlDispatcherTests`
  - `status` 无 token 路由且 fire-and-forget。
  - `read` / `agents` / `session-list` 无 token 可路由。
  - `open/split/send-keys` 仍必须 token。
  - `read` payload 字段正确传给 host。

- `AgentProcessDetectorTests`
  - 能识别 node-wrapped Claude/Codex 等路径。
  - 不因 cwd 或普通参数里的 `codex` 误报。
  - `KERN_PROCARGS2` parser 覆盖 argc、exec path、argv。

- `AgentStatusStoreTests`
  - update/state/clear/clearAll。

- `WorkspaceSessionController` / host 层测试
  - `session list` 带 status。
  - `handleRead` 裁剪尾部空白和 last lines。
  - 关闭 pane 清理状态。

## 后续

本轮完成后，Argo 会拥有可被 HAPI、脚本或 agent 使用的本机控制面。下一步可以在 HAPI 集成上做轻量编排：一键启动 `hapi runner start --workspace-root <root>` 和 `hapi hub --relay`，让手机端通过 HAPI Web 操控，而 Argo 保持 native host 与 pane 控制能力。
