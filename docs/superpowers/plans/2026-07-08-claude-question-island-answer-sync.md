# Claude Question Island Answer Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Claude 问题选项无论从灵动岛还是 Claude 终端完成，都统一清理灵动岛选项页并显示 `Answered: <选项>`。

**Architecture:** 在 Claude hook / notification 边界建立统一回答入口，不改 UI 布局。`IslandNotificationState` 负责把 session id 和回答文本应用到 `IslandSessionState.answerQuestion(sessionID:response:at:)`；`IslandResponseDispatcher` 和 `AgentNotifyControlServer` 都调用同一语义。

**Tech Stack:** Swift, XCTest, AppKit/SwiftUI existing island state, Unix-domain control socket, Claude Code hook JSON.

## Global Constraints

- 所有面向用户说明和计划文档使用简体中文；代码标识符保持英文。
- 不改变 `AgentNotifyRequest` wire format。
- 不改变灵动岛 UI 组件布局或视觉样式。
- 不改变 approval 权限请求的现有镜像写回行为。
- 使用 TDD：先写失败测试，再实现最小代码。

---

## File Structure

- Modify `Argo/Domain/IslandAgentModels.swift`
  - 给 `IslandQuestionPrompt` 增加回答解析 helper，从 response text 或 label 找到展示文本。
- Modify `Argo/Support/IslandNotificationState.swift`
  - 增加 question answer 统一入口，只在现有 session 正处于 `.waitingForAnswer` 时调用 `sessionState.answerQuestion(sessionID:response:at:)`。
- Modify `Argo/Support/IslandResponseDispatcher.swift`
  - Claude hook question resolve 成功后使用统一回答入口，summary 变为 `Answered: <选项>`。
  - approval resolve 仍保持原有 `Response sent.` 和 pane mirror 行为。
- Modify `Argo/Services/AgentNotify/ClaudeHookNotifyBridge.swift`
  - 解码 `PostToolUse` 和 `tool_response`。
  - 增加从 `AskUserQuestion` completion payload 提取回答 label 的 helper。
- Modify `Argo/Services/AgentNotify/AgentNotifyServer.swift`
  - 在 `ArgoClaudeHookControlHandler` 收到非 notify request 的 Claude hook frame 时，处理 `PostToolUse + AskUserQuestion` completion，并投递统一回答入口。
- Modify `Tests/IslandResponseDispatcherTests.swift`
  - 覆盖灵动岛内点击 Claude question option 后 summary 为 `Answered: Staging`。
- Modify `Tests/ClaudeHookNotifyBridgeTests.swift`
  - 覆盖 `PostToolUse + AskUserQuestion` payload 的回答提取。
- Modify `Tests/AgentNotifyServerTests.swift`
  - 覆盖 control socket 收到 Claude 外部完成事件后，`IslandNotificationState.shared` 清掉 waiting question。

---

### Task 1: 灵动岛内选择使用回答摘要

**Files:**
- Modify: `Tests/IslandResponseDispatcherTests.swift`
- Modify: `Argo/Domain/IslandAgentModels.swift`
- Modify: `Argo/Support/IslandNotificationState.swift`
- Modify: `Argo/Support/IslandResponseDispatcher.swift`

**Interfaces:**
- Produces: `IslandQuestionPrompt.answerDisplayText(responseText:label:) -> String?`
- Produces: `IslandNotificationState.answerQuestion(sessionID:responseText:label:at:)`
- Consumes: existing `IslandSessionState.answerQuestion(sessionID:response:at:)`

- [ ] **Step 1: Write the failing dispatcher assertion**

In `Tests/IslandResponseDispatcherTests.swift`, extend `testRespondToClaudeHookSessionResolvesPendingHookInsteadOfSendingPaneText` after the existing phase assertion:

```swift
XCTAssertNil(state.sessionState.session(id: "claude-session")?.questionPrompt)
XCTAssertEqual(state.sessionState.session(id: "claude-session")?.summary, "Answered: Staging")
```

Current expected result before implementation: FAIL because `IslandResponseDispatcher` posts summary `Response sent.`.

- [ ] **Step 2: Run the focused failing test**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandResponseDispatcherTests/testRespondToClaudeHookSessionResolvesPendingHookInsteadOfSendingPaneText \
  test
