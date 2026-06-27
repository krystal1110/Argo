# Argo Agent 控制协议 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补齐 `argo status`、`argo read`、`argo agents`，并扩展 `argo session list`，让 Argo 具备可被本机脚本、agent 和后续 HAPI 远端入口复用的 agent host 控制面。

**Architecture:** 在现有 `AgentNotifyServer` JSON-line Unix socket 控制面上扩展协议，不新增网络服务。协议模型和 CLI 解析放在 `Argo/Services/AgentNotify`，读屏通过现有 `TerminalSurfaceController` 抽象暴露，app host 从 `ArgoDesktopApplication` 聚合 workspace/session 状态。

**Tech Stack:** Swift、XCTest、AppKit main actor、GhosttyKit、Darwin `sysctl`、现有 `agent-notify.sock` Unix domain socket。

## Global Constraints

- 面向协作的说明和计划使用简体中文；代码、标识符、命令、测试名保持英文。
- 不 vendoring HAPI 源码。
- mutating 命令 `open`、`split`、`send-keys` 继续要求 `ARGO_CONTROL_TOKEN`。
- `notify`、`ping`、`status`、`session-list`、`read`、`agents` 不要求 token。
- 非 Ghostty surface 可以返回 `read-unavailable`；不要模拟读屏。
- 保持 `ArgoControlProtocol` wire 兼容：JSON key 稳定，未知字段继续忽略。
- 保留现有未跟踪文件 `default.profraw`，不要 stage 或删除。

---

## 文件结构

- `Argo/Services/AgentNotify/ArgoControlProtocol.swift`
  - 承载 wire model：`AgentReportedState`、`ArgoStatusRequest`、`ArgoReadRequest`、`ArgoAgentsRequest`、`ArgoAgentInfo`，以及扩展后的 response/session 字段。
- `Argo/Services/AgentNotify/AgentStatusStore.swift`
  - 新增按 pane UUID 索引的内存状态表，记录 `argo status` 最近上报。
- `Argo/Services/AgentNotify/ArgoControlCLI.swift`
  - 新增 CLI 参数解析；`read --wait-stable` 的轮询也放在 CLI 侧。
- `Argo/Services/AgentNotify/ArgoControlDispatcher.swift`
  - 负责鉴权分流和命令路由。
- `Argo/main.swift`
  - 新增顶层 `status`、`read`、`agents` 子命令路由。
- `Argo/App/ArgoDesktopApplication.swift`
  - 新增 `routeAgentStatus`，与现有 `routeAgentNotification` 保持同样的 pane/workspace 定位规则。
- `Argo/App/ArgoDesktopApplication+ControlHost.swift`
  - 实现 `handleStatus`、`handleRead`、`handleAgents`，并扩展 `handleSessionList`。
- `Argo/Domain/WorkspaceRuntime.swift`
  - 新增 `postAgentStatus`，关闭 pane 时清理 `AgentStatusStore`。
- `Argo/Services/Terminal/TerminalSurface.swift`
  - 给 `TerminalSurfaceController` 增加默认 `readScreenText(scrollback:)`。
- `Argo/Services/Terminal/ShellSession.swift`
  - 暴露 `readScreenText(scrollback:)` 转发方法。
- `Argo/Services/Terminal/Ghostty/ArgoGhosttyController.swift`
  - 使用 Ghostty 的 `ghostty_surface_read_text` 实现真实读屏。
- `Argo/Services/Process/AgentProcessDetector.swift`
  - 新增基于 argv 的被动 agent 进程识别。
- Tests:
  - `Tests/ArgoControlCLITests.swift`
  - `Tests/ArgoControlDispatcherTests.swift`
  - `Tests/AgentStatusStoreTests.swift`
  - `Tests/AgentProcessDetectorTests.swift`
  - `Tests/ShellSessionTests.swift`
  - `Tests/WorkspaceSessionControllerTests.swift`

---

### Task 1: 协议模型与状态表

**Files:**
- Modify: `Argo/Services/AgentNotify/ArgoControlProtocol.swift`
- Create: `Argo/Services/AgentNotify/AgentStatusStore.swift`
- Test: `Tests/AgentStatusStoreTests.swift`

**Interfaces:**
- Produces: `AgentReportedState`
- Produces: `ArgoStatusRequest`
- Produces: `ArgoReadRequest`
- Produces: `ArgoAgentsRequest`
- Produces: `ArgoAgentInfo`
- Produces: `AgentStatusStore.shared.update(pane:state:title:agentName:)`
- Produces: `AgentStatusStore.shared.state(for:)`
- Produces: `AgentStatusStore.shared.clear(pane:)`
- Produces: `AgentStatusStore.shared.clearAll()`
- Produces: `ArgoControlCommand.requiresControlToken`

- [ ] **Step 1: 写失败测试**

新增 `Tests/AgentStatusStoreTests.swift`：

