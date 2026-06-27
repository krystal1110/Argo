//
//  ArgoDesktopApplication+ControlHost.swift
//  Argo
//
//  Author: krystal
//

import Foundation

/// Glue between the IPC dispatcher and the live application state.
///
/// Each handler converts a wire-shape request into a real action against
/// the desktop application or its workspace stores. Most actions are
/// synchronous from the caller's perspective; long-running operations
/// (e.g. `openRepositoryWorkspace`) are kicked off as detached Tasks and
/// reflected to the user via the sidebar / `argo session list`.
extension ArgoDesktopApplication: ArgoControlHost {
    func handleNotify(_ request: AgentNotifyRequest) {
        routeAgentNotification(request)
    }

    func handleStatus(_ request: ArgoStatusRequest) {
        let state = AgentReportedState(cliValue: request.state) ?? .running
        let paneID = request.pane.flatMap { UUID(uuidString: $0) }
        routeAgentStatus(
            state: state,
            paneID: paneID,
            title: request.title,
            agentName: request.agentName
        )
    }

    func handleOpen(_ request: ArgoOpenRequest) -> ArgoControlResponse {
        guard let store = activeWorkspaceStore else {
            return .failure("no-active-window")
        }
        let path = request.repo
        let worktreePath = request.worktree
        Task { @MainActor in
            do {
                try await store.openRepositoryWorkspace(at: path, persistAfterChange: true)
                if let worktreePath,
                   let workspace = store.workspaces.first(where: {
                       $0.supportsRepositoryFeatures && $0.repositoryRoot == path
                   }),
                   workspace.activeWorktreePath != worktreePath {
                    workspace.switchToWorktree(path: worktreePath, restartRunning: false)
                }
            } catch {
                NSLog("[Argo] control open failed: %@", String(describing: error))
            }
        }
        return .success
    }

    func handleSplit(_ request: ArgoSplitRequest) -> ArgoControlResponse {
        let axis: PaneSplitAxis = (request.axis?.lowercased() == "horizontal") ? .horizontal : .vertical

        if let paneIDString = request.pane, let paneID = UUID(uuidString: paneIDString) {
            for store in allWorkspaceStores {
                for workspace in store.workspaces
                where workspace.sessionController.session(for: paneID) != nil {
                    workspace.sessionController.focusedPaneID = paneID
                    store.splitFocusedPane(in: workspace, axis: axis)
                    return .success
                }
            }
            return .failure("pane-not-found")
        }

        splitFocusedPane(axis: axis)
        return .success
    }

    func handleSendKeys(_ request: ArgoSendKeysRequest) -> ArgoControlResponse {
        let resolvedPane: UUID?
        if let paneIDString = request.pane, let paneID = UUID(uuidString: paneIDString) {
            resolvedPane = paneID
        } else {
            resolvedPane = activeWorkspaceStore?.selectedWorkspace?.sessionController.focusedPaneID
        }
        guard let resolvedPane else {
            return .failure("no-pane")
        }
        for store in allWorkspaceStores {
            for workspace in store.workspaces {
                if workspace.sessionController.sendProgrammaticText(request.text, to: resolvedPane) {
                    return .success
                }
            }
        }
        return .failure("pane-not-found")
    }

    func handleSessionList(_ request: ArgoSessionListRequest) -> ArgoControlResponse {
        var sessions: [ArgoControlSession] = []
        for store in allWorkspaceStores {
            for workspace in store.workspaces where workspace.isActive {
                for (paneID, session) in workspace.sessionController.sessions {
                    sessions.append(
                        ArgoControlSession(
                            workspaceID: workspace.id.uuidString.lowercased(),
                            workspaceName: workspace.name,
                            paneID: paneID.uuidString.lowercased(),
                            cwd: session.effectiveWorkingDirectory,
                            branch: workspace.supportsRepositoryFeatures ? workspace.currentBranch : nil,
                            listeningPorts: workspace.listeningPorts,
                            status: AgentStatusStore.shared.state(for: paneID)?.rawValue
                        )
                    )
                }
            }
        }
        return ArgoControlResponse(ok: true, error: nil, sessions: sessions)
    }

    func handleRead(_ request: ArgoReadRequest) -> ArgoControlResponse {
        let resolvedPane: UUID?
        if let paneIDString = request.pane, let paneID = UUID(uuidString: paneIDString) {
            resolvedPane = paneID
        } else {
            resolvedPane = activeWorkspaceStore?.selectedWorkspace?.sessionController.focusedPaneID
        }
        guard let resolvedPane else {
            return .failure("no-pane")
        }

        for store in allWorkspaceStores {
            for workspace in store.workspaces {
                guard let session = workspace.sessionController.session(for: resolvedPane) else { continue }
                guard let raw = session.readScreenText(scrollback: request.scrollback ?? false) else {
                    return .failure("read-unavailable")
                }
                let text = Self.trimScreenText(raw, lastLines: request.lines)
                let lineCount = text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
                return ArgoControlResponse(ok: true, text: text, lineCount: lineCount)
            }
        }
        return .failure("pane-not-found")
    }

    func handleAgents(_ request: ArgoAgentsRequest) -> ArgoControlResponse {
        ArgoControlResponse(ok: true, agents: [])
    }

    static func trimScreenText(_ raw: String, lastLines: Int?) -> String {
        var lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeLast()
        }
        if let lastLines, lastLines > 0, lines.count > lastLines {
            lines = Array(lines.suffix(lastLines))
        }
        return lines.joined(separator: "\n")
    }
}
