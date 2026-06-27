//
//  WorkspaceSessionControllerTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

@MainActor
final class WorkspaceSessionControllerTests: XCTestCase {
    override func tearDown() {
        AgentStatusStore.shared.clearAll()
        super.tearDown()
    }

    func testSendProgrammaticTextFocusesTargetPane() {
        let firstPaneID = UUID()
        let secondPaneID = UUID()
        let controller = WorkspaceSessionController(
            workspaceID: UUID(),
            paneSnapshots: [
                PaneSnapshot.makeDefault(id: firstPaneID, cwd: "/tmp/argo-first-pane"),
                PaneSnapshot.makeDefault(id: secondPaneID, cwd: "/tmp/argo-second-pane"),
            ]
        )

        XCTAssertEqual(controller.focusedPaneID, firstPaneID)

        let sent = controller.sendProgrammaticText("Staging\n", to: secondPaneID)

        XCTAssertTrue(sent)
        XCTAssertEqual(controller.previousFocusedPaneID, firstPaneID)
        XCTAssertEqual(controller.focusedPaneID, secondPaneID)
    }

    func testSendProgrammaticTextReturnsFalseForMissingPane() {
        let paneID = UUID()
        let controller = WorkspaceSessionController(
            workspaceID: UUID(),
            paneSnapshots: [
                PaneSnapshot.makeDefault(id: paneID, cwd: "/tmp/argo-existing-pane"),
            ]
        )

        let sent = controller.sendProgrammaticText("1\n", to: UUID())

        XCTAssertFalse(sent)
        XCTAssertEqual(controller.focusedPaneID, paneID)
    }

    func testClosingPaneClearsAgentStatus() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-agent-status-close-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let workspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
        let firstPaneID = try XCTUnwrap(workspace.paneOrder.first)
        workspace.createPane(splitAxis: .vertical)
        XCTAssertGreaterThan(workspace.paneOrder.count, 1)

        AgentStatusStore.shared.update(
            pane: firstPaneID,
            state: .waiting,
            title: "Approve command",
            agentName: "Codex"
        )
        XCTAssertEqual(AgentStatusStore.shared.state(for: firstPaneID), .waiting)

        workspace.closePane(firstPaneID)

        XCTAssertNil(AgentStatusStore.shared.state(for: firstPaneID))
    }
}