```

Expected: FAIL with summary mismatch, showing `Response sent.` instead of `Answered: Staging`.

- [ ] **Step 3: Add question answer matching helper**

In `Argo/Domain/IslandAgentModels.swift`, add this nonisolated extension after `IslandQuestionPromptResponse`:

```swift
nonisolated extension IslandQuestionPrompt {
    func answerDisplayText(responseText: String? = nil, label: String? = nil) -> String? {
        let trimmedResponse = responseText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        return options.first { option in
            option.responseText == responseText
                || option.responseText.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedResponse
                || option.label == label
                || option.label.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedLabel
        }?.label ?? trimmedLabel?.nilIfEmpty ?? trimmedResponse?.nilIfEmpty
    }
}
```

- [ ] **Step 4: Add unified question answer entry point**

In `Argo/Support/IslandNotificationState.swift`, add this method after `updateSessionError(id:error:)`:

```swift
func answerQuestion(
    sessionID: String,
    responseText: String? = nil,
    label: String? = nil,
    at timestamp: Date? = nil
) {
    guard let session = sessionState.session(id: sessionID),
          session.phase == .waitingForAnswer else { return }
    let answer = session.questionPrompt?.answerDisplayText(
        responseText: responseText,
        label: label
    ) ?? ""
    sessionState.answerQuestion(
        sessionID: sessionID,
        response: IslandQuestionPromptResponse(answer: answer),
        at: timestamp ?? now()
    )
}
```

- [ ] **Step 5: Route Claude question resolve through unified entry point**

In `Argo/Support/IslandResponseDispatcher.swift`, change the `ClaudeHookInteractionRegistry.shared.resolve(sessionID:responseText:)` success branch:

```swift
if ClaudeHookInteractionRegistry.shared.resolve(sessionID: sessionID, responseText: text) {
    let mirroredApprovalError: String? = {
        guard session.phase == .waitingForApproval else { return nil }
        guard let paneID = session.identity.paneID else {
            return "Pane is no longer available."
        }
        return sendText(paneID, text) ? nil : "Could not send response to the pane."
    }()

    if session.phase == .waitingForAnswer {
        state.answerQuestion(sessionID: sessionID, responseText: text)
    } else {
        state.post(event: .actionableStateResolved(IslandActionableStateResolved(
            sessionID: sessionID,
            summary: "Response sent.",
            timestamp: Date()
        )))
    }
    if let mirroredApprovalError {
        state.updateSessionError(id: sessionID, error: mirroredApprovalError)
    }
    return
}
```

- [ ] **Step 6: Run the focused test again**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandResponseDispatcherTests/testRespondToClaudeHookSessionResolvesPendingHookInsteadOfSendingPaneText \
  test
```

Expected: PASS.

---

### Task 2: Claude hook completion payload extracts selected answer

**Files:**
- Modify: `Tests/ClaudeHookNotifyBridgeTests.swift`
- Modify: `Argo/Services/AgentNotify/ClaudeHookNotifyBridge.swift`

**Interfaces:**
- Produces: `ClaudeHookEventName.postToolUse`
- Produces: `ClaudeHookPayload.toolResponse`
- Produces: `ClaudeHookPayload.questionCompletionAnswerLabel`

- [ ] **Step 1: Write the failing bridge test**

In `Tests/ClaudeHookNotifyBridgeTests.swift`, add:

```swift
func testAskUserQuestionPostToolUseExtractsAnswerLabel() throws {
    let json = """
    {
      "cwd": "/tmp/demo",
      "hook_event_name": "PostToolUse",
      "session_id": "claude-session-post",
      "tool_name": "AskUserQuestion",
      "tool_input": {
        "questions": [
          {
            "question": "Pick a deploy target?",
            "header": "Target",
            "options": [
              { "label": "Production" },
              { "label": "Staging" }
            ]
          }
        ],
        "answers": {
          "Pick a deploy target?": "Staging"
        }
      },
      "tool_response": {
        "answers": {
          "Pick a deploy target?": "Staging"
        }
      }
    }
    """

    let payload = try JSONDecoder().decode(ClaudeHookPayload.self, from: Data(json.utf8))

    XCTAssertEqual(payload.hookEventName, .postToolUse)
    XCTAssertEqual(payload.questionCompletionAnswerLabel, "Staging")
}
```

Expected before implementation: FAIL because `postToolUse`, `toolResponse`, and `questionCompletionAnswerLabel` do not exist.

- [ ] **Step 2: Run the focused failing test**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/ClaudeHookNotifyBridgeTests/testAskUserQuestionPostToolUseExtractsAnswerLabel \
  test
