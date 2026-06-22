//
//  AgentNotifyProtocol.swift
//  Argo
//
//  Author: krystal
//

import Foundation

/// Environment variables Argo injects into PTY sessions so out-of-band agent
/// notifications (delivered via the `argo notify` CLI) can be routed back to
/// the originating pane.
nonisolated enum ArgoAgentNotifyEnvironment {
    static let paneIDKey = "ARGO_PANE_ID"
}

/// Wire format for a single agent notification.
///
/// One frame is one JSON object on its own line, UTF-8 encoded, terminated by
/// `\n`. Forward-compatible: unknown fields are ignored, missing optional
/// fields default to nil. The `version` field is reserved so future protocol
/// breakages can be flagged.
nonisolated enum AgentNotifyKind: String, Codable, Equatable, Sendable {
    case activity
    case approval
    case question
    case completed
    case failed
}

nonisolated struct AgentNotifyOption: Codable, Equatable, Sendable {
    var label: String
    var responseText: String
}

nonisolated struct AgentNotifyRequest: Codable, Equatable, Sendable {
    /// Wire-format version. Bump only on incompatible changes.
    static let currentVersion: Int = 1

    var version: Int
    var title: String
    var body: String?
    var paneID: String?
    var workspaceID: String?
    var agentName: String?
    var toolName: String?
    var kind: AgentNotifyKind?
    var sessionID: String?
    var sourceID: String?
    var currentTool: String?
    var commandPreview: String?
    var affectedPath: String?
    var initialPrompt: String?
    var latestPrompt: String?
    var assistantMessage: String?
    var options: [AgentNotifyOption]?
    var responseText: String?

    enum CodingKeys: String, CodingKey {
        case version = "v"
        case title
        case body
        case paneID = "pane"
        case workspaceID = "workspace"
        case agentName = "agent"
        case toolName = "tool"
        case kind
        case sessionID = "session"
        case sourceID = "source"
        case currentTool
        case commandPreview
        case affectedPath
        case initialPrompt
        case latestPrompt
        case assistantMessage
        case options
        case responseText
    }

    init(
        version: Int = AgentNotifyRequest.currentVersion,
        title: String,
        body: String? = nil,
        paneID: String? = nil,
        workspaceID: String? = nil,
        agentName: String? = nil,
        toolName: String? = nil,
        kind: AgentNotifyKind? = nil,
        sessionID: String? = nil,
        sourceID: String? = nil,
        currentTool: String? = nil,
        commandPreview: String? = nil,
        affectedPath: String? = nil,
        initialPrompt: String? = nil,
        latestPrompt: String? = nil,
        assistantMessage: String? = nil,
        options: [AgentNotifyOption]? = nil,
        responseText: String? = nil
    ) {
        self.version = version
        self.title = title
        self.body = body
        self.paneID = paneID
        self.workspaceID = workspaceID
        self.agentName = agentName
        self.toolName = toolName
        self.kind = kind
        self.sessionID = sessionID
        self.sourceID = sourceID
        self.currentTool = currentTool
        self.commandPreview = commandPreview
        self.affectedPath = affectedPath
        self.initialPrompt = initialPrompt
        self.latestPrompt = latestPrompt
        self.assistantMessage = assistantMessage
        self.options = options
        self.responseText = responseText
    }
}

nonisolated extension AgentNotifyKind {
    var initialPhase: IslandSessionPhase {
        switch self {
        case .activity:
            .running
        case .approval:
            .waitingForApproval
        case .question:
            .waitingForAnswer
        case .completed:
            .completed
        case .failed:
            .failed
        }
    }
}

nonisolated extension AgentNotifyRequest {
    func followupEvent(sessionID: String, summary: String, timestamp: Date) -> IslandSessionEvent? {
        switch kind {
        case .approval:
            .permissionRequested(IslandPermissionRequested(
                sessionID: sessionID,
                request: IslandPermissionRequest(
                    title: title,
                    summary: summary,
                    affectedPath: affectedPath ?? "",
                    primaryActionTitle: options?.first?.label ?? "Allow",
                    secondaryActionTitle: options?.dropFirst().first?.label ?? "Deny",
                    allowResponseText: options?.first?.responseText ?? "1\n",
                    denyResponseText: options?.dropFirst().first?.responseText ?? "2\n",
                    actions: options?.map {
                        IslandPermissionAction(title: $0.label, responseText: $0.responseText)
                    }
                ),
                timestamp: timestamp
            ))
        case .question:
            .questionAsked(IslandQuestionAsked(
                sessionID: sessionID,
                prompt: IslandQuestionPrompt(
                    title: summary,
                    options: options?.map {
                        IslandQuestionOption(label: $0.label, responseText: $0.responseText)
                    } ?? []
                ),
                timestamp: timestamp
            ))
        case .completed:
            .sessionCompleted(IslandSessionCompleted(
                sessionID: sessionID,
                summary: summary,
                timestamp: timestamp,
                failed: false,
                lastAssistantMessage: assistantMessage
            ))
        case .failed:
            .sessionCompleted(IslandSessionCompleted(
                sessionID: sessionID,
                summary: summary,
                timestamp: timestamp,
                failed: true,
                lastAssistantMessage: assistantMessage
            ))
        case .activity, nil:
            nil
        }
    }
}