```swift
import XCTest
@testable import Argo

@MainActor
final class AgentStatusStoreTests: XCTestCase {
    override func tearDown() {
        AgentStatusStore.shared.clearAll()
        super.tearDown()
    }

    func testReportedStateParsesSynonyms() {
        XCTAssertEqual(AgentReportedState(cliValue: "working"), .running)
        XCTAssertEqual(AgentReportedState(cliValue: "needs-input"), .waiting)
        XCTAssertEqual(AgentReportedState(cliValue: "success"), .done)
        XCTAssertEqual(AgentReportedState(cliValue: "failed"), .error)
        XCTAssertNil(AgentReportedState(cliValue: "sleeping"))
    }

    func testStoreUpdateStateAndClear() {
        let pane = UUID()
        AgentStatusStore.shared.update(
            pane: pane,
            state: .waiting,
            title: "Approve command",
            agentName: "Codex"
        )

        XCTAssertEqual(AgentStatusStore.shared.state(for: pane), .waiting)
        XCTAssertEqual(AgentStatusStore.shared.entries[pane]?.title, "Approve command")
        XCTAssertEqual(AgentStatusStore.shared.entries[pane]?.agentName, "Codex")

        AgentStatusStore.shared.clear(pane: pane)
        XCTAssertNil(AgentStatusStore.shared.state(for: pane))
    }

    func testControlTokenRulesKeepMutatingCommandsProtected() {
        XCTAssertFalse(ArgoControlCommand.notify.requiresControlToken)
        XCTAssertFalse(ArgoControlCommand.ping.requiresControlToken)
        XCTAssertFalse(ArgoControlCommand.status.requiresControlToken)
        XCTAssertFalse(ArgoControlCommand.sessionList.requiresControlToken)
        XCTAssertFalse(ArgoControlCommand.read.requiresControlToken)
        XCTAssertFalse(ArgoControlCommand.agents.requiresControlToken)
        XCTAssertTrue(ArgoControlCommand.open.requiresControlToken)
        XCTAssertTrue(ArgoControlCommand.split.requiresControlToken)
        XCTAssertTrue(ArgoControlCommand.sendKeys.requiresControlToken)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/AgentStatusStoreTests test
```

Expected: FAIL，原因是 `AgentStatusStore`、`AgentReportedState` 和新增 command cases 尚不存在。

- [ ] **Step 3: 实现协议模型**

在 `ArgoControlProtocol.swift` 中扩展 `ArgoControlCommand`：

```swift
nonisolated enum ArgoControlCommand: String, Codable {
    case notify
    case ping
    case status
    case open
    case split
    case sendKeys = "send-keys"
    case sessionList = "session-list"
    case read
    case agents
    case claudeHook = "claude-hook"

    var requiresControlToken: Bool {
        switch self {
        case .notify, .ping, .status, .sessionList, .read, .agents, .claudeHook:
            return false
        case .open, .split, .sendKeys:
            return true
        }
    }
}
```

在同文件新增：

```swift
enum AgentReportedState: String, Codable, Equatable {
    case running
    case waiting
    case done
    case error

    var islandStatus: IslandSessionStatus {
        switch self {
        case .running: return .running
        case .waiting: return .waitingForInput
        case .done: return .done
        case .error: return .error
        }
    }

    init?(cliValue raw: String) {
        switch raw.lowercased() {
        case "running", "busy", "working", "start", "started":
            self = .running
        case "waiting", "wait", "blocked", "input", "needs-input":
            self = .waiting
        case "done", "complete", "completed", "finished", "success", "ok":
            self = .done
        case "error", "failed", "fail":
            self = .error
        default:
            return nil
        }
    }
}

struct ArgoStatusRequest: Decodable {
    var state: String
    var pane: String?
    var title: String?
    var agentName: String?

    enum CodingKeys: String, CodingKey {
        case state
        case pane
        case title
        case agentName = "agent"
    }
}

struct ArgoReadRequest: Decodable {
    var pane: String?
    var lines: Int?
    var scrollback: Bool?
}

struct ArgoAgentsRequest: Decodable {}

struct ArgoAgentInfo: Codable, Equatable {
    var workspaceID: String
    var workspaceName: String
    var paneID: String
    var type: String?
    var name: String?
    var status: String
    var reported: Bool
    var cwd: String
    var branch: String?
    var focused: Bool

    enum CodingKeys: String, CodingKey {
        case workspaceID = "workspace"
        case workspaceName
        case paneID = "pane"
        case type
        case name
        case status
        case reported
        case cwd
        case branch
        case focused
    }
}
```

扩展 session/response：

```swift
struct ArgoControlSession: Codable, Equatable {
    var workspaceID: String
    var workspaceName: String
    var paneID: String
    var cwd: String
    var branch: String?
    var listeningPorts: [Int]
    var status: String? = nil

    enum CodingKeys: String, CodingKey {
        case workspaceID = "workspace"
        case workspaceName
        case paneID = "pane"
        case cwd
        case branch
        case listeningPorts = "ports"
        case status
    }
}

struct ArgoControlResponse: Codable, Equatable {
    var ok: Bool
    var error: String? = nil
    var sessions: [ArgoControlSession]? = nil
    var text: String? = nil
    var lineCount: Int? = nil
    var agents: [ArgoAgentInfo]? = nil
    var executablePath: String? = nil

    static let success = ArgoControlResponse(ok: true)

    static func failure(_ message: String) -> ArgoControlResponse {
        ArgoControlResponse(ok: false, error: message)
    }
}
```

- [ ] **Step 4: 新增状态表**

创建 `Argo/Services/AgentNotify/AgentStatusStore.swift`：

```swift
import Foundation

@MainActor
final class AgentStatusStore {
    static let shared = AgentStatusStore()

    struct Entry: Equatable {
        var state: AgentReportedState
        var title: String?
        var agentName: String?
        var updatedAt: Date
    }

    private(set) var entries: [UUID: Entry] = [:]

    private let now: () -> Date

    init(now: @escaping () -> Date = { Date() }) {
        self.now = now
    }

    func update(pane: UUID, state: AgentReportedState, title: String?, agentName: String? = nil) {
        entries[pane] = Entry(state: state, title: title, agentName: agentName, updatedAt: now())
    }

    func state(for pane: UUID) -> AgentReportedState? {
        entries[pane]?.state
    }

    func clear(pane: UUID) {
        entries[pane] = nil
    }

    func clearAll() {
        entries.removeAll()
    }
}
```