```

Expected: compile failure or test failure for missing symbols.

- [ ] **Step 3: Extend hook event and payload decode**

In `Argo/Services/AgentNotify/ClaudeHookNotifyBridge.swift`, update `ClaudeHookEventName` and `ClaudeHookPayload`:

```swift
nonisolated enum ClaudeHookEventName: String, Codable, Equatable, Sendable {
    case permissionRequest = "PermissionRequest"
    case postToolUse = "PostToolUse"
    case other

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = ClaudeHookEventName(rawValue: value) ?? .other
    }
}
```

Add a property and coding key:

```swift
var toolResponse: ClaudeHookJSONValue?

enum CodingKeys: String, CodingKey {
    case cwd
    case hookEventName = "hook_event_name"
    case sessionID = "session_id"
    case toolName = "tool_name"
    case toolInput = "tool_input"
    case toolResponse = "tool_response"
    case permissionSuggestions = "permission_suggestions"
    case message
    case title
}
```

- [ ] **Step 4: Add answer extraction helper**

In the existing `nonisolated extension ClaudeHookPayload`, add:

```swift
var questionCompletionAnswerLabel: String? {
    guard hookEventName == .postToolUse,
          toolName == "AskUserQuestion" else { return nil }
    return Self.firstAnswerLabel(in: toolInput) ?? Self.firstAnswerLabel(in: toolResponse)
}

private static func firstAnswerLabel(in value: ClaudeHookJSONValue?) -> String? {
    guard case let .object(object) = value else { return nil }
    if case let .object(answers)? = object["answers"] {
        for answer in answers.values {
            if let value = answer.stringValue?.nilIfEmpty {
                return value
            }
        }
    }
    for key in ["answer", "label", "content"] {
        if let value = object[key]?.stringValue?.nilIfEmpty {
            return value
        }
    }
    if case let .array(content)? = object["content"] {
        for item in content {
            if let value = item.stringValue?.nilIfEmpty {
                return value
            }
            if case let .object(itemObject) = item,
               let value = itemObject["text"]?.stringValue?.nilIfEmpty {
                return value
            }
        }
    }
    return nil
}
```

- [ ] **Step 5: Run the focused bridge test again**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/ClaudeHookNotifyBridgeTests/testAskUserQuestionPostToolUseExtractsAnswerLabel \
  test
```

Expected: PASS.

---

### Task 3: Claude 外部完成事件清理灵动岛 waiting question

**Files:**
- Modify: `Tests/AgentNotifyServerTests.swift`
- Modify: `Argo/Services/AgentNotify/AgentNotifyServer.swift`

**Interfaces:**
- Consumes: `ClaudeHookPayload.questionCompletionAnswerLabel`
- Consumes: `IslandNotificationState.shared.answerQuestion(sessionID:label:)`

- [ ] **Step 1: Write the failing control socket test**

In `Tests/AgentNotifyServerTests.swift`, add an `@MainActor` test before the helper classes:

```swift
@MainActor
func testClaudeHookQuestionPostToolUseClearsIslandQuestion() throws {
    IslandNotificationState.shared.clearAll()
    defer { IslandNotificationState.shared.clearAll() }

    let socketURL = try XCTUnwrap(temporarySocketURL)
    let sessionID = "claude-post-answer"
    IslandNotificationState.shared.post(event: .sessionStarted(IslandSessionStarted(
        sessionID: sessionID,
        identity: IslandSessionIdentity(
            workspaceID: UUID(),
            worktreePath: "/tmp/demo",
            paneID: nil,
            sourceID: sessionID
        ),
        title: "Pick a deploy target?",
        tool: .claudeCode,
        initialPhase: .running,
        summary: "Started",
        timestamp: Date(timeIntervalSince1970: 10)
    )))
    IslandNotificationState.shared.post(event: .questionAsked(IslandQuestionAsked(
        sessionID: sessionID,
        prompt: IslandQuestionPrompt(
            title: "Pick a deploy target?",
            options: [
                IslandQuestionOption(label: "Production", responseText: "1\n"),
                IslandQuestionOption(label: "Staging", responseText: "2\n")
            ]
        ),
        timestamp: Date(timeIntervalSince1970: 11)
    )))

    let server = AgentNotifyControlServer(
        socketURL: socketURL,
        host: nil,
        tokenResolver: { nil },
        executablePathProvider: { "/debug/Argo.app/Contents/MacOS/Argo" }
    )
    try server.start()
    defer { server.stop() }

    var frame = try JSONSerialization.data(withJSONObject: [
        "cmd": "claude-hook",
        "cwd": "/tmp/demo",
        "hook_event_name": "PostToolUse",
        "session_id": sessionID,
        "tool_name": "AskUserQuestion",
        "tool_input": [
            "answers": [
                "Pick a deploy target?": "Staging",
            ],
        ],
    ], options: [.sortedKeys])
    frame.append(0x0A)

    XCTAssertNotNil(try ArgoControlClient.sendRaw(
        frame: frame,
        socketURL: socketURL,
        timeout: 1.0
    ))

    waitUntilIslandSession(sessionID: sessionID, phase: .running)
    let session = try XCTUnwrap(IslandNotificationState.shared.sessionState.session(id: sessionID))
    XCTAssertNil(session.questionPrompt)
    XCTAssertEqual(session.summary, "Answered: Staging")
}
```

