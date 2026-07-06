//
//  AgentStatusStore.swift
//  Argo
//
//  Author: krystal
//

import Foundation

@MainActor
final class AgentStatusStore {
    static let shared = AgentStatusStore()

    struct Entry: Equatable {
        var state: AgentReportedState
        var title: String?
        var agentName: String?
        var updatedAt: Date
    }

    private(set) var entries: [UUID: Entry] = [:]

    private let now: () -> Date

    init(now: @escaping () -> Date = { Date() }) {
        self.now = now
    }

    func update(pane: UUID, state: AgentReportedState, title: String?, agentName: String? = nil) {
        entries[pane] = Entry(state: state, title: title, agentName: agentName, updatedAt: now())
    }

    func state(for pane: UUID) -> AgentReportedState? {
        entries[pane]?.state
    }

    func clear(pane: UUID) {
        entries[pane] = nil
    }

    func clearAll() {
        entries.removeAll()
    }
}
