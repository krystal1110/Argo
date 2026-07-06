# Dynamic Island Open Vibe Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Argo 灵动岛从 beta 通知面板升级为接近 `open-vibe-island` 核心体验的 Argo-native agent/session 控制面。

**Architecture:** 第一阶段选择性迁移 `open-vibe-island` 的纯模型、reducer、surface eligibility、presentation 派生和 closed-island agents grid，并用 Argo adapter 连接 workspace/worktree/pane、`argo notify` 和现有 `IslandPanelController`。`IslandNotificationState` 保留为 SwiftUI facade，内部以新的 `IslandSessionState` 为真源，旧 `items` 只作为兼容 derived view。

**Tech Stack:** Swift 6, AppKit, SwiftUI, Combine, XCTest, Xcode file-system-synchronized groups.

## Global Constraints

- 允许直接复制、改名、裁剪和适配 `/Users/liaojingyu/open-vibe-island` 源码。
- 第一阶段不迁移完整外部 terminal 跳转矩阵、hook installer、transcript discovery、usage dashboard、Watch/iPhone relay、Sparkle 更新模块。
- 保留 Argo 现有 `IslandPanelController` 的 AppKit 生命周期，不整文件替换 panel controller。
- 不重写 Argo 的 terminal、workspace、worktree 或 sidebar 架构。
- 旧 `argo notify` 字段 `title`、`body`、`pane`、`workspace`、`agent` 必须保持兼容。
- 所有实现任务遵循 TDD：先写失败测试，确认失败原因，再写最小实现。

---

## 文件结构

- Create: `Argo/Domain/IslandAgentModels.swift`
  - 承载从 `open-vibe-island/Sources/OpenIslandCore/AgentSession.swift` 迁移和裁剪后的 session/tool/permission/question 模型。
- Modify: `Argo/Domain/IslandNotificationModels.swift`
  - 将已有 `IslandSessionIdentity` 扩展为 `Codable, Sendable`，供新 session 模型安全复用。
- Create: `Argo/Domain/IslandSessionEvent.swift`
  - 承载从 `open-vibe-island/Sources/OpenIslandCore/AgentEvent.swift` 迁移和裁剪后的事件枚举与 payload。
- Create: `Argo/Support/IslandSessionState.swift`
  - 承载从 `open-vibe-island/Sources/OpenIslandCore/SessionState.swift` 迁移和裁剪后的 pure reducer。
- Create: `Argo/Support/IslandSessionPresentation.swift`
  - 承载从 `open-vibe-island/Sources/OpenIslandApp/AgentSession+Presentation.swift` 迁移和 Argo 化后的展示派生逻辑。
- Create: `Argo/UI/Island/IslandSurface.swift`
  - 承载从 `open-vibe-island/Sources/OpenIslandApp/IslandSurface.swift` 迁移后的 notification card surface 逻辑。
- Create: `Argo/UI/Island/IslandClosedAgentsGrid.swift`
  - 承载从 `open-vibe-island/Sources/OpenIslandApp/Views/V6NotchContent.swift` 迁移后的 agents grid 数据结构和 SwiftUI 小组件。
- Create: `Argo/UI/Island/IslandSessionRow.swift`
  - 承载从 `open-vibe-island/Sources/OpenIslandApp/Views/IslandPanelView.swift` 提取并 Argo 化后的 session row。
- Create: `Argo/UI/Island/IslandSessionSections.swift`
  - 承载 expanded sessions tab 的分组 header 与 section 渲染。
- Modify: `Argo/Support/IslandNotificationState.swift`
  - 改为持有 `IslandSessionState`，保留 `items`、`priorityItems`、`latestItem` 兼容入口。
- Modify: `Argo/Domain/IslandNotificationModels.swift`
  - 保留旧 item 类型，增加与 `IslandAgentSession` 的转换 initializer。
- Modify: `Argo/Services/AgentNotify/AgentNotifyProtocol.swift`
  - 扩展 rich notify wire fields。
- Modify: `Argo/Services/AgentNotify/AgentNotifyCLI.swift`
  - 增加 `--approval`、`--question`、`--completed`、`--failed`、`--option`、`--session`、`--source` 等参数。
- Modify: `Argo/Services/AgentNotify/AgentNotifyServer.swift`
  - 增加 control socket 专用 owner，强持有 `ArgoControlDispatcher`，保证 `argo ping`、action write-back 和 session list 都能拿到响应。
- Modify: `Argo/AppDelegate.swift`
  - 将生产环境 control server 存储为 `AgentNotifyControlServer`，避免 `startAgentNotifyServer()` 返回后 dispatcher 被释放。
- Modify: `Argo/App/ArgoDesktopApplication.swift`
  - 将 `routeAgentNotification(_:)` 从直接 post item 改成发送 `IslandSessionEvent`。
- Modify: `Argo/Domain/WorkspaceRuntime.swift`
  - 将 OSC/Ghostty notification 改成 session event。
- Modify: `Argo/App/WorkspaceStore.swift`
  - 将 status message 改成 ephemeral session event。
- Modify: `Argo/UI/Island/IslandPanelController.swift`
  - 增加 `surface`、notification card 展示、session navigation/response 入口。
- Modify: `Argo/UI/Island/IslandContentView.swift`
  - 根据 `surface` 渲染 collapsed、notification card 或 expanded session list。
- Modify: `Argo/UI/Island/IslandCollapsedView.swift`
  - 集成 closed agents grid 与 spotlight label。
- Modify: `Argo/UI/Island/IslandExpandedView.swift`
  - 将 sessions tab 改为 grouped session list。
- Modify: `Argo/Support/IslandResponseDispatcher.swift`
  - 改为 sessionID/action 驱动，成功后发 `.actionableStateResolved`。
- Modify: `Argo/Services/Terminal/ShellSession.swift`
  - 增加 action/control 专用 programmatic input 入口，在发送文字前先聚焦 terminal surface。
- Modify: `Argo/Services/Terminal/WorkspaceSessionController.swift`
  - 增加按 paneID 聚焦并发送 programmatic text 的共享入口。
- Modify: `Argo/Services/Terminal/TerminalSurface.swift`
  - 增加 terminal surface 专用 `sendProgrammaticText(_:) -> Bool` contract。
- Modify: `Argo/Services/Terminal/Ghostty/ArgoGhosttyController.swift`
  - 将 action/control 输入从 `ghostty_surface_text` 切到 `ghostty_surface_key` 驱动的 programmatic input primitive。
- Modify: `Argo/App/ArgoDesktopApplication+ControlHost.swift`
  - 将 `send-keys` control command 接到共享 pane 输入路径。
- Modify: `Argo/Support/L10n.swift`
  - 增加 session 分组、approval/question、Show All、错误和操作文案。
- Test: `Tests/IslandSessionStateTests.swift`
- Test: `Tests/IslandSessionPresentationTests.swift`
- Test: `Tests/IslandSessionSectionsTests.swift`
- Test: `Tests/IslandSurfaceTests.swift`
- Test: `Tests/IslandClosedAgentsGridTests.swift`
- Test: `Tests/IslandRichNotifyProtocolTests.swift`
- Test: `Tests/AgentNotifyServerTests.swift`
- Create: `scripts/smoke_dynamic_island_notify.sh`
  - 提供可重复的运行态 smoke：从真实 Argo pane 发 activity/approval/question/completed 事件，并输出截图证据。
- Modify tests: `Tests/AgentNotifyCLITests.swift`, `Tests/AgentNotifyProtocolTests.swift`, `Tests/IslandResponseDispatcherTests.swift`, `Tests/IslandWorkspaceNavigatorTests.swift`, `Tests/IslandSessionCenterTests.swift`, `Tests/ShellSessionTests.swift`, `Tests/ArgoControlDispatcherTests.swift`
- Create test: `Tests/WorkspaceSessionControllerTests.swift`

### Task 1: 迁移 session 模型与 reducer

**Files:**
- Create: `Argo/Domain/IslandAgentModels.swift`
- Create: `Argo/Domain/IslandSessionEvent.swift`
- Create: `Argo/Support/IslandSessionState.swift`
- Modify: `Argo/Domain/IslandNotificationModels.swift`
- Test: `Tests/IslandSessionStateTests.swift`

**Interfaces:**
- Produces:
  - `enum IslandAgentTool: String, Codable, Sendable, CaseIterable`
  - `enum IslandSessionPhase: String, Codable, Sendable, CaseIterable`
  - `struct IslandPermissionRequest: Equatable, Identifiable, Codable, Sendable`
  - `struct IslandQuestionPrompt: Equatable, Identifiable, Codable, Sendable`
  - `struct IslandQuestionPromptResponse: Equatable, Codable, Sendable`
  - `struct IslandAgentSession: Equatable, Identifiable, Codable, Sendable`
  - `enum IslandSessionEvent: Equatable, Codable, Sendable`
  - `struct IslandSessionState: Equatable, Sendable`
  - `mutating func apply(_ event: IslandSessionEvent)`
  - `mutating func resolvePermission(sessionID: String, resolution: IslandPermissionResolution, at timestamp: Date)`
  - `mutating func answerQuestion(sessionID: String, response: IslandQuestionPromptResponse, at timestamp: Date)`

- [x] **Step 1: Write the failing reducer tests**

Create `Tests/IslandSessionStateTests.swift`:

```swift
import XCTest
@testable import Argo

final class IslandSessionStateTests: XCTestCase {
    func testSessionStartedCreatesVisibleSession() {
        var state = IslandSessionState()
        let id = "pane:abc"
        state.apply(.sessionStarted(IslandSessionStarted(
            sessionID: id,
            identity: makeIdentity(sessionID: id),
            title: "Fix auth",
            tool: .codex,
            initialPhase: .running,
            summary: "Thinking",
            timestamp: Date(timeIntervalSince1970: 10)
        )))
        XCTAssertEqual(state.sessions.map(\.id), [id])
        XCTAssertEqual(state.runningCount, 1)
        XCTAssertEqual(state.attentionCount, 0)
    }

    func testPermissionRequestPreservesPendingAgainstRunningActivity() {
        var state = IslandSessionState()
        let id = "pane:abc"
        state.apply(.sessionStarted(IslandSessionStarted(
            sessionID: id,
            identity: makeIdentity(sessionID: id),
            title: "Fix auth",
            tool: .codex,
            initialPhase: .running,
            summary: "Started",
            timestamp: Date(timeIntervalSince1970: 10)
        )))
        state.apply(.permissionRequested(IslandPermissionRequested(
            sessionID: id,
            request: IslandPermissionRequest(
                title: "Approval needed",
                summary: "Run tests",
                affectedPath: "/tmp/repo",
                primaryActionTitle: "Allow",
                secondaryActionTitle: "Deny",
                allowResponseText: "1\n",
                denyResponseText: "2\n"
            ),
            timestamp: Date(timeIntervalSince1970: 20)
        )))
        state.apply(.activityUpdated(IslandSessionActivityUpdated(
            sessionID: id,
            summary: "Still running",
            phase: .running,
            timestamp: Date(timeIntervalSince1970: 30)
        )))
        let session = state.session(id: id)
        XCTAssertEqual(session?.phase, .waitingForApproval)
        XCTAssertEqual(session?.permissionRequest?.summary, "Run tests")
        XCTAssertEqual(state.attentionCount, 1)
    }

    func testQuestionAnswerResolvesBackToRunning() {
        var state = IslandSessionState()
        let id = "pane:abc"
        state.apply(.sessionStarted(IslandSessionStarted(
            sessionID: id,
            identity: makeIdentity(sessionID: id),
            title: "Deploy",
            tool: .codex,
            initialPhase: .running,
            summary: "Started",
            timestamp: Date(timeIntervalSince1970: 10)
        )))
        state.apply(.questionAsked(IslandQuestionAsked(
            sessionID: id,
            prompt: IslandQuestionPrompt(
                title: "Which target?",
                options: [
                    IslandQuestionOption(label: "Production", responseText: "Production\n"),
                    IslandQuestionOption(label: "Staging", responseText: "Staging\n")
                ]
            ),
            timestamp: Date(timeIntervalSince1970: 20)
        )))
        state.answerQuestion(
            sessionID: id,
            response: IslandQuestionPromptResponse(answer: "Staging"),
            at: Date(timeIntervalSince1970: 25)
        )
        let session = state.session(id: id)
        XCTAssertEqual(session?.phase, .running)
        XCTAssertNil(session?.questionPrompt)
        XCTAssertEqual(session?.summary, "Answered: Staging")
    }

    func testFailedSortsBeforeRunningAndCompleted() {
        var state = IslandSessionState()
        state.apply(.sessionStarted(IslandSessionStarted(
            sessionID: "done",
            identity: makeIdentity(sessionID: "done"),
            title: "Done",
            tool: .codex,
            initialPhase: .completed,
            summary: "Done",
            timestamp: Date(timeIntervalSince1970: 10)
        )))
        state.apply(.sessionStarted(IslandSessionStarted(
            sessionID: "running",
            identity: makeIdentity(sessionID: "running"),
            title: "Run",
            tool: .codex,
            initialPhase: .running,
            summary: "Run",
            timestamp: Date(timeIntervalSince1970: 20)
        )))
        state.apply(.sessionStarted(IslandSessionStarted(
            sessionID: "failed",
            identity: makeIdentity(sessionID: "failed"),
            title: "Fail",
            tool: .codex,
            initialPhase: .failed,
            summary: "Failed",
            timestamp: Date(timeIntervalSince1970: 15),
            lastError: "boom"
        )))
        XCTAssertEqual(state.prioritySessions.map(\.id), ["failed", "running", "done"])
    }

    private func makeIdentity(sessionID: String) -> IslandSessionIdentity {
        IslandSessionIdentity(
            workspaceID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            worktreePath: "/tmp/repo",
            paneID: UUID(uuidString: "00000000-0000-0000-0000-000000000002"),
            sourceID: sessionID
        )
    }
}
```

- [x] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionStateTests \
  test
```

Expected: FAIL with compiler errors such as `cannot find type 'IslandSessionState' in scope`.

- [x] **Step 3: Implement migrated models**

Modify `Argo/Domain/IslandNotificationModels.swift`, update the existing identity declaration:

```swift
nonisolated struct IslandSessionIdentity: Hashable, Codable, Sendable {
    let workspaceID: UUID
    let worktreePath: String?
    let paneID: UUID?
    let sourceID: String?

    init(
        workspaceID: UUID,
        worktreePath: String?,
        paneID: UUID?,
        sourceID: String?
    ) {
        self.workspaceID = workspaceID
        self.worktreePath = worktreePath
        self.paneID = paneID
        self.sourceID = sourceID ?? paneID?.uuidString.lowercased()
    }
}
```

Create `Argo/Domain/IslandAgentModels.swift` with these concrete interfaces:

```swift
import Foundation

enum IslandAgentTool: String, Codable, Sendable, CaseIterable, Equatable {
    case codex
    case claudeCode
    case geminiCLI
    case openCode
    case cursor
    case argo

    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claudeCode: return "Claude Code"
        case .geminiCLI: return "Gemini CLI"
        case .openCode: return "OpenCode"
        case .cursor: return "Cursor"
        case .argo: return "Argo"
        }
    }

    var shortName: String {
        switch self {
        case .codex: return "CODEX"
        case .claudeCode: return "CLAUDE"
        case .geminiCLI: return "GEMINI"
        case .openCode: return "OPENCODE"
        case .cursor: return "CURSOR"
        case .argo: return "ARGO"
        }
    }

    var brandColorHex: String {
        switch self {
        case .codex: return "#4aa3df"
        case .claudeCode: return "#d97742"
        case .geminiCLI: return "#42e86b"
        case .openCode: return "#ffb547"
        case .cursor: return "#7a5cff"
        case .argo: return "#8fb7ff"
        }
    }
}

enum IslandSessionPhase: String, Codable, Sendable, CaseIterable, Equatable {
    case running
    case waitingForApproval
    case waitingForAnswer
    case completed
    case failed
    case stale

    var requiresAttention: Bool {
        self == .waitingForApproval || self == .waitingForAnswer
    }

    var priorityRank: Int {
        switch self {
        case .waitingForAnswer: return 0
        case .waitingForApproval: return 1
        case .failed: return 2
        case .running: return 3
        case .stale: return 4
        case .completed: return 5
        }
    }
}

enum IslandSessionAttachmentState: String, Codable, Sendable, Equatable {
    case attached
    case stale
    case detached
}

struct IslandPermissionRequest: Equatable, Identifiable, Codable, Sendable {
    var id: UUID
    var title: String
    var summary: String
    var affectedPath: String
    var primaryActionTitle: String
    var secondaryActionTitle: String
    var allowResponseText: String
    var denyResponseText: String

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        affectedPath: String,
        primaryActionTitle: String = "Allow",
        secondaryActionTitle: String = "Deny",
        allowResponseText: String = "1\n",
        denyResponseText: String = "2\n"
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.affectedPath = affectedPath
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitle = secondaryActionTitle
        self.allowResponseText = allowResponseText
        self.denyResponseText = denyResponseText
    }
}

struct IslandQuestionOption: Equatable, Identifiable, Codable, Sendable {
    var id: UUID
    var label: String
    var responseText: String

    init(id: UUID = UUID(), label: String, responseText: String? = nil) {
        self.id = id
        self.label = label
        self.responseText = responseText ?? "\(label)\n"
    }
}

struct IslandQuestionPrompt: Equatable, Identifiable, Codable, Sendable {
    var id: UUID
    var title: String
    var options: [IslandQuestionOption]

    init(id: UUID = UUID(), title: String, options: [IslandQuestionOption]) {
        self.id = id
        self.title = title
        self.options = options
    }
}

struct IslandQuestionPromptResponse: Equatable, Codable, Sendable {
    var rawAnswer: String?

    init(answer: String) {
        self.rawAnswer = answer
    }

