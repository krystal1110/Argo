# Dynamic Island Stable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Argo 灵动岛从通知列表升级为 Argo-native agent/session 控制面，支持 pane 级身份、优先级排序、精确跳转、基础响应闭环和可靠 fallback。

**Architecture:** 保留现有 `IslandPanelController` 与 SwiftUI 外壳，把业务状态集中到兼容增强后的 `IslandNotificationState`。新增小型纯逻辑组件处理导航与响应，UI 只消费排序后的 session item，并通过 controller 调用导航/响应入口。

**Tech Stack:** Swift 6, AppKit, SwiftUI, Combine, XCTest, Xcode file-system-synchronized groups.

---

## 文件结构

- Modify: `Argo/Domain/IslandNotificationModels.swift`
  定义 `IslandSessionIdentity`、`IslandSessionStatus`、`IslandSessionAction`，并扩展 `IslandNotificationItem` 为 pane/session 级 item。
- Modify: `Argo/Support/IslandNotificationState.swift`
  保留类名作为兼容入口，实现 session center reducer、排序、dismiss、clear 行为。
- Create: `Argo/Support/IslandWorkspaceNavigator.swift`
  纯导航协调器，负责在一组 `WorkspaceStore` 中找到 workspace/worktree/pane 并返回明确结果。
- Create: `Argo/Support/IslandResponseDispatcher.swift`
  纯响应调度器，负责把 prompt/approval 选项转成 pane 输入，并更新状态或错误。
- Modify: `Argo/App/ArgoDesktopApplication.swift`
  让 `navigateToWorkspace` 支持 `paneID`，并在 `routeAgentNotification` 写入 pane-aware item。
- Modify: `Argo/Support/WorkspaceNotificationCenter.swift`
  系统通知 userInfo 增加可选 `paneID`，点击回调兼容旧字段。
- Modify: `Argo/AppDelegate.swift`
  更新 notification tap 回调签名。
- Modify: `Argo/Domain/WorkspaceRuntime.swift`
  终端 OSC/desktop notification 写入 pane-aware item。
- Modify: `Argo/App/WorkspaceStore.swift`
  status message 写入新状态模型，动态岛关闭时保持 toast/system fallback。
- Modify: `Argo/UI/Island/IslandPanelController.swift`
  item 点击走 pane-aware 导航；prompt 快捷键走 response dispatcher。
- Modify: `Argo/UI/Island/IslandCollapsedView.swift`
  收起态展示 `state.latestItem` 的优先级结果与新状态 icon。
- Modify: `Argo/UI/Island/IslandExpandedView.swift`
  Notifications tab 改为 Sessions tab，使用 `state.priorityItems`，展示错误和操作按钮。
- Modify: `Argo/Support/L10n.swift`
  增加 Sessions、错误、操作按钮文案的英文/简体中文 key。
- Modify: `docs/guides/agent-notifications.md`
  更新 `argo notify` 与灵动岛 pane 级行为说明。
- Create: `Tests/IslandSessionCenterTests.swift`
  测试身份、排序、dismiss、clear、错误保留。
- Create: `Tests/IslandWorkspaceNavigatorTests.swift`
  测试 workspace/worktree/pane 路由结果。
- Create: `Tests/IslandResponseDispatcherTests.swift`
  测试回答/审批写回和失败路径。
- Modify: `Tests/AgentNotifyProtocolTests.swift`
  覆盖 `paneID` 仍保留并进入 island identity。

项目使用 `PBXFileSystemSynchronizedRootGroup` 管理 `Argo/` 与 `Tests/`，新增 Swift 文件不需要手工编辑 `Argo.xcodeproj/project.pbxproj`。如果 Xcode 在本地自动改动 project 文件，实施者必须确认改动只来自文件同步，不能覆盖用户已有 project 改动。

## Task 1: 状态模型与 reducer

**Files:**
- Modify: `Argo/Domain/IslandNotificationModels.swift:10-39`
- Modify: `Argo/Support/IslandNotificationState.swift:11-58`
- Modify: `Argo/UI/Island/IslandCollapsedView.swift:160-176`
- Test: `Tests/IslandSessionCenterTests.swift`

- [ ] **Step 1: 写 failing tests**

Create `Tests/IslandSessionCenterTests.swift`:

