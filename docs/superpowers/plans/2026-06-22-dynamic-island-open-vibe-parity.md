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
- Modify: `Argo/Support/L10n.swift`
  - 增加 session 分组、approval/question、Show All、错误和操作文案。
- Test: `Tests/IslandSessionStateTests.swift`
- Test: `Tests/IslandSessionPresentationTests.swift`
- Test: `Tests/IslandSurfaceTests.swift`
- Test: `Tests/IslandClosedAgentsGridTests.swift`
- Test: `Tests/IslandRichNotifyProtocolTests.swift`
- Modify tests: `Tests/AgentNotifyCLITests.swift`, `Tests/AgentNotifyProtocolTests.swift`, `Tests/IslandResponseDispatcherTests.swift`, `Tests/IslandWorkspaceNavigatorTests.swift`, `Tests/IslandSessionCenterTests.swift`

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

- [ ] **Step 1: Write the failing reducer tests**

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

- [ ] **Step 2: Run tests to verify they fail**

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

- [ ] **Step 3: Implement migrated models**

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

- [ ] **Step 4: Implement event payloads**

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

- [ ] **Step 5: Implement reducer**

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

- [ ] **Step 6: Run reducer tests to verify pass**

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

- [ ] **Step 7: Commit**

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

- [ ] **Step 1: Write failing presentation tests**

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

- [ ] **Step 2: Run tests to verify they fail**

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

- [ ] **Step 3: Implement presentation extension**

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

- [ ] **Step 4: Implement closed agents grid**

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

- [ ] **Step 5: Run presentation tests to verify pass**

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

- [ ] **Step 6: Commit**

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

- [ ] **Step 1: Write failing rich protocol tests**

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

- [ ] **Step 2: Run tests to verify they fail**

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

- [ ] **Step 3: Extend protocol models**

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

- [ ] **Step 4: Extend CLI parser**

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

- [ ] **Step 5: Implement facade event posting**

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

- [ ] **Step 6: Run protocol and facade tests**

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

- [ ] **Step 7: Commit**

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

- [ ] **Step 1: Write failing surface tests**

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

- [ ] **Step 2: Run tests to verify fail**

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

- [ ] **Step 3: Implement surface**

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

- [ ] **Step 4: Update dispatcher**

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

- [ ] **Step 5: Route rich notify to events**

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

- [ ] **Step 6: Update panel controller surface entry**

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

- [ ] **Step 7: Run surface/data-flow tests**

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

- [ ] **Step 8: Commit**

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

- [ ] **Step 1: Write failing source-level UI tests**

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

- [ ] **Step 2: Run UI source tests to verify fail**

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

- [ ] **Step 3: Implement session row**

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

- [ ] **Step 4: Implement session sections view**

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

- [ ] **Step 5: Update collapsed view**

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

- [ ] **Step 6: Update expanded sessions tab**

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

- [ ] **Step 7: Add localization keys**

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

- [ ] **Step 8: Run UI source tests**

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

- [ ] **Step 9: Commit**

```bash
git add Argo/UI/Island/IslandSessionRow.swift Argo/UI/Island/IslandSessionSections.swift Argo/UI/Island/IslandCollapsedView.swift Argo/UI/Island/IslandExpandedView.swift Argo/UI/Island/IslandContentView.swift Argo/Support/L10n.swift Tests/IslandUISourceTests.swift
git commit -m "feat(island): add session ui"
```

### Task 6: 集成验证与文档收口

**Files:**
- Modify: `docs/superpowers/specs/2026-06-22-dynamic-island-open-vibe-parity-design.md` only if implementation discovers necessary clarifications
- Test: all island and notify tests

**Interfaces:**
- Consumes all prior tasks.
- Produces a verified implementation branch ready for review.

- [ ] **Step 1: Run focused test suite**

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
  -only-testing:ArgoTests/IslandRichNotifyProtocolTests \
  -only-testing:ArgoTests/IslandResponseDispatcherTests \
  -only-testing:ArgoTests/IslandWorkspaceNavigatorTests \
  -only-testing:ArgoTests/IslandSessionCenterTests \
  -only-testing:ArgoTests/AgentNotifyCLITests \
  -only-testing:ArgoTests/AgentNotifyProtocolTests \
  test
```

Expected: PASS for all listed tests.

- [ ] **Step 2: Run full app test suite**

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
7. Run `argo notify --approval --title "Approve command" --body "Run tests?" --option "Allow=1\n" --option "Deny=2\n"` from pane A.
8. Confirm notification card appears and Sessions retains the approval record.
9. Click Allow and confirm text is inserted into pane A.
10. Run `argo notify --question --title "Deploy target" --body "Which target?" --option "Production=Production\n" --option "Staging=Staging\n"` from pane B.
11. Click Staging and confirm text is inserted into pane B.
12. Trigger completed and failed notifications and confirm Just Done ordering and error display.
13. Click sessions from the expanded list and confirm Argo focuses the correct workspace/worktree/pane.
```

Expected: all checklist items pass. Record any failed item in the final implementation summary.

- [ ] **Step 4: Commit verification-only doc clarification if needed**

Only if the implementation changed a design decision, update the spec with the exact resolved decision and commit:

```bash
git add docs/superpowers/specs/2026-06-22-dynamic-island-open-vibe-parity-design.md
git commit -m "feat(island): sync spec"
```

If no spec clarification is needed, do not create this commit.

## Self-Review

- Spec coverage: tasks cover model/event migration, reducer, presentation, closed agents grid, rich notify protocol, app data flow, surface/card behavior, response dispatcher, collapsed UI, expanded UI, localization, focused tests, full tests, and manual smoke.
- Placeholder scan: plan avoids placeholder markers and every task includes concrete file paths, command lines, expected outcomes, interfaces, and implementation snippets.
- Type consistency: the plan consistently uses `IslandAgentSession`, `IslandSessionEvent`, `IslandSessionState`, `IslandSurface`, `IslandRightSlotContent`, and `IslandResponseDispatcher.respond(toSessionID:with:)`.
