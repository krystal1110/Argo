//
//  ClaudeHookNotifyBridge.swift
//  Argo
//
//  Author: krystal
//

import Foundation

nonisolated struct ArgoClaudeHookControlRequest: Decodable, Sendable {
    var paneID: String?
    var payload: ClaudeHookPayload

    enum CodingKeys: String, CodingKey {
        case paneID = "pane"
        case payload
    }
}

nonisolated struct ArgoClaudeHookControlResponse: Codable, Equatable, Sendable {
    var ok: Bool
    var stdout: String?
    var error: String?

    static func success(stdout: String?) -> ArgoClaudeHookControlResponse {
        ArgoClaudeHookControlResponse(ok: true, stdout: stdout, error: nil)
    }

    static func failure(_ error: String) -> ArgoClaudeHookControlResponse {
        ArgoClaudeHookControlResponse(ok: false, stdout: nil, error: error)
    }
}

nonisolated enum ClaudeHookNotifyBridge {
    static let interactiveTimeout: TimeInterval = 24 * 60 * 60

    static func controlFrame(
        from input: Data,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> Data? {
        guard !input.isEmpty else { return nil }
        guard var payloadObject = try JSONSerialization.jsonObject(with: input) as? [String: Any] else {
            throw AgentNotifyError.decode(message: "Claude hook payload must be a JSON object")
        }
        payloadObject["cmd"] = ArgoControlCommand.claudeHook.rawValue
        if let paneID = environment[ArgoAgentNotifyEnvironment.paneIDKey], !paneID.isEmpty {
            payloadObject["pane"] = paneID
        }

        let frame = try JSONSerialization.data(withJSONObject: payloadObject, options: [.sortedKeys])
        return frame + Data("\n".utf8)
    }

    static func decodeControlRequest(from frame: Data) throws -> ArgoClaudeHookControlRequest {
        let trimmed = frame.last == 0x0A ? frame.dropLast() : frame
        let rootPayload = try JSONDecoder().decode(ClaudeHookPayload.self, from: trimmed)
        let envelope = try JSONDecoder().decode(ArgoControlEnvelope.self, from: trimmed)
        let paneID = try? JSONDecoder().decode(PaneCarrier.self, from: trimmed).paneID
        guard envelope.cmd == .claudeHook else {
            throw AgentNotifyError.decode(message: "not a claude-hook control frame")
        }
        return ArgoClaudeHookControlRequest(paneID: paneID, payload: rootPayload)
    }

    static func notifyRequest(from request: ArgoClaudeHookControlRequest) -> AgentNotifyRequest? {
        notifyRequest(from: request.payload, paneID: request.paneID)
    }

    static func notifyRequest(
        from data: Data,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> AgentNotifyRequest? {
        let payload = try JSONDecoder().decode(ClaudeHookPayload.self, from: data)
        let paneID = environment[ArgoAgentNotifyEnvironment.paneIDKey]
            .flatMap { $0.isEmpty ? nil : $0 }
        return notifyRequest(from: payload, paneID: paneID)
    }

    static func notifyRequest(from payload: ClaudeHookPayload, paneID: String?) -> AgentNotifyRequest? {
        guard payload.hookEventName == .permissionRequest else { return nil }

        let sessionID = payload.sessionID.nilIfEmpty
        let affectedPath = payload.commandPreview ?? payload.cwd.nilIfEmpty

        if let question = payload.questionPrompt {
            return AgentNotifyRequest(
                title: question.title,
                paneID: paneID,
                agentName: "Claude",
                toolName: "Claude",
                kind: .question,
                sessionID: sessionID,
                sourceID: sessionID.map { "claude:\($0):question" },
                currentTool: payload.toolName,
                affectedPath: affectedPath,
                options: question.options.map(\.agentOption)
            )
        }

        let toolName = payload.toolName?.nilIfEmpty ?? "Claude tool"
        return AgentNotifyRequest(
            title: payload.permissionRequestTitle,
            body: payload.permissionRequestSummary,
            paneID: paneID,
            agentName: "Claude",
            toolName: "Claude",
            kind: .approval,
            sessionID: sessionID,
            sourceID: sessionID.map { "claude:\($0):permission:\(toolName)" },
            currentTool: payload.toolName,
            commandPreview: payload.commandPreview,
            affectedPath: affectedPath,
            options: payload.permissionRequestOptions
        )
    }

    static func encodeControlResponse(_ response: ArgoClaudeHookControlResponse) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(response)) ?? Data("{\"ok\":false,\"error\":\"encode-failed\"}".utf8)
    }

    static func cliStdout(from responseData: Data?) throws -> Data? {
        guard let responseData, !responseData.isEmpty else { return nil }
        let trimmed = responseData.last == 0x0A ? responseData.dropLast() : responseData
        let response = try JSONDecoder().decode(ArgoClaudeHookControlResponse.self, from: trimmed)
        guard response.ok else {
            throw AgentNotifyError.decode(message: response.error ?? "claude-hook failed")
        }
        guard let stdout = response.stdout, !stdout.isEmpty else { return nil }
        return Data(stdout.utf8)
    }

    static func stdout(for result: ClaudeHookInteractionResult) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var data = try encoder.encode(ClaudePermissionRequestOutput(
            hookSpecificOutput: ClaudePermissionRequestOutput.HookSpecificOutput(
                decision: result.decision
            )
        ))
        data.append(0x0A)
        return String(decoding: data, as: UTF8.self)
    }

    private struct PaneCarrier: Decodable {
        var paneID: String?

        enum CodingKeys: String, CodingKey {
            case paneID = "pane"
        }
    }
}