- [ ] **Step 5: 运行测试确认通过**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/AgentStatusStoreTests test
```

Expected: PASS。

- [ ] **Step 6: 提交**

```sh
git add Argo/Services/AgentNotify/ArgoControlProtocol.swift Argo/Services/AgentNotify/AgentStatusStore.swift Tests/AgentStatusStoreTests.swift
git commit -m "feat(agent): add states"
```

---

### Task 2: CLI 子命令

**Files:**
- Modify: `Argo/Services/AgentNotify/ArgoControlCLI.swift`
- Modify: `Argo/main.swift`
- Test: `Tests/ArgoControlCLITests.swift`

**Interfaces:**
- Consumes: `AgentReportedState`
- Consumes: `ArgoControlResponse.text`
- Consumes: `ArgoControlResponse.agents`
- Produces: `ArgoControlCLI.runStatus`
- Produces: `ArgoControlCLI.runRead`
- Produces: `ArgoControlCLI.runAgents`

- [ ] **Step 1: 写失败测试**

在 `Tests/ArgoControlCLITests.swift` 中增加：

```swift
func testStatusEncodesFrameWithoutTokenAndUsesEnvPane() throws {
    let captured = FrameCollector()
    let exit = ArgoControlCLI.runStatus(
        arguments: ["needs-input", "--title", "Approve command", "--agent", "Codex"],
        send: captured.capture,
        environment: [ArgoAgentNotifyEnvironment.paneIDKey: "pane-from-env"],
        stdoutWriter: { _ in },
        stderrWriter: { _ in }
    )
    XCTAssertEqual(exit, .ok)
    let json = try captured.decodedJSON()
    XCTAssertEqual(json["cmd"] as? String, "status")
    XCTAssertEqual(json["state"] as? String, "waiting")
    XCTAssertEqual(json["pane"] as? String, "pane-from-env")
    XCTAssertEqual(json["title"] as? String, "Approve command")
    XCTAssertEqual(json["agent"] as? String, "Codex")
    XCTAssertNil(json["token"])
}

func testReadEncodesFrameWithoutToken() throws {
    let captured = FrameCollector(response: ArgoControlResponse(ok: true, text: "hello\n", lineCount: 1))
    let exit = ArgoControlCLI.runRead(
        arguments: ["--pane", "p1", "--last", "40", "--scrollback"],
        send: captured.capture,
        environment: [:],
        stdoutWriter: { _ in },
        stderrWriter: { _ in }
    )
    XCTAssertEqual(exit, .ok)
    let json = try captured.decodedJSON()
    XCTAssertEqual(json["cmd"] as? String, "read")
    XCTAssertEqual(json["pane"] as? String, "p1")
    XCTAssertEqual(json["lines"] as? Int, 40)
    XCTAssertEqual(json["scrollback"] as? Bool, true)
    XCTAssertNil(json["token"])
}

func testReadWaitStablePollsUntilTextRepeats() {
    var calls = 0
    let exit = ArgoControlCLI.runRead(
        arguments: ["--wait-stable"],
        send: { _ in
            defer { calls += 1 }
            return ArgoControlResponse(ok: true, text: calls < 2 ? "a" : "ab", lineCount: 1)
        },
        environment: [:],
        stdoutWriter: { _ in },
        stderrWriter: { _ in },
        sleeper: { _ in }
    )
    XCTAssertEqual(exit, .ok)
    XCTAssertEqual(calls, 3)
}

func testAgentsPrintsJSON() throws {
    let stdout = StreamCollector()
    let agents = [
        ArgoAgentInfo(
            workspaceID: "w",
            workspaceName: "demo",
            paneID: "p",
            type: "codex",
            name: "Codex",
            status: "running",
            reported: false,
            cwd: "/tmp",
            branch: "main",
            focused: true
        )
    ]
    let exit = ArgoControlCLI.runAgents(
        arguments: ["--json"],
        send: { _ in ArgoControlResponse(ok: true, agents: agents) },
        environment: [:],
        stdoutWriter: stdout.write,
        stderrWriter: { _ in }
    )
    XCTAssertEqual(exit, .ok)
    let data = Data(stdout.text.utf8)
    let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    XCTAssertEqual(parsed?.first?["type"] as? String, "codex")
}

func testSessionListNoLongerRequiresTokenAndPrintsStatus() {
    let stdout = StreamCollector()
    let exit = ArgoControlCLI.runSessionList(
        arguments: [],
        send: { _ in
            ArgoControlResponse(ok: true, sessions: [
                ArgoControlSession(
                    workspaceID: "w1",
                    workspaceName: "demo",
                    paneID: "p-1",
                    cwd: "/tmp/x",
                    branch: "main",
                    listeningPorts: [],
                    status: "waiting"
                )
            ])
        },
        environment: [:],
        stdoutWriter: stdout.write,
        stderrWriter: { _ in }
    )
    XCTAssertEqual(exit, .ok)
    XCTAssertTrue(stdout.text.contains("demo [main] <waiting> p-1 /tmp/x"))
}
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/ArgoControlCLITests test
```

Expected: FAIL，原因是新 CLI 函数尚不存在。

- [ ] **Step 3: 实现 CLI**

在 `ArgoControlCLI.swift` 中增加 `usageStatus`、`usageRead`、`usageAgents`，并实现 `runStatus`、`runRead`、`runAgents`。

`runStatus` 的 frame 形状：

```swift
let frame = encodeFrame(cmd: "status", token: nil, payload: [
    "state": normalized.rawValue,
    "pane": resolvedPane as Any?,
    "title": title as Any?,
    "agent": agent as Any?,
])
```

`runRead` 的 frame 形状：

```swift
let frame = encodeFrame(cmd: "read", token: resolvedToken, payload: [
    "pane": resolvedPane as Any?,
    "lines": lastLines as Any?,
    "scrollback": scrollback ? true : nil as Any?,
])
```

`runRead --wait-stable` 轮询规则：

```swift
var previous = response?.text
var attempts = 0
let maxAttempts = 25
while attempts < maxAttempts {
    sleeper(200_000)
    let next = try readOnce()
    if next?.text == previous {
        response = next
        break
    }
    previous = next?.text
    response = next
    attempts += 1
}
```

`runAgents` 的 frame 形状：

```swift
let frame = encodeFrame(cmd: "agents", token: resolvedToken, payload: [:])
```

更新 `runSessionList`：不再要求 token；human 输出加入 status：

```swift
let statusText = session.status.map { " <\($0)>" } ?? ""
stdoutWriter("\(session.workspaceName)\(branchText)\(statusText) \(session.paneID) \(session.cwd)\(portText)")
```

- [ ] **Step 4: 更新 `main.swift` 路由**

新增：

```swift
case "status":
    exit(ArgoControlCLI.runStatus(arguments: rest).rawValue)
