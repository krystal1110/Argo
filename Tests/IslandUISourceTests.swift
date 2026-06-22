import XCTest

final class IslandUISourceTests: XCTestCase {
    func testCollapsedViewUsesRightSlotAndSpotlightSession() throws {
        let source = try sourceFile("Argo/UI/Island/IslandCollapsedView.swift")

        XCTAssertTrue(source.contains("state.spotlightSession"))
        XCTAssertTrue(source.contains("IslandRightSlotView"))
    }

    func testExpandedViewUsesGroupedSessionSections() throws {
        let source = try sourceFile("Argo/UI/Island/IslandExpandedView.swift")

        XCTAssertTrue(source.contains("IslandSessionSectionsView"))
        XCTAssertTrue(source.contains("state.prioritySessions"))
    }

    func testExpandedViewHasNotificationCardMode() throws {
        let source = try sourceFile("Argo/UI/Island/IslandExpandedView.swift")

        XCTAssertTrue(source.contains("activeSurfaceSession"))
        XCTAssertTrue(source.contains("showAllSessionsFromNotificationCard"))
    }

    func testSessionRowHasApprovalQuestionAndCompletionBodies() throws {
        let source = try sourceFile("Argo/UI/Island/IslandSessionRow.swift")

        XCTAssertTrue(source.contains("approvalActionBody"))
        XCTAssertTrue(source.contains("questionActionBody"))
        XCTAssertTrue(source.contains("completionActionBody"))
    }

    func testApprovalRowShowsCommandAndAffectedPathContext() throws {
        let source = try sourceFile("Argo/UI/Island/IslandSessionRow.swift")

        XCTAssertTrue(source.contains("approvalCommandPreviewText"))
        XCTAssertTrue(source.contains("approvalAffectedPathText"))
    }

    func testActionRowsUseIslandButtonStyleInsteadOfSystemBorderedButtons() throws {
        let source = try sourceFile("Argo/UI/Island/IslandSessionRow.swift")

        XCTAssertTrue(source.contains("IslandActionButtonStyle"))
        XCTAssertTrue(source.contains("approvalButtonKind(for: action, index: index)"))
        XCTAssertTrue(source.contains(".warning"))
        XCTAssertTrue(source.contains(".primary"))
        XCTAssertTrue(source.contains(".secondary"))
        XCTAssertFalse(source.contains(".buttonStyle(.bordered)"))
    }

    func testApprovalRowRendersAllPermissionActions() throws {
        let source = try sourceFile("Argo/UI/Island/IslandSessionRow.swift")

        XCTAssertTrue(source.contains("session.permissionRequest?.actions"))
        XCTAssertTrue(source.contains("approvalButtonKind"))
        XCTAssertFalse(source.contains("allowResponseText ?? \"1\\n\""))
        XCTAssertFalse(source.contains("denyResponseText ?? \"2\\n\""))
    }

    func testSessionRowsUsePhaseAwareIdentity() throws {
        let source = try sourceFile("Argo/UI/Island/IslandSessionSections.swift")

        XCTAssertTrue(source.contains("sessionRowIdentity(for: session)"))
        XCTAssertTrue(source.contains("session.phase.rawValue"))
    }

    func testPanelCollapsedWidthUsesSpotlightSessionWithoutLegacyForceUnwrap() throws {
        let source = try sourceFile("Argo/UI/Island/IslandPanelController.swift")

        XCTAssertTrue(source.contains("state.spotlightSession"))
        XCTAssertFalse(source.contains("state.latestItem!"))
    }

    func testDynamicIslandSettingsDoesNotShowBetaBadge() throws {
        let source = try sourceFile("Argo/UI/Sheets/SettingsSheet.swift")

        XCTAssertTrue(source.contains("settings.dynamicIsland.enable.toggle"))
        XCTAssertFalse(source.contains("Text(\"Beta\")"))
    }

    private func sourceFile(_ relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repositoryRoot = testsDirectory.deletingLastPathComponent()
        return try String(contentsOf: repositoryRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
