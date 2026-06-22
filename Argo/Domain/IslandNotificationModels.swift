//
//  IslandNotificationModels.swift
//  Argo
//
//  Author: krystal
//

import Foundation

nonisolated enum IslandSessionStatus: Equatable {
    case running
    case waitingForApproval
    case waitingForAnswer
    case completed
    case failed
    case stale

    var requiresAttention: Bool {
        switch self {
        case .waitingForApproval, .waitingForAnswer:
            return true
        case .running, .completed, .failed, .stale:
            return false
        }
    }

    var priorityRank: Int {
        switch self {
        case .waitingForAnswer: return 0
        case .waitingForApproval: return 1
        case .failed: return 2
        case .running: return 3
        case .stale: return 4
        case .completed: return 5
        }
    }
}

typealias IslandItemStatus = IslandSessionStatus

extension IslandSessionStatus {
    static let done: IslandSessionStatus = .completed
    static let error: IslandSessionStatus = .failed
    static let waitingForInput: IslandSessionStatus = .waitingForAnswer
}

nonisolated struct IslandSessionIdentity: Hashable, Codable, Sendable {
    let workspaceID: UUID
    let worktreePath: String?
    let paneID: UUID?
    let sourceID: String?

    init(
        workspaceID: UUID,
        worktreePath: String?,
        paneID: UUID?,
        sourceID: String?
    ) {
        self.workspaceID = workspaceID
        self.worktreePath = worktreePath
        self.paneID = paneID
        self.sourceID = sourceID ?? paneID?.uuidString.lowercased()
    }
}

nonisolated enum IslandSessionAction: Equatable {
    case sendText(String)
    case prompt(IslandPrompt)
}

nonisolated struct IslandNotificationItem: Identifiable, Equatable {
    let id: UUID
    let identity: IslandSessionIdentity
    let workspaceID: UUID
    let worktreePath: String?
    let paneID: UUID?
    let sourceID: String?
    let title: String
    let agentName: String?
    let terminalTag: String?
    var status: IslandSessionStatus
    let startedAt: Date
    var updatedAt: Date
    var body: String?
    var prompt: IslandPrompt?

    var action: IslandSessionAction?
    var lastError: String?

    init(
        id: UUID = UUID(),
        workspaceID: UUID,
        worktreePath: String?,
        paneID: UUID? = nil,
        sourceID: String? = nil,
        title: String,
        agentName: String?,
        terminalTag: String?,
        status: IslandSessionStatus,
        startedAt: Date,
        updatedAt: Date = Date(),
        body: String?,
        prompt: IslandPrompt?,
        action: IslandSessionAction? = nil,
        lastError: String? = nil
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.worktreePath = worktreePath
        self.paneID = paneID
        self.sourceID = sourceID ?? paneID?.uuidString.lowercased()
        self.identity = IslandSessionIdentity(
            workspaceID: workspaceID,
            worktreePath: worktreePath,
            paneID: paneID,
            sourceID: sourceID
        )
        self.title = title
        self.agentName = agentName
        self.terminalTag = terminalTag
        self.status = status
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.body = body
        self.prompt = prompt
        self.action = action
        self.lastError = lastError
    }
}

nonisolated extension IslandNotificationItem {
    var sessionID: String {
        sourceID ?? paneID?.uuidString.lowercased() ?? "\(workspaceID.uuidString.lowercased()):\(worktreePath ?? "workspace")"
    }

    var sessionStartedEvent: IslandSessionEvent {
        .sessionStarted(IslandSessionStarted(
            sessionID: sessionID,
            identity: identity,
            title: title,
            tool: IslandAgentTool.from(agentName: agentName),
            initialPhase: IslandSessionPhase(status),
            summary: body ?? title,
            timestamp: updatedAt,
            terminalTag: terminalTag,
            lastError: lastError
        ))
    }
}

nonisolated extension IslandAgentTool {
    static func from(agentName: String?) -> IslandAgentTool {
        switch agentName?.lowercased() {
        case "claude", "claude code":
            .claudeCode
        case "gemini", "gemini cli":
            .geminiCLI
        case "opencode", "open code":
            .openCode
        case "cursor":
            .cursor
        case "codex":
            .codex
        default:
            .argo
        }
    }
}

nonisolated extension IslandSessionPhase {
    init(_ status: IslandSessionStatus) {
        switch status {
        case .running:
            self = .running
        case .waitingForApproval:
            self = .waitingForApproval
        case .waitingForAnswer:
            self = .waitingForAnswer
        case .completed:
            self = .completed
        case .failed:
            self = .failed
        case .stale:
            self = .stale
        }
    }
}

nonisolated struct IslandPrompt: Equatable {
    let question: String
    let options: [IslandPromptOption]
}

nonisolated struct IslandPromptOption: Identifiable, Equatable {
    let id: Int
    let label: String
    let responseText: String
}