nonisolated struct ClaudeQuestionPrompt {
    var title: String
    var options: [ClaudeQuestionPromptOption]
}

nonisolated struct ClaudeQuestionPromptOption {
    var question: String
    var label: String
    var answer: String
    var responseText: String

    var agentOption: AgentNotifyOption {
        AgentNotifyOption(label: label, responseText: responseText)
    }
}

nonisolated enum ClaudeHookEventName: String, Codable, Equatable, Sendable {
    case permissionRequest = "PermissionRequest"
    case other

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = ClaudeHookEventName(rawValue: value) ?? .other
    }
}

nonisolated struct ClaudeHookPayload: Codable, Equatable, Sendable {
    var cwd: String
    var hookEventName: ClaudeHookEventName
    var sessionID: String
    var toolName: String?
    var toolInput: ClaudeHookJSONValue?
    var permissionSuggestions: [ClaudePermissionUpdate]?
    var message: String?
    var title: String?

    enum CodingKeys: String, CodingKey {
        case cwd
        case hookEventName = "hook_event_name"
        case sessionID = "session_id"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case permissionSuggestions = "permission_suggestions"
        case message
        case title
    }
}

nonisolated extension ClaudeHookPayload {
    var questionPrompt: ClaudeQuestionPrompt? {
        guard toolName == "AskUserQuestion",
              case let .object(root) = toolInput,
              case let .array(rawQuestions) = root["questions"] else {
            return nil
        }

        var parsedQuestions: [(question: String, header: String, options: [String])] = []
        for rawQuestion in rawQuestions {
            guard case let .object(questionObject) = rawQuestion,
                  let question = questionObject["question"]?.stringValue?.nilIfEmpty,
                  let header = questionObject["header"]?.stringValue?.nilIfEmpty,
                  case let .array(rawOptions) = questionObject["options"] else {
                continue
            }

            let options = rawOptions.compactMap { rawOption -> String? in
                guard case let .object(optionObject) = rawOption else { return nil }
                return optionObject["label"]?.stringValue?.nilIfEmpty
            }
            guard !options.isEmpty else { continue }
            parsedQuestions.append((question: question, header: header, options: options))
        }

        guard !parsedQuestions.isEmpty else { return nil }

        let title: String
        if parsedQuestions.count == 1, let question = parsedQuestions.first?.question {
            title = question
        } else {
            title = "Claude has \(parsedQuestions.count) questions for you."
        }

        var indexedOptions: [ClaudeQuestionPromptOption] = []
        for question in parsedQuestions {
            for answer in question.options {
                let label = parsedQuestions.count == 1 ? answer : "\(question.header): \(answer)"
                indexedOptions.append(ClaudeQuestionPromptOption(
                    question: question.question,
                    label: label,
                    answer: answer,
                    responseText: "\(indexedOptions.count + 1)\n"
                ))
            }
        }

        return ClaudeQuestionPrompt(title: title, options: indexedOptions)
    }

    var commandPreview: String? {
        guard case let .object(object) = toolInput else { return nil }
        let keyPriority = ["command", "file_path", "pattern", "query", "prompt", "description", "url"]
        for key in keyPriority {
            if let value = object[key]?.stringValue?.nilIfEmpty {
                return value
            }
        }
        return nil
    }

    var permissionRequestTitle: String {
        switch toolName {
        case "ExitPlanMode":
            return "Exit plan mode"
        case "AskUserQuestion":
            return "Answer Claude's questions"
        case let toolName? where !toolName.isEmpty:
            return "Allow \(toolName)"
        default:
            return "Allow Claude tool"
        }
    }

    var permissionRequestSummary: String {
        if toolName == "ExitPlanMode" {
            return "Claude wants to exit plan mode and start implementation."
        }
        if let questionPrompt {
            return questionPrompt.title
        }
        if let notification = notificationPreview {
            return notification
        }
        if let toolName, !toolName.isEmpty {
            return "Claude wants to run \(toolName)."
        }
        return "Claude needs permission to continue."
    }

    var permissionRequestOptions: [AgentNotifyOption] {
        guard let permissionSuggestions, !permissionSuggestions.isEmpty else {
            return [
                AgentNotifyOption(label: "Yes", responseText: "1\n"),
                AgentNotifyOption(label: "No", responseText: "2\n")
            ]
        }

        return [
            AgentNotifyOption(label: "Yes", responseText: "1\n"),
            AgentNotifyOption(
                label: permissionSuggestions.first?.nativePromptLabel ?? "Yes, and don't ask again",
                responseText: "2\n"
            ),
            AgentNotifyOption(label: "No", responseText: "3\n")
        ]
    }

    var notificationPreview: String? {
        let preview = [title, message]
            .compactMap { $0?.nilIfEmpty }
            .joined(separator: " · ")
        return preview.nilIfEmpty
    }

    func updatedQuestionInput(answeredBy responseText: String) -> ClaudeHookJSONValue? {
        guard let questionPrompt,
              let selected = questionPrompt.options.first(where: { $0.responseText == responseText }) else {
            return toolInput
        }

        var updatedObject: [String: ClaudeHookJSONValue]
        if case let .object(existingObject) = toolInput {
            updatedObject = existingObject
        } else {
            updatedObject = [:]
        }
        updatedObject["answers"] = .object([selected.question: .string(selected.answer)])
        return .object(updatedObject)
    }
}