Add this helper method inside `AgentNotifyServerTests`:

```swift
@MainActor
private func waitUntilIslandSession(
    sessionID: String,
    phase: IslandSessionPhase,
    timeout: TimeInterval = 3.0,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if IslandNotificationState.shared.sessionState.session(id: sessionID)?.phase == phase {
            return
        }
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
    XCTFail("Timed out waiting for island session \(sessionID) to reach \(phase)", file: file, line: line)
}
```

Expected before implementation: FAIL because `PostToolUse` is currently ignored by `ArgoClaudeHookControlHandler`.

- [ ] **Step 2: Run the focused failing server test**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/AgentNotifyServerTests/testClaudeHookQuestionPostToolUseClearsIslandQuestion \
  test
```

Expected: FAIL or timeout waiting for `.running`.

- [ ] **Step 3: Handle PostToolUse question completion in control handler**

In `Argo/Services/AgentNotify/AgentNotifyServer.swift`, update `ArgoClaudeHookControlHandler.dispatch(frame:hostBox:)` before the existing `guard let notifyRequest = ClaudeHookNotifyBridge.notifyRequest(from: controlRequest)` success return:

```swift
if let answerLabel = controlRequest.payload.questionCompletionAnswerLabel {
    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            IslandNotificationState.shared.answerQuestion(
                sessionID: controlRequest.payload.sessionID,
                label: answerLabel
            )
        }
    }
    return ClaudeHookNotifyBridge.encodeControlResponse(.success(stdout: nil))
}
```

Then keep the existing `notifyRequest` path unchanged for `PermissionRequest`.

- [ ] **Step 4: Run the focused server test again**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/AgentNotifyServerTests/testClaudeHookQuestionPostToolUseClearsIslandQuestion \
  test
```

Expected: PASS.

---

### Task 4: Full regression verification

**Files:**
- No code changes unless tests expose a regression.

**Interfaces:**
- Consumes all previous task outputs.

- [ ] **Step 1: Run focused island / hook tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/IslandResponseDispatcherTests \
  -only-testing:ArgoTests/ClaudeHookNotifyBridgeTests \
  -only-testing:ArgoTests/AgentNotifyServerTests \
  test
```

Expected: PASS.

- [ ] **Step 2: Run full test suite**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  test
```

Expected: PASS.

- [ ] **Step 3: Run Debug build**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected: PASS.

- [ ] **Step 4: Manual/runtime verification**

If an app build is available and launching is practical, use computer/browser automation or direct app interaction to verify:

```text
1. Start Argo.
2. Open a Claude session that triggers AskUserQuestion.
3. Select an option in Claude.
4. Confirm the island leaves the option page and shows Answered: <option>.
5. Trigger another AskUserQuestion and select through the island.
6. Confirm Claude continues and the island shows Answered: <option>.
```

If full UI automation is not practical in the current environment, use the control socket test from Task 3 as authoritative runtime coverage for the external hook completion path, and report the limitation clearly.

- [ ] **Step 5: Commit implementation**

After tests pass:

```bash
git add Argo/Domain/IslandAgentModels.swift \
        Argo/Support/IslandNotificationState.swift \
        Argo/Support/IslandResponseDispatcher.swift \
        Argo/Services/AgentNotify/ClaudeHookNotifyBridge.swift \
        Argo/Services/AgentNotify/AgentNotifyServer.swift \
        Tests/IslandResponseDispatcherTests.swift \
        Tests/ClaudeHookNotifyBridgeTests.swift \
        Tests/AgentNotifyServerTests.swift
git commit -m "fix(island): answer sync"
```

Expected: commit succeeds.
