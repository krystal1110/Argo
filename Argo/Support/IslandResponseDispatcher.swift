//
//  IslandResponseDispatcher.swift
//  Argo
//
//  Author: krystal
//

import Foundation

@MainActor
struct IslandResponseDispatcher {
    let state: IslandNotificationState
    let sendText: (UUID, String) -> Bool

    func respond(to itemID: UUID, with text: String) {
        guard let item = state.items.first(where: { $0.id == itemID }) else { return }
        guard let paneID = item.paneID else {
            state.update(id: itemID, status: item.status, lastError: "Pane is no longer available.")
            return
        }

        guard sendText(paneID, text) else {
            state.update(id: itemID, status: item.status, lastError: "Could not send response to the pane.")
            return
        }

        state.update(id: itemID, status: .running, lastError: nil)
    }

    func respond(toSessionID sessionID: String, with text: String) {
        guard let session = state.sessionState.session(id: sessionID) else { return }
        if ClaudeHookInteractionRegistry.shared.resolve(sessionID: sessionID, responseText: text) {
            let mirroredApprovalError: String? = {
                guard session.phase == .waitingForApproval else { return nil }
                guard let paneID = session.identity.paneID else {
                    return "Pane is no longer available."
                }
                return sendText(paneID, text) ? nil : "Could not send response to the pane."
            }()

            state.post(event: .actionableStateResolved(IslandActionableStateResolved(
                sessionID: sessionID,
                summary: "Response sent.",
                timestamp: Date()
            )))
            if let mirroredApprovalError {
                state.updateSessionError(id: sessionID, error: mirroredApprovalError)
            }
            return
        }

        guard let paneID = session.identity.paneID else {
            state.markSessionStale(id: sessionID, error: "Pane is no longer available.")
            return
        }

        guard sendText(paneID, text) else {
            state.updateSessionError(id: sessionID, error: "Could not send response to the pane.")
            return
        }

        state.post(event: .actionableStateResolved(IslandActionableStateResolved(
            sessionID: sessionID,
            summary: "Response sent.",
            timestamp: Date()
        )))
    }
}