case "read":
    exit(ArgoControlCLI.runRead(arguments: rest).rawValue)
case "agents":
    exit(ArgoControlCLI.runAgents(arguments: rest).rawValue)
```

- [ ] **Step 5: 运行测试确认通过**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/ArgoControlCLITests test
```

Expected: PASS。

- [ ] **Step 6: 提交**

```sh
git add Argo/Services/AgentNotify/ArgoControlCLI.swift Argo/main.swift Tests/ArgoControlCLITests.swift
git commit -m "feat(agent): add cli"
```

---

### Task 3: Dispatcher 鉴权与路由

**Files:**
- Modify: `Argo/Services/AgentNotify/ArgoControlDispatcher.swift`
- Test: `Tests/ArgoControlDispatcherTests.swift`

**Interfaces:**
- Consumes: `ArgoStatusRequest`
- Consumes: `ArgoReadRequest`
- Consumes: `ArgoAgentsRequest`
- Produces: `ArgoControlHost.handleStatus`
- Produces: `ArgoControlHost.handleRead`
- Produces: `ArgoControlHost.handleAgents`

- [ ] **Step 1: 写失败测试**

在 `Tests/ArgoControlDispatcherTests.swift` 增加：

```swift
func testStatusRoutesWithoutTokenAndReturnsNoResponse() {
    dispatcher = ArgoControlDispatcher(host: host, tokenResolver: { nil })
    let frame = makeFrame(["cmd": "status", "state": "waiting", "pane": "p1", "title": "Needs approval"])
    let response = dispatcher.dispatch(frame: frame)
    XCTAssertNil(response)
    XCTAssertEqual(host.statusCalls.count, 1)
    XCTAssertEqual(host.statusCalls.first?.state, "waiting")
    XCTAssertEqual(host.statusCalls.first?.pane, "p1")
}

func testReadRoutesWithoutToken() throws {
    dispatcher = ArgoControlDispatcher(host: host, tokenResolver: { nil })
    let frame = makeFrame(["cmd": "read", "pane": "p1", "lines": 20, "scrollback": true])
    let response = try XCTUnwrap(dispatcher.dispatch(frame: frame))
    let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
    XCTAssertTrue(decoded.ok)
    XCTAssertEqual(host.readCalls.count, 1)
    XCTAssertEqual(host.readCalls.first?.pane, "p1")
    XCTAssertEqual(host.readCalls.first?.lines, 20)
    XCTAssertEqual(host.readCalls.first?.scrollback, true)
}

func testAgentsRoutesWithoutToken() throws {
    dispatcher = ArgoControlDispatcher(host: host, tokenResolver: { nil })
    let frame = makeFrame(["cmd": "agents"])
    let response = try XCTUnwrap(dispatcher.dispatch(frame: frame))
    let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
    XCTAssertTrue(decoded.ok)
    XCTAssertEqual(host.agentsCalls, 1)
}

func testMutatingCommandsStillRequireTokenAfterReadOnlyCommandsAdded() throws {
    dispatcher = ArgoControlDispatcher(host: host, tokenResolver: { "secret" })
    let frame = makeFrame(["cmd": "send-keys", "pane": "p1", "text": "ls\n"])
    let response = try XCTUnwrap(dispatcher.dispatch(frame: frame))
    let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
    XCTAssertEqual(decoded.error, "token-mismatch")
    XCTAssertTrue(host.sendKeysCalls.isEmpty)
}
```

扩展 `RecordingHost`：

```swift
var statusCalls: [ArgoStatusRequest] = []
var readCalls: [ArgoReadRequest] = []
var agentsCalls = 0

func handleStatus(_ request: ArgoStatusRequest) {
    statusCalls.append(request)
}

func handleRead(_ request: ArgoReadRequest) -> ArgoControlResponse {
    readCalls.append(request)
    return ArgoControlResponse(ok: true, text: "screen", lineCount: 1)
}

func handleAgents(_ request: ArgoAgentsRequest) -> ArgoControlResponse {
    agentsCalls += 1
    return ArgoControlResponse(ok: true, agents: [])
}
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/ArgoControlDispatcherTests test
```

Expected: FAIL。

- [ ] **Step 3: 实现 dispatcher**

更新 `ArgoControlHost`：

