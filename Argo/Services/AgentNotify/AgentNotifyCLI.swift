//
//  AgentNotifyCLI.swift
//  Argo
//
//  Author: krystal
//

import Foundation

/// `argo notify` argument parser + entry point.
///
/// The same `Argo` executable is the GUI app (when launched without
/// arguments or via Finder) and the CLI client (when invoked with
/// `notify ...`). This keeps the install footprint to a single binary.
enum AgentNotifyCLI {
    struct Options: Equatable {
        var title: String?
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
        var responseText: String?
        var options: [AgentNotifyOption] = []
        var showHelp: Bool = false
        var showVersion: Bool = false
    }

    enum ParseError: Error, Equatable {
        case unknownFlag(String)
        case missingValue(flag: String)
        case missingTitleAndBody
    }

    /// CLI exit codes. Stable for scripting.
    enum ExitCode: Int32 {
        case ok = 0
        case usage = 64       // EX_USAGE
        case unavailable = 69 // EX_UNAVAILABLE — server not reachable
        case ioError = 74     // EX_IOERR
    }

    /// Parses `argo notify` arguments. The leading `notify` token has already
    /// been consumed by the dispatch in `main.swift`.
    static func parse(arguments: [String]) throws -> Options {
        var options = Options()
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "-h", "--help":
                options.showHelp = true
            case "-V", "--version":
                options.showVersion = true
            case "-t", "--title":
                guard index + 1 < arguments.count else {
                    throw ParseError.missingValue(flag: argument)
                }
                options.title = arguments[index + 1]
                index += 1
            case "-b", "--body", "-m", "--message", "--prompt", "--summary":
                guard index + 1 < arguments.count else {
                    throw ParseError.missingValue(flag: argument)
                }
                options.body = arguments[index + 1]
                index += 1
            case "-p", "--pane":
                guard index + 1 < arguments.count else {
                    throw ParseError.missingValue(flag: argument)
                }
                options.paneID = arguments[index + 1]
                index += 1
            case "-w", "--workspace":
                guard index + 1 < arguments.count else {
                    throw ParseError.missingValue(flag: argument)
                }
                options.workspaceID = arguments[index + 1]
                index += 1
            case "-a", "--agent":
                guard index + 1 < arguments.count else {
                    throw ParseError.missingValue(flag: argument)
                }
                options.agentName = arguments[index + 1]
                index += 1
            case "--tool":
                guard index + 1 < arguments.count else {
                    throw ParseError.missingValue(flag: argument)
                }
                options.toolName = arguments[index + 1]
                index += 1
            case "--activity":
                options.kind = .activity
            case "--approval":
                options.kind = .approval
            case "--question":
                options.kind = .question
            case "--completed":
                options.kind = .completed
            case "--failed":
                options.kind = .failed
            case "--session":
                guard index + 1 < arguments.count else {
                    throw ParseError.missingValue(flag: argument)
                }
                options.sessionID = arguments[index + 1]
                index += 1
            case "--source":
                guard index + 1 < arguments.count else {
                    throw ParseError.missingValue(flag: argument)
                }
                options.sourceID = arguments[index + 1]
                index += 1
            case "--current-tool":
                guard index + 1 < arguments.count else {
                    throw ParseError.missingValue(flag: argument)
                }
                options.currentTool = arguments[index + 1]
                index += 1
            case "--command-preview":
                guard index + 1 < arguments.count else {
                    throw ParseError.missingValue(flag: argument)
                }
                options.commandPreview = arguments[index + 1]
                index += 1
            case "--affected-path":
                guard index + 1 < arguments.count else {
                    throw ParseError.missingValue(flag: argument)
                }
                options.affectedPath = arguments[index + 1]
                index += 1
            case "--initial-prompt":
                guard index + 1 < arguments.count else {
                    throw ParseError.missingValue(flag: argument)
                }
                options.initialPrompt = arguments[index + 1]
                index += 1
            case "--latest-prompt":
                guard index + 1 < arguments.count else {
                    throw ParseError.missingValue(flag: argument)
                }
                options.latestPrompt = arguments[index + 1]
                index += 1
            case "--assistant-message":
                guard index + 1 < arguments.count else {
                    throw ParseError.missingValue(flag: argument)
                }
                options.assistantMessage = arguments[index + 1]
                index += 1
            case "--response-text":
                guard index + 1 < arguments.count else {
                    throw ParseError.missingValue(flag: argument)
                }
                options.responseText = arguments[index + 1].replacingOccurrences(of: "\\n", with: "\n")
                index += 1
            case "--option":
                guard index + 1 < arguments.count else {
                    throw ParseError.missingValue(flag: argument)
                }
                options.options.append(Self.parseOption(arguments[index + 1]))
                index += 1
            default:
                if argument.hasPrefix("-") {
                    throw ParseError.unknownFlag(argument)
                }
                // Bare positional → treat as the title if not already set,
                // otherwise append to body so `argo notify "Build" "succeeded"`
                // reads naturally.
                if options.title == nil {
                    options.title = argument
                } else if options.body == nil {
                    options.body = argument
                } else {
                    options.body = "\(options.body ?? "") \(argument)"
                }
            }
            index += 1
        }
        return options
    }

    private static func parseOption(_ raw: String) -> AgentNotifyOption {
        let parts = raw.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let label = parts.first ?? raw
        let response = parts.count == 2 ? parts[1].replacingOccurrences(of: "\\n", with: "\n") : "\(label)\n"
        return AgentNotifyOption(label: label, responseText: response)
    }

    /// Build a request from CLI options + the surrounding shell environment.
    /// Pulls `ARGO_PANE_ID` from the env when the caller did not pass one,
    /// so a notification fired from inside a Argo pane routes to that pane
    /// automatically.
    static func makeRequest(
        from options: Options,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> AgentNotifyRequest {
        let title = options.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let body = options.body?.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty && (body?.isEmpty != false) {
            throw ParseError.missingTitleAndBody
        }
        let paneID = options.paneID ?? environment[ArgoAgentNotifyEnvironment.paneIDKey]
        return AgentNotifyRequest(
            title: title.isEmpty ? (body ?? "") : title,
            body: title.isEmpty ? nil : body,
            paneID: paneID.flatMap { $0.isEmpty ? nil : $0 },
            workspaceID: options.workspaceID.flatMap { $0.isEmpty ? nil : $0 },
            agentName: options.agentName.flatMap { $0.isEmpty ? nil : $0 },
            toolName: options.toolName.flatMap { $0.isEmpty ? nil : $0 },
            kind: options.kind,
            sessionID: options.sessionID.flatMap { $0.isEmpty ? nil : $0 },
            sourceID: options.sourceID.flatMap { $0.isEmpty ? nil : $0 },
            currentTool: options.currentTool.flatMap { $0.isEmpty ? nil : $0 },
            commandPreview: options.commandPreview.flatMap { $0.isEmpty ? nil : $0 },
            affectedPath: options.affectedPath.flatMap { $0.isEmpty ? nil : $0 },
            initialPrompt: options.initialPrompt.flatMap { $0.isEmpty ? nil : $0 },
            latestPrompt: options.latestPrompt.flatMap { $0.isEmpty ? nil : $0 },
            assistantMessage: options.assistantMessage.flatMap { $0.isEmpty ? nil : $0 },
            options: options.options.isEmpty ? nil : options.options,
            responseText: options.responseText.flatMap { $0.isEmpty ? nil : $0 }
        )
    }

    static let usageText = """
    argo notify — send a desktop notification to the running Argo app.

    USAGE:
      argo notify [TITLE] [BODY]
      argo notify --title <text> [--body <text>] [--pane <uuid>]
                   [--workspace <uuid>] [--agent <name>]
      argo notify --approval --title <text> --body <text>
                   [--command-preview <text>] [--affected-path <path>]
                   --option "Allow=1\\n" --option "Deny=2\\n"
      argo notify --question --prompt <text> --option Production
      argo notify --completed --summary <text> --tool Codex

    OPTIONS:
      -t, --title <text>     Notification title (required if no positional)
      -b, --body  <text>     Notification body (alias: -m, --message)
      --prompt <text>        Question prompt alias for --body
      --summary <text>       Completion/failure summary alias for --body
      -p, --pane  <uuid>     Originating pane (defaults to $ARGO_PANE_ID)
      -w, --workspace <uuid> Originating workspace
      -a, --agent <name>     Agent display name (e.g. Claude, Codex)
      --tool <name>          Agent tool name (rich notify alias)
      --activity             Mark as agent activity
      --approval             Mark as approval request
      --question             Mark as question request
      --completed            Mark as completed
      --failed               Mark as failed
      --session <id>         Stable agent session id
      --source <id>          Stable event source id
      --current-tool <name>  Current tool name
      --command-preview <s>  Command or action preview
      --affected-path <path> Approval path context shown in Dynamic Island
      --option <label=text>  Action/question option response
      -V, --version          Print Argo version and exit
      -h, --help             Show this help and exit

    The CLI talks to the running Argo app over a Unix domain socket at
    ~/Library/Application Support/Argo/agent-notify.sock. If Argo is not
    running, the command exits with status 69 (EX_UNAVAILABLE).
    """

    /// Top-level CLI runner. Returns an exit code; the dispatcher in
    /// `main.swift` calls `exit(_)` with the returned value.
    static func run(
        arguments: [String],
        send: (AgentNotifyRequest) throws -> Void = { try AgentNotifyClient.send($0) },
        stdoutWriter: (String) -> Void = { print($0) },
        stderrWriter: (String) -> Void = { FileHandle.standardError.write(Data(($0 + "\n").utf8)) },
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ExitCode {
        let options: Options
        do {
            options = try parse(arguments: arguments)
        } catch ParseError.unknownFlag(let flag) {
            stderrWriter("argo notify: unknown flag '\(flag)'")
            stderrWriter(usageText)
            return .usage
        } catch ParseError.missingValue(let flag) {
            stderrWriter("argo notify: flag '\(flag)' requires a value")
            return .usage
        } catch {
            stderrWriter("argo notify: \(error)")
            return .usage
        }

        if options.showHelp {
            stdoutWriter(usageText)
            return .ok
        }
        if options.showVersion {
            let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "dev"
            stdoutWriter("argo notify v\(version)")
            return .ok
        }

        let request: AgentNotifyRequest
        do {
            request = try makeRequest(from: options, environment: environment)
        } catch ParseError.missingTitleAndBody {
            stderrWriter("argo notify: a title or body is required")
            stderrWriter(usageText)
            return .usage
        } catch {
            stderrWriter("argo notify: \(error)")
            return .usage
        }

        do {
            try send(request)
            return .ok
        } catch AgentNotifyError.socketUnavailable {
            stderrWriter("argo notify: Argo is not running (no socket at ~/Library/Application Support/Argo/agent-notify.sock)")
            return .unavailable
        } catch AgentNotifyError.payloadTooLarge(let limit, let actual) {
            stderrWriter("argo notify: payload too large (\(actual) > \(limit) bytes)")
            return .ioError
        } catch AgentNotifyError.socketWriteFailed(let code) {
            stderrWriter("argo notify: write failed (errno \(code))")
            return .ioError
        } catch {
            stderrWriter("argo notify: \(error)")
            return .ioError
        }
    }

    /// Claude hook entry point. Hooks must fail open: if Argo is not running
    /// or the payload is not one we surface, Claude should continue normally.
    static func runClaudeHook(
        input: Data = FileHandle.standardInput.readDataToEndOfFile(),
        send: (Data, URL, TimeInterval) throws -> Data? = {
            try ArgoControlClient.sendRaw(frame: $0, socketURL: $1, timeout: $2)
        },
        stdoutWriter: (Data) -> Void = { FileHandle.standardOutput.write($0) },
        stderrWriter: (String) -> Void = { FileHandle.standardError.write(Data(($0 + "\n").utf8)) },
        environment: [String: String] = ProcessInfo.processInfo.environment,
        executablePath: String = ClaudeHookAutoInstaller.currentExecutablePath()
    ) -> ExitCode {
        do {
            guard let frame = try ClaudeHookNotifyBridge.controlFrame(from: input, environment: environment) else {
                return .ok
            }
            let socketURLs = [
                AgentNotifySocketPath.resolveExecutableSocketURL(executablePath: executablePath),
                AgentNotifySocketPath.resolveSocketURL()
            ].reduce(into: [URL]()) { urls, url in
                if !urls.contains(url) {
                    urls.append(url)
                }
            }

            var lastError: Error?
            for socketURL in socketURLs {
                do {
                    let response = try send(frame, socketURL, ClaudeHookNotifyBridge.interactiveTimeout)
                    if let stdout = try ClaudeHookNotifyBridge.cliStdout(from: response) {
                        stdoutWriter(stdout)
                    }
                    return .ok
                } catch {
                    lastError = error
                }
            }
            if let lastError {
                stderrWriter("argo claude-hook: \(lastError)")
            }
        } catch {
            stderrWriter("argo claude-hook: \(error)")
        }
        return .ok
    }
}
