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

    func testLegacyItemPostMirrorsSessionState() {
        let workspaceID = UUID()
        let paneID = UUID()
        let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 10) })

        state.post(item: makeItem(
            workspaceID: workspaceID,
            paneID: paneID,
            sourceID: "approval",
            title: "Approve",
            status: .waitingForApproval
        ))

        XCTAssertEqual(state.sessions.map(\.id), ["approval"])
        XCTAssertEqual(state.spotlightSession?.title, "Approve")
        XCTAssertEqual(state.attentionCount, 1)
    }

    func testClearAllClearsSessionState() {
        let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 10) })

        state.post(event: .sessionStarted(IslandSessionStarted(
            sessionID: "s",
            identity: IslandSessionIdentity(workspaceID: UUID(), worktreePath: "/tmp/repo", paneID: nil, sourceID: "s"),
            title: "Running",
            tool: .codex,
            initialPhase: .running,
            summary: "Running",
            timestamp: Date(timeIntervalSince1970: 10)
        )))
        state.clearAll()

        XCTAssertTrue(state.sessions.isEmpty)
    }

    func testClearCompletedDismissesSessionOnlyCompletedItems() {
        let state = IslandNotificationState(now: { Date(timeIntervalSince1970: 10) })
        let identity = IslandSessionIdentity(workspaceID: UUID(), worktreePath: "/tmp/repo", paneID: nil, sourceID: "done")
        state.post(event: .sessionStarted(IslandSessionStarted(
            sessionID: "done",
            identity: identity,
            title: "Done",
            tool: .codex,
            initialPhase: .completed,
            summary: "Done",
            timestamp: Date(timeIntervalSince1970: 10)
        )))
        state.post(event: .sessionStarted(IslandSessionStarted(
            sessionID: "running",
            identity: IslandSessionIdentity(workspaceID: UUID(), worktreePath: "/tmp/repo", paneID: nil, sourceID: "running"),
            title: "Running",
            tool: .codex,
            initialPhase: .running,
            summary: "Running",
            timestamp: Date(timeIntervalSince1970: 11)
        )))

        state.clearCompleted()

        XCTAssertTrue(state.sessionState.session(id: "done")?.isDismissed == true)
        XCTAssertFalse(state.sessionState.session(id: "running")?.isDismissed == true)
    }

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

    func testWorkspaceRichNotifyCreatesApprovalSession() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let workspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
        let paneID = UUID()
        let request = AgentNotifyRequest(
            title: "Approve command",
            body: "Run tests?",
            paneID: paneID.uuidString,
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

        IslandNotificationState.shared.clearAll()
        defer { IslandNotificationState.shared.clearAll() }
        workspace.postAgentNotification(request: request, paneID: paneID)

        let session = try XCTUnwrap(IslandNotificationState.shared.sessionState.session(id: "session-1"))
        XCTAssertEqual(session.identity.paneID, paneID)
        XCTAssertEqual(session.identity.sourceID, "approval-1")
        XCTAssertEqual(session.tool, .codex)
        XCTAssertEqual(session.phase, .waitingForApproval)
        XCTAssertEqual(session.permissionRequest?.summary, "Run tests?")
        XCTAssertEqual(session.permissionRequest?.allowResponseText, "1\n")
        XCTAssertEqual(session.permissionRequest?.denyResponseText, "2\n")
        XCTAssertEqual(session.currentTool, "exec_command")
        XCTAssertEqual(session.commandPreview, "xcodebuild test")
    }

    func testWorkspaceRichNotifyUsesToolFieldWhenAgentIsMissing() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let workspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
        let request = AgentNotifyRequest(
            title: "Running",
            toolName: "Codex",
            kind: .activity,
            sessionID: "session-tool"
        )

        IslandNotificationState.shared.clearAll()
        defer { IslandNotificationState.shared.clearAll() }
        workspace.postAgentNotification(request: request, paneID: nil)

        let session = try XCTUnwrap(IslandNotificationState.shared.sessionState.session(id: "session-tool"))
        XCTAssertEqual(session.tool, .codex)
    }

    func testNavigateToItemMarksItemStaleWhenPaneIsMissing() {
        let state = IslandNotificationState.shared
        let item = makeItem(status: .waitingForAnswer)
        let previousTapHandler = WorkspaceNotificationCenter.shared.onNotificationTapped

        state.clearAll()
        defer {
            state.clearAll()
            WorkspaceNotificationCenter.shared.onNotificationTapped = previousTapHandler
        }

        state.post(item: item)
        WorkspaceNotificationCenter.shared.onNotificationTapped = { workspaceID, worktreePath, paneID in
            XCTAssertEqual(workspaceID, item.workspaceID)
            XCTAssertEqual(worktreePath, item.worktreePath)
            XCTAssertEqual(paneID, item.paneID)
            return .paneMissing
        }

        IslandPanelController.shared.navigateToItem(item)

        XCTAssertEqual(state.items.count, 1)
        XCTAssertEqual(state.items[0].id, item.id)
        XCTAssertEqual(state.items[0].status, .stale)
        XCTAssertEqual(state.items[0].lastError, "Pane is no longer available.")
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