```swift
@MainActor
protocol ArgoControlHost: AnyObject {
    func handleNotify(_ request: AgentNotifyRequest)
    func handleStatus(_ request: ArgoStatusRequest)
    func handleOpen(_ request: ArgoOpenRequest) -> ArgoControlResponse
    func handleSplit(_ request: ArgoSplitRequest) -> ArgoControlResponse
    func handleSendKeys(_ request: ArgoSendKeysRequest) -> ArgoControlResponse
    func handleSessionList(_ request: ArgoSessionListRequest) -> ArgoControlResponse
    func handleRead(_ request: ArgoReadRequest) -> ArgoControlResponse
    func handleAgents(_ request: ArgoAgentsRequest) -> ArgoControlResponse
}
```

在 token gate 前加入 `status` fire-and-forget 分支：

```swift
if cmd == .status {
    if let request = try? JSONDecoder().decode(ArgoStatusRequest.self, from: trim(frame)) {
        host?.handleStatus(request)
    }
    return nil
}
```

将鉴权逻辑改为只保护 mutating command：

```swift
if cmd.requiresControlToken {
    guard let expected = tokenResolver(), !expected.isEmpty else {
        return ArgoControlEncoder.encodeResponse(.failure("control-disabled"))
    }
    guard let provided = envelope.token, provided == expected else {
        return ArgoControlEncoder.encodeResponse(.failure("token-mismatch"))
    }
}
```

新增 switch cases：

```swift
case .read:
    let req = (try? JSONDecoder().decode(ArgoReadRequest.self, from: trim(frame))) ?? ArgoReadRequest()
    response = host.handleRead(req)
case .agents:
    let req = (try? JSONDecoder().decode(ArgoAgentsRequest.self, from: trim(frame))) ?? ArgoAgentsRequest()
    response = host.handleAgents(req)
```

- [ ] **Step 4: 运行测试确认通过**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/ArgoControlDispatcherTests test
```

Expected: PASS。

- [ ] **Step 5: 提交**

```sh
git add Argo/Services/AgentNotify/ArgoControlDispatcher.swift Tests/ArgoControlDispatcherTests.swift
git commit -m "feat(agent): route ipc"
```

---

### Task 4: 终端读屏桥接

**Files:**
- Modify: `Argo/Services/Terminal/TerminalSurface.swift`
- Modify: `Argo/Services/Terminal/ShellSession.swift`
- Modify: `Argo/Services/Terminal/Ghostty/ArgoGhosttyController.swift`
- Test: `Tests/ShellSessionTests.swift`

**Interfaces:**
- Produces: `ShellSession.readScreenText(scrollback:) -> String?`
- Consumed by: `ArgoDesktopApplication.handleRead`

- [ ] **Step 1: 写失败测试**

在 `Tests/ShellSessionTests.swift` 中给现有 fake surface 增加 `screenText` 和 `readScrollbackFlags`，并新增测试：

```swift
func testReadScreenTextDelegatesToSurface() {
    let surface = RecordingManagedTerminalSurface()
    surface.screenText = "line 1\nline 2\n"
    let session = ShellSession(
        snapshot: PaneSnapshot.makeDefault(cwd: "/tmp"),
        surfaceController: surface
    )

    XCTAssertEqual(session.readScreenText(scrollback: false), "line 1\nline 2\n")
    XCTAssertEqual(surface.readScrollbackFlags, [false])
}
```

fake surface 增加：

```swift
var screenText: String?
var readScrollbackFlags: [Bool] = []

func readScreenText(scrollback: Bool) -> String? {
    readScrollbackFlags.append(scrollback)
    return screenText
}
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/ShellSessionTests/testReadScreenTextDelegatesToSurface test
```

Expected: FAIL。

- [ ] **Step 3: 增加读屏接口**

在 `TerminalSurface.swift` 中增加：

```swift
extension TerminalSurfaceController {
    func readScreenText(scrollback: Bool) -> String? { nil }
}
```

在 `ShellSession.swift` 中增加：

```swift
func readScreenText(scrollback: Bool) -> String? {
    surfaceController.readScreenText(scrollback: scrollback)
}
```

在 `ArgoGhosttyController.swift` 中增加：

```swift
func readScreenText(scrollback: Bool) -> String? {
    terminalView.currentScreenText(scrollback: scrollback)
}
```

在 `ArgoGhosttySurfaceView` 中增加：

```swift
func currentScreenText(scrollback: Bool) -> String? {
    guard let surface else { return nil }
    let tag = scrollback ? GHOSTTY_POINT_SCREEN : GHOSTTY_POINT_VIEWPORT
    let selection = ghostty_selection_s(
        top_left: ghostty_point_s(tag: tag, coord: GHOSTTY_POINT_COORD_TOP_LEFT, x: 0, y: 0),
        bottom_right: ghostty_point_s(tag: tag, coord: GHOSTTY_POINT_COORD_BOTTOM_RIGHT, x: 0, y: 0),
        rectangle: false
    )
    var text = ghostty_text_s()
    guard ghostty_surface_read_text(surface, selection, &text) else { return nil }
    defer { ghostty_surface_free_text(surface, &text) }
    guard let ptr = text.text, text.text_len > 0 else { return "" }
    let buffer = UnsafeRawBufferPointer(start: ptr, count: Int(text.text_len))
    return String(decoding: buffer, as: UTF8.self)
}
```

- [ ] **Step 4: 运行测试确认通过**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/ShellSessionTests/testReadScreenTextDelegatesToSurface test
```

Expected: PASS。

- [ ] **Step 5: 提交**

```sh
git add Argo/Services/Terminal/TerminalSurface.swift Argo/Services/Terminal/ShellSession.swift Argo/Services/Terminal/Ghostty/ArgoGhosttyController.swift Tests/ShellSessionTests.swift
git commit -m "feat(agent): read pane"
```

---

### Task 5: App host 的 status/read/session-list

