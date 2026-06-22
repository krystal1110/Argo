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
}