```swift
//
//  IslandSessionCenterTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

@MainActor
final class IslandSessionCenterTests: XCTestCase {
    func testDifferentPanesDoNotOverwriteEachOther() {
        let workspaceID = UUID()
        let firstPane = UUID()
        let secondPane = UUID()
        let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 10) })

        state.post(item: makeItem(workspaceID: workspaceID, paneID: firstPane, title: "first"))
        state.post(item: makeItem(workspaceID: workspaceID, paneID: secondPane, title: "second"))

        XCTAssertEqual(state.items.map(\.title), ["first", "second"])
        XCTAssertEqual(Set(state.items.compactMap(\.paneID)), Set([firstPane, secondPane]))
    }

    func testSameIdentityUpdatesExistingItemAndKeepsID() {
        let workspaceID = UUID()
        let paneID = UUID()
        let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 10) })

        state.post(item: makeItem(workspaceID: workspaceID, paneID: paneID, title: "running", status: .running))
        let originalID = state.items[0].id
        state.post(item: makeItem(workspaceID: workspaceID, paneID: paneID, title: "done", status: .completed))

        XCTAssertEqual(state.items.count, 1)
        XCTAssertEqual(state.items[0].id, originalID)
        XCTAssertEqual(state.items[0].title, "done")
        XCTAssertEqual(state.items[0].status, .completed)
    }

    func testPriorityItemsPutAttentionBeforeRunningAndCompleted() {
        let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 10) })

        state.post(item: makeItem(title: "completed", status: .completed, updatedAt: Date(timeIntervalSince1970: 30)))
        state.post(item: makeItem(title: "running", status: .running, updatedAt: Date(timeIntervalSince1970: 40)))
        state.post(item: makeItem(title: "answer", status: .waitingForAnswer, updatedAt: Date(timeIntervalSince1970: 20)))
        state.post(item: makeItem(title: "approval", status: .waitingForApproval, updatedAt: Date(timeIntervalSince1970: 10)))

        XCTAssertEqual(state.priorityItems.map(\.title), ["answer", "approval", "running", "completed"])
        XCTAssertEqual(state.latestItem?.title, "answer")
    }

    func testFailedItemsSortBeforeRunning() {
        let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 10) })

        state.post(item: makeItem(title: "running", status: .running, updatedAt: Date(timeIntervalSince1970: 40)))
        state.post(item: makeItem(title: "failed", status: .failed, updatedAt: Date(timeIntervalSince1970: 20)))

        XCTAssertEqual(state.priorityItems.map(\.title), ["failed", "running"])
    }

    func testDismissRemovesOnlyTargetItem() {
        let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 10) })
        let keep = makeItem(title: "keep")
        let remove = makeItem(title: "remove")

        state.post(item: keep)
        state.post(item: remove)
        state.dismiss(id: remove.id)

        XCTAssertEqual(state.items.map(\.id), [keep.id])
    }

    func testClearCompletedPreservesWaitingAndRunningItems() {
        let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 10) })

        state.post(item: makeItem(title: "done", status: .completed))
        state.post(item: makeItem(title: "failed", status: .failed))
        state.post(item: makeItem(title: "answer", status: .waitingForAnswer))
        state.post(item: makeItem(title: "running", status: .running))
        state.clearCompleted()

        XCTAssertEqual(state.items.map(\.title), ["answer", "running"])
    }

    func testWorkspaceLevelIdentityIsUsedWhenPaneIsMissing() {
        let workspaceID = UUID()
        let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 10) })

        state.post(item: makeItem(workspaceID: workspaceID, paneID: nil, sourceID: nil, title: "first"))
        state.post(item: makeItem(workspaceID: workspaceID, paneID: nil, sourceID: nil, title: "second"))

        XCTAssertEqual(state.items.count, 1)
        XCTAssertEqual(state.items[0].title, "second")
    }

    func testSourceIDSeparatesEventsFromSamePaneWhenProvided() {
        let workspaceID = UUID()
        let paneID = UUID()
        let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 10) })

        state.post(item: makeItem(workspaceID: workspaceID, paneID: paneID, sourceID: "build", title: "build"))
        state.post(item: makeItem(workspaceID: workspaceID, paneID: paneID, sourceID: "test", title: "test"))

        XCTAssertEqual(state.items.map(\.title), ["build", "test"])
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-island-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeItem(
        workspaceID: UUID = UUID(),
        worktreePath: String? = "/tmp/repo",
        paneID: UUID? = UUID(),
        sourceID: String? = nil,
        title: String = "item",
        status: IslandSessionStatus = .running,
        updatedAt: Date = Date(timeIntervalSince1970: 10)
    ) -> IslandNotificationItem {
        IslandNotificationItem(
            id: UUID(),
            workspaceID: workspaceID,
            worktreePath: worktreePath,
            paneID: paneID,
            sourceID: sourceID,
            title: title,
            agentName: nil,
            terminalTag: paneID?.uuidString.lowercased(),
            status: status,
            startedAt: Date(timeIntervalSince1970: 1),
            updatedAt: updatedAt,
            body: nil,
            prompt: nil,
            action: nil,
            lastError: nil
        )
    }
}
```

- [ ] **Step 2: 运行 tests 确认失败**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionCenterTests \
  test
```

Expected: FAIL，错误包含 `cannot find type 'IslandSessionStatus' in scope` 或 `extra arguments at positions ... in call`。

- [ ] **Step 3: 写最小模型实现**

Replace `Argo/Domain/IslandNotificationModels.swift` with:

```swift
//
//  IslandNotificationModels.swift
//  Argo
//
//  Author: krystal
//

import Foundation

enum IslandSessionStatus: Equatable {
    case running
    case waitingForApproval
    case waitingForAnswer
    case completed
    case failed
    case stale

    var requiresAttention: Bool {
        switch self {
        case .waitingForApproval, .waitingForAnswer:
            return true
        case .running, .completed, .failed, .stale:
            return false
        }
    }

    var priorityRank: Int {
        switch self {
        case .waitingForAnswer:    return 0
        case .waitingForApproval:  return 1
        case .failed:              return 2
        case .running:             return 3
        case .stale:               return 4
        case .completed:           return 5
        }
    }
}

typealias IslandItemStatus = IslandSessionStatus

extension IslandSessionStatus {
    static let done: IslandSessionStatus = .completed
    static let error: IslandSessionStatus = .failed
    static let waitingForInput: IslandSessionStatus = .waitingForAnswer
}

struct IslandSessionIdentity: Hashable {
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

enum IslandSessionAction: Equatable {
    case sendText(String)
    case prompt(IslandPrompt)
}

struct IslandNotificationItem: Identifiable, Equatable {
    let id: UUID
    let identity: IslandSessionIdentity
    let workspaceID: UUID
    let worktreePath: String?
    let paneID: UUID?
    let sourceID: String?
    let title: String
    let agentName: String?
    let terminalTag: String?
    var status: IslandSessionStatus
    let startedAt: Date
    var updatedAt: Date
    var body: String?
    var prompt: IslandPrompt?
    var action: IslandSessionAction?
    var lastError: String?

