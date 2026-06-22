//
//  IslandSurface.swift
//  Argo
//
//  Author: krystal
//

import Foundation

nonisolated enum IslandSurface: Equatable {
    case sessionList(actionableSessionID: String? = nil)

    var sessionID: String? {
        switch self {
        case let .sessionList(actionableSessionID):
            actionableSessionID
        }
    }

    var isNotificationCard: Bool {
        sessionID != nil
    }

    static func notificationSurface(for event: IslandSessionEvent) -> IslandSurface? {
        switch event {
        case let .permissionRequested(payload):
            .sessionList(actionableSessionID: payload.sessionID)
        case let .questionAsked(payload):
            .sessionList(actionableSessionID: payload.sessionID)
        case let .sessionCompleted(payload):
            .sessionList(actionableSessionID: payload.sessionID)
        case .sessionStarted, .activityUpdated, .actionableStateResolved:
            nil
        }
    }

    func matchesCurrentState(of session: IslandAgentSession?) -> Bool {
        guard sessionID != nil else { return true }
        guard let session else { return false }

        return switch session.phase {
        case .waitingForApproval:
            session.permissionRequest != nil
        case .waitingForAnswer:
            session.questionPrompt != nil
        case .completed, .failed:
            true
        case .running, .stale:
            false
        }
    }
}
