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
