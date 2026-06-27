//
//  ArgoControlProtocol.swift
//  Argo
//
//  Author: krystal
//

import Foundation

/// Multi-command IPC protocol layered on top of `AgentNotifyServer`.
///
/// The wire format remains a single newline-terminated JSON object per
/// connection. The `cmd` field discriminates: when absent it defaults to
/// `notify` so already-released `argo notify` clients keep working without
/// modification.
///
/// Mutating commands require a token that matches the value stored under
/// `ArgoURLScheme` (Settings → URL Scheme). Read-only commands stay open to
/// local callers so scripts and agent hooks can report or inspect status
/// without learning the user's URL-scheme secret.
nonisolated enum ArgoControlCommand: String, Codable {
    case notify
    case ping
    case status
    case open
    case split
    case sendKeys = "send-keys"
    case sessionList = "session-list"
    case read
    case agents
    case claudeHook = "claude-hook"

    var requiresControlToken: Bool {
        switch self {
        case .notify, .ping, .status, .sessionList, .read, .agents, .claudeHook:
            return false
        case .open, .split, .sendKeys:
            return true
        }
    }
}

/// Light envelope that decodes only the discriminator + auth fields. The
/// dispatcher decodes the same JSON a second time into the typed payload
/// once `cmd` is known.
nonisolated struct ArgoControlEnvelope: Decodable {
    var version: Int?
    var cmd: ArgoControlCommand?
    var token: String?

    enum CodingKeys: String, CodingKey {
        case version = "v"
        case cmd
        case token
    }
}

/// Open a repository (and optionally a worktree) in the running app.
struct ArgoOpenRequest: Decodable {
    var repo: String
    var worktree: String?
}

/// Split the focused pane (or a specific pane) along an axis.
struct ArgoSplitRequest: Decodable {
    var pane: String?
    var axis: String?       // "vertical" | "horizontal" — defaults to vertical
    var placement: String?  // "after" | "before" — defaults to after
}

/// Send literal text to a pane. Text is UTF-8; control characters are passed
/// through as-is so callers can append `\n` to submit, `\u{0003}` for
/// Ctrl-C, etc.
struct ArgoSendKeysRequest: Decodable {
    var pane: String?       // defaults to focused pane
    var text: String
}

enum AgentReportedState: String, Codable, Equatable {
    case running
    case waiting
    case done
    case error

    var islandStatus: IslandSessionStatus {
        switch self {
        case .running:
            return .running
        case .waiting:
            return .waitingForInput
        case .done:
            return .done
        case .error:
            return .error
        }
    }

    init?(cliValue raw: String) {
        switch raw.lowercased() {
        case "running", "busy", "working", "start", "started":
            self = .running
        case "waiting", "wait", "blocked", "input", "needs-input":
            self = .waiting
        case "done", "complete", "completed", "finished", "success", "ok":
            self = .done
        case "error", "failed", "fail":
            self = .error
        default:
            return nil
        }
    }
}

struct ArgoStatusRequest: Decodable {
    var state: String
    var pane: String?
    var title: String?
    var agentName: String?

    enum CodingKeys: String, CodingKey {
        case state
        case pane
        case title
        case agentName = "agent"
    }
}

struct ArgoReadRequest: Decodable {
    var pane: String?
    var lines: Int?
    var scrollback: Bool?
}

struct ArgoAgentsRequest: Decodable {}

/// Request a JSON snapshot of every running pane across all workspaces.
struct ArgoSessionListRequest: Decodable {
    // Reserved for filtering options; intentionally empty for v1.
}

struct ArgoAgentInfo: Codable, Equatable {
    var workspaceID: String
    var workspaceName: String
    var paneID: String
    var type: String?
    var name: String?
    var status: String
    var reported: Bool
    var cwd: String
    var branch: String?
    var focused: Bool

    enum CodingKeys: String, CodingKey {
        case workspaceID = "workspace"
        case workspaceName
        case paneID = "pane"
        case type
        case name
        case status
        case reported
        case cwd
        case branch
        case focused
    }
}

/// Response shape for a single pane in `session-list`.
struct ArgoControlSession: Codable, Equatable {
    var workspaceID: String
    var workspaceName: String
    var paneID: String
    var cwd: String
    var branch: String?
    var listeningPorts: [Int]
    var status: String? = nil

    enum CodingKeys: String, CodingKey {
        case workspaceID = "workspace"
        case workspaceName = "workspaceName"
        case paneID = "pane"
        case cwd
        case branch
        case listeningPorts = "ports"
        case status
    }
}

/// Generic response written back to the CLI client.
struct ArgoControlResponse: Codable, Equatable {
    var ok: Bool
    var error: String? = nil
    var sessions: [ArgoControlSession]? = nil
    var text: String? = nil
    var lineCount: Int? = nil
    var agents: [ArgoAgentInfo]? = nil
    var executablePath: String? = nil

    static let success = ArgoControlResponse(ok: true)

    static func failure(_ message: String) -> ArgoControlResponse {
        ArgoControlResponse(ok: false, error: message)
    }
}

enum ArgoControlEncoder {
    static let json: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static func encodeResponse(_ response: ArgoControlResponse) -> Data {
        (try? json.encode(response)) ?? Data("{\"ok\":false,\"error\":\"encode-failed\"}".utf8)
    }
}
