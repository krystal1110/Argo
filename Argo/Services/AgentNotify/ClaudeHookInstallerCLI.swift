//
//  ClaudeHookInstallerCLI.swift
//  Argo
//
//  Author: krystal
//

import Foundation

nonisolated enum ClaudeHookInstallerCLI {
    enum ExitCode: Int32, Equatable {
        case ok = 0
        case usage = 64
        case ioError = 74
    }

    private static let usage = """
    argo claude-hooks — install Argo Claude Code hooks.

    USAGE:
      argo claude-hooks install [--claude-dir <path>] [--binary <path>]
      argo claude-hooks status [--claude-dir <path>]
      argo claude-hooks uninstall [--claude-dir <path>]
    """

    static func run(
        arguments: [String],
        binaryPathProvider: () -> String = { defaultBinaryPath() },
        stdoutWriter: (String) -> Void = { print($0) },
        stderrWriter: (String) -> Void = { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
    ) -> ExitCode {
        guard let subcommand = arguments.first else {
            stdoutWriter(usage)
            return .usage
        }
        let rest = Array(arguments.dropFirst())
        if subcommand == "-h" || subcommand == "--help" {
            stdoutWriter(usage)
            return .ok
        }

        do {
            switch subcommand {
            case "install":
                let options = try parseOptions(rest, allowsBinary: true)
                let binaryPath = options.binaryPath ?? binaryPathProvider()
                let status = try ClaudeHookInstaller.install(
                    claudeDirectory: options.claudeDirectory,
                    binaryPath: binaryPath
                )
                stdoutWriter("Installed Argo Claude hooks.")
                stdoutWriter("Claude settings: \(status.settingsURL.path)")
                stdoutWriter("Hook command: \(status.hookCommand ?? ClaudeHookInstaller.hookCommand(for: binaryPath))")
                return .ok
            case "status":
                let options = try parseOptions(rest, allowsBinary: false)
                let status = try ClaudeHookInstaller.status(claudeDirectory: options.claudeDirectory)
                stdoutWriter("Claude settings: \(status.settingsURL.path)")
                stdoutWriter("Managed hooks present: \(status.managedHooksPresent ? "yes" : "no")")
                if let hookCommand = status.hookCommand {
                    stdoutWriter("Hook command: \(hookCommand)")
                }
                return .ok
            case "uninstall":
                let options = try parseOptions(rest, allowsBinary: false)
                let status = try ClaudeHookInstaller.uninstall(claudeDirectory: options.claudeDirectory)
                stdoutWriter("Removed Argo Claude hooks.")
                stdoutWriter("Claude settings: \(status.settingsURL.path)")
                return .ok
            default:
                stderrWriter("argo claude-hooks: unknown subcommand '\(subcommand)'")
                return .usage
            }
        } catch let error as ParseError {
            stderrWriter("argo claude-hooks: \(error.description)")
            return .usage
        } catch {
            stderrWriter("argo claude-hooks: \(error.localizedDescription)")
            return .ioError
        }
    }

    private struct Options {
        var claudeDirectory = ClaudeHookInstaller.defaultClaudeDirectory()
        var binaryPath: String?
    }

    private enum ParseError: Error, Equatable {
        case missingValue(String)
        case unknownFlag(String)
        case unsupportedFlag(String)

        var description: String {
            switch self {
            case .missingValue(let flag):
                return "\(flag) requires a value"
            case .unknownFlag(let flag):
                return "unknown flag '\(flag)'"
            case .unsupportedFlag(let flag):
                return "\(flag) is only supported for install"
            }
        }
    }

    private static func parseOptions(_ arguments: [String], allowsBinary: Bool) throws -> Options {
        var options = Options()
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--claude-dir":
                guard index + 1 < arguments.count else { throw ParseError.missingValue(argument) }
                options.claudeDirectory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true).standardizedFileURL
                index += 1
            case "--binary":
                guard allowsBinary else { throw ParseError.unsupportedFlag(argument) }
                guard index + 1 < arguments.count else { throw ParseError.missingValue(argument) }
                options.binaryPath = normalizedPath(arguments[index + 1])
                index += 1
            case "-h", "--help":
                throw ParseError.unknownFlag(argument)
            default:
                throw ParseError.unknownFlag(argument)
            }
            index += 1
        }
        return options
    }

    private static func defaultBinaryPath() -> String {
        if let executableURL = Bundle.main.executableURL {
            return executableURL.standardizedFileURL.path
        }
        return normalizedPath(CommandLine.arguments.first ?? "Argo")
    }

    private static func normalizedPath(_ path: String) -> String {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL.path
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(path)
            .standardizedFileURL
            .path
    }
}