    init(
        id: UUID = UUID(),
        workspaceID: UUID,
        worktreePath: String?,
        paneID: UUID? = nil,
        sourceID: String? = nil,
        title: String,
        agentName: String?,
        terminalTag: String?,
        status: IslandSessionStatus,
        startedAt: Date,
        updatedAt: Date = Date(),
        body: String?,
        prompt: IslandPrompt?,
        action: IslandSessionAction? = nil,
        lastError: String? = nil
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.worktreePath = worktreePath
        self.paneID = paneID
        self.sourceID = sourceID ?? paneID?.uuidString.lowercased()
        self.identity = IslandSessionIdentity(
            workspaceID: workspaceID,
            worktreePath: worktreePath,
            paneID: paneID,
            sourceID: sourceID
        )
        self.title = title
        self.agentName = agentName
        self.terminalTag = terminalTag
        self.status = status
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.body = body
        self.prompt = prompt
        self.action = action
        self.lastError = lastError
    }
}

struct IslandPrompt: Equatable {
    let question: String
    let options: [IslandPromptOption]
}

struct IslandPromptOption: Identifiable, Equatable {
    let id: Int
    let label: String
    let responseText: String
}
```

Replace `Argo/Support/IslandNotificationState.swift` with:

```swift
//
//  IslandNotificationState.swift
//  Argo
//
//  Author: krystal
//

import Combine
import Foundation

enum IslandTab: String, CaseIterable {
    case workspaces
    case notifications
}

@MainActor
final class IslandNotificationState: ObservableObject {
    static let shared = IslandNotificationState()

