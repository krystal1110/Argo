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

    func testActionableResolutionClearsStaleApprovalPayloadEvenAfterSessionIsRunning() {
        let id = "pane:abc"
        var state = IslandSessionState(sessions: [
            IslandAgentSession(
                id: id,
                identity: makeIdentity(sessionID: id),
                title: "Resolve",
                tool: .codex,
                phase: .running,
                summary: "Running",
                updatedAt: Date(timeIntervalSince1970: 20),
                firstSeenAt: Date(timeIntervalSince1970: 10),
                permissionRequest: IslandPermissionRequest(
                    title: "Approval needed",
                    summary: "Run tests",
                    affectedPath: "/tmp/repo",
                    primaryActionTitle: "Allow",
                    secondaryActionTitle: "Deny",
                    allowResponseText: "1\n",
                    denyResponseText: "2\n"
                )
            )
        ])

        state.apply(.actionableStateResolved(IslandActionableStateResolved(
            sessionID: id,
            summary: "Response sent.",
            timestamp: Date(timeIntervalSince1970: 30)
        )))

        let session = state.session(id: id)
        XCTAssertEqual(session?.phase, .running)
        XCTAssertNil(session?.permissionRequest)
        XCTAssertNil(session?.questionPrompt)
        XCTAssertEqual(session?.summary, "Response sent.")
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
