//
//  SidebarContextMenuPolicy.swift
//  Argo
//
//  Author: krystal
//

import Foundation

enum SidebarContextMenuPolicy {
    static func canRevealInFinder(for workspaces: [WorkspaceModel]) -> Bool {
        !workspaces.isEmpty && workspaces.allSatisfy { !$0.isRemote }
    }

    static func canFetchRepositories(for workspaces: [WorkspaceModel]) -> Bool {
        !workspaces.isEmpty && workspaces.allSatisfy(\.supportsLocalRepositoryFeatures)
    }

    static func canRunWorkspaceScript(in workspace: WorkspaceModel) -> Bool {
        canRunLocalScript(workspace.runScript, in: workspace)
    }

    static func canRunSetupScript(in workspace: WorkspaceModel) -> Bool {
        canRunLocalScript(workspace.setupScript, in: workspace)
    }

    private static func canRunLocalScript(_ script: String, in workspace: WorkspaceModel) -> Bool {
        !workspace.isRemote && !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