**Files:**
- Modify: `Argo/App/ArgoDesktopApplication.swift`
- Modify: `Argo/App/ArgoDesktopApplication+ControlHost.swift`
- Modify: `Argo/Domain/WorkspaceRuntime.swift`
- Test: `Tests/ArgoControlDispatcherTests.swift`
- Test: `Tests/WorkspaceSessionControllerTests.swift`

**Interfaces:**
- Consumes: `AgentStatusStore`
- Consumes: `ShellSession.readScreenText(scrollback:)`
- Produces: `ArgoDesktopApplication.routeAgentStatus(state:paneID:title:agentName:)`
- Produces: `WorkspaceModel.postAgentStatus(state:title:paneID:agentName:)`
- Produces: `ArgoDesktopApplication.trimScreenText(_:lastLines:)`

- [ ] **Step 1: 写 trim 纯函数测试**

增加：

```swift
func testTrimScreenTextDropsTrailingBlankLinesAndKeepsLastLines() {
    let raw = "one\n\ntwo\nthree\n\n"
    let trimmed = ArgoDesktopApplication.trimScreenText(raw, lastLines: 2)
    XCTAssertEqual(trimmed, "two\nthree")
}
```

- [ ] **Step 2: 写 session list status 编码测试**

增加：

```swift
func testSessionListResponseIncludesStatus() throws {
    let session = ArgoControlSession(
        workspaceID: "w",
        workspaceName: "demo",
        paneID: "p",
        cwd: "/tmp",
        branch: nil,
        listeningPorts: [],
        status: "waiting"
    )
    let data = ArgoControlEncoder.encodeResponse(ArgoControlResponse(ok: true, sessions: [session]))
    let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let sessions = decoded?["sessions"] as? [[String: Any]]
    XCTAssertEqual(sessions?.first?["status"] as? String, "waiting")
}
```

- [ ] **Step 3: 运行测试确认失败**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/ArgoControlDispatcherTests test
```

Expected: FAIL。

- [ ] **Step 4: 实现 `status` 路由**

在 `ArgoDesktopApplication+ControlHost.swift` 中增加：

```swift
func handleStatus(_ request: ArgoStatusRequest) {
    let state = AgentReportedState(cliValue: request.state) ?? .running
    let paneID = request.pane.flatMap { UUID(uuidString: $0) }
    routeAgentStatus(
        state: state,
        paneID: paneID,
        title: request.title,
        agentName: request.agentName
    )
}
```

在 `ArgoDesktopApplication.swift` 中增加：

```swift
func routeAgentStatus(
    state: AgentReportedState,
    paneID: UUID?,
    title: String?,
    agentName: String?
) {
    if let paneID {
        for context in windowContexts {
            for workspace in context.store.workspaces
            where workspace.sessionController.session(for: paneID) != nil {
                workspace.postAgentStatus(state: state, title: title, paneID: paneID, agentName: agentName)
                return
            }
        }
    }

    if let workspace = activeWorkspaceStore?.selectedWorkspace {
        workspace.postAgentStatus(state: state, title: title, paneID: paneID, agentName: agentName)
    }
}
```

在 `WorkspaceRuntime.swift` 中增加：

```swift
func postAgentStatus(
    state: AgentReportedState,
    title: String?,
    paneID: UUID?,
    agentName: String?
) {
    if let paneID {
        AgentStatusStore.shared.update(pane: paneID, state: state, title: title, agentName: agentName)
    }

    let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedTitle = (trimmedTitle?.isEmpty == false) ? trimmedTitle! : Self.defaultStatusTitle(for: state)
    let item = IslandNotificationItem(
        id: UUID(),
        workspaceID: id,
        worktreePath: activeWorktreePath,
        paneID: paneID,
        sourceID: paneID.map { "pane:\($0.uuidString.lowercased())" },
        title: resolvedTitle,
        agentName: agentName,
        terminalTag: paneID.map(Self.shortPaneTag(for:)),
        status: state.islandStatus,
        startedAt: Date(),
        updatedAt: Date(),
        body: nil,
        prompt: nil,
        action: nil,
        lastError: nil
    )
    IslandNotificationState.shared.post(item: item)
    if state != .running {
        IslandPanelController.shared.show()
    }
}

private static func defaultStatusTitle(for state: AgentReportedState) -> String {
    switch state {
    case .running: return "Working..."
    case .waiting: return "Waiting for input"
    case .done: return "Done"
    case .error: return "Error"
    }
}
```

- [ ] **Step 5: 实现 `read` 和 `session list`**

在 `ArgoDesktopApplication+ControlHost.swift` 中增加：

```swift
func handleRead(_ request: ArgoReadRequest) -> ArgoControlResponse {
    let resolvedPane: UUID?
    if let paneIDString = request.pane, let paneID = UUID(uuidString: paneIDString) {
        resolvedPane = paneID
    } else {
        resolvedPane = activeWorkspaceStore?.selectedWorkspace?.sessionController.focusedPaneID
    }
    guard let resolvedPane else {
        return .failure("no-pane")
    }

    for store in allWorkspaceStores {
        for workspace in store.workspaces {
            guard let session = workspace.sessionController.session(for: resolvedPane) else { continue }
            guard let raw = session.readScreenText(scrollback: request.scrollback ?? false) else {
                return .failure("read-unavailable")
            }
            let text = Self.trimScreenText(raw, lastLines: request.lines)
            let lineCount = text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
            return ArgoControlResponse(ok: true, text: text, lineCount: lineCount)
        }
    }
    return .failure("pane-not-found")
}

