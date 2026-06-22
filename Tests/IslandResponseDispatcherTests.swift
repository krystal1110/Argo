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
            prompt: IslandQuestionPrompt(
                title: "Continue?",
                options: [IslandQuestionOption(label: "Yes", responseText: "yes\n")]
            ),
            timestamp: Date(timeIntervalSince1970: 11)
        )))
        var sent: [(UUID, String)] = []
        let dispatcher = IslandResponseDispatcher(
            state: state,
            sendText: { pane, text in
                sent.append((pane, text))
                return true
            }
        )

        dispatcher.respond(toSessionID: sessionID, with: "yes\n")

        XCTAssertEqual(sent.first?.0, paneID)
        XCTAssertEqual(sent.first?.1, "yes\n")
        XCTAssertEqual(state.sessionState.session(id: sessionID)?.phase, .running)
    }

    func testRespondToClaudeHookSessionResolvesPendingHookInsteadOfSendingPaneText() throws {
        ClaudeHookInteractionRegistry.shared.clearAll()
        defer { ClaudeHookInteractionRegistry.shared.clearAll() }

        let hookJSON = """
        {
          "cwd": "/tmp/demo",
          "hook_event_name": "PermissionRequest",
          "session_id": "claude-session",
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
            ]
          }
        }
        """
        let payload = try JSONDecoder().decode(ClaudeHookPayload.self, from: Data(hookJSON.utf8))
        let request = try XCTUnwrap(ClaudeHookNotifyBridge.notifyRequest(from: payload, paneID: "pane-id"))
        let pending = try XCTUnwrap(ClaudeHookInteractionRegistry.shared.register(payload: payload, request: request))

        let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 20) })
        let paneID = UUID()
        state.post(event: .sessionStarted(IslandSessionStarted(
            sessionID: "claude-session",
            identity: IslandSessionIdentity(workspaceID: UUID(), worktreePath: "/tmp/demo", paneID: paneID, sourceID: "claude-session"),
            title: request.title,
            tool: .claudeCode,
            initialPhase: .waitingForAnswer,
            summary: request.title,
            timestamp: Date(timeIntervalSince1970: 10)
        )))
        state.post(event: .questionAsked(IslandQuestionAsked(
            sessionID: "claude-session",
            prompt: IslandQuestionPrompt(
                title: request.title,
                options: request.options?.map { IslandQuestionOption(label: $0.label, responseText: $0.responseText) } ?? []
            ),
            timestamp: Date(timeIntervalSince1970: 11)
        )))
        var sent: [(UUID, String)] = []
        let dispatcher = IslandResponseDispatcher(
            state: state,
            sendText: { pane, text in
                sent.append((pane, text))
                return true
            }
        )

        dispatcher.respond(toSessionID: "claude-session", with: "2\n")

        XCTAssertTrue(sent.isEmpty)
        XCTAssertEqual(state.sessionState.session(id: "claude-session")?.phase, .running)
        let result = try XCTUnwrap(pending.wait(timeout: 0.1))
        let stdout = try ClaudeHookNotifyBridge.stdout(for: result)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(stdout.utf8)) as? [String: Any])
        let hookSpecificOutput = try XCTUnwrap(object["hookSpecificOutput"] as? [String: Any])
        let decision = try XCTUnwrap(hookSpecificOutput["decision"] as? [String: Any])
        let updatedInput = try XCTUnwrap(decision["updatedInput"] as? [String: Any])
        let answers = try XCTUnwrap(updatedInput["answers"] as? [String: Any])
        XCTAssertEqual(answers["Pick a deploy target?"] as? String, "Staging")
    }

    func testRespondToClaudeHookApprovalAlsoMirrorsNativePromptText() throws {
        ClaudeHookInteractionRegistry.shared.clearAll()
        defer { ClaudeHookInteractionRegistry.shared.clearAll() }

        let hookJSON = """
        {
          "cwd": "/tmp/demo",
          "hook_event_name": "PermissionRequest",
          "session_id": "claude-approval",
          "tool_name": "Bash",
          "tool_input": {
            "command": "rm -rf /tmp/rmrf-test-again && echo removed",
            "description": "Use rm -rf to remove a test directory"
          }
        }
        """
        let payload = try JSONDecoder().decode(ClaudeHookPayload.self, from: Data(hookJSON.utf8))
        let request = try XCTUnwrap(ClaudeHookNotifyBridge.notifyRequest(from: payload, paneID: "pane-id"))
        let pending = try XCTUnwrap(ClaudeHookInteractionRegistry.shared.register(payload: payload, request: request))

        let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 20) })
        let paneID = UUID()
        state.post(event: .sessionStarted(IslandSessionStarted(
            sessionID: "claude-approval",
            identity: IslandSessionIdentity(workspaceID: UUID(), worktreePath: "/tmp/demo", paneID: paneID, sourceID: "claude-approval"),
            title: request.title,
            tool: .claudeCode,
            initialPhase: .waitingForApproval,
            summary: request.title,
            timestamp: Date(timeIntervalSince1970: 10)
        )))
        state.post(event: .permissionRequested(IslandPermissionRequested(
            sessionID: "claude-approval",
            request: IslandPermissionRequest(
                title: request.title,
                summary: request.body ?? request.title,
                affectedPath: request.affectedPath ?? "",
                actions: request.options?.map {
                    IslandPermissionAction(title: $0.label, responseText: $0.responseText)
                }
            ),
            timestamp: Date(timeIntervalSince1970: 11)
        )))
        var sent: [(UUID, String)] = []
        let dispatcher = IslandResponseDispatcher(
            state: state,
            sendText: { pane, text in
                sent.append((pane, text))
                return true
            }
        )

        dispatcher.respond(toSessionID: "claude-approval", with: "1\n")

        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?.0, paneID)
        XCTAssertEqual(sent.first?.1, "1\n")
        XCTAssertEqual(state.sessionState.session(id: "claude-approval")?.phase, .running)
        let result = try XCTUnwrap(pending.wait(timeout: 0.1))
        let stdout = try ClaudeHookNotifyBridge.stdout(for: result)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(stdout.utf8)) as? [String: Any])
        let hookSpecificOutput = try XCTUnwrap(object["hookSpecificOutput"] as? [String: Any])
        let decision = try XCTUnwrap(hookSpecificOutput["decision"] as? [String: Any])
        XCTAssertEqual(decision["behavior"] as? String, "allow")
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
