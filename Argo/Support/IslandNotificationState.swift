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

    var badgeCount: Int {
        items.count
    }

    var attentionCount: Int {
        items.filter { $0.status.requiresAttention }.count
    }

    func post(item: IslandNotificationItem) {
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
    }

    func markDone(id: UUID) {
        update(id: id, status: .completed)
    }

    func dismiss(id: UUID) {
        items.removeAll { $0.id == id }
        if items.isEmpty {
            isExpanded = false
        }
    }

    func clearCompleted() {
        items.removeAll { item in
            item.status == .completed || item.status == .failed || item.status == .stale
        }
        if items.isEmpty {
            isExpanded = false
        }
    }

    func clearAll() {
        items.removeAll()
        isExpanded = false
    }
}