static func trimScreenText(_ raw: String, lastLines: Int?) -> String {
    var lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
        lines.removeLast()
    }
    if let lastLines, lastLines > 0, lines.count > lastLines {
        lines = Array(lines.suffix(lastLines))
    }
    return lines.joined(separator: "\n")
}
```

扩展 `handleSessionList` 创建 session 时传入：

```swift
status: AgentStatusStore.shared.state(for: paneID)?.rawValue
```

- [ ] **Step 6: 关闭 pane 时清理状态**

在 `WorkspaceRuntime.closePane(_:)` 的开头加入：

```swift
AgentStatusStore.shared.clear(pane: paneID)
```

- [ ] **Step 7: 运行测试确认通过**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/ArgoControlDispatcherTests -only-testing:ArgoTests/WorkspaceSessionControllerTests test
```

Expected: PASS。

- [ ] **Step 8: 提交**

```sh
git add Argo/App/ArgoDesktopApplication.swift Argo/App/ArgoDesktopApplication+ControlHost.swift Argo/Domain/WorkspaceRuntime.swift Tests/ArgoControlDispatcherTests.swift Tests/WorkspaceSessionControllerTests.swift
git commit -m "feat(agent): host read"
```

---

### Task 6: Agent 进程识别与 `argo agents`

**Files:**
- Create: `Argo/Services/Process/AgentProcessDetector.swift`
- Modify: `Argo/App/ArgoDesktopApplication+ControlHost.swift`
- Test: `Tests/AgentProcessDetectorTests.swift`

**Interfaces:**
- Produces: `AgentProcessDetector.detect(rootPID:) -> AgentProcessDetector.Detected?`
- Consumes: `ProcessTree.descendants(of:)`
- Produces: `ArgoDesktopApplication.handleAgents(_:)`

- [ ] **Step 1: 写失败测试**

新增 `Tests/AgentProcessDetectorTests.swift`：

```swift
import XCTest
@testable import Argo

final class AgentProcessDetectorTests: XCTestCase {
    func testClassifiesNodeWrappedClaudeCode() {
        let hit = AgentProcessDetector.classify(
            execPath: "/opt/homebrew/bin/node",
            argv: ["node", "/Users/me/.npm/_npx/123/node_modules/@anthropic-ai/claude-code/cli.js"]
        )
        XCTAssertEqual(hit?.type, "claude-code")
        XCTAssertEqual(hit?.name, "Claude Code")
    }

    func testClassifiesCodexBinary() {
        let hit = AgentProcessDetector.classify(
            execPath: "/opt/homebrew/bin/codex",
            argv: ["codex", "resume", "--last"]
        )
        XCTAssertEqual(hit?.type, "codex")
    }

    func testDoesNotClassifyTrailingArgumentOrCwdLikePath() {
        let hit = AgentProcessDetector.classify(
            execPath: "/bin/zsh",
            argv: ["zsh", "-lc", "cd /tmp/codex-demo && npm test"]
        )
        XCTAssertNil(hit)
    }

    func testParseProcArgsReadsExecPathAndArgv() {
        var raw: [UInt8] = []
        var argc = Int32(2)
        withUnsafeBytes(of: &argc) { raw.append(contentsOf: $0) }
        raw.append(contentsOf: Array("/usr/bin/node".utf8))
        raw.append(0)
        raw.append(0)
        raw.append(contentsOf: Array("node".utf8))
        raw.append(0)
        raw.append(contentsOf: Array("/tmp/cli.js".utf8))
        raw.append(0)

        let parsed = AgentProcessDetector.parseProcArgs(raw)
        XCTAssertEqual(parsed?.execPath, "/usr/bin/node")
        XCTAssertEqual(parsed?.argv, ["node", "/tmp/cli.js"])
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/AgentProcessDetectorTests test
```

Expected: FAIL。

- [ ] **Step 3: 实现进程识别器**

创建 `Argo/Services/Process/AgentProcessDetector.swift`：

