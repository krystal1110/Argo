//
//  ClaudeHookAutoInstaller.swift
//  Argo
//
//  Author: krystal
//

import Foundation

nonisolated enum ClaudeHookAutoInstaller {
    enum Result: Equatable, Sendable {
        case alreadyInstalled
        case installed
    }

    @discardableResult
    static func installIfMissing(
        claudeDirectory: URL = ClaudeHookInstaller.defaultClaudeDirectory(),
        binaryPath: String
    ) throws -> Result {
        let status = try ClaudeHookInstaller.status(claudeDirectory: claudeDirectory)
        if status.managedHooksPresent, status.hookCommand == ClaudeHookInstaller.hookCommand(for: binaryPath) {
            return .alreadyInstalled
        }

        _ = try ClaudeHookInstaller.install(claudeDirectory: claudeDirectory, binaryPath: binaryPath)
        return .installed
    }

    static func installCurrentAppIfMissing(
        claudeDirectory: URL = ClaudeHookInstaller.defaultClaudeDirectory(),
        bundle: Bundle = .main
    ) throws -> Result {
        let executablePath = currentExecutablePath(bundle: bundle)
        return try installIfMissing(claudeDirectory: claudeDirectory, binaryPath: executablePath)
    }

    static func currentExecutablePath(bundle: Bundle = .main) -> String {
        bundle.executableURL?.standardizedFileURL.path
            ?? URL(fileURLWithPath: CommandLine.arguments.first ?? "Argo").standardizedFileURL.path
    }
}