    @Published private(set) var items: [IslandNotificationItem] = []
    @Published var isExpanded: Bool = false
    @Published var selectedTab: IslandTab = .workspaces
    @Published var currentGroupID: UUID? = nil

    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    var priorityItems: [IslandNotificationItem] {
        items.sorted { lhs, rhs in
            if lhs.status.priorityRank == rhs.status.priorityRank {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.status.priorityRank < rhs.status.priorityRank
        }
    }

    var latestItem: IslandNotificationItem? {
        priorityItems.first
    }

    var badgeCount: Int {
        items.count
    }

    var attentionCount: Int {
        items.filter { $0.status.requiresAttention }.count
    }

    func post(item: IslandNotificationItem) {
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

    func update(id: UUID, status: IslandSessionStatus, lastError: String? = nil) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = status
        items[index].lastError = lastError
        items[index].updatedAt = now()
    }

    func markDone(id: UUID) {
        update(id: id, status: .completed)
    }

    func dismiss(id: UUID) {
        items.removeAll { $0.id == id }
        if items.isEmpty {
            isExpanded = false
        }
    }

    func clearCompleted() {
        items.removeAll { item in
            item.status == .completed || item.status == .failed || item.status == .stale
        }
        if items.isEmpty {
            isExpanded = false
        }
    }

    func clearAll() {
        items.removeAll()
        isExpanded = false
    }
}
```

Update `Argo/UI/Island/IslandCollapsedView.swift` status icon switch so the app still compiles while the richer UI lands in Task 5:

```swift
@ViewBuilder
func islandStatusIcon(for item: IslandNotificationItem) -> some View {
    switch item.status {
    case .running:
        Circle()
            .fill(.green)
            .frame(width: 8, height: 8)
    case .completed:
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
    case .failed:
        Image(systemName: "exclamationmark.circle.fill")
            .foregroundStyle(.red)
    case .waitingForApproval:
        Image(systemName: "hand.raised.circle.fill")
            .foregroundStyle(.orange)
    case .waitingForAnswer:
        Image(systemName: "questionmark.circle.fill")
            .foregroundStyle(.cyan)
    case .stale:
        Image(systemName: "link.badge.plus")
            .foregroundStyle(.gray)
    }
}
```

- [ ] **Step 4: 运行 tests 确认通过**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionCenterTests \
  test
```

Expected: PASS。

- [ ] **Step 5: 提交 Task 1**

```bash
git add Argo/Domain/IslandNotificationModels.swift Argo/Support/IslandNotificationState.swift Argo/UI/Island/IslandCollapsedView.swift Tests/IslandSessionCenterTests.swift
git commit -m "feat(island): add model"
```

## Task 2: 入口迁移到 pane-aware item

**Files:**
- Modify: `Argo/Domain/WorkspaceRuntime.swift:1237-1268`
- Modify: `Argo/App/WorkspaceStore.swift:2821-2838`
- Modify: `Tests/AgentNotifyProtocolTests.swift:11-24`

- [ ] **Step 1: 写 failing test**

Append to `Tests/IslandSessionCenterTests.swift`:

```swift
    func testWorkspacePostAgentNotificationPreservesPaneIdentity() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let workspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
        let paneID = UUID()

        IslandNotificationState.shared.clearAll()
        defer { IslandNotificationState.shared.clearAll() }
        workspace.postAgentNotification(
            title: "Pane waiting",
            body: "needs approval",
            paneID: paneID,
            agentName: "Codex"
        )

        let item = try XCTUnwrap(IslandNotificationState.shared.items.first)
        XCTAssertEqual(item.paneID, paneID)
        XCTAssertEqual(item.sourceID, "pane:\(paneID.uuidString.lowercased())")
        XCTAssertEqual(item.terminalTag, String(paneID.uuidString.prefix(8)).lowercased())
    }
```

Update `Tests/AgentNotifyProtocolTests.swift` existing `testEncodeDecodeRoundTripPreservesAllFields` assertion block:

```swift
        XCTAssertEqual(decoded.paneID, "abc-pane")
        XCTAssertEqual(decoded.workspaceID, "ws-1")
        XCTAssertEqual(decoded.agentName, "Claude")
```

- [ ] **Step 2: 运行 tests 确认失败**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionCenterTests/testWorkspacePostAgentNotificationPreservesPaneIdentity \
  -only-testing:ArgoTests/AgentNotifyProtocolTests/testEncodeDecodeRoundTripPreservesAllFields \
  test
```

Expected: `testWorkspacePostAgentNotificationPreservesPaneIdentity` FAIL，说明 `WorkspaceModel.postAgentNotification` 仍把通知写成 workspace/worktree 级 item，没有保留 `paneID`、`sourceID` 或短 `terminalTag`。

- [ ] **Step 3: 让入口写入 pane-aware item**

In `Argo/Domain/WorkspaceRuntime.swift`, replace the item construction in `postAgentNotification`:

```swift
        let terminalTag = paneID.map { Self.shortPaneTag(for: $0) }
        let item = IslandNotificationItem(
            id: UUID(),
            workspaceID: id,
            worktreePath: activeWorktreePath,
            paneID: paneID,
            sourceID: paneID.map { "pane:\($0.uuidString.lowercased())" },
            title: resolvedTitle,
            agentName: agentName,
            terminalTag: terminalTag,
            status: .running,
            startedAt: Date(),
            updatedAt: Date(),
            body: resolvedBody,
            prompt: nil,
            action: nil,
            lastError: nil
        )
        IslandNotificationState.shared.post(item: item)
        IslandPanelController.shared.show()
```

Add this helper inside `WorkspaceModel` near `postAgentNotification`:

```swift
    private static func shortPaneTag(for paneID: UUID) -> String {
        String(paneID.uuidString.prefix(8)).lowercased()
    }
```

In `Argo/App/WorkspaceStore.swift`, replace the dynamic island branch item construction:

```swift
                let resolvedWorkspaceID = workspaceID ?? selectedWorkspace?.id ?? UUID()
                let item = IslandNotificationItem(
                    id: UUID(),
                    workspaceID: resolvedWorkspaceID,
                    worktreePath: worktreePath,
                    paneID: nil,
                    sourceID: "status:\(resolvedWorkspaceID.uuidString.lowercased()):\(text)",
                    title: text,
                    agentName: nil,
                    terminalTag: nil,
                    status: tone == .success ? .completed : .running,
                    startedAt: Date(),
                    updatedAt: Date(),
                    body: nil,
                    prompt: nil,
                    action: nil,
                    lastError: nil
                )
                IslandNotificationState.shared.post(item: item)
                IslandPanelController.shared.show()
```

In `Argo/App/ArgoDesktopApplication.swift`, verify `routeAgentNotification` still passes the parsed `paneID` into `WorkspaceModel.postAgentNotification`:

```swift
                    workspace.postAgentNotification(
                        title: request.title,
                        body: request.body,
                        paneID: paneID,
                        agentName: request.agentName
                    )
```

- [ ] **Step 4: 运行 tests 确认通过**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionCenterTests/testWorkspacePostAgentNotificationPreservesPaneIdentity \
  -only-testing:ArgoTests/AgentNotifyProtocolTests/testEncodeDecodeRoundTripPreservesAllFields \
  test
```

Expected: PASS。

- [ ] **Step 5: 提交 Task 2**

```bash
git add Argo/Domain/WorkspaceRuntime.swift Argo/App/WorkspaceStore.swift Tests/IslandSessionCenterTests.swift Tests/AgentNotifyProtocolTests.swift
git commit -m "feat(island): route panes"
```

## Task 3: pane-aware 导航

**Files:**
- Create: `Argo/Support/IslandWorkspaceNavigator.swift`
- Modify: `Argo/App/ArgoDesktopApplication.swift:240-252`
- Modify: `Argo/Support/WorkspaceNotificationCenter.swift:15-70`
- Modify: `Argo/AppDelegate.swift:76-79`
- Modify: `Argo/UI/Island/IslandPanelController.swift:145-153`
- Test: `Tests/IslandWorkspaceNavigatorTests.swift`

- [ ] **Step 1: 写 failing tests**

Create `Tests/IslandWorkspaceNavigatorTests.swift`:

```swift
//
//  IslandWorkspaceNavigatorTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

@MainActor
final class IslandWorkspaceNavigatorTests: XCTestCase {
    func testNavigateFocusesWorkspaceWorktreeAndPane() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let workspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
        workspace.createPane(splitAxis: .vertical)
        let targetPaneID = try XCTUnwrap(workspace.paneOrder.last)
        let store = WorkspaceStore(persistsWorkspaceState: false)
        store.workspaces = [workspace]

        var didPresent = false
        let navigator = IslandWorkspaceNavigator(
            stores: { [store] },
            present: { presented in
                XCTAssertTrue(presented === store)
                didPresent = true
            }
        )

        let result = navigator.navigate(
            workspaceID: workspace.id,
            worktreePath: workspace.activeWorktreePath,
            paneID: targetPaneID
        )

        XCTAssertEqual(result, .focusedPane)
        XCTAssertEqual(store.selectedWorkspaceID, workspace.id)
        XCTAssertEqual(workspace.sessionController.focusedPaneID, targetPaneID)
        XCTAssertTrue(didPresent)
    }

    func testNavigateReturnsPaneMissingButStillSelectsWorkspace() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let workspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
        let store = WorkspaceStore(persistsWorkspaceState: false)
        store.workspaces = [workspace]

        let navigator = IslandWorkspaceNavigator(stores: { [store] }, present: { _ in })

        let result = navigator.navigate(
            workspaceID: workspace.id,
            worktreePath: workspace.activeWorktreePath,
            paneID: UUID()
        )

        XCTAssertEqual(result, .paneMissing)
        XCTAssertEqual(store.selectedWorkspaceID, workspace.id)
    }

    func testNavigateReturnsWorkspaceMissing() {
        let navigator = IslandWorkspaceNavigator(stores: { [] }, present: { _ in XCTFail("present should not run") })

        let result = navigator.navigate(workspaceID: UUID(), worktreePath: nil, paneID: nil)

        XCTAssertEqual(result, .workspaceMissing)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-island-nav-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
```

- [ ] **Step 2: 运行 tests 确认失败**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandWorkspaceNavigatorTests \
  test
```

Expected: FAIL，错误包含 `cannot find 'IslandWorkspaceNavigator' in scope`。

- [ ] **Step 3: 实现 navigator 与 app 接入**

Create `Argo/Support/IslandWorkspaceNavigator.swift`:

```swift
//
//  IslandWorkspaceNavigator.swift
//  Argo
//
//  Author: krystal
//

import Foundation

enum IslandNavigationResult: Equatable {
    case focusedPane
    case focusedWorkspace
    case workspaceMissing
    case paneMissing
}

@MainActor
struct IslandWorkspaceNavigator {
    let stores: () -> [WorkspaceStore]
    let present: (WorkspaceStore) -> Void