```swift
import Darwin
import Foundation

enum AgentProcessDetector {
    struct Detected: Equatable {
        let pid: pid_t
        let type: String
        let displayName: String
    }

    struct Definition {
        let type: String
        let name: String
        let tokens: [String]
    }

    static let definitions: [Definition] = [
        Definition(type: "claude-code", name: "Claude Code", tokens: ["claude", "claude-code"]),
        Definition(type: "codex", name: "Codex", tokens: ["codex", "codex-cli"]),
        Definition(type: "aider", name: "Aider", tokens: ["aider"]),
        Definition(type: "gemini", name: "Gemini CLI", tokens: ["gemini-cli", "gemini"]),
        Definition(type: "opencode", name: "OpenCode", tokens: ["opencode"]),
        Definition(type: "cursor-agent", name: "Cursor Agent", tokens: ["cursor-agent"]),
        Definition(type: "qwen-code", name: "Qwen Code", tokens: ["qwen-code", "qwen"]),
        Definition(type: "goose", name: "Goose", tokens: ["goose"]),
        Definition(type: "crush", name: "Crush", tokens: ["crush"]),
        Definition(type: "cline", name: "Cline", tokens: ["cline"]),
        Definition(type: "amp", name: "Amp", tokens: ["amp"]),
    ]

    static func detect(rootPID: pid_t, argsProvider: (pid_t) -> [UInt8]? = procArgsRaw(pid:)) -> Detected? {
        var pids = [rootPID]
        pids.append(contentsOf: ProcessTree.descendants(of: rootPID))
        for pid in pids {
            guard let raw = argsProvider(pid), let parsed = parseProcArgs(raw) else { continue }
            if let hit = classify(execPath: parsed.execPath, argv: parsed.argv) {
                return Detected(pid: pid, type: hit.type, displayName: hit.name)
            }
        }
        return nil
    }

    static func classify(execPath: String, argv: [String]) -> (type: String, name: String)? {
        var candidates = Set<String>()
        addComponents(of: execPath, to: &candidates)
        if let first = argv.first { addComponents(of: first, to: &candidates) }
        if argv.count >= 2 { addComponents(of: argv[1], to: &candidates) }
        for definition in definitions {
            for token in definition.tokens where candidates.contains(token) {
                return (definition.type, definition.name)
            }
        }
        return nil
    }

    private static func addComponents(of path: String, to set: inout Set<String>) {
        let lower = path.lowercased()
        set.insert((lower as NSString).lastPathComponent)
        for component in lower.split(separator: "/") where !component.isEmpty {
            set.insert(String(component))
        }
    }

    static func parseProcArgs(_ data: [UInt8]) -> (execPath: String, argv: [String])? {
        guard data.count > 4 else { return nil }
        let argc = data.prefix(4).withUnsafeBytes { $0.load(as: Int32.self) }
        guard argc >= 0 else { return nil }
        var index = 4
        let execStart = index
        while index < data.count, data[index] != 0 { index += 1 }
        let execPath = String(decoding: data[execStart..<index], as: UTF8.self)
        while index < data.count, data[index] == 0 { index += 1 }
        var argv: [String] = []
        var read = 0
        while read < Int(argc), index < data.count {
            let start = index
            while index < data.count, data[index] != 0 { index += 1 }
            argv.append(String(decoding: data[start..<index], as: UTF8.self))
            while index < data.count, data[index] == 0 { index += 1 }
            read += 1
        }
        return (execPath, argv)
    }

    static func procArgsRaw(pid: pid_t) -> [UInt8]? {
        var argmax: Int = 0
        var argmaxSize = MemoryLayout<Int>.size
        var argmaxMib: [Int32] = [CTL_KERN, KERN_ARGMAX]
        guard sysctl(&argmaxMib, 2, &argmax, &argmaxSize, nil, 0) == 0, argmax > 0 else {
            return nil
        }
        var buffer = [UInt8](repeating: 0, count: argmax)
        var size = argmax
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
        return Array(buffer.prefix(size))
    }
}
```

- [ ] **Step 4: 实现 `handleAgents`**

在 `ArgoDesktopApplication+ControlHost.swift` 中增加：

```swift
func handleAgents(_ request: ArgoAgentsRequest) -> ArgoControlResponse {
    var agents: [ArgoAgentInfo] = []
    for store in allWorkspaceStores {
        for workspace in store.workspaces where workspace.isActive {
            let focusedPane = workspace.sessionController.focusedPaneID
            for (paneID, session) in workspace.sessionController.sessions {
                let entry = AgentStatusStore.shared.entries[paneID]
                var type: String?
                var name: String? = entry?.agentName
                var detectedAlive = false
                if let pid = session.pid, let detected = AgentProcessDetector.detect(rootPID: pid) {
                    type = detected.type
                    if name == nil { name = detected.displayName }
                    detectedAlive = true
                }
                guard entry != nil || detectedAlive else { continue }
                agents.append(ArgoAgentInfo(
                    workspaceID: workspace.id.uuidString.lowercased(),
                    workspaceName: workspace.name,
                    paneID: paneID.uuidString.lowercased(),
                    type: type,
                    name: name,
                    status: entry?.state.rawValue ?? "running",
                    reported: entry != nil,
                    cwd: session.effectiveWorkingDirectory,
                    branch: workspace.supportsRepositoryFeatures ? workspace.currentBranch : nil,
                    focused: paneID == focusedPane
                ))
            }
        }
    }
    return ArgoControlResponse(ok: true, agents: agents)
}
```

- [ ] **Step 5: 运行测试确认通过**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' -only-testing:ArgoTests/AgentProcessDetectorTests test
```

Expected: PASS。

- [ ] **Step 6: 提交**

```sh
git add Argo/Services/Process/AgentProcessDetector.swift Argo/App/ArgoDesktopApplication+ControlHost.swift Tests/AgentProcessDetectorTests.swift
git commit -m "feat(agent): detect procs"
```

---

### Task 7: 全量验证

**Files:**
- 只在前序任务暴露出编译或集成问题时修改相关实现文件。

**Interfaces:**
- Consumes: 前面所有任务产物。
- Produces: 经验证的完整控制协议实现。

- [ ] **Step 1: 运行控制面 focused tests**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/AgentStatusStoreTests \
  -only-testing:ArgoTests/AgentProcessDetectorTests \
  -only-testing:ArgoTests/ArgoControlCLITests \
  -only-testing:ArgoTests/ArgoControlDispatcherTests \
  -only-testing:ArgoTests/ShellSessionTests \
  -only-testing:ArgoTests/WorkspaceSessionControllerTests \
  test
```

Expected: PASS。

- [ ] **Step 2: 运行 app build**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -configuration Debug -destination 'platform=macOS,arch=arm64' build
```

Expected: BUILD SUCCEEDED。

- [ ] **Step 3: 运行完整测试套件**

Run:

```sh
xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' test
```

Expected: TEST SUCCEEDED。若出现失败，先检查第一个失败测试；如果是本功能引入的回归则修复，如果是无关既有失败则记录完整测试名和失败摘要。

- [ ] **Step 4: 手动 smoke test**

在 Argo 已运行且至少有一个 pane 活跃时执行：

```sh
argo session list --json
argo status waiting --title "Manual smoke" --agent Codex
argo read --last 20
argo agents --json
```

Expected:

- `session list` 返回 pane JSON，并在有状态时包含 `status`。
- `status waiting` 更新 pane 状态并打开 Dynamic Island。
- `read` 输出可见终端文本；如果 backend 不支持读屏，返回清晰的 `read-unavailable`。
- `agents --json` 包含刚刚上报状态的 pane。
