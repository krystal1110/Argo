//
//  IslandWorkspaceNavigator.swift
//  Argo
//
//  Author: krystal
//

import Foundation

enum IslandNavigationResult: Equatable {
    case focusedPane
    case focusedWorkspace
    case workspaceMissing
    case paneMissing
}

@MainActor
struct IslandWorkspaceNavigator {
    let stores: () -> [WorkspaceStore]
    let present: (WorkspaceStore) -> Void

    func navigate(
        workspaceID: UUID,
        worktreePath: String?,
        paneID: UUID?
    ) -> IslandNavigationResult {
        for store in stores() {
            guard let workspace = store.workspaces.first(where: { $0.id == workspaceID }) else {
                continue
            }

            present(store)
            store.selectWorkspace(workspace)

            if let worktreePath, workspace.activeWorktreePath != worktreePath {
                workspace.switchToWorktree(path: worktreePath, restartRunning: false)
            }

            guard let paneID else {
                return .focusedWorkspace
            }

            guard workspace.sessionController.session(for: paneID) != nil else {
                return .paneMissing
            }

            workspace.focusPane(paneID)
            return .focusedPane
        }

        return .workspaceMissing
    }
}
