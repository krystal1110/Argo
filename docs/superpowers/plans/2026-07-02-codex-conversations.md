# Codex Conversations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Argo 中增加 Codex Conversations 入口，利用 HAPI 已有的 Codex session import 能力，让用户从手机继续 Codex Desktop 对话。

**Architecture:** 复用现有 HAPI 菜单和 agent session 启动路径，不实现 app-server proxy。HAPI 检测层同时解析可用 `codex` CLI，WorkspaceStore 新增一键启动 Hub/Runner 的编排入口，并通过本地化状态提示把用户导向 HAPI 的 Codex import flow。

**Tech Stack:** Swift、AppKit `NSMenu`、现有 `WorkspaceStore` / `HAPIIntegrationSupport` / `AgentSessionConfiguration`、XCTest。

## Global Constraints

- 回复、设计文档和协作总结使用简体中文。
- 不实现 Codex app-server proxy。
- 不替代 HAPI Web/PWA；只启动 HAPI Hub/Runner 并提示导入 Codex sessions。
- 不修改 `Argo/Vendor/`。

---

### Task 1: HAPI/Codex CLI 检测

**Files:**
- Modify: `Argo/Support/HAPIIntegrationSupport.swift`
- Test: `Tests/HAPIIntegrationSupportTests.swift`

**Interfaces:**
- Consumes: `ShellCommandRunner.run(...)`
- Produces: `HAPIInstallationStatus.codexExecutablePath`, `codexVersion`, `hasUsableCodexCLI`

- [x] 写失败测试：解析 `codex-cli 0.142.5` 为可用版本，低于 `0.124.0` 不可用。
- [x] 写失败测试：`HAPIInstallationStatus` 携带 codex path 时 `hasUsableCodexCLI == true`。
- [x] 实现版本解析和可用性判断。
- [x] 运行 focused test。

### Task 2: Codex Conversations 启动编排

**Files:**
- Modify: `Argo/App/WorkspaceStore.swift`
- Modify: `Argo/Support/WorkspaceCommands.swift`
- Test: existing source-shape tests under `Tests/QuickCommandSupportTests.swift`

**Interfaces:**
- Consumes: `availableHAPIInstallation`, `launchWrappedHomeCommand(...)`
- Produces: `startHAPICodexConversations(workspaceID:)`

- [x] 写失败测试：WorkspaceStore source 中存在 `startHAPICodexConversations`，命令包含 `hapi hub --relay` 和 `hapi runner start --workspace-root`。
- [x] 实现 `WorkspaceCommand.startHAPICodexConversations(UUID)`。
- [x] 实现 WorkspaceStore 方法：检查 hapi/codex，启动 Hub relay，启动 Runner，并发出导入提示。
- [x] 运行 focused test。

### Task 3: UI 入口和文案

**Files:**
- Modify: `Argo/UI/MainWindowView.swift`
- Modify: `Argo/Support/L10n.swift`
- Test: `Tests/QuickCommandSupportTests.swift`
- Test: `Tests/LocalizationManagerTests.swift`

**Interfaces:**
- Consumes: `store.startHAPICodexConversations(workspaceID:)`
- Produces: HAPI 菜单中的 `Codex Conversations`，命令面板中的同名入口

- [x] 写失败测试：HAPI 菜单 source 包含 `main.hapi.codexConversations`。
- [x] 写失败测试：英文/中文本地化 key 可解析。
- [x] 添加菜单项和 command palette item。
- [x] 运行 focused test。

### Task 4: 验证

**Files:**
- No production files.

- [x] 运行 `xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' test` 或至少覆盖改动的 focused tests。
- [x] 运行 `xcodebuild -project Argo.xcodeproj -scheme Argo -configuration Debug -destination 'platform=macOS,arch=arm64' build`。
- [x] 审计目标要求逐项是否满足。