    func navigate(
        workspaceID: UUID,
        worktreePath: String?,
        paneID: UUID?
    ) -> IslandNavigationResult {
        for store in stores() {
            guard let workspace = store.workspaces.first(where: { $0.id == workspaceID }) else {
                continue
            }

            present(store)
            store.selectWorkspace(workspace)

            if let worktreePath, workspace.activeWorktreePath != worktreePath {
                workspace.switchToWorktree(path: worktreePath, restartRunning: false)
            }

            guard let paneID else {
                return .focusedWorkspace
            }

            guard workspace.sessionController.session(for: paneID) != nil else {
                return .paneMissing
            }

            workspace.focusPane(paneID)
            return .focusedPane
        }

        return .workspaceMissing
    }
}
```

Modify `Argo/App/ArgoDesktopApplication.swift` navigation method:

```swift
    @discardableResult
    func navigateToWorkspace(
        id workspaceID: UUID,
        worktreePath: String? = nil,
        paneID: UUID? = nil
    ) -> IslandNavigationResult {
        let navigator = IslandWorkspaceNavigator(
            stores: { self.windowContexts.map(\.store) },
            present: { [weak self] store in
                guard let self,
                      let context = self.windowContexts.first(where: { $0.store === store }) else { return }
                context.present(ignoringOtherApps: true)
            }
        )
        return navigator.navigate(workspaceID: workspaceID, worktreePath: worktreePath, paneID: paneID)
    }
```

Modify `Argo/Support/WorkspaceNotificationCenter.swift` callback and deliver signature:

```swift
    var onNotificationTapped: ((UUID, String?, UUID?) -> Void)?