/// Errors the protocol layer surfaces to callers.
enum AgentNotifyError: Error, Equatable {
    case missingTitle
    case payloadTooLarge(limit: Int, actual: Int)
    case decode(message: String)
    case socketUnavailable
    case socketWriteFailed(errno: Int32)
}

nonisolated enum AgentNotifyProtocol {
    /// Maximum frame size accepted by the server. A notification with a
    /// 1 MB body is already absurd; cap well below that to make a runaway
    /// or hostile client easy to reject.
    static let maxFrameBytes: Int = 64 * 1024

    /// Encode a request as a UTF-8 JSON frame terminated by `\n`.
    static func encode(_ request: AgentNotifyRequest) throws -> Data {
        guard !request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || (request.body?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) else {
            throw AgentNotifyError.missingTitle
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var data = try encoder.encode(request)
        if data.count >= maxFrameBytes {
            throw AgentNotifyError.payloadTooLarge(limit: maxFrameBytes, actual: data.count)
        }
        data.append(0x0A) // '\n'
        return data
    }

    /// Decode a UTF-8 JSON frame (with or without trailing newline).
    static func decode(_ data: Data) throws -> AgentNotifyRequest {
        let trimmed = data.last == 0x0A ? data.dropLast() : data
        if trimmed.count > maxFrameBytes {
            throw AgentNotifyError.payloadTooLarge(limit: maxFrameBytes, actual: trimmed.count)
        }
        do {
            return try JSONDecoder().decode(AgentNotifyRequest.self, from: trimmed)
        } catch {
            throw AgentNotifyError.decode(message: String(describing: error))
        }
    }
}

/// Resolves the Unix domain socket path the running app listens on.
///
/// Pinned to `~/Library/Application Support/Argo/agent-notify.sock` so it is
/// stable across launches and per-user. `sun_path` is limited to 104 bytes on
/// Darwin; a path under `Application Support` for any normal home directory
/// fits comfortably.
nonisolated enum AgentNotifySocketPath {
    static let directoryName = "Argo"
    static let socketFileName = "agent-notify.sock"

    /// Override that lets tests pin the socket to a sandbox-friendly location.
    nonisolated(unsafe) static var overrideURL: URL?

    static func resolveDirectory(
        fileManager: FileManager = .default,
        homeDirectory: String = NSHomeDirectory()
    ) -> URL {
        if let overrideURL {
            return overrideURL.deletingLastPathComponent()
        }
        let appSupport = URL(fileURLWithPath: homeDirectory, isDirectory: true)
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
        return appSupport
    }

    static func resolveSocketURL(
        fileManager: FileManager = .default,
        homeDirectory: String = NSHomeDirectory()
    ) -> URL {
        if let overrideURL { return overrideURL }
        return resolveDirectory(fileManager: fileManager, homeDirectory: homeDirectory)
            .appendingPathComponent(socketFileName, isDirectory: false)
    }

    static func resolveExecutableSocketURL(
        executablePath: String,
        fileManager: FileManager = .default,
        homeDirectory: String = NSHomeDirectory()
    ) -> URL {
        let standardizedPath = URL(fileURLWithPath: executablePath)
            .standardizedFileURL
            .path
        let hash = stableSocketHash(for: standardizedPath)
        return resolveDirectory(fileManager: fileManager, homeDirectory: homeDirectory)
            .appendingPathComponent("a-\(hash)", isDirectory: false)
    }

    static func ensureDirectory(
        fileManager: FileManager = .default,
        homeDirectory: String = NSHomeDirectory()
    ) throws {
        let directory = resolveDirectory(fileManager: fileManager, homeDirectory: homeDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private static func stableSocketHash(for value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        let hex = String(hash, radix: 16, uppercase: false)
        return String(repeating: "0", count: max(0, 16 - hex.count)) + hex
    }
}
