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
