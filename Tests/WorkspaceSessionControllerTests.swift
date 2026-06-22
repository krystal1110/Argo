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
}
