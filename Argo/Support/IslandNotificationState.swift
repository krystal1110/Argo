//
//  IslandNotificationState.swift
//  Argo
//
//  Author: krystal
//

import Combine
import Foundation

enum IslandTab: String, CaseIterable {
    case workspaces
    case sessions
}

nonisolated final class IslandNotificationState: ObservableObject {
    static let shared = IslandNotificationState()

    let objectWillChange = ObservableObjectPublisher()

    private(set) var items: [IslandNotificationItem] = [] {
        willSet { objectWillChange.send() }
    }

    private(set) var sessionState = IslandSessionState() {
        willSet { objectWillChange.send() }
    }

    var isExpanded: Bool = false {
        willSet { objectWillChange.send() }
    }

    var selectedTab: IslandTab = .workspaces {
        willSet { objectWillChange.send() }
    }

    var currentGroupID: UUID? = nil {
        willSet { objectWillChange.send() }
    }

    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    var priorityItems: [IslandNotificationItem] {
        items.sorted { lhs, rhs in
            if lhs.status.priorityRank == rhs.status.priorityRank {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.status.priorityRank < rhs.status.priorityRank
        }
    }

    var latestItem: IslandNotificationItem? {
        priorityItems.first
    }

    var sessions: [IslandAgentSession] {
        sessionState.sessions
    }

    var prioritySessions: [IslandAgentSession] {
        sessionState.prioritySessions
    }

    var spotlightSession: IslandAgentSession? {
        sessionState.spotlightSession
    }

    var badgeCount: Int {
        max(items.count, sessionState.liveSessionCount)
    }

    var attentionCount: Int {
        max(items.filter { $0.status.requiresAttention }.count, sessionState.attentionCount)
    }

    func post(item: IslandNotificationItem) {
        upsertLegacyItem(item)
        post(event: item.sessionStartedEvent)
    }

    func post(event: IslandSessionEvent) {
        sessionState.apply(event)
    }

    func markSessionStale(id: String, error: String) {
        sessionState.markSessionStale(id: id, error: error)
    }

    func updateSessionError(id: String, error: String) {
        guard var session = sessionState.session(id: id) else { return }
        session.lastError = error
        session.updatedAt = now()
        sessionState.replace(session)
    }

    private func upsertLegacyItem(_ item: IslandNotificationItem) {
        var next = item
        if next.updatedAt < next.startedAt {
            next.updatedAt = now()
        }
        if let index = items.firstIndex(where: { $0.identity == next.identity }) {
            let existingID = items[index].id
            items[index] = IslandNotificationItem(
                id: existingID,
                workspaceID: next.workspaceID,
                worktreePath: next.worktreePath,
                paneID: next.paneID,
                sourceID: next.sourceID,
                title: next.title,
                agentName: next.agentName,
                terminalTag: next.terminalTag,
                status: next.status,
                startedAt: items[index].startedAt,
                updatedAt: next.updatedAt,
                body: next.body,
                prompt: next.prompt,
                action: next.action,
                lastError: next.lastError
            )
        } else {
            items.append(next)
        }
    }

    func update(id: UUID, status: IslandSessionStatus, lastError: String? = nil) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = status
        items[index].lastError = lastError
        items[index].updatedAt = now()
        post(event: items[index].sessionStartedEvent)
    }

    func markDone(id: UUID) {
        update(id: id, status: .completed)
    }

    func resolveNavigation(id: UUID, result: IslandNavigationResult) {
        switch result {
        case .focusedPane, .focusedWorkspace:
            dismiss(id: id)
        case .paneMissing:
            update(id: id, status: .stale, lastError: "Pane is no longer available.")
        case .workspaceMissing:
            update(id: id, status: .stale, lastError: "Workspace is no longer available.")
        }
    }

    func dismiss(id: UUID) {
        if let item = items.first(where: { $0.id == id }) {
            sessionState.dismissSession(id: item.sessionID)
        }
        items.removeAll { $0.id == id }
        if items.isEmpty && sessionState.liveSessionCount == 0 {
            isExpanded = false
        }
    }

    func clearCompleted() {
        let removed = items.filter { item in
            item.status == .completed || item.status == .failed || item.status == .stale
        }
        for item in removed {
            sessionState.dismissSession(id: item.sessionID)
        }
        for session in sessionState.sessions where session.phase == .completed || session.phase == .failed || session.phase == .stale {
            sessionState.dismissSession(id: session.id)
        }
        items.removeAll { item in
            item.status == .completed || item.status == .failed || item.status == .stale
        }
        if items.isEmpty && sessionState.liveSessionCount == 0 {
            isExpanded = false
        }
    }

    func clearAll() {
        items.removeAll()
        sessionState = IslandSessionState()
        isExpanded = false
    }
}