nonisolated enum ClaudePermissionMode: String, Codable, Equatable, Sendable {
    case `default`
    case acceptEdits
    case plan
    case dontAsk
    case bypassPermissions
    case auto
}

nonisolated enum ClaudePermissionBehavior: String, Codable, Equatable, Sendable {
    case allow
    case deny
    case ask
}

nonisolated enum ClaudePermissionUpdateDestination: String, Codable, Equatable, Sendable {
    case userSettings
    case projectSettings
    case localSettings
    case session
    case cliArg
}

nonisolated struct ClaudePermissionRuleValue: Codable, Equatable, Sendable {
    var toolName: String
    var ruleContent: String?
}

nonisolated enum ClaudePermissionUpdate: Codable, Equatable, Sendable {
    case addRules(destination: ClaudePermissionUpdateDestination, rules: [ClaudePermissionRuleValue], behavior: ClaudePermissionBehavior)
    case replaceRules(destination: ClaudePermissionUpdateDestination, rules: [ClaudePermissionRuleValue], behavior: ClaudePermissionBehavior)
    case removeRules(destination: ClaudePermissionUpdateDestination, rules: [ClaudePermissionRuleValue], behavior: ClaudePermissionBehavior)
    case setMode(destination: ClaudePermissionUpdateDestination, mode: ClaudePermissionMode)
    case addDirectories(destination: ClaudePermissionUpdateDestination, directories: [String])
    case removeDirectories(destination: ClaudePermissionUpdateDestination, directories: [String])

    private enum CodingKeys: String, CodingKey {
        case type
        case destination
        case rules
        case behavior
        case mode
        case directories
    }

    private enum UpdateType: String, Codable {
        case addRules
        case replaceRules
        case removeRules
        case setMode
        case addDirectories
        case removeDirectories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(UpdateType.self, forKey: .type)
        let destination = try container.decode(ClaudePermissionUpdateDestination.self, forKey: .destination)

        switch type {
        case .addRules:
            self = .addRules(
                destination: destination,
                rules: try container.decode([ClaudePermissionRuleValue].self, forKey: .rules),
                behavior: try container.decode(ClaudePermissionBehavior.self, forKey: .behavior)
            )
        case .replaceRules:
            self = .replaceRules(
                destination: destination,
                rules: try container.decode([ClaudePermissionRuleValue].self, forKey: .rules),
                behavior: try container.decode(ClaudePermissionBehavior.self, forKey: .behavior)
            )
        case .removeRules:
            self = .removeRules(
                destination: destination,
                rules: try container.decode([ClaudePermissionRuleValue].self, forKey: .rules),
                behavior: try container.decode(ClaudePermissionBehavior.self, forKey: .behavior)
            )
        case .setMode:
            self = .setMode(
                destination: destination,
                mode: try container.decode(ClaudePermissionMode.self, forKey: .mode)
            )
        case .addDirectories:
            self = .addDirectories(
                destination: destination,
                directories: try container.decode([String].self, forKey: .directories)
            )
        case .removeDirectories:
            self = .removeDirectories(
                destination: destination,
                directories: try container.decode([String].self, forKey: .directories)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .addRules(destination, rules, behavior):
            try container.encode(UpdateType.addRules, forKey: .type)
            try container.encode(destination, forKey: .destination)
            try container.encode(rules, forKey: .rules)
            try container.encode(behavior, forKey: .behavior)
        case let .replaceRules(destination, rules, behavior):
            try container.encode(UpdateType.replaceRules, forKey: .type)
            try container.encode(destination, forKey: .destination)
            try container.encode(rules, forKey: .rules)
            try container.encode(behavior, forKey: .behavior)
        case let .removeRules(destination, rules, behavior):
            try container.encode(UpdateType.removeRules, forKey: .type)
            try container.encode(destination, forKey: .destination)
            try container.encode(rules, forKey: .rules)
            try container.encode(behavior, forKey: .behavior)
        case let .setMode(destination, mode):
            try container.encode(UpdateType.setMode, forKey: .type)
            try container.encode(destination, forKey: .destination)
            try container.encode(mode, forKey: .mode)
        case let .addDirectories(destination, directories):
            try container.encode(UpdateType.addDirectories, forKey: .type)
            try container.encode(destination, forKey: .destination)
            try container.encode(directories, forKey: .directories)
        case let .removeDirectories(destination, directories):
            try container.encode(UpdateType.removeDirectories, forKey: .type)
            try container.encode(destination, forKey: .destination)
            try container.encode(directories, forKey: .directories)
        }
    }
}

private nonisolated extension ClaudePermissionUpdate {
    var nativePromptLabel: String {
        switch self {
        case let .addRules(_, rules, _),
             let .replaceRules(_, rules, _),
             let .removeRules(_, rules, _):
            if let ruleContent = rules.first?.ruleContent?.nilIfEmpty {
                return "Yes, and don't ask again for: \(ruleContent)"
            }
            if let toolName = rules.first?.toolName.nilIfEmpty {
                return "Yes, and don't ask again for: \(toolName)"
            }
            return "Yes, and don't ask again"
        case let .setMode(_, mode):
            return "Yes, and switch to \(mode.rawValue) mode"
        case let .addDirectories(_, directories),
             let .removeDirectories(_, directories):
            if let directory = directories.first?.nilIfEmpty {
                return "Yes, and don't ask again for: \(directory)"
            }
            return "Yes, and don't ask again"
        }
    }
}

nonisolated enum ClaudeHookJSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: ClaudeHookJSONValue])
    case array([ClaudeHookJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([ClaudeHookJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: ClaudeHookJSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .object, .array, .null:
            return nil
        }
    }
}

nonisolated enum ClaudePermissionRequestDecision: Codable, Equatable, Sendable {
    case allow(updatedInput: ClaudeHookJSONValue?, updatedPermissions: [ClaudePermissionUpdate] = [])
    case deny(message: String?, interrupt: Bool)

    private enum CodingKeys: String, CodingKey {
        case behavior
        case updatedInput
        case updatedPermissions
        case message
        case interrupt
    }

    private enum Behavior: String, Codable {
        case allow
        case deny
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let behavior = try container.decode(Behavior.self, forKey: .behavior)
        switch behavior {
        case .allow:
            self = .allow(
                updatedInput: try container.decodeIfPresent(ClaudeHookJSONValue.self, forKey: .updatedInput),
                updatedPermissions: try container.decodeIfPresent([ClaudePermissionUpdate].self, forKey: .updatedPermissions) ?? []
            )
        case .deny:
            self = .deny(
                message: try container.decodeIfPresent(String.self, forKey: .message),
                interrupt: try container.decodeIfPresent(Bool.self, forKey: .interrupt) ?? false
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .allow(updatedInput, updatedPermissions):
            try container.encode(Behavior.allow, forKey: .behavior)
            try container.encodeIfPresent(updatedInput, forKey: .updatedInput)
            if !updatedPermissions.isEmpty {
                try container.encode(updatedPermissions, forKey: .updatedPermissions)
            }
        case .deny(let message, let interrupt):
            try container.encode(Behavior.deny, forKey: .behavior)
            try container.encodeIfPresent(message, forKey: .message)
            if interrupt {
                try container.encode(true, forKey: .interrupt)
            }
        }
    }
}

nonisolated struct ClaudeHookInteractionResult: Equatable, Sendable {
    var decision: ClaudePermissionRequestDecision
}

private nonisolated struct ClaudePermissionRequestOutput: Encodable {
    struct HookSpecificOutput: Encodable {
        var hookEventName = ClaudeHookEventName.permissionRequest.rawValue
        var decision: ClaudePermissionRequestDecision
    }

    var continue_ = true
    var suppressOutput = true
    var hookSpecificOutput: HookSpecificOutput

    enum CodingKeys: String, CodingKey {
        case continue_ = "continue"
        case suppressOutput
        case hookSpecificOutput
    }
}
