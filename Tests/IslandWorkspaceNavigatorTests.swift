//
//  IslandWorkspaceNavigatorTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

@MainActor
final class IslandWorkspaceNavigatorTests: XCTestCase {
    func testNavigateFocusesWorkspaceWorktreeAndPane() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let workspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
        workspace.createPane(splitAxis: .vertical)
        let targetPaneID = try XCTUnwrap(workspace.paneOrder.last)
        let store = WorkspaceStore(persistsWorkspaceState: false)
        store.workspaces = [workspace]

        var didPresent = false
        let navigator = IslandWorkspaceNavigator(
            stores: { [store] },
            present: { presented in
                XCTAssertTrue(presented === store)
                didPresent = true
            }
        )

        let result = navigator.navigate(
            workspaceID: workspace.id,
            worktreePath: workspace.activeWorktreePath,
            paneID: targetPaneID
        )

        XCTAssertEqual(result, .focusedPane)
        XCTAssertEqual(store.selectedWorkspaceID, workspace.id)
        XCTAssertEqual(workspace.sessionController.focusedPaneID, targetPaneID)
        XCTAssertTrue(didPresent)
    }

    func testNavigateReturnsPaneMissingButStillSelectsWorkspace() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let workspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
        let store = WorkspaceStore(persistsWorkspaceState: false)
        store.workspaces = [workspace]

        let navigator = IslandWorkspaceNavigator(stores: { [store] }, present: { _ in })

        let result = navigator.navigate(
            workspaceID: workspace.id,
            worktreePath: workspace.activeWorktreePath,
            paneID: UUID()
        )

        XCTAssertEqual(result, .paneMissing)
        XCTAssertEqual(store.selectedWorkspaceID, workspace.id)
    }

    func testNavigateReturnsWorkspaceMissing() {
        let navigator = IslandWorkspaceNavigator(stores: { [] }, present: { _ in XCTFail("present should not run") })

        let result = navigator.navigate(workspaceID: UUID(), worktreePath: nil, paneID: nil)

        XCTAssertEqual(result, .workspaceMissing)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-island-nav-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
