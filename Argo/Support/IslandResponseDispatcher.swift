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
}