    var displaySummary: String {
        rawAnswer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

enum IslandPermissionResolution: Equatable, Codable, Sendable {
    case allowOnce
    case deny(message: String?)

    var isApproved: Bool {
        if case .allowOnce = self { return true }
        return false
    }
}

struct IslandAgentSession: Equatable, Identifiable, Codable, Sendable {
    var id: String
    var identity: IslandSessionIdentity
    var title: String
    var tool: IslandAgentTool
    var attachmentState: IslandSessionAttachmentState
    var phase: IslandSessionPhase
    var summary: String
    var updatedAt: Date
    var firstSeenAt: Date
    var permissionRequest: IslandPermissionRequest?
    var questionPrompt: IslandQuestionPrompt?
    var currentTool: String?
    var commandPreview: String?
    var initialPrompt: String?
    var latestPrompt: String?
    var lastAssistantMessage: String?
    var terminalTag: String?
    var lastError: String?
    var isDismissed: Bool

    init(
        id: String,
        identity: IslandSessionIdentity,
        title: String,
        tool: IslandAgentTool,
        attachmentState: IslandSessionAttachmentState = .attached,
        phase: IslandSessionPhase,
        summary: String,
        updatedAt: Date,
        firstSeenAt: Date? = nil,
        permissionRequest: IslandPermissionRequest? = nil,
        questionPrompt: IslandQuestionPrompt? = nil,
        currentTool: String? = nil,
        commandPreview: String? = nil,
        initialPrompt: String? = nil,
        latestPrompt: String? = nil,
        lastAssistantMessage: String? = nil,
        terminalTag: String? = nil,
        lastError: String? = nil,
        isDismissed: Bool = false
    ) {
        self.id = id
        self.identity = identity
        self.title = title
        self.tool = tool
        self.attachmentState = attachmentState
        self.phase = phase
        self.summary = summary
        self.updatedAt = updatedAt
        self.firstSeenAt = firstSeenAt ?? updatedAt
        self.permissionRequest = permissionRequest
        self.questionPrompt = questionPrompt
        self.currentTool = currentTool
        self.commandPreview = commandPreview
        self.initialPrompt = initialPrompt
        self.latestPrompt = latestPrompt
        self.lastAssistantMessage = lastAssistantMessage
        self.terminalTag = terminalTag
        self.lastError = lastError
        self.isDismissed = isDismissed
    }
}
```

- [x] **Step 4: Implement event payloads**

Create `Argo/Domain/IslandSessionEvent.swift`:

```swift
import Foundation

struct IslandSessionStarted: Equatable, Codable, Sendable {
    var sessionID: String
    var identity: IslandSessionIdentity
    var title: String
    var tool: IslandAgentTool
    var initialPhase: IslandSessionPhase
    var summary: String
    var timestamp: Date
    var currentTool: String?
    var commandPreview: String?
    var initialPrompt: String?
    var latestPrompt: String?
    var lastAssistantMessage: String?
    var terminalTag: String?
    var lastError: String?
}

struct IslandSessionActivityUpdated: Equatable, Codable, Sendable {
    var sessionID: String
    var summary: String
    var phase: IslandSessionPhase
    var timestamp: Date
    var currentTool: String?
    var commandPreview: String?
    var latestPrompt: String?
    var lastAssistantMessage: String?
    var lastError: String?
}

struct IslandPermissionRequested: Equatable, Codable, Sendable {
    var sessionID: String
    var request: IslandPermissionRequest
    var timestamp: Date
}

struct IslandQuestionAsked: Equatable, Codable, Sendable {
    var sessionID: String
    var prompt: IslandQuestionPrompt
    var timestamp: Date
}

struct IslandSessionCompleted: Equatable, Codable, Sendable {
    var sessionID: String
    var summary: String
    var timestamp: Date
    var failed: Bool
    var lastAssistantMessage: String?
}

struct IslandActionableStateResolved: Equatable, Codable, Sendable {
    var sessionID: String
    var summary: String
    var timestamp: Date
}

enum IslandSessionEvent: Equatable, Codable, Sendable {
    case sessionStarted(IslandSessionStarted)
    case activityUpdated(IslandSessionActivityUpdated)
    case permissionRequested(IslandPermissionRequested)
    case questionAsked(IslandQuestionAsked)
    case sessionCompleted(IslandSessionCompleted)
    case actionableStateResolved(IslandActionableStateResolved)
}
```

- [x] **Step 5: Implement reducer**

Create `Argo/Support/IslandSessionState.swift`:

```swift
import Foundation

struct IslandSessionState: Equatable, Sendable {
    private(set) var sessionsByID: [String: IslandAgentSession]

    init(sessions: [IslandAgentSession] = []) {
        self.sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
    }

    var sessions: [IslandAgentSession] {
        sessionsByID.values.sorted {
            if $0.updatedAt == $1.updatedAt {
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    var prioritySessions: [IslandAgentSession] {
        sessions.filter { !$0.isDismissed }.sorted {
            if $0.phase.priorityRank == $1.phase.priorityRank {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.phase.priorityRank < $1.phase.priorityRank
        }
    }

    var spotlightSession: IslandAgentSession? { prioritySessions.first }
    var runningCount: Int { sessionsByID.values.filter { $0.phase == .running }.count }
    var attentionCount: Int { sessionsByID.values.filter { $0.phase.requiresAttention }.count }
    var liveSessionCount: Int { sessionsByID.values.filter { !$0.isDismissed && $0.phase != .stale }.count }

    func session(id: String?) -> IslandAgentSession? {
        guard let id else { return nil }
        return sessionsByID[id]
    }

    mutating func apply(_ event: IslandSessionEvent) {
        switch event {
        case let .sessionStarted(payload):
            let existing = sessionsByID[payload.sessionID]
            upsert(IslandAgentSession(
                id: payload.sessionID,
                identity: payload.identity,
                title: payload.title,
                tool: payload.tool,
                phase: payload.initialPhase,
                summary: payload.summary,
                updatedAt: payload.timestamp,
                firstSeenAt: existing?.firstSeenAt,
                currentTool: payload.currentTool,
                commandPreview: payload.commandPreview,
                initialPrompt: payload.initialPrompt,
                latestPrompt: payload.latestPrompt,
                lastAssistantMessage: payload.lastAssistantMessage,
                terminalTag: payload.terminalTag,
                lastError: payload.lastError
            ))
        case let .activityUpdated(payload):
            guard var session = sessionsByID[payload.sessionID] else { return }
            let preservesPending = payload.phase == .running && session.phase.requiresAttention
            if !preservesPending {
                session.phase = payload.phase
                if payload.phase != .waitingForApproval { session.permissionRequest = nil }
                if payload.phase != .waitingForAnswer { session.questionPrompt = nil }
            }
            session.summary = payload.summary
            session.updatedAt = payload.timestamp
            session.currentTool = payload.currentTool ?? session.currentTool
            session.commandPreview = payload.commandPreview ?? session.commandPreview
            session.latestPrompt = payload.latestPrompt ?? session.latestPrompt
            session.lastAssistantMessage = payload.lastAssistantMessage ?? session.lastAssistantMessage
            session.lastError = payload.lastError
            upsert(session)
        case let .permissionRequested(payload):
            guard var session = sessionsByID[payload.sessionID] else { return }
            session.phase = .waitingForApproval
            session.summary = payload.request.summary
            session.permissionRequest = payload.request
            session.questionPrompt = nil
            session.updatedAt = payload.timestamp
            session.lastError = nil
            upsert(session)
        case let .questionAsked(payload):
            guard var session = sessionsByID[payload.sessionID] else { return }
            session.phase = .waitingForAnswer
            session.summary = payload.prompt.title
            session.questionPrompt = payload.prompt
            session.permissionRequest = nil
            session.updatedAt = payload.timestamp
            session.lastError = nil
            upsert(session)
        case let .sessionCompleted(payload):
            guard var session = sessionsByID[payload.sessionID] else { return }
            session.phase = payload.failed ? .failed : .completed
            session.summary = payload.summary
            session.permissionRequest = nil
            session.questionPrompt = nil
            session.updatedAt = payload.timestamp
            session.lastAssistantMessage = payload.lastAssistantMessage ?? session.lastAssistantMessage
            session.lastError = payload.failed ? payload.summary : nil
            upsert(session)
        case let .actionableStateResolved(payload):
            guard var session = sessionsByID[payload.sessionID] else { return }
            guard session.phase.requiresAttention else { return }
            session.phase = .running
            session.summary = payload.summary
            session.permissionRequest = nil
            session.questionPrompt = nil
            session.updatedAt = payload.timestamp
            session.lastError = nil
            upsert(session)
        }
    }

    mutating func resolvePermission(
        sessionID: String,
        resolution: IslandPermissionResolution,
        at timestamp: Date = .now
    ) {
        let summary = resolution.isApproved ? "Permission approved." : "Permission denied."
        apply(.actionableStateResolved(IslandActionableStateResolved(
            sessionID: sessionID,
            summary: summary,
            timestamp: timestamp
        )))
    }

    mutating func answerQuestion(
        sessionID: String,
        response: IslandQuestionPromptResponse,
        at timestamp: Date = .now
    ) {
        let summary = response.displaySummary.isEmpty ? "Answered the question." : "Answered: \(response.displaySummary)"
        apply(.actionableStateResolved(IslandActionableStateResolved(
            sessionID: sessionID,
            summary: summary,
            timestamp: timestamp
        )))
    }

    mutating func dismissSession(id: String) {
        guard var session = sessionsByID[id] else { return }
        session.isDismissed = true
        upsert(session)
    }

    mutating func markSessionStale(id: String, error: String) {
        guard var session = sessionsByID[id] else { return }
        session.phase = .stale
        session.lastError = error
        session.updatedAt = .now
        upsert(session)
    }

    private mutating func upsert(_ session: IslandAgentSession) {
        sessionsByID[session.id] = session
    }
}
```

- [x] **Step 6: Run reducer tests to verify pass**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionStateTests \
  test
```

Expected: PASS for `IslandSessionStateTests`.

- [x] **Step 7: Commit**

```bash
git add Argo/Domain/IslandAgentModels.swift Argo/Domain/IslandSessionEvent.swift Argo/Domain/IslandNotificationModels.swift Argo/Support/IslandSessionState.swift Tests/IslandSessionStateTests.swift
git commit -m "feat(island): add sessions"
```

### Task 2: 迁移 presentation 派生与 closed agents grid

**Files:**
- Create: `Argo/Support/IslandSessionPresentation.swift`
- Create: `Argo/UI/Island/IslandClosedAgentsGrid.swift`
- Test: `Tests/IslandSessionPresentationTests.swift`
- Test: `Tests/IslandClosedAgentsGridTests.swift`

**Interfaces:**
- Consumes: `IslandAgentSession`, `IslandSessionPhase`
- Produces:
  - `enum IslandSessionPresence`
  - `enum IslandGridCellState`
  - `enum IslandGridCell`
  - `enum IslandRightSlotContent`
  - `extension IslandAgentSession { var spotlightHeadlineText: String ... }`
  - `struct IslandClosedAgentsGrid: View`
  - `struct IslandRightSlotView: View`

- [x] **Step 1: Write failing presentation tests**

Create `Tests/IslandSessionPresentationTests.swift`:

```swift
import XCTest
@testable import Argo

final class IslandSessionPresentationTests: XCTestCase {
    func testHeadlineUsesWorkspaceBranchAndPrompt() {
        let session = makeSession(
            title: "Codex",
            initialPrompt: "fix auth",
            worktreePath: "/repo/feature-login"
        )
        XCTAssertEqual(session.spotlightHeadlineText, "feature-login · fix auth")
    }

    func testActivityLineShowsCurrentToolAndCommandPreview() {
        let session = makeSession(currentTool: "exec_command", commandPreview: "xcodebuild test")
        XCTAssertEqual(session.spotlightActivityLineText, "Bash xcodebuild test")
    }

    func testAgeBadgeFormatsMinutesAndHours() {
        let session = makeSession(updatedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(session.spotlightAgeBadge(at: Date(timeIntervalSince1970: 65)), "1m")
        XCTAssertEqual(session.spotlightAgeBadge(at: Date(timeIntervalSince1970: 7_200)), "2h")
    }

    func testPresenceMapsAttentionToActive() {
        let session = makeSession(phase: .waitingForApproval)
        XCTAssertEqual(session.islandPresence(at: Date()), .active)
    }

    private func makeSession(
        title: String = "Codex",
        phase: IslandSessionPhase = .running,
        updatedAt: Date = Date(timeIntervalSince1970: 0),
        initialPrompt: String? = nil,
        worktreePath: String = "/repo/main",
        currentTool: String? = nil,
        commandPreview: String? = nil
    ) -> IslandAgentSession {
        IslandAgentSession(
            id: "s",
            identity: IslandSessionIdentity(
                workspaceID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                worktreePath: worktreePath,
                paneID: nil,
                sourceID: "s"
            ),
            title: title,
            tool: .codex,
            phase: phase,
            summary: "summary",
            updatedAt: updatedAt,
            initialPrompt: initialPrompt,
            currentTool: currentTool,
            commandPreview: commandPreview
        )
    }
}
```

Create `Tests/IslandClosedAgentsGridTests.swift`:

```swift
import XCTest
@testable import Argo

final class IslandClosedAgentsGridTests: XCTestCase {
    func testBalancedRowsMatchOpenVibeShapes() {
        XCTAssertEqual(IslandRightSlotView.balancedRows(1), [1])
        XCTAssertEqual(IslandRightSlotView.balancedRows(4), [2, 2])
        XCTAssertEqual(IslandRightSlotView.balancedRows(7), [4, 3])
        XCTAssertEqual(IslandRightSlotView.balancedRows(9), [3, 3, 3])
    }

    func testGridCellsMapSessionPhases() {
        XCTAssertEqual(IslandGridCellState(phase: .running), .running)
        XCTAssertEqual(IslandGridCellState(phase: .waitingForAnswer), .waiting)
        XCTAssertEqual(IslandGridCellState(phase: .completed), .idle)
    }
}
```

- [x] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionPresentationTests \
  -only-testing:ArgoTests/IslandClosedAgentsGridTests \
  test
```

Expected: FAIL with missing `IslandRightSlotView`, `IslandSessionPresence`, and presentation properties.

- [x] **Step 3: Implement presentation extension**

Create `Argo/Support/IslandSessionPresentation.swift`:

```swift
import Foundation

enum IslandSessionPresence: Equatable {
    case running
    case active
    case inactive
}

extension IslandAgentSession {
    static let staleCompletedDisplayThreshold: TimeInterval = 5 * 60

    var spotlightWorkspaceName: String {
        guard let path = identity.worktreePath, !path.isEmpty else { return title }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    var spotlightHeadlineText: String {
        if let prompt = initialPrompt?.trimmedForIslandSurface, !prompt.isEmpty {
            return "\(spotlightWorkspaceName) · \(prompt)"
        }
        return spotlightWorkspaceName
    }

    var spotlightActivityLineText: String? {
        if let currentTool = currentTool?.trimmedForIslandSurface, !currentTool.isEmpty {
            let label = Self.currentToolDisplayName(for: currentTool)
            if let commandPreview = commandPreview?.trimmedForIslandSurface, !commandPreview.isEmpty {
                return "\(label) \(commandPreview)"
            }
            return label
        }
        if phase.requiresAttention { return summary }
        if phase == .completed { return lastAssistantMessage?.trimmedForIslandSurface ?? summary }
        return summary
    }

    func spotlightAgeBadge(at referenceDate: Date = .now) -> String {
        let age = max(0, Int(referenceDate.timeIntervalSince(updatedAt)))
        if age < 60 { return "<1m" }
        if age < 3_600 { return "\(max(1, age / 60))m" }
        if age < 86_400 { return "\(max(1, age / 3_600))h" }
        return "\(max(1, age / 86_400))d"
    }

    func islandPresence(at referenceDate: Date) -> IslandSessionPresence {
        if phase == .running { return .running }
        if phase.requiresAttention || phase == .failed { return .active }
        if referenceDate.timeIntervalSince(updatedAt) <= Self.staleCompletedDisplayThreshold { return .active }
        return .inactive
    }

    static func currentToolDisplayName(for toolName: String) -> String {
        switch toolName {
        case "exec_command", "Bash": return "Bash"
        case "apply_patch": return "Patch"
        case "tool_search", "web_search": return "Search"
        case "update_plan": return "Plan"
        case "request_user_input": return "Question"
        default:
            return toolName
                .split(separator: "_")
                .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                .joined(separator: " ")
        }
    }
}

private extension String {
    var trimmedForIslandSurface: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [x] **Step 4: Implement closed agents grid**

Create `Argo/UI/Island/IslandClosedAgentsGrid.swift`:

```swift
import SwiftUI

enum IslandGridCellState: Equatable {
    case running
    case idle
    case waiting

    init(phase: IslandSessionPhase) {
        if phase.requiresAttention {
            self = .waiting
        } else if phase == .running {
            self = .running
        } else {
            self = .idle
        }
    }
}

enum IslandGridCell {
    case session(hexColor: String, state: IslandGridCellState)
    case overflow(Int)
}

enum IslandRightSlotContent {
    case count(Int)
    case agents([IslandGridCell])
}

struct IslandRightSlotView: View {
    let content: IslandRightSlotContent

    var body: some View {
        switch content {
        case .count(let count):
            Text("×\(count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
        case .agents(let cells):
            IslandClosedAgentsGrid(cells: cells)
        }
    }

    static func balancedRows(_ count: Int) -> [Int] {
        switch count {
        case ..<1: return []
        case 1: return [1]
        case 2: return [2]
        case 3: return [3]
        case 4: return [2, 2]
        case 5: return [3, 2]
        case 6: return [3, 3]
        case 7: return [4, 3]
        case 8: return [4, 4]
        case 9: return [3, 3, 3]
        default: return [4, 4]
        }
    }
}

struct IslandClosedAgentsGrid: View {
    let cells: [IslandGridCell]

    var body: some View {
        let rowSizes = IslandRightSlotView.balancedRows(cells.count)
        let rows = splitIntoRows(cells, rowSizes: rowSizes)
        VStack(spacing: rowSizes.count >= 3 ? 1.5 : 2) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: rowSizes.count >= 3 ? 1.5 : 2) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        IslandGridTile(cell: cell, size: rowSizes.count >= 3 ? 6 : 8)
                    }
                }
            }
        }
        .fixedSize()
    }

    private func splitIntoRows(_ cells: [IslandGridCell], rowSizes: [Int]) -> [[IslandGridCell]] {
        var output: [[IslandGridCell]] = []
        var index = 0
        for size in rowSizes {
            let end = min(index + size, cells.count)
            output.append(Array(cells[index..<end]))
            index = end
            if index >= cells.count { break }
        }
        return output
    }
}

private struct IslandGridTile: View {
    let cell: IslandGridCell
    let size: CGFloat
    @State private var pulse = false

    var body: some View {
        switch cell {
        case .session(let hexColor, let state):
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color(islandHex: hexColor) ?? .white)
                .frame(width: size, height: size)
                .opacity(opacity(for: state))
                .onAppear {
                    if state == .waiting {
                        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }
                }
        case .overflow(let count):
            ZStack {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(.white.opacity(0.14))
                Text("+\(count)")
                    .font(.system(size: max(5, size * 0.55), weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
        }
    }

    private func opacity(for state: IslandGridCellState) -> Double {
        switch state {
        case .running: return 1
        case .idle: return 0.22
        case .waiting: return pulse ? 1 : 0.35
        }
    }
}

private extension Color {
    init?(islandHex hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xff) / 255
        let green = Double((value >> 8) & 0xff) / 255
        let blue = Double(value & 0xff) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
```

- [x] **Step 5: Run presentation tests to verify pass**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionPresentationTests \
  -only-testing:ArgoTests/IslandClosedAgentsGridTests \
  test
```

Expected: PASS.

- [x] **Step 6: Commit**

```bash
git add Argo/Support/IslandSessionPresentation.swift Argo/UI/Island/IslandClosedAgentsGrid.swift Tests/IslandSessionPresentationTests.swift Tests/IslandClosedAgentsGridTests.swift
git commit -m "feat(island): add live grid"
```

### Task 3: 接入 facade 与 rich notify 协议

**Files:**
- Modify: `Argo/Support/IslandNotificationState.swift`
- Modify: `Argo/Domain/IslandNotificationModels.swift`
- Modify: `Argo/Services/AgentNotify/AgentNotifyProtocol.swift`
- Modify: `Argo/Services/AgentNotify/AgentNotifyCLI.swift`
- Test: `Tests/IslandRichNotifyProtocolTests.swift`
- Modify Test: `Tests/AgentNotifyProtocolTests.swift`
- Modify Test: `Tests/AgentNotifyCLITests.swift`
- Modify Test: `Tests/IslandSessionCenterTests.swift`

**Interfaces:**
- Consumes: `IslandSessionState`, `IslandSessionEvent`
- Produces:
  - `IslandNotificationState.post(event:)`
  - `IslandNotificationState.sessions`
  - `AgentNotifyRequest.kind`, `sessionID`, `sourceID`, rich metadata fields
  - `AgentNotifyCLI.Options.kind`, options parsing

- [x] **Step 1: Write failing rich protocol tests**

Create `Tests/IslandRichNotifyProtocolTests.swift`:

```swift
import XCTest
@testable import Argo

final class IslandRichNotifyProtocolTests: XCTestCase {
    func testRichNotifyRoundTripPreservesApprovalFields() throws {
        let request = AgentNotifyRequest(
            title: "Approve command",
            body: "Run tests?",
            paneID: "pane-1",
            workspaceID: "workspace-1",
            agentName: "Codex",
            kind: .approval,
            sessionID: "session-1",
            sourceID: "approval-1",
            currentTool: "exec_command",
            commandPreview: "xcodebuild test",
            options: [
                AgentNotifyOption(label: "Allow", responseText: "1\n"),
                AgentNotifyOption(label: "Deny", responseText: "2\n")
            ]
        )
        let decoded = try AgentNotifyProtocol.decode(try AgentNotifyProtocol.encode(request))
        XCTAssertEqual(decoded.kind, .approval)
        XCTAssertEqual(decoded.sessionID, "session-1")
        XCTAssertEqual(decoded.options?.map(\.label), ["Allow", "Deny"])
        XCTAssertEqual(decoded.commandPreview, "xcodebuild test")
    }

    func testLegacyNotifyDecodeStillWorks() throws {
        let data = Data(#"{"v":1,"title":"Done","body":"ok","pane":"abc"}"#.utf8)
        let decoded = try AgentNotifyProtocol.decode(data)
        XCTAssertEqual(decoded.title, "Done")
        XCTAssertEqual(decoded.body, "ok")
        XCTAssertNil(decoded.kind)
    }
}
```

Append to `Tests/AgentNotifyCLITests.swift`:

```swift
func testParseApprovalOptions() throws {
    let options = try AgentNotifyCLI.parse(arguments: [
        "--approval",
        "--title", "Approve",
        "--option", "Allow=1\\n",
        "--option", "Deny=2\\n",
        "--session", "s1",
        "--source", "approval-1"
    ])
    let request = try AgentNotifyCLI.makeRequest(from: options, environment: [:])
    XCTAssertEqual(request.kind, .approval)
    XCTAssertEqual(request.sessionID, "s1")
    XCTAssertEqual(request.sourceID, "approval-1")
    XCTAssertEqual(request.options?.map(\.label), ["Allow", "Deny"])
}
```

- [x] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandRichNotifyProtocolTests \
  -only-testing:ArgoTests/AgentNotifyCLITests/testParseApprovalOptions \
  test
```

Expected: FAIL with missing `AgentNotifyKind`, `AgentNotifyOption`, and CLI flags.

- [x] **Step 3: Extend protocol models**

Modify `Argo/Services/AgentNotify/AgentNotifyProtocol.swift`:

```swift
enum AgentNotifyKind: String, Codable, Equatable {
    case activity
    case approval
    case question
    case completed
    case failed
}

struct AgentNotifyOption: Codable, Equatable {
    var label: String
    var responseText: String
}
```

Add fields to `AgentNotifyRequest` and `CodingKeys`:

```swift
var kind: AgentNotifyKind?
var sessionID: String?
var sourceID: String?
var currentTool: String?
var commandPreview: String?
var initialPrompt: String?
var latestPrompt: String?
var assistantMessage: String?
var options: [AgentNotifyOption]?
var responseText: String?

case kind
case sessionID = "session"
case sourceID = "source"
case currentTool
case commandPreview
case initialPrompt
case latestPrompt
case assistantMessage
case options
case responseText
```

Update `init` with matching optional parameters defaulting to `nil`.

- [x] **Step 4: Extend CLI parser**

Modify `Argo/Services/AgentNotify/AgentNotifyCLI.swift`:

```swift
enum NotifyKindFlag: String {
    case approval
    case question
    case completed
    case failed
}
```

Add to `AgentNotifyCLI.Options`:

```swift
var kind: AgentNotifyKind?
var sessionID: String?
var sourceID: String?
var currentTool: String?
var commandPreview: String?
var initialPrompt: String?
var latestPrompt: String?
var assistantMessage: String?
var options: [AgentNotifyOption] = []
```

In `parse(arguments:)`, handle flags:

```swift
case "--approval":
    options.kind = .approval
case "--question":
    options.kind = .question
case "--completed":
    options.kind = .completed
case "--failed":
    options.kind = .failed
case "--session":
    options.sessionID = try value(after: argument)
case "--source":
    options.sourceID = try value(after: argument)
case "--current-tool":
    options.currentTool = try value(after: argument)
case "--command-preview":
    options.commandPreview = try value(after: argument)
case "--initial-prompt":
    options.initialPrompt = try value(after: argument)
case "--latest-prompt":
    options.latestPrompt = try value(after: argument)
case "--assistant-message":
    options.assistantMessage = try value(after: argument)
case "--option":
    let raw = try value(after: argument)
    let parts = raw.split(separator: "=", maxSplits: 1).map(String.init)
    let label = parts[0]
    let response = parts.count == 2 ? parts[1].replacingOccurrences(of: "\\n", with: "\n") : "\(label)\n"
    options.options.append(AgentNotifyOption(label: label, responseText: response))
```

In `makeRequest`, pass all new fields. Keep pane fallback:

```swift
let paneID = options.paneID ?? environment[ArgoAgentNotifyEnvironment.paneIDKey]
```

- [x] **Step 5: Implement facade event posting**

Modify `Argo/Support/IslandNotificationState.swift` to add:

```swift
private(set) var sessionState = IslandSessionState() {
    willSet { objectWillChange.send() }
}

var sessions: [IslandAgentSession] { sessionState.sessions }
var prioritySessions: [IslandAgentSession] { sessionState.prioritySessions }
var spotlightSession: IslandAgentSession? { sessionState.spotlightSession }

func post(event: IslandSessionEvent) {
    sessionState.apply(event)
}
```

Keep existing `items` compatibility by moving the current `post(item:)` upsert body into `upsertLegacyItem(_:)`, then also posting the matching session event:

```swift
func post(item: IslandNotificationItem) {
    upsertLegacyItem(item)
    post(event: item.sessionStartedEvent)
}

private func upsertLegacyItem(_ item: IslandNotificationItem) {
    var next = item
    if next.updatedAt < next.startedAt {
        next.updatedAt = now()
    }
    if let index = items.firstIndex(where: { $0.identity == next.identity }) {
        let existingID = items[index].id
        items[index] = IslandNotificationItem(
            id: existingID,
            workspaceID: next.workspaceID,
            worktreePath: next.worktreePath,
            paneID: next.paneID,
            sourceID: next.sourceID,
            title: next.title,
            agentName: next.agentName,
            terminalTag: next.terminalTag,
            status: next.status,
            startedAt: items[index].startedAt,
            updatedAt: next.updatedAt,
            body: next.body,
            prompt: next.prompt,
            action: next.action,
            lastError: next.lastError
        )
    } else {
        items.append(next)
    }
}
```

Add conversion from the legacy item to the new session event:

```swift
extension IslandNotificationItem {
    var sessionID: String {
        sourceID ?? paneID?.uuidString.lowercased() ?? "\(workspaceID.uuidString.lowercased()):\(worktreePath ?? "workspace")"
    }

    var sessionStartedEvent: IslandSessionEvent {
        .sessionStarted(IslandSessionStarted(
            sessionID: sessionID,
            identity: identity,
            title: title,
            tool: IslandAgentTool.from(agentName: agentName),
            initialPhase: IslandSessionPhase(status),
            summary: body ?? title,
            timestamp: updatedAt,
            terminalTag: terminalTag,
            lastError: lastError
        ))
    }
}

extension IslandAgentTool {
    static func from(agentName: String?) -> IslandAgentTool {
        switch agentName?.lowercased() {
        case "claude", "claude code": return .claudeCode
        case "gemini", "gemini cli": return .geminiCLI
        case "opencode": return .openCode
        case "cursor": return .cursor
        case "codex": return .codex
        default: return .argo
        }
    }
}

extension IslandSessionPhase {
    init(_ status: IslandSessionStatus) {
        switch status {
        case .running: self = .running
        case .waitingForApproval: self = .waitingForApproval
        case .waitingForAnswer: self = .waitingForAnswer
        case .completed: self = .completed
        case .failed: self = .failed
        case .stale: self = .stale
        }
    }
}
```

- [x] **Step 6: Run protocol and facade tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandRichNotifyProtocolTests \
  -only-testing:ArgoTests/AgentNotifyCLITests \
  -only-testing:ArgoTests/AgentNotifyProtocolTests \
  -only-testing:ArgoTests/IslandSessionCenterTests \
  test
```

Expected: PASS for listed tests.

- [x] **Step 7: Commit**

```bash
git add Argo/Support/IslandNotificationState.swift Argo/Domain/IslandNotificationModels.swift Argo/Services/AgentNotify/AgentNotifyProtocol.swift Argo/Services/AgentNotify/AgentNotifyCLI.swift Tests/IslandRichNotifyProtocolTests.swift Tests/AgentNotifyProtocolTests.swift Tests/AgentNotifyCLITests.swift Tests/IslandSessionCenterTests.swift
git commit -m "feat(island): add rich notify"
```

### Task 4: 接入 app data flow、surface 与 response dispatcher

**Files:**
- Create: `Argo/UI/Island/IslandSurface.swift`
- Modify: `Argo/App/ArgoDesktopApplication.swift`
- Modify: `Argo/Domain/WorkspaceRuntime.swift`
- Modify: `Argo/App/WorkspaceStore.swift`
- Modify: `Argo/Support/IslandResponseDispatcher.swift`
- Modify: `Argo/UI/Island/IslandPanelController.swift`
- Test: `Tests/IslandSurfaceTests.swift`
- Modify Test: `Tests/IslandResponseDispatcherTests.swift`
- Modify Test: `Tests/IslandWorkspaceNavigatorTests.swift`

**Interfaces:**
- Consumes: rich `AgentNotifyRequest`, `IslandSessionEvent`, `IslandSessionState`
- Produces:
  - `IslandSurface.notificationSurface(for:)`
  - `IslandSurface.matchesCurrentState(of:)`
  - `IslandResponseDispatcher.respond(toSessionID:with:)`
  - `IslandPanelController.navigateToSession(_:)`
  - `IslandPanelController.respondToSession(_:text:)`

- [x] **Step 1: Write failing surface tests**

Create `Tests/IslandSurfaceTests.swift`:

```swift
import XCTest
@testable import Argo

final class IslandSurfaceTests: XCTestCase {
    func testPermissionAndQuestionOpenNotificationSurface() {
        XCTAssertEqual(
            IslandSurface.notificationSurface(for: .permissionRequested(IslandPermissionRequested(
                sessionID: "s",
                request: IslandPermissionRequest(title: "A", summary: "B", affectedPath: "/tmp"),
                timestamp: Date()
            ))),
            .sessionList(actionableSessionID: "s")
        )
        XCTAssertEqual(
            IslandSurface.notificationSurface(for: .questionAsked(IslandQuestionAsked(
                sessionID: "q",
                prompt: IslandQuestionPrompt(title: "Q", options: []),
                timestamp: Date()
            ))),
            .sessionList(actionableSessionID: "q")
        )
    }

    func testSurfaceRejectsResolvedWaitingState() {
        let surface = IslandSurface.sessionList(actionableSessionID: "s")
        let session = IslandAgentSession(
            id: "s",
            identity: IslandSessionIdentity(workspaceID: UUID(), worktreePath: nil, paneID: nil, sourceID: "s"),
            title: "Done",
            tool: .codex,
            phase: .running,
            summary: "Running",
            updatedAt: Date()
        )
        XCTAssertFalse(surface.matchesCurrentState(of: session))
    }
}
```

Update `Tests/IslandResponseDispatcherTests.swift` with:

```swift
func testRespondToSessionOptionResolvesQuestion() {
    let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 20) })
    let paneID = UUID()
    let sessionID = "question"
    state.post(event: .sessionStarted(IslandSessionStarted(
        sessionID: sessionID,
        identity: IslandSessionIdentity(workspaceID: UUID(), worktreePath: "/tmp/repo", paneID: paneID, sourceID: sessionID),
        title: "Question",
        tool: .codex,
        initialPhase: .running,
        summary: "Started",
        timestamp: Date(timeIntervalSince1970: 10)
    )))
    state.post(event: .questionAsked(IslandQuestionAsked(
        sessionID: sessionID,
        prompt: IslandQuestionPrompt(title: "Continue?", options: [IslandQuestionOption(label: "Yes", responseText: "yes\n")]),
        timestamp: Date(timeIntervalSince1970: 11)
    )))
    var sent: [(UUID, String)] = []
    let dispatcher = IslandResponseDispatcher(state: state, sendText: { pane, text in
        sent.append((pane, text))
        return true
    })
    dispatcher.respond(toSessionID: sessionID, with: "yes\n")
    XCTAssertEqual(sent.first?.0, paneID)
    XCTAssertEqual(sent.first?.1, "yes\n")
    XCTAssertEqual(state.sessionState.session(id: sessionID)?.phase, .running)
}
```

- [x] **Step 2: Run tests to verify fail**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSurfaceTests \
  -only-testing:ArgoTests/IslandResponseDispatcherTests/testRespondToSessionOptionResolvesQuestion \
  test
```

Expected: FAIL with missing `IslandSurface` and `respond(toSessionID:with:)`.

- [x] **Step 3: Implement surface**

Create `Argo/UI/Island/IslandSurface.swift`:

```swift
import Foundation

enum IslandSurface: Equatable {
    case sessionList(actionableSessionID: String? = nil)

    var sessionID: String? {
        switch self {
        case let .sessionList(actionableSessionID):
            return actionableSessionID
        }
    }

    var isNotificationCard: Bool { sessionID != nil }

    static func notificationSurface(for event: IslandSessionEvent) -> IslandSurface? {
        switch event {
        case let .permissionRequested(payload):
            return .sessionList(actionableSessionID: payload.sessionID)
        case let .questionAsked(payload):
            return .sessionList(actionableSessionID: payload.sessionID)
        case let .sessionCompleted(payload):
            return .sessionList(actionableSessionID: payload.sessionID)
        case .sessionStarted, .activityUpdated, .actionableStateResolved:
            return nil
        }
    }

    func matchesCurrentState(of session: IslandAgentSession?) -> Bool {
        guard sessionID != nil else { return true }
        guard let session else { return false }
        switch session.phase {
        case .waitingForApproval:
            return session.permissionRequest != nil
        case .waitingForAnswer:
            return session.questionPrompt != nil
        case .completed, .failed:
            return true
        case .running, .stale:
            return false
        }
    }
}
```

- [x] **Step 4: Update dispatcher**

Modify `Argo/Support/IslandResponseDispatcher.swift`:

```swift
func respond(toSessionID sessionID: String, with text: String) {
    guard let session = state.sessionState.session(id: sessionID) else { return }
    guard let paneID = session.identity.paneID else {
        state.markSessionStale(id: sessionID, error: "Pane is no longer available.")
        return
    }
    guard sendText(paneID, text) else {
        state.updateSessionError(id: sessionID, error: "Could not send response to the pane.")
        return
    }
    state.post(event: .actionableStateResolved(IslandActionableStateResolved(
        sessionID: sessionID,
        summary: "Response sent.",
        timestamp: Date()
    )))
}
```

Add these helpers to `IslandNotificationState`:

```swift
func markSessionStale(id: String, error: String) {
    sessionState.markSessionStale(id: id, error: error)
}

func updateSessionError(id: String, error: String) {
    guard var session = sessionState.session(id: id) else { return }
    session.lastError = error
    session.updatedAt = Date()
    sessionState.replace(session)
}
```

Also add `mutating func replace(_ session: IslandAgentSession)` to `IslandSessionState`.

- [x] **Step 5: Route rich notify to events**

Modify `Argo/App/ArgoDesktopApplication.swift` in `routeAgentNotification(_:)` so resolved workspace calls:

```swift
workspace.postAgentNotification(request: request, paneID: paneID)
```

Add overload to `WorkspaceModel` in `Argo/Domain/WorkspaceRuntime.swift`:

```swift
func postAgentNotification(request: AgentNotifyRequest, paneID: UUID?) {
    let identity = IslandSessionIdentity(
        workspaceID: id,
        worktreePath: activeWorktreePath,
        paneID: paneID,
        sourceID: request.sourceID ?? request.sessionID ?? paneID?.uuidString.lowercased()
    )
    let sessionID = request.sessionID ?? identity.sourceID ?? identity.paneID?.uuidString.lowercased() ?? "\(id.uuidString.lowercased()):\(activeWorktreePath)"
    let started = IslandSessionStarted(
        sessionID: sessionID,
        identity: identity,
        title: request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Argo" : request.title,
        tool: IslandAgentTool.from(agentName: request.agentName),
        initialPhase: request.kind?.initialPhase ?? .running,
        summary: request.body ?? request.title,
        timestamp: Date(),
        currentTool: request.currentTool,
        commandPreview: request.commandPreview,
        initialPrompt: request.initialPrompt,
        latestPrompt: request.latestPrompt,
        lastAssistantMessage: request.assistantMessage,
        terminalTag: paneID.map(Self.shortPaneTag(for:))
    )
    var events: [IslandSessionEvent] = [.sessionStarted(started)]
    if let followup = request.followupEvent(sessionID: sessionID) {
        events.append(followup)
    }
    IslandPanelController.shared.present(events: events)
}
```

Add helpers:

```swift
extension AgentNotifyKind {
    var initialPhase: IslandSessionPhase {
        switch self {
        case .approval: return .waitingForApproval
        case .question: return .waitingForAnswer
        case .completed: return .completed
        case .failed: return .failed
        case .activity: return .running
        }
    }
}

extension AgentNotifyRequest {
    func followupEvent(sessionID: String) -> IslandSessionEvent? {
        switch kind {
        case .approval:
            return .permissionRequested(IslandPermissionRequested(
                sessionID: sessionID,
                request: IslandPermissionRequest(
                    title: title,
                    summary: body ?? title,
                    affectedPath: commandPreview ?? "",
                    allowResponseText: options?.first?.responseText ?? "1\n",
                    denyResponseText: options?.dropFirst().first?.responseText ?? "2\n"
                ),
                timestamp: Date()
            ))
        case .question:
            return .questionAsked(IslandQuestionAsked(
                sessionID: sessionID,
                prompt: IslandQuestionPrompt(
                    title: body ?? title,
                    options: options?.map { IslandQuestionOption(label: $0.label, responseText: $0.responseText) } ?? []
                ),
                timestamp: Date()
            ))
        case .completed:
            return .sessionCompleted(IslandSessionCompleted(sessionID: sessionID, summary: body ?? title, timestamp: Date(), failed: false, lastAssistantMessage: assistantMessage))
        case .failed:
            return .sessionCompleted(IslandSessionCompleted(sessionID: sessionID, summary: body ?? title, timestamp: Date(), failed: true, lastAssistantMessage: assistantMessage))
        case .activity, nil:
            return nil
        }
    }
}
```

- [x] **Step 6: Update panel controller surface entry**

Modify `Argo/UI/Island/IslandPanelController.swift`:

```swift
var surface: IslandSurface = .sessionList()

func present(events: [IslandSessionEvent]) {
    for event in events {
        present(event: event)
    }
}

func present(event: IslandSessionEvent) {
    state.post(event: event)
    if let next = IslandSurface.notificationSurface(for: event) {
        surface = next
        state.selectedTab = .sessions
        state.isExpanded = true
    }
    show()
    repositionPanel()
}

func navigateToSession(_ session: IslandAgentSession) {
    let result = WorkspaceNotificationCenter.shared.onNotificationTapped?(
        session.identity.workspaceID,
        session.identity.worktreePath,
        session.identity.paneID
    ) ?? .workspaceMissing
    switch result {
    case .focusedPane, .focusedWorkspace:
        break
    case .paneMissing:
        state.markSessionStale(id: session.id, error: "Pane is no longer available.")
    case .workspaceMissing:
        state.markSessionStale(id: session.id, error: "Workspace is no longer available.")
    }
    repositionPanel()
}

func respondToSession(_ session: IslandAgentSession, text: String) {
    responseDispatcher().respond(toSessionID: session.id, with: text)
    repositionPanel()
}
```

- [x] **Step 7: Run surface/data-flow tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSurfaceTests \
  -only-testing:ArgoTests/IslandResponseDispatcherTests \
  -only-testing:ArgoTests/IslandWorkspaceNavigatorTests \
  test
```

Expected: PASS.

- [x] **Step 8: Commit**

```bash
git add Argo/UI/Island/IslandSurface.swift Argo/App/ArgoDesktopApplication.swift Argo/Domain/WorkspaceRuntime.swift Argo/App/WorkspaceStore.swift Argo/Support/IslandResponseDispatcher.swift Argo/UI/Island/IslandPanelController.swift Tests/IslandSurfaceTests.swift Tests/IslandResponseDispatcherTests.swift Tests/IslandWorkspaceNavigatorTests.swift
git commit -m "feat(island): add card flow"
```

### Task 5: 迁移 collapsed 与 expanded session UI

**Files:**
- Create: `Argo/UI/Island/IslandSessionRow.swift`
- Create: `Argo/UI/Island/IslandSessionSections.swift`
- Modify: `Argo/UI/Island/IslandCollapsedView.swift`
- Modify: `Argo/UI/Island/IslandExpandedView.swift`
- Modify: `Argo/UI/Island/IslandContentView.swift`
- Modify: `Argo/Support/L10n.swift`
- Test: source assertions can be added to `Tests/WorkspaceTabsTests.swift` or a new `Tests/IslandUISourceTests.swift`

**Interfaces:**
- Consumes: `IslandAgentSession`, `IslandSessionState`, `IslandSurface`
- Produces:
  - `IslandSessionRow`
  - `IslandSessionSection`
  - `IslandSessionSectionsView`
  - collapsed right slot from `state.prioritySessions`

- [x] **Step 1: Write failing source-level UI tests**

Create `Tests/IslandUISourceTests.swift`:

```swift
import XCTest

final class IslandUISourceTests: XCTestCase {
    func testCollapsedViewUsesRightSlotAndSpotlightSession() throws {
        let source = try String(contentsOfFile: "Argo/UI/Island/IslandCollapsedView.swift")
        XCTAssertTrue(source.contains("state.spotlightSession"))
        XCTAssertTrue(source.contains("IslandRightSlotView"))
    }

    func testExpandedViewUsesGroupedSessionSections() throws {
        let source = try String(contentsOfFile: "Argo/UI/Island/IslandExpandedView.swift")
        XCTAssertTrue(source.contains("IslandSessionSectionsView"))
        XCTAssertTrue(source.contains("state.prioritySessions"))
    }

    func testSessionRowHasApprovalQuestionAndCompletionBodies() throws {
        let source = try String(contentsOfFile: "Argo/UI/Island/IslandSessionRow.swift")
        XCTAssertTrue(source.contains("approvalActionBody"))
        XCTAssertTrue(source.contains("questionActionBody"))
        XCTAssertTrue(source.contains("completionActionBody"))
    }
}
```

- [x] **Step 2: Run UI source tests to verify fail**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandUISourceTests \
  test
```

Expected: FAIL because source files do not contain the new session UI components.

- [x] **Step 3: Implement session row**

Create `Argo/UI/Island/IslandSessionRow.swift`:

```swift
import SwiftUI

struct IslandSessionRow: View {
    let session: IslandAgentSession
    let referenceDate: Date
    let isActionable: Bool
    let controller: IslandPanelController
    @State private var showsDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summary
            if showsDetail || isActionable {
                detail
            }
        }
        .background(rowFill)
        .contentShape(Rectangle())
        .onTapGesture {
            if session.phase.requiresAttention {
                showsDetail.toggle()
            } else {
                controller.navigateToSession(session)
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 10) {
            islandSessionStatusIcon(session.phase)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(session.spotlightHeadlineText)
                    .font(.system(size: 13.2, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let line = session.spotlightActivityLineText {
                    Text(line)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            IslandTagPill(text: session.tool.shortName.lowercased())
            if let terminalTag = session.terminalTag {
                IslandTagPill(text: terminalTag)
            }
            Text(session.spotlightAgeBadge(at: referenceDate))
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var detail: some View {
        switch session.phase {
        case .waitingForApproval:
            approvalActionBody
        case .waitingForAnswer:
            questionActionBody
        case .completed, .failed:
            completionActionBody
        case .running, .stale:
            if let lastError = session.lastError {
                Text(lastError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.85))
                    .padding(.horizontal, 40)
                    .padding(.bottom, 10)
            }
        }
    }

    private var approvalActionBody: some View {
        HStack(spacing: 8) {
            Button(session.permissionRequest?.primaryActionTitle ?? "Allow") {
                controller.respondToSession(session, text: session.permissionRequest?.allowResponseText ?? "1\n")
            }
            Button(session.permissionRequest?.secondaryActionTitle ?? "Deny") {
                controller.respondToSession(session, text: session.permissionRequest?.denyResponseText ?? "2\n")
            }
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 40)
        .padding(.bottom, 10)
    }

    private var questionActionBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(session.questionPrompt?.options ?? []) { option in
                Button(option.label) {
                    controller.respondToSession(session, text: option.responseText)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 10)
    }

    private var completionActionBody: some View {
        Text(session.lastAssistantMessage ?? session.summary)
            .font(.system(size: 11.5))
            .foregroundStyle(session.phase == .failed ? .red.opacity(0.85) : .white.opacity(0.72))
            .lineLimit(3)
            .padding(.horizontal, 40)
            .padding(.bottom, 10)
    }

    private var rowFill: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(session.phase.requiresAttention ? .orange.opacity(0.08) : .white.opacity(0.02))
    }
}

@ViewBuilder
func islandSessionStatusIcon(_ phase: IslandSessionPhase) -> some View {
    switch phase {
    case .running:
        Circle().fill(.green).frame(width: 8, height: 8)
    case .completed:
        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
    case .failed:
        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
    case .waitingForApproval:
        Image(systemName: "hand.raised.circle.fill").foregroundStyle(.orange)
    case .waitingForAnswer:
        Image(systemName: "questionmark.circle.fill").foregroundStyle(.cyan)
    case .stale:
        Image(systemName: "link.badge.plus").foregroundStyle(.gray)
    }
}
```

- [x] **Step 4: Implement session sections view**

Create `Argo/UI/Island/IslandSessionSections.swift`:

```swift
import SwiftUI

struct IslandSessionSection: Identifiable {
    let id: String
    let titleKey: String
    let sessions: [IslandAgentSession]
}

struct IslandSessionSectionsView: View {
    let sessions: [IslandAgentSession]
    let controller: IslandPanelController

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            LazyVStack(spacing: 4) {
                ForEach(sections) { section in
                    if !section.sessions.isEmpty {
                        Text(LocalizationManager.shared.string(section.titleKey))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.top, 6)
                        ForEach(section.sessions) { session in
                            IslandSessionRow(
                                session: session,
                                referenceDate: context.date,
                                isActionable: session.phase.requiresAttention,
                                controller: controller
                            )
                        }
                    }
                }
            }
        }
    }

    private var sections: [IslandSessionSection] {
        [
            IslandSessionSection(id: "approval", titleKey: "island.section.needsApproval", sessions: sessions.filter { $0.phase == .waitingForApproval }),
            IslandSessionSection(id: "answer", titleKey: "island.section.needsAnswer", sessions: sessions.filter { $0.phase == .waitingForAnswer }),
            IslandSessionSection(id: "running", titleKey: "island.section.inProgress", sessions: sessions.filter { $0.phase == .running }),
            IslandSessionSection(id: "done", titleKey: "island.section.justDone", sessions: sessions.filter { $0.phase == .completed || $0.phase == .failed }),
            IslandSessionSection(id: "idle", titleKey: "island.section.idle", sessions: sessions.filter { $0.phase == .stale })
        ]
    }
}
```

- [x] **Step 5: Update collapsed view**

Modify `Argo/UI/Island/IslandCollapsedView.swift`:

```swift
private var spotlightTitle: String? {
    state.spotlightSession?.spotlightHeadlineText
}

private var rightSlot: IslandRightSlotContent? {
    let sessions = state.prioritySessions
    guard !sessions.isEmpty else { return nil }
    if sessions.count <= 1 { return .count(sessions.count) }
    let cells = sessions.prefix(8).map { session in
        IslandGridCell.session(
            hexColor: session.tool.brandColorHex,
            state: IslandGridCellState(phase: session.phase)
        )
    }
    if sessions.count > 8 {
        return .agents(Array(cells.prefix(7)) + [.overflow(sessions.count - 7)])
    }
    return .agents(Array(cells))
}
```

Replace `state.latestItem` branches with `state.spotlightSession`, and render:

```swift
if let spotlightTitle {
    Text(spotlightTitle)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .lineLimit(1)
        .truncationMode(.tail)
}
if let rightSlot {
    IslandRightSlotView(content: rightSlot)
}
```

- [x] **Step 6: Update expanded sessions tab**

Modify `Argo/UI/Island/IslandExpandedView.swift` sessions tab:

```swift
if state.prioritySessions.isEmpty {
    emptySessionsView
} else {
    ScrollView {
        IslandSessionSectionsView(
            sessions: state.prioritySessions,
            controller: controller
        )
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
    }
}
```

- [x] **Step 7: Add localization keys**

Modify `Argo/Support/L10n.swift`, add English and Simplified Chinese keys:

```swift
"island.section.needsApproval": "Needs approval",
"island.section.needsAnswer": "Needs answer",
"island.section.inProgress": "In progress",
"island.section.justDone": "Just done",
"island.section.idle": "Idle",
"island.action.showAll": "Show All",
```

```swift
"island.section.needsApproval": "需要审批",
"island.section.needsAnswer": "需要回答",
"island.section.inProgress": "进行中",
"island.section.justDone": "刚完成",
"island.section.idle": "空闲",
"island.action.showAll": "显示全部",
```

- [x] **Step 8: Run UI source tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandUISourceTests \
  test
```

Expected: PASS.

- [x] **Step 9: Commit**

```bash
git add Argo/UI/Island/IslandSessionRow.swift Argo/UI/Island/IslandSessionSections.swift Argo/UI/Island/IslandCollapsedView.swift Argo/UI/Island/IslandExpandedView.swift Argo/UI/Island/IslandContentView.swift Argo/Support/L10n.swift Tests/IslandUISourceTests.swift
git commit -m "feat(island): add session ui"
```

### Task 6: 将 Workspace status message 改成 ephemeral session event

**Files:**
- Modify: `Argo/App/WorkspaceStore.swift`
- Modify Test: `Tests/WorkspaceStoreTests.swift`

**Interfaces:**
- Consumes: `WorkspaceEvent.statusMessage`, `IslandSessionStarted`, `IslandPanelController.present(event:)`
- Produces:
  - dynamic island enabled + `deliverSystemNotification == true` 时不再写 legacy `IslandNotificationItem`
  - success status message 映射为 `.completed` session
  - warning status message 映射为 `.failed` session，`lastError == text`
  - neutral status message 映射为 `.running` session

- [x] **Step 1: Write the failing WorkspaceStore test**

Append this test to `Tests/WorkspaceStoreTests.swift`:

```swift
func testDynamicIslandStatusMessagePostsSessionEvent() throws {
    let directoryURL = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }
    let workspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
    let store = WorkspaceStore(persistsWorkspaceState: false)
    store.workspaces = [workspace]
    store.selectedWorkspaceID = workspace.id
    store.updateAppSettings(AppSettings(dynamicIslandEnabled: true))

    IslandNotificationState.shared.clearAll()
    defer { IslandNotificationState.shared.clearAll() }

    store.receive(.statusMessage(
        "Setup complete",
        .success,
        deliverSystemNotification: true,
        workspaceID: workspace.id,
        worktreePath: workspace.activeWorktreePath
    ))

    XCTAssertTrue(IslandNotificationState.shared.items.isEmpty)
    let successSession = try XCTUnwrap(IslandNotificationState.shared.sessions.first)
    XCTAssertEqual(successSession.title, "Setup complete")
    XCTAssertEqual(successSession.phase, .completed)

    store.receive(.statusMessage(
        "Setup failed",
        .warning,
        deliverSystemNotification: true,
        workspaceID: workspace.id,
        worktreePath: workspace.activeWorktreePath
    ))

    let warningSession = try XCTUnwrap(IslandNotificationState.shared.sessionState.session(
        id: "status:\(workspace.id.uuidString.lowercased()):Setup failed"
    ))
    XCTAssertEqual(warningSession.phase, .failed)
    XCTAssertEqual(warningSession.lastError, "Setup failed")
}
```

- [x] **Step 2: Run the focused test to verify it fails**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceStoreTests/testDynamicIslandStatusMessagePostsSessionEvent \
  test
```

Expected: FAIL because `WorkspaceStore.receive(.statusMessage...)` still constructs `IslandNotificationItem`, so `IslandNotificationState.shared.items` is not empty.

- [x] **Step 3: Replace the dynamic-island branch with a session event**

Modify `Argo/App/WorkspaceStore.swift` inside `receive(_:)`, in the `.statusMessage` case. Replace the whole `if deliverSystemNotification && appSettings.dynamicIslandEnabled { ... }` body with:

```swift
// Dynamic Island takes priority — skip toast and system notification.
let resolvedWorkspaceID = workspaceID ?? selectedWorkspace?.id ?? UUID()
let timestamp = Date()
let sessionID = "status:\(resolvedWorkspaceID.uuidString.lowercased()):\(text)"

let phase: IslandSessionPhase
let lastError: String?
switch tone {
case .success:
    phase = .completed
    lastError = nil
case .warning:
    phase = .failed
    lastError = text
case .neutral:
    phase = .running
    lastError = nil
}

let event = IslandSessionEvent.sessionStarted(IslandSessionStarted(
    sessionID: sessionID,
    identity: IslandSessionIdentity(
        workspaceID: resolvedWorkspaceID,
        worktreePath: worktreePath,
        paneID: nil,
        sourceID: sessionID
    ),
    title: text,
    tool: .argo,
    initialPhase: phase,
    summary: text,
    timestamp: timestamp,
    lastError: lastError
))
IslandPanelController.shared.present(event: event)
```

Keep the `else` toast/system-notification branch unchanged.

- [x] **Step 4: Run the focused test to verify it passes**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceStoreTests/testDynamicIslandStatusMessagePostsSessionEvent \
  test
```

Expected: PASS.

- [x] **Step 5: Run related island tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceStoreTests/testDynamicIslandStatusMessagePostsSessionEvent \
  -only-testing:ArgoTests/IslandSessionCenterTests \
  -only-testing:ArgoTests/IslandSurfaceTests \
  test
```

Expected: PASS.

- [x] **Step 6: Commit**

```bash
git add Argo/App/WorkspaceStore.swift Tests/WorkspaceStoreTests.swift
git commit -m "feat(island): add status event"
```

### Task 7: 清理 session-only 路径上的 legacy item UI 依赖

**Files:**
- Modify: `Argo/UI/Island/IslandPanelController.swift`
- Modify: `Argo/Support/IslandNotificationState.swift`
- Modify Test: `Tests/IslandUISourceTests.swift`
- Modify Test: `Tests/IslandSessionCenterTests.swift`

**Interfaces:**
- Consumes: `IslandNotificationState.spotlightSession`, `IslandNotificationState.liveSessionCount`
- Produces:
  - collapsed panel width uses session spotlight text first
  - no force unwrap of `state.latestItem` in collapsed sizing
  - dismissing the last legacy item does not collapse the island when live session-only records remain

- [x] **Step 1: Write failing source and state tests**

Append to `Tests/IslandUISourceTests.swift`:

```swift
func testPanelCollapsedWidthUsesSpotlightSessionWithoutLegacyForceUnwrap() throws {
    let source = try sourceFile("Argo/UI/Island/IslandPanelController.swift")

    XCTAssertTrue(source.contains("state.spotlightSession"))
    XCTAssertFalse(source.contains("state.latestItem!"))
}
```

Append to `Tests/IslandSessionCenterTests.swift`:

```swift
func testDismissLegacyItemKeepsExpandedWhenSessionOnlyRecordRemains() {
    let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 10) })
    let legacyItem = makeItem(title: "legacy")
    let sessionOnlyID = "session-only"

    state.post(item: legacyItem)
    state.post(event: .sessionStarted(IslandSessionStarted(
        sessionID: sessionOnlyID,
        identity: IslandSessionIdentity(
            workspaceID: UUID(),
            worktreePath: "/tmp/repo",
            paneID: nil,
            sourceID: sessionOnlyID
        ),
        title: "Session only",
        tool: .codex,
        initialPhase: .running,
        summary: "Running",
        timestamp: Date(timeIntervalSince1970: 11)
    )))
    state.isExpanded = true

    state.dismiss(id: legacyItem.id)

    XCTAssertTrue(state.isExpanded)
    XCTAssertEqual(state.sessionState.session(id: sessionOnlyID)?.phase, .running)
}
```

- [x] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandUISourceTests/testPanelCollapsedWidthUsesSpotlightSessionWithoutLegacyForceUnwrap \
  -only-testing:ArgoTests/IslandSessionCenterTests/testDismissLegacyItemKeepsExpandedWhenSessionOnlyRecordRemains \
  test
```

Expected: FAIL because `IslandPanelController.collapsedWidth()` still force unwraps `state.latestItem`, and `IslandNotificationState.dismiss(id:)` collapses when `items.isEmpty` without checking live sessions.

- [x] **Step 3: Make collapsed sizing session-first**

Modify `Argo/UI/Island/IslandPanelController.swift`:

```swift
private func collapsedWidth() -> CGFloat {
    let title = state.spotlightSession?.spotlightHeadlineText ?? state.latestItem?.title
    guard let title else {
        return collapsedMaxWidth
    }

    let font = NSFont.systemFont(ofSize: 13, weight: .medium)
    let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
    let hasBadge = state.badgeCount > 1
    let badgeWidth: CGFloat = hasBadge ? 26 : 0
    let totalWidth = 14 + 10 + textWidth + 4 + badgeWidth + 32
    return min(max(ceil(totalWidth), collapsedMinWidth), collapsedMaxWidth)
}
```

- [x] **Step 4: Keep the island expanded while session-only records remain**

Modify `Argo/Support/IslandNotificationState.swift` in `dismiss(id:)`:

```swift
func dismiss(id: UUID) {
    if let item = items.first(where: { $0.id == id }) {
        sessionState.dismissSession(id: item.sessionID)
    }
    items.removeAll { $0.id == id }
    if items.isEmpty && sessionState.liveSessionCount == 0 {
        isExpanded = false
    }
}
```

- [x] **Step 5: Run the focused tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandUISourceTests/testPanelCollapsedWidthUsesSpotlightSessionWithoutLegacyForceUnwrap \
  -only-testing:ArgoTests/IslandSessionCenterTests/testDismissLegacyItemKeepsExpandedWhenSessionOnlyRecordRemains \
  test
```

Expected: PASS.

- [x] **Step 6: Commit**

```bash
git add Argo/UI/Island/IslandPanelController.swift Argo/Support/IslandNotificationState.swift Tests/IslandUISourceTests.swift Tests/IslandSessionCenterTests.swift
git commit -m "fix(island): use sessions"
```

### Task 8: 让超时 completed session 折叠到 Idle

**Files:**
- Modify: `Argo/Support/IslandSessionPresentation.swift`
- Modify: `Argo/UI/Island/IslandSessionSections.swift`
- Modify Test: `Tests/IslandSessionPresentationTests.swift`
- Create Test: `Tests/IslandSessionSectionsTests.swift`

**Interfaces:**
- Consumes:
  - `IslandAgentSession.staleCompletedDisplayThreshold`
  - `IslandAgentSession.phase`
  - `IslandAgentSession.updatedAt`
- Produces:
  - `func IslandAgentSession.isStaleCompletedForIsland(at:threshold:) -> Bool`
  - `static func IslandSessionSectionsView.sections(for:referenceDate:) -> [IslandSessionSection]`
  - completed sessions newer than threshold stay in `Just Done`
  - completed sessions older than or equal to threshold move to `Idle`
  - failed sessions stay in `Just Done`

- [x] **Step 1: Write failing stale-completed tests**

Append this test to `Tests/IslandSessionPresentationTests.swift`:

```swift
func testCompletedSessionBecomesStaleForIslandAfterThreshold() {
    let session = makeSession(
        phase: .completed,
        updatedAt: Date(timeIntervalSince1970: 0)
    )

    XCTAssertFalse(session.isStaleCompletedForIsland(
        at: Date(timeIntervalSince1970: IslandAgentSession.staleCompletedDisplayThreshold - 1)
    ))
    XCTAssertTrue(session.isStaleCompletedForIsland(
        at: Date(timeIntervalSince1970: IslandAgentSession.staleCompletedDisplayThreshold)
    ))
}
```

Create `Tests/IslandSessionSectionsTests.swift`:

```swift
import XCTest
@testable import Argo

final class IslandSessionSectionsTests: XCTestCase {
    func testStaleCompletedSessionsMoveFromJustDoneToIdle() {
        let recent = makeSession(
            id: "recent",
            phase: .completed,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let stale = makeSession(
            id: "stale",
            phase: .completed,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let sections = IslandSessionSectionsView.sections(
            for: [recent, stale],
            referenceDate: Date(timeIntervalSince1970: IslandAgentSession.staleCompletedDisplayThreshold)
        )

        XCTAssertEqual(section(sections, id: "done")?.sessions.map(\.id), ["recent"])
        XCTAssertEqual(section(sections, id: "idle")?.sessions.map(\.id), ["stale"])
    }

    private func section(_ sections: [IslandSessionSection], id: String) -> IslandSessionSection? {
        sections.first { $0.id == id }
    }

    private func makeSession(
        id: String,
        phase: IslandSessionPhase,
        updatedAt: Date
    ) -> IslandAgentSession {
        IslandAgentSession(
            id: id,
            identity: IslandSessionIdentity(
                workspaceID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                worktreePath: "/tmp/repo",
                paneID: nil,
                sourceID: id
            ),
            title: id,
            tool: .codex,
            phase: phase,
            summary: id,
            updatedAt: updatedAt
        )
    }
}
```

- [x] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionPresentationTests/testCompletedSessionBecomesStaleForIslandAfterThreshold \
  -only-testing:ArgoTests/IslandSessionSectionsTests/testStaleCompletedSessionsMoveFromJustDoneToIdle \
  test
```

Expected: FAIL because `IslandAgentSession.isStaleCompletedForIsland(at:)` does not exist, and `IslandSessionSectionsView.sections(for:referenceDate:)` is not available to tests.

- [x] **Step 3: Add stale-completed presentation helper**

Modify `Argo/Support/IslandSessionPresentation.swift`, inside `nonisolated extension IslandAgentSession` after `islandPresence(at:)`:

```swift
func isStaleCompletedForIsland(
    at referenceDate: Date,
    threshold: TimeInterval = Self.staleCompletedDisplayThreshold
) -> Bool {
    phase == .completed && referenceDate.timeIntervalSince(updatedAt) >= threshold
}
```

- [x] **Step 4: Extract section grouping and move stale completed sessions to Idle**

Modify `Argo/UI/Island/IslandSessionSections.swift`. In `body`, replace `ForEach(sections)` with:

```swift
ForEach(Self.sections(for: sessions, referenceDate: context.date)) { section in
```

Replace the private computed `sections` property with this static helper:

```swift
static func sections(
    for sessions: [IslandAgentSession],
    referenceDate: Date
) -> [IslandSessionSection] {
    [
        IslandSessionSection(
            id: "approval",
            titleKey: "island.section.needsApproval",
            sessions: sessions.filter { $0.phase == .waitingForApproval }
        ),
        IslandSessionSection(
            id: "answer",
            titleKey: "island.section.needsAnswer",
            sessions: sessions.filter { $0.phase == .waitingForAnswer }
        ),
        IslandSessionSection(
            id: "running",
            titleKey: "island.section.inProgress",
            sessions: sessions.filter { $0.phase == .running }
        ),
        IslandSessionSection(
            id: "done",
            titleKey: "island.section.justDone",
            sessions: sessions.filter {
                ($0.phase == .completed && !$0.isStaleCompletedForIsland(at: referenceDate))
                    || $0.phase == .failed
            }
        ),
        IslandSessionSection(
            id: "idle",
            titleKey: "island.section.idle",
            sessions: sessions.filter {
                $0.phase == .stale || $0.isStaleCompletedForIsland(at: referenceDate)
            }
        )
    ]
}
```

- [x] **Step 5: Run focused tests to verify pass**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionPresentationTests/testCompletedSessionBecomesStaleForIslandAfterThreshold \
  -only-testing:ArgoTests/IslandSessionSectionsTests/testStaleCompletedSessionsMoveFromJustDoneToIdle \
  test
```

Expected: PASS.

- [x] **Step 6: Run related presentation/UI tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionPresentationTests \
  -only-testing:ArgoTests/IslandSessionSectionsTests \
  -only-testing:ArgoTests/IslandUISourceTests \
  test
```

Expected: PASS.

- [x] **Step 7: Commit**

```bash
git add Argo/Support/IslandSessionPresentation.swift Argo/UI/Island/IslandSessionSections.swift Tests/IslandSessionPresentationTests.swift Tests/IslandSessionSectionsTests.swift
git commit -m "feat(island): add stale idle"
```

### Task 9: 补齐 approval card 的命令与路径上下文

**Files:**
- Modify: `Argo/Support/IslandSessionPresentation.swift`
- Modify: `Argo/UI/Island/IslandSessionRow.swift`
- Modify Test: `Tests/IslandSessionPresentationTests.swift`
- Modify Test: `Tests/IslandUISourceTests.swift`

**Interfaces:**
- Consumes:
  - `IslandAgentSession.commandPreview`
  - `IslandAgentSession.permissionRequest`
  - `IslandPermissionRequest.summary`
  - `IslandPermissionRequest.affectedPath`
- Produces:
  - `IslandAgentSession.approvalCommandPreviewText`
  - `IslandAgentSession.approvalAffectedPathText`
  - `IslandSessionRow.approvalContextBlock`
  - approval rows that show request title, command preview or summary fallback, affected path, then Deny/Allow actions.

- [x] **Step 1: Write the failing presentation and UI source tests**

Append this test to `Tests/IslandSessionPresentationTests.swift`:

```swift
func testApprovalContextPrefersCommandPreviewAndAffectedPath() {
    let session = makeSession(
        phase: .waitingForApproval,
        currentTool: "exec_command",
        commandPreview: "xcodebuild test",
        permissionRequest: IslandPermissionRequest(
            title: "Approval needed",
            summary: "Run tests?",
            affectedPath: "/tmp/repo"
        )
    )

    XCTAssertEqual(session.approvalCommandPreviewText, "xcodebuild test")
    XCTAssertEqual(session.approvalAffectedPathText, "/tmp/repo")
}
```

Update the `makeSession` helper in `Tests/IslandSessionPresentationTests.swift` so it accepts and forwards `permissionRequest`:

```swift
private func makeSession(
    title: String = "Codex",
    phase: IslandSessionPhase = .running,
    updatedAt: Date = Date(timeIntervalSince1970: 0),
    initialPrompt: String? = nil,
    worktreePath: String = "/repo/main",
    currentTool: String? = nil,
    commandPreview: String? = nil,
    permissionRequest: IslandPermissionRequest? = nil
) -> IslandAgentSession {
    IslandAgentSession(
        id: "s",
        identity: IslandSessionIdentity(
            workspaceID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            worktreePath: worktreePath,
            paneID: nil,
            sourceID: "s"
        ),
        title: title,
        tool: .codex,
        phase: phase,
        summary: "summary",
        updatedAt: updatedAt,
        permissionRequest: permissionRequest,
        currentTool: currentTool,
        commandPreview: commandPreview,
        initialPrompt: initialPrompt
    )
}
```

Append this source assertion to `Tests/IslandUISourceTests.swift`:

```swift
func testApprovalRowShowsCommandAndAffectedPathContext() throws {
    let source = try sourceFile("Argo/UI/Island/IslandSessionRow.swift")

    XCTAssertTrue(source.contains("approvalCommandPreviewText"))
    XCTAssertTrue(source.contains("approvalAffectedPathText"))
}
```

- [x] **Step 2: Run focused tests to verify they fail**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionPresentationTests/testApprovalContextPrefersCommandPreviewAndAffectedPath \
  -only-testing:ArgoTests/IslandUISourceTests/testApprovalRowShowsCommandAndAffectedPathContext \
  test
```

Expected: FAIL with missing `approvalCommandPreviewText` and `approvalAffectedPathText`.

- [x] **Step 3: Add approval context presentation helpers**

Modify `Argo/Support/IslandSessionPresentation.swift`, inside `nonisolated extension IslandAgentSession` after `isStaleCompletedForIsland(at:threshold:)`:

```swift
var approvalCommandPreviewText: String? {
    if let commandPreview = commandPreview?.trimmedForIslandSurface, !commandPreview.isEmpty {
        return commandPreview
    }
    if let summary = permissionRequest?.summary.trimmedForIslandSurface, !summary.isEmpty {
        return summary
    }
    return nil
}

var approvalAffectedPathText: String? {
    guard let affectedPath = permissionRequest?.affectedPath.trimmedForIslandSurface,
          !affectedPath.isEmpty else {
        return nil
    }
    return affectedPath
}
```

- [x] **Step 4: Replace the compact approval button row with contextual approval body**

Modify `Argo/UI/Island/IslandSessionRow.swift`. Replace `approvalActionBody` with:

```swift
private var approvalActionBody: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(session.permissionRequest?.title ?? "Approval needed")
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(.white.opacity(0.72))

        if session.approvalCommandPreviewText != nil || session.approvalAffectedPathText != nil {
            approvalContextBlock
        }

        HStack(spacing: 8) {
            Button(session.permissionRequest?.secondaryActionTitle ?? "Deny") {
                controller.respondToSession(session, text: session.permissionRequest?.denyResponseText ?? "2\n")
            }
            Button(session.permissionRequest?.primaryActionTitle ?? "Allow") {
                controller.respondToSession(session, text: session.permissionRequest?.allowResponseText ?? "1\n")
            }
        }
        .buttonStyle(.bordered)
    }
    .padding(.horizontal, 40)
    .padding(.bottom, 10)
}
```

Add this helper below it:

```swift
private var approvalContextBlock: some View {
    VStack(alignment: .leading, spacing: 6) {
        if let commandPreview = session.approvalCommandPreviewText {
            Text(commandPreview)
                .font(.system(size: 11.2, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let affectedPath = session.approvalAffectedPathText {
            Text(affectedPath)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)
        }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
        RoundedRectangle(cornerRadius: 7)
            .fill(.white.opacity(0.045))
    )
}
```

- [x] **Step 5: Run focused tests to verify pass**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionPresentationTests/testApprovalContextPrefersCommandPreviewAndAffectedPath \
  -only-testing:ArgoTests/IslandUISourceTests/testApprovalRowShowsCommandAndAffectedPathContext \
  test
```

Expected: PASS.

- [x] **Step 6: Run related presentation/UI regression tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionPresentationTests \
  -only-testing:ArgoTests/IslandUISourceTests \
  -only-testing:ArgoTests/IslandSurfaceTests \
  -only-testing:ArgoTests/IslandResponseDispatcherTests \
  test
```

Expected: PASS.

- [x] **Step 7: Run whitespace check**

Run:

```bash
git diff --check
```

Expected: no output.

- [x] **Step 8: Commit**

```bash
git add Argo/Support/IslandSessionPresentation.swift Argo/UI/Island/IslandSessionRow.swift Tests/IslandSessionPresentationTests.swift Tests/IslandUISourceTests.swift
git commit -m "feat(island): add approval ctx"
```

### Task 10: 将 affected path 纳入 rich notify 协议

**Files:**
- Modify: `Argo/Services/AgentNotify/AgentNotifyProtocol.swift`
- Modify: `Argo/Services/AgentNotify/AgentNotifyCLI.swift`
- Modify Test: `Tests/IslandRichNotifyProtocolTests.swift`
- Modify Test: `Tests/AgentNotifyCLITests.swift`

**Interfaces:**
- Consumes:
  - `AgentNotifyRequest.followupEvent(sessionID:summary:timestamp:)`
  - `IslandPermissionRequest.affectedPath`
- Produces:
  - `AgentNotifyRequest.affectedPath`
  - JSON field `"affectedPath"`
  - CLI flag `--affected-path`
  - approval follow-up events where `IslandPermissionRequest.affectedPath == request.affectedPath ?? ""`
  - replacement for the temporary Task 4 behavior that used `commandPreview` as the affected path fallback.

- [x] **Step 1: Write failing protocol and CLI tests**

Append this test to `Tests/IslandRichNotifyProtocolTests.swift`:

```swift
func testRichNotifyRoundTripPreservesAffectedPath() throws {
    let request = AgentNotifyRequest(
        title: "Approve command",
        body: "Run tests?",
        paneID: "pane-1",
        workspaceID: "workspace-1",
        agentName: "Codex",
        kind: .approval,
        sessionID: "session-1",
        sourceID: "approval-1",
        currentTool: "exec_command",
        commandPreview: "xcodebuild test",
        affectedPath: "/tmp/repo",
        options: [
            AgentNotifyOption(label: "Allow", responseText: "1\n"),
            AgentNotifyOption(label: "Deny", responseText: "2\n")
        ]
    )

    let decoded = try AgentNotifyProtocol.decode(try AgentNotifyProtocol.encode(request))
    XCTAssertEqual(decoded.affectedPath, "/tmp/repo")

    let event = try XCTUnwrap(decoded.followupEvent(
        sessionID: "session-1",
        summary: "Run tests?",
        timestamp: Date(timeIntervalSince1970: 10)
    ))
    guard case let .permissionRequested(payload) = event else {
        return XCTFail("Expected permissionRequested")
    }
    XCTAssertEqual(payload.request.affectedPath, "/tmp/repo")
}
```

Append this test to `Tests/AgentNotifyCLITests.swift`:

```swift
func testParseApprovalAffectedPath() throws {
    let options = try AgentNotifyCLI.parse(arguments: [
        "--approval",
        "--title", "Approve",
        "--command-preview", "xcodebuild test",
        "--affected-path", "/tmp/repo",
        "--option", "Allow=1\\n",
        "--option", "Deny=2\\n"
    ])
    let request = try AgentNotifyCLI.makeRequest(from: options, environment: [:])

    XCTAssertEqual(request.kind, .approval)
    XCTAssertEqual(request.commandPreview, "xcodebuild test")
    XCTAssertEqual(request.affectedPath, "/tmp/repo")
}
```

- [x] **Step 2: Run focused tests to verify they fail**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandRichNotifyProtocolTests/testRichNotifyRoundTripPreservesAffectedPath \
  -only-testing:ArgoTests/AgentNotifyCLITests/testParseApprovalAffectedPath \
  test
```

Expected: FAIL with missing `AgentNotifyRequest.affectedPath` and missing `--affected-path`.

- [x] **Step 3: Add affectedPath to the wire model**

Modify `Argo/Services/AgentNotify/AgentNotifyProtocol.swift`. Add the field:

```swift
var affectedPath: String?
```

Add the coding key:

```swift
case affectedPath
```

Add the initializer parameter after `commandPreview`:

```swift
affectedPath: String? = nil,
```

Assign it inside `init`:

```swift
self.affectedPath = affectedPath
```

In `AgentNotifyRequest.followupEvent(sessionID:summary:timestamp:)`, change the approval request construction to:

```swift
request: IslandPermissionRequest(
    title: title,
    summary: summary,
    affectedPath: affectedPath ?? "",
    primaryActionTitle: options?.first?.label ?? "Allow",
    secondaryActionTitle: options?.dropFirst().first?.label ?? "Deny",
    allowResponseText: options?.first?.responseText ?? "1\n",
    denyResponseText: options?.dropFirst().first?.responseText ?? "2\n"
)
```

- [x] **Step 4: Add affectedPath to the CLI parser**

Modify `Argo/Services/AgentNotify/AgentNotifyCLI.swift`. Add to `AgentNotifyCLI.Options`:

```swift
var affectedPath: String?
```

In `parse(arguments:)`, handle the flag:

```swift
case "--affected-path":
    guard index + 1 < arguments.count else {
        throw ParseError.missingValue(flag: argument)
    }
    options.affectedPath = arguments[index + 1]
    index += 1
```

In `makeRequest(from:environment:)`, pass the new field:

```swift
affectedPath: options.affectedPath.flatMap { $0.isEmpty ? nil : $0 },
```

Update `usageText` so approval examples and options mention path context:

```swift
argo notify --approval --title <text> --body <text>
             [--command-preview <text>] [--affected-path <path>]
             --option "Allow=1\\n" --option "Deny=2\\n"
```

```swift
--affected-path <path> Approval path context shown in Dynamic Island
```

- [x] **Step 5: Run focused tests to verify pass**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandRichNotifyProtocolTests/testRichNotifyRoundTripPreservesAffectedPath \
  -only-testing:ArgoTests/AgentNotifyCLITests/testParseApprovalAffectedPath \
  test
```

Expected: PASS.

- [x] **Step 6: Run notify protocol regression tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandRichNotifyProtocolTests \
  -only-testing:ArgoTests/AgentNotifyCLITests \
  -only-testing:ArgoTests/AgentNotifyProtocolTests \
  test
```

Expected: PASS.

- [x] **Step 7: Commit**

```bash
git add Argo/Services/AgentNotify/AgentNotifyProtocol.swift Argo/Services/AgentNotify/AgentNotifyCLI.swift Tests/IslandRichNotifyProtocolTests.swift Tests/AgentNotifyCLITests.swift
git commit -m "feat(island): add approval path"
```

### Task 11: 集成验证与文档收口

**Files:**
- Modify: `docs/superpowers/specs/2026-06-22-dynamic-island-open-vibe-parity-design.md` only if implementation discovers necessary clarifications
- Test: all island and notify tests

**Interfaces:**
- Consumes all prior tasks, including Task 6, Task 7, Task 8, Task 9, and Task 10.
- Produces a verified implementation branch ready for review.

- [x] **Step 1: Run focused test suite**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionStateTests \
  -only-testing:ArgoTests/IslandSessionPresentationTests \
  -only-testing:ArgoTests/IslandSurfaceTests \
  -only-testing:ArgoTests/IslandClosedAgentsGridTests \
  -only-testing:ArgoTests/IslandSessionSectionsTests \
  -only-testing:ArgoTests/IslandRichNotifyProtocolTests \
  -only-testing:ArgoTests/IslandResponseDispatcherTests \
  -only-testing:ArgoTests/IslandWorkspaceNavigatorTests \
  -only-testing:ArgoTests/IslandSessionCenterTests \
  -only-testing:ArgoTests/IslandUISourceTests \
  -only-testing:ArgoTests/WorkspaceStoreTests/testDynamicIslandStatusMessagePostsSessionEvent \
  -only-testing:ArgoTests/AgentNotifyCLITests \
  -only-testing:ArgoTests/AgentNotifyProtocolTests \
  test
```

Expected: PASS for all listed tests.

- [x] **Step 2: Run full app test suite**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  test
```

Expected: PASS for `ArgoTests`.

- [ ] **Step 3: Manual smoke checklist**

Run Argo Debug build locally and cover:

```text
1. Enable Dynamic Island.
2. Open one workspace with two terminal panes.
3. Run `argo notify --title "Pane A running"` from pane A.
4. Run `argo notify --title "Pane B running"` from pane B.
5. Confirm collapsed island shows agents grid or count.
6. Expand island and confirm Sessions groups show both sessions.
7. Run `argo notify --approval --title "Approve command" --body "Run tests?" --current-tool exec_command --command-preview "xcodebuild test" --affected-path "$PWD" --option "Allow=1\n" --option "Deny=2\n"` from pane A.
8. Confirm notification card appears, shows the command preview and affected path, and Sessions retains the approval record.
9. Click Allow and confirm text is inserted into pane A.
10. Run `argo notify --question --title "Deploy target" --body "Which target?" --option "Production=Production\n" --option "Staging=Staging\n"` from pane B.
11. Click Staging and confirm text is inserted into pane B.
12. Trigger completed and failed notifications and confirm Just Done ordering and error display.
13. Keep a completed session visible for at least `IslandAgentSession.staleCompletedDisplayThreshold` seconds and confirm it moves from Just Done to Idle.
14. Trigger a workspace status success with `deliverSystemNotification: true` and confirm it appears as a completed session without creating a legacy item.
15. Trigger a workspace status warning with `deliverSystemNotification: true` and confirm it appears as a failed session with the warning text as `lastError`.
16. Click sessions from the expanded list and confirm Argo focuses the correct workspace/worktree/pane.
```

Expected: all checklist items pass. Record any failed item in the final implementation summary.

- [ ] **Step 4: Commit verification-only doc clarification if needed**

Only if the implementation changed a design decision, update the spec with the exact resolved decision and commit:

```bash
git add docs/superpowers/specs/2026-06-22-dynamic-island-open-vibe-parity-design.md
git commit -m "feat(island): sync spec"
```

If no spec clarification is needed, do not create this commit.

### Task 12: 补运行态 smoke 脚本与 approval card 诊断

**Files:**
- Create: `scripts/smoke_dynamic_island_notify.sh`

**Interfaces:**
- Consumes: the Debug `Argo.app` produced by `xcodebuild -project Argo.xcodeproj -scheme Argo -configuration Debug`.
- Consumes: `$ARGO_PANE_ID` injected by `ShellSession` into an Argo terminal pane.
- Produces: repeatable screenshots in `/tmp/argo-island-smoke/` proving real IPC, route, panel surface, and card rendering.

- [x] **Step 1: Create the smoke script**

Create `scripts/smoke_dynamic_island_notify.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ARGO_ISLAND_SMOKE_DIR:-/tmp/argo-island-smoke}"
mkdir -p "$OUT"

resolve_argo_bin() {
  if [[ -n "${ARGO_BIN:-}" && -x "${ARGO_BIN}" ]]; then
    printf '%s\n' "$ARGO_BIN"
    return 0
  fi

  local settings="$OUT/build-settings.txt"
  xcodebuild \
    -project "$ROOT/Argo.xcodeproj" \
    -scheme Argo \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    -showBuildSettings > "$settings"

  local products
  products="$(awk -F'= ' '/ BUILT_PRODUCTS_DIR = / {print $2; exit}' "$settings")"
  local candidate="$products/Argo.app/Contents/MacOS/Argo"
  if [[ -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  find "$HOME/Library/Developer/Xcode/DerivedData" \
    -path '*/Build/Products/Debug/Argo.app/Contents/MacOS/Argo' \
    -type f \
    -print |
    while IFS= read -r path; do
      stat -f '%m %N' "$path"
    done |
    sort -nr |
    head -n 1 |
    cut -d' ' -f2-
}

ARGO_BIN="$(resolve_argo_bin)"
if [[ -z "${ARGO_BIN:-}" || ! -x "$ARGO_BIN" ]]; then
  echo "smoke: could not find a Debug Argo binary; run xcodebuild build first or pass ARGO_BIN=/path/to/Argo" >&2
  exit 1
fi

if [[ -z "${ARGO_PANE_ID:-}" ]]; then
  echo "smoke: ARGO_PANE_ID is missing; run this script from inside an Argo terminal pane" >&2
  exit 2
fi

echo "smoke: using $ARGO_BIN"
echo "smoke: pane $ARGO_PANE_ID"

"$ARGO_BIN" notify \
  --activity \
  --title "Smoke activity" \
  --body "Pane activity route" \
  --pane "$ARGO_PANE_ID" \
  --session "smoke-activity" \
  --tool Codex \
  --current-tool exec_command
sleep 0.8
screencapture -x "$OUT/activity.png" || true

"$ARGO_BIN" notify \
  --approval \
  --title "Approve command" \
  --body "Run tests?" \
  --pane "$ARGO_PANE_ID" \
  --session "smoke-approval" \
  --source "smoke-approval" \
  --tool Codex \
  --current-tool exec_command \
  --command-preview "xcodebuild test" \
  --affected-path "$PWD" \
  --option "Allow=1\\n" \
  --option "Deny=2\\n"
sleep 1.0
screencapture -x "$OUT/approval-card.png" || true

"$ARGO_BIN" notify \
  --question \
  --title "Deploy target" \
  --body "Which target?" \
  --pane "$ARGO_PANE_ID" \
  --session "smoke-question" \
  --source "smoke-question" \
  --tool Codex \
  --option "Production=Production\\n" \
  --option "Staging=Staging\\n"
sleep 1.0
screencapture -x "$OUT/question-card.png" || true

"$ARGO_BIN" notify \
  --completed \
  --title "Smoke complete" \
  --summary "All clear" \
  --pane "$ARGO_PANE_ID" \
  --session "smoke-complete" \
  --source "smoke-complete" \
  --tool Codex
sleep 0.8
screencapture -x "$OUT/completed-card.png" || true

echo "smoke: screenshots written to $OUT"
echo "smoke: approval-card.png must show Approve command, xcodebuild test, and $PWD"
echo "smoke: click Allow in the island and confirm the focused pane receives 1 plus a newline"
echo "smoke: click Staging in the island and confirm the focused pane receives Staging plus a newline"
```

- [x] **Step 2: Make the script executable**

Run:

```bash
chmod +x scripts/smoke_dynamic_island_notify.sh
```

Expected: `scripts/smoke_dynamic_island_notify.sh` is executable.

- [ ] **Step 3: Run the script from inside a real Argo pane**

Run this command inside an Argo terminal pane, not from an external terminal:

```bash
scripts/smoke_dynamic_island_notify.sh
```

Expected:

```text
smoke: screenshots written to /tmp/argo-island-smoke
smoke: approval-card.png must show Approve command, xcodebuild test, and <current working directory>
```

Expected screenshots:

```text
/tmp/argo-island-smoke/activity.png
/tmp/argo-island-smoke/approval-card.png
/tmp/argo-island-smoke/question-card.png
/tmp/argo-island-smoke/completed-card.png
```

- [ ] **Step 4: Confirm the previous no-card failure mode is not reproduced**

Run:

```bash
open /tmp/argo-island-smoke/approval-card.png
open /tmp/argo-island-smoke/question-card.png
```

Expected:

```text
approval-card.png shows:
- Approve command
- Run tests?
- xcodebuild test
- the current working directory as affected path
- Allow and Deny actions

question-card.png shows:
- Deploy target
- Which target?
- Production and Staging actions
```

- [ ] **Step 5: Verify action write-back**

In the visible island card:

```text
1. Click Allow on the approval card.
2. Confirm the same Argo pane receives `1` followed by a newline.
3. Send the question event again if the question card is no longer visible:
   scripts/smoke_dynamic_island_notify.sh
4. Click Staging on the question card.
5. Confirm the same Argo pane receives `Staging` followed by a newline.
```

Expected: both responses are inserted into the pane identified by `$ARGO_PANE_ID`, and the session row returns from waiting state to running/resolved state.

- [x] **Step 6: Commit the smoke script**

```bash
git add scripts/smoke_dynamic_island_notify.sh docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
git commit -m "feat(island): add smoke"
```

### Task 13: 防止 notification card 被鼠标离开自动折叠

**Files:**
- Modify: `Argo/UI/Island/IslandPanelController.swift`
- Modify: `Tests/IslandSurfaceTests.swift`

**Interfaces:**
- Consumes: `IslandPanelController.activeSurfaceSession`
- Produces: `IslandPanelController.shouldCollapseAfterMouseExit`

- [x] **Step 1: Write the failing controller behavior tests**

Append to `Tests/IslandSurfaceTests.swift`:

```swift
@MainActor
func testNotificationSurfaceDoesNotAutoCollapseWhenMouseLeaves() {
    let controller = IslandPanelController.shared
    let state = controller.state
    state.clearAll()
    defer {
        state.clearAll()
        controller.surface = .sessionList()
    }

    state.post(event: .sessionStarted(IslandSessionStarted(
        sessionID: "approval",
        identity: IslandSessionIdentity(workspaceID: UUID(), worktreePath: "/tmp/repo", paneID: nil, sourceID: "approval"),
        title: "Approve",
        tool: .codex,
        initialPhase: .running,
        summary: "Started",
        timestamp: Date(timeIntervalSince1970: 10)
    )))
    state.post(event: .permissionRequested(IslandPermissionRequested(
        sessionID: "approval",
        request: IslandPermissionRequest(title: "Approve", summary: "Run tests", affectedPath: "/tmp/repo"),
        timestamp: Date(timeIntervalSince1970: 11)
    )))
    controller.surface = .sessionList(actionableSessionID: "approval")
    state.isExpanded = true

    XCTAssertFalse(controller.shouldCollapseAfterMouseExit)
}

@MainActor
func testSessionListStillAutoCollapsesWhenMouseLeaves() {
    let controller = IslandPanelController.shared
    let state = controller.state
    state.clearAll()
    defer {
        state.clearAll()
        controller.surface = .sessionList()
    }

    controller.surface = .sessionList()
    state.isExpanded = true

    XCTAssertTrue(controller.shouldCollapseAfterMouseExit)
}
```

- [x] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSurfaceTests/testNotificationSurfaceDoesNotAutoCollapseWhenMouseLeaves \
  -only-testing:ArgoTests/IslandSurfaceTests/testSessionListStillAutoCollapsesWhenMouseLeaves \
  test
```

Expected: FAIL with `value of type 'IslandPanelController' has no member 'shouldCollapseAfterMouseExit'`.

- [x] **Step 3: Implement the collapse guard**

Modify `Argo/UI/Island/IslandPanelController.swift`:

```swift
var shouldCollapseAfterMouseExit: Bool {
    activeSurfaceSession == nil
}
```

In `checkMousePosition()`, gate the scheduled collapse:

```swift
if state.isExpanded && collapseTask == nil && shouldCollapseAfterMouseExit {
    collapseTask = Task { @MainActor in
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard !Task.isCancelled else { return }
        guard self.shouldCollapseAfterMouseExit else {
            self.collapseTask = nil
            return
        }
        self.state.isExpanded = false
        self.state.currentGroupID = nil
        self.repositionPanel()
        self.collapseTask = nil
    }
}
```

- [x] **Step 4: Run focused tests to verify pass**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSurfaceTests \
  test
```

Expected: PASS for `IslandSurfaceTests`.

- [ ] **Step 5: Re-run Task 12 smoke after Debug Argo is relaunched**

Run from a real Argo pane after restarting the Debug app onto the newly built binary:

```bash
scripts/smoke_dynamic_island_notify.sh
```

Expected: `/tmp/argo-island-smoke/approval-card.png` captures the expanded approval card after the 1 second wait.

- [x] **Step 6: Commit**

```bash
git add Argo/UI/Island/IslandPanelController.swift Tests/IslandSurfaceTests.swift docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
git commit -m "fix(island): keep card open"
```

### Task 14: 最终 parity audit 与发布前验收

**Files:**
- Modify: `docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md` if audit results need to be recorded for handoff.

**Interfaces:**
- Consumes: all committed implementation tasks and Task 12 smoke screenshots.
- Produces: final evidence that Argo Dynamic Island matches the accepted first-stage `open-vibe-island` parity scope.

Execute Task 14 only after every later focused parity patch in this document has been implemented, verified, and either committed or explicitly left as a no-op. Task 14 is the final gate, even when new corrective tasks are appended below it.

- [x] **Step 1: Confirm the branch only has expected local changes**

Run:

```bash
git status --short --branch
```

Expected: only deliberate smoke-plan/script changes are present before the smoke commit; after the smoke commit, the branch is clean except unrelated local artifacts such as `default.profraw`.

Observed on 2026-06-22 before final audit commit:

```text
## codex/dynamic-island-parity
 M Argo/Support/IslandSessionState.swift
 M Argo/UI/Island/IslandSessionSections.swift
 M Tests/IslandSessionStateTests.swift
 M Tests/IslandUISourceTests.swift
 M docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
?? default.profraw
```

Only deliberate Task 27 code/test/doc changes are present; `default.profraw` remains unstaged.

- [x] **Step 2: Run full verification one last time**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  test
```

Expected: `TEST SUCCEEDED`.

Run:

```bash
git diff --check
```

Expected: no output.

Observed on 2026-06-22:

```text
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' test -> exit 0
git diff --check -> no output
```

- [x] **Step 3: Run the complete runtime audit matrix**

Use the Debug app and real Argo panes. Verify each item exactly:

```text
1. Activity event from pane A appears in collapsed island.
2. Activity event from pane B adds a second live session.
3. Collapsed island shows agents grid or count for both live sessions.
4. Expanded Sessions tab groups both live sessions under Running.
5. Approval event opens a notification card immediately.
6. Approval card displays command preview and affected path.
7. Approval card Show All returns to grouped Sessions without losing the waiting record.
8. Allow writes the configured response text into the originating pane.
9. Deny writes the configured response text into the originating pane.
10. Question event opens a notification card immediately.
11. Question option writes the configured response text into the originating pane.
12. Completed event appears under Just Done.
13. Failed event appears above Running and displays lastError.
14. A completed session older than `IslandAgentSession.staleCompletedDisplayThreshold` moves to Idle.
15. Workspace status success appears as a completed session and does not create a legacy item.
16. Workspace status warning appears as a failed session and does not create a legacy item.
17. Clicking a session focuses the correct workspace, worktree, and pane.
18. Dismissing or resolving an actionable session returns the surface to the session list when appropriate.
```

Expected: all 18 items pass. If any item fails, do not mark the goal complete; add a new focused task below Task 14 with the failing item number, the observed screenshot path, and the exact test or code path to fix. If approval has more than two actions, include that case in item 8 and confirm every visible action writes its configured response text.

Observed final runtime audit on 2026-06-22: all 18 Task 14 Step 3 items have concrete `PASS` evidence in the Task 26/Task 27 audit notes below. The final runtime-only gaps were closed by:

```text
17. /tmp/argo-island-smoke-real-pane/task27-final-focus-list-before-click.png
    /tmp/argo-island-smoke-real-pane/task27-final-click-focus-b-marker.txt -> task27-final-click-focus-b-ok
    /tmp/argo-island-smoke-real-pane/task27-final-display2-after-click-focus-b.png
18. /tmp/argo-island-smoke-real-pane/task27-resolve-final-card-display1.png
    /tmp/argo-island-smoke-real-pane/task27-resolve-final-marker.txt -> task27-resolve-final-ok
    /tmp/argo-island-smoke-real-pane/task27-final-sessions-list-display1.png
```

- [x] **Step 4: Compare against open-vibe first-stage parity scope**

Open the reference UI file:

```bash
sed -n '1643,1695p' /Users/liaojingyu/open-vibe-island/Sources/OpenIslandApp/Views/IslandPanelView.swift
```

Expected Argo parity:

```text
1. Approval/question are durable session records, not one-shot notifications.
2. Approval card has contextual command/path information.
3. Waiting states are visually prioritized over running/completed states.
4. Expanded view preserves grouped session history.
5. Collapsed view summarizes multiple live agents.
6. The action path writes back to the originating pane.
```

Observed on 2026-06-22: reference `IslandPanelView.swift` lines 1643-1695 were reviewed. The Argo runtime evidence confirms the accepted first-stage parity scope: durable approval/question rows, command/path context, prioritized waiting/running grouping, grouped session history, collapsed multi-agent summary, and originating-pane write-back.

- [x] **Step 5: Final commit or no-op**

If Task 14 only verifies behavior and changes no files, do not commit.

If Task 14 records an audit note in this plan, commit only that doc update:

```bash
git add docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
git commit -m "feat(island): sync audit"
```

### Task 15: 防止 smoke 使用旧 Debug Argo 进程造成误判

**Files:**
- Modify: `scripts/smoke_dynamic_island_notify.sh`
- Modify: `docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md`

**Interfaces:**
- Consumes:
  - `ARGO_BIN` or the resolved Debug `Argo.app/Contents/MacOS/Argo` executable.
  - Running macOS process list for `Argo.app/Contents/MacOS/Argo`.
  - Binary modification time from `stat -f '%m'`.
- Produces:
  - `validate_running_argo_binary "$ARGO_BIN"` guard.
  - Exit code `3` when a running Argo app process is older than the Debug binary.
  - Built-in smoke script self-test mode via `ARGO_ISLAND_SMOKE_SELF_TEST=1`.
  - A clear message asking the worker to restart the Debug Argo app before runtime smoke.

- [x] **Step 1: Run the missing self-test mode to capture the current failure**

Run:

```bash
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh
```

Expected: FAIL, currently with:

```text
smoke: ARGO_PANE_ID is missing; run this script from inside an Argo terminal pane
```

This failure is correct before implementation because the script has no self-test entry point and checks `ARGO_PANE_ID` too early.

- [x] **Step 2: Refactor the script into `main` so self-tests can run without an Argo pane**

Modify `scripts/smoke_dynamic_island_notify.sh`. Keep the existing `ROOT` and `OUT` declarations near the top, then move all current top-level smoke behavior into:

```bash
main() {
  if [[ "${ARGO_ISLAND_SMOKE_SELF_TEST:-}" == "1" ]]; then
    run_self_tests
    return
  fi

  if [[ -z "${ARGO_PANE_ID:-}" ]]; then
    echo "smoke: ARGO_PANE_ID is missing; run this script from inside an Argo terminal pane" >&2
    exit 2
  fi

  ARGO_BIN="$(resolve_argo_bin)"
  if [[ -z "${ARGO_BIN:-}" || ! -x "$ARGO_BIN" ]]; then
    echo "smoke: could not find a Debug Argo binary; run xcodebuild build first or pass ARGO_BIN=/path/to/Argo" >&2
    exit 1
  fi

  validate_running_argo_binary "$ARGO_BIN"

  echo "smoke: using $ARGO_BIN"
  echo "smoke: pane $ARGO_PANE_ID"

  send_smoke_events
}

main "$@"
```

Move the four existing `"$ARGO_BIN" notify ...` blocks and their `screencapture` calls into:

```bash
send_smoke_events() {
  "$ARGO_BIN" notify \
    --activity \
    --title "Smoke activity" \
    --body "Pane activity route" \
    --pane "$ARGO_PANE_ID" \
    --session "smoke-activity" \
    --tool Codex \
    --current-tool exec_command
  sleep 0.8
  screencapture -x "$OUT/activity.png" || true

  "$ARGO_BIN" notify \
    --approval \
    --title "Approve command" \
    --body "Run tests?" \
    --pane "$ARGO_PANE_ID" \
    --session "smoke-approval" \
    --source "smoke-approval" \
    --tool Codex \
    --current-tool exec_command \
    --command-preview "xcodebuild test" \
    --affected-path "$PWD" \
    --option "Allow=1\\n" \
    --option "Deny=2\\n"
  sleep 1.0
  screencapture -x "$OUT/approval-card.png" || true

  "$ARGO_BIN" notify \
    --question \
    --title "Deploy target" \
    --body "Which target?" \
    --pane "$ARGO_PANE_ID" \
    --session "smoke-question" \
    --source "smoke-question" \
    --tool Codex \
    --option "Production=Production\\n" \
    --option "Staging=Staging\\n"
  sleep 1.0
  screencapture -x "$OUT/question-card.png" || true

  "$ARGO_BIN" notify \
    --completed \
    --title "Smoke complete" \
    --summary "All clear" \
    --pane "$ARGO_PANE_ID" \
    --session "smoke-complete" \
    --source "smoke-complete" \
    --tool Codex
  sleep 0.8
  screencapture -x "$OUT/completed-card.png" || true

  echo "smoke: screenshots written to $OUT"
  echo "smoke: approval-card.png must show Approve command, xcodebuild test, and $PWD"
  echo "smoke: click Allow in the island and confirm the focused pane receives 1 plus a newline"
  echo "smoke: click Staging in the island and confirm the focused pane receives Staging plus a newline"
}
```

- [x] **Step 3: Add injectable process freshness helpers**

Add these functions below `resolve_argo_bin()`:

```bash
binary_mtime() {
  local argo_bin="$1"
  if [[ -n "${ARGO_ISLAND_SMOKE_FAKE_BINARY_MTIME:-}" ]]; then
    printf '%s\n' "$ARGO_ISLAND_SMOKE_FAKE_BINARY_MTIME"
    return 0
  fi
  stat -f '%m' "$argo_bin"
}

running_argo_pids() {
  if [[ -n "${ARGO_ISLAND_SMOKE_FAKE_PIDS:-}" ]]; then
    tr ' ' '\n' <<< "$ARGO_ISLAND_SMOKE_FAKE_PIDS" | sed '/^$/d'
    return 0
  fi

  local pid
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    local command
    command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    [[ "$command" == *"/Argo.app/Contents/MacOS/Argo"* ]] || continue
    [[ "$command" == *" notify "* ]] && continue
    printf '%s\n' "$pid"
  done < <(pgrep -f '/Argo.app/Contents/MacOS/Argo' 2>/dev/null || true)
}

pid_start_epoch() {
  local pid="$1"
  local fake_var="ARGO_ISLAND_SMOKE_FAKE_PID_START_${pid}"
  if [[ -n "${!fake_var:-}" ]]; then
    printf '%s\n' "${!fake_var}"
    return 0
  fi

  local start
  start="$(ps -p "$pid" -o lstart= 2>/dev/null | sed 's/^ *//')"
  [[ -n "$start" ]] || return 1
  LC_TIME=C date -j -f "%a %b %e %T %Y" "$start" "+%s"
}

pid_start_label() {
  local pid="$1"
  local fake_var="ARGO_ISLAND_SMOKE_FAKE_PID_LABEL_${pid}"
  if [[ -n "${!fake_var:-}" ]]; then
    printf '%s\n' "${!fake_var}"
    return 0
  fi
  ps -p "$pid" -o lstart= 2>/dev/null | sed 's/^ *//'
}

validate_running_argo_binary() {
  local argo_bin="$1"
  local bin_mtime
  bin_mtime="$(binary_mtime "$argo_bin")"

  local stale=0
  local found=0
  local pid
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    found=1

    local start_epoch
    start_epoch="$(pid_start_epoch "$pid" || true)"
    [[ -n "$start_epoch" ]] || continue

    if (( start_epoch < bin_mtime )); then
      echo "smoke: running Argo pid $pid is older than the Debug binary" >&2
      echo "smoke: pid start: $(pid_start_label "$pid")" >&2
      echo "smoke: binary: $argo_bin" >&2
      echo "smoke: restart the Debug Argo app before running Dynamic Island smoke" >&2
      stale=1
    fi
  done < <(running_argo_pids)

  if [[ "$stale" -eq 1 ]]; then
    return 3
  fi

  if [[ "$found" -eq 0 ]]; then
    echo "smoke: warning: no running Argo app process found for freshness check" >&2
  fi
}
```

- [x] **Step 4: Add the built-in self-tests**

Add:

```bash
run_self_tests() {
  local fixture_bin="$OUT/self-test-Argo"
  : > "$fixture_bin"
  chmod +x "$fixture_bin"

  local stale_log="$OUT/self-test-stale.log"
  set +e
  ARGO_ISLAND_SMOKE_FAKE_BINARY_MTIME=200 \
    ARGO_ISLAND_SMOKE_FAKE_PIDS="123" \
    ARGO_ISLAND_SMOKE_FAKE_PID_START_123=100 \
    ARGO_ISLAND_SMOKE_FAKE_PID_LABEL_123="Mon Jun 22 10:32:59 2026" \
    validate_running_argo_binary "$fixture_bin" >"$stale_log" 2>&1
  local stale_status=$?
  set -e

  if [[ "$stale_status" -ne 3 ]]; then
    echo "self-test: expected stale guard exit 3, got $stale_status" >&2
    cat "$stale_log" >&2
    return 1
  fi

  if ! grep -q "restart the Debug Argo app" "$stale_log"; then
    echo "self-test: stale guard did not print restart guidance" >&2
    cat "$stale_log" >&2
    return 1
  fi

  ARGO_ISLAND_SMOKE_FAKE_BINARY_MTIME=100 \
    ARGO_ISLAND_SMOKE_FAKE_PIDS="123" \
    ARGO_ISLAND_SMOKE_FAKE_PID_START_123=200 \
    validate_running_argo_binary "$fixture_bin" >/dev/null

  echo "self-test: OK"
}
```

- [x] **Step 5: Run the self-test to verify the stale guard passes**

Run:

```bash
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh
```

Expected:

```text
self-test: OK
```

- [x] **Step 6: Verify syntax and no-pane behavior**

Run:

```bash
bash -n scripts/smoke_dynamic_island_notify.sh
```

Expected: no output.

Run:

```bash
env -u ARGO_PANE_ID bash scripts/smoke_dynamic_island_notify.sh
```

Expected: exit code `2` with:

```text
smoke: ARGO_PANE_ID is missing; run this script from inside an Argo terminal pane
```

- [ ] **Step 7: Re-run runtime smoke only after the guard accepts the running app**

From a real Argo pane:

```bash
scripts/smoke_dynamic_island_notify.sh
```

Expected:

```text
smoke: using <Debug Argo binary>
smoke: pane <ARGO_PANE_ID>
smoke: screenshots written to /tmp/argo-island-smoke
```

If the script exits `3`, restart the Debug Argo app onto the current binary and rerun this step. Do not treat screenshots from an older running app as valid parity evidence.

- [x] **Step 8: Commit**

```bash
git add scripts/smoke_dynamic_island_notify.sh docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
git commit -m "fix(island): guard smoke"
```

### Task 16: 保留 approval 的全部 action options

**Files:**
- Modify: `Argo/Domain/IslandAgentModels.swift`
- Modify: `Argo/Services/AgentNotify/AgentNotifyProtocol.swift`
- Modify: `Argo/UI/Island/IslandSessionRow.swift`
- Test: `Tests/IslandRichNotifyProtocolTests.swift`
- Test: `Tests/IslandUISourceTests.swift`

**Interfaces:**
- Consumes:
  - `AgentNotifyRequest.options: [AgentNotifyOption]?`
  - `IslandPermissionRequest.primaryActionTitle`
  - `IslandPermissionRequest.secondaryActionTitle`
  - `IslandPermissionRequest.allowResponseText`
  - `IslandPermissionRequest.denyResponseText`
- Produces:
  - `struct IslandPermissionAction: Equatable, Identifiable, Codable, Sendable`
  - `IslandPermissionRequest.actions: [IslandPermissionAction]`
  - Approval rows that render every action in `actions`, preserving option order and response text.

- [x] **Step 1: Write the failing protocol test**

Add this test to `Tests/IslandRichNotifyProtocolTests.swift`:

```swift
func testApprovalFollowupPreservesAllActionOptions() throws {
    let request = AgentNotifyRequest(
        title: "Approve command",
        body: "Run tests?",
        kind: .approval,
        options: [
            AgentNotifyOption(label: "Deny", responseText: "2\n"),
            AgentNotifyOption(label: "Allow once", responseText: "1\n"),
            AgentNotifyOption(label: "Always allow", responseText: "always\n")
        ]
    )

    let event = try XCTUnwrap(request.followupEvent(
        sessionID: "session-1",
        summary: "Run tests?",
        timestamp: Date(timeIntervalSince1970: 10)
    ))
    guard case let .permissionRequested(payload) = event else {
        return XCTFail("Expected permissionRequested")
    }
    XCTAssertEqual(payload.request.actions.map(\.title), ["Deny", "Allow once", "Always allow"])
    XCTAssertEqual(payload.request.actions.map(\.responseText), ["2\n", "1\n", "always\n"])
}
```

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandRichNotifyProtocolTests/testApprovalFollowupPreservesAllActionOptions \
  test
```

Expected before implementation: FAIL because `IslandPermissionRequest` has no `actions` array or the third option is dropped.

- [x] **Step 2: Write the failing UI source test**

Add this test to `Tests/IslandUISourceTests.swift`:

```swift
func testApprovalRowRendersAllPermissionActions() throws {
    let source = try sourceFile("Argo/UI/Island/IslandSessionRow.swift")

    XCTAssertTrue(source.contains("session.permissionRequest?.actions"))
    XCTAssertTrue(source.contains("approvalButtonKind"))
    XCTAssertFalse(source.contains("allowResponseText ?? \"1\\n\""))
    XCTAssertFalse(source.contains("denyResponseText ?? \"2\\n\""))
}
```

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandUISourceTests/testApprovalRowRendersAllPermissionActions \
  test
```

Expected before implementation: FAIL because the row renders only the old fixed Allow/Deny buttons.

- [x] **Step 3: Add permission action modeling**

Modify `Argo/Domain/IslandAgentModels.swift`:

```swift
nonisolated struct IslandPermissionAction: Equatable, Identifiable, Codable, Sendable {
    var id: UUID
    var title: String
    var responseText: String

    init(id: UUID = UUID(), title: String, responseText: String) {
        self.id = id
        self.title = title
        self.responseText = responseText
    }
}
```

Add `actions` to `IslandPermissionRequest` while preserving the legacy fields:

```swift
var actions: [IslandPermissionAction]
```

Update the initializer signature:

```swift
actions: [IslandPermissionAction]? = nil
```

Update the initializer body:

```swift
self.actions = actions ?? [
    IslandPermissionAction(title: secondaryActionTitle, responseText: denyResponseText),
    IslandPermissionAction(title: primaryActionTitle, responseText: allowResponseText)
]
```

Expected: existing callers that only provide `allowResponseText` and `denyResponseText` still get two buttons in the old Deny/Allow visual order.

- [x] **Step 4: Preserve all approval options in the rich notify bridge**

Modify `Argo/Services/AgentNotify/AgentNotifyProtocol.swift` inside the `.approval` branch of `followupEvent(sessionID:summary:timestamp:)`:

```swift
request: IslandPermissionRequest(
    title: title,
    summary: summary,
    affectedPath: affectedPath ?? "",
    primaryActionTitle: options?.first?.label ?? "Allow",
    secondaryActionTitle: options?.dropFirst().first?.label ?? "Deny",
    allowResponseText: options?.first?.responseText ?? "1\n",
    denyResponseText: options?.dropFirst().first?.responseText ?? "2\n",
    actions: options?.map {
        IslandPermissionAction(title: $0.label, responseText: $0.responseText)
    }
),
```

Expected: `--option "Deny=2\n" --option "Allow once=1\n" --option "Always allow=always\n"` becomes three visible actions with the same order and response text.

- [x] **Step 5: Render every approval action with Argo-native button styling**

Modify `Argo/UI/Island/IslandSessionRow.swift`, replacing the fixed two-button approval row with:

```swift
HStack(spacing: 8) {
    ForEach(Array((session.permissionRequest?.actions ?? []).enumerated()), id: \.element.id) { index, action in
        Button(action.title) {
            controller.respondToSession(session, text: action.responseText)
        }
        .buttonStyle(IslandActionButtonStyle(
            kind: approvalButtonKind(for: action, index: index),
            expands: true
        ))
    }
}
```

Add the local button-kind helper:

```swift
private func approvalButtonKind(
    for action: IslandPermissionAction,
    index: Int
) -> IslandActionButtonStyle.Kind {
    let normalized = action.title.lowercased()
    if normalized.contains("deny")
        || normalized.contains("reject")
        || normalized.contains("cancel")
        || normalized == "no" {
        return .secondary
    }
    if normalized.contains("always")
        || normalized.contains("permanent") {
        return .primary
    }
    return index == 0 && (session.permissionRequest?.actions.count ?? 0) == 1 ? .primary : .warning
}
```

Expected: destructive/negative actions are secondary, permanent allow actions are primary, and ordinary allow actions keep the warning treatment used by the approval card.

- [x] **Step 6: Run the focused tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandRichNotifyProtocolTests/testApprovalFollowupPreservesAllActionOptions \
  -only-testing:ArgoTests/IslandUISourceTests/testApprovalRowRendersAllPermissionActions \
  test
```

Expected: `TEST SUCCEEDED`.

- [x] **Step 7: Run the related regression set**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandRichNotifyProtocolTests \
  -only-testing:ArgoTests/IslandUISourceTests \
  -only-testing:ArgoTests/IslandResponseDispatcherTests \
  -only-testing:ArgoTests/AgentNotifyCLITests \
  test
```

Expected: `TEST SUCCEEDED`.

Run:

```bash
git diff --check
```

Expected: no output.

- [x] **Step 8: Commit**

```bash
git add Argo/Domain/IslandAgentModels.swift Argo/Services/AgentNotify/AgentNotifyProtocol.swift Argo/UI/Island/IslandSessionRow.swift Tests/IslandRichNotifyProtocolTests.swift Tests/IslandUISourceTests.swift docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
git commit -m "feat(island): add actions"
```

### Task 17: 让 runtime smoke 覆盖 approval 多 action

**Files:**
- Modify: `scripts/smoke_dynamic_island_notify.sh`
- Modify: `docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md`

**Interfaces:**
- Consumes:
  - `scripts/smoke_dynamic_island_notify.sh` `send_smoke_events()`
  - `ARGO_ISLAND_SMOKE_SELF_TEST=1`
- Produces:
  - Approval smoke event with three actions: `Allow`, `Deny`, `Always allow`.
  - Self-test that fails when `send_smoke_events()` stops carrying the `Always allow` option.
  - Runtime instruction asking the worker to click `Always allow` and confirm `always\n` is written to the pane.

- [x] **Step 1: Add the failing smoke self-test**

Modify `scripts/smoke_dynamic_island_notify.sh` inside `run_self_tests()`:

```bash
local smoke_body
smoke_body="$(sed -n '/^send_smoke_events()/,/^main()/p' "$0")"
if ! grep -Fq -- '--option "Always allow=always\\n"' <<< "$smoke_body"; then
  echo "self-test: approval smoke must include the Always allow action" >&2
  return 1
fi
```

Run:

```bash
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh
```

Expected before implementation:

```text
self-test: approval smoke must include the Always allow action
```

- [x] **Step 2: Add the third approval action to the smoke event**

Modify the approval notify block in `send_smoke_events()`:

```bash
--option "Allow=1\\n" \
--option "Deny=2\\n" \
--option "Always allow=always\\n"
```

Expected: the runtime smoke approval card exercises all approval action rendering and write-back, including the third action introduced by Task 16.

- [x] **Step 3: Add the manual write-back prompt**

Modify the smoke output near the end of `send_smoke_events()`:

```bash
echo "smoke: click Always allow in the island and confirm the focused pane receives always plus a newline"
```

Expected: the worker has explicit runtime evidence instructions for the third approval action.

- [x] **Step 4: Run script verification**

Run:

```bash
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh
```

Expected:

```text
self-test: OK
```

Run:

```bash
bash -n scripts/smoke_dynamic_island_notify.sh
```

Expected: no output.

Run:

```bash
git diff --check
```

Expected: no output.

- [x] **Step 5: Commit**

```bash
git add scripts/smoke_dynamic_island_notify.sh
git add -f docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
git commit -m "feat(island): smoke actions"
```

### Task 18: 记录静态 parity audit，并恢复 runtime audit 执行路径

**Files:**
- Modify: `docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md`

**Interfaces:**
- Consumes:
  - `open-vibe-island/Sources/OpenIslandApp/Views/IslandPanelView.swift` approval/question/completion row implementation.
  - `Argo/Support/IslandSessionState.swift`
  - `Argo/UI/Island/IslandSessionRow.swift`
  - `Argo/UI/Island/IslandCollapsedView.swift`
  - `Argo/UI/Island/IslandExpandedView.swift`
  - `Argo/UI/Island/IslandSurface.swift`
  - `Argo/Support/IslandResponseDispatcher.swift`
  - `Argo/Services/AgentNotify/AgentNotifyProtocol.swift`
  - `scripts/smoke_dynamic_island_notify.sh`
- Produces:
  - A documented static parity table for the accepted first-stage scope.
  - A concrete runtime unblock checklist for stale Debug Argo processes and real-pane smoke.
  - No code changes unless the audit finds a gap that must be fixed by a later focused Task.

- [x] **Step 1: Re-run the static source evidence commands**

Run:

```bash
nl -ba /Users/liaojingyu/open-vibe-island/Sources/OpenIslandApp/Views/IslandPanelView.swift | sed -n '1643,1765p'
```

Expected: output includes the reference `approvalActionBody`, `questionActionBody`, `completionActionBody`, command preview display, affected path display, Deny/Allow actions, and optional Always Allow-style action.

Run:

```bash
nl -ba Argo/Support/IslandSessionState.swift | sed -n '56,135p'
```

Expected: output includes durable handling for `.sessionStarted`, `.permissionRequested`, `.questionAsked`, `.sessionCompleted`, and `.actionableStateResolved`; `.activityUpdated` must preserve an existing waiting state when a running update arrives.

Run:

```bash
nl -ba Argo/UI/Island/IslandSessionRow.swift | sed -n '67,150p'
```

Expected: output includes `approvalActionBody`, `questionActionBody`, `completionActionBody`, `approvalContextBlock`, `approvalCommandPreviewText`, `approvalAffectedPathText`, and `session.permissionRequest?.actions`.

Run:

```bash
nl -ba Argo/UI/Island/IslandCollapsedView.swift | sed -n '20,39p'
```

Expected: output shows `state.spotlightSession`, `state.prioritySessions`, `IslandGridCell.session`, and overflow handling for more than 8 sessions.

Run:

```bash
nl -ba Argo/UI/Island/IslandExpandedView.swift | sed -n '208,263p'
```

Expected: output shows `controller.activeSurfaceSession`, notification card rendering, grouped `IslandSessionSectionsView`, and the `Show All` button calling `controller.showAllSessionsFromNotificationCard()`.

Run:

```bash
nl -ba Argo/UI/Island/IslandSurface.swift | sed -n '24,51p'
```

Expected: output shows permission/question/completed events opening `.sessionList(actionableSessionID:)`, and resolved running/stale states no longer matching the notification card.

Run:

```bash
nl -ba Argo/Support/IslandResponseDispatcher.swift | sed -n '30,47p'
```

Expected: output shows `respond(toSessionID:with:)`, pane lookup through `session.identity.paneID`, write-back through `sendText`, stale pane error, send failure error, and `.actionableStateResolved` after success.

Run:

```bash
nl -ba Argo/Services/AgentNotify/AgentNotifyProtocol.swift | sed -n '138,168p'
```

Expected: output shows approval follow-up events preserving `affectedPath`, command/card summary, and every option as `IslandPermissionAction`; question follow-up events preserve every option as `IslandQuestionOption`.

- [x] **Step 2: Record the static audit table**

Executed on 2026-06-22 and recorded this table:

```text
Static parity audit, 2026-06-22:
1. Durable approval/question records: PASS (static). Evidence: IslandSessionState.apply stores permission/question payloads by session ID at Argo/Support/IslandSessionState.swift:97-114 and resolves them through actionableStateResolved at Argo/Support/IslandSessionState.swift:125-134.
2. Approval command/path context: PASS (static). Evidence: open-vibe renders command/path at open-vibe-island/Sources/OpenIslandApp/Views/IslandPanelView.swift:1649-1661; Argo renders approvalContextBlock with approvalCommandPreviewText and approvalAffectedPathText at Argo/UI/Island/IslandSessionRow.swift:87-150.
3. Waiting state priority: PASS (static). Evidence: activityUpdated preserves pending state at Argo/Support/IslandSessionState.swift:77-88; priority ranking is defined in IslandSessionPhase.priorityRank.
4. Expanded grouped history: PASS (static). Evidence: IslandExpandedView renders IslandSessionSectionsView from state.prioritySessions at Argo/UI/Island/IslandExpandedView.swift:208-230.
5. Collapsed multiple live agents: PASS (static). Evidence: IslandCollapsedView builds IslandRightSlotContent.agents from prioritySessions and emits overflow at Argo/UI/Island/IslandCollapsedView.swift:20-39.
6. Originating pane write-back: PASS (static), pending runtime proof. Evidence: IslandResponseDispatcher writes text to session.identity.paneID and resolves only after sendText succeeds at Argo/Support/IslandResponseDispatcher.swift:30-47.
7. Approval multi-action parity: PASS (static), pending runtime proof. Evidence: AgentNotifyRequest.followupEvent maps every option to IslandPermissionAction at Argo/Services/AgentNotify/AgentNotifyProtocol.swift:141-155 and IslandSessionRow renders all actions at Argo/UI/Island/IslandSessionRow.swift:97-107.
```

Result: static audit is documented in the plan. Static PASS does not replace Task 14 runtime audit.

- [x] **Step 3: Confirm the no-pane smoke guard still protects runtime audit**

Run:

```bash
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh
```

Expected:

```text
self-test: OK
```

Run:

```bash
bash -n scripts/smoke_dynamic_island_notify.sh
```

Expected: no output.

Run:

```bash
env -u ARGO_PANE_ID bash scripts/smoke_dynamic_island_notify.sh
```

Expected: exit code `2` with:

```text
smoke: ARGO_PANE_ID is missing; run this script from inside an Argo terminal pane
```

Observed on 2026-06-22:

```text
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh -> self-test: OK
bash -n scripts/smoke_dynamic_island_notify.sh -> no output
env -u ARGO_PANE_ID bash scripts/smoke_dynamic_island_notify.sh -> exit 2 with the expected ARGO_PANE_ID message
```

- [x] **Step 4: Confirm whether runtime smoke is currently blocked by a stale running app**

Run:

```bash
pgrep -fl '/Argo.app/Contents/MacOS/Argo'
```

Expected: output may include the running Debug Argo process. Ignore transient `pgrep` or `find` commands in the result.

Observed on 2026-06-22:

```text
66539 /Applications/Argo.app/Contents/MacOS/Argo
99603 /Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo -NSDocumentRevisionsDebugMode YES
```

Run this for the running Debug app pid:

```bash
ps -p 99603 -o lstart= -o command=
```

Expected observed blocker on 2026-06-22:

```text
Mon Jun 22 10:32:59 2026     /Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo -NSDocumentRevisionsDebugMode YES
```

Run:

```bash
stat -f '%Sm %m %N' /Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
```

Expected observed blocker on 2026-06-22:

```text
Jun 22 13:55:27 2026 1782107727 /Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
```

If the process start time is older than the binary modification time, runtime smoke is blocked until the Debug Argo app is restarted onto the current binary. Do not kill the running app automatically because it may contain user sessions.

Result on 2026-06-22: runtime smoke remains blocked until the Debug Argo app is restarted. The running Debug process `99603` started at `Mon Jun 22 10:32:59 2026`, while its Debug binary was modified at `Jun 22 13:55:27 2026`.

- [ ] **Step 5: Runtime unblock procedure**

Use the least disruptive path:

```text
1. Ask the user to save or pause any important terminal sessions in the currently running Debug Argo.
2. Ask the user to quit and relaunch the Debug Argo app built from this branch, or explicitly approve killing/restarting the Debug process.
3. Open a real Argo terminal pane in the relaunched app.
4. Confirm the pane has ARGO_PANE_ID:
   printf '%s\n' "$ARGO_PANE_ID"
5. From that pane, run:
   scripts/smoke_dynamic_island_notify.sh
6. Confirm the smoke script does not exit 3.
7. Confirm screenshots exist under /tmp/argo-island-smoke.
```

Expected screenshots:

```text
/tmp/argo-island-smoke/activity.png
/tmp/argo-island-smoke/approval-card.png
/tmp/argo-island-smoke/question-card.png
/tmp/argo-island-smoke/completed-card.png
```

- [ ] **Step 6: Manual runtime smoke actions**

In the visible island card, verify these write-backs:

```text
1. Click Allow; the originating pane receives `1\n`.
2. Re-send the approval event if needed, then click Deny; the originating pane receives `2\n`.
3. Re-send the approval event if needed, then click Always allow; the originating pane receives `always\n`.
4. Click Staging on the question card; the originating pane receives `Staging\n`.
5. After each click, the row leaves the waiting state and the notification surface returns to the session list when appropriate.
```

Expected: all four write-back checks pass before Task 14 can be marked complete.

- [x] **Step 7: Run the focused post-audit regression set**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandRichNotifyProtocolTests \
  -only-testing:ArgoTests/IslandUISourceTests \
  -only-testing:ArgoTests/IslandResponseDispatcherTests \
  -only-testing:ArgoTests/AgentNotifyCLITests \
  -only-testing:ArgoTests/IslandSurfaceTests \
  test
```

Expected: `TEST SUCCEEDED`.

Run:

```bash
git diff --check
```

Expected: no output.

Observed on 2026-06-22:

```text
xcodebuild focused post-audit regression set -> ** TEST SUCCEEDED **
git diff --check -> no output
```

- [x] **Step 8: Commit the audit plan update**

After this Task is written and self-reviewed:

```bash
git add -f docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
git commit -m "feat(island): sync audit"
```

Expected: commit contains only this plan update unless Step 1 found an implementation gap and a later focused Task was added.

Observed on 2026-06-22: committed this Task 18 audit update with `feat(island): sync audit`.

### Task 19: 防止 smoke guard 误把非目标 Argo 当作 Debug 目标

**Files:**
- Modify: `scripts/smoke_dynamic_island_notify.sh`
- Modify: `docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md`

**Interfaces:**
- Consumes:
  - `validate_running_argo_binary "$ARGO_BIN"`
  - `running_argo_pids`
  - macOS `ps -p <pid> -o command=`
  - self-test fake pid variables under `ARGO_ISLAND_SMOKE_FAKE_*`
- Produces:
  - `pid_command <pid>` helper with fake-command injection.
  - `command_matches_binary <command> <argo_bin>` helper.
  - Runtime smoke validation that only considers a running process whose command matches the resolved Debug `ARGO_BIN`.
  - Exit code `4` when Argo processes exist but none match the target Debug binary.

- [x] **Step 1: Write the failing self-test**

Added this self-test case inside `run_self_tests()`:

```bash
local wrong_process_log="$OUT/self-test-wrong-process.log"
set +e
ARGO_ISLAND_SMOKE_FAKE_BINARY_MTIME=100 \
  ARGO_ISLAND_SMOKE_FAKE_PIDS="456" \
  ARGO_ISLAND_SMOKE_FAKE_PID_START_456=200 \
  ARGO_ISLAND_SMOKE_FAKE_PID_COMMAND_456="/Applications/Argo.app/Contents/MacOS/Argo" \
  validate_running_argo_binary "$fixture_bin" >"$wrong_process_log" 2>&1
local wrong_process_status=$?
set -e

if [[ "$wrong_process_status" -ne 4 ]]; then
  echo "self-test: expected wrong-process guard exit 4, got $wrong_process_status" >&2
  cat "$wrong_process_log" >&2
  return 1
fi

if ! grep -q "no running Debug Argo process matches" "$wrong_process_log"; then
  echo "self-test: wrong-process guard did not explain the target mismatch" >&2
  cat "$wrong_process_log" >&2
  return 1
fi
```

Run:

```bash
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh
```

Observed before implementation:

```text
self-test: expected wrong-process guard exit 4, got 0
```

- [x] **Step 2: Implement target-binary matching**

Added:

```bash
pid_command() {
  local pid="$1"
  local fake_var="ARGO_ISLAND_SMOKE_FAKE_PID_COMMAND_${pid}"
  if [[ -n "${!fake_var:-}" ]]; then
    printf '%s\n' "${!fake_var}"
    return 0
  fi
  ps -p "$pid" -o command= 2>/dev/null || true
}

command_matches_binary() {
  local command="$1"
  local argo_bin="$2"

  [[ "$command" == "$argo_bin" || "$command" == "$argo_bin "* ]]
}
```

Updated `validate_running_argo_binary "$ARGO_BIN"` so it:

```text
1. Reads each Argo pid command.
2. Ignores pids whose command does not match the resolved Debug ARGO_BIN.
3. Applies stale-process mtime checks only to matching target Debug processes.
4. Returns exit 4 with launch guidance when no target Debug process is running.
```

- [x] **Step 3: Run script verification**

Run:

```bash
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh
```

Observed:

```text
self-test: OK
```

Run:

```bash
bash -n scripts/smoke_dynamic_island_notify.sh
```

Observed: no output.

Run:

```bash
env -u ARGO_PANE_ID bash scripts/smoke_dynamic_island_notify.sh
```

Observed: exit code `2` with:

```text
smoke: ARGO_PANE_ID is missing; run this script from inside an Argo terminal pane
```

- [x] **Step 4: Verify current real process layout is still blocked before smoke events**

Run:

```bash
ARGO_PANE_ID=smoke-guard-check bash scripts/smoke_dynamic_island_notify.sh
```

Observed:

```text
smoke: running Argo pid 99603 is older than the Debug binary
smoke: pid start: Mon Jun 22 10:32:59 2026
smoke: binary: /Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
smoke: restart the Debug Argo app before running Dynamic Island smoke
```

Expected: script exits `3` before sending smoke events.

- [x] **Step 5: Commit**

```bash
git add scripts/smoke_dynamic_island_notify.sh
git add -f docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
git commit -m "fix(island): target smoke"
```

Observed on 2026-06-22: committed Task 19 with `fix(island): target smoke`.

### Task 20: 保留重复 sessionStarted 下的待处理交互

**Files:**
- Modify: `Argo/Support/IslandSessionState.swift`
- Modify: `Tests/IslandSessionStateTests.swift`
- Modify: `docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md`

**Interfaces:**
- Consumes:
  - `IslandSessionState.apply(_:)`
  - `IslandSessionEvent.sessionStarted(IslandSessionStarted)`
  - `IslandSessionEvent.permissionRequested(IslandPermissionRequested)`
  - `IslandSessionEvent.questionAsked(IslandQuestionAsked)`
  - `IslandAgentSession.phase`
  - `IslandAgentSession.permissionRequest`
  - `IslandAgentSession.questionPrompt`
- Produces:
  - Repeated `.sessionStarted` events with `initialPhase: .running` preserve an existing `.waitingForApproval` session when `permissionRequest` is still present.
  - Repeated `.sessionStarted` events with `initialPhase: .running` preserve an existing `.waitingForAnswer` session when `questionPrompt` is still present.
  - Fresh running metadata such as `currentTool`, `commandPreview`, prompts, terminal tags, and `updatedAt` still flows into the existing session.
  - Non-actionable `.sessionStarted` events continue to replace the prior phase and clear stale actionable payloads.

- [x] **Step 1: Write the failing approval preservation test**

Added to `Tests/IslandSessionStateTests.swift`:

```swift
func testSessionStartedRunningPreservesPendingApproval() {
    var state = IslandSessionState()
    let id = "pane:abc"

    state.apply(.sessionStarted(IslandSessionStarted(
        sessionID: id,
        identity: makeIdentity(sessionID: id),
        title: "Fix auth",
        tool: .codex,
        initialPhase: .running,
        summary: "Started",
        timestamp: Date(timeIntervalSince1970: 10)
    )))
    state.apply(.permissionRequested(IslandPermissionRequested(
        sessionID: id,
        request: IslandPermissionRequest(
            title: "Approval needed",
            summary: "Run tests",
            affectedPath: "/tmp/repo",
            actions: [
                IslandPermissionAction(title: "Deny", responseText: "2\n"),
                IslandPermissionAction(title: "Allow", responseText: "1\n"),
                IslandPermissionAction(title: "Always allow", responseText: "always\n")
            ]
        ),
        timestamp: Date(timeIntervalSince1970: 20)
    )))

    state.apply(.sessionStarted(IslandSessionStarted(
        sessionID: id,
        identity: makeIdentity(sessionID: id),
        title: "Fix auth",
        tool: .codex,
        initialPhase: .running,
        summary: "Restarted",
        timestamp: Date(timeIntervalSince1970: 30),
        currentTool: "exec_command",
        commandPreview: "xcodebuild test"
    )))

    let session = state.session(id: id)
    XCTAssertEqual(session?.phase, .waitingForApproval)
    XCTAssertEqual(session?.summary, "Run tests")
    XCTAssertEqual(session?.permissionRequest?.actions.map(\.title), ["Deny", "Allow", "Always allow"])
    XCTAssertEqual(session?.currentTool, "exec_command")
    XCTAssertEqual(session?.commandPreview, "xcodebuild test")
    XCTAssertEqual(state.attentionCount, 1)
}
```

- [x] **Step 2: Write the failing question preservation test**

Added to `Tests/IslandSessionStateTests.swift`:

```swift
func testSessionStartedRunningPreservesPendingQuestion() {
    var state = IslandSessionState()
    let id = "pane:abc"

    state.apply(.sessionStarted(IslandSessionStarted(
        sessionID: id,
        identity: makeIdentity(sessionID: id),
        title: "Deploy",
        tool: .codex,
        initialPhase: .running,
        summary: "Started",
        timestamp: Date(timeIntervalSince1970: 10)
    )))
    state.apply(.questionAsked(IslandQuestionAsked(
        sessionID: id,
        prompt: IslandQuestionPrompt(
            title: "Which target?",
            options: [
                IslandQuestionOption(label: "Production", responseText: "Production\n"),
                IslandQuestionOption(label: "Staging", responseText: "Staging\n")
            ]
        ),
        timestamp: Date(timeIntervalSince1970: 20)
    )))

    state.apply(.sessionStarted(IslandSessionStarted(
        sessionID: id,
        identity: makeIdentity(sessionID: id),
        title: "Deploy",
        tool: .codex,
        initialPhase: .running,
        summary: "Restarted",
        timestamp: Date(timeIntervalSince1970: 30)
    )))

    let session = state.session(id: id)
    XCTAssertEqual(session?.phase, .waitingForAnswer)
    XCTAssertEqual(session?.summary, "Which target?")
    XCTAssertEqual(session?.questionPrompt?.options.map(\.label), ["Production", "Staging"])
    XCTAssertEqual(state.attentionCount, 1)
}
```

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionStateTests/testSessionStartedRunningPreservesPendingApproval \
  -only-testing:ArgoTests/IslandSessionStateTests/testSessionStartedRunningPreservesPendingQuestion \
  test
```

Observed before implementation:

```text
** TEST FAILED **
```

- [x] **Step 3: Preserve actionable state in the session reducer**

Updated the `.sessionStarted` branch in `Argo/Support/IslandSessionState.swift`:

```swift
case let .sessionStarted(payload):
    let existing = sessionsByID[payload.sessionID]
    let preservesPendingApproval = payload.initialPhase == .running
        && existing?.phase == .waitingForApproval
        && existing?.permissionRequest != nil
    let preservesPendingQuestion = payload.initialPhase == .running
        && existing?.phase == .waitingForAnswer
        && existing?.questionPrompt != nil
    let preservesActionableState = preservesPendingApproval || preservesPendingQuestion

    upsert(IslandAgentSession(
        id: payload.sessionID,
        identity: payload.identity,
        title: payload.title,
        tool: payload.tool,
        phase: preservesActionableState ? existing?.phase ?? payload.initialPhase : payload.initialPhase,
        summary: preservesActionableState ? existing?.summary ?? payload.summary : payload.summary,
        updatedAt: payload.timestamp,
        firstSeenAt: existing?.firstSeenAt,
        permissionRequest: preservesActionableState ? existing?.permissionRequest : nil,
        questionPrompt: preservesActionableState ? existing?.questionPrompt : nil,
        currentTool: payload.currentTool,
        commandPreview: payload.commandPreview,
        initialPrompt: payload.initialPrompt,
        latestPrompt: payload.latestPrompt,
        lastAssistantMessage: payload.lastAssistantMessage,
        terminalTag: payload.terminalTag,
        lastError: preservesActionableState ? payload.lastError ?? existing?.lastError : payload.lastError
    ))
```

- [x] **Step 4: Verify the new focused tests pass**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionStateTests/testSessionStartedRunningPreservesPendingApproval \
  -only-testing:ArgoTests/IslandSessionStateTests/testSessionStartedRunningPreservesPendingQuestion \
  test
```

Observed after implementation:

```text
** TEST SUCCEEDED **
```

- [x] **Step 5: Run related island regression tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionStateTests \
  -only-testing:ArgoTests/IslandRichNotifyProtocolTests \
  -only-testing:ArgoTests/IslandSurfaceTests \
  -only-testing:ArgoTests/IslandResponseDispatcherTests \
  -only-testing:ArgoTests/IslandSessionCenterTests \
  test
```

Observed on 2026-06-22:

```text
** TEST SUCCEEDED **
```

- [x] **Step 6: Run final hygiene verification for this task**

Run:

```bash
git diff --check
```

Expected: no output.

Run:

```bash
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh
```

Expected:

```text
self-test: OK
```

Run:

```bash
bash -n scripts/smoke_dynamic_island_notify.sh
```

Expected: no output.

Observed on 2026-06-22:

```text
git diff --check -> no output
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh -> self-test: OK
bash -n scripts/smoke_dynamic_island_notify.sh -> no output
```

- [x] **Step 7: Commit**

Use `team-commit-convention` before committing. Then run:

```bash
git add Argo/Support/IslandSessionState.swift Tests/IslandSessionStateTests.swift
git add -f docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
git commit -m "fix(island): keep pending"
```

Expected: commit contains the reducer fix, the two regression tests, and this Task 20 plan update.

Observed on 2026-06-22: committed reducer fix, regression tests, and this Task 20 plan update with `fix(island): keep pending`.

### Task 21: 让 smoke guard 支持新旧 Debug Argo 并存

**Files:**
- Modify: `scripts/smoke_dynamic_island_notify.sh`
- Modify: `docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md`

**Interfaces:**
- Consumes:
  - `validate_running_argo_binary "$ARGO_BIN"`
  - `binary_mtime "$ARGO_BIN"`
  - `running_argo_pids`
  - `pid_command <pid>`
  - `pid_start_epoch <pid>`
  - `pid_start_label <pid>`
  - macOS `ps -p <pid> -o ppid=`
  - self-test fake pid variables under `ARGO_ISLAND_SMOKE_FAKE_*`
- Produces:
  - `current_process_id()` helper with `ARGO_ISLAND_SMOKE_FAKE_CURRENT_PID` injection.
  - `pid_parent <pid>` helper with `ARGO_ISLAND_SMOKE_FAKE_PID_PARENT_<pid>` injection.
  - `target_ancestor_pid <pid> <argo_bin>` helper that walks the current process tree and finds the target Debug Argo ancestor.
  - `validate_target_pid_fresh <pid> <argo_bin> <bin_mtime>` shared freshness check.
  - Runtime guard behavior that validates the current Argo ancestor first when the smoke script is run from inside a target Debug Argo pane.
  - Existing fallback behavior for non-Argo shells: old matching Debug processes still block with exit code `3`, and no matching process still returns `4`.

- [x] **Step 1: Write the failing current-process self-test**

Added this self-test case inside `run_self_tests()`:

```bash
local current_process_log="$OUT/self-test-current-process.log"
set +e
ARGO_ISLAND_SMOKE_FAKE_BINARY_MTIME=200 \
  ARGO_ISLAND_SMOKE_FAKE_CURRENT_PID=300 \
  ARGO_ISLAND_SMOKE_FAKE_PIDS="123 456" \
  ARGO_ISLAND_SMOKE_FAKE_PID_START_123=100 \
  ARGO_ISLAND_SMOKE_FAKE_PID_COMMAND_123="$fixture_bin -NSDocumentRevisionsDebugMode YES" \
  ARGO_ISLAND_SMOKE_FAKE_PID_START_456=300 \
  ARGO_ISLAND_SMOKE_FAKE_PID_COMMAND_456="$fixture_bin -NSDocumentRevisionsDebugMode YES" \
  ARGO_ISLAND_SMOKE_FAKE_PID_PARENT_300=200 \
  ARGO_ISLAND_SMOKE_FAKE_PID_PARENT_200=456 \
  ARGO_ISLAND_SMOKE_FAKE_PID_PARENT_456=1 \
  validate_running_argo_binary "$fixture_bin" >"$current_process_log" 2>&1
local current_process_status=$?
set -e

if [[ "$current_process_status" -ne 0 ]]; then
  echo "self-test: expected current fresh Debug ancestor to bypass unrelated stale process, got $current_process_status" >&2
  cat "$current_process_log" >&2
  return 1
fi
```

Run:

```bash
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh; printf 'exit=%s\n' "$?"
```

Observed before implementation:

```text
self-test: expected current fresh Debug ancestor to bypass unrelated stale process, got 3
smoke: running Argo pid 123 is older than the Debug binary
smoke: pid start:
smoke: binary: /tmp/argo-island-smoke/self-test-Argo
smoke: restart the Debug Argo app before running Dynamic Island smoke
exit=1
```

- [x] **Step 2: Add current process tree helpers**

Added to `scripts/smoke_dynamic_island_notify.sh`:

```bash
current_process_id() {
  printf '%s\n' "${ARGO_ISLAND_SMOKE_FAKE_CURRENT_PID:-$$}"
}

pid_parent() {
  local pid="$1"
  local fake_var="ARGO_ISLAND_SMOKE_FAKE_PID_PARENT_${pid}"
  if [[ -n "${!fake_var:-}" ]]; then
    printf '%s\n' "${!fake_var}"
    return 0
  fi

  ps -p "$pid" -o ppid= 2>/dev/null | tr -d '[:space:]' || true
}

target_ancestor_pid() {
  local pid="$1"
  local argo_bin="$2"
  local depth=0

  while [[ -n "$pid" && "$pid" != "0" && "$depth" -lt 64 ]]; do
    local command
    command="$(pid_command "$pid")"
    if command_matches_binary "$command" "$argo_bin"; then
      printf '%s\n' "$pid"
      return 0
    fi

    local parent
    parent="$(pid_parent "$pid" || true)"
    [[ -n "$parent" && "$parent" != "$pid" ]] || break
    pid="$parent"
    depth=$((depth + 1))
  done

  return 1
}
```

- [x] **Step 3: Share target freshness validation**

Added:

```bash
validate_target_pid_fresh() {
  local pid="$1"
  local argo_bin="$2"
  local bin_mtime="$3"

  local start_epoch
  start_epoch="$(pid_start_epoch "$pid" || true)"
  [[ -n "$start_epoch" ]] || return 0

  if (( start_epoch < bin_mtime )); then
    echo "smoke: running Argo pid $pid is older than the Debug binary" >&2
    echo "smoke: pid start: $(pid_start_label "$pid")" >&2
    echo "smoke: binary: $argo_bin" >&2
    echo "smoke: restart the Debug Argo app before running Dynamic Island smoke" >&2
    return 3
  fi

  return 0
}
```

- [x] **Step 4: Prefer the current Argo ancestor when present**

Updated `validate_running_argo_binary "$ARGO_BIN"` so it first checks:

```bash
local ancestor_pid
ancestor_pid="$(target_ancestor_pid "$(current_process_id)" "$argo_bin" || true)"
if [[ -n "$ancestor_pid" ]]; then
  if validate_target_pid_fresh "$ancestor_pid" "$argo_bin" "$bin_mtime"; then
    return 0
  else
    return $?
  fi
fi
```

Then the existing global scan remains the fallback for shells that are not descendants of the target Debug app.

- [x] **Step 5: Run script verification**

Run:

```bash
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh
```

Observed:

```text
self-test: OK
```

Run:

```bash
bash -n scripts/smoke_dynamic_island_notify.sh
```

Observed: no output.

Run:

```bash
env -u ARGO_PANE_ID bash scripts/smoke_dynamic_island_notify.sh; printf 'exit=%s\n' "$?"
```

Observed:

```text
smoke: ARGO_PANE_ID is missing; run this script from inside an Argo terminal pane
exit=2
```

Run:

```bash
ARGO_PANE_ID=smoke-guard-check bash scripts/smoke_dynamic_island_notify.sh; printf 'exit=%s\n' "$?"
```

Observed in this non-Argo shell while the old Debug process is still running:

```text
smoke: running Argo pid 99603 is older than the Debug binary
smoke: pid start: Mon Jun 22 10:32:59 2026
smoke: binary: /Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
smoke: restart the Debug Argo app before running Dynamic Island smoke
exit=3
```

- [x] **Step 6: Commit**

Use `team-commit-convention` before committing. Then run:

```bash
git add scripts/smoke_dynamic_island_notify.sh
git add -f docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
git commit -m "fix(island): pane guard"
```

Expected: commit contains the process-tree-aware smoke guard and this Task 21 plan update.

Observed on 2026-06-22: committed the process-tree-aware smoke guard and this Task 21 plan update with `fix(island): pane guard`.

### Task 22: 用 ping 校验 control socket 属于目标 Debug Argo

**Files:**
- Modify: `Argo/Services/AgentNotify/ArgoControlProtocol.swift`
- Modify: `Argo/Services/AgentNotify/ArgoControlDispatcher.swift`
- Modify: `Argo/Services/AgentNotify/ArgoControlCLI.swift`
- Modify: `Argo/main.swift`
- Modify: `scripts/smoke_dynamic_island_notify.sh`
- Modify: `docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md`
- Test: `Tests/ArgoControlDispatcherTests.swift`
- Test: `Tests/ArgoControlCLITests.swift`

**Interfaces:**
- Consumes:
  - Existing newline-terminated control frame transport through `AgentNotifyServer`.
  - Existing `ArgoControlCLI.encodeFrame(cmd:token:payload:)`.
  - Existing fixed socket path used by `ArgoControlClient.send(frame:)`.
  - `Bundle.main.executablePath` or `CommandLine.arguments.first` inside the running app process.
  - `scripts/smoke_dynamic_island_notify.sh` helpers `resolve_argo_bin`, `validate_running_argo_binary`, `send_smoke_events`, and `run_self_tests`.
- Produces:
  - `ArgoControlCommand.ping`.
  - `ArgoControlResponse.executablePath: String?`.
  - `ArgoControlDispatcher.init(host:tokenResolver:executablePathProvider:)`.
  - `ArgoControlDispatcher.dispatch(frame:)` handling `cmd == .ping` without token and without host routing.
  - `ArgoControlCLI.usagePing`.
  - `ArgoControlCLI.runPing(arguments:send:stdoutWriter:stderrWriter:) -> ArgoControlCLI.ExitCode`.
  - `main.swift` route for `argo ping`.
  - Smoke helper `run_argo_ping "$ARGO_BIN"`.
  - Smoke helper `canonical_file_path <path>`.
  - Smoke helper `validate_control_socket_owner "$ARGO_BIN"` that exits `5` when the fixed socket is owned by a different Argo binary.

- [x] **Step 1: Write the failing dispatcher and CLI tests**

Modify `Tests/ArgoControlDispatcherTests.swift`, add the ping case after the notify tests:

```swift
// MARK: - Ping (socket health, no auth)

func testPingDoesNotRequireTokenAndReturnsExecutablePath() throws {
    dispatcher = ArgoControlDispatcher(
        host: host,
        tokenResolver: { nil },
        executablePathProvider: { "/debug/Argo.app/Contents/MacOS/Argo" }
    )
    let frame = makeFrame(["cmd": "ping"])
    let response = try XCTUnwrap(dispatcher.dispatch(frame: frame))
    let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
    XCTAssertTrue(decoded.ok)
    XCTAssertEqual(decoded.executablePath, "/debug/Argo.app/Contents/MacOS/Argo")
    XCTAssertTrue(host.openCalls.isEmpty)
    XCTAssertTrue(host.notifyCalls.isEmpty)
}
```

Modify `Tests/ArgoControlCLITests.swift`, add the ping tests before the encode-frame helper tests:

```swift
// MARK: - ping

func testPingEncodesFrameWithoutToken() throws {
    let captured = FrameCollector(response: ArgoControlResponse(
        ok: true,
        error: nil,
        sessions: nil,
        executablePath: "/debug/Argo.app/Contents/MacOS/Argo"
    ))
    let exit = ArgoControlCLI.runPing(
        arguments: [],
        send: captured.capture,
        stdoutWriter: { _ in },
        stderrWriter: { _ in }
    )
    XCTAssertEqual(exit, .ok)
    let json = try captured.decodedJSON()
    XCTAssertEqual(json["cmd"] as? String, "ping")
    XCTAssertNil(json["token"])
}

func testPingPrintsExecutablePath() {
    let stdout = StreamCollector()
    let exit = ArgoControlCLI.runPing(
        arguments: [],
        send: { _ in ArgoControlResponse(
            ok: true,
            error: nil,
            sessions: nil,
            executablePath: "/debug/Argo.app/Contents/MacOS/Argo"
        ) },
        stdoutWriter: stdout.write,
        stderrWriter: { _ in }
    )
    XCTAssertEqual(exit, .ok)
    XCTAssertEqual(stdout.text, "/debug/Argo.app/Contents/MacOS/Argo\n")
}
```

Update `FrameCollector` in the same file so tests can stub the ping response:

```swift
nonisolated private final class FrameCollector {
    private(set) var frame: Data?
    private let response: ArgoControlResponse?

    init(response: ArgoControlResponse? = .success) {
        self.response = response
    }

    func capture(_ data: Data) throws -> ArgoControlResponse? {
        frame = data
        return response
    }

    func decodedJSON() throws -> [String: Any] {
        guard let raw = frame else {
            throw NSError(domain: "FrameCollector", code: -1, userInfo: [NSLocalizedDescriptionKey: "no frame captured"])
        }
        let trimmed = raw.last == 0x0A ? raw.dropLast() : raw
        guard let object = try JSONSerialization.jsonObject(with: trimmed) as? [String: Any] else {
            throw NSError(domain: "FrameCollector", code: -2, userInfo: [NSLocalizedDescriptionKey: "frame was not a JSON object"])
        }
        return object
    }
}
```

- [x] **Step 2: Run focused tests to verify the red phase**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/ArgoControlDispatcherTests/testPingDoesNotRequireTokenAndReturnsExecutablePath \
  -only-testing:ArgoTests/ArgoControlCLITests/testPingEncodesFrameWithoutToken \
  -only-testing:ArgoTests/ArgoControlCLITests/testPingPrintsExecutablePath \
  test
```

Expected before implementation: FAIL at compile time because `ArgoControlDispatcher` does not accept `executablePathProvider`, `ArgoControlResponse` has no `executablePath`, and `ArgoControlCLI.runPing` is not defined.

Observed on 2026-06-22:

```text
extra argument 'executablePathProvider' in call
type 'ArgoControlResponse' has no member 'executablePath'
```

- [x] **Step 3: Add ping to the control protocol**

Modify `Argo/Services/AgentNotify/ArgoControlProtocol.swift`:

```swift
enum ArgoControlCommand: String, Codable {
    case notify
    case ping
    case open
    case split
    case sendKeys = "send-keys"
    case sessionList = "session-list"
}
```

Update `ArgoControlResponse`:

```swift
struct ArgoControlResponse: Codable, Equatable {
    var ok: Bool
    var error: String?
    var sessions: [ArgoControlSession]?
    var executablePath: String?

    static let success = ArgoControlResponse(ok: true)

    static func failure(_ message: String) -> ArgoControlResponse {
        ArgoControlResponse(ok: false, error: message)
    }
}
```

Expected: existing response construction keeps compiling because Swift memberwise initializers with default member values allow `ArgoControlResponse(ok:)` and `ArgoControlResponse(ok:error:sessions:)` call sites to omit `executablePath`.

Observed on 2026-06-22: added `ArgoControlCommand.ping` and `ArgoControlResponse.executablePath`.

- [x] **Step 4: Implement unauthenticated dispatcher ping**

Modify `Argo/Services/AgentNotify/ArgoControlDispatcher.swift`:

```swift
nonisolated final class ArgoControlDispatcher {
    weak var host: ArgoControlHost?
    /// Token resolver — returns the user-configured trust token or nil if
    /// the URL-scheme feature is disabled. Indirection so tests can inject.
    var tokenResolver: () -> String?
    var executablePathProvider: () -> String

    init(
        host: ArgoControlHost?,
        tokenResolver: @escaping () -> String? = { MainActor.assumeIsolated { ArgoURLScheme.isEnabled() ? ArgoURLScheme.storedToken() : nil } },
        executablePathProvider: @escaping () -> String = { Bundle.main.executablePath ?? CommandLine.arguments.first ?? "" }
    ) {
        self.host = host
        self.tokenResolver = tokenResolver
        self.executablePathProvider = executablePathProvider
    }
```

In `dispatch(frame:)`, add ping before the auth gate:

```swift
if cmd == .ping {
    return ArgoControlEncoder.encodeResponse(ArgoControlResponse(
        ok: true,
        error: nil,
        sessions: nil,
        executablePath: executablePathProvider()
    ))
}
```

Update the command switch:

```swift
case .ping:
    // Already handled above.
    return ArgoControlEncoder.encodeResponse(.failure("invalid-ping-state"))
```

Expected: `ping` returns response bytes even when URL scheme control is disabled, and it does not call any `ArgoControlHost` method.

Observed on 2026-06-22: dispatcher now accepts `executablePathProvider`, handles `ping` before auth, and does not route ping through the host.

- [x] **Step 5: Implement `argo ping` CLI**

Modify `Argo/Services/AgentNotify/ArgoControlCLI.swift`, update the top-level command comment:

```swift
///   argo ping
///   argo open <repo> [--worktree <path>] [--token <t>]
///   argo split [--axis vertical|horizontal] [--placement after|before]
///                [--pane <uuid>] [--token <t>]
///   argo send-keys <pane> <text> [--token <t>]
///   argo session list [--token <t>] [--json]
```

Add usage text after `usageSendKeys`:

```swift
static let usagePing = """
argo ping — print the executable path of the Argo app that owns the control socket.

USAGE:
  argo ping
"""
```

Add the CLI implementation before `runOpen`:

```swift
// MARK: - Ping

static func runPing(
    arguments: [String],
    send: (Data) throws -> ArgoControlResponse? = { try ArgoControlClient.send(frame: $0) },
    stdoutWriter: (String) -> Void = { print($0) },
    stderrWriter: (String) -> Void = { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
) -> ExitCode {
    if arguments.contains("-h") || arguments.contains("--help") {
        stdoutWriter(usagePing)
        return .ok
    }
    if let unexpected = arguments.first {
        stderrWriter("argo ping: unexpected argument '\(unexpected)'")
        return .usage
    }

    let frame = encodeFrame(cmd: "ping", token: nil, payload: [:])
    do {
        let response = try send(frame)
        guard let response else {
            stderrWriter("argo ping: server returned no response")
            return .ioError
        }
        if !response.ok {
            stderrWriter("argo ping: \(response.error ?? "unknown error")")
            return response.error == "token-mismatch" || response.error == "control-disabled"
                ? .authRequired
                : .ioError
        }
        guard let executablePath = response.executablePath, !executablePath.isEmpty else {
            stderrWriter("argo ping: server returned no executable path")
            return .ioError
        }
        stdoutWriter(executablePath)
        return .ok
    } catch AgentNotifyError.socketUnavailable {
        stderrWriter("argo: Argo is not running")
        return .unavailable
    } catch {
        stderrWriter("argo ping: \(error)")
        return .ioError
    }
}
```

Expected: `argo ping` writes exactly one executable path line to stdout on success, and never requires `--token`.

Observed on 2026-06-22: implemented `ArgoControlCLI.runPing(...)` and `usagePing`.

- [x] **Step 6: Route `ping` from `main.swift`**

Modify `Argo/main.swift`:

```swift
case "ping":
    exit(ArgoControlCLI.runPing(arguments: rest).rawValue)
case "open":
    exit(ArgoControlCLI.runOpen(arguments: rest).rawValue)
```

Expected: running the built binary as `Argo ping` uses CLI mode and does not start the AppKit event loop.

Observed on 2026-06-22: `main.swift` now routes `ping` to `ArgoControlCLI.runPing(arguments:)`.

- [x] **Step 7: Run focused control tests and keep the green evidence**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/ArgoControlDispatcherTests/testPingDoesNotRequireTokenAndReturnsExecutablePath \
  -only-testing:ArgoTests/ArgoControlCLITests/testPingEncodesFrameWithoutToken \
  -only-testing:ArgoTests/ArgoControlCLITests/testPingPrintsExecutablePath \
  test
```

Expected: PASS for all three focused ping tests.

Observed on 2026-06-22:

```text
** TEST SUCCEEDED **
ArgoControlCLITests.testPingEncodesFrameWithoutToken passed
ArgoControlCLITests.testPingPrintsExecutablePath passed
ArgoControlDispatcherTests.testPingDoesNotRequireTokenAndReturnsExecutablePath passed
```

- [x] **Step 8: Add smoke self-tests for socket owner validation**

Modify `scripts/smoke_dynamic_island_notify.sh`, add helpers after `validate_running_argo_binary()`:

```bash
run_argo_ping() {
  local argo_bin="$1"
  if [[ -n "${ARGO_ISLAND_SMOKE_FAKE_PING_OUTPUT:-}" || -n "${ARGO_ISLAND_SMOKE_FAKE_PING_STATUS:-}" ]]; then
    printf '%s\n' "${ARGO_ISLAND_SMOKE_FAKE_PING_OUTPUT:-}"
    return "${ARGO_ISLAND_SMOKE_FAKE_PING_STATUS:-0}"
  fi

  "$argo_bin" ping
}

canonical_file_path() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    printf '%s\n' "$path"
    return 0
  fi

  local dir
  local base
  dir="$(cd "$(dirname "$path")" && pwd -P)"
  base="$(basename "$path")"
  printf '%s/%s\n' "$dir" "$base"
}

validate_control_socket_owner() {
  local argo_bin="$1"
  local ping_stderr="$OUT/ping.stderr"
  local actual
  local status

  if actual="$(run_argo_ping "$argo_bin" 2>"$ping_stderr")"; then
    status=0
  else
    status=$?
  fi

  if [[ "$status" -ne 0 || -z "$actual" ]]; then
    echo "smoke: argo ping failed for $argo_bin" >&2
    if [[ -s "$ping_stderr" ]]; then
      sed 's/^/smoke: ping: /' "$ping_stderr" >&2
    fi
    return 5
  fi

  local expected
  expected="$(canonical_file_path "$argo_bin")"
  actual="$(canonical_file_path "$actual")"

  if [[ "$actual" != "$expected" ]]; then
    echo "smoke: control socket is owned by a different Argo app" >&2
    echo "smoke: expected: $expected" >&2
    echo "smoke: actual:   $actual" >&2
    echo "smoke: quit the non-target Argo app or relaunch the Debug app so the socket points at the target binary" >&2
    return 5
  fi
}
```

Add this self-test inside `run_self_tests()` before `echo "self-test: OK"`:

```bash
ARGO_ISLAND_SMOKE_FAKE_PING_OUTPUT="$fixture_bin" \
  validate_control_socket_owner "$fixture_bin" >/dev/null

local wrong_socket_log="$OUT/self-test-wrong-socket.log"
set +e
ARGO_ISLAND_SMOKE_FAKE_PING_OUTPUT="/Applications/Argo.app/Contents/MacOS/Argo" \
  validate_control_socket_owner "$fixture_bin" >"$wrong_socket_log" 2>&1
local wrong_socket_status=$?
set -e

if [[ "$wrong_socket_status" -ne 5 ]]; then
  echo "self-test: expected wrong socket owner exit 5, got $wrong_socket_status" >&2
  cat "$wrong_socket_log" >&2
  return 1
fi

if ! grep -q "control socket is owned by a different Argo app" "$wrong_socket_log"; then
  echo "self-test: wrong socket owner guard did not explain the mismatch" >&2
  cat "$wrong_socket_log" >&2
  return 1
fi
```

Run before wiring `validate_control_socket_owner` into `main()`:

```bash
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh
```

Expected: PASS because this step tests the helper behavior directly.

Observed on 2026-06-22: added `run_argo_ping`, `canonical_file_path`, `validate_control_socket_owner`, and self-tests for matching and mismatched socket owner. The first implementation incorrectly restored `set -e` inside the helper, which caused the expected exit `5` path to terminate the whole self-test; the helper now captures ping status with an `if actual="$(...)"` assignment and does not mutate the caller's errexit state.

- [x] **Step 9: Gate smoke events on socket owner ping**

Modify `scripts/smoke_dynamic_island_notify.sh` in `main()`:

```bash
validate_running_argo_binary "$ARGO_BIN"
validate_control_socket_owner "$ARGO_BIN"

echo "smoke: using $ARGO_BIN"
echo "smoke: pane $ARGO_PANE_ID"
```

Expected: the script exits `5` before sending any notify events when the fixed socket responds from `/Applications/Argo.app` or another non-target binary.

Observed on 2026-06-22: `main()` now calls `validate_control_socket_owner "$ARGO_BIN"` immediately after `validate_running_argo_binary "$ARGO_BIN"` and before printing smoke target information or sending events.

- [x] **Step 10: Run script verification**

Run:

```bash
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh
```

Expected:

```text
self-test: OK
```

Run:

```bash
bash -n scripts/smoke_dynamic_island_notify.sh
```

Expected: no output.

Run:

```bash
git diff --check
```

Expected: no output.

Observed on 2026-06-22:

```text
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh -> self-test: OK
bash -n scripts/smoke_dynamic_island_notify.sh -> no output
git diff --check -> no output
```

- [x] **Step 11: Run full control regression tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/ArgoControlDispatcherTests \
  -only-testing:ArgoTests/ArgoControlCLITests \
  test
```

Expected: PASS for all control dispatcher and CLI tests.

Observed on 2026-06-22:

```text
** TEST SUCCEEDED **
ArgoControlDispatcherTests: 17 tests passed
ArgoControlCLITests: 19 tests passed
```

- [x] **Step 12: Commit**

Use `team-commit-convention` before committing. Then run:

```bash
git add Argo/Services/AgentNotify/ArgoControlProtocol.swift
git add Argo/Services/AgentNotify/ArgoControlDispatcher.swift
git add Argo/Services/AgentNotify/ArgoControlCLI.swift
git add Argo/main.swift
git add Tests/ArgoControlDispatcherTests.swift Tests/ArgoControlCLITests.swift
git add scripts/smoke_dynamic_island_notify.sh
git add -f docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
git commit -m "fix(island): ping socket"
```

Expected: commit contains the unauthenticated ping command, smoke socket-owner guard, focused tests, script self-tests, and this Task 22 plan update.

Observed on 2026-06-22: committed Task 22 with `fix(island): ping socket`.

- [ ] **Step 13: Re-run runtime smoke only after ping proves the socket owner**

From a real terminal pane inside the target Debug Argo app, run:

```bash
ARGO_BIN=/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo \
  scripts/smoke_dynamic_island_notify.sh
```

Expected success output starts with:

```text
smoke: using /Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
smoke: pane <ARGO_PANE_ID>
smoke: screenshots written to /tmp/argo-island-smoke
```

Expected failure when the socket is still owned by another app:

```text
smoke: control socket is owned by a different Argo app
smoke: expected: /Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
smoke: actual:   /Applications/Argo.app/Contents/MacOS/Argo
smoke: quit the non-target Argo app or relaunch the Debug app so the socket points at the target binary
```

Observed on 2026-06-22 from a non-Argo shell with `ARGO_PANE_ID=smoke-guard-check`: runtime smoke is still blocked before events are sent because the running target Debug app process is older than the newly built Debug binary.

```text
smoke: running Argo pid 53330 is older than the Debug binary
smoke: pid start: Mon Jun 22 14:49:34 2026
smoke: binary: /Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
smoke: restart the Debug Argo app before running Dynamic Island smoke
rc=3
```

Do not mark Task 14 runtime audit complete until the screenshots show the approval and question cards, and clicking the rendered actions writes the expected response text into the originating pane.

### Task 23: 保持 control dispatcher 生命周期，恢复 `argo ping` 响应

**Files:**
- Modify: `Argo/Services/AgentNotify/AgentNotifyProtocol.swift`
- Modify: `Argo/Services/AgentNotify/AgentNotifyServer.swift`
- Modify: `Argo/AppDelegate.swift`
- Test: `Tests/AgentNotifyServerTests.swift`
- Modify: `docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md`

**Interfaces:**
- Consumes:
  - `AgentNotifyServer.FrameHandler = @Sendable (Data) -> Data?`
  - `AgentNotifyProtocol.encode(_:)`, `AgentNotifyProtocol.decode(_:)`, and `AgentNotifySocketPath.resolveSocketURL(...)`
  - `ArgoControlDispatcher.init(host:tokenResolver:executablePathProvider:)`
  - `ArgoControlDispatcher.dispatch(frame:) -> Data?`
  - `AgentNotifyMainActorBridge.dispatchOnMain(_:dispatcher:) -> Data?`
  - `ArgoControlCLI.encodeFrame(cmd:token:payload:)`
  - `ArgoControlClient.send(frame:socketURL:timeout:)`
  - `AppDelegate.startAgentNotifyServer()`
- Produces:
  - `nonisolated final class AgentNotifyControlServer`
  - `AgentNotifyControlServer.init(socketURL:host:tokenResolver:executablePathProvider:)`
  - `AgentNotifyControlServer.start() throws`
  - `AgentNotifyControlServer.stop()`
  - `AppDelegate.agentNotifyServer: AgentNotifyControlServer?`
  - Production control socket handler that strongly retains its dispatcher for the full socket-server lifetime.

- [x] **Step 1: Write the failing control-server lifecycle test**

Modify `Tests/AgentNotifyServerTests.swift`, add this test after `testClientReportsSocketUnavailableWhenNoServer()`:

```swift
func testControlServerRetainsDispatcherAndRespondsToPing() throws {
    let socketURL = try XCTUnwrap(temporarySocketURL)
    let executablePath = "/debug/Argo.app/Contents/MacOS/Argo"
    let server = AgentNotifyControlServer(
        socketURL: socketURL,
        host: nil,
        tokenResolver: { nil },
        executablePathProvider: { executablePath }
    )
    try server.start()
    defer { server.stop() }

    let responseBox = AgentNotifyControlResponseCapture()
    let received = expectation(description: "ping response received")
    let frame = ArgoControlCLI.encodeFrame(cmd: "ping", token: nil, payload: [:])
    DispatchQueue.global(qos: .userInitiated).async {
        responseBox.set(try? ArgoControlClient.send(frame: frame, socketURL: socketURL, timeout: 1.0))
        received.fulfill()
    }

    wait(for: [received], timeout: 3.0)
    XCTAssertEqual(responseBox.value??.executablePath, executablePath)
}
```

Add this helper after `AgentNotifyFrameCapture`:

```swift
nonisolated final class AgentNotifyControlResponseCapture: @unchecked Sendable {
    var value: ArgoControlResponse??

    func set(_ value: ArgoControlResponse??) {
        self.value = value
    }
}
```

Observed on 2026-06-22: the test exists in the working tree and captures the runtime symptom. Without a retained dispatcher, the socket accepts the connection but `argo ping` receives no response.

- [x] **Step 2: Run the focused test and keep the red evidence**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/AgentNotifyServerTests/testControlServerRetainsDispatcherAndRespondsToPing \
  test
```

Expected before implementation: FAIL because production wiring weakly captures a dispatcher local to `AppDelegate.startAgentNotifyServer()`, so the handler returns `nil` after the function returns.

Observed on 2026-06-22 after the first wrapper attempt: the test process aborts instead of reaching the assertion. The newest crash report should be inspected before changing more code:

```bash
find ~/Library/Logs/DiagnosticReports -maxdepth 1 \( -name 'Argo*.ips' -o -name 'Argo*.crash' \) -print | sort -r | head
```

The current suspected cause is actor-isolated deallocation for helper/server objects under `SWIFT_APPROACHABLE_CONCURRENCY`, matching the earlier `ArgoControlDispatcher` deinit issue that was solved by making the class `nonisolated`.

- [x] **Step 3: Make socket-server support objects explicitly nonisolated**

Modify the declaration of `AgentNotifyServer` in `Argo/Services/AgentNotify/AgentNotifyServer.swift`:

```swift
nonisolated final class AgentNotifyServer {
```

Modify the response box declaration at the bottom of the same file:

```swift
nonisolated private final class AgentNotifyResponseBox: @unchecked Sendable {
    var value: Data?
}
```

Expected: server start/stop/deinit remain callable from the existing tests and from `AppDelegate`, while Swift no longer infers main-actor deallocation for the socket server or response box.

Modify `Argo/Services/AgentNotify/AgentNotifyProtocol.swift` so the pure protocol and socket-path helpers remain callable from the nonisolated socket server:

```swift
nonisolated enum AgentNotifyProtocol {
    // existing encode/decode implementation
}

nonisolated enum AgentNotifySocketPath {
    static let directoryName = "Argo"
    static let socketFileName = "agent-notify.sock"
    nonisolated(unsafe) static var overrideURL: URL?

    // existing resolveDirectory/resolveSocketURL/ensureDirectory implementation
}
```

Observed on 2026-06-22: `AgentNotifyServer`, `AgentNotifyProtocol`, `AgentNotifySocketPath`, `AgentNotifyDispatcherBox`, `AgentNotifyMainActorBridge`, and `AgentNotifyResponseBox` are explicit `nonisolated`; `overrideURL` is `nonisolated(unsafe)` because it is a test-only global override.

- [x] **Step 4: Replace weak dispatcher capture with a retained control-server owner**

In `Argo/Services/AgentNotify/AgentNotifyServer.swift`, add this owner between `AgentNotifyServer` and `AgentNotifyMainActorBridge`, replacing any prior incomplete `AgentNotifyControlServer` attempt:

```swift
/// Owns both the Unix socket server and its dispatcher. Keeping this as a
/// single object prevents the production handler from weakly capturing a
/// short-lived dispatcher and silently returning no response.
nonisolated final class AgentNotifyControlServer {
    private let dispatcherBox: AgentNotifyDispatcherBox
    private let server: AgentNotifyServer

    init(
        socketURL: URL = AgentNotifySocketPath.resolveSocketURL(),
        host: ArgoControlHost?,
        tokenResolver: @escaping () -> String? = { MainActor.assumeIsolated { ArgoURLScheme.isEnabled() ? ArgoURLScheme.storedToken() : nil } },
        executablePathProvider: @escaping () -> String = { Bundle.main.executablePath ?? CommandLine.arguments.first ?? "" }
    ) {
        let dispatcherBox = AgentNotifyDispatcherBox(ArgoControlDispatcher(
            host: host,
            tokenResolver: tokenResolver,
            executablePathProvider: executablePathProvider
        ))
        self.dispatcherBox = dispatcherBox
        self.server = AgentNotifyServer(socketURL: socketURL) { frame -> Data? in
            AgentNotifyMainActorBridge.dispatchOnMain(frame, dispatcher: dispatcherBox.dispatcher)
        }
    }

    deinit {
        stop()
    }

    func start() throws {
        try server.start()
    }

    func stop() {
        server.stop()
    }
}

nonisolated private final class AgentNotifyDispatcherBox: @unchecked Sendable {
    let dispatcher: ArgoControlDispatcher

    init(_ dispatcher: ArgoControlDispatcher) {
        self.dispatcher = dispatcher
    }
}
```

Expected: the closure captures `dispatcherBox` strongly, `AgentNotifyControlServer` owns both the box and `AgentNotifyServer`, and no handler path can lose the dispatcher while the server is running.

Observed on 2026-06-22: `AgentNotifyControlServer` owns `dispatcherBox` and `server`; `AgentNotifyMainActorBridge` also wraps its dispatcher argument in `AgentNotifyDispatcherBox` before crossing the `DispatchQueue.main.async` boundary, avoiding a new non-Sendable capture warning.

- [x] **Step 5: Wire `AppDelegate` to the retained owner**

Modify `Argo/AppDelegate.swift`, change the stored server type:

```swift
@MainActor private var agentNotifyServer: AgentNotifyControlServer?
```

Replace the local dispatcher construction inside `startAgentNotifyServer()`:

```swift
@MainActor
private func startAgentNotifyServer() {
    guard agentNotifyServer == nil else { return }
    let server = AgentNotifyControlServer(host: desktopApplication)
    do {
        try server.start()
        agentNotifyServer = server
    } catch {
        NSLog("Failed to start agent notify server: \(error)")
    }
}
```

Expected: `AppDelegate` retains the same object that retains the dispatcher and socket server. `applicationWillTerminate(_:)` continues calling `agentNotifyServer?.stop()` without other changes.

Observed on 2026-06-22: `AppDelegate.agentNotifyServer` is now `AgentNotifyControlServer?`, and `startAgentNotifyServer()` constructs `AgentNotifyControlServer(host: desktopApplication)` instead of weakly capturing a local dispatcher.

- [x] **Step 6: Run the focused lifecycle test to green**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/AgentNotifyServerTests/testControlServerRetainsDispatcherAndRespondsToPing \
  test
```

Expected:

```text
** TEST SUCCEEDED **
```

The specific assertion must pass with:

```text
XCTAssertEqual(responseBox.value??.executablePath, "/debug/Argo.app/Contents/MacOS/Argo")
```

Observed on 2026-06-22:

```text
** TEST SUCCEEDED **
AgentNotifyServerTests.testControlServerRetainsDispatcherAndRespondsToPing passed
```

The red evidence before this fix was a reproducible crash:

```text
Crash: Argo at AgentNotifyServerTests.testControlServerRetainsDispatcherAndRespondsToPing(). libsystem_c.dylib: abort() called
triggered frame: AgentNotifyDispatcherBox.__deallocating_deinit
```

- [x] **Step 7: Run control and socket regressions**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/AgentNotifyServerTests \
  -only-testing:ArgoTests/ArgoControlDispatcherTests \
  -only-testing:ArgoTests/ArgoControlCLITests \
  test
```

Expected: PASS for all socket-server, dispatcher, and CLI tests.

Run:

```bash
bash -n scripts/smoke_dynamic_island_notify.sh
```

Expected: no output.

Run:

```bash
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh
```

Expected:

```text
self-test: OK
```

Run:

```bash
git diff --check
```

Expected: no output.

Observed on 2026-06-22:

```text
** TEST SUCCEEDED **
AgentNotifyServerTests: 5 tests passed
ArgoControlDispatcherTests: 17 tests passed
ArgoControlCLITests: 19 tests passed

bash -n scripts/smoke_dynamic_island_notify.sh -> no output
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh -> self-test: OK
git diff --check -> no output
```

- [x] **Step 8: Build and prove a fresh Debug app owns the control socket**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected:

```text
** BUILD SUCCEEDED **
```

Launch a fresh Debug app instance without quitting any user session:

```bash
DEBUG_APP=/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app
DEBUG_BIN="$DEBUG_APP/Contents/MacOS/Argo"
open -n "$DEBUG_APP"
```

Poll ping until the fixed socket reports the target binary:

```bash
for attempt in {1..20}; do
  actual="$("$DEBUG_BIN" ping 2>/tmp/argo-ping.stderr || true)"
  if [[ "$actual" == "$DEBUG_BIN" ]]; then
    printf '%s\n' "$actual"
    break
  fi
  sleep 0.5
done
```

Expected output:

```text
/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
```

If the loop prints nothing, inspect `/tmp/argo-ping.stderr`; expected failure before this task is:

```text
argo ping: server returned no response
```

Observed on 2026-06-22:

```text
** BUILD SUCCEEDED **
/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
```

The fresh Debug app was launched with `open -n` so existing user Argo sessions stayed alive. Multiple Argo processes still held file descriptors for the same socket path, but `argo ping` proved the active socket server responded from the fresh Debug binary.

- [ ] **Step 9: Re-run runtime Dynamic Island smoke from a real target pane**

From a terminal pane inside the fresh Debug Argo instance, run:

```bash
ARGO_BIN=/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo \
  scripts/smoke_dynamic_island_notify.sh
```

Expected success output:

```text
smoke: using /Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
smoke: pane <ARGO_PANE_ID>
smoke: screenshots written to /tmp/argo-island-smoke
```

Expected visual result: `/tmp/argo-island-smoke` contains screenshots where the Dynamic Island shows the approval card and question card. Clicking each rendered action writes the expected response text back into the originating pane. Only after this evidence is captured may Task 14 runtime audit proceed.

Observed on 2026-06-22:

```text
/tmp/argo-island-smoke-real-pane/activity.png
/tmp/argo-island-smoke-real-pane/approval-card.png
/tmp/argo-island-smoke-real-pane/question-card.png
/tmp/argo-island-smoke-real-pane/completed-card.png
```

Visual checks passed:

```text
approval-card.png shows Approve command, xcodebuild test, affected path, Allow, Deny, and Always allow.
question-card.png shows Deploy target with Production and Staging.
completed-card.png shows the completed session state.
```

Runtime write-back is still red and must be handled by Task 24 and Task 25:

```text
Clicking Allow dismisses the approval card, but the originating pane does not visibly receive "1\n".
Running argo send-keys --pane 37d97222-9ac6-4905-857d-45e492be947a --text ... returns ok, but the visible pane does not receive the text.
Manually typing with cliclick into the same visible terminal works, so the terminal UI can receive text and the remaining failure is in programmatic pane targeting/input dispatch.
```

- [ ] **Step 10: Commit the lifecycle fix**

Use `team-commit-convention` before committing. Then run:

```bash
git add Argo/Services/AgentNotify/AgentNotifyServer.swift
git add Argo/Services/AgentNotify/AgentNotifyProtocol.swift
git add Argo/AppDelegate.swift
git add Tests/AgentNotifyServerTests.swift
git add -f docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
git commit -m "fix(island): keep control"
```

Expected: commit contains only the retained control-server owner, the lifecycle regression test, and this Task 23 plan update.

Do not mark Task 23 complete until either this lifecycle fix is committed independently or Task 24 and Task 25 are completed and all fixes are committed together.

### Task 24: 统一 `send-keys` 与 action write-back 的 pane 路由，并确认 Ghostty programmatic input 仍红

**Files:**
- Modify: `Argo/Services/Terminal/ShellSession.swift`
- Modify: `Argo/Services/Terminal/WorkspaceSessionController.swift`
- Modify: `Argo/App/ArgoDesktopApplication+ControlHost.swift`
- Modify: `Argo/UI/Island/IslandPanelController.swift`
- Test: `Tests/ShellSessionTests.swift`
- Test: `Tests/WorkspaceSessionControllerTests.swift`
- Test: `Tests/ArgoControlDispatcherTests.swift`
- Modify: `docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md`

**Interfaces:**
- Consumes:
  - `ShellSession.insertText(_ text: String)`
  - `ShellSession.focus()`
  - `WorkspaceSessionController.session(for:) -> ShellSession?`
  - `WorkspaceSessionController.focus(_:)`
  - `ArgoDesktopApplication.handleSendKeys(_:) -> ArgoControlResponse`
  - `IslandResponseDispatcher(state:sendText:)`
- Produces:
  - `ShellSession.insertProgrammaticText(_ text: String)`
  - `WorkspaceSessionController.sendProgrammaticText(_ text: String, to paneID: UUID) -> Bool`
  - `handleSendKeys(_:)` and `IslandPanelController.responseDispatcher()` both use the same target-pane send path.
  - Runtime evidence that focusing the target pane before `TerminalSurfaceController.sendText(_:)` is not enough for Ghostty PTY write-back; Task 25 owns the terminal input primitive.

- [x] **Step 1: Capture the current red runtime with a file marker**

From the fresh Debug Argo pane, use a temporary token and marker file. This keeps the proof independent of visual terminal screenshots.

```bash
DEBUG_BIN=/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
TOKEN="argo-task24-$(uuidgen)"
MARKER="/tmp/argo-island-sendkeys-$(uuidgen).txt"

old_enabled="$(defaults read com.krystal.argo com.krystal.argo.urlScheme.enabled 2>/dev/null || true)"
old_token="$(defaults read com.krystal.argo com.krystal.argo.urlScheme.token 2>/dev/null || true)"
cleanup() {
  if [[ -n "$old_enabled" ]]; then
    defaults write com.krystal.argo com.krystal.argo.urlScheme.enabled -bool "$old_enabled"
  else
    defaults delete com.krystal.argo com.krystal.argo.urlScheme.enabled 2>/dev/null || true
  fi
  if [[ -n "$old_token" ]]; then
    defaults write com.krystal.argo com.krystal.argo.urlScheme.token "$old_token"
  else
    defaults delete com.krystal.argo com.krystal.argo.urlScheme.token 2>/dev/null || true
  fi
  rm -f "$MARKER"
}
trap cleanup EXIT

defaults write com.krystal.argo com.krystal.argo.urlScheme.enabled -bool true
defaults write com.krystal.argo com.krystal.argo.urlScheme.token "$TOKEN"

"$DEBUG_BIN" send-keys \
  --pane "$ARGO_PANE_ID" \
  --text "printf 'send-keys-ok' > '$MARKER'\n" \
  --token "$TOKEN"

for attempt in {1..20}; do
  [[ -f "$MARKER" ]] && cat "$MARKER" && break
  sleep 0.25
done
```

Expected before this task is implemented:

```text
ok
```

and no `send-keys-ok` marker output after five seconds. If the marker appears before code changes, the runtime failure is target-pane selection rather than terminal input dispatch; keep the same test additions below and update the implementation to route to the actual `ARGO_PANE_ID`.

Observed on 2026-06-22: `argo send-keys` returned `ok`, but no marker file appeared. Re-running the proof with an actual newline argument instead of a literal `\n` also returned `marker-missing`, so the remaining failure is not shell quoting.

- [x] **Step 2: Write the failing `ShellSession` focus-before-programmatic-input test**

Modify `Tests/ShellSessionTests.swift`, add this test beside `testInsertTextDoesNotAppendReturn`:

```swift
func testProgrammaticInsertFocusesSurfaceBeforeSendingText() async {
    await MainActor.run {
        let surface = FakeManagedTerminalSurfaceController()
        let session = ShellSession(
            snapshot: PaneSnapshot.makeDefault(cwd: "/tmp/argo-shell-session-programmatic-insert"),
            surfaceController: surface
        )

        session.insertProgrammaticText("1\n")

        XCTAssertEqual(surface.events, [.focus, .sendText("1\n")])
        XCTAssertEqual(surface.sentTexts, ["1\n"])
        XCTAssertEqual(surface.focusCallCount, 1)
    }
}
```

In the same file, add the event enum above `FakeManagedTerminalSurfaceController`:

```swift
private enum FakeTerminalSurfaceEvent: Equatable {
    case focus
    case sendText(String)
}
```

Extend `FakeManagedTerminalSurfaceController`:

```swift
private(set) var events: [FakeTerminalSurfaceEvent] = []
private(set) var focusCallCount = 0
```

Replace its `sendText(_:)` and `focus()` implementations:

```swift
func sendText(_ text: String) {
    sentTexts.append(text)
    events.append(.sendText(text))
}

func focus() {
    focusCallCount += 1
    events.append(.focus)
}
```

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/ShellSessionTests/testProgrammaticInsertFocusesSurfaceBeforeSendingText \
  test
```

Expected failure:

```text
Value of type 'ShellSession' has no member 'insertProgrammaticText'
```

- [x] **Step 3: Implement `ShellSession.insertProgrammaticText(_:)`**

Modify `Argo/Services/Terminal/ShellSession.swift`, directly below `insertText(_:)`:

```swift
func insertProgrammaticText(_ text: String) {
    focus()
    surfaceController.sendText(text)
}
```

Run the focused test again:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/ShellSessionTests/testProgrammaticInsertFocusesSurfaceBeforeSendingText \
  test
```

Expected:

```text
** TEST SUCCEEDED **
```

- [x] **Step 4: Add `WorkspaceSessionController` send-path tests**

Create `Tests/WorkspaceSessionControllerTests.swift`:

```swift
import XCTest
@testable import Argo

@MainActor
final class WorkspaceSessionControllerTests: XCTestCase {
    func testSendProgrammaticTextFocusesTargetPane() {
        let firstPaneID = UUID()
        let secondPaneID = UUID()
        let controller = WorkspaceSessionController(
            workspaceID: UUID(),
            paneSnapshots: [
                PaneSnapshot.makeDefault(id: firstPaneID, cwd: "/tmp/argo-first-pane"),
                PaneSnapshot.makeDefault(id: secondPaneID, cwd: "/tmp/argo-second-pane"),
            ]
        )

        XCTAssertEqual(controller.focusedPaneID, firstPaneID)

        let sent = controller.sendProgrammaticText("Staging\n", to: secondPaneID)

        XCTAssertTrue(sent)
        XCTAssertEqual(controller.previousFocusedPaneID, firstPaneID)
        XCTAssertEqual(controller.focusedPaneID, secondPaneID)
    }

    func testSendProgrammaticTextReturnsFalseForMissingPane() {
        let paneID = UUID()
        let controller = WorkspaceSessionController(
            workspaceID: UUID(),
            paneSnapshots: [
                PaneSnapshot.makeDefault(id: paneID, cwd: "/tmp/argo-existing-pane"),
            ]
        )

        let sent = controller.sendProgrammaticText("1\n", to: UUID())

        XCTAssertFalse(sent)
        XCTAssertEqual(controller.focusedPaneID, paneID)
    }
}
```

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceSessionControllerTests \
  test
```

Expected failure:

```text
Value of type 'WorkspaceSessionController' has no member 'sendProgrammaticText'
```

- [x] **Step 5: Implement `WorkspaceSessionController.sendProgrammaticText`**

Modify `Argo/Services/Terminal/WorkspaceSessionController.swift`, directly below `focus(_:)`:

```swift
@discardableResult
func sendProgrammaticText(_ text: String, to paneID: UUID) -> Bool {
    guard let session = sessions[paneID] else { return false }
    if focusedPaneID != paneID {
        previousFocusedPaneID = focusedPaneID
    }
    focusedPaneID = paneID
    session.insertProgrammaticText(text)
    return true
}
```

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceSessionControllerTests \
  -only-testing:ArgoTests/ShellSessionTests/testProgrammaticInsertFocusesSurfaceBeforeSendingText \
  test
```

Expected:

```text
** TEST SUCCEEDED **
```

- [x] **Step 6: Route control socket `send-keys` through the shared send path**

Modify `Argo/App/ArgoDesktopApplication+ControlHost.swift`, replace the inner session send block in `handleSendKeys(_:)`:

```swift
for store in allWorkspaceStores {
    for workspace in store.workspaces {
        if workspace.sessionController.sendProgrammaticText(request.text, to: resolvedPane) {
            return .success
        }
    }
}
return .failure("pane-not-found")
```

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/ArgoControlDispatcherTests/testSendKeysRoutesText \
  test
```

Expected:

```text
** TEST SUCCEEDED **
```

This dispatcher test remains host-level; it proves the wire command is unchanged while the concrete host implementation now uses the focused programmatic input path.

- [x] **Step 7: Route Dynamic Island action write-back through the same send path**

Modify `Argo/UI/Island/IslandPanelController.swift`, replace the `sendText` closure inside `responseDispatcher()`:

```swift
IslandResponseDispatcher(state: state) { [weak self] paneID, text in
    guard let store = self?.workspaceStore else { return false }
    for workspace in store.workspaces {
        if workspace.sessionController.sendProgrammaticText(text, to: paneID) {
            return true
        }
    }
    return false
}
```

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandResponseDispatcherTests \
  test
```

Expected:

```text
** TEST SUCCEEDED **
```

- [x] **Step 8: Run focused regression tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/ShellSessionTests/testProgrammaticInsertFocusesSurfaceBeforeSendingText \
  -only-testing:ArgoTests/WorkspaceSessionControllerTests \
  -only-testing:ArgoTests/ArgoControlDispatcherTests \
  -only-testing:ArgoTests/ArgoControlCLITests \
  -only-testing:ArgoTests/IslandResponseDispatcherTests \
  test
```

Expected:

```text
** TEST SUCCEEDED **
```

- [x] **Step 9: Rebuild and prove the shared route still fails at the Ghostty input primitive**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected:

```text
** BUILD SUCCEEDED **
```

Relaunch a fresh Debug app instance without quitting user sessions:

```bash
DEBUG_APP=/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app
DEBUG_BIN="$DEBUG_APP/Contents/MacOS/Argo"
open -n "$DEBUG_APP"
```

Run the marker proof from Step 1 again, but pass a real trailing newline so this check cannot be invalidated by shell quoting:

```bash
DEBUG_BIN=/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
PANE_ID=37d97222-9ac6-4905-857d-45e492be947a
TOKEN="argo-task24-newline-$(uuidgen)"
MARKER="/tmp/argo-island-sendkeys-newline-$(uuidgen).txt"

old_enabled="$(defaults read com.krystal.argo com.krystal.argo.urlScheme.enabled 2>/dev/null || true)"
old_token="$(defaults read com.krystal.argo com.krystal.argo.urlScheme.token 2>/dev/null || true)"
cleanup() {
  if [[ -n "$old_enabled" ]]; then
    defaults write com.krystal.argo com.krystal.argo.urlScheme.enabled "$old_enabled" >/dev/null 2>&1 || true
  else
    defaults delete com.krystal.argo com.krystal.argo.urlScheme.enabled >/dev/null 2>&1 || true
  fi
  if [[ -n "$old_token" ]]; then
    defaults write com.krystal.argo com.krystal.argo.urlScheme.token "$old_token" >/dev/null 2>&1 || true
  else
    defaults delete com.krystal.argo com.krystal.argo.urlScheme.token >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

defaults write com.krystal.argo com.krystal.argo.urlScheme.enabled -bool true
defaults write com.krystal.argo com.krystal.argo.urlScheme.token "$TOKEN"
command="printf 'send-keys-ok' > '$MARKER'"
"$DEBUG_BIN" send-keys --pane "$PANE_ID" --text "${command}"$'\n' --token "$TOKEN"
for attempt in {1..20}; do
  if [[ -f "$MARKER" ]]; then
    cat "$MARKER"
    rm -f "$MARKER"
    break
  fi
  sleep 0.25
done
```

Expected after Task 24 only:

```text
ok
```

and no `send-keys-ok` marker. This is intentional red evidence for Task 25.

Observed on 2026-06-22 after focused routing implementation and Debug rebuild:

```text
marker-missing:/tmp/argo-island-sendkeys-newline-2EE2B0F8-BB1A-4D9A-A19B-61EA43BFA38E.txt
```

- [x] **Step 10: Record why the Dynamic Island smoke remains blocked**

Do not run Task 14 runtime audit to completion yet. The blocked path is now precise:

```text
IslandResponseDispatcher -> WorkspaceSessionController.sendProgrammaticText(_:to:)
  -> ShellSession.insertProgrammaticText(_:)
  -> ArgoGhosttyController.sendText(_:)
  -> ArgoGhosttySurfaceView.insertTerminalText(_:)
  -> ghostty_surface_text(...)
```

This chain is invoked and returns success to the control socket, but the target PTY does not receive the command. Manual keyboard typing into the same visible pane still works, which means the next task must replace the Ghostty programmatic input primitive rather than continue changing pane lookup or control-socket auth.

- [ ] **Step 11: Defer the write-back commit until Task 25 passes**

Do not commit this as `fix(island): send response` yet. Keep the Task 23 lifecycle fix, Task 24 shared route, and Task 25 terminal-input fix together until the runtime marker and approval/question clicks are green.

Expected after this step:

```text
Task 24 focused unit tests pass, Debug build passes, runtime marker remains red, and Task 25 is required.
```

### Task 25: 用 Ghostty key-event programmatic input 替换 `ghostty_surface_text`

**Files:**
- Modify: `Argo/Services/Terminal/TerminalSurface.swift`
- Modify: `Argo/Services/Terminal/ShellSession.swift`
- Modify: `Argo/Services/Terminal/WorkspaceSessionController.swift`
- Modify: `Argo/Services/Terminal/Ghostty/ArgoGhosttyController.swift`
- Modify: `Tests/ShellSessionTests.swift`
- Modify: `Tests/WorkspaceSessionControllerTests.swift`
- Modify: `docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md`

**Interfaces:**
- Consumes:
  - `TerminalSurfaceController.sendText(_:)`
  - `TerminalSurfaceController.sendReturn()`
  - `ArgoGhosttySurfaceView.insertTerminalReturn()`
  - `ghostty_surface_key(_:_:)`
  - `WorkspaceSessionController.sendProgrammaticText(_ text: String, to paneID: UUID) -> Bool`
- Produces:
  - `TerminalSurfaceController.sendProgrammaticText(_ text: String) -> Bool`
  - `ShellSession.insertProgrammaticText(_ text: String) -> Bool`
  - `ArgoGhosttyController.sendProgrammaticText(_ text: String) -> Bool`
  - `ArgoGhosttySurfaceView.insertProgrammaticTerminalText(_ text: String) -> Bool`
  - `WorkspaceSessionController.sendProgrammaticText(_ text: String, to paneID: UUID) -> Bool` returns `false` when the target pane exists but the terminal surface cannot accept programmatic input.

- [x] **Step 1: Replace the shell-session test with a surface-specific programmatic input contract**

Modify `Tests/ShellSessionTests.swift`. Replace `testProgrammaticInsertFocusesSurfaceBeforeSendingText` with:

```swift
func testProgrammaticInsertFocusesSurfaceBeforeSendingProgrammaticText() async {
    await MainActor.run {
        let surface = FakeManagedTerminalSurfaceController()
        let session = ShellSession(
            snapshot: PaneSnapshot.makeDefault(cwd: "/tmp/argo-shell-session-programmatic-insert"),
            surfaceController: surface
        )

        let sent = session.insertProgrammaticText("1\n")

        XCTAssertTrue(sent)
        XCTAssertEqual(surface.events, [.focus, .sendProgrammaticText("1\n")])
        XCTAssertEqual(surface.sentProgrammaticTexts, ["1\n"])
        XCTAssertEqual(surface.sentTexts, [])
        XCTAssertEqual(surface.focusCallCount, 1)
    }
}

func testProgrammaticInsertReturnsFalseWhenSurfaceRejectsInput() async {
    await MainActor.run {
        let surface = FakeManagedTerminalSurfaceController()
        surface.programmaticTextResult = false
        let session = ShellSession(
            snapshot: PaneSnapshot.makeDefault(cwd: "/tmp/argo-shell-session-programmatic-reject"),
            surfaceController: surface
        )

        let sent = session.insertProgrammaticText("1\n")

        XCTAssertFalse(sent)
        XCTAssertEqual(surface.events, [.focus, .sendProgrammaticText("1\n")])
    }
}
```

In the same file, change `FakeTerminalSurfaceEvent` to:

```swift
private enum FakeTerminalSurfaceEvent: Equatable {
    case focus
    case sendText(String)
    case sendProgrammaticText(String)
}
```

Extend `FakeManagedTerminalSurfaceController` with:

```swift
var programmaticTextResult = true
private(set) var sentProgrammaticTexts: [String] = []
```

Add this method to the fake:

```swift
func sendProgrammaticText(_ text: String) -> Bool {
    sentProgrammaticTexts.append(text)
    events.append(.sendProgrammaticText(text))
    return programmaticTextResult
}
```

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/ShellSessionTests/testProgrammaticInsertFocusesSurfaceBeforeSendingProgrammaticText \
  -only-testing:ArgoTests/ShellSessionTests/testProgrammaticInsertReturnsFalseWhenSurfaceRejectsInput \
  test
```

Expected failure:

```text
Cannot convert value of type '()' to expected argument type 'Bool'
```

Observed on 2026-06-22:

```text
** TEST FAILED **
ShellSessionTests.swift:410:27: error: cannot convert value of type '()' to expected argument type 'Bool'
ShellSessionTests.swift:429:28: error: cannot convert value of type '()' to expected argument type 'Bool'
```

- [x] **Step 2: Add the programmatic input method to the terminal surface protocol**

Modify `Argo/Services/Terminal/TerminalSurface.swift`. Add this requirement directly below `func sendText(_ text: String)`:

```swift
@discardableResult
func sendProgrammaticText(_ text: String) -> Bool
```

In `ArgoTestManagedTerminalSurfaceController`, add:

```swift
@discardableResult
func sendProgrammaticText(_ text: String) -> Bool {
    sendText(text)
    return true
}
```

Modify `Argo/Services/Terminal/ShellSession.swift`. Replace `insertProgrammaticText(_:)` with:

```swift
@discardableResult
func insertProgrammaticText(_ text: String) -> Bool {
    focus()
    return surfaceController.sendProgrammaticText(text)
}
```

Modify `Argo/Services/Terminal/WorkspaceSessionController.swift`. Replace the last two lines of `sendProgrammaticText(_:to:)`:

```swift
session.insertProgrammaticText(text)
return true
```

with:

```swift
return session.insertProgrammaticText(text)
```

Run the focused tests again:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/ShellSessionTests/testProgrammaticInsertFocusesSurfaceBeforeSendingProgrammaticText \
  -only-testing:ArgoTests/ShellSessionTests/testProgrammaticInsertReturnsFalseWhenSurfaceRejectsInput \
  -only-testing:ArgoTests/WorkspaceSessionControllerTests \
  test
```

Expected failure:

```text
Type 'ArgoGhosttyController' does not conform to protocol 'TerminalSurfaceController'
```

Observed on 2026-06-22:

```text
** TEST FAILED **
ArgoGhosttyController.swift:15:13: error: type 'ArgoGhosttyController' does not conform to protocol 'TerminalSurfaceController'
```

- [x] **Step 3: Implement Ghostty programmatic input with `ghostty_surface_key`**

Modify `Argo/Services/Terminal/Ghostty/ArgoGhosttyController.swift`. Add this method to `ArgoGhosttyController` directly below `sendText(_:)`:

```swift
@discardableResult
func sendProgrammaticText(_ text: String) -> Bool {
    terminalView.insertProgrammaticTerminalText(text)
}
```

In `ArgoGhosttySurfaceView`, add this method directly below `insertTerminalText(_:)`:

```swift
@discardableResult
func insertProgrammaticTerminalText(_ string: String) -> Bool {
    guard let surface else { return false }
    guard !string.isEmpty else { return true }

    window?.makeFirstResponder(self)

    for scalar in string.unicodeScalars {
        if scalar.value == 0x0A || scalar.value == 0x0D {
            insertTerminalReturn()
            continue
        }

        let text = String(scalar)
        text.withCString { pointer in
            var press = ghostty_input_key_s()
            press.action = GHOSTTY_ACTION_PRESS
            press.mods = GHOSTTY_MODS_NONE
            press.consumed_mods = GHOSTTY_MODS_NONE
            press.keycode = 0
            press.text = pointer
            press.unshifted_codepoint = scalar.value
            press.composing = false
            _ = ghostty_surface_key(surface, press)

            var release = press
            release.action = GHOSTTY_ACTION_RELEASE
            _ = ghostty_surface_key(surface, release)
        }
    }

    return true
}
```

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/ShellSessionTests/testProgrammaticInsertFocusesSurfaceBeforeSendingProgrammaticText \
  -only-testing:ArgoTests/ShellSessionTests/testProgrammaticInsertReturnsFalseWhenSurfaceRejectsInput \
  -only-testing:ArgoTests/WorkspaceSessionControllerTests \
  test
```

Expected:

```text
** TEST SUCCEEDED **
```

Observed on 2026-06-22:

```text
** TEST SUCCEEDED **
ShellSessionTests.testProgrammaticInsertFocusesSurfaceBeforeSendingProgrammaticText passed
ShellSessionTests.testProgrammaticInsertReturnsFalseWhenSurfaceRejectsInput passed
WorkspaceSessionControllerTests passed
```

- [x] **Step 4: Run the control and response dispatcher regressions**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/ArgoControlDispatcherTests \
  -only-testing:ArgoTests/ArgoControlCLITests \
  -only-testing:ArgoTests/IslandResponseDispatcherTests \
  test
```

Expected:

```text
** TEST SUCCEEDED **
```

Observed on 2026-06-22:

```text
** TEST SUCCEEDED **
ArgoControlCLITests passed
ArgoControlDispatcherTests passed
IslandResponseDispatcherTests passed
```

- [x] **Step 5: Rebuild Debug Argo**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected:

```text
** BUILD SUCCEEDED **
```

Relaunch a fresh Debug app instance without quitting user sessions:

```bash
DEBUG_APP=/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app
open -n "$DEBUG_APP"
```

Observed on 2026-06-22:

```text
** BUILD SUCCEEDED **
ping-ok:/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
Terminal 37d97222-9ac6-4905-857d-45e492be947a /Users/liaojingyu
```

- [x] **Step 6: Prove `send-keys` writes a marker file**

Run:

```bash
DEBUG_BIN=/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
PANE_ID=37d97222-9ac6-4905-857d-45e492be947a
TOKEN="argo-task25-$(uuidgen)"
MARKER="/tmp/argo-island-sendkeys-$(uuidgen).txt"

old_enabled="$(defaults read com.krystal.argo com.krystal.argo.urlScheme.enabled 2>/dev/null || true)"
old_token="$(defaults read com.krystal.argo com.krystal.argo.urlScheme.token 2>/dev/null || true)"
cleanup() {
  if [[ -n "$old_enabled" ]]; then
    defaults write com.krystal.argo com.krystal.argo.urlScheme.enabled "$old_enabled" >/dev/null 2>&1 || true
  else
    defaults delete com.krystal.argo com.krystal.argo.urlScheme.enabled >/dev/null 2>&1 || true
  fi
  if [[ -n "$old_token" ]]; then
    defaults write com.krystal.argo com.krystal.argo.urlScheme.token "$old_token" >/dev/null 2>&1 || true
  else
    defaults delete com.krystal.argo com.krystal.argo.urlScheme.token >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

defaults write com.krystal.argo com.krystal.argo.urlScheme.enabled -bool true
defaults write com.krystal.argo com.krystal.argo.urlScheme.token "$TOKEN"
command="printf 'send-keys-ok' > '$MARKER'"
"$DEBUG_BIN" send-keys --pane "$PANE_ID" --text "${command}"$'\n' --token "$TOKEN"
for attempt in {1..20}; do
  if [[ -f "$MARKER" ]]; then
    cat "$MARKER"
    rm -f "$MARKER"
    break
  fi
  sleep 0.25
done
```

Expected:

```text
ok
send-keys-ok
```

Observed on 2026-06-22:

```text
send-keys-ok
```

- [x] **Step 7: Prove approval and question action write-back**

Run:

```bash
env \
  ARGO_ISLAND_SMOKE_DIR=/tmp/argo-island-smoke-real-pane \
  ARGO_BIN=/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo \
  ARGO_PANE_ID=37d97222-9ac6-4905-857d-45e492be947a \
  bash scripts/smoke_dynamic_island_notify.sh
```

Expected:

```text
smoke: screenshots written to /tmp/argo-island-smoke-real-pane
```

Manual verification:

```text
Click Allow in the approval card -> the originating pane receives "1\n".
Click Always allow in the approval card -> the originating pane receives "always\n".
Click Staging in the question card -> the originating pane receives "Staging\n".
```

Record the observed screenshot paths and write-back result under this step before marking it complete.

Observed on 2026-06-22:

```text
smoke: screenshots written to /tmp/argo-island-smoke-real-pane
/tmp/argo-island-smoke-real-pane/approval-card.png
/tmp/argo-island-smoke-real-pane/question-card.png
/tmp/argo-island-smoke-real-pane/completed-card.png
```

Visual evidence:

```text
approval-card.png shows Task 25 approval styling with command/path context and action buttons.
question-card.png shows the question card with Production and Staging.
completed-card.png shows the completed state.
```

Runtime write-back evidence:

```text
Custom approval Allow click wrote marker output: approval-click-ok
Custom question Staging click wrote marker output: question-staging-ok
```

Synthetic click calibration note: `cliclick` uses display points while screenshots are 2x pixels; the successful Allow click used `c:681,190`, and the successful Staging click used `c:760,166`.

- [x] **Step 8: Commit the lifecycle and write-back fixes together**

Use `team-commit-convention` before committing. Then run:

```bash
git add Argo/AppDelegate.swift
git add Argo/Services/AgentNotify/AgentNotifyProtocol.swift
git add Argo/Services/AgentNotify/AgentNotifyServer.swift
git add Argo/Services/Terminal/TerminalSurface.swift
git add Argo/Services/Terminal/ShellSession.swift
git add Argo/Services/Terminal/WorkspaceSessionController.swift
git add Argo/Services/Terminal/Ghostty/ArgoGhosttyController.swift
git add Argo/App/ArgoDesktopApplication+ControlHost.swift
git add Argo/UI/Island/IslandPanelController.swift
git add Tests/AgentNotifyServerTests.swift
git add Tests/ShellSessionTests.swift
git add Tests/WorkspaceSessionControllerTests.swift
git add -f docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
git commit -m "fix(island): send response"
```

Expected: commit contains the Task 23 retained control-server owner, Task 24 shared pane route, Task 25 Ghostty programmatic input primitive, focused tests, and this plan update. `default.profraw` remains unstaged.

Observed on 2026-06-22:

```text
Committed Tasks 23-25 with fix(island): send response at 66a7163.
```

- [ ] **Step 9: Resume Task 14 runtime parity audit**

Run:

```bash
env \
  ARGO_ISLAND_SMOKE_DIR=/tmp/argo-island-smoke-real-pane \
  ARGO_BIN=/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo \
  ARGO_PANE_ID="$ARGO_PANE_ID" \
  bash scripts/smoke_dynamic_island_notify.sh
```

Expected:

```text
smoke: screenshots written to /tmp/argo-island-smoke-real-pane
```

Manual verification:

```text
Click Allow in the approval card -> the originating pane receives "1\n".
Click Always allow in the approval card -> the originating pane receives "always\n".
Click Staging in the question card -> the originating pane receives "Staging\n".
```

Expected: Task 14 runtime audit can now continue with screenshot evidence and action write-back evidence.

### Task 26: 提交 write-back 修复并完成最终 runtime parity audit

**Files:**
- Modify: `Argo/Support/IslandSessionState.swift`
- Modify: `Argo/UI/Island/IslandSessionSections.swift`
- Modify: `Tests/IslandSessionStateTests.swift`
- Modify: `Tests/IslandUISourceTests.swift`
- Modify: `docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md`

**Interfaces:**
- Consumes:
  - Task 23 retained `AgentNotifyControlServer` lifecycle fix.
  - Task 24 shared `WorkspaceSessionController.sendProgrammaticText(_:to:)` route.
  - Task 25 `TerminalSurfaceController.sendProgrammaticText(_:) -> Bool` and Ghostty key-event input primitive.
  - Runtime screenshots under `/tmp/argo-island-smoke-real-pane`.
  - A real target Debug Argo pane with `$ARGO_PANE_ID`.
- Produces:
  - One commit containing Tasks 23-25: `fix(island): send response`.
  - Final runtime audit evidence for approval, question, completed, failed, grouped sessions, collapsed agents grid, and originating-pane write-back.
  - A final audit note committed as `feat(island): sync audit` only if this plan is updated with new observed evidence after the code commit.

- [x] **Step 1: Re-run pre-commit verification for the uncommitted Tasks 23-25 changes**

Run:

```bash
git status --short --branch
```

Expected: modified files are limited to the Task 23-25 code/tests/plan set, `Tests/WorkspaceSessionControllerTests.swift` is untracked, and `default.profraw` is the only unrelated untracked artifact.

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/AgentNotifyServerTests \
  -only-testing:ArgoTests/ShellSessionTests/testProgrammaticInsertFocusesSurfaceBeforeSendingProgrammaticText \
  -only-testing:ArgoTests/ShellSessionTests/testProgrammaticInsertReturnsFalseWhenSurfaceRejectsInput \
  -only-testing:ArgoTests/WorkspaceSessionControllerTests \
  -only-testing:ArgoTests/ArgoControlDispatcherTests \
  -only-testing:ArgoTests/ArgoControlCLITests \
  -only-testing:ArgoTests/IslandResponseDispatcherTests \
  test
```

Expected:

```text
** TEST SUCCEEDED **
```

Run:

```bash
bash -n scripts/smoke_dynamic_island_notify.sh
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh
git diff --check
```

Expected:

```text
bash -n scripts/smoke_dynamic_island_notify.sh -> no output
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh -> self-test: OK
git diff --check -> no output
```

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected:

```text
** BUILD SUCCEEDED **
```

Observed on 2026-06-22:

```text
xcodebuild focused Task 23-25 regression set -> ** TEST SUCCEEDED **
bash -n scripts/smoke_dynamic_island_notify.sh -> no output
ARGO_ISLAND_SMOKE_SELF_TEST=1 bash scripts/smoke_dynamic_island_notify.sh -> self-test: OK
git diff --check -> no output
xcodebuild Debug build -> ** BUILD SUCCEEDED **
```

- [x] **Step 2: Commit the Tasks 23-25 lifecycle, route, and Ghostty input fixes**

Use `team-commit-convention` before committing. Then run:

```bash
git add Argo/AppDelegate.swift
git add Argo/Services/AgentNotify/AgentNotifyProtocol.swift
git add Argo/Services/AgentNotify/AgentNotifyServer.swift
git add Argo/Services/Terminal/TerminalSurface.swift
git add Argo/Services/Terminal/ShellSession.swift
git add Argo/Services/Terminal/WorkspaceSessionController.swift
git add Argo/Services/Terminal/Ghostty/ArgoGhosttyController.swift
git add Argo/App/ArgoDesktopApplication+ControlHost.swift
git add Argo/UI/Island/IslandPanelController.swift
git add Tests/AgentNotifyServerTests.swift
git add Tests/ShellSessionTests.swift
git add Tests/WorkspaceSessionControllerTests.swift
git add -f docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
git commit -m "fix(island): send response"
```

Expected: commit succeeds, includes only Tasks 23-25 code/tests/plan updates, and leaves `default.profraw` unstaged.

Run:

```bash
git status --short --branch
```

Expected: branch is clean except for `?? default.profraw` or other explicitly unrelated local artifacts.

Observed on 2026-06-22:

```text
Committed Tasks 23-25 with fix(island): send response at 66a7163.
Post-commit status is clean except for the unrelated untracked default.profraw before this plan-note update.
```

- [x] **Step 3: Relaunch a fresh target Debug Argo and prove the control socket owner**

Run outside Argo if needed:

```bash
DEBUG_APP=/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app
DEBUG_BIN="$DEBUG_APP/Contents/MacOS/Argo"
open -n "$DEBUG_APP"
for attempt in {1..20}; do
  actual="$("$DEBUG_BIN" ping 2>/tmp/argo-ping.stderr || true)"
  if [[ "$actual" == "$DEBUG_BIN" ]]; then
    printf 'ping-ok:%s\n' "$actual"
    break
  fi
  sleep 0.5
done
```

Expected:

```text
ping-ok:/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
```

If the loop prints nothing, inspect `/tmp/argo-ping.stderr`. Expected actionable failures:

```text
argo: Argo is not running
argo ping: server returned no response
```

Do not kill existing user Argo processes automatically. If the fixed socket is owned by the wrong app, quit or relaunch the target Debug app only after the user has saved important terminal sessions.

Observed on 2026-06-22:

```text
ping-ok:/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
```

- [x] **Step 4: Run the baseline smoke from a real target Debug Argo pane**

From a terminal pane inside the fresh target Debug Argo app:

```bash
printf 'pane:%s\n' "$ARGO_PANE_ID"
env \
  ARGO_ISLAND_SMOKE_DIR=/tmp/argo-island-smoke-real-pane \
  ARGO_BIN=/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo \
  bash scripts/smoke_dynamic_island_notify.sh
```

Expected:

```text
pane:37d97222-9ac6-4905-857d-45e492be947a
smoke: using /Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
smoke: pane 37d97222-9ac6-4905-857d-45e492be947a
smoke: screenshots written to /tmp/argo-island-smoke-real-pane
```

If the pane ID differs in the fresh target Debug app, replace `37d97222-9ac6-4905-857d-45e492be947a` in the expected output with the exact UUID printed by `printf 'pane:%s\n' "$ARGO_PANE_ID"`.

Expected screenshots:

```text
/tmp/argo-island-smoke-real-pane/activity.png
/tmp/argo-island-smoke-real-pane/approval-card.png
/tmp/argo-island-smoke-real-pane/question-card.png
/tmp/argo-island-smoke-real-pane/completed-card.png
```

Visual expectations:

```text
approval-card.png shows Approve command, Run tests?, xcodebuild test, affected path, Allow, Deny, and Always allow.
question-card.png shows Deploy target, Which target?, Production, and Staging.
completed-card.png shows Smoke complete / All clear as a completed session.
```

Observed on 2026-06-22:

```text
External-shell smoke was correctly blocked by stale older Debug Argo processes with exit 3.
Pane-executed smoke via /tmp/argo-run-smoke-from-pane.sh succeeded with smoke-pane-exit:0.
Screenshots written to /tmp/argo-island-smoke-real-pane.
question-card.png shows Deploy target with Production and Staging.
completed-card.png shows All clear as a completed session.
approval-card.png from the baseline run did not capture the card clearly, so a unique approval event was captured separately at /tmp/argo-island-smoke-real-pane/task26-approval-card.png.
task26-approval-card.png shows Task 26 approval, xcodebuild test, /Users/liaojingyu/argo, and Allow/Deny/Always allow.
```

- [x] **Step 5: Verify every approval action with marker-file write-back**

Run this from the same target Argo pane after confirming the shell prompt is active:

```bash
DEBUG_BIN=/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
PANE_ID="$ARGO_PANE_ID"
ALLOW_MARKER="/tmp/argo-island-approval-allow-$(uuidgen).txt"
DENY_MARKER="/tmp/argo-island-approval-deny-$(uuidgen).txt"
ALWAYS_MARKER="/tmp/argo-island-approval-always-$(uuidgen).txt"

"$DEBUG_BIN" notify \
  --approval \
  --title "Approval marker audit" \
  --body "Click one action" \
  --pane "$PANE_ID" \
  --session "audit-approval-allow" \
  --source "audit-approval-allow" \
  --tool Codex \
  --current-tool exec_command \
  --command-preview "marker write-back" \
  --affected-path "$PWD" \
  --option "Allow=printf 'approval-allow-ok' > '$ALLOW_MARKER'\n" \
  --option "Deny=printf 'approval-deny-ok' > '$DENY_MARKER'\n" \
  --option "Always allow=printf 'approval-always-ok' > '$ALWAYS_MARKER'\n"
```

Click `Allow`, then run:

```bash
for attempt in {1..20}; do
  [[ -f "$ALLOW_MARKER" ]] && cat "$ALLOW_MARKER" && break
  sleep 0.25
done
rm -f "$ALLOW_MARKER"
```

Expected:

```text
approval-allow-ok
```

Repeat the same notify command twice with new session/source IDs, click `Deny` and `Always allow`, and then run:

```bash
for attempt in {1..20}; do
  [[ -f "$DENY_MARKER" ]] && cat "$DENY_MARKER" && break
  sleep 0.25
done
for attempt in {1..20}; do
  [[ -f "$ALWAYS_MARKER" ]] && cat "$ALWAYS_MARKER" && break
  sleep 0.25
done
rm -f "$DENY_MARKER" "$ALWAYS_MARKER"
```

Expected:

```text
approval-deny-ok
approval-always-ok
```

Observed on 2026-06-22:

```text
approval-allow-ok
approval-deny-ok
approval-always-ok
```

- [x] **Step 6: Verify question option write-back with a marker file**

Run this from the same target Argo pane:

```bash
DEBUG_BIN=/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
PANE_ID="$ARGO_PANE_ID"
QUESTION_MARKER="/tmp/argo-island-question-staging-$(uuidgen).txt"

"$DEBUG_BIN" notify \
  --question \
  --title "Question marker audit" \
  --body "Which target?" \
  --pane "$PANE_ID" \
  --session "audit-question-staging" \
  --source "audit-question-staging" \
  --tool Codex \
  --option "Production=printf 'question-production-ok' > '$QUESTION_MARKER'\n" \
  --option "Staging=printf 'question-staging-ok' > '$QUESTION_MARKER'\n"
```

Click `Staging`, then run:

```bash
for attempt in {1..20}; do
  [[ -f "$QUESTION_MARKER" ]] && cat "$QUESTION_MARKER" && break
  sleep 0.25
done
rm -f "$QUESTION_MARKER"
```

Expected:

```text
question-staging-ok
```

Observed on 2026-06-22:

```text
question-staging-ok
```

- [x] **Step 7: Complete the Task 14 runtime audit matrix and record only concrete results**

Run or manually verify each item from Task 14 Step 3. Append a runtime audit note under Task 14 Step 3 only after each line has a real observed result and concrete evidence. Do not write ambiguous combined status markers or generic evidence labels; every line must contain either a concrete `PASS` with a real file path, command output, or test name, or it must be replaced by a new focused follow-up task.

Use this evidence map when updating Task 14 Step 3. Lines marked `RUNTIME GAP` have passing unit or surface evidence, but still need a direct runtime screenshot or terminal-output proof before Task 14 can be checked off:

```text
Runtime parity audit evidence map, 2026-06-22:
1. Activity event from pane A appears in collapsed island: PASS. Evidence: /tmp/argo-island-smoke-real-pane/activity.png.
2. Activity event from pane B adds a second live session: PASS. Evidence: session list showed pane ff651f49-a639-4c59-ac23-9d73607e383c and pane 37d97222-9ac6-4905-857d-45e492be947a; /tmp/argo-island-smoke-real-pane/task26-two-pane-grid.png.
3. Collapsed island shows agents grid or count for both live sessions: PASS. Evidence: /tmp/argo-island-smoke-real-pane/task26-two-pane-grid-top-crop.png shows multiple live cells and a +4 overflow badge.
4. Expanded Sessions tab groups both live sessions under Running: PASS. Evidence: /tmp/argo-island-smoke-real-pane/task26-expanded-sessions-top-crop.png shows ff651f49 and 37d97222 under 进行中.
5. Approval event opens a notification card immediately: PASS. Evidence: /tmp/argo-island-smoke-real-pane/task26-approval-card.png.
6. Approval card displays command preview and affected path: PASS. Evidence: /tmp/argo-island-smoke-real-pane/task26-approval-card.png shows xcodebuild test and /Users/liaojingyu/argo.
7. Approval card Show All returns to grouped Sessions without losing the waiting record: PASS. Evidence: /tmp/argo-island-smoke-real-pane/task26-showall2-after-top-crop.png shows the Sessions tab, 需要审批, and the waiting approval card.
8. Allow writes the configured response text into the originating pane: PASS. Evidence: marker output approval-allow-ok.
9. Deny writes the configured response text into the originating pane: PASS. Evidence: marker output approval-deny-ok.
9a. Always allow writes the configured response text into the originating pane: PASS. Evidence: marker output approval-always-ok.
10. Question event opens a notification card immediately: PASS. Evidence: /tmp/argo-island-smoke-real-pane/question-card.png.
11. Question option writes the configured response text into the originating pane: PASS. Evidence: marker output question-staging-ok.
12. Completed event appears under Just Done: PASS. Evidence: /tmp/argo-island-smoke-real-pane/completed-card.png.
13. Failed event appears above Running and displays lastError: PASS. Evidence: /tmp/argo-island-smoke-real-pane/task26-failed2-card-top-crop.png and /tmp/argo-island-smoke-real-pane/task26-failed2-expanded-top-crop.png show lastError audit failure above 进行中.
14. A completed session older than IslandAgentSession.staleCompletedDisplayThreshold moves to Idle: PASS. Evidence: xcodebuild focused audit set returned ** TEST SUCCEEDED ** for IslandSessionPresentationTests/testCompletedSessionBecomesStaleForIslandAfterThreshold and IslandSessionSectionsTests/testStaleCompletedSessionsMoveFromJustDoneToIdle.
15. Workspace status success appears as a completed session and does not create a legacy item: PASS. Evidence: xcodebuild returned ** TEST SUCCEEDED ** for WorkspaceStoreTests/testDynamicIslandStatusMessagePostsSessionEvent.
16. Workspace status warning appears as a failed session and does not create a legacy item: PASS. Evidence: xcodebuild returned ** TEST SUCCEEDED ** for WorkspaceStoreTests/testDynamicIslandStatusMessagePostsSessionEvent.
17. Clicking a session focuses the correct workspace, worktree, and pane: PASS. Evidence: /tmp/argo-island-smoke-real-pane/task27-final-focus-list-before-click.png shows the rendered session row tagged ce6c7fb7; after clicking it, the no-pane raw control send wrote marker output task27-final-click-focus-b-ok and /tmp/argo-island-smoke-real-pane/task27-final-display2-after-click-focus-b.png shows TASK27_FINAL_NO_PANE_AFTER_CLICK_B in the pane labeled TASK27_LABEL_PANE_B. Unit evidence also passes via IslandWorkspaceNavigatorTests/testNavigateFocusesWorkspaceWorktreeAndPane.
18. Dismissing or resolving an actionable session returns the surface to the session list when appropriate: PASS. Evidence: /tmp/argo-island-smoke-real-pane/task27-resolve-final-card-display1.png shows the approval card, marker output task27-resolve-final-ok proves Allow write-back, and /tmp/argo-island-smoke-real-pane/task27-final-sessions-list-display1.png shows the Sessions tab with the resolved "Bash resolve final" row running and no stale Allow/Deny buttons.
```

For any remaining runtime-only item, capture a screenshot or exact terminal output first, then write the line with that real path or output. If any item fails, do not write a final PASS table. Stop and add a focused follow-up task below Task 26. Use this concrete title pattern for the next failure:

```text
### Task 27: Fix runtime audit item 8 action write-back
```

Replace the item number and short symptom with the actual failing audit item. The new task must include the failing screenshot path, a focused red test or deterministic reproduction command, the expected implementation file paths, and a verification command.

Observed concrete audit evidence on 2026-06-22:

```text
2. Activity event from pane B adds a second live session: PASS evidence captured. Evidence: session list showed pane ff651f49-a639-4c59-ac23-9d73607e383c and pane 37d97222-9ac6-4905-857d-45e492be947a; /tmp/argo-island-smoke-real-pane/task26-two-pane-grid.png was captured after sending activity events to both panes.
3. Collapsed island shows agents grid or count for both live sessions: PASS evidence captured. Evidence: /tmp/argo-island-smoke-real-pane/task26-two-pane-grid-top-crop.png shows the collapsed agents grid with multiple live cells and a +4 overflow badge.
4. Expanded Sessions tab groups both sessions under Running: PASS evidence captured. Evidence: /tmp/argo-island-smoke-real-pane/task26-expanded-sessions-top-crop.png shows both pane tags under the running group.
7. Approval card Show All returns to grouped Sessions without losing the waiting record: PASS evidence captured. Evidence: /tmp/argo-island-smoke-real-pane/task26-showall2-after-top-crop.png shows the Sessions tab, 需要审批, and the waiting approval card after clicking Show All.
8. Allow, Deny, and Always allow write configured response text into the originating pane: PASS evidence captured. Evidence: marker outputs approval-allow-ok, approval-deny-ok, approval-always-ok.
9. Question option writes the configured response text into the originating pane: PASS evidence captured. Evidence: marker output question-staging-ok.
13. Failed event appears above Running and displays lastError: PASS evidence captured. Evidence: /tmp/argo-island-smoke-real-pane/task26-failed2-card-top-crop.png and /tmp/argo-island-smoke-real-pane/task26-failed2-expanded-top-crop.png show lastError audit failure above the running list.
14. A completed session older than IslandAgentSession.staleCompletedDisplayThreshold moves to Idle: PASS test evidence captured. Evidence: IslandSessionPresentationTests/testCompletedSessionBecomesStaleForIslandAfterThreshold and IslandSessionSectionsTests/testStaleCompletedSessionsMoveFromJustDoneToIdle returned ** TEST SUCCEEDED **.
17. Clicking a session focuses the correct workspace, worktree, and pane: PASS evidence captured. Evidence: /tmp/argo-island-smoke-real-pane/task27-final-focus-list-before-click.png shows the rendered session row tagged ce6c7fb7. Before the click, a focused-pane baseline wrote TASK27_FINAL_BASELINE_FOCUS_A into pane 9ef8e47c; after clicking the ce6c7fb7 row, a raw no-pane control send wrote marker output task27-final-click-focus-b-ok and /tmp/argo-island-smoke-real-pane/task27-final-display2-after-click-focus-b.png shows TASK27_FINAL_NO_PANE_AFTER_CLICK_B in the pane labeled TASK27_LABEL_PANE_B.
18. Dismissing or resolving an actionable session returns the surface to the session list when appropriate: PASS evidence captured. Evidence: /tmp/argo-island-smoke-real-pane/task27-resolve-final-card-display1.png shows the approval card; marker output task27-resolve-final-ok proves Allow write-back; /tmp/argo-island-smoke-real-pane/task27-final-sessions-list-display1.png shows the Sessions list after resolution with the resolved "Bash resolve final" row in running state and no stale Allow/Deny controls.
```

- [x] **Step 8: Commit the final audit note if the plan was updated**

If Step 7 adds runtime audit observations to this plan, run:

```bash
git add -f docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
git commit -m "feat(island): sync audit"
```

Expected: commit contains only the final runtime audit note. If Step 7 adds a new Task 27 instead of a PASS table, do not mark Task 14 or the overall goal complete.

### Task 27: 补齐 runtime audit 聚焦与 resolve 后回流证据

**Files:**
- Modify: `Argo/Support/IslandSessionState.swift`
- Modify: `Argo/UI/Island/IslandSessionSections.swift`
- Modify: `Tests/IslandSessionStateTests.swift`
- Modify: `Tests/IslandUISourceTests.swift`
- Modify: `docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md`

**Interfaces:**
- Consumes:
  - Target Debug binary: `/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo`.
  - Main pane ID: `37d97222-9ac6-4905-857d-45e492be947a`.
  - Secondary pane ID: `ff651f49-a639-4c59-ac23-9d73607e383c`.
  - Existing runtime smoke evidence under `/tmp/argo-island-smoke-real-pane`.
  - Passing focused tests from Task 26 Step 7.
- Produces:
  - Direct runtime evidence for Task 14 Step 3 item 17: clicking a rendered session focuses the correct workspace/worktree/pane.
  - Direct runtime evidence for Task 14 Step 3 item 18: resolving an actionable card returns to the Sessions list when appropriate.
  - A final Task 14 Step 3 audit note only after all 18 lines have concrete `PASS` evidence.

Additional implementation result on 2026-06-22:

```text
During the item 18 runtime audit, the resolved approval session briefly remained visually keyed as the old actionable row. The root cause was a stale approval payload on a session that was already back to .running, plus SwiftUI row reuse across phase changes. TDD fixes:
- IslandSessionState.apply(.actionableStateResolved) now clears stale permission/question payloads when a session is .running but still carries actionable data.
- IslandSessionSectionsView keys rows by "session.id:session.phase.rawValue" so the resolved row is rebuilt when approval/question state becomes running.
Evidence: IslandSessionStateTests/testActionableResolutionClearsStaleApprovalPayloadEvenAfterSessionIsRunning and IslandUISourceTests/testSessionRowsUsePhaseAwareIdentity both failed before the fix and pass after it.
```

- [x] **Step 1: Confirm the target Debug app and panes are still the audit target**

Run:

```bash
DEBUG_BIN=/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
"$DEBUG_BIN" ping
```

Expected:

```text
/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
```

Run:

```bash
TOKEN=$(uuidgen)
defaults write com.krystal.argo com.krystal.argo.urlScheme.enabled -bool true
defaults write com.krystal.argo com.krystal.argo.urlScheme.token "$TOKEN"
"$DEBUG_BIN" session list --json --token "$TOKEN" > /tmp/argo-island-smoke-real-pane/task27-session-list-before.json
rg '37d97222|ff651f49' /tmp/argo-island-smoke-real-pane/task27-session-list-before.json
```

Expected:

```text
37d97222
ff651f49
```

Observed on 2026-06-22 after rebuilding and relaunching Debug Argo:

```text
/Users/liaojingyu/Library/Developer/Xcode/DerivedData/Argo-gyqenyyrfogymcgjptgrjdamesuo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo
PANE_A=9ef8e47c-b7fd-4559-9205-a6f622a80161
PANE_B=ce6c7fb7-0960-4ccb-9e86-5edba7a27521
WORKSPACE=5ab9056d-8ccb-4079-9805-9dde690eef36
```

Evidence:
- `/tmp/argo-island-smoke-real-pane/task27-clean-ping.out`
- `/tmp/argo-island-smoke-real-pane/task27-clean-session-list-after-split.json`
- `/tmp/argo-island-smoke-real-pane/task27-clean-panes.env`

- [x] **Step 2: Capture the pre-click expanded Sessions list**

Open the Dynamic Island expanded Sessions tab and capture:

```bash
screencapture -x /tmp/argo-island-smoke-real-pane/task27-focus-before.png
cp /tmp/argo-island-smoke-real-pane/task27-focus-before.png /tmp/argo-island-smoke-real-pane/task27-focus-before-top-crop.png
sips -c 900 1400 --cropOffset 0 812 /tmp/argo-island-smoke-real-pane/task27-focus-before-top-crop.png
```

Expected visual result:

```text
task27-focus-before-top-crop.png shows both 37d97222 and ff651f49 in the Sessions list.
```

Observed on 2026-06-22:

```text
/tmp/argo-island-smoke-real-pane/task27-final-focus-list-before-click.png shows the Sessions tab with rows tagged ce6c7fb7 and 9ef8e47c.
```

- [x] **Step 3: Click the secondary pane session and prove focus switched**

Click the row tagged `ff651f49` in the expanded Sessions list. Then run:

```bash
"$DEBUG_BIN" send-keys \
  --pane ff651f49-a639-4c59-ac23-9d73607e383c \
  --text "printf 'task27-focus-pane-b-ok' > /tmp/argo-island-smoke-real-pane/task27-focus-pane-b.txt\n" \
  --token "$TOKEN"
for attempt in {1..20}; do
  [[ -f /tmp/argo-island-smoke-real-pane/task27-focus-pane-b.txt ]] && cat /tmp/argo-island-smoke-real-pane/task27-focus-pane-b.txt && break
  sleep 0.25
done
screencapture -x /tmp/argo-island-smoke-real-pane/task27-focus-after.png
```

Expected:

```text
task27-focus-pane-b-ok
```

Expected visual result:

```text
task27-focus-after.png shows the active Argo window focused on the workspace/worktree containing pane ff651f49.
```

Observed on 2026-06-22:

```text
task27-final-click-focus-b-ok
```

Evidence:
- `/tmp/argo-island-smoke-real-pane/task27-final-focus-list-before-click.png` shows the rendered row tagged `ce6c7fb7`.
- `/tmp/argo-island-smoke-real-pane/task27-final-raw-nopane-after-click-b.out` returned `{"ok":true}` for a raw no-pane control send after the row click.
- `/tmp/argo-island-smoke-real-pane/task27-final-click-focus-b-marker.txt` contains `task27-final-click-focus-b-ok`.
- `/tmp/argo-island-smoke-real-pane/task27-final-display2-after-click-focus-b.png` shows the no-pane command output `TASK27_FINAL_NO_PANE_AFTER_CLICK_B` in the terminal pane labeled `TASK27_LABEL_PANE_B`, while pane A contains the prior `TASK27_FINAL_BASELINE_FOCUS_A` baseline.

- [x] **Step 4: Resolve an actionable card and capture the Sessions list return**

From the focused pane, create a fresh approval card:

```bash
RESOLVE_MARKER=/tmp/argo-island-smoke-real-pane/task27-resolve-marker.txt
"$DEBUG_BIN" notify \
  --approval \
  --title "Task 27 resolve audit" \
  --body "Return to Sessions after action" \
  --pane ff651f49-a639-4c59-ac23-9d73607e383c \
  --session "task27-resolve-audit" \
  --source "task27-resolve-audit" \
  --tool Codex \
  --current-tool exec_command \
  --command-preview "resolve audit" \
  --affected-path "/Users/liaojingyu/argo" \
  --option "Allow=printf 'task27-resolve-ok' > '$RESOLVE_MARKER'\n" \
  --option "Deny=printf 'task27-resolve-deny' > '$RESOLVE_MARKER'\n"
```

Click `显示全部` if the notification card is open, then click `Allow`. Run:

```bash
for attempt in {1..20}; do
  [[ -f "$RESOLVE_MARKER" ]] && cat "$RESOLVE_MARKER" && break
  sleep 0.25
done
screencapture -x /tmp/argo-island-smoke-real-pane/task27-resolve-after.png
cp /tmp/argo-island-smoke-real-pane/task27-resolve-after.png /tmp/argo-island-smoke-real-pane/task27-resolve-after-top-crop.png
sips -c 900 1400 --cropOffset 0 812 /tmp/argo-island-smoke-real-pane/task27-resolve-after-top-crop.png
```

Expected:

```text
task27-resolve-ok
```

Expected visual result:

```text
task27-resolve-after-top-crop.png shows the Sessions tab rather than the resolved single notification card, and the resolved session no longer appears under 需要审批.
```

Observed on 2026-06-22:

```text
task27-resolve-final-ok
```

Evidence:
- `/tmp/argo-island-smoke-real-pane/task27-resolve-final-card-display1.png` shows the approval card for `Task 27 resolve final`.
- `/tmp/argo-island-smoke-real-pane/task27-resolve-final-marker.txt` contains `task27-resolve-final-ok`.
- `/tmp/argo-island-smoke-real-pane/task27-final-sessions-list-display1.png` shows the Sessions tab after resolution. The resolved `Bash resolve final` row is back in running state and no stale `Allow`/`Deny` controls remain.

- [x] **Step 5: Record the final Task 14 audit note and commit it**

Only after Steps 1-4 pass, add the final Task 14 Step 3 audit note with all 18 lines marked `PASS`. Then run:

```bash
git diff --check
git add -f docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
git commit -m "feat(island): sync audit"
```

Expected:

```text
git diff --check -> no output
commit contains only docs/superpowers/plans/2026-06-22-dynamic-island-open-vibe-parity.md
default.profraw remains unstaged
```

## Self-Review

- Spec coverage: tasks cover model/event migration, reducer, presentation, approval command/path context, approval multi-action preservation, pending approval/question preservation across repeated running `sessionStarted` events, smoke coverage for approval multi-action write-back, stale completed folding, closed agents grid, rich notify protocol, affected path transport, app data flow, surface/card behavior, response dispatcher, collapsed UI, expanded UI, localization, workspace status messages as ephemeral session events, session-only UI cleanup, focused tests, full tests, repeatable runtime smoke, stale Debug-process smoke guard, target Debug-process smoke guard, process-tree-aware smoke guard for new/old Debug app coexistence, unauthenticated control-socket owner ping, retained control dispatcher lifetime, shared pane write-back routing, Ghostty key-event programmatic input, static open-vibe parity audit, deterministic marker-file action write-back audit, runtime smoke unblock procedure, final parity audit, runtime focus proof, post-resolution Sessions return proof, and follow-up task creation rules for any runtime audit failure.
- Placeholder scan: plan avoids placeholder markers and every task includes concrete file paths, command lines, expected outcomes, interfaces, and implementation snippets.
- Type consistency: the plan consistently uses `IslandAgentSession`, `IslandSessionEvent`, `IslandSessionState`, `IslandSurface`, `IslandRightSlotContent`, `IslandPermissionAction`, `IslandSessionSectionsView.sections(for:referenceDate:)`, `IslandResponseDispatcher.respond(toSessionID:with:)`, `TerminalSurfaceController.sendProgrammaticText(_:)`, `ShellSession.insertProgrammaticText(_:)`, `WorkspaceSessionController.sendProgrammaticText(_:to:)`, `ArgoControlCommand.ping`, `ArgoControlResponse.executablePath`, `ArgoControlCLI.runPing(arguments:send:stdoutWriter:stderrWriter:)`, and `AgentNotifyControlServer`.