    func deliver(
        title: String,
        body: String?,
        workspaceID: UUID? = nil,
        worktreePath: String? = nil,
        paneID: UUID? = nil
    ) {
```

Add userInfo:

```swift
        if let paneID {
            userInfo["paneID"] = paneID.uuidString
        }
```

Update didReceive extraction:

```swift
        let paneID = (userInfo["paneID"] as? String).flatMap(UUID.init(uuidString:))

        if let workspaceIDString, let workspaceID = UUID(uuidString: workspaceIDString) {
            Task { @MainActor in
                self.onNotificationTapped?(workspaceID, worktreePath, paneID)
                self.onNotificationTappedFromSystem?()
            }
        }
```

Modify `Argo/AppDelegate.swift`:

```swift
            WorkspaceNotificationCenter.shared.onNotificationTapped = { [weak desktopApplication] workspaceID, worktreePath, paneID in
                desktopApplication?.navigateToWorkspace(id: workspaceID, worktreePath: worktreePath, paneID: paneID)
            }
```

Modify `Argo/UI/Island/IslandPanelController.swift` item navigation:

```swift
    func navigateToItem(_ item: IslandNotificationItem) {
        WorkspaceNotificationCenter.shared.onNotificationTapped?(item.workspaceID, item.worktreePath, item.paneID)
        state.dismiss(id: item.id)
        if state.items.isEmpty && state.selectedTab == .notifications {
            hide()
        } else {
            repositionPanel()
        }
    }

    func navigateToWorkspace(_ workspace: WorkspaceModel) {
        WorkspaceNotificationCenter.shared.onNotificationTapped?(workspace.id, nil, nil)
        state.isExpanded = false
        repositionPanel()
    }
```

- [ ] **Step 4: 运行 tests 确认通过**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandWorkspaceNavigatorTests \
  test
```

Expected: PASS。

- [ ] **Step 5: 提交 Task 3**

```bash
git add Argo/Support/IslandWorkspaceNavigator.swift Argo/App/ArgoDesktopApplication.swift Argo/Support/WorkspaceNotificationCenter.swift Argo/AppDelegate.swift Argo/UI/Island/IslandPanelController.swift Tests/IslandWorkspaceNavigatorTests.swift
git commit -m "feat(island): focus pane"
```

## Task 4: response dispatcher

**Files:**
- Create: `Argo/Support/IslandResponseDispatcher.swift`
- Modify: `Argo/UI/Island/IslandPanelController.swift:314-343`
- Modify: `Argo/UI/Island/IslandExpandedView.swift:443-493`
- Test: `Tests/IslandResponseDispatcherTests.swift`

- [ ] **Step 1: 写 failing tests**

Create `Tests/IslandResponseDispatcherTests.swift`:

```swift
//
//  IslandResponseDispatcherTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

@MainActor
final class IslandResponseDispatcherTests: XCTestCase {
    func testRespondSendsTextAndMarksItemRunning() {
        let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 20) })
        let paneID = UUID()
        let item = makeQuestionItem(paneID: paneID)
        state.post(item: item)
        var sent: [(UUID, String)] = []
        let dispatcher = IslandResponseDispatcher(
            state: state,
            sendText: { targetPaneID, text in
                sent.append((targetPaneID, text))
                return true
            }
        )

        dispatcher.respond(to: item.id, with: "yes\n")

        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent[0].0, paneID)
        XCTAssertEqual(sent[0].1, "yes\n")
        XCTAssertEqual(state.items[0].status, .running)
        XCTAssertNil(state.items[0].lastError)
    }

    func testRespondKeepsWaitingStateWhenPaneIsMissing() {
        let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 20) })
        let item = makeQuestionItem(paneID: nil)
        state.post(item: item)
        let dispatcher = IslandResponseDispatcher(state: state, sendText: { _, _ in true })

        dispatcher.respond(to: item.id, with: "yes\n")

        XCTAssertEqual(state.items[0].status, .waitingForAnswer)
        XCTAssertEqual(state.items[0].lastError, "Pane is no longer available.")
    }

    func testRespondKeepsWaitingStateWhenSendFails() {
        let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 20) })
        let item = makeQuestionItem(paneID: UUID())
        state.post(item: item)
        let dispatcher = IslandResponseDispatcher(state: state, sendText: { _, _ in false })

        dispatcher.respond(to: item.id, with: "yes\n")

        XCTAssertEqual(state.items[0].status, .waitingForAnswer)
        XCTAssertEqual(state.items[0].lastError, "Could not send response to the pane.")
    }

    private func makeQuestionItem(paneID: UUID?) -> IslandNotificationItem {
        IslandNotificationItem(
            id: UUID(),
            workspaceID: UUID(),
            worktreePath: "/tmp/repo",
            paneID: paneID,
            sourceID: "question",
            title: "Question",
            agentName: "Codex",
            terminalTag: paneID?.uuidString.lowercased(),
            status: .waitingForAnswer,
            startedAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 10),
            body: nil,
            prompt: IslandPrompt(
                question: "Continue?",
                options: [IslandPromptOption(id: 1, label: "Yes", responseText: "yes\n")]
            ),
            action: nil,
            lastError: nil
        )
    }
}
```

- [ ] **Step 2: 运行 tests 确认失败**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandResponseDispatcherTests \
  test
```

Expected: FAIL，错误包含 `cannot find 'IslandResponseDispatcher' in scope`。

- [ ] **Step 3: 实现 dispatcher**

Create `Argo/Support/IslandResponseDispatcher.swift`:

```swift
//
//  IslandResponseDispatcher.swift
//  Argo
//
//  Author: krystal
//

import Foundation

@MainActor
struct IslandResponseDispatcher {
    let state: IslandNotificationState
    let sendText: (UUID, String) -> Bool

    func respond(to itemID: UUID, with text: String) {
        guard let item = state.items.first(where: { $0.id == itemID }) else { return }
        guard let paneID = item.paneID else {
            state.update(id: itemID, status: item.status, lastError: "Pane is no longer available.")
            return
        }

        guard sendText(paneID, text) else {
            state.update(id: itemID, status: item.status, lastError: "Could not send response to the pane.")
            return
        }

        state.update(id: itemID, status: .running, lastError: nil)
    }
}
```

In `Argo/UI/Island/IslandPanelController.swift`, add:

```swift
    private func responseDispatcher() -> IslandResponseDispatcher {
        IslandResponseDispatcher(state: state) { [weak self] paneID, text in
            guard let store = self?.workspaceStore else { return false }
            for workspace in store.workspaces {
                if let session = workspace.sessionController.session(for: paneID) {
                    session.insertText(text)
                    return true
                }
            }
            return false
        }
    }

    func respondToItem(_ item: IslandNotificationItem, text: String) {
        responseDispatcher().respond(to: item.id, with: text)
        repositionPanel()
    }
```

Update the keyboard monitor response block:

```swift
            if let keyNumber, let option = prompt.options.first(where: { $0.id == keyNumber }) {
                if let item = self.state.items.first(where: { $0.prompt != nil }) {
                    Task { @MainActor in
                        self.respondToItem(item, text: option.responseText)
                    }
                }
                return nil
            }
```

Update `IslandPromptRow` button action in `Argo/UI/Island/IslandExpandedView.swift`:

```swift
                Button {
                    controller.respondToItem(item, text: option.responseText)
                } label: {
```

- [ ] **Step 4: 运行 tests 确认通过**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandResponseDispatcherTests \
  test
```

Expected: PASS。

- [ ] **Step 5: 提交 Task 4**

```bash
git add Argo/Support/IslandResponseDispatcher.swift Argo/UI/Island/IslandPanelController.swift Argo/UI/Island/IslandExpandedView.swift Tests/IslandResponseDispatcherTests.swift
git commit -m "feat(island): send reply"
```

## Task 5: UI sessions tab 与本地化

**Files:**
- Modify: `Argo/Support/IslandNotificationState.swift:10-14`
- Modify: `Argo/UI/Island/IslandContentView.swift:28-35`
- Modify: `Argo/UI/Island/IslandPanelController.swift:145-153`
- Modify: `Argo/UI/Island/IslandCollapsedView.swift:34-175`
- Modify: `Argo/UI/Island/IslandExpandedView.swift:42-235,383-497`
- Modify: `Argo/Support/L10n.swift`
- Test: `Tests/LocalizationManagerTests.swift`

- [ ] **Step 1: 写 failing localization tests**

Append assertions to the existing localization test that checks settings keys, or add this method to `Tests/LocalizationManagerTests.swift`:

```swift
    func testDynamicIslandSessionStringsExistInEnglishAndChinese() {
        LocalizationManager.shared.updateSelectedLanguage(.english)
        XCTAssertEqual(LocalizationManager.shared.string("island.tab.sessions"), "Sessions")
        XCTAssertEqual(LocalizationManager.shared.string("island.empty.sessions"), "No active sessions")
        XCTAssertEqual(LocalizationManager.shared.string("island.action.clearCompleted"), "Clear completed")

        LocalizationManager.shared.updateSelectedLanguage(.simplifiedChinese)
        XCTAssertEqual(LocalizationManager.shared.string("island.tab.sessions"), "会话")
        XCTAssertEqual(LocalizationManager.shared.string("island.empty.sessions"), "没有活跃会话")
        XCTAssertEqual(LocalizationManager.shared.string("island.action.clearCompleted"), "清除已完成")
    }
```

- [ ] **Step 2: 运行 test 确认失败**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/LocalizationManagerTests/testDynamicIslandSessionStringsExistInEnglishAndChinese \
  test
```

Expected: FAIL，缺少 `island.tab.sessions` 等 key。

- [ ] **Step 3: 加本地化 key**

Add to English dictionary in `Argo/Support/L10n.swift`:

```swift
        "island.tab.workspaces": "Workspaces",
        "island.tab.sessions": "Sessions",
        "island.empty.sessions": "No active sessions",
        "island.action.clearCompleted": "Clear completed",
        "island.status.completed": "Done - click to jump",
        "island.status.failed": "Needs attention",
        "island.status.stale": "Pane is gone",
```

Add to Simplified Chinese dictionary:

```swift
        "island.tab.workspaces": "工作区",
        "island.tab.sessions": "会话",
        "island.empty.sessions": "没有活跃会话",
        "island.action.clearCompleted": "清除已完成",
        "island.status.completed": "已完成，点击跳转",
        "island.status.failed": "需要处理",
        "island.status.stale": "面板已失效",
```

- [ ] **Step 4: 更新 UI 使用优先级与新状态**

In `Argo/Support/IslandNotificationState.swift`, remove the temporary compatibility tab case:

```swift
enum IslandTab: String, CaseIterable {
    case workspaces
    case sessions
}
```

In `Argo/UI/Island/IslandContentView.swift`, update collapsed-tap expansion to open Sessions:

```swift
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                if !state.isExpanded && !state.items.isEmpty {
                    state.selectedTab = .sessions
                }
                state.isExpanded.toggle()
            }
            controller.repositionPanel()
        }
```

In `Argo/UI/Island/IslandPanelController.swift`, update the empty-session hide check:

```swift
    func navigateToItem(_ item: IslandNotificationItem) {
        WorkspaceNotificationCenter.shared.onNotificationTapped?(item.workspaceID, item.worktreePath, item.paneID)
        state.dismiss(id: item.id)
        if state.items.isEmpty && state.selectedTab == .sessions {
            hide()
        } else {
            repositionPanel()
        }
    }
```

In `Argo/UI/Island/IslandCollapsedView.swift`, keep the layout but rely on `state.latestItem`, which now means highest-priority item. Replace status icon switch with:

```swift
@ViewBuilder
func islandStatusIcon(for item: IslandNotificationItem) -> some View {
    switch item.status {
    case .running:
        Circle()
            .fill(.green)
            .frame(width: 8, height: 8)
    case .completed:
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
    case .failed:
        Image(systemName: "exclamationmark.circle.fill")
            .foregroundStyle(.red)
    case .waitingForApproval:
        Image(systemName: "hand.raised.circle.fill")
            .foregroundStyle(.orange)
    case .waitingForAnswer:
        Image(systemName: "questionmark.circle.fill")
            .foregroundStyle(.cyan)
    case .stale:
        Image(systemName: "link.badge.plus")
            .foregroundStyle(.gray)
    }
}
```

In `Argo/UI/Island/IslandExpandedView.swift`, update tab references:

```swift
                case .sessions:
                    sessionsTabContent
```

Rename the existing notifications content property to `sessionsTabContent` and iterate `state.priorityItems`:

```swift
                    ForEach(state.priorityItems) { item in
                        if let prompt = item.prompt {
                            IslandPromptRow(item: item, prompt: prompt, controller: controller)
                        } else {
                            IslandNotificationRow(item: item, controller: controller)
                        }
                    }
```

Update tab icon/title:

```swift
        case .workspaces: return "square.grid.2x2"
        case .sessions: return "bolt.horizontal.circle"
```

```swift
        case .workspaces: return LocalizationManager.shared.string("island.tab.workspaces")
        case .sessions: return LocalizationManager.shared.string("island.tab.sessions")
```

Update empty state:

```swift
                Image(systemName: "bolt.slash")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.2))
                Text(LocalizationManager.shared.string("island.empty.sessions"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
```

Update clear button condition:

```swift
            if state.selectedTab == .sessions && !state.items.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        state.clearCompleted()
                    }
                    controller.repositionPanel()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .help(LocalizationManager.shared.string("island.action.clearCompleted"))
            }
