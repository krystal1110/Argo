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

    @MainActor
    func testControllerActiveSurfaceSessionReturnsOnlyMatchingActionableSession() {
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

        XCTAssertEqual(controller.activeSurfaceSession?.id, "approval")

        state.post(event: .actionableStateResolved(IslandActionableStateResolved(
            sessionID: "approval",
            summary: "Response sent.",
            timestamp: Date(timeIntervalSince1970: 12)
        )))

        XCTAssertNil(controller.activeSurfaceSession)
    }

    @MainActor
    func testShowAllSessionsFromNotificationCardReturnsToSessionList() {
        let controller = IslandPanelController.shared
        controller.surface = .sessionList(actionableSessionID: "approval")
        controller.state.selectedTab = .workspaces
        controller.state.isExpanded = false
        defer {
            controller.state.clearAll()
            controller.surface = .sessionList()
        }

        controller.showAllSessionsFromNotificationCard()

        XCTAssertEqual(controller.surface, .sessionList())
        XCTAssertEqual(controller.state.selectedTab, .sessions)
        XCTAssertTrue(controller.state.isExpanded)
    }

    @MainActor
    func testNotificationCardUsesCompactExpandedHeight() {
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

        XCTAssertLessThan(controller.currentExpandedPanelHeight, 500)
        XCTAssertGreaterThan(controller.currentExpandedPanelHeight, 180)

        controller.surface = .sessionList()

        XCTAssertEqual(controller.currentExpandedPanelHeight, 500)
    }

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
}
