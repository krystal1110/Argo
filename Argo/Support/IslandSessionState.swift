//
//  IslandSessionState.swift
//  Argo
//
//  Author: krystal
//

import Foundation

nonisolated struct IslandSessionState: Equatable, Sendable {
    private(set) var sessionsByID: [String: IslandAgentSession]

    init(sessions: [IslandAgentSession] = []) {
        self.sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
    }

    var sessions: [IslandAgentSession] {
        sessionsByID.values.sorted {
            if $0.updatedAt == $1.updatedAt {
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    var prioritySessions: [IslandAgentSession] {
        sessions.filter { !$0.isDismissed }.sorted {
            if $0.phase.priorityRank == $1.phase.priorityRank {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.phase.priorityRank < $1.phase.priorityRank
        }
    }

    var spotlightSession: IslandAgentSession? {
        prioritySessions.first
    }

    var runningCount: Int {
        sessionsByID.values.filter { $0.phase == .running }.count
    }

    var attentionCount: Int {
        sessionsByID.values.filter { $0.phase.requiresAttention }.count
    }

    var liveSessionCount: Int {
        sessionsByID.values.filter { !$0.isDismissed && $0.phase != .stale }.count
    }

    func session(id: String?) -> IslandAgentSession? {
        guard let id else { return nil }
        return sessionsByID[id]
    }

    mutating func apply(_ event: IslandSessionEvent) {
        switch event {
        case let .sessionStarted(payload):
            let existing = sessionsByID[payload.sessionID]
            let preservesPendingApproval = payload.initialPhase == .running
                && existing?.phase == .waitingForApproval
                && existing?.permissionRequest != nil
            let preservesPendingQuestion = payload.initialPhase == .running
                && existing?.phase == .waitingForAnswer
                && existing?.questionPrompt != nil
            let preservesActionableState = preservesPendingApproval || preservesPendingQuestion

            upsert(IslandAgentSession(
                id: payload.sessionID,
                identity: payload.identity,
                title: payload.title,
                tool: payload.tool,
                phase: preservesActionableState ? existing?.phase ?? payload.initialPhase : payload.initialPhase,
                summary: preservesActionableState ? existing?.summary ?? payload.summary : payload.summary,
                updatedAt: payload.timestamp,
                firstSeenAt: existing?.firstSeenAt,
                permissionRequest: preservesActionableState ? existing?.permissionRequest : nil,
                questionPrompt: preservesActionableState ? existing?.questionPrompt : nil,
                currentTool: payload.currentTool,
                commandPreview: payload.commandPreview,
                initialPrompt: payload.initialPrompt,
                latestPrompt: payload.latestPrompt,
                lastAssistantMessage: payload.lastAssistantMessage,
                terminalTag: payload.terminalTag,
                lastError: preservesActionableState ? payload.lastError ?? existing?.lastError : payload.lastError
            ))
        case let .activityUpdated(payload):
            guard var session = sessionsByID[payload.sessionID] else { return }
            let preservesPending = payload.phase == .running && session.phase.requiresAttention
            if !preservesPending {
                session.phase = payload.phase
                if payload.phase != .waitingForApproval {
                    session.permissionRequest = nil
                }
                if payload.phase != .waitingForAnswer {
                    session.questionPrompt = nil
                }
            }
            session.summary = payload.summary
            session.updatedAt = payload.timestamp
            session.currentTool = payload.currentTool ?? session.currentTool
            session.commandPreview = payload.commandPreview ?? session.commandPreview
            session.latestPrompt = payload.latestPrompt ?? session.latestPrompt
            session.lastAssistantMessage = payload.lastAssistantMessage ?? session.lastAssistantMessage
            session.lastError = payload.lastError
            upsert(session)
        case let .permissionRequested(payload):
            guard var session = sessionsByID[payload.sessionID] else { return }
            session.phase = .waitingForApproval
            session.summary = payload.request.summary
            session.permissionRequest = payload.request
            session.questionPrompt = nil
            session.updatedAt = payload.timestamp
            session.lastError = nil
            upsert(session)
        case let .questionAsked(payload):
            guard var session = sessionsByID[payload.sessionID] else { return }
            session.phase = .waitingForAnswer
            session.summary = payload.prompt.title
            session.questionPrompt = payload.prompt
            session.permissionRequest = nil
            session.updatedAt = payload.timestamp
            session.lastError = nil
            upsert(session)
        case let .sessionCompleted(payload):
            guard var session = sessionsByID[payload.sessionID] else { return }
            session.phase = payload.failed ? .failed : .completed
            session.summary = payload.summary
            session.permissionRequest = nil
            session.questionPrompt = nil
            session.updatedAt = payload.timestamp
            session.lastAssistantMessage = payload.lastAssistantMessage ?? session.lastAssistantMessage
            session.lastError = payload.failed ? payload.summary : nil
            upsert(session)
        case let .actionableStateResolved(payload):
            guard var session = sessionsByID[payload.sessionID] else { return }
            let hasStaleActionablePayload = session.phase == .running
                && (session.permissionRequest != nil || session.questionPrompt != nil)
            guard session.phase.requiresAttention || hasStaleActionablePayload else { return }
            session.phase = .running
            session.summary = payload.summary
            session.permissionRequest = nil
            session.questionPrompt = nil
            session.updatedAt = payload.timestamp
            session.lastError = nil
            upsert(session)
        }
    }

    mutating func resolvePermission(
        sessionID: String,
        resolution: IslandPermissionResolution,
        at timestamp: Date = .now
    ) {
        let summary = resolution.isApproved ? "Permission approved." : "Permission denied."
        apply(.actionableStateResolved(IslandActionableStateResolved(
            sessionID: sessionID,
            summary: summary,
            timestamp: timestamp
        )))
    }

    mutating func answerQuestion(
        sessionID: String,
        response: IslandQuestionPromptResponse,
        at timestamp: Date = .now
    ) {
        let summary = response.displaySummary.isEmpty ? "Answered the question." : "Answered: \(response.displaySummary)"
        apply(.actionableStateResolved(IslandActionableStateResolved(
            sessionID: sessionID,
            summary: summary,
            timestamp: timestamp
        )))
    }

    mutating func dismissSession(id: String) {
        guard var session = sessionsByID[id] else { return }
        session.isDismissed = true
        upsert(session)
    }

    mutating func markSessionStale(id: String, error: String) {
        guard var session = sessionsByID[id] else { return }
        session.phase = .stale
        session.lastError = error
        session.updatedAt = .now
        upsert(session)
    }

    mutating func replace(_ session: IslandAgentSession) {
        upsert(session)
    }

    private mutating func upsert(_ session: IslandAgentSession) {
        sessionsByID[session.id] = session
    }
}
