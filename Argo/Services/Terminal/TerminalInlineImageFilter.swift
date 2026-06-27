//
//  TerminalInlineImageFilter.swift
//  Argo
//
//  Author: krystal
//

import Foundation

nonisolated enum TerminalInlineImageFilter {
    static let defaultsKey = "argo.terminal.inlineImageProtocol"

    private static let helperResourceName = "argo-osc-filter"

    static var isEnabled: Bool {
        guard UserDefaults.standard.object(forKey: defaultsKey) != nil else {
            return true
        }
        return UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static var helperPath: String? {
        Bundle.main.url(forResource: helperResourceName, withExtension: nil)?.path
    }

    static func applyIfEnabled(to command: TerminalCommandDefinition) -> TerminalCommandDefinition {
        guard isEnabled, let helperPath else { return command }
        return wrapped(command: command, helperPath: helperPath)
    }

    static func wrapped(command: TerminalCommandDefinition, helperPath: String) -> TerminalCommandDefinition {
        guard !command.executablePath.isEmpty, command.executablePath != helperPath else {
            return command
        }
        return TerminalCommandDefinition(
            executablePath: helperPath,
            arguments: [command.executablePath] + command.arguments,
            displayName: command.displayName
        )
    }
}