```

Update `IslandNotificationRow` body text:

```swift
                    if let lastError = item.lastError {
                        Text(lastError)
                            .font(.system(size: 11))
                            .foregroundStyle(.red.opacity(0.85))
                            .lineLimit(1)
                    } else if item.status == .completed {
                        Text(LocalizationManager.shared.string("island.status.completed"))
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                    } else if item.status == .failed {
                        Text(LocalizationManager.shared.string("island.status.failed"))
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    } else if item.status == .stale {
                        Text(LocalizationManager.shared.string("island.status.stale"))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                    } else if let body = item.body {
                        Text(body)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
```

Update row background:

```swift
                    .fill(item.status == .completed ? .green.opacity(0.08) : item.status.requiresAttention ? .orange.opacity(0.08) : .clear)
```

- [ ] **Step 5: 运行 tests 确认通过**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/LocalizationManagerTests/testDynamicIslandSessionStringsExistInEnglishAndChinese \
  -only-testing:ArgoTests/IslandSessionCenterTests \
  test
```

Expected: PASS。

- [ ] **Step 6: 提交 Task 5**

```bash
git add Argo/Support/IslandNotificationState.swift Argo/UI/Island/IslandContentView.swift Argo/UI/Island/IslandPanelController.swift Argo/UI/Island/IslandCollapsedView.swift Argo/UI/Island/IslandExpandedView.swift Argo/Support/L10n.swift Tests/LocalizationManagerTests.swift
git commit -m "feat(island): add ui"
```

## Task 6: docs 与最终验证

**Files:**
- Modify: `docs/guides/agent-notifications.md`

- [ ] **Step 1: 更新文档**

In `docs/guides/agent-notifications.md`, update the first paragraph to:

```markdown
Argo surfaces notifications from anything running inside a pane - shells,
build tools, AI coding agents - through the dynamic island and the system
notification center. When Dynamic Island is enabled, pane-scoped events become
session rows: multiple panes can report independently, attention items sort to
the top, and clicking a row jumps back to the originating workspace, worktree,
and pane.
```

In the `Routing rules` section, replace the final paragraph with:

```markdown
The notification is then posted to the dynamic island for that workspace.
When a pane is known, Argo stores it as the item identity so notifications
from different panes do not overwrite one another. Clicking a row navigates
back to the workspace, worktree, and pane when that pane still exists; if the
pane is gone, Argo falls back to the workspace/worktree and marks the row stale.
```

- [ ] **Step 2: 运行 focused tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandSessionCenterTests \
  -only-testing:ArgoTests/IslandWorkspaceNavigatorTests \
  -only-testing:ArgoTests/IslandResponseDispatcherTests \
  -only-testing:ArgoTests/AgentNotifyProtocolTests \
  -only-testing:ArgoTests/LocalizationManagerTests/testDynamicIslandSessionStringsExistInEnglishAndChinese \
  test
```

Expected: PASS。

- [ ] **Step 3: 运行完整测试**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  test
```

Expected: PASS。若完整测试因既有无关失败未通过，记录失败测试名称，并重新运行 focused island tests 证明本功能切片。

- [ ] **Step 4: 手动 smoke**

Run the app from Xcode or:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Manual checks:

- Enable Dynamic Island in Settings.
- In pane A, run `printf '\e]9;Pane A done\a'`.
- In pane B, run `printf '\e]777;notify;Pane B waiting;needs input\a'`.
- Confirm the expanded island shows two rows, not one overwritten row.
- Click each row and confirm Argo focuses the matching pane.
- Run `argo notify --title "CLI notify" --body "from pane"` from inside a pane and confirm the row uses that pane identity.
- Disable Dynamic Island and trigger `printf '\e]9;System path\a'`; confirm toast/system notification path remains active.

- [ ] **Step 5: 提交 Task 6**

```bash
git add docs/guides/agent-notifications.md
git commit -m "feat(island): update docs"
```

## Self-review

Spec coverage:

- Pane identity: Task 1 and Task 2.
- Attention-first ordering: Task 1 and Task 5.
- Workspace/worktree/pane navigation: Task 3.
- Approval/question response: Task 4.
- Dynamic Island disabled fallback: Task 2 and Task 6 smoke.
- Tests and docs: Task 1 through Task 6.

Placeholder scan:

- 禁用占位语已经清理；计划中的每个代码修改步骤都给出具体代码或明确命令。
- Each task has a failing test, an expected failure, implementation code, verification command, and commit command.

Type consistency:

- `IslandSessionStatus` is used consistently by models, tests, and UI.
- `IslandNotificationItem` remains the public item type consumed by existing views while gaining `identity`, `paneID`, `sourceID`, `updatedAt`, `action`, and `lastError`.
- `IslandTab.notifications` is kept through Task 4 for compile compatibility, then Task 5 replaces it with `IslandTab.sessions` and updates remaining UI references.
