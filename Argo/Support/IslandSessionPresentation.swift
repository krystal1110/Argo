//
//  IslandSessionPresentation.swift
//  Argo
//
//  Author: krystal
//

import Foundation

nonisolated enum IslandSessionPresence: Equatable {
    case running
    case active
    case inactive
}

nonisolated extension IslandAgentSession {
    static let staleCompletedDisplayThreshold: TimeInterval = 5 * 60

    var spotlightWorkspaceName: String {
        guard let path = identity.worktreePath, !path.isEmpty else { return title }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    var spotlightHeadlineText: String {
        if let prompt = initialPrompt?.trimmedForIslandSurface, !prompt.isEmpty {
            return "\(spotlightWorkspaceName) · \(prompt)"
        }
        return spotlightWorkspaceName
    }

    var spotlightActivityLineText: String? {
        if let currentTool = currentTool?.trimmedForIslandSurface, !currentTool.isEmpty {
            let label = Self.currentToolDisplayName(for: currentTool)
            if let commandPreview = commandPreview?.trimmedForIslandSurface, !commandPreview.isEmpty {
                return "\(label) \(commandPreview)"
            }
            return label
        }
        if phase.requiresAttention { return summary }
        if phase == .completed { return lastAssistantMessage?.trimmedForIslandSurface ?? summary }
        return summary
    }

    func spotlightAgeBadge(at referenceDate: Date = .now) -> String {
        let age = max(0, Int(referenceDate.timeIntervalSince(updatedAt)))
        if age < 60 { return "<1m" }
        if age < 3_600 { return "\(max(1, age / 60))m" }
        if age < 86_400 { return "\(max(1, age / 3_600))h" }
        return "\(max(1, age / 86_400))d"
    }

    func islandPresence(at referenceDate: Date) -> IslandSessionPresence {
        if phase == .running { return .running }
        if phase.requiresAttention || phase == .failed { return .active }
        if referenceDate.timeIntervalSince(updatedAt) <= Self.staleCompletedDisplayThreshold {
            return .active
        }
        return .inactive
    }

    func isStaleCompletedForIsland(
        at referenceDate: Date,
        threshold: TimeInterval = Self.staleCompletedDisplayThreshold
    ) -> Bool {
        phase == .completed && referenceDate.timeIntervalSince(updatedAt) >= threshold
    }

    var approvalCommandPreviewText: String? {
        if let commandPreview = commandPreview?.trimmedForIslandSurface, !commandPreview.isEmpty {
            return commandPreview
        }
        if let summary = permissionRequest?.summary.trimmedForIslandSurface, !summary.isEmpty {
            return summary
        }
        return nil
    }

    var approvalAffectedPathText: String? {
        guard let affectedPath = permissionRequest?.affectedPath.trimmedForIslandSurface,
              !affectedPath.isEmpty else {
            return nil
        }
        return affectedPath
    }

    static func currentToolDisplayName(for toolName: String) -> String {
        switch toolName {
        case "exec_command", "Bash":
            "Bash"
        case "apply_patch":
            "Patch"
        case "tool_search", "web_search":
            "Search"
        case "update_plan":
            "Plan"
        case "request_user_input":
            "Question"
        default:
            toolName
                .split(separator: "_")
                .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                .joined(separator: " ")
        }
    }
}

private nonisolated extension String {
    var trimmedForIslandSurface: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
