//
//  IslandAgentModels.swift
//  Argo
//
//  Author: krystal
//

import Foundation

nonisolated enum IslandAgentTool: String, Codable, Sendable, CaseIterable, Equatable {
    case codex
    case claudeCode
    case geminiCLI
    case openCode
    case cursor
    case argo

    var displayName: String {
        switch self {
        case .codex:
            "Codex"
        case .claudeCode:
            "Claude Code"
        case .geminiCLI:
            "Gemini CLI"
        case .openCode:
            "OpenCode"
        case .cursor:
            "Cursor"
        case .argo:
            "Argo"
        }
    }

    var shortName: String {
        switch self {
        case .codex:
            "CODEX"
        case .claudeCode:
            "CLAUDE"
        case .geminiCLI:
            "GEMINI"
        case .openCode:
            "OPENCODE"
        case .cursor:
            "CURSOR"
        case .argo:
            "ARGO"
        }
    }

    var brandColorHex: String {
        switch self {
        case .codex:
            "#4aa3df"
        case .claudeCode:
            "#d97742"
        case .geminiCLI:
            "#42e86b"
        case .openCode:
            "#ffb547"
        case .cursor:
            "#7a5cff"
        case .argo:
            "#8fb7ff"
        }
    }
}

nonisolated enum IslandSessionPhase: String, Codable, Sendable, CaseIterable, Equatable {
    case running
    case waitingForApproval
    case waitingForAnswer
    case completed
    case failed
    case stale

    var requiresAttention: Bool {
        self == .waitingForApproval || self == .waitingForAnswer
    }

    var priorityRank: Int {
        switch self {
        case .waitingForAnswer:
            0
        case .waitingForApproval:
            1
        case .failed:
            2
        case .running:
            3
        case .stale:
            4
        case .completed:
            5
        }
    }
}

nonisolated enum IslandSessionAttachmentState: String, Codable, Sendable, Equatable {
    case attached
    case stale
    case detached
}

nonisolated struct IslandPermissionAction: Equatable, Identifiable, Codable, Sendable {
    var id: UUID
    var title: String
    var responseText: String

    init(id: UUID = UUID(), title: String, responseText: String) {
        self.id = id
        self.title = title
        self.responseText = responseText
    }
}

nonisolated struct IslandPermissionRequest: Equatable, Identifiable, Codable, Sendable {
    var id: UUID
    var title: String
    var summary: String
    var affectedPath: String
    var primaryActionTitle: String
    var secondaryActionTitle: String
    var allowResponseText: String
    var denyResponseText: String
    var actions: [IslandPermissionAction]

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        affectedPath: String,
        primaryActionTitle: String = "Allow",
        secondaryActionTitle: String = "Deny",
        allowResponseText: String = "1\n",
        denyResponseText: String = "2\n",
        actions: [IslandPermissionAction]? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.affectedPath = affectedPath
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitle = secondaryActionTitle
        self.allowResponseText = allowResponseText
        self.denyResponseText = denyResponseText
        self.actions = actions ?? [
            IslandPermissionAction(title: secondaryActionTitle, responseText: denyResponseText),
            IslandPermissionAction(title: primaryActionTitle, responseText: allowResponseText)
        ]
    }
}

nonisolated struct IslandQuestionOption: Equatable, Identifiable, Codable, Sendable {
    var id: UUID
    var label: String
    var responseText: String

    init(id: UUID = UUID(), label: String, responseText: String? = nil) {
        self.id = id
        self.label = label
        self.responseText = responseText ?? "\(label)\n"
    }
}

nonisolated struct IslandQuestionPrompt: Equatable, Identifiable, Codable, Sendable {
    var id: UUID
    var title: String
    var options: [IslandQuestionOption]

    init(id: UUID = UUID(), title: String, options: [IslandQuestionOption]) {
        self.id = id
        self.title = title
        self.options = options
    }
}

nonisolated struct IslandQuestionPromptResponse: Equatable, Codable, Sendable {
    var rawAnswer: String?

    init(answer: String) {
        self.rawAnswer = answer
    }

    var displaySummary: String {
        rawAnswer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

nonisolated enum IslandPermissionResolution: Equatable, Codable, Sendable {
    case allowOnce
    case deny(message: String?)

    var isApproved: Bool {
        if case .allowOnce = self {
            true
        } else {
            false
        }
    }
}

nonisolated struct IslandAgentSession: Equatable, Identifiable, Codable, Sendable {
    var id: String
    var identity: IslandSessionIdentity
    var title: String
    var tool: IslandAgentTool
    var attachmentState: IslandSessionAttachmentState
    var phase: IslandSessionPhase
    var summary: String
    var updatedAt: Date
    var firstSeenAt: Date
    var permissionRequest: IslandPermissionRequest?
    var questionPrompt: IslandQuestionPrompt?
    var currentTool: String?
    var commandPreview: String?
    var initialPrompt: String?
    var latestPrompt: String?
    var lastAssistantMessage: String?
    var terminalTag: String?
    var lastError: String?
    var isDismissed: Bool

    init(
        id: String,
        identity: IslandSessionIdentity,
        title: String,
        tool: IslandAgentTool,
        attachmentState: IslandSessionAttachmentState = .attached,
        phase: IslandSessionPhase,
        summary: String,
        updatedAt: Date,
        firstSeenAt: Date? = nil,
        permissionRequest: IslandPermissionRequest? = nil,
        questionPrompt: IslandQuestionPrompt? = nil,
        currentTool: String? = nil,
        commandPreview: String? = nil,
        initialPrompt: String? = nil,
        latestPrompt: String? = nil,
        lastAssistantMessage: String? = nil,
        terminalTag: String? = nil,
        lastError: String? = nil,
        isDismissed: Bool = false
    ) {
        self.id = id
        self.identity = identity
        self.title = title
        self.tool = tool
        self.attachmentState = attachmentState
        self.phase = phase
        self.summary = summary
        self.updatedAt = updatedAt
        self.firstSeenAt = firstSeenAt ?? updatedAt
        self.permissionRequest = permissionRequest
        self.questionPrompt = questionPrompt
        self.currentTool = currentTool
        self.commandPreview = commandPreview
        self.initialPrompt = initialPrompt
        self.latestPrompt = latestPrompt
        self.lastAssistantMessage = lastAssistantMessage
        self.terminalTag = terminalTag
        self.lastError = lastError
        self.isDismissed = isDismissed
    }
}
